// ============================================================================
//  Jota — BLE link (implementation)
//  Contract: docs/ble-service.md
// ============================================================================
#include "link/ble.h"

#include <NimBLEDevice.h>
#include <esp_random.h>
#include <Preferences.h>

#include <stdio.h>
#include <string.h>

#include "app/identity.h"
#include "app/tags.h"
#include "util/clock.h"
#include "util/diag.h"

namespace jota {

// "4a6f7461" is "Jota" in hex.
static const char *SVC_UUID    = "4a6f7461-1e5f-4b2a-9c33-000000000000";
static const char *CH_AUTH     = "4a6f7461-1e5f-4b2a-9c33-000000000001";
static const char *CH_STATUS   = "4a6f7461-1e5f-4b2a-9c33-000000000002";
static const char *CH_INDEX    = "4a6f7461-1e5f-4b2a-9c33-000000000003";
static const char *CH_FETCH    = "4a6f7461-1e5f-4b2a-9c33-000000000004";
static const char *CH_DATA     = "4a6f7461-1e5f-4b2a-9c33-000000000005";
static const char *CH_ACK      = "4a6f7461-1e5f-4b2a-9c33-000000000006";
static const char *CH_TAGS     = "4a6f7461-1e5f-4b2a-9c33-000000000007";
static const char *CH_CLOCK    = "4a6f7461-1e5f-4b2a-9c33-000000000008";
static const char *CH_DIAG     = "4a6f7461-1e5f-4b2a-9c33-000000000009";
static const char *CH_ERASE    = "4a6f7461-1e5f-4b2a-9c33-00000000000a";

static const uint32_t ADV_FAST_MS   = 60000;  // after a recording or SYNC
static const uint8_t  MAX_AUTH_FAIL = 3;
static const uint32_t LOCKOUT_MS    = 30000;
// Chunks pushed per loop() pass. NimBLE 1.x notify() gives no backpressure
// signal, so this is deliberately modest: with the 5 ms main-loop delay it
// stays comfortably inside what the link can carry, and the stack queues the
// rest rather than dropping it.
static const uint8_t  CHUNKS_PER_LOOP = 3;

// ---- Module state --------------------------------------------------------

static NoteStore *g_store = nullptr;
static AppModel  *g_model = nullptr;

static NimBLECharacteristic *g_status = nullptr;
static NimBLECharacteristic *g_index  = nullptr;
static NimBLECharacteristic *g_data   = nullptr;

static bool     g_connected  = false;
static bool     g_authed     = false;
static uint16_t g_conn       = 0;
static uint16_t g_mtu        = 23;
static uint8_t  g_authFails  = 0;
static uint32_t g_lockUntil  = 0;
static uint32_t g_fastUntil  = 0;
static uint8_t  g_advPending = 0xFF;   // forces the first advert update
static uint8_t  g_advFlags   = 0xFF;
static uint8_t  g_advBattery = 0xFE;  // never a real value; forces the first
static char     g_pairCode[8] = {0};
static uint8_t  g_battery    = 0xFF;  // 0xFF = no sense pin, unknown
static bool     g_eraseAsked = false; // owner wrote a valid `erase`

// ---- tags ----------------------------------------------------------------
// The phone owns the list and writes it whole; Jota stores it and the TAGS
// screen shows it. A write lands in this staging buffer and is applied from
// loop(), never from the callback: parsing plus an NVS commit is far more than
// a BLE callback may do on the host stack's task.
//
// The list itself lives in AppModel::tags. It used to live here, in a buffer
// nothing ever drew, which is why a tag written from the app never appeared on
// the panel.
static const size_t TAGS_JSON_MAX = 192;  // 8 * (12 + 3) + 2, with headroom

static char        g_tagsPending[TAGS_JSON_MAX] = {0};
static bool        g_tagsDirty   = false;  // a write is waiting to be applied
static bool        g_tagsChanged = false;  // the model changed; repaint
static Preferences g_prefs;

struct Xfer {
  bool     active = false;
  uint16_t id     = 0;
  uint32_t offset = 0;
};
static Xfer g_xfer;

// ---- Helpers -------------------------------------------------------------

static void digitsOnly(const char *in, char *out, size_t n) {
  size_t w = 0;
  for (const char *p = in; *p && w + 1 < n; ++p)
    if (*p >= '0' && *p <= '9') out[w++] = *p;
  out[w] = '\0';
}

// Reads a string field out of a flat JSON object. Same spirit as the integer
// readers further down: two fields do not justify a parser.
static bool jsonStr(const char *s, const char *key, char *out, size_t n) {
  out[0] = '\0';
  const char *p = strstr(s, key);
  if (!p) return false;
  p = strchr(p + strlen(key), ':');
  if (!p) return false;
  p = strchr(p, '"');
  if (!p) return false;
  ++p;

  size_t w = 0;
  while (*p && *p != '"' && w + 1 < n) out[w++] = *p++;
  out[w] = '\0';
  return w > 0;
}

// `"forget":true` — a bare literal, not a quoted string, so jsonStr cannot
// find it. Deliberately strict: only the exact literal counts, because the
// thing on the other end of a loose match is the destruction of the bond.
static bool jsonBool(const char *s, const char *key) {
  const char *p = strstr(s, key);
  if (!p) return false;
  p = strchr(p + strlen(key), ':');
  if (!p) return false;
  ++p;
  while (*p == ' ') ++p;
  return strncmp(p, "true", 4) == 0;
}

static void buildStatus(char *out, size_t n) {
  // `authed` is what the app reads to find out whether it still has to
  // present itself. It used to infer that from the read SUCCEEDING, which it
  // always does — this characteristic is deliberately ungated so that an
  // unauthenticated phone can learn it is unauthenticated.
  snprintf(out, n,
           "{\"pending\":%u,\"paired\":%s,\"authed\":%s,\"owned\":%s,"
           "\"device\":\"%s\",\"battery\":%d,\"clock\":%lu}",
           (unsigned)(g_store ? g_store->pending() : 0),
           (g_model && g_model->paired) ? "true" : "false",
           g_authed ? "true" : "false", hasOwner() ? "true" : "false",
           deviceId(), (g_battery == 0xFF) ? -1 : (int)g_battery, 0UL);
}

static void pushStatus() {
  if (!g_status) return;
  char buf[128];
  buildStatus(buf, sizeof(buf));
  g_status->setValue((uint8_t *)buf, strlen(buf));
  if (g_connected) g_status->notify();
}

static void statusError(const char *code) {
  if (!g_status || !g_connected) return;
  char buf[64];
  snprintf(buf, sizeof(buf), "{\"error\":\"%s\"}", code);
  g_status->setValue((uint8_t *)buf, strlen(buf));
  g_status->notify();
}

// Advertise the pending count so the phone can decide whether to wake at all.
static void refreshAdvert(bool force = false) {
  const uint8_t pending = g_store ? g_store->pending() : 0;
  const uint8_t flags   = (uint8_t)(((g_model && g_model->paired) ? 0x01 : 0)
                                  | (hasOwner() ? 0x02 : 0));
  if (!force && pending == g_advPending && flags == g_advFlags &&
      g_battery == g_advBattery) {
    return;
  }
  g_advPending = pending;
  g_advFlags   = flags;
  g_advBattery = g_battery;

  NimBLEAdvertising *adv = NimBLEDevice::getAdvertising();
  adv->stop();

  // 0xFFFF is the "no company" identifier, then our four bytes. The id goes
  // out unconnected so the app can name each Jota in a scan list — "which of
  // these two is mine" has to be answerable before you connect to one.
  const uint16_t id    = deviceIdShort();
  uint8_t        md[7] = {0xFF,          0xFF,
                          pending,       flags,
                          (uint8_t)(id >> 8), (uint8_t)(id & 0xFF),
                          g_battery};
  adv->setManufacturerData(std::string((char *)md, sizeof(md)));
  adv->start();
}

// ---- Callbacks -----------------------------------------------------------

class ServerCB : public NimBLEServerCallbacks {
  void onConnect(NimBLEServer *s, ble_gap_conn_desc *desc) override {
    Serial.println("[ble] connected");
    g_connected = true;
    g_conn      = desc->conn_handle;
    g_mtu       = s->getPeerMTU(g_conn);
    g_authed    = false;      // every connection re-authenticates
    g_xfer.active = false;
  }
  void onDisconnect(NimBLEServer *s) override {
    Serial.println("[ble] disconnected");
    g_connected   = false;
    g_authed      = false;
    if (g_model) g_model->authed = false;
    // An interrupted transfer is simply abandoned. The note was never acked,
    // so it stays pending and the advert keeps calling the phone back; it
    // will resume with a byte offset rather than starting over.
    g_xfer.active = false;
    refreshAdvert(/*force=*/true);
  }
  void onMTUChange(uint16_t mtu, ble_gap_conn_desc *desc) override {
    g_mtu = mtu;
  }
};

static void grantAuth() {
  g_authed    = true;
  g_authFails = 0;
  if (g_model) {
    g_model->paired = true;
    g_model->authed = true;
  }
  pushStatus();
  refreshAdvert();
}

class AuthCB : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic *c) override {
    const std::string v = c->getValue();

