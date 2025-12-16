import 'package:test/test.dart';
import 'package:zart/src/z_machine/zscii.dart';
import 'package:zart/zart.dart';
import '../test_utils.dart';

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

    test(
      'ZSCII.readZString() returns the expected string from the address.',
      () {
        var addrStart = 0xb0a0;
        var addrEnd = 0xb0be;
        var testString = 'An old leather bag, bulging with coins, is here.';
        expect(ZSCII.readZString(addrStart), equals(testString));

        // address after string end should be at 0xb0be
        expect(Z.engine.callStack.pop(), equals(addrEnd));
      },
    );
  });

  test(
    'ZSCII.readZString() handles Space Space Abbreviation1 (0 0 1) correctly.',
    () {
      // Setup
      // 1. Define "YOU" abbreviation string at a safe address (e.g. end of mem - 20)
      //    "YOU" -> Y(30), O(20), U(26).
      //    Word = (30<<10) | (20<<5) | 26 = 31386.
      //    With terminator: 0x8000 | 31386 = 0xFA9A.
      //    Note: Ensure even address.
      int abbrevStringAddr = (Z.engine.mem.size - 20) & ~1;
      Z.engine.mem.storew(abbrevStringAddr, 0xFA9A);

      // 2. Point Abbreviation 1 (Set 1, Index 0) to this string.
      //    Abbrev table address:
      int abbrevTableBase = Z.engine.mem.loadw(Header.abbreviationsTableAddr);
      //    Entry 0 is at abbrevTableBase.
      //    Value is word address (byte address / 2).
      Z.engine.mem.storew(abbrevTableBase, abbrevStringAddr ~/ 2);

      // 3. Create Z-String with "Space Space Abbrev1:0" at another safe address.
      //    Word 1: Space Space Abbrev1 (0, 0, 1) -> 0x0001.
      //    Word 2: Index 0, Pad, Pad (0, 5, 5). 0<<10 | 5<<5 | 5 = 165.
      //    With terminator: 0x80A5.
      int textStringAddr = (Z.engine.mem.size - 10) & ~1;
      Z.engine.mem.storew(textStringAddr, 0x0001);
      Z.engine.mem.storew(textStringAddr + 2, 0x80A5);

      // Act
      String result = ZSCII.readZString(textStringAddr);
      Z.engine.callStack.pop();

      // Assert
      // Should be "  YOU"
      expect(result, equals("  you"));
    },
  );
}
