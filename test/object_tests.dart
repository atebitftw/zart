
import 'package:test/test.dart';
import 'package:zart/game_exception.dart';
import 'package:zart/game_object.dart';

void objectTests(){
  group('Objects>', (){
    test('remove', (){

      var o1 = new GameObject(1); //forest

      // check if we have the right object and
      // assumptions are correct.
  //       test("String.split() splits the string on the delimiter", () {
  //   var string = "foo,bar,baz";
  //   expect(string.split(","), equals(["foo", "bar", "baz"]));
  // });
      expect('pair of hands', equals(o1.shortName));
      expect(247, equals(o1.parent));
      expect(2, equals(o1.sibling));
      expect(0, equals(o1.child));
      expect(o1.isFlagBitSet(14), equals(true));
      expect(o1.isFlagBitSet(28), equals(true));

      var ls = o1.leftSibling(); //248
      //var p = new GameObject(36);

      o1.removeFromTree();
      //check that 2 is now the sibling of o1's
      //left sibling
      expect(2, equals(new GameObject(ls).sibling));

      expect(0, equals(o1.parent));
      expect(0, equals(o1.sibling));
    });

    test('insert', (){
      var o1 = new GameObject(1); //forest
      var p = new GameObject(36); //parent
      var oc = p.child;

      o1.insertTo(36);
      expect(36, equals(o1.parent));

      expect(1, equals(p.child));
      expect(oc, equals(o1.sibling));
    });

    test('get next property', (){
      GameObject o1 = new GameObject(5); //"you";

      expect('you', equals(o1.shortName));

      expect(17, equals(o1.getNextProperty(18)));
      expect(0, equals(o1.getNextProperty(17)));
      expect(18, equals(o1.getNextProperty(0)));

      expect(() => o1.getNextProperty(19), throwsA(GameException));

    });

    test('get property', (){
      GameObject o1 = new GameObject(5); //"you";

      expect('you', equals(o1.shortName));

      expect(0x295c, equals(o1.getPropertyValue(17)));

      //throw on property len > 2
      expect(() => o1.getNextProperty(18), throwsA(GameException));
    });

    test('set property', (){
      GameObject o1 = new GameObject(31); //"frigid river";

      expect('Frigid River', equals(o1.shortName));

      o1.setPropertyValue(30, 0xffff);
      //should truncate to 0xff since prop #30 is len 1
      expect(0xff, equals(o1.getPropertyValue(30)));

      o1.setPropertyValue(30, 0x13);
      expect(0x13, equals(o1.getPropertyValue(30)));

      expect(0x951a, equals(o1.getPropertyValue(23)));

      o1.setPropertyValue(11, 0xfff);
      expect(0xfff, equals(o1.getPropertyValue(11)));

      expect(0xee83, equals(o1.getPropertyValue(5)));

      //throw on prop no exist
      expect(() => o1.setPropertyValue(13, 0xffff), throwsA(GameException));
      // Expect.throws(
      //   () => o1.setPropertyValue(13, 0xffff),
      //     (e) => e is GameException);

      o1 = new GameObject(29);

      //throw on prop len > 2
      // Expect.throws(
      //   () => o1.setPropertyValue(29, 0xffff),
      //     (e) => e is GameException);
      expect(() => o1.setPropertyValue(29, 0xffff), throwsA(GameException));

    });

    test('attributes are set', (){
      GameObject o1 = new GameObject(4);// "cretin";

      expect('cretin', equals(o1.shortName));

      expect(o1.isFlagBitSet(7), equals(true));
      expect(o1.isFlagBitSet(9), equals(true));
      expect(o1.isFlagBitSet(14), equals(true));
      expect(o1.isFlagBitSet(30), equals(true));

      //check some that aren't set:
      expect(o1.isFlagBitSet(1), equals(false));
      expect(o1.isFlagBitSet(4), equals(false));
      expect(o1.isFlagBitSet(6), equals(false));
      expect(o1.isFlagBitSet(13), equals(false));
      expect(o1.isFlagBitSet(15), equals(false));
      expect(o1.isFlagBitSet(29), equals(false));
      expect(o1.isFlagBitSet(31), equals(false));
    });

    test ('unset attribute', (){
      GameObject o1 = new GameObject(4);// "cretin";
      expect(o1.isFlagBitSet(7), equals(true));
      o1.unsetFlagBit(7);
      expect(o1.isFlagBitSet(7), equals(false));

      expect(o1.isFlagBitSet(9), equals(true));
      o1.unsetFlagBit(9);
      expect(o1.isFlagBitSet(9), equals(false));

      expect(o1.isFlagBitSet(14), equals(true));
      o1.unsetFlagBit(14);
      expect(o1.isFlagBitSet(14), equals(false));

      o1.setFlagBit(7);
      o1.setFlagBit(9);
      o1.setFlagBit(14);
    });

    test('set attribute', (){
      GameObject o1 = new GameObject(30);// "you";
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


    test('get property address', (){
      GameObject o1 = new GameObject(180); //"west of house"

      var addr = o1.getPropertyAddress(31);

      expect(0x1c2a, equals(addr));

      var pnum = GameObject.propertyNumber(addr - 1);

      expect(31, equals(pnum));

      var val = o1.getPropertyValue(pnum);

      expect(0x51, equals(val));

      addr = o1.getPropertyAddress(pnum);

      expect(0x1c2a, equals(addr));

      addr = o1.getPropertyAddress(0);
      expect(0, equals(addr));

    });

    test('get property length', (){
      GameObject o1 = new GameObject(232); //"Entrance to Hades"

      expect(4, equals(GameObject.propertyLength(o1.getPropertyAddress(28) - 1)));
      expect(1, equals(GameObject.propertyLength(o1.getPropertyAddress(23) - 1)));
      expect(4, equals(GameObject.propertyLength(o1.getPropertyAddress(21) - 1)));
      expect(2, equals(GameObject.propertyLength(o1.getPropertyAddress(17) - 1)));
      expect(1, equals(GameObject.propertyLength(o1.getPropertyAddress(5) - 1)));
      expect(8, equals(GameObject.propertyLength(o1.getPropertyAddress(4) - 1)));
    });

  });



}