    char appId[APP_ID_MAX];
    jsonStr(v.c_str(), "\"app\"", appId, sizeof(appId));

    // The owner reconnecting. No code, no prompt, no e-paper — this is the
    // whole point of the bond, and what stops every single sync from
    // demanding six digits off a device that may be in another room.
    if (isOwner(appId)) {
      // "Forget this phone", asked for by the phone that IS the owner. That is
      // the only party entitled to ask, which is why it rides on `auth` rather
      // than a characteristic anyone could write.
      //
      // Without this, forgetting a Jota in the app forgot nothing on the Jota:
      // the app id it minted at install never changes, so the very next
      // connection matched the stored owner and authenticated silently. A
      // person who "unpaired" in order to hand the device on had done nothing
      // at all.
      if (jsonBool(v.c_str(), "\"forget\"")) {
        Serial.println("[ble] owner asked to be forgotten — bond cleared");
        clearOwner();
        g_authed = false;
        if (g_model) {
          g_model->paired = false;
          g_model->authed = false;
        }
        pushStatus();
        refreshAdvert();
        return;
      }
      grantAuth();
      return;
    }

    char code[16];
    jsonStr(v.c_str(), "\"code\"", code, sizeof(code));

    char given[8], want[8];
    digitsOnly(code, given, sizeof(given));
    digitsOnly(g_pairCode, want, sizeof(want));

