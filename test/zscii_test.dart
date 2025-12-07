import 'package:test/test.dart';
import 'package:zart/src/zscii.dart';
import 'package:zart/zart.dart';
import 'test_utils.dart';

void main() {
  setupZMachine();

  group('ZSCII Tests>', () {
    test("ZSCII.ZCharToChar(0) returns empty string''.", () {
      expect(ZSCII.zCharToChar(0), equals(""));
    });

    test("ZSCII.ZCharToChar(9) returns tab \\t.", () {
      expect(ZSCII.zCharToChar(9), equals('\t'));
    });

    test("ZSCII.ZCharToChar(11) returns double space '  '.", () {
      expect(ZSCII.zCharToChar(11), equals("  "));
    });

    test("ZSCII.ZCharToChar(13) returns newline \\n.", () {
      expect(ZSCII.zCharToChar(13), equals('\n'));
    });

    test("ZSCII.ZCharToChar(32-126) returns expected letter.", () {
      const String ascii =
          " !\"#\$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~";
      for (var i = 0; i < 95; i++) {
        expect(ZSCII.zCharToChar(i + 32), equals(ascii[i]));
      }
    });

    test('Unicode translations work as expected in ZSCII.ZCharToChar().', () {
      var s = StringBuffer();
      for (int i = 155; i <= 223; i++) {
        s.writeCharCode(unicodeTranslations[i]!);
        expect(ZSCII.zCharToChar(i), equals(s.toString()));
        s.clear();
      }
    });

    test('ZSCII.readZString() returns the expected string from the address.', () {
      var addrStart = 0xb0a0;
      var addrEnd = 0xb0be;
      var testString = 'An old leather bag, bulging with coins, is here.';
      expect(ZSCII.readZString(addrStart), equals(testString));

      // address after string end should be at 0xb0be
      expect(Z.engine.callStack.pop(), equals(addrEnd));
    });
  });
}
