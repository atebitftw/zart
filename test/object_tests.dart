part of tests;


void objectTests(){
  group('Objects>', (){
    test('remove', (){

      var o1 = new GameObject(1); //forest

      // check if we have the right object and
      // assumptions are correct.
      Expect.equals('pair of hands', o1.shortName);
      Expect.equals(247, o1.parent);
      Expect.equals(2, o1.sibling);
      Expect.equals(0, o1.child);
      Expect.isTrue(o1.isFlagBitSet(14));
      Expect.isTrue(o1.isFlagBitSet(28));

      var ls = o1.leftSibling(); //248
      var p = new GameObject(36);

      o1.removeFromTree();
      //check that 2 is now the sibling of o1's
      //left sibling
      Expect.equals(2, new GameObject(ls).sibling);

      Expect.equals(0, o1.parent);
      Expect.equals(0, o1.sibling);
    });

    test('insert', (){
      var o1 = new GameObject(1); //forest
      var p = new GameObject(36); //parent
      var oc = p.child;

      o1.insertTo(36);
      Expect.equals(36, o1.parent);

      Expect.equals(1, p.child);
      Expect.equals(oc, o1.sibling);
    });

    test('get next property', (){
      GameObject o1 = new GameObject(5); //"you";

      Expect.equals('you', o1.shortName);

      Expect.equals(17, o1.getNextProperty(18));
      Expect.equals(0, o1.getNextProperty(17));
      Expect.equals(18, o1.getNextProperty(0));

      Expect.throws(
        () => o1.getNextProperty(19),
        (e) => e is GameException
        );

    });

    test('get property', (){
      GameObject o1 = new GameObject(5); //"you";

      Expect.equals('you', o1.shortName);

      Expect.equals(0x295c, o1.getPropertyValue(17));

      //throw on property len > 2
      Expect.throws(() => o1.getPropertyValue(18),
          (e) => e is GameException);

    });

    test('set property', (){
      GameObject o1 = new GameObject(31); //"frigid river";

      Expect.equals('Frigid River', o1.shortName);

      o1.setPropertyValue(30, 0xffff);
      //should truncate to 0xff since prop #30 is len 1
      Expect.equals(0xff, o1.getPropertyValue(30));

      o1.setPropertyValue(30, 0x13);
      Expect.equals(0x13, o1.getPropertyValue(30));

      Expect.equals(0x951a, o1.getPropertyValue(23));

      o1.setPropertyValue(11, 0xfff);
      Expect.equals(0xfff, o1.getPropertyValue(11));

      Expect.equals(0xee83, o1.getPropertyValue(5));

      //throw on prop no exist
      Expect.throws(
        () => o1.setPropertyValue(13, 0xffff),
          (e) => e is GameException);

      o1 = new GameObject(29);

      //throw on prop len > 2
      Expect.throws(
        () => o1.setPropertyValue(29, 0xffff),
          (e) => e is GameException);

    });

    test('attributes are set', (){
      GameObject o1 = new GameObject(4);// "cretin";

      Expect.equals('cretin', o1.shortName);

      Expect.isTrue(o1.isFlagBitSet(7));
      Expect.isTrue(o1.isFlagBitSet(9));
      Expect.isTrue(o1.isFlagBitSet(14));
      Expect.isTrue(o1.isFlagBitSet(30));

      //check some that aren't set:
      Expect.isFalse(o1.isFlagBitSet(1));
      Expect.isFalse(o1.isFlagBitSet(4));
      Expect.isFalse(o1.isFlagBitSet(6));
      Expect.isFalse(o1.isFlagBitSet(13));
      Expect.isFalse(o1.isFlagBitSet(15));
      Expect.isFalse(o1.isFlagBitSet(29));
      Expect.isFalse(o1.isFlagBitSet(31));
    });

    test ('unset attribute', (){
      GameObject o1 = new GameObject(4);// "cretin";
      Expect.isTrue(o1.isFlagBitSet(7));
      o1.unsetFlagBit(7);
      Expect.isFalse(o1.isFlagBitSet(7));

      Expect.isTrue(o1.isFlagBitSet(9));
      o1.unsetFlagBit(9);
      Expect.isFalse(o1.isFlagBitSet(9));

      Expect.isTrue(o1.isFlagBitSet(14));
      o1.unsetFlagBit(14);
      Expect.isFalse(o1.isFlagBitSet(14));

      o1.setFlagBit(7);
      o1.setFlagBit(9);
      o1.setFlagBit(14);
    });

    test('set attribute', (){
      GameObject o1 = new GameObject(30);// "you";
      Expect.isFalse(o1.isFlagBitSet(1));
      o1.setFlagBit(1);
      Expect.isTrue(o1.isFlagBitSet(1));

      Expect.isFalse(o1.isFlagBitSet(0));
      o1.setFlagBit(0);
      Expect.isTrue(o1.isFlagBitSet(0));

      Expect.isFalse(o1.isFlagBitSet(31));
      o1.setFlagBit(31);
      Expect.isTrue(o1.isFlagBitSet(31));

      o1.unsetFlagBit(1);
      o1.unsetFlagBit(0);
      o1.unsetFlagBit(31);
    });


    test('get property address', (){
      GameObject o1 = new GameObject(180); //"west of house"

      var addr = o1.getPropertyAddress(31);

      Expect.equals(0x1c2a, addr);

      var pnum = GameObject.propertyNumber(addr - 1);

      Expect.equals(31, pnum);

      var val = o1.getPropertyValue(pnum);

      Expect.equals(0x51, val);

      addr = o1.getPropertyAddress(pnum);

      Expect.equals(0x1c2a, addr);

      addr = o1.getPropertyAddress(0);
      Expect.equals(0, addr);

    });

    test('get property length', (){
      GameObject o1 = new GameObject(232); //"Entrance to Hades"

      Expect.equals(4, GameObject.propertyLength(o1.getPropertyAddress(28) - 1));
      Expect.equals(1, GameObject.propertyLength(o1.getPropertyAddress(23) - 1));
      Expect.equals(4, GameObject.propertyLength(o1.getPropertyAddress(21) - 1));
      Expect.equals(2, GameObject.propertyLength(o1.getPropertyAddress(17) - 1));
      Expect.equals(1, GameObject.propertyLength(o1.getPropertyAddress(5) - 1));
      Expect.equals(8, GameObject.propertyLength(o1.getPropertyAddress(4) - 1));
    });

  });



}