    // A correct code takes ownership, even from an existing owner. Possession
    // of the device outranks the stored bond by design: possession IS the
    // security model, so a Jota that could lock out the person holding it
    // would be worse, not better.
    Serial.printf("[ble] auth: given='%s' want='%s' owner=%s\n",
                  given, want, hasOwner() ? "yes" : "no");

    if (want[0] && strcmp(given, want) == 0) {
      if (appId[0]) setOwner(appId);
      grantAuth();
      return;
    }

    // No code offered at all. That is a phone introducing itself, not a wrong
    // guess, so it must not burn one of the three attempts — otherwise an app
    // that simply is not the owner would lock the device out of the air in
    // three reconnects.
    if (!given[0]) {
      // A phone introducing itself and not recognised. Put the code up so the
      // person holding the device can read it out — that IS the handshake.
      if (g_model && hasOwner()) {
        g_model->pairAsked = true;
        Serial.println("[ble] stranger knocked — offering the code");
      }
      statusError(hasOwner() ? "owner" : "auth");
      return;
    }

    // A code offered while the device has published none is not a wrong
    // guess — there was nothing to guess. Ask for the offer to open and let
    // the phone try again against a real code. Counting this burned attempts
    // on the ONE path a legitimate user takes: type the digits a moment before
    // the panel has published them and three tries later the device stops
    // advertising for thirty seconds.
    if (!want[0]) {
      if (g_model) g_model->pairAsked = true;
      statusError("nocode");
      return;
    }
    Serial.printf("[ble] auth REFUSED (%u/%u)\n",
                  (unsigned)(g_authFails + 1), (unsigned)MAX_AUTH_FAIL);
    if (++g_authFails >= MAX_AUTH_FAIL) {
      Serial.println("[ble] too many attempts — advertising off for 30s");
      g_lockUntil = millis() + LOCKOUT_MS;
      NimBLEDevice::getAdvertising()->stop();
      if (g_connected) NimBLEDevice::getServer()->disconnect(g_conn);
    }
    statusError("auth");
  }
};

