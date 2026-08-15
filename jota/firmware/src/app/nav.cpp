// ============================================================================
//  Jota — screen navigator (implementation)
//
//  Interaction contract, held to on EVERY screen:
//    BOOT short = select / confirm / record      BOOT long = back
//    PWR  short = next item                      PWR  long = power off
//
//  NOTE (phase 1): recording and syncing are SIMULATED. The timer counts and
//  the sync bar advances so the whole flow can be walked on real hardware —
//  but no audio is captured and nothing is uploaded. Phase 2 replaces the
//  tick() bodies with real work.
// ============================================================================
#include "app/nav.h"

#include "ui/screens.h"
#include "ui/theme.h"  // element regions are expressed in layout tokens

namespace jota {

static const uint32_t SPLASH_MS    = 3000;
static const uint32_t GUIDE_MS     = 4000;
static const uint32_t SAVED_MS     = 1800;
static const uint32_t SYNC_STEP_MS = 900;

// How long the pairing offer stands. The code must live exactly as long as the
// offer does: this used to be a 6-second animation left over from the simulated
// handshake, and it CLEARED the code — so by the time a phone got round to
// writing `auth`, the device had nothing to compare against and every attempt
// failed. Two minutes is a walk-to-the-other-room's worth of patience.
static const uint32_t PAIR_WINDOW_MS = 120000;

// How long "PAIRED" stays up before falling back to the menu.
static const uint32_t PAIR_OK_MS    = 1800;
static const char    *SIM_PAIR_CODE = "428 913";

// Element regions, so a tick pushes only the pixels that actually change.
static const Rect kTimerRect = {TIMER_X, TIMER_Y, TIMER_W, TIMER_H};
static const Rect kListRect  = {MARGIN, CONTENT_TOP, CONTENT_W, CONTENT_H};
static const Rect kSyncRect  = {MARGIN, STATUS_BASELINE - CAP_LABEL - 2,
                                CONTENT_W,
                                (PROGRESS_Y + PROGRESS_H + 4) -
                                    (STATUS_BASELINE - CAP_LABEL - 2)};

void renderScreen(Adafruit_GFX &g, Screen s, const AppModel &m) {
  switch (s) {
    case Screen::Splash:    screenSplash(g, m); break;
    case Screen::Guide:     screenGuide(g); break;
    case Screen::Ready:     screenReady(g, m); break;
    case Screen::Recording: screenRecording(g, m); break;
    case Screen::Saved:     screenSaved(g, m); break;
    case Screen::Menu:      screenMenu(g, m); break;
    case Screen::ChooseTag: screenChooseTag(g, m); break;
    case Screen::Syncing:   screenSyncing(g, m); break;
    case Screen::NoteView:  screenNoteView(g, m); break;
    case Screen::Pair:      screenPair(g, m); break;
  }
}

void Nav::begin(uint32_t nowMs) {
  s_           = Screen::Splash;
  enteredMs_   = nowMs;
  lastTickMs_  = nowMs;
  dirty_       = true;
  needsFull_   = true;
  hasRegion_   = false;
  justEntered_ = true;
  powerOff_    = false;
}

void Nav::go(Screen s, uint32_t nowMs, bool full) {
  s_           = s;
  enteredMs_   = nowMs;
  lastTickMs_  = nowMs;
  dirty_       = true;
  needsFull_   = full;
  hasRegion_   = false;  // a screen change invalidates any element region
  justEntered_ = true;   // dwell is measured from paintDone(), not from here
}

// Commit the in-progress recording as a note.
static void commitNote(AppModel &m) {
  m.note.id   = ++m.noteCount;
  m.note.secs = m.recSecs;
  m.note.text = nullptr;  // untranscribed until phase 2
  m.noteIndex = m.noteCount;

  // The armed tag belongs to THIS note, and is then spent. Leaving it armed
  // would silently file every later note under a heading chosen once, which is
  // worse than not tagging at all.
  m.note.tag  = tagAt(m.tags, m.tagArmed);
  m.tagArmed  = TAG_NONE;
}

void Nav::handle(BtnEvent e, AppModel &m, uint32_t nowMs) {
  if (e == BtnEvent::None) return;

  // Power off works from EVERY screen. Previously it was wired on two, so on
  // the other six holding PWR silently did nothing and read as a hang.
  if (e == BtnEvent::PwrLong) {
    // Never lose audio to a power press: stop and save first.
    if (s_ == Screen::Recording) commitNote(m);
    powerOff_ = true;
    return;
  }

  switch (s_) {
    case Screen::Splash:
      go(Screen::Guide, nowMs);
      break;

    case Screen::Guide:
      go(Screen::Ready, nowMs);
      break;

    case Screen::Ready:
      // BootLong starts too. Press-and-hold-to-talk is the first instinct on
      // any one-button recorder, and it used to do NOTHING here — no ink, no
      // sound, on a panel that takes two seconds to repaint. The instinct
      // cannot be allowed to fail silently.
      if (e == BtnEvent::BootShort || e == BtnEvent::BootLong) {
        m.recSecs = 0;
        // The ONE transition that stays partial: the ring's outer edge does
        // not move and the annulus only thickens inward, so this is purely
        // additive ink with nothing to erase. Record lands instantly.
        go(Screen::Recording, nowMs, /*full=*/false);
      } else if (e == BtnEvent::PwrShort) {
        m.menuSel = 0;
        go(Screen::Menu, nowMs);
      }
      break;

    case Screen::Recording:
      // BOTH stop and SAVE. A long press used to discard, silently, with no
      // undo — while PwrLong on this very screen committed first. Two long
      // presses on adjacent buttons with opposite outcomes, and the
      // destructive one unguarded, is a trap; whoever holds the button to
      // stop is not asking to throw the recording away.
      //
      // Nothing on this device destroys a recording. Deleting a note is the
      // phone's job, where there is a screen big enough to confirm it.
      if (e == BtnEvent::BootShort || e == BtnEvent::BootLong) {
        commitNote(m);
        go(Screen::Saved, nowMs);
      }
      break;

    case Screen::Saved:
      if (e == BtnEvent::BootShort || e == BtnEvent::BootLong) {
        go(Screen::Ready, nowMs);
      }
      break;

    case Screen::Menu:
      if (e == BtnEvent::PwrShort) {
        m.menuSel = (uint8_t)((m.menuSel + 1) % MENU_COUNT);
        markDirtyRegion(kListRect);  // only the inverted row moves
      } else if (e == BtnEvent::BootShort) {
        switch (m.menuSel) {
          case 0: go(Screen::NoteView, nowMs); break;
          case 1: go(Screen::ChooseTag, nowMs); break;
          case 2: m.syncDone = 0; go(Screen::Syncing, nowMs); break;
          case 3: m.pairCode = SIM_PAIR_CODE; go(Screen::Pair, nowMs); break;
          default: go(Screen::Guide, nowMs); break;
        }
      } else if (e == BtnEvent::BootLong) {
        go(Screen::Ready, nowMs);
      }
      break;

    case Screen::ChooseTag:
      if (e == BtnEvent::BootShort) {
        // Select ARMS the tag for the next recording. This branch used to be
        // identical to cancel: pressing select on this screen did nothing at
        // all, which taught that select is sometimes meaningless.
        if (m.tags.count) {
          // Choosing the armed tag again disarms it — the only way back to
          // "no tag" without a sixth screen.
          m.tagArmed = (m.tagArmed == m.tagSel) ? TAG_NONE : m.tagSel;
        }
        go(Screen::Menu, nowMs);
      } else if (e == BtnEvent::PwrShort) {
        // The list is whatever the phone last wrote, so it can be empty — and
        // `% 0` is an integer-divide exception, which on the ESP32 is a panic
        // and a reboot, not a wrong pixel.
        if (m.tags.count == 0) break;
        m.tagSel = (uint8_t)((m.tagSel + 1) % m.tags.count);
        // Not just the list: the status slot carries the position, and a long
        // list scrolls every row under the cursor.
        markDirty();
      } else if (e == BtnEvent::BootLong) {
        // Cancel: leave whatever was already armed alone.
        go(Screen::Menu, nowMs);
      }
      break;

    case Screen::Syncing:
      if (e == BtnEvent::BootLong) go(Screen::Menu, nowMs);
      break;

    case Screen::NoteView:
      if (e == BtnEvent::BootShort || e == BtnEvent::BootLong) {
        go(Screen::Menu, nowMs);
      }
      break;

    case Screen::Pair:
      if (e == BtnEvent::BootLong) {   // cancel pairing
        m.pairCode = nullptr;
        go(Screen::Menu, nowMs);
      }
      break;
  }
}

void Nav::tick(uint32_t nowMs, AppModel &m) {
  // A phone authenticating is worth showing. Jump to MENU so the device is
  // sitting on the thing you can now drive from it, rather than leaving the
  // person to guess whether the connection landed.
  //
  // Three screens are never interrupted:
  //   PAIR      — it has its own "PAIRED" confirmation and gets to MENU itself
  //   RECORDING — nothing preempts a recording, ever
  //   SAVED     — a 1.8s confirmation that a note exists; cutting it short
  //               would make the note look like it had not been kept
  if (m.authed && !wasAuthed_) {
    wasAuthed_ = true;
    if (s_ != Screen::Pair && s_ != Screen::Recording && s_ != Screen::Saved) {
      m.menuSel = 0;
      go(Screen::Menu, nowMs);
    }
  } else if (!m.authed) {
    wasAuthed_ = false;
  }

  switch (s_) {
    case Screen::Splash:
      // TODO(phase 2): gate GUIDE behind an NVS first-run flag so it appears
      // once rather than on every boot.
      if (nowMs - enteredMs_ >= SPLASH_MS) go(Screen::Guide, nowMs);
      break;

    case Screen::Guide:
      if (nowMs - enteredMs_ >= GUIDE_MS) go(Screen::Ready, nowMs);
      break;

    case Screen::Recording:
      if (nowMs - lastTickMs_ >= 1000) {
        lastTickMs_ += 1000;
        m.recSecs++;
        markDirtyRegion(kTimerRect);
      }
      break;

    case Screen::Saved:
      if (nowMs - enteredMs_ >= SAVED_MS) go(Screen::Ready, nowMs);
      break;

    case Screen::Syncing:
      if (nowMs - lastTickMs_ >= SYNC_STEP_MS) {
        lastTickMs_ = nowMs;
        if (m.syncDone < m.syncTotal) {
          m.syncDone++;
          // Spans the status ratio as well as the bar — both change together.
          markDirtyRegion(kSyncRect);
        } else {
          go(Screen::Menu, nowMs);
        }
      }
      break;

    case Screen::Pair:
      if (m.authed && m.pairCode) {
        // The phone answered. Drop the code — it has done its job and must not
        // sit on an unattended panel — and hold the confirmation.
        m.pairCode = nullptr;
        m.paired   = true;
        enteredMs_ = nowMs;   // the hold starts now, not when PAIR opened
        markDirty(/*full=*/true);
      } else if (!m.pairCode) {
        if (nowMs - enteredMs_ >= PAIR_OK_MS) go(Screen::Menu, nowMs);
      } else if (nowMs - enteredMs_ >= PAIR_WINDOW_MS) {
        m.pairCode = nullptr;  // the offer expired; nothing is left showing
        go(Screen::Menu, nowMs);
      }
      break;

    default:
      break;
  }
}

}  // namespace jota
