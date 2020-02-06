part of 'main_test.dart';

void binaryTests() {
  test("0xf should convert to 1111 in binary.", () {
    expect("1111", equals(0xf.toRadixString(2)));
  });

  test(
      "BinaryHelper.binaryOf(0xf) (15 decimal) should be equivalent to .toRadixString(2)",
      () {
    expect(BinaryHelper.binaryOf(0xf), equals(0xf.toRadixString(2)));
  });

  test("BinaryHelper.isSet(0xf) (15 decimal) should return true at position 0",
      () {
    expect(BinaryHelper.isSet(0xf, 0), isTrue);
  });

  test("BinaryHelper.isSet(0xf) (15 decimal) should return true at position 1",
      () {
    expect(BinaryHelper.isSet(0xf, 1), isTrue);
  });

  test("BinaryHelper.isSet(0xf) (15 decimal) should return true at position 2",
      () {
    expect(BinaryHelper.isSet(0xf, 2), isTrue);
  });

  test("BinaryHelper.isSet(0xf) (15 decimal) should return true at position 3",
      () {
    expect(BinaryHelper.isSet(0xf, 3), isTrue);
  });

  test("BinaryHelper.isSet(0xf) (15 decimal) should return false at position 4",
      () {
    expect(BinaryHelper.isSet(0xf, 4), isFalse);
  });

  test("BinaryHelper.isSet(0xf) (15 decimal) should return false at position 5",
      () {
    expect(BinaryHelper.isSet(0xf, 5), isFalse);
  });

  test("BinaryHelper.isSet(0xf) (15 decimal) should return false at position 6",
      () {
    expect(BinaryHelper.isSet(0xf, 6), isFalse);
  });

  test("BinaryHelper.isSet(0xf) (15 decimal) should return false at position 7",
      () {
    expect(BinaryHelper.isSet(0xf, 7), isFalse);
  });

  test("BinaryHelper.binaryOf(0xf0) should return 11110000", () {
    expect(BinaryHelper.binaryOf(0xf0), equals("11110000"));
  });

  test(
      "BinaryHelper.isSet(0xf0) (240 decimal) should return false at position 0",
      () {
    expect(BinaryHelper.isSet(0xf0, 0), isFalse);
  });

  test(
      "BinaryHelper.isSet(0xf0) (240 decimal) should return false at position 1",
      () {
    expect(BinaryHelper.isSet(0xf0, 1), isFalse);
  });

  test(
      "BinaryHelper.isSet(0xf0) (240 decimal) should return false at position 2",
      () {
    expect(BinaryHelper.isSet(0xf0, 2), isFalse);
  });

  test(
      "BinaryHelper.isSet(0xf0) (240 decimal) should return false at position 3",
      () {
    expect(BinaryHelper.isSet(0xf0, 3), isFalse);
  });

  test(
      "BinaryHelper.isSet(0xf0) (240 decimal) should return true at position 4",
      () {
    expect(BinaryHelper.isSet(0xf0, 4), isTrue);
  });

  test(
      "BinaryHelper.isSet(0xf0) (240 decimal) should return true at position 5",
      () {
    expect(BinaryHelper.isSet(0xf0, 5), isTrue);
  });

  test(
      "BinaryHelper.isSet(0xf0) (240 decimal) should return true at position 6",
      () {
    expect(BinaryHelper.isSet(0xf0, 6), isTrue);
  });

  test(
      "BinaryHelper.isSet(0xf0) (240 decimal) should return true at position 7",
      () {
    expect(BinaryHelper.isSet(0xf0, 7), isTrue);
  });

  test(
      'BinaryHelper.bottomBits() properly returns 24 from the bottom 6 bits of 88.',
      () {
    expect(BinaryHelper.bottomBits(88, 6), equals(24));
    //stringify as well and test
    expect(BinaryHelper.binaryOf(BinaryHelper.bottomBits(88, 6)),
        equals(BinaryHelper.binaryOf(24)));
  });

  test("BinaryHelper.setBottomBits(4) properly returns 15 (0xf).", () {
    expect(BinaryHelper.setBottomBits(4), equals(0xf));
  });

  test("BinaryHelper.set(0,0) returns 1.", () {
    expect(BinaryHelper.set(0, 0), equals(1));
  });

  test("BinaryHelper.set(0,8) returns 2^8 (256).", () {
    expect(BinaryHelper.set(0, 8), equals(256));
  });

  test("BinaryHelper.set(0,16) returns 2^16 (65536).", () {
    expect(BinaryHelper.set(0, 16), equals(65536));
  });

  test("BinaryHelper.set(0,32) returns 2^32 (4294967296).", () {
    expect(BinaryHelper.set(0, 32), equals(4294967296));
  });

  test("BinaryHelper.unset(0xff, 0) returns 0xfe", () {
    expect(BinaryHelper.unset(0xff, 0), equals(0xfe));
  });

  test("BinaryHelper.unset(0xff, 1) returns 0xfd", () {
    expect(BinaryHelper.unset(0xff, 1), equals(0xfd));
  });

  test("BinaryHelper.unset(256, 8) returns 0.", () {
    expect(BinaryHelper.unset(256, 8), equals(0));
  });

  test("BinaryHelper.unset(65536, 16) returns 0.", () {
    expect(BinaryHelper.unset(65536, 16), equals(0));
  });

  test("BinaryHelper.unset(4294967296, 32) returns 0.", () {
    expect(BinaryHelper.unset(4294967296, 32), equals(0));
  });
}
