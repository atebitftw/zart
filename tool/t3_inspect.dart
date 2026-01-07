import 'dart:io';
import 'package:zart/src/tads3/vm/t3_interpreter.dart';
import 'package:zart/src/tads3/vm/t3_opcodes.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart t3_inspect.dart <file.t3>');
    return;
  }

  String filePath = args[0];
  bool disassemble = false;
  if (args[0] == '--disasm') {
    if (args.length < 2) {
      print('Usage: dart t3_inspect.dart --disasm <file.t3>');
      return;
    }
    disassemble = true;
    filePath = args[1];
  }

  final data = File(filePath).readAsBytesSync();
  final interp = T3Interpreter();

  print('Loading ${args[0]}...');
  interp.load(data);

  print('Entrypoint: ${interp.entrypoint}');
  print('');

  // Inspect code pool at entrypoint
  final codePool = interp.codePool;
  if (codePool == null) {
    print('No code pool loaded');
    return;
  }

  final entryOffset = interp.entrypoint!.codeOffset;
  print('Inspecting code pool at offset 0x${entryOffset.toRadixString(16)}:');
  print('');

  // Read first 32 bytes
  print('First 32 bytes of code pool:');
  for (int i = 0; i < 32; i++) {
    final byte = codePool.readByte(i);
    final opcodeName = T3Opcodes.getName(byte);
    print(
      '  0x${i.toRadixString(16).padLeft(2, '0')}: 0x${byte.toRadixString(16).padLeft(2, '0')} ($byte) - $opcodeName',
    );
  }
  print('');

  // Read function header at entrypoint
  print('Function header at entrypoint (offset 0x${entryOffset.toRadixString(16)}):');
  final headerBytes = codePool.readBytes(entryOffset, 10);
  for (int i = 0; i < 10; i++) {
    print('  +$i: 0x${headerBytes[i].toRadixString(16).padLeft(2, '0')} (${headerBytes[i]})');
  }
  print('');

  // Parse header
  print('Parsed header:');
  print('  argc: ${headerBytes[0]} (0x${headerBytes[0].toRadixString(16)})');
  print('  optionalArgc: ${headerBytes[1]} (0x${headerBytes[1].toRadixString(16)})');
  final localCount = headerBytes[2] | (headerBytes[3] << 8);
  print('  localCount: $localCount (0x${localCount.toRadixString(16)})');
  final stackDepth = headerBytes[4] | (headerBytes[5] << 8);
  print('  stackDepth: $stackDepth (0x${stackDepth.toRadixString(16)})');
  final exceptionTableOffset = headerBytes[6] | (headerBytes[7] << 8);
  print('  exceptionTableOffset: $exceptionTableOffset (0x${exceptionTableOffset.toRadixString(16)})');
  final debugOffset = headerBytes[8] | (headerBytes[9] << 8);
  print('  debugOffset: $debugOffset (0x${debugOffset.toRadixString(16)})');
  print('');

  // Show first bytecode instruction
  final firstInstructionOffset = entryOffset + 10;
  print('First instruction at offset 0x${firstInstructionOffset.toRadixString(16)}:');
  for (int i = 0; i < 16; i++) {
    final offset = firstInstructionOffset + i;
    final byte = codePool.readByte(offset);
    final opcodeName = T3Opcodes.getName(byte);
    print(
      '  0x${offset.toRadixString(16).padLeft(2, '0')}: 0x${byte.toRadixString(16).padLeft(2, '0')} ($byte) - $opcodeName',
    );
  }

  if (disassemble) {
    print('');
    print('Disassembly:');
    print('');

    final codePool = interp.codePool;
    if (codePool == null) {
      print('No code pool loaded');
      return;
    }

    var ip = interp.entrypoint!.codeOffset;
    final endIp = ip + 10000; // Limit to 10000 bytes

    while (ip < endIp) {
      final opcode = codePool.readByte(ip);
      final opcodeName = T3Opcodes.getName(opcode);

      var extra = '';
      var len = 1;

      // Simple heuristic for common opcodes to show operands
      // This is NOT comprehensive, just enough for debugging
      try {
        if (opcodeName == 'INCLCL') {
          final lclIdx = codePool.readByte(ip + 1);
          extra = ' local($lclIdx)';
          len = 2;
        } else if (opcodeName == 'GETLCL1' || opcodeName == 'SETLCL1') {
          final lclIdx = codePool.readByte(ip + 1);
          extra = ' local($lclIdx)';
          len = 2;
        } else if (opcodeName == 'PUSHSTR') {
          final offset = codePool.readUint32(ip + 1);
          extra = ' offset=$offset';
          len = 5;
        } else if (opcodeName == 'JMP' || opcodeName == 'JT' || opcodeName == 'JF') {
          final offset = codePool.readInt16(ip + 1);
          extra = ' target=${(ip + offset + 3).toRadixString(16)}'; // relative to next instruction
          len = 3;
        }
      } catch (e) {
        // ignore read errors at end of file
      }

      print(
        '0x${ip.toRadixString(16).padLeft(4, '0')}: ${opcode.toRadixString(16).padLeft(2, '0')} ($opcodeName)$extra',
      );

      ip += len; // rudimentary step
      // Ideally we need opcode lengths table
    }
  }
}