class IndexCB : public NimBLECharacteristicCallbacks {
  void onRead(NimBLECharacteristic *c) override {
    // An empty index on an unauthenticated read is the defect the whole bond
    // rewrite exists to prevent looking like success — so say which it was.
    if (!g_authed || !g_store) {
      Serial.println("[ble] index read while NOT authed -> []");
      c->setValue("[]");
      return;
    }
    Serial.printf("[ble] index read, %u pending\n",
                  (unsigned)g_store->pending());
    diagCountSync();
    char buf[512];
    const size_t n = g_store->indexJson(buf, sizeof(buf));
    // The exact bytes the phone receives. A malformed or unexpected index is
    // indistinguishable on the phone from "nothing to sync" — which is the
    // shape of the original bug this whole contract was rewritten to kill.
    Serial.printf("[ble] index (%u bytes): %.*s\n", (unsigned)n, (int)n, buf);
    c->setValue((uint8_t *)buf, n);
  }
};

class StatusCB : public NimBLECharacteristicCallbacks {
  void onRead(NimBLECharacteristic *c) override {
    char buf[128];
    buildStatus(buf, sizeof(buf));
    c->setValue((uint8_t *)buf, strlen(buf));
  }
};

// Very small hand-rolled field readers — pulling in a JSON parser for two
// integers is not worth the flash.
static bool jsonUint(const char *s, const char *key, uint32_t *out) {
  const char *p = strstr(s, key);
  if (!p) return false;
  p = strchr(p, ':');
  if (!p) return false;
  *out = (uint32_t)strtoul(p + 1, nullptr, 10);
  return true;
}
static bool jsonHex(const char *s, const char *key, uint32_t *out) {
  const char *p = strstr(s, key);
  if (!p) return false;
  p = strchr(p, ':');
  if (!p) return false;
  p = strchr(p, '"');
  if (!p) return false;
  *out = (uint32_t)strtoul(p + 1, nullptr, 16);
  return true;
}

class FetchCB : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic *c) override {
    if (!g_authed || !g_store) {
      Serial.println("[ble] fetch while NOT authed — ignored");
      return;
    }
    const std::string v = c->getValue();
    uint32_t id = 0, off = 0;
    if (!jsonUint(v.c_str(), "\"id\"", &id)) return;
    jsonUint(v.c_str(), "\"offset\"", &off);   // absent means 0

    // Probe the range before committing, so a bad request answers cleanly
    // instead of streaming nothing.
    uint8_t probe;
    if (g_store->read((uint16_t)id, off, &probe, 1) == 0) {
      statusError("range");
      return;
    }
    g_xfer.active = true;
    g_xfer.id     = (uint16_t)id;
    g_xfer.offset = off;
  }
};

class AckCB : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic *c) override {
    Serial.println("[ble] ack");
    if (!g_authed || !g_store) return;
    const std::string v = c->getValue();
    uint32_t id = 0, crc = 0;
    if (!jsonUint(v.c_str(), "\"id\"", &id)) return;
    if (!jsonHex(v.c_str(), "\"crc\"", &crc)) return;

    // Only a matching CRC retires a note. A truncated transfer must never be
    // mistaken for a complete one.
    if (!g_store->ack((uint16_t)id, crc)) {
      statusError("crc");
      return;
    }
    if (g_model && g_model->pending) g_model->pending--;
    pushStatus();
    refreshAdvert();
  }
};

// Persisted so the list survives a power cycle — "Jota stores it". Without
// this every reboot silently reverted to the factory five, and the app, which
// believes the device already has its list, had no reason to write again.
static void tagsSave(const TagList &t) {
  char         buf[TAGS_JSON_MAX];
  const size_t n = tagsToJson(t, buf, sizeof(buf));
  g_prefs.begin("jota", /*readOnly=*/false);
  g_prefs.putBytes("tags", buf, n);
  g_prefs.end();
}

