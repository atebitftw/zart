import 'dart:typed_data';

/// Utility for TADS3 UTF-8 decoding.
class T3Utf8 {
  /// Decodes UTF-8 bytes to a string.
  static String decode(Uint8List bytes) {
    final codeUnits = <int>[];
    var i = 0;

    while (i < bytes.length) {
      final b = bytes[i];
      if ((b & 0x80) == 0) {
        // Single byte character (0x00-0x7F)
        codeUnits.add(b);
        i++;
      } else if ((b & 0xE0) == 0xC0) {
        // Two byte character (0x80-0x7FF)
        if (i + 1 >= bytes.length) break;
        final c = ((b & 0x1F) << 6) | (bytes[i + 1] & 0x3F);
        codeUnits.add(c);
        i += 2;
      } else if ((b & 0xF0) == 0xE0) {
        // Three byte character (0x800-0xFFFF)
        if (i + 2 >= bytes.length) break;
        final c = ((b & 0x0F) << 12) | ((bytes[i + 1] & 0x3F) << 6) | (bytes[i + 2] & 0x3F);
        codeUnits.add(c);
        i += 3;
      } else {
        // Invalid UTF-8 or surrogate - skip
        codeUnits.add(0xFFFD); // Replacement character
        i++;
      }
    }

    return String.fromCharCodes(codeUnits);
  }
}
