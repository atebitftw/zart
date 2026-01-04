import 'dart:io';
import 'package:zart/src/tads3/vm/t3_interpreter.dart';
import 'package:zart/src/tads3/vm/t3_opcodes.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart t3_trace.dart <file.t3>');
    return;
  }

  final data = File(args[0]).readAsBytesSync();
  final interp = T3Interpreter();

  print('Loading ${args[0]}...');
  interp.load(data);

  print('Entrypoint: ${interp.entrypoint}');
  print('');

  // Manually trace first few instructions
  final codePool = interp.codePool!;
  var ip = interp.entrypoint!.codeOffset + 10; // Skip header

  print('Tracing from IP 0x${ip.toRadixString(16)}:');
  for (var i = 0; i < 10; i++) {
    final opcode = codePool.readByte(ip);
    final opcodeName = T3Opcodes.getName(opcode);
    print('');
    print('IP 0x${ip.toRadixString(16)}: $opcodeName (0x${opcode.toRadixString(16)})');

    ip++; // Move past opcode

    // Decode operands based on opcode
    if (opcode == T3Opcodes.CALL) {
      final argc = codePool.readByte(ip);
      print('  argc: $argc');
      ip++;
      final targetAddr = codePool.readUint32(ip);
      print('  targetAddr: 0x${targetAddr.toRadixString(16)} ($targetAddr)');
      ip += 4;
    } else if (opcode == T3Opcodes.PUSHNIL) {
      // No operands
    } else if (opcode == T3Opcodes.GETARG1) {
      final argIdx = codePool.readByte(ip);
      print('  argIdx: $argIdx');
      ip++;
    } else if (opcode == 0x00) {
      print('  (NOP/unknown)');
    } else {
      print('  (operands not decoded)');
      break;
    }
  }
}
