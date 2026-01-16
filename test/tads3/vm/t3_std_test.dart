// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_std.dart';

void main() {
  group('Type Constants', () {
    test('int16 constants are correct', () {
      expect(int16MaxVal, equals(32767));
      expect(int16MinVal, equals(-32768));
      expect(uint16MaxVal, equals(65535));
    });

    test('int32 constants are correct', () {
      expect(int32MaxVal, equals(2147483647));
      expect(int32MinVal, equals(-2147483648));
      expect(uint32MaxVal, equals(4294967295));
    });
  });

  group('Bit Shift Operations', () {
    group('t3Ashr (Arithmetic Right Shift)', () {
      test('shifts positive values correctly', () {
        expect(t3Ashr(8, 1), equals(4));
        expect(t3Ashr(16, 2), equals(4));
        expect(t3Ashr(100, 3), equals(12));
      });

      test('shifts negative values with sign extension', () {
        expect(t3Ashr(-8, 1), equals(-4));
        expect(t3Ashr(-16, 2), equals(-4));
        expect(t3Ashr(-100, 3), equals(-13));
      });

      test('shift by 0 returns original value', () {
        expect(t3Ashr(42, 0), equals(42));
        expect(t3Ashr(-42, 0), equals(-42));
      });

      test('large shifts work correctly', () {
        expect(t3Ashr(0x7FFFFFFF, 31), equals(0));
        expect(t3Ashr(-1, 31), equals(-1));
      });
    });

    group('t3Lshr (Logical Right Shift)', () {
      test('shifts positive values correctly', () {
        expect(t3Lshr(8, 1), equals(4));
        expect(t3Lshr(16, 2), equals(4));
        expect(t3Lshr(100, 3), equals(12));
      });

      test('shifts negative values with zero fill', () {
        // -8 in 32-bit two's complement is 0xFFFFFFF8
        // Logical shift right by 1 should give 0x7FFFFFFC = 2147483644
        expect(t3Lshr(-8, 1), equals(2147483644));

        // -1 is 0xFFFFFFFF, shift right by 1 gives 0x7FFFFFFF
        expect(t3Lshr(-1, 1), equals(2147483647));
      });

      test('shift by 0 returns original value', () {
        expect(t3Lshr(42, 0), equals(42));
      });

      test('large shifts work correctly', () {
        expect(t3Lshr(0xFFFFFFFF, 31), equals(1));
        expect(t3Lshr(0x80000000, 31), equals(1));
      });
    });
  });

  group('String Utilities', () {
    group('libStrcpy', () {
      test('copies full string when length >= string length', () {
        expect(libStrcpy('hello', 10), equals('hello'));
        expect(libStrcpy('hello', 5), equals('hello'));
      });

      test('truncates string when length < string length', () {
        expect(libStrcpy('hello', 3), equals('hel'));
        expect(libStrcpy('hello', 1), equals('h'));
      });

      test('returns empty string for zero or negative length', () {
        expect(libStrcpy('hello', 0), equals(''));
        expect(libStrcpy('hello', -1), equals(''));
      });
    });

    group('libStrcmp', () {
      test('returns 0 for equal strings', () {
        expect(libStrcmp('hello', 5, 'hello', 5), equals(0));
        expect(libStrcmp('test', 4, 'test', 4), equals(0));
      });

      test('returns negative when first string is less', () {
        expect(libStrcmp('abc', 3, 'xyz', 3), lessThan(0));
        expect(libStrcmp('hello', 5, 'world', 5), lessThan(0));
      });

      test('returns positive when first string is greater', () {
        expect(libStrcmp('xyz', 3, 'abc', 3), greaterThan(0));
        expect(libStrcmp('world', 5, 'hello', 5), greaterThan(0));
      });

      test('compares by length when prefixes are equal', () {
        expect(libStrcmp('hello', 5, 'hello', 3), greaterThan(0));
        expect(libStrcmp('hello', 3, 'hello', 5), lessThan(0));
      });

      test('respects length limits', () {
        expect(libStrcmp('hello', 3, 'help', 3), equals(0)); // Both truncate to 'hel'
        expect(libStrcmp('hello', 2, 'help', 2), equals(0)); // Both truncate to 'he'
      });
    });

    group('libStricmp', () {
      test('returns 0 for equal strings (case-insensitive)', () {
        expect(libStricmp('hello', 5, 'HELLO', 5), equals(0));
        expect(libStricmp('TeSt', 4, 'test', 4), equals(0));
      });

      test('returns negative when first string is less', () {
        expect(libStricmp('abc', 3, 'XYZ', 3), lessThan(0));
      });

      test('returns positive when first string is greater', () {
        expect(libStricmp('XYZ', 3, 'abc', 3), greaterThan(0));
      });
    });

    group('libStrnchr', () {
      test('finds character within length limit', () {
        expect(libStrnchr('hello', 5, 'e'.codeUnitAt(0)), equals(1));
        expect(libStrnchr('hello', 5, 'l'.codeUnitAt(0)), equals(2));
        expect(libStrnchr('hello', 5, 'o'.codeUnitAt(0)), equals(4));
      });

      test('returns -1 when character not found', () {
        expect(libStrnchr('hello', 5, 'x'.codeUnitAt(0)), equals(-1));
        expect(libStrnchr('hello', 5, 'z'.codeUnitAt(0)), equals(-1));
      });

      test('respects length limit', () {
        expect(libStrnchr('hello', 2, 'l'.codeUnitAt(0)), equals(-1)); // 'l' is at index 2
        expect(libStrnchr('hello', 3, 'l'.codeUnitAt(0)), equals(2)); // Now we can find it
      });

      test('handles empty string', () {
        expect(libStrnchr('', 5, 'a'.codeUnitAt(0)), equals(-1));
      });
    });

    group('libAtoi', () {
      test('parses valid integers', () {
        expect(libAtoi('123', 3), equals(123));
        expect(libAtoi('456', 3), equals(456));
        expect(libAtoi('-789', 4), equals(-789));
      });

      test('respects length limit', () {
        expect(libAtoi('12345', 3), equals(123));
        expect(libAtoi('12345', 2), equals(12));
      });

      test('returns 0 for invalid input', () {
        expect(libAtoi('abc', 3), equals(0));
        expect(libAtoi('', 0), equals(0));
        expect(libAtoi('xyz', 3), equals(0));
      });

      test('handles whitespace', () {
        expect(libAtoi('  123  ', 7), equals(123));
        expect(libAtoi('  -456  ', 8), equals(-456));
      });
    });

    group('libStrequalCollapseSpaces', () {
      test('returns true for identical strings', () {
        expect(libStrequalCollapseSpaces('hello', 5, 'hello', 5), isTrue);
      });

      test('returns true when only whitespace amount differs', () {
        expect(libStrequalCollapseSpaces('log in', 6, 'log  in', 7), isTrue);
        expect(libStrequalCollapseSpaces('a b c', 5, 'a  b  c', 7), isTrue);
      });

      test('returns false when whitespace presence differs', () {
        expect(libStrequalCollapseSpaces('login', 5, 'log in', 6), isFalse);
        expect(libStrequalCollapseSpaces('abc', 3, 'a bc', 4), isFalse);
      });

      test('returns false for different strings', () {
        expect(libStrequalCollapseSpaces('hello', 5, 'world', 5), isFalse);
      });
    });
  });

  group('Character Classification', () {
    test('isAscii identifies ASCII characters', () {
      expect(isAscii(0), isTrue);
      expect(isAscii(65), isTrue); // 'A'
      expect(isAscii(127), isTrue);
      expect(isAscii(128), isFalse);
      expect(isAscii(255), isFalse);
    });

    test('isSpace identifies whitespace', () {
      expect(isSpace(0x20), isTrue); // space
      expect(isSpace(0x09), isTrue); // tab
      expect(isSpace(0x0A), isTrue); // newline
      expect(isSpace(0x0D), isTrue); // carriage return
      expect(isSpace('A'.codeUnitAt(0)), isFalse);
    });

    test('isAlpha identifies alphabetic characters', () {
      expect(isAlpha('A'.codeUnitAt(0)), isTrue);
      expect(isAlpha('Z'.codeUnitAt(0)), isTrue);
      expect(isAlpha('a'.codeUnitAt(0)), isTrue);
      expect(isAlpha('z'.codeUnitAt(0)), isTrue);
      expect(isAlpha('0'.codeUnitAt(0)), isFalse);
      expect(isAlpha('!'.codeUnitAt(0)), isFalse);
    });

    test('isDigit identifies decimal digits', () {
      expect(isDigit('0'.codeUnitAt(0)), isTrue);
      expect(isDigit('5'.codeUnitAt(0)), isTrue);
      expect(isDigit('9'.codeUnitAt(0)), isTrue);
      expect(isDigit('a'.codeUnitAt(0)), isFalse);
      expect(isDigit('A'.codeUnitAt(0)), isFalse);
    });

    test('isOdigit identifies octal digits', () {
      expect(isOdigit('0'.codeUnitAt(0)), isTrue);
      expect(isOdigit('7'.codeUnitAt(0)), isTrue);
      expect(isOdigit('8'.codeUnitAt(0)), isFalse);
      expect(isOdigit('9'.codeUnitAt(0)), isFalse);
    });

    test('isXdigit identifies hex digits', () {
      expect(isXdigit('0'.codeUnitAt(0)), isTrue);
      expect(isXdigit('9'.codeUnitAt(0)), isTrue);
      expect(isXdigit('a'.codeUnitAt(0)), isTrue);
      expect(isXdigit('f'.codeUnitAt(0)), isTrue);
      expect(isXdigit('A'.codeUnitAt(0)), isTrue);
      expect(isXdigit('F'.codeUnitAt(0)), isTrue);
      expect(isXdigit('g'.codeUnitAt(0)), isFalse);
      expect(isXdigit('G'.codeUnitAt(0)), isFalse);
    });

    test('valueOfDigit returns correct values', () {
      expect(valueOfDigit('0'.codeUnitAt(0)), equals(0));
      expect(valueOfDigit('5'.codeUnitAt(0)), equals(5));
      expect(valueOfDigit('9'.codeUnitAt(0)), equals(9));
    });

    test('valueOfXdigit returns correct values', () {
      expect(valueOfXdigit('0'.codeUnitAt(0)), equals(0));
      expect(valueOfXdigit('9'.codeUnitAt(0)), equals(9));
      expect(valueOfXdigit('a'.codeUnitAt(0)), equals(10));
      expect(valueOfXdigit('f'.codeUnitAt(0)), equals(15));
      expect(valueOfXdigit('A'.codeUnitAt(0)), equals(10));
      expect(valueOfXdigit('F'.codeUnitAt(0)), equals(15));
    });

    test('intToXdigit converts numbers to hex digits', () {
      expect(intToXdigit(0), equals('0'));
      expect(intToXdigit(9), equals('9'));
      expect(intToXdigit(10), equals('A'));
      expect(intToXdigit(15), equals('F'));
      expect(intToXdigit(16), equals('?')); // Out of range
      expect(intToXdigit(-1), equals('?')); // Out of range
    });

    test('byteToXdigits converts bytes to hex pairs', () {
      expect(byteToXdigits(0), equals('00'));
      expect(byteToXdigits(15), equals('0F'));
      expect(byteToXdigits(255), equals('FF'));
      expect(byteToXdigits(0xAB), equals('AB'));
    });

    test('isSyminit identifies symbol initial characters', () {
      expect(isSyminit('_'.codeUnitAt(0)), isTrue);
      expect(isSyminit('a'.codeUnitAt(0)), isTrue);
      expect(isSyminit('Z'.codeUnitAt(0)), isTrue);
      expect(isSyminit('0'.codeUnitAt(0)), isFalse);
      expect(isSyminit('!'.codeUnitAt(0)), isFalse);
    });

    test('isSym identifies symbol characters', () {
      expect(isSym('_'.codeUnitAt(0)), isTrue);
      expect(isSym('a'.codeUnitAt(0)), isTrue);
      expect(isSym('Z'.codeUnitAt(0)), isTrue);
      expect(isSym('0'.codeUnitAt(0)), isTrue);
      expect(isSym('9'.codeUnitAt(0)), isTrue);
      expect(isSym('!'.codeUnitAt(0)), isFalse);
      expect(isSym(' '.codeUnitAt(0)), isFalse);
    });

    test('isLower identifies lowercase characters', () {
      expect(isLower('a'.codeUnitAt(0)), isTrue);
      expect(isLower('z'.codeUnitAt(0)), isTrue);
      expect(isLower('A'.codeUnitAt(0)), isFalse);
      expect(isLower('Z'.codeUnitAt(0)), isFalse);
      expect(isLower('0'.codeUnitAt(0)), isFalse);
    });

    test('toUpper converts to uppercase', () {
      expect(toUpper('a'.codeUnitAt(0)), equals('A'.codeUnitAt(0)));
      expect(toUpper('z'.codeUnitAt(0)), equals('Z'.codeUnitAt(0)));
      expect(toUpper('A'.codeUnitAt(0)), equals('A'.codeUnitAt(0)));
      expect(toUpper('0'.codeUnitAt(0)), equals('0'.codeUnitAt(0)));
    });

    test('toLower converts to lowercase', () {
      expect(toLower('A'.codeUnitAt(0)), equals('a'.codeUnitAt(0)));
      expect(toLower('Z'.codeUnitAt(0)), equals('z'.codeUnitAt(0)));
      expect(toLower('a'.codeUnitAt(0)), equals('a'.codeUnitAt(0)));
      expect(toLower('0'.codeUnitAt(0)), equals('0'.codeUnitAt(0)));
    });
  });

  group('T3ArrayList', () {
    test('starts empty', () {
      final list = T3ArrayList<int>();
      expect(list.count, equals(0));
    });

    test('addElement increases count', () {
      final list = T3ArrayList<int>();
      list.addElement(1);
      expect(list.count, equals(1));
      list.addElement(2);
      expect(list.count, equals(2));
    });

    test('can retrieve added elements', () {
      final list = T3ArrayList<int>();
      list.addElement(42);
      list.addElement(99);
      expect(list[0], equals(42));
      expect(list[1], equals(99));
    });

    test('findElement returns correct index', () {
      final list = T3ArrayList<String>();
      list.addElement('hello');
      list.addElement('world');
      list.addElement('test');

      expect(list.findElement('hello'), equals(0));
      expect(list.findElement('world'), equals(1));
      expect(list.findElement('test'), equals(2));
      expect(list.findElement('missing'), equals(-1));
    });

    test('removeElement removes by value', () {
      final list = T3ArrayList<int>();
      list.addElement(1);
      list.addElement(2);
      list.addElement(3);

      expect(list.removeElement(2), isTrue);
      expect(list.count, equals(2));
      expect(list[0], equals(1));
      expect(list[1], equals(3));

      expect(list.removeElement(99), isFalse);
      expect(list.count, equals(2));
    });

    test('removeAt removes by index', () {
      final list = T3ArrayList<String>();
      list.addElement('a');
      list.addElement('b');
      list.addElement('c');

      list.removeAt(1);
      expect(list.count, equals(2));
      expect(list[0], equals('a'));
      expect(list[1], equals('c'));
    });

    test('clear empties the list', () {
      final list = T3ArrayList<int>();
      list.addElement(1);
      list.addElement(2);
      list.addElement(3);

      list.clear();
      expect(list.count, equals(0));
    });

    test('expands automatically beyond initial size', () {
      final list = T3ArrayList<int>.withSize(2, 2);

      // Add more than initial size
      for (int i = 0; i < 10; i++) {
        list.addElement(i);
      }

      expect(list.count, equals(10));
      for (int i = 0; i < 10; i++) {
        expect(list[i], equals(i));
      }
    });

    test('supports different types', () {
      final intList = T3ArrayList<int>();
      intList.addElement(42);
      expect(intList[0], equals(42));

      final stringList = T3ArrayList<String>();
      stringList.addElement('test');
      expect(stringList[0], equals('test'));

      final boolList = T3ArrayList<bool>();
      boolList.addElement(true);
      expect(boolList[0], isTrue);
    });
  });
}
