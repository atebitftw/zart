import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_registers.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';

/// T3 Registers unit tests with TADS 3 specification validation.
///
/// Spec Reference: packages/tads-sources/t3doc/techman/t3spec/model.htm
/// - "Machine Registers" section (lines 1112-1155)
void main() {
  group('T3Registers per spec', () {
    late T3Registers registers;

    setUp(() {
      registers = T3Registers();
    });

    /// Spec: model.htm lines 1115-1116:
    /// "The T3 VM has several 'registers' which control the state of
    /// the machine."
    test('initial state is all zeros/nil', () {
      expect(registers.r0.isNil, isTrue);
      expect(registers.ip, 0);
      expect(registers.ep, 0);
      expect(registers.currentSavepoint, 0);
      expect(registers.savepointCount, 0);
    });

    /// Spec: model.htm lines 1119-1123:
    /// "Data Register 0 (R0): this register is used for temporary storage
    /// of data values. This register can contain any value that can be
    /// stored in a stack location. The Return Value (RETVAL) instruction,
    /// for example, stores the return value of a function in this register."
    group('R0 register', () {
      test('can store any T3Value type', () {
        registers.r0 = T3Value.fromInt(42);
        expect(registers.r0.value, 42);
        expect(registers.r0.isInt, isTrue);

        registers.r0 = T3Value.fromObject(100);
        expect(registers.r0.value, 100);
        expect(registers.r0.isObject, isTrue);

        registers.r0 = T3Value.fromProp(50);
        expect(registers.r0.isProp, isTrue);

        registers.r0 = T3Value.nil();
        expect(registers.r0.isNil, isTrue);

        registers.r0 = T3Value.true_();
        expect(registers.r0.isTrue, isTrue);
      });

      test('is used for function return values', () {
        // RETVAL instruction stores result in R0
        registers.r0 = T3Value.fromInt(999);
        expect(registers.r0.value, 999);
      });
    });

    /// Spec: model.htm lines 1126-1127:
    /// "Instruction pointer (IP): this register points to the next byte of
    /// byte-code to be interpreted by the VM execution engine."
    group('IP register', () {
      test('can store code pool offset', () {
        registers.ip = 0x1234;
        expect(registers.ip, 0x1234);
      });

      test('can be incremented during execution', () {
        registers.ip = 100;
        registers.ip++;
        expect(registers.ip, 101);
      });
    });

    /// Spec: model.htm lines 1130-1136:
    /// "Entry pointer (EP): this register points to the entrypoint of the
    /// current function. This allows us to calculate the offset of any given
    /// instruction within the function from the start of the function, which
    /// allows us to find any given instruction within certain tables that
    /// describe the function; in particular, exception tables and debugging
    /// tables specify information on ranges of instructions, stored relative
    /// to the start of the function."
    group('EP register', () {
      test('stores function entrypoint offset', () {
        registers.ep = 0x5678;
        expect(registers.ep, 0x5678);
      });

      test('used to calculate instruction offset within function', () {
        registers.ep = 1000;
        registers.ip = 1025;
        final offsetWithinFunction = registers.ip - registers.ep;
        expect(offsetWithinFunction, 25);
      });
    });

    /// Spec: model.htm lines 1139-1143:
    /// "Stack pointer (SP): this register points at any given time to the
    /// next free element of the machine stack. A 'push' operation stores
    /// a value at the stack location to which this register points, and
    /// then increments the register. A 'pop' operation decrements this
    /// register, then retrieves the value at the stack location to which
    /// it points."
    /// Note: SP is managed by T3Stack, not T3Registers directly.
    group('SP register (conceptual)', () {
      test('SP is managed by T3Stack class', () {
        // SP is not directly in T3Registers - it's in T3Stack
        // This test documents where to find it
        expect(true, isTrue); // Placeholder - SP tested in t3_stack_test.dart
      });
    });

    /// Spec: model.htm lines 1146-1148:
    /// "Frame pointer (FP): this register points to the current stack frame.
    /// See the section on stack organization for details on how the frame
    /// pointer is used."
    /// Note: FP is managed by T3Stack, not T3Registers directly.
    group('FP register (conceptual)', () {
      test('FP is managed by T3Stack class', () {
        // FP is not directly in T3Registers - it's in T3Stack
        // This test documents where to find it
        expect(true, isTrue); // Placeholder - FP tested in t3_stack_test.dart
      });
    });

    /// Spec: model.htm lines 1151-1154:
    /// "Current Savepoint: this register is used for undo operations."
    /// "Savepoint Count: this register is used for undo operations."
    group('Savepoint registers', () {
      test('currentSavepoint for undo operations', () {
        registers.currentSavepoint = 5;
        expect(registers.currentSavepoint, 5);
      });

      test('savepointCount tracks total savepoints', () {
        registers.savepointCount = 10;
        expect(registers.savepointCount, 10);
      });

      test('savepoints can be incremented', () {
        registers.currentSavepoint = 0;
        registers.savepointCount = 0;

        // Simulate savepoint operation
        registers.savepointCount++;
        registers.currentSavepoint = registers.savepointCount;

        expect(registers.currentSavepoint, 1);
        expect(registers.savepointCount, 1);
      });
    });
  });

  group('T3Registers operations', () {
    late T3Registers registers;

    setUp(() {
      registers = T3Registers();
    });

    /// Spec: Restart requires resetting machine state.
    test('reset clears all registers', () {
      registers.r0 = T3Value.fromInt(42);
      registers.ip = 0x1234;
      registers.ep = 0x5678;
      registers.currentSavepoint = 5;
      registers.savepointCount = 10;

      registers.reset();

      expect(registers.r0.isNil, isTrue);
      expect(registers.ip, 0);
      expect(registers.ep, 0);
      expect(registers.currentSavepoint, 0);
      expect(registers.savepointCount, 0);
    });

    /// Spec: Save/restore game requires preserving register state.
    test('save creates independent snapshot', () {
      registers.r0 = T3Value.fromInt(42);
      registers.ip = 0x1234;
      registers.ep = 0x5678;

      final snapshot = registers.save();

      // Modify originals
      registers.r0 = T3Value.fromInt(100);
      registers.ip = 999;

      // Snapshot unchanged
      expect(snapshot.r0.value, 42);
      expect(snapshot.ip, 0x1234);
    });

    /// Spec: Restore game applies saved state.
    test('restore applies snapshot', () {
      registers.r0 = T3Value.fromInt(42);
      registers.ip = 0x1234;
      registers.ep = 0x5678;
      final snapshot = registers.save();

      registers.reset();
      registers.restore(snapshot);

      expect(registers.r0.value, 42);
      expect(registers.ip, 0x1234);
      expect(registers.ep, 0x5678);
    });
  });

  group('T3RegisterSnapshot', () {
    /// Spec: Snapshots preserve all register values.
    test('preserves all register values', () {
      final snapshot = T3RegisterSnapshot(
        r0: T3Value.fromInt(42),
        ip: 100,
        ep: 200,
        currentSavepoint: 1,
        savepointCount: 2,
      );

      expect(snapshot.r0.value, 42);
      expect(snapshot.ip, 100);
      expect(snapshot.ep, 200);
      expect(snapshot.currentSavepoint, 1);
      expect(snapshot.savepointCount, 2);
    });
  });
}
