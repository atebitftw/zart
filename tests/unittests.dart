#import('dart:io');
#import('../../../src/lib/unittest/unittest.dart');
#import('../lib/zmachine.dart');

#source('MockUIProvider.dart');
#source('MockV3Machine.dart');
#source('InstructionTests.dart');

//#import('../../../../src/lib/unittest/html_enhanced_config.dart');


void main() {

 // useHtmlEnhancedConfiguration();

  var defaultGameFile = 'games${Platform.pathSeparator}minizork.z3';

  File f = new File(defaultGameFile);

  try{
    Z.load(f.readAsBytesSync());
  } catch (FileIOException fe){
    //TODO log then print friendly
    print('$fe');
  } catch (Exception e){
    //TODO log then print friendly
    print('$e');
  }

  final int version = 3;
  final int pcAddr = 14297;
  final Machine machine = new MockV3Machine();
  
  Debugger.setMachine(machine);
  Z.IOConfig = new MockUIProvider();


  group('ZSCII Tests>', (){
    test('unicode translations', (){
      for(int i = 155; i <= 223; i++){
        var s = new StringBuffer();
        s.addCharCode(ZSCII.UNICODE_TRANSLATIONS['$i']);
        Expect.equals(s.toString(), ZSCII.ZCharToChar(i));
      }
    });
    
    test('readZString', (){
      var addrStart = 0xb0a0;
      var addrEnd = 0xb0be;
      var testString = 'An old leather bag, bulging with coins, is here.';
      Expect.equals(testString, ZSCII.readZString(addrStart));
      
      // address after string end should be at 0xb0be
      Expect.equals(addrEnd, Z.machine.callStack.pop());
    });

  });

  group('Objects>', (){
    test('remove', (){
      
      var o1 = new GameObjectV3(1); //forest

      // check if we have the right object and
      // assumptions are correct.
      Expect.equals('forest', o1.shortName);
      Expect.equals(36, o1.parent);
      Expect.equals(147, o1.sibling);
      Expect.equals(0, o1.child);
      Expect.isTrue(o1.isFlagBitSet(6));
      
      var ls = o1.leftSibling();
      var p = new GameObjectV3(36);
      
      o1.removeFromTree();
      //check that 147 is now the sibling of o1's
      //left sibling
      Expect.equals(147, new GameObjectV3(ls).sibling);
      
      Expect.equals(0, o1.parent);
      Expect.equals(0, o1.sibling);
    });
    
    test('insert', (){
      var o1 = new GameObjectV3(1); //forest
      var p = new GameObjectV3(36); //parent
      var oc = p.child;
      
      o1.insertTo(36);
      Expect.equals(36, o1.parent);
      
      Expect.equals(1, p.child);
      Expect.equals(oc, o1.sibling);
    });
    
    test('get property', (){
      GameObjectV3 o1 = new GameObjectV3(30); //"you";
      
      Expect.equals('you', o1.shortName);
      
      Expect.equals(0, o1.getPropertyValue(18));
      Expect.equals(0x28b5, o1.getPropertyValue(17));
      Expect.equals(0x0006, o1.getPropertyValue(15));
    });
    
    test('attributes are set', (){
      GameObjectV3 o1 = new GameObjectV3(30);// "you";
      
      Expect.equals('you', o1.shortName);
      
      Expect.isTrue(o1.isFlagBitSet(5));
      Expect.isTrue(o1.isFlagBitSet(6));
      Expect.isTrue(o1.isFlagBitSet(14));
      Expect.isTrue(o1.isFlagBitSet(30));
      
      //check some that aren't set:
      Expect.isFalse(o1.isFlagBitSet(1));
      Expect.isFalse(o1.isFlagBitSet(4));
      Expect.isFalse(o1.isFlagBitSet(7));
      Expect.isFalse(o1.isFlagBitSet(13));
      Expect.isFalse(o1.isFlagBitSet(15));
      Expect.isFalse(o1.isFlagBitSet(29));
      Expect.isFalse(o1.isFlagBitSet(31));
    });

    test ('unset attribute', (){
      GameObjectV3 o1 = new GameObjectV3(30);// "you";
      Expect.isTrue(o1.isFlagBitSet(5));
      o1.unsetFlagBit(5);
      Expect.isFalse(o1.isFlagBitSet(5));
      
      Expect.isTrue(o1.isFlagBitSet(6));
      o1.unsetFlagBit(6);
      Expect.isFalse(o1.isFlagBitSet(6));
      
      Expect.isTrue(o1.isFlagBitSet(14));
      o1.unsetFlagBit(14);
      Expect.isFalse(o1.isFlagBitSet(14));
      
      o1.setFlagBit(5);
      o1.setFlagBit(6);
      o1.setFlagBit(14);
    });
    
    test('set attribute', (){
      GameObjectV3 o1 = new GameObjectV3(30);// "you";
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
      GameObjectV3 o1 = new GameObjectV3(46); //"west of house"
      
      var addr = o1.getPropertyAddress(28);
      
      Expect.equals(0xe17, addr);
      
      var pnum = GameObjectV3.propertyNumber(addr);
      
      Expect.equals(28, pnum);
      
      var val = o1.getPropertyValue(pnum);
      
      Expect.equals(0x90, val);
      
      addr = o1.getPropertyAddress(pnum);
      
      Expect.equals(0xe17, addr);

    });
    
    test('get property length', (){
      GameObjectV3 o1 = new GameObjectV3(29); //"Entrance to Hades"
      
      Expect.equals(4, GameObjectV3.propertyLength(o1.getPropertyAddress(28)));
      Expect.equals(1, GameObjectV3.propertyLength(o1.getPropertyAddress(23)));
      Expect.equals(4, GameObjectV3.propertyLength(o1.getPropertyAddress(21)));
      Expect.equals(2, GameObjectV3.propertyLength(o1.getPropertyAddress(18)));
      Expect.equals(1, GameObjectV3.propertyLength(o1.getPropertyAddress(12)));
      Expect.equals(8, GameObjectV3.propertyLength(o1.getPropertyAddress(8)));
      Expect.equals(0, GameObjectV3.propertyLength(o1.getPropertyAddress(0)));
    });
    
  });
  
  group('BinaryHelper Tests>', (){
    test('isSet() true', (){
      Expect.equals('1111', 15.toRadixString(2));
      Expect.isTrue(BinaryHelper.isSet(15, 0), '0');
      Expect.isTrue(BinaryHelper.isSet(15, 1), '1');
      Expect.isTrue(BinaryHelper.isSet(15, 2), '2');
      Expect.isTrue(BinaryHelper.isSet(15, 3), '3');
      Expect.isFalse(BinaryHelper.isSet(15, 4), '4');
      Expect.isFalse(BinaryHelper.isSet(15, 5), '5');
      Expect.isFalse(BinaryHelper.isSet(15, 6), '6');
      Expect.isFalse(BinaryHelper.isSet(15, 7), '7');

      Expect.equals('11110000', 240.toRadixString(2));
      Expect.isFalse(BinaryHelper.isSet(240, 0), '0');
      Expect.isFalse(BinaryHelper.isSet(240, 1), '1');
      Expect.isFalse(BinaryHelper.isSet(240, 2), '2');
      Expect.isFalse(BinaryHelper.isSet(240, 3), '3');
      Expect.isTrue(BinaryHelper.isSet(240, 4), '4');
      Expect.isTrue(BinaryHelper.isSet(240, 5), '5');
      Expect.isTrue(BinaryHelper.isSet(240, 6), '6');
      Expect.isTrue(BinaryHelper.isSet(240, 7), '7');
    });

    test('bottomBits()', (){
      Expect.equals(24, BinaryHelper.bottomBits(88, 6));
    });
    
    test('setBit()', (){
      Expect.equals(1, BinaryHelper.set(0, 0));
      Expect.equals(Math.pow(2, 8), BinaryHelper.set(0, 8));
      Expect.equals(Math.pow(2, 16), BinaryHelper.set(0, 16));
      Expect.equals(Math.pow(2, 32), BinaryHelper.set(0, 32));
    });
    
    test('unsetBit()', (){
      Expect.equals(0xFE, BinaryHelper.unset(0xFF, 0));
      Expect.equals(0xFD, BinaryHelper.unset(0xFF, 1));
      Expect.equals(0, BinaryHelper.unset(Math.pow(2, 8), 8));
      Expect.equals(0, BinaryHelper.unset(Math.pow(2, 16), 16));
      Expect.equals(0, BinaryHelper.unset(Math.pow(2, 32), 32));
    });
    
  });

  group('memory tests> ', (){
    test('read byte', (){
      Expect.equals(version, Z.machine.mem.loadb(0x00));
    });

    test('read word', (){
      Expect.equals(pcAddr, Z.machine.mem.loadw(Header.PC_INITIAL_VALUE_ADDR));
    });

    test('write byte', (){
      Z.machine.mem.storeb(0x00, 42);

      Expect.equals(42, Z.machine.mem.loadb(0x00));

      Z.machine.mem.storeb(0x00, version);

      Expect.equals(version, Z.machine.mem.loadb(0x00));
    });

    test('write word', (){
      Z.machine.mem.storew(Header.PC_INITIAL_VALUE_ADDR, 42420);

      Expect.equals(42420, Z.machine.mem.loadw(Header.PC_INITIAL_VALUE_ADDR));

      Z.machine.mem.storew(Header.PC_INITIAL_VALUE_ADDR, pcAddr);

      Expect.equals(pcAddr, Z.machine.mem.loadw(Header.PC_INITIAL_VALUE_ADDR));
    });

    test('read global var', (){
      Expect.equals(8101, Z.machine.mem.loadw(Z.machine.mem.globalVarsAddress + 8), 'offset');

      Expect.equals(8101, Z.machine.mem.readGlobal(0x14), 'from global');
    });

    test('write global var', (){
      Z.machine.mem.writeGlobal(0x14, 41410);

      Expect.equals(41410, Z.machine.mem.readGlobal(0x14));

      Z.machine.mem.writeGlobal(0x14, 8101);

      Expect.equals(8101, Z.machine.mem.readGlobal(0x14));
    });
  });
  
  instructionTests();
}
