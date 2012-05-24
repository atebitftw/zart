//V5 Object Tests

void objectTestsV5(){
  group('Objects>', (){
    test('remove', (){

      var o1 = new GameObject(18); //golden fish

      // check if we have the right object and
      // assumptions are correct.
      Expect.equals('*GOLDEN FISH*', o1.shortName);
      Expect.equals(16, o1.parent);
      Expect.equals(19, o1.sibling);
      Expect.equals(0, o1.child);

      var ls = o1.leftSibling(); //19
      var p = new GameObject(16); //lakeside

      o1.removeFromTree();
      //check that 2 is now the sibling of o1's
      //left sibling
      Expect.equals(19, new GameObject(ls).sibling);

      Expect.equals(0, o1.parent);
      Expect.equals(0, o1.sibling);
    });

    test('insert', (){
      var o1 = new GameObject(18); //golden fish
      var p = new GameObject(16); //lakeside
      var oc = p.child;

      o1.insertTo(p.id);
      Expect.equals(p.id, o1.parent);

      Expect.equals(18, p.child);
      Expect.equals(oc, o1.sibling);
    });

    test('get property length', (){
      GameObject o1 = new GameObject(18); //"golden fish"

      Expect.equals(2, GameObject.propertyLength(o1.getPropertyAddress(27) - 1));
      Expect.equals(2, GameObject.propertyLength(o1.getPropertyAddress(4) - 1));
      Expect.equals(2, GameObject.propertyLength(o1.getPropertyAddress(2) - 1));
      Expect.equals(6, GameObject.propertyLength(o1.getPropertyAddress(1) - 1));
    });
    
    test('get property', (){
      GameObject o1 = new GameObject(18); //"golden fish";

      Expect.equals('*GOLDEN FISH*', o1.shortName);

      Expect.equals(0x22da, o1.getPropertyValue(4), 'get property #4');
      Expect.equals(0x0007, o1.getPropertyValue(2), 'get property #4');
      
      //throw on property len > 2
      Expect.throws(() => o1.getPropertyValue(1),
          (e) => e is GameException);

    });

    test('get property address', (){
      GameObject o1 = new GameObject(18); //"west of house"

      var addr = o1.getPropertyAddress(4);

      Expect.equals(0x868, addr);

      var pnum = GameObject.propertyNumber(addr - 1);

      Expect.equals(4, pnum);

      var val = o1.getPropertyValue(pnum);

      Expect.equals(0x22da, val);

      addr = o1.getPropertyAddress(pnum);

      Expect.equals(0x868, addr);

      addr = o1.getPropertyAddress(0);
      Expect.equals(0, addr);

    });
    
    
    test('get next property', (){
      GameObject o1 = new GameObject(18); //"golden fish";

      Expect.equals('*GOLDEN FISH*', o1.shortName);

      Expect.equals(4, o1.getNextProperty(27));
      Expect.equals(2, o1.getNextProperty(4));
      Expect.equals(1, o1.getNextProperty(2));
      Expect.equals(27, o1.getNextProperty(0));

      Expect.throws(
        () => o1.getNextProperty(19),
        (e) => e is GameException
        );

    });

    test('set property', (){
      GameObject o1 = new GameObject(18); //"golden fish";

      Expect.equals('*GOLDEN FISH*', o1.shortName);

      o1.setPropertyValue(4, 0xffff);
      //should truncate to 0xff since prop #30 is len 1
      Expect.equals(0xffff, o1.getPropertyValue(4));

      //throw on prop no exist
      Expect.throws(
        () => o1.setPropertyValue(13, 0xffff),
          (e) => e is GameException);

      //throw on prop len > 2
      Expect.throws(
        () => o1.setPropertyValue(1, 0xffff),
          (e) => e is GameException);

    });

    test('attributes are set', (){
      GameObject o1 = new GameObject(58);// "the door";

      Expect.equals('the door', o1.shortName);

      Expect.isTrue(o1.isFlagBitSet(6));
      Expect.isTrue(o1.isFlagBitSet(12));
      Expect.isTrue(o1.isFlagBitSet(13));
      Expect.isTrue(o1.isFlagBitSet(17));
      Expect.isTrue(o1.isFlagBitSet(21));

      //check some that aren't set:
      Expect.isFalse(o1.isFlagBitSet(1));
      Expect.isFalse(o1.isFlagBitSet(5));
      Expect.isFalse(o1.isFlagBitSet(7));
      Expect.isFalse(o1.isFlagBitSet(11));
      Expect.isFalse(o1.isFlagBitSet(14));
      Expect.isFalse(o1.isFlagBitSet(16));
      Expect.isFalse(o1.isFlagBitSet(18));
      Expect.isFalse(o1.isFlagBitSet(40));
    });

    test ('unset attribute', (){
      GameObject o1 = new GameObject(58);// "the door";
      Expect.isTrue(o1.isFlagBitSet(6));
      o1.unsetFlagBit(6);
      Expect.isFalse(o1.isFlagBitSet(6));

      Expect.isTrue(o1.isFlagBitSet(12));
      o1.unsetFlagBit(12);
      Expect.isFalse(o1.isFlagBitSet(12));

      Expect.isTrue(o1.isFlagBitSet(17));
      o1.unsetFlagBit(17);
      Expect.isFalse(o1.isFlagBitSet(17));

      o1.setFlagBit(6);
      o1.setFlagBit(12);
      o1.setFlagBit(17);
    });

    test('set attribute', (){
      GameObject o1 = new GameObject(58);// "the door";
      Expect.isFalse(o1.isFlagBitSet(1), '1');
      o1.setFlagBit(1);
      Expect.isTrue(o1.isFlagBitSet(1));

      Expect.isFalse(o1.isFlagBitSet(0), '0');
      o1.setFlagBit(0);
      Expect.isTrue(o1.isFlagBitSet(0));

      Expect.isFalse(o1.isFlagBitSet(47), '47');
      o1.setFlagBit(47);
      Expect.isTrue(o1.isFlagBitSet(47));

      o1.unsetFlagBit(1);
      o1.unsetFlagBit(0);
      o1.unsetFlagBit(47);
    });
  });
}