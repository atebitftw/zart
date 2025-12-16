import 'package:test/test.dart';
import 'package:zart/zart.dart';
import 'package:zart/src/z_machine/interpreters/interpreter_v5.dart';
import 'dart:async';

class CapturingIoProvider implements IoProvider {
  Map<String, dynamic>? lastCommand;
  String nextReadResult = "hello";
  String nextCharResult = "a";

  @override
  Future<dynamic> command(Map<String, dynamic> command) async {
    lastCommand = command;
    if (command['command'] == IoCommands.read) {
      return nextReadResult;
    }
    if (command['command'] == IoCommands.readChar) {
      return nextCharResult;
    }
    // Handle other commands like printBuffer by returning null
    return null;
  }

  @override
  int getFlags1() => 0;

  int getFlags2() => 0; // if needed
}

void main() {
  group('Version 5 Input Opcodes', () {
    late CapturingIoProvider io;

    setUp(() {
      io = CapturingIoProvider();

      // Initialize Z-Machine with a dummy V5 header
      final rawBytes = List<int>.filled(4096, 0);
      rawBytes[0] = 5; // Version 5

      // Setup minimal Dictionary
      int dictAddr = 0x800; // Place it somewhere safe
      rawBytes[8] = (dictAddr >> 8) & 0xFF; // Header: Dictionary address
      rawBytes[9] = dictAddr & 0xFF;

      // Dictionary structure
      rawBytes[dictAddr] = 0; // Number of separators
      // Entry length (must be >= 6 for V5)
      rawBytes[dictAddr + 1] = 7; // Entry length
      // Number of entries = 0
      rawBytes[dictAddr + 2] = 0;
      rawBytes[dictAddr + 3] = 0;

      Z.load(rawBytes);
      Z.io = io;

      // Ensure we are using InterpreterV5
      expect(Z.engine, isA<InterpreterV5>());
    });

    test('readChar passes time and routine to IoProvider', () async {
      final v5 = Z.engine as InterpreterV5;

      // Mock memory for read_char 1 time routine -> result
      // Opcode: VAR:246 (read_char)
      // We'll manually inject operands or just mock the call?
      // Calling individual methods on interpreter is hard because they read from PC.
      // We will write a tiny program into memory.

      // Program: read_char 1 time routine -> result
      // VAR 246 is 0xEC (call_2s) ... wait.
      // VAR opcodes: 224-255.
      // read_char is 246.

      // Constructing instruction bytes manually is tedious and error prone.
      // Let's rely on `aread()` and `readChar()` methods being public in `InterpreterV5`?
      // No, `InterpreterV5` methods are void and read from PC.
      // Wait, `readChar()` IS public but it reads operands from memory.

      // Let's forge the memory at PC.
      int pc = 0x100;
      v5.programCounter = pc;

      // write operands
      // We need to encode the call to readChar.
      // Actually, we can just populate the memory that `visitOperandsVar` reads.
      // But `visitOperandsVar` reads the "Types" byte(s) to know what follows.
      // read_char VAR types byte:
      // 4 operands: 1, time, routine.
      // 1 (id) = small constant
      // time = small constant
      // routine = small constant
      // types byte: 01 01 01 11 (last one omitted? No, result store is separate).
      // 01(small) 01(small) 01(small) 11(omitted) = 01010111 binary = 0x57.

      // Opcode is read_char (VAR 246).
      // The dispatcher calls `readChar()`. We can call it directly if we set up memory.

      Z.engine.mem.storeb(pc, 0x57); // Types: Small, Small, Small, Omitted
      Z.engine.mem.storeb(pc + 1, 1); // Device ID 1
      Z.engine.mem.storeb(pc + 2, 50); // Time (t=50)
      Z.engine.mem.storeb(pc + 3, 200); // Routine (packed addr 200)

      // Store result to stack (0)
      // wait, `readChar` does `var resultTo = readb();`
      // So we need another byte after operands for store location.
      Z.engine.mem.storeb(pc + 4, 0); // Store to stack

      // Execute
      await v5.readChar();

      expect(io.lastCommand, isNotNull);
      expect(io.lastCommand!['command'], equals(IoCommands.readChar));
      expect(io.lastCommand!['time'], equals(50));
      expect(io.lastCommand!['routine'], equals(200));
    });

    test('aread sends IoCommands.read with correct parameters', () async {
      final v5 = Z.engine as InterpreterV5;

      // Setup Text Buffer at address 0x200
      int textBufferAddr = 0x200;
      Z.engine.mem.storeb(textBufferAddr, 20); // Max Length = 20
      Z.engine.mem.storeb(textBufferAddr + 1, 0); // Current Length = 0

      // Setup PC
      int pc = 0x100;
      v5.programCounter = pc;

      // aread text parse time routine -> result
      // operands: text(small implied ptr), parse(omitted), time(small), routine(small)
      // types: small, omitted, small, small = 01 11 01 01 = 0x75

      Z.engine.mem.storeb(pc, 0x75);
      Z.engine.mem.storeb(
        pc + 1,
        (textBufferAddr >> 0) & 0xFF,
      ); // text buffer (truncated to byte for 'Small' operand? No.)
      // Wait, 'Small' operand is 1 byte value (0-255). 0x200 is > 255.
      // So we must use 'Large' (word).
      // Types: Large, Omitted, Small, Small.
      // 00 11 01 01 = 0x35

      Z.engine.mem.storeb(pc, 0x35);
      Z.engine.mem.storew(pc + 1, textBufferAddr); // text buffer addr
      // skipped parse operand?
      // visitOperandsVar logic:
      // "to = (os >> shiftStart) & 3"
      // If omitted, break.
      // If we skip parse, we break, so we can't provide time/routine as subsequent args in simple variable encoding?
      // Wait, Z-Machine VAR opcodes: supply as many as needed?
      // But `visitOperandsVar` stops at first omitted.
      // So to supply time/routine (args 3 and 4), we MUST supply arg 2 (parse).
      // Parse can be 0 (constant).
      // So: Large, Small(0), Small, Small.
      // 00 01 01 01 = 0x15.

      Z.engine.mem.storeb(pc, 0x15);
      Z.engine.mem.storew(pc + 1, textBufferAddr); // Arg 1: text
      // Arg 2: parse (Small, val 0)
      Z.engine.mem.storeb(pc + 3, 0);
      // Arg 3: time (Small, val 100)
      Z.engine.mem.storeb(pc + 4, 100);
      // Arg 4: routine (Small, val 250) (Assuming routine fits in byte for test)
      Z.engine.mem.storeb(pc + 5, 250);

      // Result Store byte
      Z.engine.mem.storeb(pc + 6, 0); // Stack

      await v5.aread();

      expect(io.lastCommand, isNotNull);
      expect(io.lastCommand!['command'], equals(IoCommands.read));
      expect(io.lastCommand!['max_chars'], equals(18)); // 20 - 2
      expect(io.lastCommand!['time'], equals(100));
      expect(io.lastCommand!['routine'], equals(250));
      expect(io.lastCommand!['initial_text'], isNull); // Was 0 length
    });

    test('aread extracts initial text from buffer', () async {
      final v5 = Z.engine as InterpreterV5;

      int textBufferAddr = 0x300;
      Z.engine.mem.storeb(textBufferAddr, 20); // Max
      Z.engine.mem.storeb(textBufferAddr + 1, 5); // Current Length = 5

      // "hello" in ZSCII (is ASCII compatible for lowercase)
      // "h"=104, "e"=101, "l"=108, "l"=108, "o"=111.
      Z.engine.mem.storeb(textBufferAddr + 2, 104);
      Z.engine.mem.storeb(textBufferAddr + 3, 101);
      Z.engine.mem.storeb(textBufferAddr + 4, 108);
      Z.engine.mem.storeb(textBufferAddr + 5, 108);
      Z.engine.mem.storeb(textBufferAddr + 6, 111);

      int pc = 0x100;
      v5.programCounter = pc;

      // Types: Large, Small(0) = 00 01 11 11 = 0x1F
      // Just Text and Parse(0) provided.
      Z.engine.mem.storeb(pc, 0x1F);
      Z.engine.mem.storew(pc + 1, textBufferAddr);
      Z.engine.mem.storeb(pc + 3, 0); // Parse = 0

      Z.engine.mem.storeb(pc + 4, 0); // Store

      await v5.aread();

      expect(io.lastCommand, isNotNull);
      expect(io.lastCommand!['initial_text'], equals('hello'));
    });
  });
}
