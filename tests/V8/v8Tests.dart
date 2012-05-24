#import('dart:io');
#import('dart:builtin');
#import('../../../../src/lib/unittest/unittest.dart');
//#import('dart:unittest');
//^^ not working
#import('../../lib/ZMachine.dart');

#source('V8ObjectTests.dart');

main(){
  // Tests depend on using this file.  Tests will fail if changed.
  var defaultGameFile = 'games${Platform.pathSeparator}across.z8';

  File f = new File(defaultGameFile);

  try{
    Z.load(f.readAsBytesSync());
  } catch (FileIOException fe){
    //TODO log then print friendly
    print('$fe');
    exit(1);
  } catch (Exception e){
    //TODO log then print friendly
    print('$e');
    exit(1);
  }

  if (Z.isLoaded){
    objectTestsV8();
  }
}