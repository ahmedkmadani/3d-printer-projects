// ============================================================================
//  Jota — BLE link (implementation)
//  Contract: docs/ble-service.md
// ============================================================================
#include "link/ble.h"

#include <NimBLEDevice.h>

#include <stdio.h>
#include <string.h>

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
static char     g_pairCode[8] = {0};

static char g_tags[160] =
    "[\"WORK\",\"HOME\",\"IDEA\",\"BUY\",\"LATER\"]";

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

static void buildStatus(char *out, size_t n) {
  snprintf(out, n,
           "{\"pending\":%u,\"paired\":%s,\"authed\":%s,\"clock\":%lu}",
           (unsigned)(g_store ? g_store->pending() : 0),
           (g_model && g_model->paired) ? "true" : "false",
           g_authed ? "true" : "false", 0UL);
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
  if (!force && pending == g_advPending) return;
  g_advPending = pending;

  NimBLEAdvertising *adv = NimBLEDevice::getAdvertising();
  adv->stop();

  // 0xFFFF is the "no company" identifier, then our two bytes.
  uint8_t md[4] = {0xFF, 0xFF, pending,
                   (uint8_t)((g_model && g_model->paired) ? 0x01 : 0x00)};
  adv->setManufacturerData(std::string((char *)md, sizeof(md)));
  adv->start();
}

// ---- Callbacks -----------------------------------------------------------

class ServerCB : public NimBLEServerCallbacks {
  void onConnect(NimBLEServer *s, ble_gap_conn_desc *desc) override {
    g_connected = true;
    g_conn      = desc->conn_handle;
    g_mtu       = s->getPeerMTU(g_conn);
    g_authed    = false;      // every connection re-authenticates
    g_xfer.active = false;
  }
  void onDisconnect(NimBLEServer *s) override {
    g_connected   = false;
    g_authed      = false;
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

class AuthCB : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic *c) override {
    char given[8], want[8];
    digitsOnly(c->getValue().c_str(), given, sizeof(given));
    digitsOnly(g_pairCode, want, sizeof(want));

    if (want[0] && strcmp(given, want) == 0) {
      g_authed    = true;
      g_authFails = 0;
      if (g_model) g_model->paired = true;
      pushStatus();
      return;
    }
    if (++g_authFails >= MAX_AUTH_FAIL) {
      g_lockUntil = millis() + LOCKOUT_MS;
      NimBLEDevice::getAdvertising()->stop();
      if (g_connected) NimBLEDevice::getServer()->disconnect(g_conn);
    }
    statusError("auth");
  }
};

class IndexCB : public NimBLECharacteristicCallbacks {
  void onRead(NimBLECharacteristic *c) override {
    if (!g_authed || !g_store) {
      c->setValue("[]");
      return;
    }
    char buf[512];
    const size_t n = g_store->indexJson(buf, sizeof(buf));
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
    if (!g_authed || !g_store) return;
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

class TagsCB : public NimBLECharacteristicCallbacks {
  void onRead(NimBLECharacteristic *c) override {
    c->setValue((uint8_t *)g_tags, strlen(g_tags));
  }
  void onWrite(NimBLECharacteristic *c) override {
    if (!g_authed) return;
    const std::string v = c->getValue();
    if (v.size() >= sizeof(g_tags)) return;
    memcpy(g_tags, v.data(), v.size());
    g_tags[v.size()] = '\0';
  }
};

class ClockCB : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic *c) override {
    if (!g_authed || !g_store) return;
    // Jota has no network, so the phone is its only time source.
    const uint32_t t = (uint32_t)strtoul(c->getValue().c_str(), nullptr, 10);
    if (t > 1600000000UL) g_store->setClock(t);
  }
};

// ---- Link ----------------------------------------------------------------

void Link::begin(NoteStore &store, AppModel &model) {
  g_store = &store;
  g_model = &model;

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

  svc->start();

  NimBLEAdvertising *adv = NimBLEDevice::getAdvertising();
  adv->addServiceUUID(NimBLEUUID(SVC_UUID));
  adv->setScanResponse(true);
  refreshAdvert(/*force=*/true);
}

void Link::setPairCode(const char *code) {
  if (!code) {
    g_pairCode[0] = '\0';
    return;
  }
  digitsOnly(code, g_pairCode, sizeof(g_pairCode));
}

bool Link::connected() const { return g_connected; }
bool Link::authed() const { return g_authed; }

void Link::nudge(uint32_t nowMs) {
  g_fastUntil = nowMs + ADV_FAST_MS;
  NimBLEAdvertising *adv = NimBLEDevice::getAdvertising();
  adv->stop();
  adv->setMinInterval(32);   // 20 ms
  adv->setMaxInterval(64);   // 40 ms
  adv->start();
}

void Link::loop(uint32_t nowMs) {
  if (g_lockUntil && nowMs > g_lockUntil) {
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

  // Pump the transfer here, never from a callback: callbacks run on the host
  // stack's task and must return promptly.
  if (g_xfer.active && g_connected && g_data && g_store) {
    size_t chunk = (g_mtu > 3) ? (size_t)(g_mtu - 3) : 20;
    if (chunk > 244) chunk = 244;

    for (uint8_t i = 0; i < CHUNKS_PER_LOOP && g_xfer.active; ++i) {
      uint8_t buf[244];
      const size_t n = g_store->read(g_xfer.id, g_xfer.offset, buf, chunk);
      if (n == 0) {                       // reached the end
        g_xfer.active = false;
        break;
      }
      g_data->setValue(buf, n);
      g_data->notify();                   // 1.x returns void; the stack queues
      g_xfer.offset += n;
    }
  }
}

}  // namespace jota
