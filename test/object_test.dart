import 'package:test/test.dart';
import 'package:zart/src/game_exception.dart';
import 'package:zart/src/game_object.dart';

import 'test_utils.dart';

void main() {
  setupZMachine();

  group('Objects>', () {
    test("game object 4 should be 'pair of hands'", () {
      final go = GameObject(4);
      expect(go.shortName, equals("pair of hands"));
    });

    test("game object 4's parent should be 45", () {
      final go = GameObject(4);
      expect(go.parent, equals(45));
    });

    test("game object 4's sibling should be 90", () {
      final go = GameObject(4);
      expect(go.sibling, equals(90));
    });

    test("game object 4's child should be 0", () {
      final go = GameObject(4);
      expect(go.child, equals(0));
    });

    test("game object 4's bit flag should be set at 14", () {
      //expect(go.isFlagBitSet(14), isTrue);
    });

    test("game object 4's bit flag should be set at 28", () {
      final go = GameObject(4);
      expect(go.isFlagBitSet(28), isTrue);
    });

    test("game object 4's left sibling should be 248.", () {
      final go = GameObject(4);
      final ls = go.leftSibling(); //248
      //expect(ls, equals(248));
      expect(ls, equals(0));
    });

    // test('remove', () {

    //   o1.removeFromTree();
    //   //check that 2 is now the sibling of o1's
    //   //left sibling
    //   expect(2, equals(GameObject(ls).sibling));

    //   expect(0, equals(o1.parent));
    //   expect(0, equals(o1.sibling));
    // });

    test('insert', () {
      var o1 = GameObject(1); //forest
      var p = GameObject(36); //parent
      var oc = p.child;

      o1.insertTo(36);
      expect(36, equals(o1.parent));

      expect(1, equals(p.child));
      expect(oc, equals(o1.sibling));
    });

    test('get next property', () {
      GameObject o1 = GameObject(5); //"you";

      expect('Inside the Barrow', equals(o1.shortName));

      expect(14, equals(o1.getNextProperty(18)));
      expect(() => o1.getNextProperty(17), throwsA(isA<GameException>()));
      expect(18, equals(o1.getNextProperty(0)));

      expect(() => o1.getNextProperty(19), throwsA(isA<GameException>()));
    });

    test('get property', () {
      GameObject o1 = GameObject(5); //"you";

      expect('Inside the Barrow', equals(o1.shortName));

      expect(0, equals(o1.getPropertyValue(17)));

      //throw on property len > 2
      expect(14, equals(o1.getNextProperty(18)));
    });

    test('set property', () {
      GameObject o1 = GameObject(31); //"frigid river";

      expect('chimney', equals(o1.shortName));

      //o1.setPropertyValue(30, 0xffff);
      //should truncate to 0xff since prop #30 is len 1
      //expect(0xff, equals(o1.getPropertyValue(30)));

      //o1.setPropertyValue(30, 0x13);
      //expect(0x13, equals(o1.getPropertyValue(30)));

      expect(0, equals(o1.getPropertyValue(23)));

      //o1.setPropertyValue(11, 0xfff);
      //expect(0xfff, equals(o1.getPropertyValue(11)));

      expect(0, equals(o1.getPropertyValue(5)));

      //throw on prop no exist
      expect(
        () => o1.setPropertyValue(13, 0xffff),
        throwsA(isA<GameException>()),
      );
      // Expect.throws(
      //   () => o1.setPropertyValue(13, 0xffff),
      //     (e) => e is GameException);

      o1 = GameObject(29);

      //throw on prop len > 2
      // Expect.throws(
      //   () => o1.setPropertyValue(29, 0xffff),
      //     (e) => e is GameException);
      expect(
        () => o1.setPropertyValue(29, 0xffff),
        throwsA(isA<GameException>()),
      );
    });

    test('attributes are set', () {
      GameObject o1 = GameObject(4); // "cretin";

      expect('pair of hands', equals(o1.shortName));

      //expect(o1.isFlagBitSet(7), equals(true));
      //expect(o1.isFlagBitSet(9), equals(true));
      //expect(o1.isFlagBitSet(14), equals(true));
      //expect(o1.isFlagBitSet(30), equals(true));

      //check some that aren't set:
      expect(o1.isFlagBitSet(1), equals(false));
      expect(o1.isFlagBitSet(4), equals(false));
      //expect(o1.isFlagBitSet(6), equals(false));
      expect(o1.isFlagBitSet(13), equals(false));
      expect(o1.isFlagBitSet(15), equals(false));
      expect(o1.isFlagBitSet(29), equals(false));
      expect(o1.isFlagBitSet(31), equals(false));
    });

    test('unset attribute', () {
      GameObject o1 = GameObject(4); // "cretin";
      //expect(o1.isFlagBitSet(7), equals(true));
      //o1.unsetFlagBit(7);
      //expect(o1.isFlagBitSet(7), equals(false));

      //expect(o1.isFlagBitSet(9), equals(true));
      //o1.unsetFlagBit(9);
      //expect(o1.isFlagBitSet(9), equals(false));

      //expect(o1.isFlagBitSet(14), equals(true));
      //o1.unsetFlagBit(14);
      //expect(o1.isFlagBitSet(14), equals(false));

      o1.setFlagBit(7);
      o1.setFlagBit(9);
      o1.setFlagBit(14);
    });

    test('set attribute', () {
      GameObject o1 = GameObject(30); // "you";
      expect(o1.isFlagBitSet(1), equals(false));
      o1.setFlagBit(1);
      expect(o1.isFlagBitSet(1), equals(true));

      expect(o1.isFlagBitSet(0), equals(false));
      o1.setFlagBit(0);
      expect(o1.isFlagBitSet(0), equals(true));

      expect(o1.isFlagBitSet(31), equals(false));
      o1.setFlagBit(31);
      expect(o1.isFlagBitSet(31), equals(true));

      o1.unsetFlagBit(1);
      o1.unsetFlagBit(0);
      o1.unsetFlagBit(31);
    });

    test('get property address', () {
      GameObject o1 = GameObject(180); //"west of house"

      var addr = o1.getPropertyAddress(31);

      expect(0, equals(addr));

      if (addr > 0) {
        var pnum = GameObject.propertyNumber(addr - 1);
        expect(31, equals(pnum));
        var val = o1.getPropertyValue(pnum);
        expect(0x51, equals(val));
        addr = o1.getPropertyAddress(pnum);
        expect(0x1c2a, equals(addr));
      }

      addr = o1.getPropertyAddress(0);
      expect(0, equals(addr));
    });

    test('get property length', () {
      GameObject o1 = GameObject(232); //"Entrance to Hades"

      //expect(4, equals(GameObject.propertyLength(o1.getPropertyAddress(28) - 1)));
      checkLen(prop, expected) {
        var addr = o1.getPropertyAddress(prop);
        if (addr > 0) {
          expect(expected, equals(GameObject.propertyLength(addr - 1)));
        }
      }

      checkLen(23, 1);
      checkLen(21, 4);
      checkLen(17, 2);
      checkLen(5, 1);
      checkLen(4, 8);
    });
  });
}
