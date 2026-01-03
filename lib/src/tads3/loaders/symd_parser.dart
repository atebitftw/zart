import 'dart:typed_data';
import 'package:zart/src/tads3/vm/t3_value.dart';

/// A TADS3 Symbol Names (SYMD) block.
///
/// This block maps symbol names (e.g., "propNotDefined", "RuntimeError") to
/// their runtime values (typed as [T3Value]).
class T3SymdBlock {
  /// The symbols defined in this block.
  final Map<String, T3Value> symbols;

  T3SymdBlock(this.symbols);

  /// Parses a SYMD block from binary data.
  factory T3SymdBlock.parse(Uint8List data) {
    if (data.length < 2) {
      throw FormatException('SYMD block too short');
    }

    final byteData = ByteData.view(data.buffer, data.offsetInBytes, data.length);
    final count = byteData.getUint16(0, Endian.little);
    final symbols = <String, T3Value>{};

    var offset = 2;
    for (var i = 0; i < count; i++) {
      if (offset + 5 > data.length) break;

      // Each entry:
      // DATA_HOLDER (5 bytes)
      // UBYTE name length
      // Name (length bytes)

      final value = T3Value.fromPortable(data, offset);
      offset += 5;

      if (offset >= data.length) break;
      final nameLen = data[offset++];

      if (offset + nameLen > data.length) break;
      final name = String.fromCharCodes(data.sublist(offset, offset + nameLen));
      offset += nameLen;

      symbols[name] = value;
    }

    return T3SymdBlock(symbols);
  }
}