static bool tagsLoad(TagList &t) {
  g_prefs.begin("jota", /*readOnly=*/true);
  char         buf[TAGS_JSON_MAX] = {0};
  const size_t n = g_prefs.getBytes("tags", buf, sizeof(buf) - 1);
  g_prefs.end();
  if (n == 0) return false;
  buf[n] = '\0';
  return tagsParseJson(buf, t);
}

class TagsCB : public NimBLECharacteristicCallbacks {
  void onRead(NimBLECharacteristic *c) override {
    // Serialised from the model, so what the phone reads back is exactly what
    // the panel is showing — one source of truth, not two.
    char buf[TAGS_JSON_MAX];
    if (g_model && tagsToJson(g_model->tags, buf, sizeof(buf)) > 0) {
      c->setValue((uint8_t *)buf, strlen(buf));
    } else {
      c->setValue("[]");
    }
  }
  void onWrite(NimBLECharacteristic *c) override {
    // A dropped write used to be indistinguishable from a stored one: the
    // characteristic still acks, so the phone reported success either way.
    // Say what happened instead.
    if (!g_authed) {
      statusError("auth");
      return;
    }
    const std::string v = c->getValue();
    if (v.size() >= sizeof(g_tagsPending)) {
      statusError("tags");
      return;
    }
    memcpy(g_tagsPending, v.data(), v.size());
    g_tagsPending[v.size()] = '\0';
    g_tagsDirty             = true;
  }
};

class DiagCB : public NimBLECharacteristicCallbacks {
  void onRead(NimBLECharacteristic *c) override {
    // Gated like `index`: what a device has been through is the owner's
    // business, not the room's.
    if (!g_authed) {
      c->setValue("{}");
      return;
    }
    char buf[192];
    const size_t n = diagJson(buf, sizeof(buf));
    c->setValue((uint8_t *)buf, n);
  }
};

class EraseCB : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic *c) override {
    // Owner only. `authed` implies owner here — a code-holder became the
    // owner the moment auth passed — but say which refusal it was.
    if (!g_authed) {
      statusError("auth");
      return;
    }
    // The request must echo this device's own id. A stray or replayed write
    // aimed at the wrong Jota then does nothing, the same reason the ack
    // must echo a CRC.
    char confirm[16];
    jsonStr(c->getValue().c_str(), "\"confirm\"", confirm, sizeof(confirm));
    if (strcmp(confirm, deviceId()) != 0) {
      Serial.printf("[ble] erase refused: confirm '%s' is not '%s'\n",
                    confirm, deviceId());
      statusError("confirm");
      return;
    }
    Serial.println("[ble] owner asked for an erase");
    // The wipe runs from main's loop: deleting every note is seconds of file
    // I/O, far more than a callback on the host stack's task may spend.
    g_eraseAsked = true;
  }
};

class ClockCB : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic *c) override {
    if (!g_authed || !g_store) return;
    // Jota has no network, so the phone is its only time source.
    const uint32_t t = (uint32_t)strtoul(c->getValue().c_str(), nullptr, 10);
    if (t > CLOCK_SANE_AFTER) {
      clockSet(t);           // from now on notes are stamped as they are made
      g_store->setClock(t);  // and the ones made before this connect get now
    }
  }
};

// ---- Link ----------------------------------------------------------------

