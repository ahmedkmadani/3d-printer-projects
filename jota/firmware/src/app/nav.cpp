// ============================================================================
//  Jota — screen navigator (implementation)
//
//  Interaction contract, held to on EVERY screen:
//    BOOT short = record / stop / confirm     BOOT long = same as short
//    PWR  short = next tag (SAVED only)       PWR  long = power off
//    BOTH long  = erase everything (asks first)
//
//  BOOT long doing exactly what BOOT short does is deliberate. There is
//  nowhere left to go "back" to now that the menu is gone, and a long press
//  that silently did nothing on a panel this slow reads as a crash.
//
//  NOTE (phase 1): recording is SIMULATED. The timer counts so the whole flow
//  can be walked on real hardware — but no audio is captured. Phase 2 replaces
//  the tick() bodies with real work.
// ============================================================================
#include "app/nav.h"

#include "ui/screens.h"
#include "ui/theme.h"  // element regions are expressed in layout tokens

namespace jota {

static const uint32_t SAVED_MS = 1600;

// How long the tag offer stands after a recording is saved.
//
// Ten seconds, and it TIMES OUT rather than waiting: the moment you have to
// deal with it is often the moment you are driving, and a device that holds a
// decision open until you answer has put itself in the middle of
// press-speak-press. Say nothing and the note is simply untagged; the phone
// will suggest one later.
static const uint32_t TAG_WINDOW_MS = 10000;

// How long the pairing offer stands. The code must live exactly as long as the
// offer does: this used to be a 6-second animation left over from the simulated
// handshake, and it CLEARED the code — so by the time a phone got round to
// writing `auth`, the device had nothing to compare against and every attempt
// failed. Two minutes is a walk-to-the-other-room's worth of patience.
static const uint32_t PAIR_WINDOW_MS = 120000;

// How long "PAIRED" stays up before falling back.
static const uint32_t PAIR_OK_MS = 1800;

// How long the ERASE question stands before it answers itself with "no".
static const uint32_t ERASE_WINDOW_MS = 10000;

static const char *SIM_PAIR_CODE = "428 913";

// Element regions, so a tick pushes only the pixels that actually change.
static const Rect kTimerRect = {TIMER_X, TIMER_Y, TIMER_W, TIMER_H};
static const Rect kListRect  = {MARGIN, CONTENT_TOP, CONTENT_W, CONTENT_H};

void renderScreen(Adafruit_GFX &g, Screen s, const AppModel &m) {
  switch (s) {
    case Screen::Ready:     screenReady(g, m); break;
    case Screen::Recording: screenRecording(g, m); break;
    case Screen::Saved:     screenSaved(g, m); break;
    case Screen::Pair:      screenPair(g, m); break;
    case Screen::Erase:     screenErase(g, m); break;
  }
}

void Nav::begin(uint32_t nowMs) {
  s_            = Screen::Ready;
  enteredMs_    = nowMs;
  lastTickMs_   = nowMs;
  dirty_        = true;
  needsFull_    = true;
  hasRegion_    = false;
  justEntered_  = true;
  powerOff_     = false;
  wipeRequested_ = false;
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

// Commit the in-progress recording as a note. The tag is NOT set here: it is
// chosen on the SAVED screen in the seconds afterwards, or not at all.
static void commitNote(AppModel &m) {
  m.note.id   = ++m.noteCount;
  m.note.secs = m.recSecs;
  m.note.text = nullptr;  // the device never holds a transcript, by design
  m.note.tag  = nullptr;
  if (m.pending < 255) m.pending++;
  m.tagSel = 0;
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

  if (e == BtnEvent::BothLong) {
    // Nothing preempts a recording, not even this. The gesture is destructive
    // and the recording is the one thing on the device that cannot be got
    // back — asking "erase everything?" over a live microphone would be the
    // worst possible moment to be wrong about what the user meant.
    if (s_ == Screen::Recording) return;

    if (s_ == Screen::Erase) {
      // Second hold: this is the answer. The wipe itself belongs to main.cpp;
      // nav owns no storage and no radio, which is what keeps it renderable
      // on the host preview.
      wipeRequested_ = true;
      return;
    }
    go(Screen::Erase, nowMs);
    return;
  }

  const bool select = (e == BtnEvent::BootShort || e == BtnEvent::BootLong);

  switch (s_) {
    case Screen::Ready:
      // Press-and-hold-to-talk is the first instinct on any one-button
      // recorder, and it used to do NOTHING here — no ink, no sound, on a
      // panel that takes two seconds to repaint. The instinct cannot be
      // allowed to fail silently.
      if (select) {
        m.recSecs = 0;
        // The ONE transition that stays partial: the ring's outer edge does
        // not move and the state mark appears inside it, so this is purely
        // additive ink with nothing to erase. Record lands instantly.
        go(Screen::Recording, nowMs, /*full=*/false);
      }
      // PWR short deliberately does nothing here. Every destination it used to
      // reach is gone: notes and sync live on the phone, tags are chosen on
      // SAVED, and pairing shows itself. A button that opens a menu of one
      // thing is worse than a button that waits.
      break;

    case Screen::Recording:
      // BOTH stop and SAVE. A long press used to discard, silently, with no
      // undo — while PwrLong on this very screen committed first. Two long
      // presses on adjacent buttons with opposite outcomes, and the
      // destructive one unguarded, is a trap; whoever holds the button to
      // stop is not asking to throw the recording away.
      //
      // Nothing on this device destroys a recording except ERASE. Deleting one
      // note is the phone's job, where there is a screen big enough to confirm
      // it.
      if (select) {
        commitNote(m);
        go(Screen::Saved, nowMs);
      }
      break;

    case Screen::Saved:
      if (e == BtnEvent::PwrShort) {
        // The list is whatever the phone last wrote, so it can be empty — and
        // `% 0` is an integer-divide exception, which on the ESP32 is a panic
        // and a reboot, not a wrong pixel.
        if (m.tags.count == 0) break;
        m.tagSel = (uint8_t)((m.tagSel + 1) % m.tags.count);
        markDirtyRegion(kListRect);
      } else if (select) {
        // Confirm. Choosing the tag already on the note again clears it —
        // the only way back to "no tag" without inventing a sixth screen.
        const char *chosen = tagAt(m.tags, m.tagSel);
        m.note.tag = (m.note.tag == chosen) ? nullptr : chosen;
        go(Screen::Ready, nowMs);
      }
      break;

    case Screen::Pair:
      // No way to dismiss it by hand. The device is unowned: there is nothing
      // else for it to show, and a cancel would only hide the one number the
      // phone is asking for.
      break;

    case Screen::Erase:
      // A single press is not an answer to a destructive question. Only the
      // deliberate second both-button hold above counts, or the timeout below
      // declines for you.
      break;
  }
}

void Nav::tick(uint32_t nowMs, AppModel &m) {
  // An unowned device has exactly one useful thing to say, so it says it
  // without being asked. This replaces hunting MENU -> PAIR on a two-button
  // device at the single highest-friction moment in the product.
  if (!m.paired && s_ != Screen::Pair && s_ != Screen::Recording &&
      s_ != Screen::Saved && s_ != Screen::Erase) {
    m.pairCode = SIM_PAIR_CODE;
    go(Screen::Pair, nowMs);
    return;
  }

  // A phone authenticating is worth showing. Land on READY — the thing you
  // can actually do — rather than leaving the person to guess.
  //
  // Three screens are never interrupted:
  //   PAIR      — it has its own "PAIRED" confirmation and gets there itself
  //   RECORDING — nothing preempts a recording, ever
  //   SAVED     — the tag window is the user's, not ours
  if (m.authed && !wasAuthed_) {
    wasAuthed_ = true;
    if (s_ != Screen::Pair && s_ != Screen::Recording && s_ != Screen::Saved) {
      go(Screen::Ready, nowMs);
    }
  } else if (!m.authed) {
    wasAuthed_ = false;
  }

  switch (s_) {
    case Screen::Recording:
      if (nowMs - lastTickMs_ >= 1000) {
        lastTickMs_ += 1000;
        m.recSecs++;
        markDirtyRegion(kTimerRect);
      }
      break;

    case Screen::Saved:
      // With no tags to offer there is nothing to wait for, so the
      // confirmation is short. With tags, the window is the person's to spend.
      if (nowMs - enteredMs_ >=
          (m.tags.count == 0 ? SAVED_MS : TAG_WINDOW_MS)) {
        go(Screen::Ready, nowMs);
      }
      break;

    case Screen::Pair:
      if (m.authed && m.pairCode) {
        // The phone answered. Drop the code — it has done its job and must not
        // sit on an unattended panel — and hold the confirmation.
        m.pairCode = nullptr;
        m.paired   = true;
        enteredMs_ = nowMs;  // the hold starts now, not when PAIR opened
        markDirty(/*full=*/true);
      } else if (!m.pairCode) {
        if (nowMs - enteredMs_ >= PAIR_OK_MS) go(Screen::Ready, nowMs);
      } else if (nowMs - enteredMs_ >= PAIR_WINDOW_MS) {
        // The offer expired. Nothing is left showing, and the next tick puts
        // it straight back up if the device is still unowned — which is
        // correct: the code rotates, the offer does not end.
        m.pairCode = nullptr;
        go(Screen::Ready, nowMs);
      }
      break;

    case Screen::Erase:
      // Silence declines. A destructive question that waited forever would
      // eventually be answered by a pocket.
      if (nowMs - enteredMs_ >= ERASE_WINDOW_MS) go(Screen::Ready, nowMs);
      break;

    default:
      break;
  }
}

}  // namespace jota
