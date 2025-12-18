import 'package:test/test.dart';
import 'package:zart/src/glulx/glulx_float.dart';

void main() {
  /// Glulx Spec Section 1.6: Floating-Point Numbers
  group('GlulxFloat', () {
    group('32-bit Single Precision', () {
      test('converts known values correctly', () {
        /// Spec Section 1.6 example values:
        /// - 0.0   =  00000000 (S=0, E=00, M=0)
        /// - 1.0   =  3F800000 (S=0, E=7F, M=0)
        /// - −2.0  =  C0000000 (S=1, E=80, M=0)
        /// - 100.0 =  42C80000 (S=0, E=85, M=480000)
        expect(GlulxFloat.fromInt32(0x00000000), equals(0.0));
        expect(GlulxFloat.fromInt32(0x3F800000), equals(1.0));
        expect(GlulxFloat.fromInt32(0xC0000000), equals(-2.0));
        expect(GlulxFloat.fromInt32(0x42C80000), equals(100.0));
      });

      test('roundtrips values correctly', () {
        /// Spec Section 1.6: "Floats have limited precision; they cannot represent all real values exactly."
        /// We use closeTo for non-exact values since single-precision has ~7 decimal digits of precision.
        expect(GlulxFloat.fromInt32(GlulxFloat.toInt32(0.0)), equals(0.0));
        expect(GlulxFloat.fromInt32(GlulxFloat.toInt32(1.0)), equals(1.0));
        expect(GlulxFloat.fromInt32(GlulxFloat.toInt32(-1.0)), equals(-1.0));
        expect(GlulxFloat.fromInt32(GlulxFloat.toInt32(100.0)), equals(100.0));
        expect(GlulxFloat.fromInt32(GlulxFloat.toInt32(-0.5)), equals(-0.5));

        // These values can't be represented exactly in single-precision
        expect(GlulxFloat.fromInt32(GlulxFloat.toInt32(3.14159)), closeTo(3.14159, 1e-5));
      });

      test('detects +Inf correctly', () {
        /// Spec Section 1.6: "+Inf is 7F800000"
        expect(GlulxFloat.isInf32(0x7F800000), isTrue);
        expect(GlulxFloat.isNaN32(0x7F800000), isFalse);
        expect(GlulxFloat.fromInt32(0x7F800000), equals(double.infinity));
      });

      test('detects -Inf correctly', () {
        /// Spec Section 1.6: "-Inf is FF800000"
        expect(GlulxFloat.isInf32(0xFF800000), isTrue);
        expect(GlulxFloat.isNaN32(0xFF800000), isFalse);
        expect(GlulxFloat.fromInt32(0xFF800000), equals(double.negativeInfinity));
      });

      test('detects NaN correctly', () {
        /// Spec Section 1.6: "NaN values are 7F800001 to 7FFFFFFF (+NaN) and FF800001 to FFFFFFFF (-NaN)"
        expect(GlulxFloat.isNaN32(0x7F800001), isTrue);
        expect(GlulxFloat.isNaN32(0x7FFFFFFF), isTrue);
        expect(GlulxFloat.isNaN32(0xFF800001), isTrue);
        expect(GlulxFloat.isNaN32(0xFFFFFFFF), isTrue);

        // These are NOT NaN
        expect(GlulxFloat.isNaN32(0x7F800000), isFalse); // +Inf
        expect(GlulxFloat.isNaN32(0x00000000), isFalse); // +0
      });

      test('detects negative zero correctly', () {
        /// Spec Section 1.6: "−0 is 80000000"
        expect(GlulxFloat.isNegativeZero32(0x80000000), isTrue);
        expect(GlulxFloat.isNegativeZero32(0x00000000), isFalse);
      });

      test('normal values are not special', () {
        expect(GlulxFloat.isNaN32(0x3F800000), isFalse); // 1.0
        expect(GlulxFloat.isInf32(0x3F800000), isFalse);
        expect(GlulxFloat.isNegativeZero32(0x3F800000), isFalse);
      });
    });

    group('64-bit Double Precision', () {
      test('converts known values correctly', () {
        /// Spec Section 1.6.1: Double precision examples
        // 0.0 = 00000000:00000000
        expect(GlulxFloat.fromInt64(0x00000000, 0x00000000), equals(0.0));

        // 1.0 = 3FF00000:00000000
        expect(GlulxFloat.fromInt64(0x3FF00000, 0x00000000), equals(1.0));

        // -1.0 = BFF00000:00000000
        expect(GlulxFloat.fromInt64(0xBFF00000, 0x00000000), equals(-1.0));
      });

      test('roundtrips values correctly', () {
        for (final value in [0.0, 1.0, -1.0, 3.141592653589793, 100.0, -0.5]) {
          final (hi, lo) = GlulxFloat.toInt64(value);
          final restored = GlulxFloat.fromInt64(hi, lo);
          expect(restored, equals(value));
        }
      });

      test('detects +Inf correctly', () {
        /// Spec Section 1.6.1: "+Inf is 7FF00000:00000000"
        expect(GlulxFloat.isInf64(0x7FF00000, 0x00000000), isTrue);
        expect(GlulxFloat.isNaN64(0x7FF00000, 0x00000000), isFalse);
      });

      test('detects -Inf correctly', () {
        /// Spec Section 1.6.1: "-Inf is FFF00000:00000000"
        expect(GlulxFloat.isInf64(0xFFF00000, 0x00000000), isTrue);
        expect(GlulxFloat.isNaN64(0xFFF00000, 0x00000000), isFalse);
      });

      test('detects NaN correctly', () {
        /// Spec Section 1.6.1: NaN has E=7FF and M nonzero
        expect(GlulxFloat.isNaN64(0x7FF00001, 0x00000000), isTrue);
        expect(GlulxFloat.isNaN64(0x7FF00000, 0x00000001), isTrue);
        expect(GlulxFloat.isNaN64(0x7FFFFFFF, 0xFFFFFFFF), isTrue);

        // These are NOT NaN
        expect(GlulxFloat.isNaN64(0x7FF00000, 0x00000000), isFalse); // +Inf
      });

      test('detects negative zero correctly', () {
        expect(GlulxFloat.isNegativeZero64(0x80000000, 0x00000000), isTrue);
        expect(GlulxFloat.isNegativeZero64(0x00000000, 0x00000000), isFalse);
      });
    });
  });
}
