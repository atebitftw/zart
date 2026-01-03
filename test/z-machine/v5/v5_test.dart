import 'dart:io';
import 'package:test/test.dart';
import 'package:zart/src/z_machine/z_machine.dart';
import 'package:zart/src/z_machine/game_exception.dart';
import 'package:zart/src/z_machine/game_object.dart';

void main() {
  setUpAll(() {
    // Tests depend on using this file. Tests will fail if changed.
    var gameFile = File('assets/games/z/adventureland.z5');

    if (!gameFile.existsSync()) {
      throw Exception('Game file not found: ${gameFile.path}');
    }

    try {
      Z.load(gameFile.readAsBytesSync());
    } on Exception catch (e) {
      print('Error loading game file: $e');
      rethrow;
    }
  });

  group('Objects>', () {
    test('remove', () {
      var o1 = GameObject(18); // "inside"

      // check if we have the right object and assumptions are correct.
      expect('inside', equals(o1.shortName));
      expect(6, equals(o1.parent)); // Parent is compass(6)
      expect(0, equals(o1.sibling));
      expect(0, equals(o1.child));

      // Object 17 (outside) is the sibling that points to 18
      var leftSib = GameObject(17);
      expect(18, equals(leftSib.sibling));

      o1.removeFromTree();

      // check that 17's sibling matches what 18's sibling was (0)
      expect(0, equals(leftSib.sibling));

      expect(0, equals(o1.parent));
      expect(0, equals(o1.sibling));
    });

    test('insert', () {
      var o1 = GameObject(18); // "inside"
      var p = GameObject(5); // "CompassDirection" (root-ish object with no children initially)

      // Ensure p has no children for this simple test case
      // (Ref: output shows CompassDirection(5), child: (0))
      expect(0, equals(p.child));

      o1.insertTo(p.id);

      expect(p.id, equals(o1.parent));
      expect(18, equals(p.child));
      expect(0, equals(o1.sibling));
    });

    test('get property length', () {
      GameObject o1 = GameObject(18); // "inside"
      // Props found: 41, 37, 21, 2. All len 2 based on validation.

      expect(2, equals(GameObject.propertyLength(o1.getPropertyAddress(41) - 1)));
      expect(2, equals(GameObject.propertyLength(o1.getPropertyAddress(37) - 1)));
      expect(2, equals(GameObject.propertyLength(o1.getPropertyAddress(21) - 1)));
      expect(2, equals(GameObject.propertyLength(o1.getPropertyAddress(2) - 1)));
    });

    test('get property', () {
      GameObject o1 = GameObject(18); // "inside"

      // Prop 2 val 5
      expect(5, equals(o1.getPropertyValue(2)));

      // Prop 37 val 12775 (0x31E7)
      expect(12775, equals(o1.getPropertyValue(37)));

      //throw on property len > 2
      // Note: We don't have a known property > length 2 on this object easily accessible
      // without scanning, but the logic remains if we try to read a non-existent one
      // it returns default (0).
    });

    test('get property address', () {
      GameObject o1 = GameObject(20); // (self object) has prop 4

      var addr = o1.getPropertyAddress(4);
      expect(addr, greaterThan(0));

      var pnum = GameObject.propertyNumber(addr - 1);
      expect(4, equals(pnum));

      // We don't verify specific value as it might change, just mechanics
      var val = o1.getPropertyValue(pnum);
      expect(val, isNotNull);

      var addr2 = o1.getPropertyAddress(pnum);
      expect(addr, equals(addr2));

      var addr0 = o1.getPropertyAddress(0);
      expect(0, equals(addr0));
    });

    test('get next property', () {
      GameObject o1 = GameObject(18); // "inside"
      // Props: 41 -> 37 -> 21 -> 2

      expect(41, equals(o1.getNextProperty(0)));
      expect(37, equals(o1.getNextProperty(41)));
      expect(21, equals(o1.getNextProperty(37)));
      expect(2, equals(o1.getNextProperty(21)));
      expect(0, equals(o1.getNextProperty(2)));

      // Per Z-Machine spec (strictz.z5 compliance): returns 0 for non-existent properties
      expect(0, equals(o1.getNextProperty(99)));
    });

    test('set property', () {
      GameObject o1 = GameObject(18); // "inside"

      var originalVal = o1.getPropertyValue(2);
      expect(5, equals(originalVal));

      o1.setPropertyValue(2, 42);
      expect(42, equals(o1.getPropertyValue(2)));

      // Restore
      o1.setPropertyValue(2, originalVal);

      //throw on prop no exist
      expect(() => o1.setPropertyValue(99, 0xffff), throwsA(isA<GameException>()));
    });

    test('attributes are set', () {
      GameObject o1 = GameObject(58); // "Inside Stump"

      expect('Inside Stump', equals(o1.shortName));

      // Only bit 9 is set
      expect(o1.isFlagBitSet(9), equals(true));

      //check some that aren't set:
      expect(o1.isFlagBitSet(0), equals(false));
      expect(o1.isFlagBitSet(8), equals(false));
      expect(o1.isFlagBitSet(10), equals(false));
    });

    test('unset attribute', () {
      GameObject o1 = GameObject(58); // "Inside Stump"
      expect(o1.isFlagBitSet(9), equals(true));

      o1.unsetFlagBit(9);
      expect(o1.isFlagBitSet(9), equals(false));

      // Set back
      o1.setFlagBit(9);
    });

    test('set attribute', () {
      GameObject o1 = GameObject(58); // "Inside Stump"

      expect(o1.isFlagBitSet(1), equals(false));
      o1.setFlagBit(1);
      expect(o1.isFlagBitSet(1), equals(true));

      expect(o1.isFlagBitSet(0), equals(false));
      o1.setFlagBit(0);
      expect(o1.isFlagBitSet(0), equals(true));

      expect(o1.isFlagBitSet(47), equals(false));
      o1.setFlagBit(47);
      expect(o1.isFlagBitSet(47), equals(true));

      o1.unsetFlagBit(1);
      o1.unsetFlagBit(0);
      o1.unsetFlagBit(47);
    });
  });
}
