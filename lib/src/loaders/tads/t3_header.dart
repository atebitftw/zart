import 'dart:typed_data';

import 'package:zart/src/loaders/tads/t3_exception.dart';

/// The T3 image file header.
///
/// T3 image files begin with a 69-byte header containing:
/// - Magic signature: "T3-image\r\n\x1A" (11 bytes)
/// - Format version: 2-byte little-endian integer
/// - Reserved: 32 bytes
/// - Timestamp: 24-byte ASCII string
///
/// After the header, the file contains a sequence of data blocks.
class T3Header {
  /// Size of the header in bytes (before blocks begin).
  static const int size = 69;

  /// The expected signature bytes: "T3-image\r\n\x1A".
  static const List<int> expectedSignature = [
    0x54, 0x33, 0x2D, 0x69, 0x6D, 0x61, 0x67, 0x65, // "T3-image"
    0x0D, 0x0A, 0x1A, // "\r\n\x1A"
  ];

  /// Signature length in bytes.
  static const int signatureLength = 11;

  /// Offset of the format version field.
  static const int versionOffset = 11;

  /// Offset of the reserved bytes.
  static const int reservedOffset = 13;

  /// Length of reserved bytes.
  static const int reservedLength = 32;

  /// Offset of the timestamp field.
  static const int timestampOffset = 45;

  /// Length of the timestamp string.
  static const int timestampLength = 24;

  final Uint8List _data;
  late final ByteData _view;

  /// Creates a new [T3Header] from the given bytes.
  ///
  /// Throws a [T3Exception] if the data is too short.
  T3Header(Uint8List data) : _data = Uint8List(size) {
    if (data.length < size) {
      throw T3Exception('T3 header must be at least $size bytes.');
    }
    // Copy header bytes
    for (var i = 0; i < size; i++) {
      _data[i] = data[i];
    }
    _view = ByteData.view(_data.buffer);
  }

  /// Returns the raw signature bytes (first 11 bytes).
  Uint8List get signatureBytes => _data.sublist(0, signatureLength);

  /// Returns true if the signature is valid.
  bool get hasValidSignature {
    for (var i = 0; i < signatureLength; i++) {
      if (_data[i] != expectedSignature[i]) return false;
    }
    return true;
  }

  /// Format version number (little-endian 16-bit integer).
  ///
  /// Current version is 1 for the format described in the TADS3 spec.
  int get version => _view.getUint16(versionOffset, Endian.little);

  /// The reserved bytes (32 bytes, should be zero).
  Uint8List get reservedBytes => _data.sublist(reservedOffset, reservedOffset + reservedLength);

  /// The compilation timestamp as an ASCII string.
  ///
  /// Format: "Day Mon DD HH:MM:SS YYYY" (e.g., "Sat Feb 25 09:24:39 2006").
  String get timestamp {
    final bytes = _data.sublist(timestampOffset, timestampOffset + timestampLength);
    // Find null terminator if present
    var end = bytes.indexOf(0);
    if (end == -1) end = timestampLength;
    return String.fromCharCodes(bytes.sublist(0, end));
  }

  /// Validates the header signature and version.
  ///
  /// Throws a [T3Exception] if validation fails.
  void validate() {
    if (!hasValidSignature) {
      throw T3Exception('Invalid T3 signature: expected "T3-image\\r\\n\\x1A"');
    }

    // Version 1 is the only currently defined version
    if (version < 1 || version > 1) {
      throw T3Exception('Unsupported T3 format version: $version');
    }
  }

  /// Returns the raw header bytes.
  Uint8List get rawData => _data;

  @override
  String toString() => 'T3Header(version: $version, timestamp: "$timestamp")';
}
