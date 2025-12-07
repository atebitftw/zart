import 'dart:io';
import 'package:test/test.dart';
import 'package:zart/src/math_helper.dart';
import 'package:zart/zart.dart';

void main() {
  group('Integers', () {
    test("Machine.toSigned(0xFFFF) should return -1.", () {
      stdout.writeln("${0xFFFF}");
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

    test('16-bit signed out of range (-32769) throws GameException', () {
      expect(
        () => MathHelper.dartSignedIntTo16BitSigned(-32769),
        throwsA(
          allOf(
            const TypeMatcher<GameException>(),
            predicate(
              (dynamic e) =>
                  e.msg.startsWith("Signed 16-bit int is out of range"),
            ),
          ),
        ),
      );
    });

    test('16-bit signed out of range (32768) throws GameException', () {
      expect(
        () => MathHelper.dartSignedIntTo16BitSigned(32768),
        throwsA(
          allOf(
            const TypeMatcher<GameException>(),
            predicate(
              (dynamic e) =>
                  e.msg.startsWith("Signed 16-bit int is out of range"),
            ),
          ),
        ),
      );
    });
  });
}
