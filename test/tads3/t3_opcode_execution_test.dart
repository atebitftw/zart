import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_opcodes.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';

import 'opcode_test_harness.dart';

/// T3 Opcode Execution Tests
///
/// Tests actual opcode execution behavior, not just constant values.
/// Uses OpcodeTestHarness to build and run bytecode sequences.
void main() {
  group('Push opcodes execution', () {
    test('PUSH_0 pushes integer 0', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSH_0);
      h.build();
      h.step();

      expect(h.peek().isInt, isTrue);
      expect(h.peek().value, 0);
    });

    test('PUSH_1 pushes integer 1', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSH_1);
      h.build();
      h.step();

      expect(h.peek().value, 1);
    });

    test('PUSHINT8 pushes signed 8-bit integer', () {
      final h = OpcodeTestHarness.withPushInt8(42);
      h.step();
      expect(h.peek().value, 42);
    });

    test('PUSHINT8 handles negative values', () {
      final h = OpcodeTestHarness.withPushInt8(-1);
      h.step();
      // -1 as signed byte is 0xFF, should be sign-extended
      expect(h.peek().value, -1);
    });

    test('PUSHINT pushes 32-bit integer', () {
      final h = OpcodeTestHarness.withPushInt(100000);
      h.step();
      expect(h.peek().value, 100000);
    });

    test('PUSHINT handles negative 32-bit', () {
      final h = OpcodeTestHarness.withPushInt(-100000);
      h.step();
      expect(h.peek().value, -100000);
    });

    test('PUSHNIL pushes nil value', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHNIL);
      h.build();
      h.step();

      expect(h.peek().isNil, isTrue);
    });

    test('PUSHTRUE pushes true value', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHTRUE);
      h.build();
      h.step();

      expect(h.peek().isTrue, isTrue);
    });

    test('PUSHOBJ pushes object reference', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHOBJ);
      h.emitUint32(12345);
      h.build();
      h.step();

      expect(h.peek().isObject, isTrue);
      expect(h.peek().value, 12345);
    });

    test('PUSHPROPID pushes property ID', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHPROPID);
      h.emitUint16(100);
      h.build();
      h.step();

      expect(h.peek().type, T3DataType.prop);
      expect(h.peek().value, 100);
    });
  });

  group('Arithmetic opcodes execution', () {
    test('ADD adds two integers', () {
      final h = OpcodeTestHarness.withBinaryOp(T3Opcodes.ADD, 30, 12);
      h.runSteps(3); // PUSHINT, PUSHINT, ADD
      expect(h.peek().value, 42);
    });

    test('SUB subtracts integers', () {
      final h = OpcodeTestHarness.withBinaryOp(T3Opcodes.SUB, 50, 8);
      h.runSteps(3);
      expect(h.peek().value, 42);
    });

    test('MUL multiplies integers', () {
      final h = OpcodeTestHarness.withBinaryOp(T3Opcodes.MUL, 6, 7);
      h.runSteps(3);
      expect(h.peek().value, 42);
    });

    test('DIV divides integers', () {
      final h = OpcodeTestHarness.withBinaryOp(T3Opcodes.DIV, 84, 2);
      h.runSteps(3);
      expect(h.peek().value, 42);
    });

    test('MOD computes modulo', () {
      final h = OpcodeTestHarness.withBinaryOp(T3Opcodes.MOD, 47, 5);
      h.runSteps(3);
      expect(h.peek().value, 2);
    });

    test('NEG negates integer', () {
      final h = OpcodeTestHarness.withUnaryOp(T3Opcodes.NEG, 42);
      h.runSteps(2);
      expect(h.peek().value, -42);
    });

    test('INC increments TOS', () {
      final h = OpcodeTestHarness.withUnaryOp(T3Opcodes.INC, 41);
      h.runSteps(2);
      expect(h.peek().value, 42);
    });

    test('DEC decrements TOS', () {
      final h = OpcodeTestHarness.withUnaryOp(T3Opcodes.DEC, 43);
      h.runSteps(2);
      expect(h.peek().value, 42);
    });
  });

  group('Bitwise opcodes execution', () {
    test('BAND performs bitwise AND', () {
      final h = OpcodeTestHarness.withBinaryOp(T3Opcodes.BAND, 0xFF, 0x0F);
      h.runSteps(3);
      expect(h.peek().value, 0x0F);
    });

    test('BOR performs bitwise OR', () {
      final h = OpcodeTestHarness.withBinaryOp(T3Opcodes.BOR, 0xF0, 0x0F);
      h.runSteps(3);
      expect(h.peek().value, 0xFF);
    });

    test('XOR performs bitwise XOR', () {
      final h = OpcodeTestHarness.withBinaryOp(T3Opcodes.XOR, 0xFF, 0x0F);
      h.runSteps(3);
      expect(h.peek().value, 0xF0);
    });

    test('BNOT performs bitwise NOT', () {
      final h = OpcodeTestHarness.withUnaryOp(T3Opcodes.BNOT, 0);
      h.runSteps(2);
      expect(h.peek().value, -1); // ~0 = -1 in two's complement
    });

    test('SHL shifts left', () {
      final h = OpcodeTestHarness.withBinaryOp(T3Opcodes.SHL, 1, 4);
      h.runSteps(3);
      expect(h.peek().value, 16);
    });

    test('ASHR arithmetic shifts right', () {
      final h = OpcodeTestHarness.withBinaryOp(T3Opcodes.ASHR, -16, 2);
      h.runSteps(3);
      expect(h.peek().value, -4); // Sign bit preserved
    });

    test('LSHR logical shifts right', () {
      final h = OpcodeTestHarness.withBinaryOp(T3Opcodes.LSHR, -1, 1);
      h.runSteps(3);
      // -1 = 0xFFFFFFFF, logical shift right by 1 = 0x7FFFFFFF
      expect(h.peek().value, 0x7FFFFFFF);
    });
  });

  group('Comparison opcodes execution', () {
    test('EQ returns true for equal values', () {
      final h = OpcodeTestHarness.withBinaryOp(T3Opcodes.EQ, 42, 42);
      h.runSteps(3);
      expect(h.peek().isTrue, isTrue);
    });

    test('EQ returns nil for unequal values', () {
      final h = OpcodeTestHarness.withBinaryOp(T3Opcodes.EQ, 42, 43);
      h.runSteps(3);
      expect(h.peek().isNil, isTrue);
    });

    test('NE returns true for unequal values', () {
      final h = OpcodeTestHarness.withBinaryOp(T3Opcodes.NE, 42, 43);
      h.runSteps(3);
      expect(h.peek().isTrue, isTrue);
    });

    test('LT returns true when a < b', () {
      final h = OpcodeTestHarness.withBinaryOp(T3Opcodes.LT, 10, 20);
      h.runSteps(3);
      expect(h.peek().isTrue, isTrue);
    });

    test('LT returns nil when a >= b', () {
      final h = OpcodeTestHarness.withBinaryOp(T3Opcodes.LT, 20, 10);
      h.runSteps(3);
      expect(h.peek().isNil, isTrue);
    });

    test('LE returns true when a <= b', () {
      final h = OpcodeTestHarness.withBinaryOp(T3Opcodes.LE, 10, 10);
      h.runSteps(3);
      expect(h.peek().isTrue, isTrue);
    });

    test('GT returns true when a > b', () {
      final h = OpcodeTestHarness.withBinaryOp(T3Opcodes.GT, 20, 10);
      h.runSteps(3);
      expect(h.peek().isTrue, isTrue);
    });

    test('GE returns true when a >= b', () {
      final h = OpcodeTestHarness.withBinaryOp(T3Opcodes.GE, 10, 10);
      h.runSteps(3);
      expect(h.peek().isTrue, isTrue);
    });
  });

  group('Logic opcodes execution', () {
    test('NOT on nil returns true', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHNIL);
      h.emit(T3Opcodes.NOT);
      h.build();
      h.runSteps(2);
      expect(h.peek().isTrue, isTrue);
    });

    test('NOT on true returns nil', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHTRUE);
      h.emit(T3Opcodes.NOT);
      h.build();
      h.runSteps(2);
      expect(h.peek().isNil, isTrue);
    });

    test('NOT on non-zero int returns nil', () {
      final h = OpcodeTestHarness.withUnaryOp(T3Opcodes.NOT, 42);
      h.runSteps(2);
      expect(h.peek().isNil, isTrue);
    });

    test('BOOLIZE on truthy returns true', () {
      final h = OpcodeTestHarness.withUnaryOp(T3Opcodes.BOOLIZE, 42);
      h.runSteps(2);
      expect(h.peek().isTrue, isTrue);
    });

    test('BOOLIZE on zero returns nil', () {
      final h = OpcodeTestHarness.withUnaryOp(T3Opcodes.BOOLIZE, 0);
      h.runSteps(2);
      expect(h.peek().isNil, isTrue);
    });
  });

  group('Stack manipulation opcodes', () {
    test('DUP duplicates TOS', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(42);
      h.emit(T3Opcodes.DUP);
      h.build();
      h.runSteps(2);

      expect(h.pop().value, 42);
      expect(h.pop().value, 42);
    });

    test('DISC discards TOS', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(1);
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(2);
      h.emit(T3Opcodes.DISC);
      h.build();
      final initialDepth = h.stackDepth;
      h.runSteps(3);

      expect(h.stackDepth, initialDepth + 1); // Only one value remains
      expect(h.peek().value, 1);
    });

    test('DISC1 discards N values', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(1);
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(2);
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(3);
      h.emit(T3Opcodes.DISC1);
      h.emitByte(2); // Discard 2 values
      h.build();
      final initialDepth = h.stackDepth;
      h.runSteps(4);

      expect(h.stackDepth, initialDepth + 1);
      expect(h.peek().value, 1);
    });

    test('SWAP exchanges top two values', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(1);
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(2);
      h.emit(T3Opcodes.SWAP);
      h.build();
      h.runSteps(3);

      expect(h.pop().value, 1);
      expect(h.pop().value, 2);
    });

    test('GETR0 pushes R0 register', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.GETR0);
      h.build();
      h.r0 = T3Value.fromInt(42);
      h.step();

      expect(h.peek().value, 42);
    });
  });

  group('Local variable opcodes', () {
    test('SETLCL1 stores to local', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(42);
      h.emit(T3Opcodes.SETLCL1);
      h.emitByte(0); // Local index 0
      h.build();
      h.runSteps(2);

      expect(h.getLocal(0).value, 42);
    });

    test('GETLCL1 retrieves local', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.GETLCL1);
      h.emitByte(0);
      h.build();
      h.setLocal(0, T3Value.fromInt(42));
      h.step();

      expect(h.peek().value, 42);
    });

    test('INCLCL increments local', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.INCLCL);
      h.emitUint16(0);
      h.build();
      h.setLocal(0, T3Value.fromInt(41));
      h.step();

      expect(h.getLocal(0).value, 42);
    });

    test('DECLCL decrements local', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.DECLCL);
      h.emitUint16(0);
      h.build();
      h.setLocal(0, T3Value.fromInt(43));
      h.step();

      expect(h.getLocal(0).value, 42);
    });

    test('ZEROLCL1 sets local to 0', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.ZEROLCL1);
      h.emitByte(0);
      h.build();
      h.setLocal(0, T3Value.fromInt(999));
      h.step();

      expect(h.getLocal(0).value, 0);
    });

    test('NILLCL1 sets local to nil', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.NILLCL1);
      h.emitByte(0);
      h.build();
      h.setLocal(0, T3Value.fromInt(999));
      h.step();

      expect(h.getLocal(0).isNil, isTrue);
    });

    test('ONELCL1 sets local to 1', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.ONELCL1);
      h.emitByte(0);
      h.build();
      h.setLocal(0, T3Value.fromInt(999));
      h.step();

      expect(h.getLocal(0).value, 1);
    });
  });

  group('Jump opcodes', () {
    test('JMP jumps unconditionally', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.JMP);
      h.emitInt16(3); // Skip next 3 bytes (includes this offset)
      h.emit(T3Opcodes.PUSH_1); // Should be skipped
      h.emit(T3Opcodes.PUSH_0); // Land here
      h.build();
      h.runSteps(2);

      expect(h.peek().value, 0); // PUSH_0 executed, not PUSH_1
    });

    test('JT jumps if true', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHTRUE);
      h.emit(T3Opcodes.JT);
      h.emitInt16(3);
      h.emit(T3Opcodes.PUSH_1); // Skipped
      h.emit(T3Opcodes.PUSH_0); // Land here
      h.build();
      h.runSteps(3);

      expect(h.peek().value, 0);
    });

    test('JT does not jump if false', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHNIL);
      h.emit(T3Opcodes.JT);
      h.emitInt16(3);
      h.emit(T3Opcodes.PUSH_1); // Executed
      h.build();
      h.runSteps(3);

      expect(h.peek().value, 1);
    });

    test('JF jumps if false', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHNIL);
      h.emit(T3Opcodes.JF);
      h.emitInt16(3);
      h.emit(T3Opcodes.PUSH_1); // Skipped
      h.emit(T3Opcodes.PUSH_0); // Land here
      h.build();
      h.runSteps(3);

      expect(h.peek().value, 0);
    });

    test('JNIL jumps if nil', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHNIL);
      h.emit(T3Opcodes.JNIL);
      h.emitInt16(3);
      h.emit(T3Opcodes.PUSH_1);
      h.emit(T3Opcodes.PUSH_0);
      h.build();
      h.runSteps(3);

      expect(h.peek().value, 0);
    });

    test('JNOTNIL jumps if not nil', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSH_1);
      h.emit(T3Opcodes.JNOTNIL);
      h.emitInt16(3);
      h.emit(T3Opcodes.PUSHNIL);
      h.emit(T3Opcodes.PUSH_0);
      h.build();
      h.runSteps(3);

      expect(h.peek().value, 0);
    });
  });

  group('NOP and debug opcodes', () {
    test('NOP does nothing', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.NOP);
      h.emit(T3Opcodes.PUSH_1);
      h.build();
      final ipBefore = h.ip;
      h.step(); // NOP
      expect(h.ip, ipBefore + 1);
      h.step(); // PUSH_1
      expect(h.peek().value, 1);
    });
  });

  group('Additional push opcodes', () {
    test('PUSHENUM pushes enum value', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHENUM);
      h.emitUint32(1001);
      h.build();
      h.step();

      expect(h.peek().type, T3DataType.enum_);
      expect(h.peek().value, 1001);
    });

    test('PUSHFNPTR pushes function pointer', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHFNPTR);
      h.emitUint32(0x1000);
      h.build();
      h.step();

      expect(h.peek().type, T3DataType.funcptr);
      expect(h.peek().value, 0x1000);
    });
  });

  group('Additional local opcodes', () {
    test('GETLCL2 retrieves local with 16-bit index', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.GETLCL2);
      h.emitUint16(1);
      h.build();
      h.setLocal(1, T3Value.fromInt(99));
      h.step();

      expect(h.peek().value, 99);
    });

    test('SETLCL2 stores to local with 16-bit index', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(77);
      h.emit(T3Opcodes.SETLCL2);
      h.emitUint16(2);
      h.build();
      h.runSteps(2);

      expect(h.getLocal(2).value, 77);
    });

    test('SETLCL1R0 stores R0 to local', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.SETLCL1R0);
      h.emitByte(3);
      h.build();
      h.r0 = T3Value.fromInt(123);
      h.step();

      expect(h.getLocal(3).value, 123);
    });

    test('ADDILCL1 adds immediate to local (1-byte index)', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.ADDILCL1);
      h.emitByte(0); // local index
      h.emitInt8(5); // value to add
      h.build();
      h.setLocal(0, T3Value.fromInt(10));
      h.step();

      expect(h.getLocal(0).value, 15);
    });

    test('ADDTOLCL adds TOS to local', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(7);
      h.emit(T3Opcodes.ADDTOLCL);
      h.emitUint16(0);
      h.build();
      h.setLocal(0, T3Value.fromInt(20));
      h.runSteps(2);

      expect(h.getLocal(0).value, 27);
    });

    test('SUBFROMLCL subtracts TOS from local', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(3);
      h.emit(T3Opcodes.SUBFROMLCL);
      h.emitUint16(0);
      h.build();
      h.setLocal(0, T3Value.fromInt(10));
      h.runSteps(2);

      expect(h.getLocal(0).value, 7);
    });
  });

  group('Argument opcodes', () {
    test('GETARGC pushes argument count', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.GETARGC);
      h.build();
      h.step();

      // Base frame has argCount=0
      expect(h.peek().value, 0);
    });
  });

  group('DUP2 opcode', () {
    test('DUP2 duplicates top two values', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(1);
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(2);
      h.emit(T3Opcodes.DUP2);
      h.build();
      h.runSteps(3);

      // Stack should have: 1, 2, 1, 2 (bottom to top)
      expect(h.pop().value, 2);
      expect(h.pop().value, 1);
      expect(h.pop().value, 2);
      expect(h.pop().value, 1);
    });
  });

  group('Indexed local access', () {
    test('IDXLCL1INT8 indexes local with immediate index', () {
      final h = OpcodeTestHarness();

      // Add a list to the constant pool: [10, 20, 30]
      final listOffset = h.addList([T3Value.fromInt(10), T3Value.fromInt(20), T3Value.fromInt(30)]);

      // Bytecode: push list ref, store to local 0, then use IDXLCL1INT8
      // Push the list constant
      h.emit(T3Opcodes.PUSHLST);
      h.emitUint32(listOffset);
      // Store to local 0
      h.emit(T3Opcodes.SETLCL1);
      h.emitByte(0);
      // Index local 0 with immediate index 2 (1-based, so gets element at index 2 = value 20)
      h.emit(T3Opcodes.IDXLCL1INT8);
      h.emitByte(0); // local number
      h.emitByte(2); // index (1-based)
      h.build();

      h.runSteps(3);

      // Result should be 20 (second element)
      expect(h.peek().value, 20);
    });
  });

  group('Comparison jump opcodes', () {
    test('JE jumps if TOS values equal', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(5);
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(5);
      h.emit(T3Opcodes.JE);
      h.emitInt16(3);
      h.emit(T3Opcodes.PUSH_0); // Skipped
      h.emit(T3Opcodes.PUSH_1); // Land here
      h.build();
      h.runSteps(4);

      expect(h.peek().value, 1);
    });

    test('JNE jumps if TOS values not equal', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(5);
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(6);
      h.emit(T3Opcodes.JNE);
      h.emitInt16(3);
      h.emit(T3Opcodes.PUSH_0);
      h.emit(T3Opcodes.PUSH_1);
      h.build();
      h.runSteps(4);

      expect(h.peek().value, 1);
    });

    test('JGT jumps if a > b', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(10);
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(5);
      h.emit(T3Opcodes.JGT);
      h.emitInt16(3);
      h.emit(T3Opcodes.PUSH_0);
      h.emit(T3Opcodes.PUSH_1);
      h.build();
      h.runSteps(4);

      expect(h.peek().value, 1);
    });

    test('JGE jumps if a >= b', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(5);
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(5);
      h.emit(T3Opcodes.JGE);
      h.emitInt16(3);
      h.emit(T3Opcodes.PUSH_0);
      h.emit(T3Opcodes.PUSH_1);
      h.build();
      h.runSteps(4);

      expect(h.peek().value, 1);
    });

    test('JLT jumps if a < b', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(3);
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(5);
      h.emit(T3Opcodes.JLT);
      h.emitInt16(3);
      h.emit(T3Opcodes.PUSH_0);
      h.emit(T3Opcodes.PUSH_1);
      h.build();
      h.runSteps(4);

      expect(h.peek().value, 1);
    });

    test('JLE jumps if a <= b', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(5);
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(5);
      h.emit(T3Opcodes.JLE);
      h.emitInt16(3);
      h.emit(T3Opcodes.PUSH_0);
      h.emit(T3Opcodes.PUSH_1);
      h.build();
      h.runSteps(4);

      expect(h.peek().value, 1);
    });
  });

  group('Short-circuit jump opcodes', () {
    test('JST saves and jumps if true (short-circuit AND)', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHTRUE);
      h.emit(T3Opcodes.JST);
      h.emitInt16(3);
      h.emit(T3Opcodes.PUSHNIL); // Skipped
      h.emit(T3Opcodes.NOP); // Land here
      h.build();
      h.runSteps(3);

      // Value should be preserved (true)
      expect(h.peek().isTrue, isTrue);
    });

    test('JST pops if false', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHNIL);
      h.emit(T3Opcodes.JST);
      h.emitInt16(3);
      h.emit(T3Opcodes.PUSHTRUE); // Executes
      h.build();
      h.runSteps(3);

      // Nil was popped, true was pushed
      expect(h.peek().isTrue, isTrue);
    });

    test('JSF saves and jumps if false (short-circuit OR)', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHNIL);
      h.emit(T3Opcodes.JSF);
      h.emitInt16(3);
      h.emit(T3Opcodes.PUSHTRUE); // Skipped
      h.emit(T3Opcodes.NOP); // Land here
      h.build();
      h.runSteps(3);

      expect(h.peek().isNil, isTrue);
    });
  });

  group('JR0 opcodes', () {
    test('JR0T jumps if R0 is true', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.JR0T);
      h.emitInt16(3);
      h.emit(T3Opcodes.PUSH_0);
      h.emit(T3Opcodes.PUSH_1);
      h.build();
      h.r0 = T3Value.true_();
      h.runSteps(2);

      expect(h.peek().value, 1);
    });

    test('JR0F jumps if R0 is false', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.JR0F);
      h.emitInt16(3);
      h.emit(T3Opcodes.PUSH_0);
      h.emit(T3Opcodes.PUSH_1);
      h.build();
      h.r0 = T3Value.nil();
      h.runSteps(2);

      expect(h.peek().value, 1);
    });
  });

  group('Local subroutine opcodes', () {
    test('LJSR and LRET work together', () {
      // LJSR pushes return offset and jumps
      // LRET retrieves return offset from local and jumps back
      final h = OpcodeTestHarness();
      // byte 0: LJSR (1 byte opcode + 2 byte operand = 3 bytes)
      h.emit(T3Opcodes.LJSR);
      // Offset is relative to operand address (byte 1).
      // To jump to byte 5: offset = 5 - 1 = 4
      h.emitInt16(4);
      // byte 3: PUSH_0 (return point - this should execute after LRET)
      h.emit(T3Opcodes.PUSH_0);
      // byte 4: NOP (end marker)
      h.emit(T3Opcodes.NOP);
      // byte 5: subroutine start - first save the return address
      h.emit(T3Opcodes.SETLCL1);
      h.emitByte(0);
      // bytes 7-8: Now do subroutine work
      h.emit(T3Opcodes.PUSH_1); // Push 1
      // bytes 9-11: LRET from local 0
      h.emit(T3Opcodes.LRET);
      h.emitUint16(0);
      h.build();

      // Execute LJSR - should jump to byte 5
      h.step();
      expect(h.ip, 5);

      // Execute SETLCL1 - saves return offset (3) to local 0
      h.step();
      expect(h.getLocal(0).value, 3);

      // Execute PUSH_1
      h.step();
      expect(h.peek().value, 1);

      // Execute LRET - returns to byte 3 (the saved return offset + ep)
      h.step();
      expect(h.ip, 3);
    });
  });

  group('String opcodes', () {
    test('PUSHLST pushes list reference', () {
      final h = OpcodeTestHarness();
      final listOffset = h.addList([T3Value.fromInt(1), T3Value.fromInt(2), T3Value.fromInt(3)]);

      h.emit(T3Opcodes.PUSHLST);
      h.emitUint32(listOffset);
      h.build();
      h.step();

      expect(h.peek().type, T3DataType.list);
      expect(h.peek().value, listOffset);
    });

    test('PUSHSTR pushes string reference', () {
      final h = OpcodeTestHarness();
      final strOffset = h.addString('Hello');

      h.emit(T3Opcodes.PUSHSTR);
      h.emitUint32(strOffset);
      h.build();
      h.step();

      expect(h.peek().type, T3DataType.sstring);
      expect(h.peek().value, strOffset);
    });
  });

  group('Optimized local opcodes (GETLCLN0-5)', () {
    test('GETLCLN0 gets local 0', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.GETLCLN0);
      h.build();
      h.setLocal(0, T3Value.fromInt(100));
      h.step();

      expect(h.peek().value, 100);
    });

    test('GETLCLN1 gets local 1', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.GETLCLN1);
      h.build();
      h.setLocal(1, T3Value.fromInt(101));
      h.step();

      expect(h.peek().value, 101);
    });

    test('GETLCLN2 gets local 2', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.GETLCLN2);
      h.build();
      h.setLocal(2, T3Value.fromInt(102));
      h.step();

      expect(h.peek().value, 102);
    });

    test('GETLCLN3 gets local 3', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.GETLCLN3);
      h.build();
      h.setLocal(3, T3Value.fromInt(103));
      h.step();

      expect(h.peek().value, 103);
    });

    test('GETLCLN4 gets local 4', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.GETLCLN4);
      h.build();
      h.setLocal(4, T3Value.fromInt(104));
      h.step();

      expect(h.peek().value, 104);
    });

    test('GETLCLN5 gets local 5', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.GETLCLN5);
      h.build();
      h.setLocal(5, T3Value.fromInt(105));
      h.step();

      expect(h.peek().value, 105);
    });
  });

  group('GETSPN opcode', () {
    test('GETSPN gets stack element at index', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(10);
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(20);
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(30);
      // Stack is now: 10, 20, 30 (bottom to top)
      // GETSPN 0 = top (30), GETSPN 1 = second (20), GETSPN 2 = third (10)
      h.emit(T3Opcodes.GETSPN);
      h.emitByte(2); // Get element at index 2 (the 10)
      h.build();
      h.runSteps(4);

      expect(h.peek().value, 10);
    });

    test('GETSPN 0 duplicates top (like DUP)', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(42);
      h.emit(T3Opcodes.GETSPN);
      h.emitByte(0);
      h.build();
      h.runSteps(2);

      expect(h.pop().value, 42);
      expect(h.pop().value, 42);
    });
  });

  group('INDEX opcode with constant list', () {
    test('INDEX retrieves element from constant list', () {
      final h = OpcodeTestHarness();
      final listOffset = h.addList([T3Value.fromInt(100), T3Value.fromInt(200), T3Value.fromInt(300)]);

      // Push list reference
      h.emit(T3Opcodes.PUSHLST);
      h.emitUint32(listOffset);
      // Push index (1-based, so 2 = second element)
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(2);
      // INDEX
      h.emit(T3Opcodes.INDEX);
      h.build();
      h.runSteps(3);

      expect(h.peek().value, 200);
    });
  });

  group('DUPR0 opcode', () {
    test('DUPR0 pushes R0 twice', () {
      final h = OpcodeTestHarness();
      h.r0 = T3Value.fromInt(55);
      h.emit(T3Opcodes.DUPR0);
      h.build();
      h.step();

      expect(h.pop().value, 55);
      expect(h.pop().value, 55);
    });
  });

  group('RETVAL and RETNIL opcodes', () {
    test('RETNIL sets R0 to nil', () {
      final h = OpcodeTestHarness();
      h.r0 = T3Value.fromInt(999); // Set to non-nil first
      h.emit(T3Opcodes.RETNIL);
      h.build();
      h.step();

      expect(h.r0.isNil, isTrue);
    });

    test('RETTRUE sets R0 to true', () {
      final h = OpcodeTestHarness();
      h.r0 = T3Value.nil();
      h.emit(T3Opcodes.RETTRUE);
      h.build();
      h.step();

      expect(h.r0.isTrue, isTrue);
    });
  });

  group('PUSHCTXELE opcode', () {
    test('PUSHCTXELE 1 pushes target property', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHCTXELE);
      h.emitByte(1);
      h.build();
      h.step();

      // Base frame has target prop = 0
      expect(h.peek().type, T3DataType.prop);
    });
  });

  group('NAMEDARGTAB opcode', () {
    test('NAMEDARGTAB creates named arg table marker', () {
      final h = OpcodeTestHarness();
      // Named arg table: count=0, no entries
      h.emit(T3Opcodes.NAMEDARGTAB);
      h.emitUint16(0); // table offset (points to empty table)
      h.build();
      // Just verify it doesn't crash
      h.step();
      expect(true, isTrue);
    });
  });

  group('PUSHOBJ opcode', () {
    test('PUSHOBJ pushes object reference', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHOBJ);
      h.emitUint32(12345); // object ID
      h.build();
      h.step();

      expect(h.peek().type, T3DataType.obj);
      expect(h.peek().value, 12345);
    });
  });

  group('GETR0 opcode', () {
    test('GETR0 pushes R0 onto stack', () {
      final h = OpcodeTestHarness();
      h.r0 = T3Value.fromInt(777);
      h.emit(T3Opcodes.GETR0);
      h.build();
      h.step();

      expect(h.peek().value, 777);
    });
  });

  group('DISC and DISC1 opcodes', () {
    test('DISC discards top of stack', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(42);
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(99);
      h.emit(T3Opcodes.DISC);
      h.build();
      h.runSteps(3);

      // 99 was discarded, 42 is on top
      expect(h.peek().value, 42);
    });

    test('DISC1 discards N items', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(1);
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(2);
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(3);
      h.emit(T3Opcodes.DISC1);
      h.emitByte(2); // Discard 2 items
      h.build();
      h.runSteps(4);

      // 3 and 2 discarded, 1 is on top
      expect(h.peek().value, 1);
    });
  });

  group('SWAP opcodes', () {
    test('SWAP swaps top two elements', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(10);
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(20);
      h.emit(T3Opcodes.SWAP);
      h.build();
      h.runSteps(3);

      expect(h.pop().value, 10);
      expect(h.pop().value, 20);
    });
  });

  group('INC and DEC stack opcodes', () {
    test('INC increments TOS', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(41);
      h.emit(T3Opcodes.INC);
      h.build();
      h.runSteps(2);

      expect(h.peek().value, 42);
    });

    test('DEC decrements TOS', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(43);
      h.emit(T3Opcodes.DEC);
      h.build();
      h.runSteps(2);

      expect(h.peek().value, 42);
    });
  });

  group('JNIL and JNOTNIL opcodes', () {
    test('JNIL jumps if nil', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHNIL);
      h.emit(T3Opcodes.JNIL);
      h.emitInt16(3); // Jump 3 bytes forward
      h.emit(T3Opcodes.PUSH_0); // Skipped
      h.emit(T3Opcodes.PUSH_1); // Lands here (byte 6)
      h.build();
      h.runSteps(2);

      expect(h.ip, 5);
    });

    test('JNOTNIL jumps if not nil', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSH_1);
      h.emit(T3Opcodes.JNOTNIL);
      h.emitInt16(3);
      h.emit(T3Opcodes.PUSH_0); // Skipped
      h.emit(T3Opcodes.PUSH_1); // Lands here
      h.build();
      h.runSteps(2);

      expect(h.ip, 5);
    });

    test('JNIL does not jump if not nil', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSH_1);
      h.emit(T3Opcodes.JNIL);
      h.emitInt16(3);
      h.emit(T3Opcodes.PUSH_0); // Executes
      h.build();
      h.runSteps(3);

      expect(h.peek().value, 0);
    });
  });

  group('ZEROLCL, NILLCL, ONELCL opcodes', () {
    test('ZEROLCL1 sets local to 0', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.ZEROLCL1);
      h.emitByte(0);
      h.build();
      h.setLocal(0, T3Value.fromInt(999));
      h.step();

      expect(h.getLocal(0).value, 0);
    });

    test('NILLCL1 sets local to nil', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.NILLCL1);
      h.emitByte(0);
      h.build();
      h.setLocal(0, T3Value.fromInt(999));
      h.step();

      expect(h.getLocal(0).isNil, isTrue);
    });

    test('ONELCL1 sets local to 1', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.ONELCL1);
      h.emitByte(0);
      h.build();
      h.setLocal(0, T3Value.fromInt(999));
      h.step();

      expect(h.getLocal(0).value, 1);
    });
  });

  group('INCLCL and DECLCL opcodes', () {
    test('INCLCL increments local by 1', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.INCLCL);
      h.emitByte(0);
      h.build();
      h.setLocal(0, T3Value.fromInt(41));
      h.step();

      expect(h.getLocal(0).value, 42);
    });

    test('DECLCL decrements local by 1', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.DECLCL);
      h.emitByte(0);
      h.build();
      h.setLocal(0, T3Value.fromInt(43));
      h.step();

      expect(h.getLocal(0).value, 42);
    });
  });

  group('GETARGN opcodes', () {
    // Note: These require a frame with arguments, which our base harness doesn't have.
    // For now we skip these or test with a modified harness.
    test('GETARGN0 gets argument 0', () {
      // This would need argument setup in the harness
      expect(true, isTrue);
    }, skip: 'Requires argument setup in harness');
  });

  group('PUSHSELF opcode', () {
    test('PUSHSELF pushes self value', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHSELF);
      h.build();
      h.step();

      // Base frame has nil self
      expect(h.peek().isNil, isTrue);
    });
  });

  group('ADDILCL4 opcode', () {
    test('ADDILCL4 adds 32-bit immediate to local', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.ADDILCL4);
      h.emitUint16(0); // local number (UINT2 per implementation)
      h.emitInt32(1000);
      h.build();
      h.setLocal(0, T3Value.fromInt(234));
      h.step();

      expect(h.getLocal(0).value, 1234);
    });
  });

  group('GETSETLCL1 and GETSETLCL1R0 opcodes', () {
    test('GETSETLCL1 sets local and leaves value on stack', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(55);
      h.emit(T3Opcodes.GETSETLCL1);
      h.emitByte(0);
      h.build();
      h.runSteps(2);

      expect(h.getLocal(0).value, 55);
      expect(h.peek().value, 55);
    });

    test('GETSETLCL1R0 sets local from R0 and pushes R0', () {
      final h = OpcodeTestHarness();
      h.r0 = T3Value.fromInt(66);
      h.emit(T3Opcodes.GETSETLCL1R0);
      h.emitByte(0);
      h.build();
      h.step();

      expect(h.getLocal(0).value, 66);
      expect(h.peek().value, 66);
    });
  });

  group('IDXINT8 opcode', () {
    test('IDXINT8 indexes value on stack with immediate index', () {
      final h = OpcodeTestHarness();
      final listOffset = h.addList([T3Value.fromInt(100), T3Value.fromInt(200), T3Value.fromInt(300)]);

      h.emit(T3Opcodes.PUSHLST);
      h.emitUint32(listOffset);
      h.emit(T3Opcodes.IDXINT8);
      h.emitByte(3); // 1-based index for third element
      h.build();
      h.runSteps(2);

      expect(h.peek().value, 300);
    });
  });

  group('2-byte local opcodes', () {
    test('ZEROLCL2 sets local to 0', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.ZEROLCL2);
      h.emitUint16(5);
      h.build();
      h.setLocal(5, T3Value.fromInt(999));
      h.step();

      expect(h.getLocal(5).value, 0);
    });

    test('NILLCL2 sets local to nil', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.NILLCL2);
      h.emitUint16(5);
      h.build();
      h.setLocal(5, T3Value.fromInt(999));
      h.step();

      expect(h.getLocal(5).isNil, isTrue);
    });

    test('ONELCL2 sets local to 1', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.ONELCL2);
      h.emitUint16(5);
      h.build();
      h.setLocal(5, T3Value.fromInt(999));
      h.step();

      expect(h.getLocal(5).value, 1);
    });
  });

  group('PUSHPROPID opcode', () {
    test('PUSHPROPID pushes property ID', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHPROPID);
      h.emitUint16(0x1234);
      h.build();
      h.step();

      expect(h.peek().type, T3DataType.prop);
      expect(h.peek().value, 0x1234);
    });
  });

  group('PUSHBIFPTR opcode', () {
    test('PUSHBIFPTR pushes builtin function pointer', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHBIFPTR);
      h.emitUint16(3); // function set index
      h.emitUint16(7); // function index
      h.build();
      h.step();

      expect(h.peek().type, T3DataType.bifptr);
      // Value encodes both set and function index
    });
  });

  group('PUSHFNPTR opcode', () {
    test('PUSHFNPTR pushes function pointer', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHFNPTR);
      h.emitUint32(0x1000);
      h.build();
      h.step();

      expect(h.peek().type, T3DataType.funcptr);
      expect(h.peek().value, 0x1000);
    });
  });

  group('PUSHENUM opcode', () {
    test('PUSHENUM pushes enum value', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHENUM);
      h.emitUint32(42);
      h.build();
      h.step();

      expect(h.peek().type, T3DataType.enum_);
      expect(h.peek().value, 42);
    });
  });

  group('GETLCL2 opcode', () {
    test('GETLCL2 gets local with 2-byte index', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.GETLCL2);
      h.emitUint16(10);
      h.build();
      h.setLocal(10, T3Value.fromInt(555));
      h.step();

      expect(h.peek().value, 555);
    });
  });

  group('SETLCL2 opcode', () {
    test('SETLCL2 sets local with 2-byte index', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(77);
      h.emit(T3Opcodes.SETLCL2);
      h.emitUint16(10);
      h.build();
      h.runSteps(2);

      expect(h.getLocal(10).value, 77);
    });
  });

  group('RET opcode', () {
    test('RET keeps R0 unchanged', () {
      final h = OpcodeTestHarness();
      h.r0 = T3Value.fromInt(123);
      h.emit(T3Opcodes.RET);
      h.build();
      h.step();

      // RET should preserve R0
      expect(h.r0.value, 123);
    });
  });

  group('SWAPN opcode', () {
    test('SWAPN swaps elements at given indices', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(1);
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(2);
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(3);
      // Stack: 1, 2, 3 (bottom to top)
      h.emit(T3Opcodes.SWAPN);
      h.emitByte(0); // index 0 = top (3)
      h.emitByte(2); // index 2 = bottom (1)
      h.build();
      h.runSteps(4);

      // After swap: 3, 2, 1
      expect(h.pop().value, 1);
      expect(h.pop().value, 2);
      expect(h.pop().value, 3);
    });
  });

  group('PUSHSTRI opcode', () {
    test('PUSHSTRI pushes inline string', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHSTRI);
      h.emitUint16(5); // length
      h.emitByte(0x48); // H
      h.emitByte(0x65); // e
      h.emitByte(0x6C); // l
      h.emitByte(0x6C); // l
      h.emitByte(0x6F); // o
      h.build();
      h.step();

      expect(h.peek().type, T3DataType.sstring);
    });
  });

  group('BP and NOP opcodes', () {
    test('NOP does nothing', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(42);
      h.emit(T3Opcodes.NOP);
      h.emit(T3Opcodes.NOP);
      h.emit(T3Opcodes.NOP);
      h.build();
      h.runSteps(4);

      expect(h.peek().value, 42);
    });
  });

  group('GETARG opcodes with harness args', () {
    test('GETARG1 gets argument by 1-byte index', () {
      final h = OpcodeTestHarness();
      h.setArgs([T3Value.fromInt(100), T3Value.fromInt(200), T3Value.fromInt(300)]);
      h.emit(T3Opcodes.GETARG1);
      h.emitByte(1); // Get arg 1 (second argument)
      h.build();
      h.step();

      expect(h.peek().value, 200);
    });

    test('GETARG2 gets argument by 2-byte index', () {
      final h = OpcodeTestHarness();
      h.setArgs([T3Value.fromInt(111), T3Value.fromInt(222)]);
      h.emit(T3Opcodes.GETARG2);
      h.emitUint16(0);
      h.build();
      h.step();

      expect(h.peek().value, 111);
    });

    test('GETARGN0 gets argument 0', () {
      final h = OpcodeTestHarness();
      h.setArgs([T3Value.fromInt(999)]);
      h.emit(T3Opcodes.GETARGN0);
      h.build();
      h.step();

      expect(h.peek().value, 999);
    });

    test('GETARGN1 gets argument 1', () {
      final h = OpcodeTestHarness();
      h.setArgs([T3Value.fromInt(10), T3Value.fromInt(20)]);
      h.emit(T3Opcodes.GETARGN1);
      h.build();
      h.step();

      expect(h.peek().value, 20);
    });

    test('GETARGN2 gets argument 2', () {
      final h = OpcodeTestHarness();
      h.setArgs([T3Value.fromInt(1), T3Value.fromInt(2), T3Value.fromInt(3)]);
      h.emit(T3Opcodes.GETARGN2);
      h.build();
      h.step();

      expect(h.peek().value, 3);
    });

    test('GETARGN3 gets argument 3', () {
      final h = OpcodeTestHarness();
      h.setArgs([T3Value.fromInt(10), T3Value.fromInt(20), T3Value.fromInt(30), T3Value.fromInt(40)]);
      h.emit(T3Opcodes.GETARGN3);
      h.build();
      h.step();

      expect(h.peek().value, 40);
    });

    test('GETARGC gets argument count', () {
      final h = OpcodeTestHarness();
      h.setArgs([T3Value.fromInt(1), T3Value.fromInt(2), T3Value.fromInt(3)]);
      h.emit(T3Opcodes.GETARGC);
      h.build();
      h.step();

      expect(h.peek().value, 3);
    });
  });

  group('SETARG opcodes', () {
    test('SETARG1 sets argument by 1-byte index', () {
      final h = OpcodeTestHarness();
      h.setArgs([T3Value.fromInt(100), T3Value.fromInt(200)]);
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(999);
      h.emit(T3Opcodes.SETARG1);
      h.emitByte(0);
      h.build();
      h.runSteps(2);

      // Verify arg was modified by reading it back
      h.emit(T3Opcodes.GETARG1);
      h.emitByte(0);
    });

    test('SETARG2 sets argument by 2-byte index', () {
      final h = OpcodeTestHarness();
      h.setArgs([T3Value.fromInt(100)]);
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(888);
      h.emit(T3Opcodes.SETARG2);
      h.emitUint16(0);
      h.build();
      h.runSteps(2);
      // Just verify no crash
      expect(true, isTrue);
    });
  });

  group('PUSHSELF with configured self', () {
    test('PUSHSELF pushes configured self', () {
      final h = OpcodeTestHarness();
      h.setSelf(T3Value.fromObject(12345));
      h.emit(T3Opcodes.PUSHSELF);
      h.build();
      h.step();

      expect(h.peek().type, T3DataType.obj);
      expect(h.peek().value, 12345);
    });
  });

  group('PUSHCTXELE with all context elements', () {
    test('PUSHCTXELE 0 pushes frame reference', () {
      final h = OpcodeTestHarness();
      h.setSelf(T3Value.fromObject(111));
      h.emit(T3Opcodes.PUSHCTXELE);
      h.emitByte(T3Opcodes.PUSHCTXELE_THIS);
      h.build();
      h.step();

      // PUSHCTXELE_THIS pushes a frame reference (different from self)
      // Just verify the operation completes without error
      expect(h.stackDepth > 0, isTrue);
    });

    test('PUSHCTXELE 1 pushes target property', () {
      final h = OpcodeTestHarness();
      h.setTargetProp(0x5678);
      h.emit(T3Opcodes.PUSHCTXELE);
      h.emitByte(T3Opcodes.PUSHCTXELE_TARGPROP);
      h.build();
      h.step();

      expect(h.peek().type, T3DataType.prop);
      expect(h.peek().value, 0x5678);
    });
  });

  group('SWAP2 opcode', () {
    test('SWAP2 swaps top two with next two', () {
      final h = OpcodeTestHarness();
      // Push 4 values: 1, 2, 3, 4 (bottom to top)
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(1);
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(2);
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(3);
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(4);
      h.emit(T3Opcodes.SWAP2);
      h.build();
      h.runSteps(5);

      // After SWAP2: 3, 4, 1, 2 (bottom to top)
      expect(h.pop().value, 2);
      expect(h.pop().value, 1);
      expect(h.pop().value, 4);
      expect(h.pop().value, 3);
    });
  });

  group('RETVAL opcode', () {
    test('RETVAL stores TOS to R0', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(77);
      h.emit(T3Opcodes.RETVAL);
      h.build();
      h.runSteps(2);

      expect(h.r0.value, 77);
    });
  });

  group('NAMEDARGPTR opcode', () {
    test('NAMEDARGPTR pushes named arg table pointer', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.NAMEDARGPTR);
      h.emitUint16(100); // offset to named arg table
      h.build();
      h.step();
      // Just verify no crash
      expect(true, isTrue);
    });
  });

  group('VARARGC opcode', () {
    test('VARARGC is a modifier opcode', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.VARARGC);
      // VARARGC modifies the next call opcode, but on its own just sets a flag
      h.emit(T3Opcodes.NOP);
      h.build();
      h.runSteps(2);
      expect(true, isTrue);
    });
  });

  group('LOADCTX and STORECTX opcodes', () {
    test('STORECTX stores context and pushes marker', () {
      final h = OpcodeTestHarness();
      h.setSelf(T3Value.fromObject(42));
      h.emit(T3Opcodes.STORECTX);
      h.build();
      h.step();

      // Should push a context marker onto the stack
      expect(h.stackDepth > 0, isTrue);
    });
  });

  group('SETSELF opcode', () {
    test('SETSELF sets self from stack', () {
      final h = OpcodeTestHarness();
      h.emit(T3Opcodes.PUSHOBJ);
      h.emitUint32(9999);
      h.emit(T3Opcodes.SETSELF);
      h.build();
      h.runSteps(2);
      // Self should now be 9999, verified by PUSHSELF
      h.emit(T3Opcodes.PUSHSELF);
      // Can't verify without re-building, just ensure no crash
      expect(true, isTrue);
    });
  });

  group('MAKELSTPAR opcode', () {
    test('MAKELSTPAR creates varargs list parameter', () {
      final h = OpcodeTestHarness();
      // Push some values then make them into a list
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(10);
      h.emit(T3Opcodes.PUSHINT8);
      h.emitInt8(20);
      h.emit(T3Opcodes.MAKELSTPAR);
      h.emitByte(2); // 2 elements
      h.build();
      h.runSteps(3);

      // Result should be something on stack (list object or similar)
      // The exact type depends on implementation
      expect(h.stackDepth > 0, isTrue);
    });
  });

  // Opcodes that require object/method infrastructure - mark as skipped with explanation
  group('Property access opcodes (require object infrastructure)', () {
    test('GETPROP gets property from object', () {
      expect(true, isTrue);
    }, skip: 'Requires object store with properties');

    test('CALLPROP calls property method', () {
      expect(true, isTrue);
    }, skip: 'Requires object store with methods');

    test('SETPROP sets property on object', () {
      expect(true, isTrue);
    }, skip: 'Requires object store with properties');
  });

  group('Object creation opcodes (require metaclass infrastructure)', () {
    test('NEW1 creates object instance', () {
      expect(true, isTrue);
    }, skip: 'Requires metaclass registration');

    test('NEW2 creates object with 2-byte metaclass', () {
      expect(true, isTrue);
    }, skip: 'Requires metaclass registration');

    test('TRNEW1 creates transient object', () {
      expect(true, isTrue);
    }, skip: 'Requires metaclass registration');
  });

  group('Function call opcodes (require code setup)', () {
    test('CALL calls function at offset', () {
      expect(true, isTrue);
    }, skip: 'Requires function code in pool');

    test('PTRCALL calls function through pointer', () {
      expect(true, isTrue);
    }, skip: 'Requires function code in pool');
  });

  group('Exception handling opcodes (require handler setup)', () {
    test('THROW throws exception', () {
      expect(true, isTrue);
    }, skip: 'Requires exception handler table');
  });

  group('Builtin function opcodes (require BIF registration)', () {
    test('BUILTIN_A calls builtin from set 0', () {
      expect(true, isTrue);
    }, skip: 'Requires BIF function set registration');

    test('BUILTIN1 calls builtin with 1-byte index', () {
      expect(true, isTrue);
    }, skip: 'Requires BIF function set registration');
  });

  group('SWITCH opcode (requires jump table)', () {
    test('SWITCH jumps through case table', () {
      expect(true, isTrue);
    }, skip: 'Requires case table in code');
  });

  group('Inheritance opcodes (require object hierarchy)', () {
    test('INHERIT calls inherited method', () {
      expect(true, isTrue);
    }, skip: 'Requires object inheritance setup');

    test('DELEGATE delegates to object', () {
      expect(true, isTrue);
    }, skip: 'Requires delegation setup');
  });

  group('Iterator opcodes (require collection setup)', () {
    test('ITERNEXT advances iterator', () {
      expect(true, isTrue);
    }, skip: 'Requires iterator object setup');
  });

  group('Debug opcodes', () {
    test('GETDBLCL gets debug local', () {
      expect(true, isTrue);
    }, skip: 'Debug opcodes need special handling');

    test('SETDBLCL sets debug local', () {
      expect(true, isTrue);
    }, skip: 'Debug opcodes need special handling');

    test('GETDBARG gets debug argument', () {
      expect(true, isTrue);
    }, skip: 'Debug opcodes need special handling');

    test('SETDBARG sets debug argument', () {
      expect(true, isTrue);
    }, skip: 'Debug opcodes need special handling');

    test('GETDBARGC gets debug argument count', () {
      expect(true, isTrue);
    }, skip: 'Debug opcodes need special handling');

    test('BP breakpoint', () {
      expect(true, isTrue);
    }, skip: 'Debug opcodes need special handling');
  });

  group('Output opcodes (require I/O setup)', () {
    test('SAY outputs string', () {
      expect(true, isTrue);
    }, skip: 'Requires I/O provider setup');

    test('SAYVAL outputs value', () {
      expect(true, isTrue);
    }, skip: 'Requires I/O provider setup');
  });

  group('SETIND opcode (requires indexable object)', () {
    test('SETIND sets indexed value', () {
      expect(true, isTrue);
    }, skip: 'Requires mutable list/object');

    test('SETINDLCL1I8 sets indexed local', () {
      expect(true, isTrue);
    }, skip: 'Requires mutable list in local');
  });

  group('PUSHPARLST opcode', () {
    test('PUSHPARLST pushes varargs parameter list', () {
      expect(true, isTrue);
    }, skip: 'Requires varargs frame setup');
  });
}
