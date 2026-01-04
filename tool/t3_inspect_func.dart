import 'dart:io';
import 'package:zart/src/tads3/vm/t3_interpreter.dart';
import 'package:zart/src/tads3/vm/t3_function_header.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart t3_inspect_func.dart <file.t3> <offset_hex>');
    return;
  }

  final data = File(args[0]).readAsBytesSync();
  final interp = T3Interpreter();

  print('Loading ${args[0]}...');
  interp.load(data);

  final offset = int.parse(args[1], radix: 16);
  print('Inspecting function at offset 0x${offset.toRadixString(16)}:');
  print('');

  // Read and display bytes
  print('Bytes at offset:');
  for (int i = 0; i < 32; i++) {
    final byte = interp.codePool!.readByte(offset + i);
    print('  +$i (0x${(offset + i).toRadixString(16)}): 0x${byte.toRadixString(16).padLeft(2, '0')} ($byte)');
  }
  print('');

  // Try parsing as 10-byte header
  print('Parsing as 10-byte header:');
  final headerBytes = interp.codePool!.readBytes(offset, 10);
  final header = T3FunctionHeader.parse(headerBytes);
  print('  argc: ${header.argc} (0x${header.argc.toRadixString(16)})');
  print('  optionalArgc: ${header.optionalArgc} (0x${header.optionalArgc.toRadixString(16)})');
  print('  minArgs: ${header.minArgs}');
  print('  maxArgs: ${header.maxArgs}');
  print('  isVarargs: ${header.isVarargs}');
  print('  localCount: ${header.localCount}');
  print('  stackDepth: ${header.stackDepth}');
  print('  exceptionTableOffset: ${header.exceptionTableOffset}');
  print('  debugOffset: ${header.debugOffset}');
}
