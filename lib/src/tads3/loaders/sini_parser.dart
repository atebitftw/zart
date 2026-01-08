import 'dart:typed_data';

/// A TADS 3 Static Initializer (SINI) block.
///
/// This block contains a list of properties that should be evaluated
/// at load time, before the game starts.
class T3SiniBlock {
  /// The initializers defined in this block.
  /// Each entry is a pair of (objectId, propId).
  final List<(int, int)> initializers;

  T3SiniBlock(this.initializers);

  /// Parses a SINI block from binary data.
  factory T3SiniBlock.parse(Uint8List data) {
    if (data.length < 2) {
      throw FormatException('SINI block too short');
    }

    final byteData = ByteData.view(
      data.buffer,
      data.offsetInBytes,
      data.length,
    );
    final count = byteData.getUint32(0, Endian.little);
    final initializers = <(int, int)>[];

    var offset = 4;
    for (var i = 0; i < count; i++) {
      if (offset + 6 > data.length) break;

      // Each entry:
      // UINT4 object ID
      // UINT2 property ID
      final objId = byteData.getUint32(offset, Endian.little);
      final propId = byteData.getUint16(offset + 4, Endian.little);
      offset += 6;

      initializers.add((objId, propId));
    }

    return T3SiniBlock(initializers);
  }
}
