import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_registers.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';

void main() {
  group('T3Registers', () {
    late T3Registers registers;

    setUp(() {
      registers = T3Registers();
    });

    test('initial state is all zeros/nil', () {
      expect(registers.r0.isNil, isTrue);
      expect(registers.ip, 0);
      expect(registers.ep, 0);
      expect(registers.currentSavepoint, 0);
      expect(registers.savepointCount, 0);
    });

    test('registers can be set and read', () {
      registers.r0 = T3Value.fromInt(42);
      registers.ip = 0x1234;
      registers.ep = 0x5678;
      registers.currentSavepoint = 5;
      registers.savepointCount = 10;

      expect(registers.r0.value, 42);
      expect(registers.ip, 0x1234);
      expect(registers.ep, 0x5678);
      expect(registers.currentSavepoint, 5);
      expect(registers.savepointCount, 10);
    });

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

    test('save creates snapshot', () {
      registers.r0 = T3Value.fromInt(42);
      registers.ip = 0x1234;
      registers.ep = 0x5678;
      registers.currentSavepoint = 5;
      registers.savepointCount = 10;

      final snapshot = registers.save();

      expect(snapshot.r0.value, 42);
      expect(snapshot.ip, 0x1234);
      expect(snapshot.ep, 0x5678);
      expect(snapshot.currentSavepoint, 5);
      expect(snapshot.savepointCount, 10);
    });

    test('save snapshot is independent of registers', () {
      registers.r0 = T3Value.fromInt(42);
      final snapshot = registers.save();

      registers.r0 = T3Value.fromInt(100);
      registers.ip = 999;

      expect(snapshot.r0.value, 42);
      expect(snapshot.ip, 0);
    });

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

    test('toString provides useful debug info', () {
      registers.r0 = T3Value.fromInt(42);
      registers.ip = 0x1234;
      registers.ep = 0x5678;

      final str = registers.toString();
      expect(str, contains('r0'));
      expect(str, contains('ip'));
      expect(str, contains('1234'));
    });
  });

  group('T3RegisterSnapshot', () {
    test('is immutable', () {
      final snapshot = T3RegisterSnapshot(
        r0: T3Value.fromInt(42),
        ip: 100,
        ep: 200,
        currentSavepoint: 1,
        savepointCount: 2,
      );

      // Attempting to modify snapshot.r0 shouldn't affect original
      // (this test just verifies the values are preserved)
      expect(snapshot.r0.value, 42);
      expect(snapshot.ip, 100);
      expect(snapshot.ep, 200);
      expect(snapshot.currentSavepoint, 1);
      expect(snapshot.savepointCount, 2);
    });
  });
}
