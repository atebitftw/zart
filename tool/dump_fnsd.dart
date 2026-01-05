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
    final blockData = bytes.sublist(pos + 10, pos + 10 + size);

    if (type == 'FNSD') {
      final blockView = ByteData.view(blockData.buffer);
      final count = blockView.getUint16(0, Endian.little);
      print('FNSD block: $count dependencies');
      int off = 2;
      for (int i = 0; i < count; i++) {
        final nameLen = blockData[off];
        final name = String.fromCharCodes(blockData.sublist(off + 1, off + 1 + nameLen));
        off += 1 + nameLen;
        print('  $i: $name');
      }
    }

    if (type == 'EOF ') break;
    pos += 10 + size;
  }
}
