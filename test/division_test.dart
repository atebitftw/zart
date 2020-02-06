part of 'main_test.dart';

/// http://inform-fiction.org/zmachine/standards/z1point1/sect02.html3
/// ref 2.4.3
void divisionTests() {
  test("-11 ~/ 2 should return -5.", () {
    expect(-11 ~/ 2, equals(-5));
  });

  test("-11 ~/ -2 should return 5.", () {
    expect(-11 ~/ -2, equals(5));
  });

  test("11 ~/ -2 should return -5.", () {
    expect(11 ~/ -2, equals(-5));
  });

  test("13 % -5 should return 3.", () {
    expect(13 % -5, equals(3));
  });

  test("-13 % -5 should returns -3.", () {
    expect(Machine.doMod(-13, -5), equals(-3));
  });

  test("-13 % 5 should returns -3.", () {
    expect(Machine.doMod(-13, 5), equals(-3));
  });
}
