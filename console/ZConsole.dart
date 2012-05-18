#import('../lib/zmachine.dart');
#import('dart:io');


// Console player for Z-Machine
// Assumes first command line arguement is path to story file,
// otherwise attempts to load default minizork.z3 file from environment.
//
// Works in the Dart console.

// VM:
// dart ZConsole.dart ../games/minizork.z3

void main() {
  var defaultGameFile = 'games${Platform.pathSeparator}minizork.z3';

  var args = new Options().arguments;

  File f = (args.isEmpty()) ? new File(defaultGameFile) : new File(args[0]);

  try{
    Z.load(f.readAsBytesSync());
  } catch (FileIOException fe){
    //TODO log then print friendly
    print('$fe');
    return;
  } catch (Exception e){
    //TODO log then print friendly
    print('$e');
    return;
  }

  //enableDebug enables the other flags (verbose, trace, breakpoints, etc)
  Debugger.enableDebug = false; 
  Debugger.enableVerbose = true;
  Debugger.enableTrace = true;
  Debugger.enableStackTrace = false;
  //Debugger.setBreaks([0x6a8d]);
  
  Z.run();

}

