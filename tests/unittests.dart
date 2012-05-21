#import('dart:io');
#import('../../../src/lib/unittest/unittest.dart');
#import('../lib/zmachine.dart');

#source('MockUIProvider.dart');
#source('MockV3Machine.dart');
#source('InstructionTests.dart');
#source('ObjectTests.dart');

//#import('../../../../src/lib/unittest/html_enhanced_config.dart');

/*
* IMPORTANT: Run in Checked Mode so Assertions fire.
*/

void main() {

 // useHtmlEnhancedConfiguration();

  var defaultGameFile = 'games${Platform.pathSeparator}zork1.z3';

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
  final int pcAddr = 0x4f05;
  final Machine machine = new MockV3Machine();

  Debugger.setMachine(machine);
  Z.IOConfig = new MockUIProvider();


  group('16-bit signed conversion and math>', (){
    test('sign conversion', (){
      Expect.equals(-1, Machine.toSigned(0xFFFF));
      Expect.equals(32767, Machine.toSigned(32767));
      Expect.equals(-32768, Machine.toSigned(0x10000-32768));
    });

    test('dart ints to 16-bit signed', (){
      Expect.equals(65535, Machine.dartSignedIntTo16BitSigned(-1));
      Expect.equals(32769, Machine.dartSignedIntTo16BitSigned(-32767));
      Expect.equals(0, Machine.dartSignedIntTo16BitSigned(0));
      Expect.equals(42, Machine.dartSignedIntTo16BitSigned(42));

      Expect.throws(() => Machine.dartSignedIntTo16BitSigned(-32769),
          (e) => e is AssertionError);

    });

    test('division', (){
      //ref (2.4.3)
      Expect.equals(-5, (-11 / 2).toInt());
      Expect.equals(5, (-11 / -2).toInt());
      Expect.equals(-5, (11 / -2).toInt());
      Expect.equals(3, (13 % -5).toInt());

      int doMod(a, b){

        var result = a.abs() % b.abs();
        if (a < 0) result = -result;
        return result;
      }


      Expect.equals(-3, doMod(-13, -5), '-13 % -5');
      Expect.equals(-3, doMod(-13, 5), '-13 % 5');
    });

  });

  group('ZSCII Tests>', (){
    test('unicode translations', (){
      for(int i = 155; i <= 223; i++){
        var s = new StringBuffer();
        s.addCharCode(ZSCII.UNICODE_TRANSLATIONS['$i']);
        Expect.equals(s.toString(), ZSCII.ZCharToChar(i));
      }
    });

    test('readZString', (){
      var addrStart = 0x10e7c;
      var addrEnd = 0x10e9a;
      var testString = 'An old leather bag, bulging with coins, is here.';
      Expect.equals(testString, ZSCII.readZString(addrStart));

      // address after string end should be at 0xb0be
      Expect.equals(addrEnd, Z.machine.callStack.pop());
    });

  });

  group('RNG>', (){
    test('in bounds', (){
      var r = new DRandom.withSeed(new Date.now().milliseconds);

      for(int i = 0; i < 1000; i++){
        var result = r.NextFromMax(10) + 1;
        Expect.isTrue(result >= 1 && result <= 10, 'between 1 - 10 inclusive');
      }

    });

  });


  group('BinaryHelper Tests>', (){
    test('isSet() true', (){
      Expect.equals('1111', 0xf.toRadixString(2));
      Expect.isTrue(BinaryHelper.isSet(15, 0), '0');
      Expect.isTrue(BinaryHelper.isSet(15, 1), '1');
      Expect.isTrue(BinaryHelper.isSet(15, 2), '2');
      Expect.isTrue(BinaryHelper.isSet(15, 3), '3');
      Expect.isFalse(BinaryHelper.isSet(15, 4), '4');
      Expect.isFalse(BinaryHelper.isSet(15, 5), '5');
      Expect.isFalse(BinaryHelper.isSet(15, 6), '6');
      Expect.isFalse(BinaryHelper.isSet(15, 7), '7');

      Expect.equals('11110000', 0xf0.toRadixString(2));
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
      Expect.equals(11803, Z.machine.mem.loadw(Z.machine.mem.globalVarsAddress + 8), 'offset');

      Expect.equals(11803, Z.machine.mem.readGlobal(0x14), 'from global');
    });

    test('write global var', (){
      Z.machine.mem.writeGlobal(0x14, 41410);

      Expect.equals(41410, Z.machine.mem.readGlobal(0x14));

      Z.machine.mem.writeGlobal(0x14, 8101);

      Expect.equals(8101, Z.machine.mem.readGlobal(0x14));
    });
  });

  objectTests();

  instructionTests();

}
