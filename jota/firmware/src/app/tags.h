// ============================================================================
//  Jota — the tag list
//
//  The phone owns the tags (docs/ble-service.md): it writes the whole list and
//  Jota shows it. The list lives here, in the model, rather than inside the BLE
//  layer — when the two were separate, `tags` writes landed in a buffer that
//  nothing ever drew, so the TAGS screen could never change.
//
//  Free of Arduino and of NimBLE so the host UI preview links it.
// ============================================================================
#pragma once

#include <stddef.h>
#include <stdint.h>

namespace jota {

// The contract's ceiling: "Max 8 tags, 12 characters each".
static const uint8_t TAGS_MAX    = 8;
static const uint8_t TAG_LEN_MAX = 12;

// No tag armed. Deliberately not 0 — that is a valid tag index.
static const uint8_t TAG_NONE = 0xFF;

struct TagList {
  char    items[TAGS_MAX][TAG_LEN_MAX + 1];
  uint8_t count;
};

// The tag at [index], or nullptr for TAG_NONE or an index past the end — which
// happens for real whenever the phone writes a shorter list than the one the
// armed index was chosen from.
const char *tagAt(const TagList &t, uint8_t index);

// What a Jota shows before a phone has ever written to it.
void tagsSetDefaults(TagList &t);

// Replace the whole list from the `tags` payload — a JSON array of strings.
//
// Returns false and leaves [t] untouched when the payload is not an array, so
// a garbled write cannot silently empty the list. An explicit `[]` IS accepted:
// clearing every tag is a legitimate edit, and the screen has a state for it.
bool tagsParseJson(const char *json, TagList &t);

// Serialise back to the same JSON for the characteristic's read. Returns the
// number of bytes written, never more than n-1.
size_t tagsToJson(const TagList &t, char *out, size_t n);

// The window of up to [max] rows that keeps [sel] visible, for a list taller
// than the panel. Writes the first visible index to [first] and the selection's
// position within the window to [selInWindow], and returns how many rows to
// draw.
uint8_t tagsWindow(const TagList &t, uint8_t sel, uint8_t max, uint8_t *first,
                   uint8_t *selInWindow);

}  // namespace jota
