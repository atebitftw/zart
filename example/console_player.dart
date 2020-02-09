import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:zart/IO/io_provider.dart';
import 'package:zart/IO/blorb.dart';
import 'package:zart/debugger.dart';
import 'package:zart/header.dart';
import 'package:zart/mixins/loggable.dart';
import 'package:zart/zart.dart';
import 'package:zart/game_exception.dart';

/// A basic Console player for Z-Machine
/// Assumes first command line arguement is path to story file,
/// otherwise attempts to load default file (specified in main()).
///
/// Works in the Dart console.
///
/// VM:
/// dart ZConsole.dart path/to/minizork.z3
void main(List<String> args) {
  initializeLogger(Level.INFO);
  final log = Logger("main()");

  var defaultGameFile =
      'assets${Platform.pathSeparator}games${Platform.pathSeparator}minizork.z3';

  final f = (args.isEmpty) ? File(defaultGameFile) : File(args.first);

  try {
    final bytes = f.readAsBytesSync();

    final gameData = Blorb.getZData(bytes);

    if (gameData == null) {
      log.severe('Unable to load game.');
      exit(1);
    }

    Z.load(gameData);
  } catch (fe) {
    log.severe("Exception occurred while trying to load game: $fe");
    exit(1);
  }

  // This interpreter doesn't support any advanced functions so set the
  // header flags to reflect that.
  Header.setFlags1(0);
  Header.setFlags2(0);

  Z.io = ConsoleProvider();

  //enableDebug enables the other flags (verbose, trace, breakpoints, etc)
  Debugger.enableDebug = false;
  Debugger.enableVerbose = false;
  Debugger.enableTrace = false;
  Debugger.enableStackTrace = false;
  //Debugger.setBreaks([0x2bfd]);

  try {
    Z.run();
  } on GameException catch (e) {
    log.severe('A game error occurred: $e');
    exit(1);
  } catch (err) {
    log.severe('A system error occurred. $err');
    exit(1);
  }
}

/// A basic console provider with word-wrap support.
class ConsoleProvider with Loggable implements IOProvider {
  final lineBuffer = Queue<String>();
  final outputBuffer = Queue<String>();
  final int cols = 80;

  ConsoleProvider() {
    logName = "ConsoleProvider";
  }

  @override
  Future<dynamic> command(Map<String, dynamic> command) async {

    final cmd = command['command'];

    switch (cmd) {
      //print('msg received>>> $cmd');    switch(cmd){
      case IOCommands.PRINT:
        output(command['window'], command['buffer']);
        return null;
      case IOCommands.STATUS:
        //TODO format for timed game type as well
        print("${command['room_name'].toUpperCase()} Score: ${command['score_one']} / ${command['score_two']}\n");
        return null;
      case IOCommands.READ:
        final line = await getLine();
        return line;
      case IOCommands.READ_CHAR:
        final char = await getChar();
        return char;
      case IOCommands.SAVE:
        final result =
            await saveGame(command['file_data'].getRange(1, command['file_data'].length - 1).toList());
        return result;
      case IOCommands.CLEAR_SCREEN:
        //no clear console api, so
        //we just print a bunch of lines
        for (int i = 0; i < 50; i++) {
          print('');
        }
        return null;
      case IOCommands.RESTORE:
        final result = await restore();
        return result;
      case IOCommands.PRINT_DEBUG:
        debugOutput(command['message']);
        return null;
      case IOCommands.QUIT:
        print('Zart: Game Over!');
        exit(0);
        return null;
      default:
        log.warning("IO Command not recognized: $cmd");
        //print('Zart: ${cmd}');
        return null;
    }
  }

  Future<bool> saveGame(List<int> saveBytes) {
    var c = Completer();
    print('(Caution: will overwrite existing file!)');
    print('Enter file name to save to (no extension):');

    String fn = stdin.readLineSync();
    if (fn == null || fn.isEmpty) {
      print('Invalid file name given.');
      c.complete(false);
    } else {
      try {
        print('Saving game "${fn}.sav".  Use "restore" to restore it.');
        File f2 = File('games${Platform.pathSeparator}${fn}.sav');
        f2.writeAsBytesSync(saveBytes);
        c.complete(true);
      } on Exception catch (_) {
        print('File IO error.');
        c.complete(false);
      }
    }

    return c.future;
  }

  Future<List<int>> restore() {
    var c = Completer();
    print('Enter game file name to load (no extension):');

    String fn = stdin.readLineSync();

    if (fn == null || fn.isEmpty) {
      print('Invalid file name given.');
      c.complete(null);
    } else {
      try {
        print('Restoring game "${fn}.sav"...');
        File f2 = File('games${Platform.pathSeparator}${fn}.sav');
        c.complete(f2.readAsBytesSync());
      } on Exception catch (_) {
        print('File IO error.');
        c.complete(null);
      }
    }

    return c.future;
  }

  void output(int windowID, String text) {
    if (text.startsWith('["STATUS",') && text.endsWith(']')) {
      //ignore status line for simple console games
      return;
    }
    var lines = text.split('\n');
    for (final l in lines) {
      var words = Queue<String>.from(l.split(' '));

      var s = StringBuffer();
      while (!words.isEmpty) {
        var nextWord = words.removeFirst();

        if (s.length > cols) {
          outputBuffer.addFirst('$s');
          print('$s');
          s = StringBuffer();
          s.write('$nextWord ');
        } else {
          if (words.isEmpty) {
            s.write('$nextWord ');
            outputBuffer.addFirst('$s');
            print('$s');
            s = StringBuffer();
          } else {
            s.write('$nextWord ');
          }
        }
      }

      if (s.length > 0) {
        outputBuffer.addFirst('$s');
        print('$s');
        s = StringBuffer();
      }
    }
  }

  void debugOutput(String text) => print(text);

  Future<String> getChar() async {
    if (!lineBuffer.isEmpty) {
      return lineBuffer.removeLast();
    } else {
      //TODO flush here?
      final line = stdin.readLineSync();
      
      if (line == null) {
        return '';
      } else {
        if (line == '') {
          return '\n';
        } else {
          return line[0];
        }
      }
    }
  }

  Future<String> getLine() async {
    if (!lineBuffer.isEmpty) {
      return lineBuffer.removeLast();
    } else {

      final line = stdin.readLineSync();
      
      if (line == null) {
        return '';
      } else {
        if (line == '') {
          return '\n';
        } else {
          return line;
        }
      }
    }
  }
}
