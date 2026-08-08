// ============================================================================
//  Jota — CRC32 (IEEE 802.3, reflected)
//
//  The only thing standing between a truncated BLE transfer and a corrupt note
//  in the archive. ble-service.md: "trust only the CRC", and "Jota only marks a
//  note synced when it receives a valid ack" — so the app must never write an
//  `ack` it has not earned.
//
//  Polynomial 0xEDB88320 (reflected 0x04C11DB7), init 0xFFFFFFFF, final xor
//  0xFFFFFFFF. The same CRC-32 as zlib, PNG and zip.
// ============================================================================
import 'dart:typed_data';

class Crc32 {
  Crc32();

  static final Uint32List _table = _buildTable();

  static Uint32List _buildTable() {
    final Uint32List t = Uint32List(256);
    for (int i = 0; i < 256; i++) {
      int c = i;
      for (int k = 0; k < 8; k++) {
        c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
      }
      t[i] = c;
    }
    return t;
  }

  int _crc = 0xFFFFFFFF;

  /// Feed a chunk. Safe to call incrementally as `data` notifications arrive,
  /// which is what lets a 480 KB note be verified without ever holding a second
  /// copy of it just to checksum.
  void update(List<int> bytes) {
    int c = _crc;
    for (int i = 0; i < bytes.length; i++) {
      c = _table[(c ^ bytes[i]) & 0xFF] ^ (c >> 8);
    }
    _crc = c;
  }

  /// The running value, finalised. Does not consume the accumulator, so a
  /// resumed transfer can keep feeding after a checkpoint.
  int get value => (_crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;

  void reset() => _crc = 0xFFFFFFFF;

  /// One-shot over a whole buffer.
  static int compute(List<int> bytes) {
    final Crc32 c = Crc32();
    c.update(bytes);
    return c.value;
  }

  /// The protocol carries the CRC as eight lowercase hex digits in JSON:
  ///   {"id":12,"crc":"a1b2c3d4"}
  /// Compared case-insensitively and zero-padded, because a device that emits
  /// "a1b2c3d" for a value with a leading zero should still match.
  static String toHex(int crc) =>
      (crc & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');

  static bool matches(int computed, String expectedHex) {
    final String a = toHex(computed);
    final String b = expectedHex.trim().toLowerCase().padLeft(8, '0');
    return a == b;
  }
}
