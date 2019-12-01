library z_console;

import 'dart:io';
import 'package:zart/IO/blorb.dart';
import 'package:zart/debugger.dart';
import 'package:zart/header.dart';
import 'package:zart/zart.dart';
import 'package:zart/game_exception.dart';
import 'console_provider.dart';


// A basic Console player for Z-Machine
// Assumes first command line arguement is path to story file,
// otherwise attempts to load default file (specified in main()).
//
// Works in the Dart console.

// VM:
// dart ZConsole.dart path/to/minizork.z3

void main(List<String> args) {

  var defaultGameFile = 'example${Platform.pathSeparator}games${Platform.pathSeparator}minizork.z3';

  File f = (args.isEmpty) ? File(defaultGameFile) : File(args.first);

  try{
    var bytes = f.readAsBytesSync();

    var gameData = Blorb.getZData(bytes);

    if (gameData == null){
      print('Unable to load game.');
      exit(1);
    }

    Z.load(gameData);

  } on Exception catch (fe){
    //TODO log then print friendly
    print('$fe');
    exit(0);
  }

  Header.setFlags1(0);
  Header.setFlags2(0);

  Z.IOConfig = ConsoleProvider();

  //enableDebug enables the other flags (verbose, trace, breakpoints, etc)
  Debugger.enableDebug = false;
  Debugger.enableVerbose = false;
  Debugger.enableTrace = false;
  Debugger.enableStackTrace = false;
  //Debugger.setBreaks([0x2bfd]);

  try{
    Z.run();
  }on GameException catch(e){
    print('A game error occurred: ${e}');
    exit(1);
  }on Exception catch(_){
    print('A system error occurred.');
    exit(1);
  }
}

