import 'dart:io';
import 'package:zart/src/loaders/tads/t3_image.dart';
import 'package:zart/src/loaders/tads/t3_block.dart';
import 'package:zart/src/tads3/loaders/fnsd_parser.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    print('Usage: dart debug_fnsd.dart <file.t3>');
    return;
  }

  final data = File(args[0]).readAsBytesSync();
  final image = T3Image(data);

  final block = image.findBlock(T3Block.typeFunctionSetDep);
  if (block != null) {
    final blockData = image.getBlockData(block);
    final fnsd = T3FunctionSetDepList.parse(blockData);
    print('Function Sets:');
    for (final dep in fnsd.dependencies) {
      print('  ${dep.index}: ${dep.name}/${dep.version}');
    }
  } else {
    print('No FNSD block found.');
  }
}
