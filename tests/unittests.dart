#import('dart:io');
#import('../../../src/lib/unittest/unittest.dart');
#import('../lib/zmachine.dart');

#source('TestMachine.dart');

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
  final IMachine machine = new TestMachine();

  machine.visitHeader();

  StringBuffer s = new StringBuffer();

  for(int i = 155; i <= 223; i++){
    s.add('($i, ${ZSCII.ZCharToChar(i)})');
  }

  print(s.toString());

  group('ZSCII Tests>', (){

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
  });

  group('memory tests> ', (){
    test('read byte', (){
      Expect.equals(version, Z.mem.loadb(0x00));
    });

    test('read word', (){
      Expect.equals(pcAddr, Z.mem.loadw(Header.PC_INITIAL_VALUE_ADDR));
    });

    test('write byte', (){
      Z.mem.storeb(0x00, 42);

      Expect.equals(42, Z.mem.loadb(0x00));

      Z.mem.storeb(0x00, version);

      Expect.equals(version, Z.mem.loadb(0x00));
    });

    test('write word', (){
      Z.mem.storew(Header.PC_INITIAL_VALUE_ADDR, 42420);

      Expect.equals(42420, Z.mem.loadw(Header.PC_INITIAL_VALUE_ADDR));

      Z.mem.storew(Header.PC_INITIAL_VALUE_ADDR, pcAddr);

      Expect.equals(pcAddr, Z.mem.loadw(Header.PC_INITIAL_VALUE_ADDR));
    });

    test('read global var', (){
      Expect.equals(8101, Z.mem.loadw(Z.mem.globalVarsAddress + 8), 'offset');

      Expect.equals(8101, Z.mem.readGlobal(0x14), 'from global');
    });

    test('write global var', (){
      Z.mem.writeGlobal(0x14, 41410);

      Expect.equals(41410, Z.mem.readGlobal(0x14));

      Z.mem.writeGlobal(0x14, 8101);

      Expect.equals(8101, Z.mem.readGlobal(0x14));
    });

    test('write/read global var 0x00 (stack push/pop)', (){
      //push
      Z.mem.writeGlobal(0x00, 41410);
      Expect.equals(1, Z.stack.length);

      Expect.equals(41410, Z.stack.peek());

      //pop
      Expect.equals(41410, Z.mem.readGlobal(0x00));

      //should be empty
      Expect.equals(0, Z.stack.length);
    });
  });
}