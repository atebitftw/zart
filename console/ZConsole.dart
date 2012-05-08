#import('../lib/zmachine.dart');
#import('dart:io');


//Console player for Z-Machine
// Assumes first command line arguement is path to story file,
// otherwise attempts to load default minizork.z3 file from environment.

//VM:
//dart ZConsole.dart ../games/minizork.z3

void main() {
  var defaultGameFile = 'games${Platform.pathSeparator}minizork.z3';
  
  var args = new Options().arguments;

  File f = (args.isEmpty()) ? new File(defaultGameFile) : new File(args[0]);

  try{
    Z.load(f.readAsBytesSync());
  } catch (FileIOException fe){
    //TODO log then print friendly
    print('$fe');
  } catch (Exception e){
    //TODO log then print friendly
    print('$e');
  }

  Z.run(new Tester());
}

