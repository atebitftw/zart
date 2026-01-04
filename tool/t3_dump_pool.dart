import 'dart:io';
import 'package:zart/src/tads3/vm/t3_interpreter.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart t3_dump_pool.dart <file.t3> <start_hex> <count>');
    return;
  }

  final data = File(args[0]).readAsBytesSync();
  final interp = T3Interpreter();

  print('Loading ${args[0]}...');
  interp.load(data);

  final start = int.parse(args[1], radix: 16);
  final count = int.parse(args[2]);

  print('Code pool dump from 0x${start.toRadixString(16)} for $count bytes:');
  print('');

  for (int i = 0; i < count; i++) {
    final offset = start + i;
    final byte = interp.codePool!.readByte(offset);
    final hex = byte.toRadixString(16).padLeft(2, '0');
    final ascii = (byte >= 32 && byte < 127) ? String.fromCharCode(byte) : '.';

    if (i % 16 == 0) {
      if (i > 0) print('');
      stdout.write('0x${offset.toRadixString(16).padLeft(4, '0')}: ');
    }
    stdout.write('$hex ');

    if (i % 16 == 15) {
      stdout.write(' | ');
      for (int j = i - 15; j <= i; j++) {
        final b = interp.codePool!.readByte(start + j);
        final a = (b >= 32 && b < 127) ? String.fromCharCode(b) : '.';
        stdout.write(a);
      }
    }
  }
  print('');
}
