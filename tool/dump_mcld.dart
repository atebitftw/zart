import 'dart:io';
import 'dart:typed_data';

void main() async {
  final file = File('assets/testers/tads/aboutbox.t3');
  final bytes = await file.readAsBytes();
  final data = ByteData.view(bytes.buffer);

  int pos = 69;
  while (pos + 10 <= bytes.length) {
    final type = String.fromCharCodes(bytes.sublist(pos, pos + 4));
    final size = data.getUint32(pos + 4, Endian.little);
    final flags = data.getUint16(pos + 8, Endian.little);
    var blockData = bytes.sublist(pos + 10, pos + 10 + size);

    // MCLD is usually NOT masked, but if it was, flags bit 0x0001 would be set.
    // Based on previous run, it seems it is NOT masked.
    if (type == 'MCLD') {
      final blockView = ByteData.view(blockData.buffer);
      final count = blockView.getUint16(0, Endian.little);
      print('MCLD Block: $count metaclasses');
      var offset = 2;
      for (var i = 0; i < count; i++) {
        if (offset + 2 > blockData.length) break;
        final entrySize = blockView.getUint16(offset, Endian.little);
        final entryEnd = offset + entrySize;
        offset += 2;

        final nameLen = blockData[offset++];
        final identifier = String.fromCharCodes(
          blockData.sublist(offset, offset + nameLen),
        );
        offset += nameLen;

        final propCount = blockView.getUint16(offset, Endian.little);
        offset += 2;
        final propEntrySize = blockView.getUint16(offset, Endian.little);
        offset += 2;

        print(
          '  [$i] $identifier: $propCount properties (entry size $propEntrySize)',
        );
        for (var j = 0; j < propCount; j++) {
          final propId = blockView.getUint16(offset, Endian.little);
          offset += propEntrySize;
          print('    #$j: prop 0x${propId.toRadixString(16)}');
        }
        offset = entryEnd;
      }
    }

    if (type == 'EOF ') break;
    pos += 10 + size;
  }
}
