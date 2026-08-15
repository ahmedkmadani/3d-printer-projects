// ============================================================================
//  Jota — the tag list (implementation)
//
//  The parser is hand-rolled in the same spirit as the field readers in
//  link/ble.cpp: a JSON library for one array of short strings is not worth
//  the flash.
// ============================================================================
#include "app/tags.h"

#include <stdio.h>
#include <string.h>

namespace jota {

void tagsSetDefaults(TagList &t) {
  // Three, not eight. A device out of the box should offer a decision that can
  // be made in a second, and these three cover most of what a voice note is
  // for. The phone ships with the SAME three (see kDefaultTags in the app), so
  // an unpaired Jota and a fresh install already agree before they ever meet.
  static const char *const kDefaults[] = {"WORK", "PERSONAL", "IDEAS"};
  static const uint8_t     kCount      = 3;

  t = TagList{};
  for (uint8_t i = 0; i < kCount; ++i) {
    snprintf(t.items[i], sizeof(t.items[i]), "%s", kDefaults[i]);
  }
  t.count = kCount;
}

const char *tagAt(const TagList &t, uint8_t index) {
  if (index == TAG_NONE || index >= t.count) return nullptr;
  return t.items[index];
}

bool tagsParseJson(const char *json, TagList &t) {
  if (!json) return false;

  const char *p = json;
  while (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r') ++p;
  if (*p != '[') return false;  // not an array — refuse rather than clear
  ++p;

  TagList out = TagList{};

  while (*p && *p != ']') {
    if (*p != '"') {
      ++p;
      continue;
    }
    ++p;  // past the opening quote

    char   buf[TAG_LEN_MAX + 1];
    size_t n = 0;
    while (*p && *p != '"') {
      char c = *p++;
      if (c == '\\' && *p) c = *p++;      // one level of escape is enough
      if (n < TAG_LEN_MAX) buf[n++] = c;  // over-long tags truncate, exactly
    }                                     // as the app clamps them
    buf[n] = '\0';
    if (*p == '"') ++p;

    // An empty string would draw as a blank row, so it is not a tag.
    if (n > 0 && out.count < TAGS_MAX) {
      memcpy(out.items[out.count], buf, n + 1);
      out.count++;
    }
  }

  t = out;
  return true;
}

size_t tagsToJson(const TagList &t, char *out, size_t n) {
  if (!out || n == 0) return 0;

  size_t w    = 0;
  out[w++]    = '[';
  const uint8_t count = (t.count > TAGS_MAX) ? TAGS_MAX : t.count;

  for (uint8_t i = 0; i < count; ++i) {
    const size_t len = strlen(t.items[i]);
    // comma + two quotes + the tag + the closing bracket + NUL
    if (w + len + 4 >= n) break;
    if (i) out[w++] = ',';
    out[w++] = '"';
    memcpy(out + w, t.items[i], len);
    w += len;
    out[w++] = '"';
  }

  out[w++] = ']';
  out[w]   = '\0';
  return w;
}

uint8_t tagsWindow(const TagList &t, uint8_t sel, uint8_t max, uint8_t *first,
                   uint8_t *selInWindow) {
  uint8_t f = 0;
  if (t.count > max && sel >= max) {
    // Scroll only as far as it takes to bring the selection into view, so the
    // list stays put until the cursor actually reaches the bottom edge.
    f = (uint8_t)(sel - max + 1);
  }
  const uint8_t rows = (uint8_t)((t.count - f) > max ? max : (t.count - f));
  if (first) *first = f;
  if (selInWindow) *selInWindow = (uint8_t)(sel - f);
  return rows;
}

}  // namespace jota