void Link::begin(NoteStore &store, AppModel &model) {
  g_store = &store;
  g_model = &model;

  // This board's id, and the phone that owns it if there is one.
  identityBegin();
  g_model->deviceId = deviceId();
  g_model->paired   = hasOwner();

  // Whatever the phone last wrote, or the factory list if it never has.
  if (!tagsLoad(g_model->tags)) tagsSetDefaults(g_model->tags);

  NimBLEDevice::init("JOTA");
  NimBLEDevice::setMTU(247);

  NimBLEServer *server = NimBLEDevice::createServer();
  server->setCallbacks(new ServerCB());

  NimBLEService *svc = server->createService(NimBLEUUID(SVC_UUID));

  svc->createCharacteristic(NimBLEUUID(CH_AUTH), NIMBLE_PROPERTY::WRITE)
      ->setCallbacks(new AuthCB());

  g_status = svc->createCharacteristic(
      NimBLEUUID(CH_STATUS), NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY);
  g_status->setCallbacks(new StatusCB());

  g_index = svc->createCharacteristic(NimBLEUUID(CH_INDEX),
                                      NIMBLE_PROPERTY::READ);
  g_index->setCallbacks(new IndexCB());

  svc->createCharacteristic(NimBLEUUID(CH_FETCH), NIMBLE_PROPERTY::WRITE)
      ->setCallbacks(new FetchCB());

  g_data = svc->createCharacteristic(NimBLEUUID(CH_DATA),
                                     NIMBLE_PROPERTY::NOTIFY);

  svc->createCharacteristic(NimBLEUUID(CH_ACK), NIMBLE_PROPERTY::WRITE)
      ->setCallbacks(new AckCB());

  svc->createCharacteristic(NimBLEUUID(CH_TAGS),
                            NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::WRITE)
      ->setCallbacks(new TagsCB());

  svc->createCharacteristic(NimBLEUUID(CH_CLOCK), NIMBLE_PROPERTY::WRITE)
      ->setCallbacks(new ClockCB());

  svc->createCharacteristic(NimBLEUUID(CH_DIAG), NIMBLE_PROPERTY::READ)
      ->setCallbacks(new DiagCB());

  svc->createCharacteristic(NimBLEUUID(CH_ERASE), NIMBLE_PROPERTY::WRITE)
      ->setCallbacks(new EraseCB());

  svc->start();

  NimBLEAdvertising *adv = NimBLEDevice::getAdvertising();
  adv->addServiceUUID(NimBLEUUID(SVC_UUID));
  adv->setScanResponse(true);
  refreshAdvert(/*force=*/true);
}

void Link::setBattery(uint8_t pct) {
  g_battery = (pct > 100 && pct != 0xFF) ? 100 : pct;
}

// Six random digits, from the hardware RNG.
//
// This replaces a constant that was compiled into every Jota ever built:
// "428 913", the same on every unit, sitting in nav.cpp where anyone reading
// the source could find it. A code every device shares is not a secret, and it
// made the entire security model a decoration — the whole premise is that
// holding the device is what proves you may pair with it, and a shared
// constant means you never need to hold anything.
const char *Link::newPairCode() {
  uint32_t n = esp_random() % 1000000u;
  snprintf(g_pairCode, sizeof(g_pairCode), "%06u", (unsigned)n);
  return g_pairCode;
}

void Link::clearPairCode() { g_pairCode[0] = '\0'; }

bool Link::hasOwner() const { return ::jota::hasOwner(); }

void Link::setPairCode(const char *code) {
  if (!code) {
    g_pairCode[0] = '\0';
    return;
  }
  digitsOnly(code, g_pairCode, sizeof(g_pairCode));
}

bool Link::connected() const { return g_connected; }
bool Link::authed() const { return g_authed; }

bool Link::takeEraseRequested() {
  const bool v = g_eraseAsked;
  g_eraseAsked = false;
  return v;
}

void Link::confirmErased() { statusError("erased"); }

bool Link::takeTagsChanged() {
  const bool v  = g_tagsChanged;
  g_tagsChanged = false;
  return v;
}

void Link::nudge(uint32_t nowMs) {
  g_fastUntil = nowMs + ADV_FAST_MS;
  NimBLEAdvertising *adv = NimBLEDevice::getAdvertising();
  adv->stop();
  adv->setMinInterval(32);   // 20 ms
  adv->setMaxInterval(64);   // 40 ms
  adv->start();
}

void Link::forgetOwner() {
  clearOwner();
  // Also drop THIS connection's authentication. Leaving it standing would let
  // the phone that just asked for an erase keep reading the device it no
  // longer owns, until it happened to disconnect.
  g_authed = false;
  if (g_model) {
    g_model->paired = false;
    g_model->authed = false;
  }
  // Re-advertise so the "owned" flag in the advertisement stops claiming a
  // bond that no longer exists — otherwise a scanning phone would keep being
  // told to expect a silent reconnect.
  NimBLEAdvertising *adv = NimBLEDevice::getAdvertising();
  adv->stop();
  adv->start();
}

