#import('dart:io');
#import('dart:json');
#import('package:zart/zart.dart');

#source('console_provider.dart');
#source('debug_provider.dart');

// A basic Console player for Z-Machine
// Assumes first command line arguement is path to story file,
// otherwise attempts to load default file (specified in main()).
//
// Works in the Dart console.

// VM:
// dart ZConsole.dart path/to/minizork.z3

void main() {

  //var defaultGameFile = 'games${Platform.pathSeparator}minizork.z3';
  //var defaultGameFile = 'games${Platform.pathSeparator}etude.z5';
  var defaultGameFile = 'games${Platform.pathSeparator}zork1.z3';
  //var defaultGameFile = 'games${Platform.pathSeparator}Tester.z8';

  var args = new Options().arguments;

  File f = (args.isEmpty()) ? new File(defaultGameFile) : new File(args[0]);

  try{
    var bytes = f.readAsBytesSync();

//    File f2 = new File('games${Platform.pathSeparator}bytes.txt');
//    OutputStream s = f2.openOutputStream();
//    s.writeString('$bytes');
//    s.close();

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

  //Z.IOConfig = new DebugProvider.with('s.e.open window.enter.take all.w.take all.move rug.open trap door.down.turn lantern on');

  //Z.IOConfig = new DebugProvider.with('s.e.open window.enter.w');
  //Z.IOConfig = new DebugProvider.with('');


  //enableDebug enables the other flags (verbose, trace, breakpoints, etc)
  Debugger.enableDebug = false;
  Debugger.enableVerbose = false;
  Debugger.enableTrace = true;
  Debugger.enableStackTrace = false;
  //Debugger.setBreaks([0x2bfd]);

  try{
    Z.run();
  }on GameException catch(ge){
    print('got it!\n $ge');
    exit(0);
  }on Exception catch(e){
    print('$e');
    exit(0);
  }
}

