// ============================================================================
//  Jota — identity and the owner bond (implementation)
// ============================================================================
#include "app/identity.h"

#include <Arduino.h>
#include <Preferences.h>
#include <esp_system.h>

#include <stdio.h>
#include <string.h>

namespace jota {

static char g_deviceId[9]           = {0};
static char g_ownerAppId[APP_ID_MAX] = {0};

void identityBegin() {
  // The efuse MAC is unique per board and read-only, so the device id needs no
  // provisioning step and survives a reflash — an id stored in NVS would be
  // lost by an erase and the phone's bond would break for no reason.
  uint8_t mac[6] = {0};
  esp_efuse_mac_get_default(mac);
  snprintf(g_deviceId, sizeof(g_deviceId), "%02x%02x%02x%02x", mac[2], mac[3],
           mac[4], mac[5]);

  Preferences prefs;
  prefs.begin("jota", /*readOnly=*/true);
  const size_t n =
      prefs.getBytes("owner", g_ownerAppId, sizeof(g_ownerAppId) - 1);
  prefs.end();
  g_ownerAppId[n] = '\0';
}

const char *deviceId() { return g_deviceId; }

uint16_t deviceIdShort() {
  // The last four hex characters — the same four the panel shows.
  return (uint16_t)strtoul(g_deviceId + 4, nullptr, 16);
}

const char *ownerAppId() { return g_ownerAppId; }

bool hasOwner() { return g_ownerAppId[0] != '\0'; }

bool isOwner(const char *appId) {
  if (!appId || !appId[0] || !hasOwner()) return false;
  return strcmp(appId, g_ownerAppId) == 0;
}

void setOwner(const char *appId) {
  if (!appId) return;
  snprintf(g_ownerAppId, sizeof(g_ownerAppId), "%s", appId);

  Preferences prefs;
  prefs.begin("jota", /*readOnly=*/false);
  prefs.putBytes("owner", g_ownerAppId, strlen(g_ownerAppId));
  prefs.end();
}

void clearOwner() {
  g_ownerAppId[0] = '\0';

  Preferences prefs;
  prefs.begin("jota", /*readOnly=*/false);
  // remove(), not an empty putBytes: a zero-length value still leaves the key
  // present, and hasOwner() would keep answering yes on the next boot.
  prefs.remove("owner");
  prefs.end();
}

}  // namespace jota
