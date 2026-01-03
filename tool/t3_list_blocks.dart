import 'dart:io';
import 'dart:typed_data';
import 'package:zart/src/loaders/tads/t3_image.dart';
import 'package:zart/src/loaders/tads/t3_block.dart';
import 'package:zart/src/tads3/loaders/entp_parser.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    print('Usage: dart t3_list_blocks.dart <file.t3>');
    return;
  }

  final data = File(args[0]).readAsBytesSync();
  final image = T3Image(data);
  image.validate();

  print('Blocks in ${args[0]}:');
  for (final block in image.blocks) {
    print('  ${block.type} (${block.dataSize} bytes)');
    if (block.type == T3Block.typeEntrypoint) {
      final blockData = image.getBlockData(block);
      final entp = T3Entrypoint.parse(blockData);
      print('    -> $entp');
    }
    if (block.type == T3Block.typeConstPoolDef) {
      final blockData = image.getBlockData(block);
      final view = ByteData.view(blockData.buffer, blockData.offsetInBytes);
      final poolId = view.getUint16(0, Endian.little);
      final pageCount = view.getUint32(2, Endian.little);
      final pageSize = view.getUint32(6, Endian.little);
      print('    -> Pool $poolId: $pageCount pages, $pageSize bytes/page');
    }
  }
}
