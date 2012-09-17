#import('dart:io');
#import('../../../../src/lib/unittest/unittest.dart');
//#import('dart:unittest');
//^^ not working
#import('../../lib/zart.dart');

#source('v8_object_tests.dart');

main(){
  // Tests depend on using this file.  Tests will fail if changed.
  var defaultGameFile = 'games${Platform.pathSeparator}across.z8';

  File f = new File(defaultGameFile);

  try{
    Z.load(f.readAsBytesSync());
  } on FileIOException catch (fe){
    //TODO log then print friendly
    print('$fe');
    exit(1);
  } on Exception catch (e){
    //TODO log then print friendly
    print('$e');
    exit(1);
  }

  if (Z.isLoaded){
    objectTestsV8();
  }
}