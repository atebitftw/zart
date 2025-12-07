import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:zart/zart.dart';

/// A basic Console player for Z-Machine
void main(List<String> args) {
  initializeLogger(Level.INFO);
  final log = Logger.root;

  if (args.isEmpty) {
    stdout.writeln('Usage: zart <game>');
    exit(1);
  }

  final filename = args.first;
  final f = File(filename);

  if (!f.existsSync()) {
    stdout.writeln('Error: Game file not found at "$filename"');
    stdout.writeln('Current Directory: ${Directory.current.path}');
    exit(1);
  }

  try {
    final bytes = f.readAsBytesSync();

    final gameData = Blorb.getZData(bytes);

    if (gameData == null) {
      stdout.writeln('Unable to load game.');
      exit(1);
    }

    Z.load(gameData);
  } catch (fe) {
    stdout.writeln("Exception occurred while trying to load game: $fe");
    exit(1);
  }

  // This interpreter doesn't support any advanced functions so set the
  // header flags to reflect that.
  Header.setFlags1(0);
  Header.setFlags2(0);

  Z.io = ConsoleProvider() as IoProvider;

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
class ConsoleProvider with Loggable implements IoProvider {
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
      case IoCommands.print:
        output(command['window'], command['buffer']);
        return null;
      case IoCommands.status:
        //TODO format for timed game type as well
        stdout.writeln(
          "${command['room_name'].toUpperCase()} Score: ${command['score_one']} / ${command['score_two']}\n",
        );
        return null;
      case IoCommands.read:
        final line = await getLine();
        return line;
      case IoCommands.readChar:
        final char = await getChar();
        return char;
      case IoCommands.save:
        final result = await saveGame(command['file_data'].getRange(1, command['file_data'].length - 1).toList());
        return result;
      case IoCommands.clearScreen:
        //no clear console api, so
        //we just print a bunch of lines
        for (int i = 0; i < 50; i++) {
          stdout.writeln('');
        }
        return null;
      case IoCommands.restore:
        final result = await restore();
        return result;
      case IoCommands.printDebug:
        debugOutput(command['message']);
        return null;
      case IoCommands.quit:
        stdout.writeln('Zart: Game Over!');
        exit(0);
      default:
        log.warning("IO Command not recognized: $cmd");
        //print('Zart: ${cmd}');
        return null;
    }
  }

  Future<bool> saveGame(List<int>? saveBytes) {
    var c = Completer();
    stdout.writeln('(Caution: will overwrite existing file!)');
    stdout.writeln('Enter file name to save to (no extension):');

    String? fn = stdin.readLineSync();
    if (fn == null || fn.isEmpty) {
      stdout.writeln('Invalid file name given.');
      c.complete(false);
    } else {
      try {
        stdout.writeln('Saving game "$fn.sav".  Use "restore" to restore it.');
        File f2 = File('games${Platform.pathSeparator}$fn.sav');
        f2.writeAsBytesSync(saveBytes!);
        c.complete(true);
      } on Exception catch (_) {
        stderr.writeln('File IO error.');
        c.complete(false);
      }
    }

    return c.future.then((value) => value as bool);
  }

  Future<List<int>> restore() {
    var c = Completer();
    stdout.writeln('Enter game file name to load (no extension):');

    String? fn = stdin.readLineSync();

    if (fn == null || fn.isEmpty) {
      stdout.writeln('Invalid file name given.');
      c.complete(null);
    } else {
      try {
        stdout.writeln('Restoring game "$fn.sav"...');
        File f2 = File('games${Platform.pathSeparator}$fn.sav');
        c.complete(f2.readAsBytesSync());
      } on Exception catch (_) {
        stderr.writeln('File IO error.');
        c.complete(null);
      }
    }

    return c.future.then((value) => value as List<int>);
  }

  void output(int? windowID, String text) {
    if (text.startsWith('["STATUS",') && text.endsWith(']')) {
      //ignore status line for simple console games
      return;
    }
    var lines = text.split('\n');
    for (final l in lines) {
      var words = Queue<String>.from(l.split(' '));

      var s = StringBuffer();
      while (words.isNotEmpty) {
        var nextWord = words.removeFirst();

        if (s.length > cols) {
          outputBuffer.addFirst('$s');
          stdout.writeln('$s');
          s = StringBuffer();
          s.write('$nextWord ');
        } else {
          if (words.isEmpty) {
            s.write('$nextWord ');
            outputBuffer.addFirst('$s');
            stdout.writeln('$s');
            s = StringBuffer();
          } else {
            s.write('$nextWord ');
          }
        }
      }

      if (s.length > 0) {
        outputBuffer.addFirst('$s');
        stdout.writeln('$s');
        s = StringBuffer();
      }
    }
  }

  void debugOutput(String? text) => stdout.writeln(text);

  Future<String> getChar() async {
    if (lineBuffer.isNotEmpty) {
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
    if (lineBuffer.isNotEmpty) {
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
