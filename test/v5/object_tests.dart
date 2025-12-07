//V5 Object Tests

import 'package:test/test.dart';
import 'package:zart/src/game_exception.dart';
import 'package:zart/src/game_object.dart';

void objectTestsV5() {
  group('Objects>', () {
    test('remove', () {
      var o1 = GameObject(18); //golden fish

      // check if we have the right object and
      // assumptions are correct.
      expect('*GOLDEN FISH*', equals(o1.shortName));
      expect(16, equals(o1.parent));
      expect(19, equals(o1.sibling));
      expect(0, equals(o1.child));

      var ls = o1.leftSibling(); //19
      //var p = GameObject(16); //lakeside

      o1.removeFromTree();
      //check that 2 is now the sibling of o1's
      //left sibling
      expect(19, equals(GameObject(ls).sibling));

      expect(0, equals(o1.parent));
      expect(0, equals(o1.sibling));
    });

    test('insert', () {
      var o1 = GameObject(18); //golden fish
      var p = GameObject(16); //lakeside
      var oc = p.child;

      o1.insertTo(p.id);
      expect(p.id, equals(o1.parent));

      expect(18, equals(p.child));
      expect(oc, equals(o1.sibling));
    });

    test('get property length', () {
      GameObject o1 = GameObject(18); //"golden fish"

      expect(2, equals(GameObject.propertyLength(o1.getPropertyAddress(27) - 1)));
      expect(2, equals(GameObject.propertyLength(o1.getPropertyAddress(4) - 1)));
      expect(2, equals(GameObject.propertyLength(o1.getPropertyAddress(2) - 1)));
      expect(6, equals(GameObject.propertyLength(o1.getPropertyAddress(1) - 1)));
    });

    test('get property', () {
      GameObject o1 = GameObject(18); //"golden fish";      Expect.equals('*GOLDEN FISH*', o1.shortName);

      expect(0x22da, equals(o1.getPropertyValue(4)));
      expect(0x0007, equals(o1.getPropertyValue(2)));

      //throw on property len > 2
      expect(() => o1.getPropertyValue(1), throwsA(GameException));
      // Expect.throws(() => o1.getPropertyValue(1),
      //     (e) =>GameException);
    });

    test('get property address', () {
      GameObject o1 = GameObject(18); //"west of house"

      var addr = o1.getPropertyAddress(4);

      expect(0x868, equals(addr));

      var pnum = GameObject.propertyNumber(addr - 1);

      expect(4, equals(pnum));

      var val = o1.getPropertyValue(pnum);

      expect(0x22da, equals(val));

      addr = o1.getPropertyAddress(pnum);

      expect(0x868, equals(addr));

      addr = o1.getPropertyAddress(0);
      expect(0, equals(addr));
    });

    test('get next property', () {
      GameObject o1 = GameObject(18); //"golden fish";

      expect('*GOLDEN FISH*', equals(o1.shortName));

      expect(4, equals(o1.getNextProperty(27)));
      expect(2, equals(o1.getNextProperty(4)));
      expect(1, equals(o1.getNextProperty(2)));
      expect(27, equals(o1.getNextProperty(0)));

      // Expect.throws(
      //   () => o1.getNextProperty(19),
      //   (e) => e is GameException
      //   );
      expect(() => o1.getNextProperty(19), throwsA(GameException));
    });

    test('set property', () {
      GameObject o1 = GameObject(18); //"golden fish";

      expect('*GOLDEN FISH*', equals(o1.shortName));

      o1.setPropertyValue(4, 0xffff);
      //should truncate to 0xff since prop #30 is len 1
      expect(0xffff, equals(o1.getPropertyValue(4)));

      //throw on prop no exist
      // Expect.throws(
      //   () => o1.setPropertyValue(13, 0xffff),
      //     (e) => e is GameException);
      expect(() => o1.setPropertyValue(13, 0xffff), throwsA(GameException));

      //throw on prop len > 2
      // Expect.throws(
      //   () => o1.setPropertyValue(1, 0xffff),
      //     (e) => e is GameException);
      expect(() => o1.setPropertyValue(1, 0xffff), throwsA(GameException));
    });

    test('attributes are set', () {
      GameObject o1 = GameObject(58); // "the door";

      expect('the door', equals(o1.shortName));

      expect(o1.isFlagBitSet(6), equals(true));
      expect(o1.isFlagBitSet(12), equals(true));
      expect(o1.isFlagBitSet(13), equals(true));
      expect(o1.isFlagBitSet(17), equals(true));
      expect(o1.isFlagBitSet(21), equals(true));

      //check some that aren't set:
      expect(o1.isFlagBitSet(1), equals(false));
      expect(o1.isFlagBitSet(5), equals(false));
      expect(o1.isFlagBitSet(7), equals(false));
      expect(o1.isFlagBitSet(11), equals(false));
      expect(o1.isFlagBitSet(14), equals(false));
      expect(o1.isFlagBitSet(16), equals(false));
      expect(o1.isFlagBitSet(18), equals(false));
      expect(o1.isFlagBitSet(40), equals(false));
    });

    test('unset attribute', () {
      GameObject o1 = GameObject(58); // "the door";
      expect(o1.isFlagBitSet(6), equals(true));
      o1.unsetFlagBit(6);
      expect(o1.isFlagBitSet(6), equals(false));

      expect(o1.isFlagBitSet(12), equals(true));
      o1.unsetFlagBit(12);
      expect(o1.isFlagBitSet(12), equals(false));

      expect(o1.isFlagBitSet(17), equals(true));
      o1.unsetFlagBit(17);
      expect(o1.isFlagBitSet(17), equals(false));

      o1.setFlagBit(6);
      o1.setFlagBit(12);
      o1.setFlagBit(17);
    });

    test('set attribute', () {
      GameObject o1 = GameObject(58); // "the door";
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
