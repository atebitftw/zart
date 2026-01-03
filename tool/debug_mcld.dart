import 'dart:io';
import 'dart:typed_data';

import 'package:zart/src/loaders/tads/t3_block.dart';
import 'package:zart/src/loaders/tads/t3_image.dart';
import 'package:zart/src/tads3/loaders/mcld_parser.dart';

void main() {
  final gameFile = File('assets/games/tads/AllHope.t3');
  final gameData = gameFile.readAsBytesSync();
  final image = T3Image(Uint8List.fromList(gameData));

  // Get MCLD block data
  final mcldBlock = image.findBlock(T3Block.typeMetaclassDep);
  if (mcldBlock == null) {
    print('No MCLD block found');
    return;
  }

  print('MCLD block size: ${mcldBlock.dataSize}');
  print('MCLD block offset: ${mcldBlock.dataOffset}');

  final data = image.getBlockData(mcldBlock);
  print('Block data length: ${data.length}');

  // Parse using the updated parser
  try {
    final mcld = T3MetaclassDepList.parse(data);
    print('Successfully parsed ${mcld.length} metaclasses:');
    for (final dep in mcld.dependencies) {
      print('  $dep');
    }
  } catch (e, st) {
    print('Error parsing MCLD: $e');
    print(st);
  }
}
