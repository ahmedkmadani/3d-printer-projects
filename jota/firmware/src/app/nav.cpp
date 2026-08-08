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

// PHASE 2 STUB: stands in for the BLE provisioning handshake so the flow can
// be walked on hardware before the radio exists. The real code comes from the
// provisioning manager, and this timeout becomes its success callback.
static const uint32_t PAIR_SIM_MS   = 6000;
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
    case Screen::Splash:    screenSplash(g); break;
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
      if (e == BtnEvent::BootShort) {
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
      if (e == BtnEvent::BootShort) {
        commitNote(m);
        go(Screen::Saved, nowMs);
      } else if (e == BtnEvent::BootLong) {
        go(Screen::Ready, nowMs);  // discard — long press is deliberate
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
      if (e == BtnEvent::PwrShort) {
        m.tagSel = (uint8_t)((m.tagSel + 1) % TAG_COUNT);
        markDirtyRegion(kListRect);
      } else if (e == BtnEvent::BootShort || e == BtnEvent::BootLong) {
        // Confirming must never land further out than cancelling: a flow
        // entered from Menu returns to Menu.
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
      if (nowMs - enteredMs_ >= PAIR_SIM_MS) {
        m.pairCode = nullptr;
        m.paired   = true;
        go(Screen::Menu, nowMs);
      }
      break;

    default:
      break;
  }
}

}  // namespace jota
