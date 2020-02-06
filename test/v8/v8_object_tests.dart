
import 'package:test/test.dart';
import 'package:zart/game_exception.dart';
import 'package:zart/game_object.dart';


void objectTestsV8(){
  group('Objects>', (){

    final SHIP = 63;
    final DREAMBRIDGE = 60;
    //final PIRATES = 62;
    final LADDER = 64;

    test('remove', (){

      var o1 = GameObject(SHIP);

      // check if we have the right object and
      // assumptions are correct.
      expect('ship', equals(o1.shortName));
      expect(DREAMBRIDGE, equals(o1.parent));
      expect(LADDER, equals(o1.sibling));
      expect(0, equals(o1.child));

      var ls = o1.leftSibling(); //PIRATES
      // var p = GameObject(DREAMBRIDGE); //(dream bridge)

      o1.removeFromTree();
      //check that 2 is now the sibling of o1's
      //left sibling
      expect(LADDER, equals(GameObject(ls).sibling));

      expect(0, equals(o1.parent));
      expect(0, equals(o1.sibling));
    });

    test('insert', (){
      var o1 = GameObject(SHIP); //ship
      var p = GameObject(DREAMBRIDGE); //parent
      var oc = p.child;

      o1.insertTo(p.id);
      expect(p.id, equals(o1.parent));

      expect(SHIP, equals(p.child));
      expect(oc, equals(o1.sibling));
    });

    test('get property length', (){
      GameObject o1 = GameObject(SHIP); //ship

      // Expect.equals(2, GameObject.propertyLength(o1.getPropertyAddress(35) - 1));
      // Expect.equals(2, GameObject.propertyLength(o1.getPropertyAddress(4) - 1));
      // Expect.equals(2, GameObject.propertyLength(o1.getPropertyAddress(3) - 1));
      // Expect.equals(20, GameObject.propertyLength(o1.getPropertyAddress(1) - 1));
    });

    test('get property', (){
      GameObject o1 = GameObject(SHIP);

      // Expect.equals('ship', o1.shortName);

      // Expect.equals(0x3843, o1.getPropertyValue(4), 'get property #4');
      // Expect.equals(0x74a9, o1.getPropertyValue(3), 'get property #3');

      //throw on property len > 2
      // Expect.throws(() => o1.getPropertyValue(1),
      //     (e) => e is GameException);
      expect(() => o1.getPropertyValue(1), throwsA(GameException));
    });

    test('get property address', (){
      // GameObject o1 = GameObject(SHIP); //"west of house"

      // var addr = o1.getPropertyAddress(4);

      // Expect.equals(0x2b41, addr);

      // var pnum = GameObject.propertyNumber(addr - 1);

      // Expect.equals(4, pnum);

      // var val = o1.getPropertyValue(pnum);

      // Expect.equals(0x3843, val);

      // addr = o1.getPropertyAddress(pnum);

      // Expect.equals(0x2b41, addr);

      // addr = o1.getPropertyAddress(0);
      // Expect.equals(0, addr);

    });


    test('get next property', (){
      GameObject o1 = GameObject(SHIP);

      // Expect.equals('ship', o1.shortName);

      // Expect.equals(4, o1.getNextProperty(35));
      // Expect.equals(3, o1.getNextProperty(4));
      // Expect.equals(1, o1.getNextProperty(3));
      // Expect.equals(35, o1.getNextProperty(0));

      // Expect.throws(
      //   () => o1.getNextProperty(19),
      //   (e) => e is GameException
      //   );

      expect(() => o1.getNextProperty(19), throwsA(GameException));

    });

    test('set property', (){
      GameObject o1 = GameObject(SHIP);

      // Expect.equals('ship', o1.shortName);

      // o1.setPropertyValue(4, 0xffff);
      // //should truncate to 0xff since prop #30 is len 1
      // Expect.equals(0xffff, o1.getPropertyValue(4));

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

    test('attributes are set', (){
      GameObject o1 = GameObject(SHIP);

      // Expect.equals('ship', o1.shortName);

      // Expect.isTrue(o1.isFlagBitSet(17));
      // Expect.isTrue(o1.isFlagBitSet(19));

      // //check some that aren't set:
      // Expect.isFalse(o1.isFlagBitSet(1));
      // Expect.isFalse(o1.isFlagBitSet(5));
      // Expect.isFalse(o1.isFlagBitSet(7));
      // Expect.isFalse(o1.isFlagBitSet(11));
      // Expect.isFalse(o1.isFlagBitSet(14));
      // Expect.isFalse(o1.isFlagBitSet(16));
      // Expect.isFalse(o1.isFlagBitSet(18));
      // Expect.isFalse(o1.isFlagBitSet(40));
    });

    test ('unset attribute', (){
      GameObject o1 = GameObject(SHIP);

      // Expect.isTrue(o1.isFlagBitSet(17));
      // o1.unsetFlagBit(17);
      // Expect.isFalse(o1.isFlagBitSet(17));

      // Expect.isTrue(o1.isFlagBitSet(19));
      // o1.unsetFlagBit(19);
      // Expect.isFalse(o1.isFlagBitSet(19));

      o1.setFlagBit(19);
      o1.setFlagBit(17);
    });

    test('set attribute', (){
      GameObject o1 = GameObject(58);// "the door";
      // Expect.isFalse(o1.isFlagBitSet(1), '1');
      // o1.setFlagBit(1);
      // Expect.isTrue(o1.isFlagBitSet(1));

      // Expect.isFalse(o1.isFlagBitSet(0), '0');
      // o1.setFlagBit(0);
      // Expect.isTrue(o1.isFlagBitSet(0));

      // Expect.isFalse(o1.isFlagBitSet(47), '47');
      // o1.setFlagBit(47);
      // Expect.isTrue(o1.isFlagBitSet(47));

      o1.unsetFlagBit(1);
      o1.unsetFlagBit(0);
      o1.unsetFlagBit(47);
    });
  });

}