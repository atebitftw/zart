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
  var ip = args.length > 1 ? int.parse(args[1]) : interp.entrypoint!.codeOffset + 10;
  var count = args.length > 2 ? int.parse(args[2]) : 100;

  print('Tracing from IP 0x${ip.toRadixString(16)}:');
  for (var i = 0; i < count; i++) {
    if (ip >= codePool.totalSize) break;

    final startIp = ip;
    final opcode = codePool.readByte(ip++);
    final opcodeName = T3Opcodes.getName(opcode);

    String description = '';

    switch (opcode) {
      case T3Opcodes.CALL:
        final argc = codePool.readByte(ip++);
        final targetAddr = codePool.readUint32(ip);
        ip += 4;
        description = 'argc=$argc, target=0x${targetAddr.toRadixString(16)}';
        break;
      case T3Opcodes.PUSHNIL:
        description = 'nil';
        break;
      case T3Opcodes.PUSHTRUE:
        description = 'true';
        break;
      case T3Opcodes.PUSHINT8:
        final val = codePool.readByte(ip++).toSigned(8);
        description = 'val=$val';
        break;
      case T3Opcodes.PUSHINT:
        final val = codePool.readUint32(ip);
        ip += 4;
        description = 'val=$val';
        break;
      case T3Opcodes.PUSHSTR:
        final offset = codePool.readUint32(ip);
        ip += 4;
        description = 'offset=0x${offset.toRadixString(16)}';
        break;
      case T3Opcodes.GETARG1:
        final argIdx = codePool.readByte(ip++);
        description = 'argIdx=$argIdx';
        break;
      case T3Opcodes.GETLCL1:
        final lclIdx = codePool.readByte(ip++);
        description = 'lclIdx=$lclIdx';
        break;
      case T3Opcodes.SETLCL1:
        final lclIdx = codePool.readByte(ip++);
        description = 'lclIdx=$lclIdx';
        break;
      case T3Opcodes.GETLCLN0:
      case T3Opcodes.GETLCLN1:
      case T3Opcodes.GETLCLN2:
      case T3Opcodes.GETLCLN3:
      case T3Opcodes.GETLCLN4:
      case T3Opcodes.GETLCLN5:
        description = 'local ${opcode - T3Opcodes.GETLCLN0}';
        break;
      case T3Opcodes.ADD:
        description = '(binary add)';
        break;
      case T3Opcodes.SAY:
        final offset = codePool.readUint32(ip);
        ip += 4;
        description = 'offset=0x${offset.toRadixString(16)}';
        break;
      case T3Opcodes.BUILTIN_A:
        final argc = codePool.readByte(ip++);
        final idx = codePool.readByte(ip++);
        description = 'set 0, idx $idx, argc $argc';
        break;
      case T3Opcodes.BUILTIN_B:
        final argc = codePool.readByte(ip++);
        final idx = codePool.readByte(ip++);
        description = 'set 1, idx $idx, argc $argc';
        break;
      case T3Opcodes.INCLCL:
        final lclIdx = codePool.readByte(ip++);
        description = 'lclIdx=$lclIdx';
        break;
      case T3Opcodes.RETVAL:
        description = '(return value)';
        break;
    }

    print(
      '  [+0x${(startIp - interp.entrypoint!.codeOffset - 10).toRadixString(16).padLeft(2, '0')}] 0x${startIp.toRadixString(16)}: $opcodeName (0x${opcode.toRadixString(16)}) $description',
    );

    if (opcodeName == 'UNKNOWN') {
      print('Stopping at unknown opcode 0x${opcode.toRadixString(16)}');
      break;
    }
  }
}
