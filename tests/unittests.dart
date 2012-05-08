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
      Expect.equals(8101, Z.mem.loadw(Z.mem.globalVarsAddress + 8));
      
      Expect.equals(8101, Z.mem.readGlobal(0x04));
    });
    
    test('write global var', (){
      Z.mem.writeGlobal(0x04, 41410);
      
      Expect.equals(41410, Z.mem.readGlobal(0x04));
      
      Z.mem.writeGlobal(0x04, 8101);
      
      Expect.equals(8101, Z.mem.readGlobal(0x04));
    });
    
  });
}
