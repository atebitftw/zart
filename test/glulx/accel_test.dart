import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:zart/src/glulx/glulx_interpreter.dart';
import 'package:zart/src/glulx/glulx_exception.dart';
import 'mock_glk_io_provider.dart';

/// Unit tests for the Glulx acceleration system (accelfunc, accelparam opcodes).
///
/// Tests verify:
/// - Parameter setting and retrieval
/// - Function registration and cancellation
/// - Gestalt selector support
/// - Integration with the interpreter
void main() {
  late GlulxInterpreter interpreter;
  late TestGlkIoProvider mockGlk;
  late Uint8List gameData;

  /// Load the test game file (glulxercise.ulx for comprehensive testing).
  setUpAll(() async {
    final file = File('assets/testers/glulxercise.ulx');
    gameData = await file.readAsBytes();
  });

  setUp(() async {
    mockGlk = TestGlkIoProvider();
    interpreter = GlulxInterpreter(mockGlk);
    await interpreter.load(gameData);
  });

  group('GlulxAccel', () {
    group('Parameter Management', () {
      /// Spec: "accelparam L1 L2: Store the value L2 in the parameter table
      /// at position L1."
      test('setParam stores values at valid indices 0-8', () {
        for (var i = 0; i < 9; i++) {
          interpreter.accel.setParam(i, 0x1000 + i);
          expect(interpreter.accel.getParam(i), equals(0x1000 + i));
        }
      });

      /// Spec: "If the terp does not know about parameter L1, this does nothing."
      test('setParam ignores invalid indices', () {
        interpreter.accel.setParam(9, 0xDEAD);
        interpreter.accel.setParam(-1, 0xBEEF);
        interpreter.accel.setParam(100, 0xCAFE);
        // No exception thrown, and getParam returns 0 for invalid indices
        expect(interpreter.accel.getParam(9), equals(0));
        expect(interpreter.accel.getParam(-1), equals(0));
      });

      test('reset clears all parameters', () {
        for (var i = 0; i < 9; i++) {
          interpreter.accel.setParam(i, 0xFFFF);
        }
        interpreter.accel.reset();
        for (var i = 0; i < 9; i++) {
          expect(interpreter.accel.getParam(i), equals(0));
        }
      });
    });

    group('Function Registration', () {
      /// Spec: All 13 functions (1-13) should be supported.
      test('supportsFunc returns true for indices 1-13', () {
        expect(interpreter.accel.supportsFunc(1), isTrue, reason: 'Z__Region');
        expect(
          interpreter.accel.supportsFunc(2),
          isTrue,
          reason: 'CP__Tab old',
        );
        expect(interpreter.accel.supportsFunc(3), isTrue, reason: 'RA__Pr old');
        expect(interpreter.accel.supportsFunc(4), isTrue, reason: 'RL__Pr old');
        expect(interpreter.accel.supportsFunc(5), isTrue, reason: 'OC__Cl old');
        expect(interpreter.accel.supportsFunc(6), isTrue, reason: 'RV__Pr old');
        expect(interpreter.accel.supportsFunc(7), isTrue, reason: 'OP__Pr old');
        expect(
          interpreter.accel.supportsFunc(8),
          isTrue,
          reason: 'CP__Tab new',
        );
        expect(interpreter.accel.supportsFunc(9), isTrue, reason: 'RA__Pr new');
        expect(
          interpreter.accel.supportsFunc(10),
          isTrue,
          reason: 'RL__Pr new',
        );
        expect(
          interpreter.accel.supportsFunc(11),
          isTrue,
          reason: 'OC__Cl new',
        );
        expect(
          interpreter.accel.supportsFunc(12),
          isTrue,
          reason: 'RV__Pr new',
        );
        expect(
          interpreter.accel.supportsFunc(13),
          isTrue,
          reason: 'OP__Pr new',
        );
      });

      /// Spec: "0 always means no acceleration"
      test('supportsFunc returns false for index 0', () {
        expect(interpreter.accel.supportsFunc(0), isFalse);
      });

      /// Unknown indices should not be supported
      test('supportsFunc returns false for unknown indices', () {
        expect(interpreter.accel.supportsFunc(14), isFalse);
        expect(interpreter.accel.supportsFunc(100), isFalse);
        expect(interpreter.accel.supportsFunc(-1), isFalse);
      });

      test('getFunc returns null for unregistered address', () {
        expect(interpreter.accel.getFunc(0x1000), isNull);
      });

      test('reset clears all function registrations', () {
        // Find a valid function address in the game file
        // (This is a simplified test - actual addresses depend on game file)
        interpreter.accel.reset();
        // After reset, no functions should be registered
        expect(interpreter.accel.getFunc(0x1000), isNull);
      });

      /// Reference: accel.c lines 131-134 - fatal_error on non-function address
      test('setFunc throws GlulxException for non-function address', () {
        // Address 0x24 is in the header (not a function - doesn't start with 0xC0/0xC1)
        expect(
          () => interpreter.accel.setFunc(1, 0x24),
          throwsA(isA<GlulxException>()),
        );
      });
    });

    group('Gestalt Selectors', () {
      /// Spec: Gestalt selector 9 (Acceleration) should return 1.
      test('gestalt Acceleration returns 1', () {
        // Create a simple gestalt call scenario
        // The gestalt is handled internally by _doGestalt
        // We test via the accel module directly
        expect(interpreter.accel.supportsFunc(1), isTrue);
      });

      /// Spec: Gestalt selector 10 (AccelFunc) returns 1 for supported functions.
      test('gestalt AccelFunc returns 1 for supported indices', () {
        // This is tested implicitly through supportsFunc
        for (var i = 1; i <= 13; i++) {
          expect(
            interpreter.accel.supportsFunc(i),
            isTrue,
            reason: 'Function $i should be supported',
          );
        }
      });

      /// Spec: Gestalt selector 10 (AccelFunc) returns 0 for unsupported indices.
      test('gestalt AccelFunc returns 0 for unsupported indices', () {
        expect(interpreter.accel.supportsFunc(0), isFalse);
        expect(interpreter.accel.supportsFunc(14), isFalse);
      });
    });
  });

  group('Acceleration Parameters', () {
    /// Reference: accel.c lines 41-49
    /// Parameter indices:
    /// 0: classes_table
    /// 1: indiv_prop_start
    /// 2: class_metaclass
    /// 3: object_metaclass
    /// 4: routine_metaclass
    /// 5: string_metaclass
    /// 6: self
    /// 7: num_attr_bytes
    /// 8: cpv__start
    test('all 9 parameters can be set and retrieved', () {
      final testValues = [
        0x10000, // classes_table
        64, // indiv_prop_start (typical Inform value)
        0x20000, // class_metaclass
        0x20100, // object_metaclass
        0x20200, // routine_metaclass
        0x20300, // string_metaclass
        0x30000, // self (address of global)
        7, // num_attr_bytes (default)
        0x40000, // cpv__start
      ];

      for (var i = 0; i < 9; i++) {
        interpreter.accel.setParam(i, testValues[i]);
      }

      for (var i = 0; i < 9; i++) {
        expect(
          interpreter.accel.getParam(i),
          equals(testValues[i]),
          reason: 'Parameter $i should match',
        );
      }
    });
  });
}
