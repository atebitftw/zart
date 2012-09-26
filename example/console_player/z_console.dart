#import('dart:io');
#import('dart:json');
#import('package:zart/zart.dart');

#source('console_provider.dart');

// A basic Console player for Z-Machine
// Assumes first command line arguement is path to story file,
// otherwise attempts to load default file (specified in main()).
//
// Works in the Dart console.

// VM:
// dart ZConsole.dart path/to/minizork.z3

void main() {

  var defaultGameFile = 'games${Platform.pathSeparator}minizork.z3';

  var args = new Options().arguments;

  File f = (args.isEmpty()) ? new File(defaultGameFile) : new File(args[0]);

  try{
    var bytes = f.readAsBytesSync();

    var gameData = Blorb.getZData(bytes);

    if (gameData == null){
      print('unable to load game.');
      exit(1);
    }

    Z.load(gameData);

  } on FileIOException catch (fe){
    //TODO log then print friendly
    print('$fe');
    exit(0);
  } on Exception catch (e){
    //TODO log then print friendly
    print('$e');
    exit(0);
  }

  Header.setFlags1(0);
  Header.setFlags2(0);

  Z.IOConfig = new ConsoleProvider();

  //enableDebug enables the other flags (verbose, trace, breakpoints, etc)
  Debugger.enableDebug = false;
  Debugger.enableVerbose = false;
  Debugger.enableTrace = false;
  Debugger.enableStackTrace = false;
  //Debugger.setBreaks([0x2bfd]);

  try{
    Z.run();
  }on GameException catch(ge){
    print('A game error occurred.');
    exit(1);
  }on Exception catch(e){
    print('A system error occurred.');
    exit(1);
  }
}

