import 'dart:io';
import 'dart:typed_data';

void main(List<String> args) async {
  final file = File('assets/testers/tads/aboutbox.t3');
  if (!await file.exists()) {
    print('File not found: ${file.path}');
    return;
  }
  final bytes = await file.readAsBytes();
  final data = ByteData.view(bytes.buffer);

  print('File size: ${bytes.length}');

  // Header: 69 bytes
  int pos = 69;
  int? codePoolPageSize;
  Map<int, Uint8List> codePages = {};

  while (pos + 10 <= bytes.length) {
    final type = String.fromCharCodes(bytes.sublist(pos, pos + 4));
    final size = data.getUint32(pos + 4, Endian.little);
    final flags = data.getUint16(pos + 8, Endian.little);
    final blockData = bytes.sublist(pos + 10, pos + 10 + size);
    final blockView = ByteData.view(blockData.buffer);

    if (type == 'CPDF') {
      final poolId = blockView.getUint16(0, Endian.little);
      final pCount = blockView.getUint32(2, Endian.little);
      final pSize = blockView.getUint32(6, Endian.little);
      print('Found CPDF: poolId=$poolId, pageCount=$pCount, pageSize=$pSize');
      if (poolId == 1) codePoolPageSize = pSize;
    } else if (type == 'CPPG') {
      final poolId = blockView.getUint16(0, Endian.little);
      final pageIdx = blockView.getUint32(2, Endian.little);
      final xorMask = blockData[6];
      if (poolId == 1) {
        print('Found CPPG for Code Pool: pageIdx=$pageIdx, size=${size - 7}, xorMask=$xorMask');
        var pageData = blockData.sublist(7);
        if (xorMask != 0) {
          pageData = Uint8List.fromList([for (var b in pageData) b ^ xorMask]);
        }
        codePages[pageIdx] = pageData;
      }
    }

    if (type == 'EOF ') break;
    pos += 10 + size;
  }

  if (codePoolPageSize == null) {
    print('Error: Could not find code pool definition');
    return;
  }

  if (args.isEmpty) {
    print('Usage: dart dump_bytecode.dart <offset_hex_or_dec> [range]');
    return;
  }

  final targetStr = args[0];
  final targetOffset = targetStr.startsWith('0x') ? int.parse(targetStr.substring(2), radix: 16) : int.parse(targetStr);

  final range = args.length > 1 ? int.parse(args[1]) : 32;

  final pageIdx = targetOffset ~/ codePoolPageSize;
  final pageOff = targetOffset % codePoolPageSize;

  print('Targeting offset 0x${targetOffset.toRadixString(16)} -> Page $pageIdx, Offset 0x${pageOff.toRadixString(16)}');

  final page = codePages[pageIdx];
  if (page == null) {
    print('Error: Page $pageIdx not found');
    return;
  }

  print('Bytecode around 0x${targetOffset.toRadixString(16)}:');
  final start = pageOff - range ~/ 2;
  final end = pageOff + range ~/ 2;
  for (int i = start; i < end; i++) {
    if (i < 0 || i >= page.length) continue;
    final b = page[i];
    final prefix = (i == pageOff) ? '>>' : '  ';
    print(
      '$prefix 0x${(pageIdx * codePoolPageSize + i).toRadixString(16).padLeft(3, "0")}: 0x${b.toRadixString(16).padLeft(2, "0")}',
    );
  }
}