void Link::loop(uint32_t nowMs) {
  // ADVERTISING WATCHDOG.
  //
  // The device stopped advertising after its first connection and never came
  // back — invisible to the phone AND to a laptop scanner, until a reset. A
  // peripheral that has gone quiet is, for this product, simply dead: the whole
  // sync model is "the device calls the phone", so if the advert stops, notes
  // sit on it forever and nothing on either screen says why.
  //
  // Rather than chase which of NimBLE's paths dropped it — restarting from
  // inside the disconnect callback is a known way to lose the race, and the
  // lockout path stops it deliberately — this asserts the invariant every
  // loop: if nobody is connected and we are not deliberately locked out, we
  // MUST be advertising. Cheap to check, and it cannot be defeated by whatever
  // else goes wrong.
  if (!g_connected && !g_lockUntil) {
    NimBLEAdvertising *adv = NimBLEDevice::getAdvertising();
    if (!adv->isAdvertising()) {
      Serial.println("[ble] advert had stopped — restarting");
      adv->start();
    }
  }

  if (g_lockUntil && nowMs > g_lockUntil) {
    Serial.println("[ble] lockout over");
    g_lockUntil = 0;
    g_authFails = 0;
    refreshAdvert(/*force=*/true);
  }

  if (g_fastUntil && nowMs > g_fastUntil) {
    g_fastUntil = 0;
    NimBLEAdvertising *adv = NimBLEDevice::getAdvertising();
    adv->stop();
    adv->setMinInterval(1600);  // 1 s — quiet, and cheap on battery
    adv->setMaxInterval(3200);  // 2 s
    adv->start();
  }

  refreshAdvert();

  // Apply a pending tag write. Deferred out of the callback because both the
  // parse and the NVS commit are slow enough to stall the host stack's task.
  if (g_tagsDirty) {
    g_tagsDirty = false;
    if (g_model && tagsParseJson(g_tagsPending, g_model->tags)) {
      // A shorter list must not leave the cursor pointing off the end.
      if (g_model->tagSel >= g_model->tags.count) {
        g_model->tagSel =
            g_model->tags.count ? (uint8_t)(g_model->tags.count - 1) : 0;
      }
      tagsSave(g_model->tags);
      g_tagsChanged = true;
      pushStatus();
    } else {
      statusError("tags");
    }
  }

  // Pump the transfer here, never from a callback: callbacks run on the host
  // stack's task and must return promptly.
  if (g_xfer.active && g_connected && g_data && g_store) {
    size_t chunk = (g_mtu > 3) ? (size_t)(g_mtu - 3) : 20;
    if (chunk > 244) chunk = 244;

    for (uint8_t i = 0; i < CHUNKS_PER_LOOP && g_xfer.active; ++i) {
      uint8_t buf[244];
      const size_t n = g_store->read(g_xfer.id, g_xfer.offset, buf, chunk);
      if (n == 0) {                       // reached the end
        Serial.printf("[ble] fetch done: id=%u sent=%u bytes\n",
                      (unsigned)g_xfer.id, (unsigned)g_xfer.offset);
        g_xfer.active = false;
        break;
      }

      // Notify by hand rather than through NimBLECharacteristic::notify().
      //
      // That helper returns void and DISCARDS the result of both steps below:
      // when the host's mbuf pool runs dry it hands ble_gattc_notify_custom a
      // null buffer and the chunk simply disappears. Nothing tells the app,
      // which then waits for bytes that were never sent. That is exactly what
      // this looked like from the other end — a note arriving 90% complete and
      // the transfer stopping dead.
      //
      // The loop is thousands of times faster than the radio, which drains
      // only a handful of packets per connection interval, so the pool WILL
      // run dry on every transfer. It is a normal condition, not an error.
      // The fix is to notice it: leave the offset where it is and try the same
      // chunk on the next pass, once the radio has made room.
      os_mbuf *om = ble_hs_mbuf_from_flat(buf, n);
      if (om == nullptr) break;           // pool empty — same chunk, next pass
      if (ble_gattc_notify_custom(g_conn, g_data->getHandle(), om) != 0) {
        break;                            // the stack owns om either way
      }
      g_xfer.offset += n;
    }
  }
}

}  // namespace jota
