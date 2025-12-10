import 'package:test/test.dart';
import 'package:zart/src/math_helper.dart';

void main() {
  group('Integers', () {
    test("Machine.toSigned(0xFFFF) should return -1.", () {
      expect(MathHelper.toSigned(0xFFFF), equals(-1));
    });

    test("Machine.toSigned(32767) should return 32767.", () {
      expect(MathHelper.toSigned(32767), equals(32767));
    });

    test(
      "Machine.toSigned(32768) (0x10000 - 32768) should yield signed int -32768.",
      () {
        expect(MathHelper.toSigned(32768), equals(-32768));
      },
    );

    test("Machine.dartSignedIntTo16BitSigned(-1) should return 65535.", () {
      expect(MathHelper.dartSignedIntTo16BitSigned(-1), equals(65535));
    });

    test("Machine.dartSignedIntTo16BitSigned(-32767) should return 32769.", () {
      expect(MathHelper.dartSignedIntTo16BitSigned(-32767), equals(32769));
    });

    test("Machine.dartSignedIntTo16BitSigned(0) should return 0.", () {
      expect(MathHelper.dartSignedIntTo16BitSigned(0), equals(0));
    });

    test("Machine.dartSignedIntTo16BitSigned(42) should return 42.", () {
      expect(42, equals(MathHelper.dartSignedIntTo16BitSigned(42)));
    });

    test("Machine.dartSignedIntTo16BitSigned(-42) should return 65494.", () {
      expect(65494, equals(MathHelper.dartSignedIntTo16BitSigned(-42)));
    });

    test('16-bit signed wraps correctly for -32769 (becomes 32767)', () {
      // Z-Machine spec: values wrap using modular arithmetic
      // -32769 & 0xFFFF = 32767
      expect(MathHelper.dartSignedIntTo16BitSigned(-32769), equals(32767));
    });

    test('16-bit signed wraps correctly for 32768 (stays 32768)', () {
      // Z-Machine spec: values wrap using modular arithmetic
      // 32768 & 0xFFFF = 32768
      expect(MathHelper.dartSignedIntTo16BitSigned(32768), equals(32768));
    });
  });
}
