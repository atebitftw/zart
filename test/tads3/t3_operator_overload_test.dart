import 'package:zart/src/tads3/vm/t3_opcodes.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';
import 'opcode_test_harness.dart';
import 'package:test/test.dart';

/// T3 Operator Overloading unit tests with spec validation.
///
/// Spec Reference: packages/tads-sources/t3doc/techman/t3spec/opcode.htm#opov
/// Starting with December 2010 revision (3.1), certain operators can be overloaded.
void main() {
  group('Operator overloading per opcode.htm#opov', () {
    /// opcode.htm:390-581 - Operator overloading mechanism.
    group('overloadable operators', () {
      /// Binary addition operator (+)
      test('operator + affects ADD, INC, INCLCL, ADDILCL1, ADDILCL4, ADDTOLCL', () {
        // Import symbol: 'operator +'
        expect(T3Opcodes.ADD, 0x22);
        expect(T3Opcodes.INC, 0x2E);
        expect(T3Opcodes.INCLCL, 0xD0);
        expect(T3Opcodes.ADDILCL1, 0xD2);
        expect(T3Opcodes.ADDILCL4, 0xD3);
        expect(T3Opcodes.ADDTOLCL, 0xD4);
      });

      /// Binary subtraction operator (-)
      test('operator - affects SUB, DEC, DECLCL, SUBFROMLCL', () {
        // Import symbol: 'operator -'
        expect(T3Opcodes.SUB, 0x23);
        expect(T3Opcodes.DEC, 0x2F);
        expect(T3Opcodes.DECLCL, 0xD1);
        expect(T3Opcodes.SUBFROMLCL, 0xD5);
      });

      /// Binary multiplication operator (*)
      test('operator * affects MUL', () {
        // Import symbol: 'operator *'
        expect(T3Opcodes.MUL, 0x24);
      });

      /// Binary division operator (/)
      test('operator / affects DIV', () {
        // Import symbol: 'operator /'
        expect(T3Opcodes.DIV, 0x2A);
      });

      /// Binary modulo operator (%)
      test('operator % affects MOD', () {
        // Import symbol: 'operator %'
        expect(T3Opcodes.MOD, 0x2B);
      });

      /// Binary XOR operator (^)
      test('operator ^ affects XOR', () {
        // Import symbol: 'operator ^'
        expect(T3Opcodes.XOR, 0x29);
      });

      /// Binary left-shift operator (<<)
      test('operator << affects SHL', () {
        // Import symbol: 'operator <<'
        expect(T3Opcodes.SHL, 0x27);
      });

      /// Binary arithmetic right-shift operator (>>)
      test('operator >> affects ASHR', () {
        // Import symbol: 'operator >>'
        expect(T3Opcodes.ASHR, 0x28);
      });

      /// Binary logical right-shift operator (>>>)
      test('operator >>> affects LSHR', () {
        // Import symbol: 'operator >>>'
        expect(T3Opcodes.LSHR, 0x30);
      });

      /// Unary bitwise NOT operator (~)
      test('operator ~ affects BNOT', () {
        // Import symbol: 'operator ~'
        expect(T3Opcodes.BNOT, 0x21);
      });

      /// Binary bitwise OR operator (|)
      test('operator | affects BOR', () {
        // Import symbol: 'operator |'
        expect(T3Opcodes.BOR, 0x26);
      });

      /// Binary bitwise AND operator (&)
      test('operator & affects BAND', () {
        // Import symbol: 'operator &'
        expect(T3Opcodes.BAND, 0x25);
      });

      /// Unary arithmetic negation operator (negate)
      test('operator negate affects NEG', () {
        // Import symbol: 'operator negate'
        expect(T3Opcodes.NEG, 0x20);
      });

      /// Binary indexing operator ([])
      test('operator [] affects INDEX, IDXLCL1INT8, IDXINT8', () {
        // Import symbol: 'operator []'
        expect(T3Opcodes.INDEX, 0xBA);
        expect(T3Opcodes.IDXLCL1INT8, 0xBB);
        expect(T3Opcodes.IDXINT8, 0xBC);
      });

      /// Ternary index-and-assign operator ([]=)
      test('operator []= affects SETIND, SETINDLCL1I8', () {
        // Import symbol: 'operator []='
        expect(T3Opcodes.SETIND, 0xE4);
        expect(T3Opcodes.SETINDLCL1I8, 0xEF);
      });
    });

    /// opcode.htm:509-522 - Zero performance impact design.
    group('operator overloading mechanism', () {
      test('native operators tried first', () {
        // Native handling before overloading check
        expect(true, isTrue);
      }, skip: 'DISCREPANCY: native operator priority not tested');

      test('overloading only on type mismatch', () {
        // Only invoked if no valid native handling
        expect(true, isTrue);
      }, skip: 'DISCREPANCY: type mismatch trigger not tested');

      test('controlling operand must be object', () {
        // opcode.htm:535-536
        expect(true, isTrue);
      }, skip: 'DISCREPANCY: controlling operand check not tested');

      test('operator property lookup via import symbol', () {
        // opcode.htm:538-541
        expect(true, isTrue);
      }, skip: 'DISCREPANCY: operator property lookup not tested');
    });

    /// opcode.htm:559-580 - Implementation via GETPROP.
    group('operator method invocation', () {
      test('call operator property on objects', () {
        final h = OpcodeTestHarness();

        // 1. Setup symbol 'operator +' mapping to prop 100
        h.interpreter.addGlobalSymbol('operator +', T3Value.fromProp(100));

        // 2. Create object
        final objId = h.interpreter.objectTable.createDynamicObject('tads-object', [], isTransient: false);

        // 3. Main test code: result = obj + 10
        h.emit(T3Opcodes.PUSHOBJ);
        h.emitUint32(objId);
        h.emit(T3Opcodes.PUSHINT8);
        h.emitByte(10);
        h.emit(T3Opcodes.ADD);
        h.emit(T3Opcodes.RETVAL);

        // 3. Add function for the operator elsewhere
        final funcOfs = h.currentOffset;

        // Header: 1 arg, 0 locals, no varargs
        h.addFunction([0x01, 0, 0, 0, 0, 0, 0, 0, 0, 0]);

        // Implementation of operator+(val): return val + 42
        h.emit(T3Opcodes.GETARGN0, offset: funcOfs + 10);
        h.emit(T3Opcodes.PUSHINT8);
        h.emitByte(42);
        h.emit(T3Opcodes.ADD);
        h.emit(T3Opcodes.RETVAL);

        // 4. Update the object's property to point to the correct offset
        h.interpreter.setPropertyValue(T3Value.fromObject(objId), 100, T3Value.fromCodeOffset(funcOfs));

        h.build();

        // Since ADD is overloaded, it will perform a SUB-CALL.
        // runUntilReturn should continue through the sub-call and return only when the main frame returns.
        h.runUntilReturn();

        expect(h.r0.value, 52);
      });
    });
  });

  group('List-like objects per opcode.htm#listlike', () {
    /// opcode.htm:583-606 - Definition of list-like objects.
    group('list-like object criteria', () {
      test('must define operator [] property', () {
        // Import symbol: 'operator []'
        expect(true, isTrue);
      }, skip: 'DISCREPANCY: operator [] check not tested');

      test('must define length property', () {
        // Import symbol: 'length'
        expect(true, isTrue);
      }, skip: 'DISCREPANCY: length property check not tested');

      test('length returns non-negative integer', () {
        expect(true, isTrue);
      }, skip: 'DISCREPANCY: length return type not tested');
    });

    /// MAKELSTPAR instruction behavior with list-like objects.
    group('MAKELSTPAR with list-like objects', () {
      test('MAKELSTPAR opcode constant', () {
        expect(T3Opcodes.MAKELSTPAR, 0x0E);
      });

      test('treats list-like objects as lists', () {
        expect(true, isTrue);
      }, skip: 'DISCREPANCY: MAKELSTPAR list-like handling not tested');
    });
  });
}
