import 'package:test/test.dart';
import 'package:zart/src/glulx/glulx_binary_helper.dart';

void main() {
  /// Tests for GlulxBinaryHelper - JavaScript-safe 32-bit operations.
  /// Reference: JAVASCRIPT_COMPATIBILITY.md test cases
  group('GlulxBinaryHelper', () {
    // ========== toU32 Tests ==========
    group('toU32', () {
      test('wraps at 32-bit boundary', () {
        /// JAVASCRIPT_COMPATIBILITY.md: "0xFFFFFFFF + 1 should = 0"
        expect(GlulxBinaryHelper.toU32(0xFFFFFFFF + 1), equals(0));
      });

      test('handles large multiplication overflow', () {
        /// JAVASCRIPT_COMPATIBILITY.md: "0x80000000 * 2 should = 0"
        expect(GlulxBinaryHelper.toU32(0x80000000 * 2), equals(0));
      });

      test('converts -1 to 0xFFFFFFFF', () {
        /// JAVASCRIPT_COMPATIBILITY.md: "-1 should = 0xFFFFFFFF"
        expect(GlulxBinaryHelper.toU32(-1), equals(0xFFFFFFFF));
      });

      test('converts -0 to 0', () {
        /// JAVASCRIPT_COMPATIBILITY.md: "-0 should = 0"
        expect(GlulxBinaryHelper.toU32(-0), equals(0));
      });

      test('preserves high bit value', () {
        /// Values with bit 31 set should be preserved as unsigned
        expect(GlulxBinaryHelper.toU32(0x80000000), equals(0x80000000));
      });

      test('preserves max unsigned value', () {
        expect(GlulxBinaryHelper.toU32(0xFFFFFFFF), equals(0xFFFFFFFF));
      });

      test('preserves zero', () {
        expect(GlulxBinaryHelper.toU32(0), equals(0));
      });

      test('preserves positive values', () {
        expect(GlulxBinaryHelper.toU32(42), equals(42));
        expect(GlulxBinaryHelper.toU32(0x7FFFFFFF), equals(0x7FFFFFFF));
      });
    });

    // ========== Arithmetic Tests ==========
    group('add32', () {
      test('basic addition', () {
        expect(GlulxBinaryHelper.add32(5, 7), equals(12));
      });

      test('wraps at 32-bit boundary', () {
        /// Spec Section 2.4.1: "Truncate the result to 32 bits if necessary."
        expect(GlulxBinaryHelper.add32(0xFFFFFFFF, 1), equals(0));
      });

      test('handles values near max', () {
        expect(GlulxBinaryHelper.add32(0xFFFFFFFE, 1), equals(0xFFFFFFFF));
      });
    });

    group('sub32', () {
      test('basic subtraction', () {
        expect(GlulxBinaryHelper.sub32(10, 3), equals(7));
      });

      test('wraps to high value on underflow', () {
        /// 0 - 1 = 0xFFFFFFFF (two's complement)
        expect(GlulxBinaryHelper.sub32(0, 1), equals(0xFFFFFFFF));
      });
    });

    group('mul32', () {
      test('basic multiplication', () {
        expect(GlulxBinaryHelper.mul32(6, 7), equals(42));
      });

      test('wraps at 32-bit boundary', () {
        /// Spec Section 2.4.1: "Truncate the result to 32 bits if necessary."
        expect(GlulxBinaryHelper.mul32(0x80000000, 2), equals(0));
      });

      test('handles high bit multiplication', () {
        /// 0x10000 * 0x10000 = 0x100000000 → 0
        expect(GlulxBinaryHelper.mul32(0x10000, 0x10000), equals(0));
      });
    });

    group('neg32', () {
      test('negates positive value', () {
        /// Spec Section 2.4.1: "neg L1 S1: Compute the negative of L1."
        expect(GlulxBinaryHelper.neg32(5), equals(0xFFFFFFFB));
      });

      test('negates 1 to 0xFFFFFFFF', () {
        expect(GlulxBinaryHelper.neg32(1), equals(0xFFFFFFFF));
      });

      test('negates 0 to 0', () {
        expect(GlulxBinaryHelper.neg32(0), equals(0));
      });

      test('double negation returns original', () {
        expect(GlulxBinaryHelper.neg32(GlulxBinaryHelper.neg32(42)), equals(42));
      });
    });

    // ========== Bitwise Tests ==========
    group('and32', () {
      test('computes bitwise AND', () {
        /// Spec Section 2.4.2: "bitand L1 L2 S1: Compute the bitwise AND of L1 and L2."
        expect(GlulxBinaryHelper.and32(0xFF00, 0x0FF0), equals(0x0F00));
      });

      test('handles high bit set', () {
        /// Critical JS test: values with bit 31 set
        expect(GlulxBinaryHelper.and32(0x80000000, 0xFFFFFFFF), equals(0x80000000));
      });

      test('AND with 0 yields 0', () {
        expect(GlulxBinaryHelper.and32(0xFFFFFFFF, 0), equals(0));
      });

      test('AND with 0xFFFFFFFF yields original', () {
        expect(GlulxBinaryHelper.and32(0xDEADBEEF, 0xFFFFFFFF), equals(0xDEADBEEF));
      });
    });

    group('or32', () {
      test('computes bitwise OR', () {
        /// Spec Section 2.4.2: "bitor L1 L2 S1: Compute the bitwise OR of L1 and L2."
        expect(GlulxBinaryHelper.or32(0xFF00, 0x00FF), equals(0xFFFF));
      });

      test('handles high bit set', () {
        expect(GlulxBinaryHelper.or32(0x80000000, 0x00000001), equals(0x80000001));
      });

      test('OR with 0 yields original', () {
        expect(GlulxBinaryHelper.or32(0xDEADBEEF, 0), equals(0xDEADBEEF));
      });
    });

    group('xor32', () {
      test('computes bitwise XOR', () {
        /// Spec Section 2.4.2: "bitxor L1 L2 S1: Compute the bitwise XOR of L1 and L2."
        expect(GlulxBinaryHelper.xor32(0xFF00, 0xFFFF), equals(0x00FF));
      });

      test('XOR with self yields 0', () {
        expect(GlulxBinaryHelper.xor32(0xDEADBEEF, 0xDEADBEEF), equals(0));
      });

      test('XOR with 0 yields original', () {
        expect(GlulxBinaryHelper.xor32(0x80000000, 0), equals(0x80000000));
      });
    });

    group('not32', () {
      test('computes bitwise NOT', () {
        /// Spec Section 2.4.2: "bitnot L1 S1: Compute the bitwise negation of L1."
        expect(GlulxBinaryHelper.not32(0x00000000), equals(0xFFFFFFFF));
      });

      test('inverts all bits', () {
        expect(GlulxBinaryHelper.not32(0xAAAAAAAA), equals(0x55555555));
      });

      test('double NOT returns original', () {
        expect(GlulxBinaryHelper.not32(GlulxBinaryHelper.not32(0x12345678)), equals(0x12345678));
      });

      test('handles max value', () {
        expect(GlulxBinaryHelper.not32(0xFFFFFFFF), equals(0));
      });
    });

    // ========== Shift Tests ==========
    group('shl32', () {
      test('shifts left basic', () {
        /// Spec Section 2.4.2: "shiftl L1 L2 S1: Shift the bits of L1 to the left by L2 places."
        expect(GlulxBinaryHelper.shl32(1, 4), equals(16));
      });

      test('shift into high bit', () {
        expect(GlulxBinaryHelper.shl32(1, 31), equals(0x80000000));
      });

      test('returns 0 if shift >= 32', () {
        /// Spec Section 2.4.2: "If L2 is 32 or more, the result is always zero."
        expect(GlulxBinaryHelper.shl32(0xFFFFFFFF, 32), equals(0));
        expect(GlulxBinaryHelper.shl32(0xFFFFFFFF, 33), equals(0));
        expect(GlulxBinaryHelper.shl32(0xFFFFFFFF, 100), equals(0));
      });

      test('shift by 0 returns original', () {
        expect(GlulxBinaryHelper.shl32(0xDEADBEEF, 0), equals(0xDEADBEEF));
      });

      test('truncates bits shifted past 32', () {
        /// 0x80000000 << 1 = 0x100000000 → 0
        expect(GlulxBinaryHelper.shl32(0x80000000, 1), equals(0));
      });
    });

    group('shr32', () {
      test('shifts right unsigned basic', () {
        /// Spec Section 2.4.2: "ushiftr L1 L2 S1: Shift bits right, fill with zeroes."
        expect(GlulxBinaryHelper.shr32(16, 4), equals(1));
      });

      test('fills with zeroes (unsigned)', () {
        /// 0x80000000 >> 4 = 0x08000000 (not 0xF8000000)
        expect(GlulxBinaryHelper.shr32(0x80000000, 4), equals(0x08000000));
      });

      test('returns 0 if shift >= 32', () {
        /// Spec Section 2.4.2: "If L2 is 32 or more, the result is always zero."
        expect(GlulxBinaryHelper.shr32(0xFFFFFFFF, 32), equals(0));
        expect(GlulxBinaryHelper.shr32(0xFFFFFFFF, 33), equals(0));
      });

      test('shift by 0 returns original', () {
        expect(GlulxBinaryHelper.shr32(0xDEADBEEF, 0), equals(0xDEADBEEF));
      });
    });

    group('sar32', () {
      test('shifts right with sign extension (positive)', () {
        /// Spec Section 2.4.2: "sshiftr: Fill top bits with copies of the top bit of L1."
        /// 0x7FFFFFFF >> 4 = 0x07FFFFFF (top bit 0 → fill with 0)
        expect(GlulxBinaryHelper.sar32(0x7FFFFFFF, 4), equals(0x07FFFFFF));
      });

      test('shifts right with sign extension (negative)', () {
        /// 0x80000000 >> 4 = 0xF8000000 (top bit 1 → fill with 1)
        expect(GlulxBinaryHelper.sar32(0x80000000, 4), equals(0xF8000000));
      });

      test('returns 0 if shift >= 32 and positive', () {
        /// Spec Section 2.4.2: "If L2 is 32 or more, result is 0 or FFFFFFFF."
        expect(GlulxBinaryHelper.sar32(0x7FFFFFFF, 32), equals(0));
      });

      test('returns 0xFFFFFFFF if shift >= 32 and negative', () {
        expect(GlulxBinaryHelper.sar32(0x80000000, 32), equals(0xFFFFFFFF));
        expect(GlulxBinaryHelper.sar32(0xFFFFFFFF, 32), equals(0xFFFFFFFF));
      });

      test('shift by 0 returns original', () {
        expect(GlulxBinaryHelper.sar32(0xDEADBEEF, 0), equals(0xDEADBEEF));
      });
    });

    // ========== Edge Cases for JavaScript Compatibility ==========
    group('JavaScript edge cases', () {
      test('xoshiro multiplier 0x85EBCA6B', () {
        /// From xoshiro128.dart line 57: s * 0x85EBCA6B
        /// This tests large constant multiplication
        final s = 0x12345678;
        final result = GlulxBinaryHelper.mul32(s, 0x85EBCA6B);
        // Result should be a valid 32-bit value (not overflow or negative in JS)
        expect(result, lessThanOrEqualTo(0xFFFFFFFF));
        expect(result, greaterThanOrEqualTo(0));
      });

      test('xoshiro multiplier 0xC2B2AE35', () {
        /// From xoshiro128.dart line 59: s * 0xC2B2AE35
        final s = 0x12345678;
        final result = GlulxBinaryHelper.mul32(s, 0xC2B2AE35);
        expect(result, lessThanOrEqualTo(0xFFFFFFFF));
        expect(result, greaterThanOrEqualTo(0));
      });

      test('xoshiro addend 0x9E3779B9', () {
        /// From xoshiro128.dart line 54: seed + 0x9E3779B9
        final seed = 0xFFFFFFFF;
        final result = GlulxBinaryHelper.add32(seed, 0x9E3779B9);
        expect(result, lessThanOrEqualTo(0xFFFFFFFF));
        expect(result, greaterThanOrEqualTo(0));
      });

      test('value near 2^31 boundary', () {
        /// Test values near the JavaScript 32-bit signed boundary
        expect(GlulxBinaryHelper.toU32(0x7FFFFFFF), equals(0x7FFFFFFF));
        expect(GlulxBinaryHelper.toU32(0x80000000), equals(0x80000000));
        expect(GlulxBinaryHelper.add32(0x7FFFFFFF, 1), equals(0x80000000));
      });

      test('bitwise AND with negative-looking result in JS', () {
        /// In JS: (0x80000000 & 0x80000000) could return -2147483648
        /// We need 0x80000000 (2147483648)
        expect(GlulxBinaryHelper.and32(0x80000000, 0x80000000), equals(0x80000000));
      });

      test('rotl pattern (used in xoshiro)', () {
        /// rotl(x, k) => (x << k) | (x >> (32 - k))
        /// Test the pattern from xoshiro128.dart
        final x = 0x12345678;
        const k = 7;
        final rotl = GlulxBinaryHelper.or32(GlulxBinaryHelper.shl32(x, k), GlulxBinaryHelper.shr32(x, 32 - k));
        // Manual calculation: (0x12345678 << 7) | (0x12345678 >> 25)
        expect(rotl, equals(0x1A2B3C09));
      });
    });
  });
}
