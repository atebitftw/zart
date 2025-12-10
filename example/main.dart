import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:zart/src/logging.dart' show log;
import 'package:zart/zart.dart';

/// A basic Console player for Z-Machine using the pump API
void main(List<String> args) async {
  log.level = .WARNING;

  log.onRecord.listen((record) {
    print(record);
  });

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

    // Set IoProvider before loading so visitHeader() can read flags
    Z.io = ConsoleProvider() as IoProvider;

    Z.load(gameData);
  } catch (fe) {
    stdout.writeln("Exception occurred while trying to load game: $fe");
    exit(1);
  }

  //enableDebug enables the other flags (verbose, trace, breakpoints, etc)
  Debugger.enableDebug = false;
  Debugger.enableVerbose = false;
  Debugger.enableTrace = false;
  Debugger.enableStackTrace = false;
  //Debugger.setBreaks([0x2bfd]);

  stdout.writeln(getPreamble().join('\n'));
  stdout.writeln();

  try {
    // Command queue for chained commands (e.g., "get up.take all.north")
    final commandQueue = Queue<String>();

    // Pump API: run until input needed, then get input and continue
    var state = await Z.runUntilInput();

    while (state != ZMachineRunState.quit) {
      switch (state) {
        case ZMachineRunState.needsLineInput:
          // Check if we have queued commands from a previous chained input
          if (commandQueue.isEmpty) {
            stdout.write('> '); // Prompt on same line as input
            final line = stdin.readLineSync() ?? '';
            stdout.writeln(); // Blank line after input for visual separation
            // Split by '.' to support chained commands like "get up.take all.n"
            final commands = line.split('.').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
            if (commands.isEmpty) {
              // Empty input, just submit empty string
              state = await Z.submitLineInput('');
            } else {
              // Queue all commands and process the first one
              commandQueue.addAll(commands);
              state = await Z.submitLineInput(commandQueue.removeFirst());
            }
          } else {
            // Process next queued command - print as if user typed it
            final cmd = commandQueue.removeFirst();
            stdout.writeln('> $cmd');
            stdout.writeln();
            state = await Z.submitLineInput(cmd);
          }
          break;
        case ZMachineRunState.needsCharInput:
          final line = stdin.readLineSync() ?? '';
          final char = line.isEmpty ? '\n' : line[0];
          state = await Z.submitCharInput(char);
          break;
        case ZMachineRunState.quit:
        case ZMachineRunState.error:
        case ZMachineRunState.running:
          break;
      }
    }

    stdout.writeln('Zart: Game Over!');
    exit(0);
  } on GameException catch (e) {
    log.severe('A game error occurred: $e');
    exit(1);
  } catch (err, stack) {
    log.severe('A system error occurred. $err\n$stack');
    exit(1);
  }
}

/// A basic console provider with word-wrap support and quote box handling.
/// - Suppresses "quote box" content (Window 1 when split_window > 2 lines)
/// - Uses setCursor to properly position status bar text on single line
/// - Supports ANSI escape codes for text styling when terminal supports it
class ConsoleProvider implements IoProvider {
  final int cols = 80;

  // ANSI escape code support
  final bool _supportsAnsi = stdout.supportsAnsiEscapes;

  // Current text style (Z-Machine bitmask: 0=roman, 1=reverse, 2=bold, 4=italic, 8=fixed)
  int _currentStyle = 0;

  // Current colors (Z-Machine color codes, 0=current, 1=default)
  int _foregroundColor = 1;
  int _backgroundColor = 1;

  // Track split window height to detect quote boxes
  int _splitWindowLines = 0;

  // Track current window and cursor column for status line positioning
  int _currentWindow = 0;
  int _cursorColumn = 0;

  // Status line buffer (single row, fixed-width, filled with spaces)
  late List<String> _statusLine;

  // Buffer Window 0 output
  final List<String> _window0Buffer = [];

  ConsoleProvider() {
    _resetStatusLine();
  }

  void _resetStatusLine() {
    _statusLine = List.filled(cols, ' ');
    _cursorColumn = 0;
  }

  // ANSI escape code helpers
  String _getAnsiStyle() {
    if (!_supportsAnsi || _currentStyle == 0) return '';

    final codes = <String>[];
    if (_currentStyle & 1 != 0) codes.add('7'); // Reverse video
    if (_currentStyle & 2 != 0) codes.add('1'); // Bold
    if (_currentStyle & 4 != 0) codes.add('3'); // Italic

    return codes.isEmpty ? '' : '\x1B[${codes.join(";")}m';
  }

  String _getAnsiReset() {
    return _supportsAnsi ? '\x1B[0m' : '';
  }

  int _zColorToAnsiFg(int zColor) {
    const map = {2: 30, 3: 31, 4: 32, 5: 33, 6: 34, 7: 35, 8: 36, 9: 37};
    return map[zColor] ?? 39;
  }

  int _zColorToAnsiBg(int zColor) {
    const map = {2: 40, 3: 41, 4: 42, 5: 43, 6: 44, 7: 45, 8: 46, 9: 47};
    return map[zColor] ?? 49;
  }

  String _getAnsiColor() {
    if (!_supportsAnsi) return '';
    if (_foregroundColor <= 1 && _backgroundColor <= 1) return '';

    final codes = <String>[];
    if (_foregroundColor > 1) codes.add('${_zColorToAnsiFg(_foregroundColor)}');
    if (_backgroundColor > 1) codes.add('${_zColorToAnsiBg(_backgroundColor)}');

    return codes.isEmpty ? '' : '\x1B[${codes.join(";")}m';
  }

  @override
  Future<dynamic> command(Map<String, dynamic> command) async {
    final cmd = command['command'];

    switch (cmd) {
      case IoCommands.print:
        _bufferOutput(command['window'], command['buffer']);
        return null;
      case IoCommands.splitWindow:
        _splitWindowLines = command['lines'] ?? 0;
        return null;
      case IoCommands.setWindow:
        final newWindow = command['window'] ?? 0;
        if (_currentWindow == 1 && newWindow == 0) {
          // Leaving Window 1 - emit status line, then flush Window 0
          _emitStatusLine();
          _flushBuffers();
        } else if (_currentWindow == 0 && newWindow == 1) {
          // Entering Window 1 - reset status line for new content
          _resetStatusLine();
        }
        _currentWindow = newWindow;
        return null;
      case IoCommands.setCursor:
        // Track cursor column for status line positioning (we ignore row for single-line console)
        // Engine sends 'line' and 'column' (1-indexed)
        _cursorColumn = (command['column'] ?? 1) - 1;
        return null;
      case IoCommands.setTextStyle:
        // Z-Machine style bitmask: 0=roman, 1=reverse, 2=bold, 4=italic, 8=fixed
        _currentStyle = command['style'] ?? 0;
        return null;
      case IoCommands.setColour:
        // Z-Machine color codes: 0=current, 1=default, 2-9=colors
        _foregroundColor = command['foreground'] ?? 1;
        _backgroundColor = command['background'] ?? 1;
        return null;
      case IoCommands.status:
        // V3-style status - format and print directly
        final roomName = (command['room_name'] ?? '').toString().toUpperCase();
        final score = 'Score: ${command['score_one']} / ${command['score_two']}';
        _resetStatusLine();
        _writeToStatusLine(0, roomName);
        _writeToStatusLine(cols - score.length, score);
        _emitStatusLine();
        return null;
      case IoCommands.save:
        final result = await saveGame(command['file_data'].getRange(1, command['file_data'].length - 1).toList());
        return result;
      case IoCommands.clearScreen:
        _emitStatusLine();
        _flushBuffers();
        _resetStatusLine();
        _currentStyle = 0; // Reset style on clear
        _foregroundColor = 1;
        _backgroundColor = 1;
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
        _emitStatusLine();
        _flushBuffers();
        stdout.write(_getAnsiReset()); // Reset styling on quit
        return null;
      case IoCommands.read:
      case IoCommands.readChar:
        // Before input, emit status line (if any) then game text
        _emitStatusLine();
        _flushBuffers();
        return null;
      default:
        return null;
    }
  }

  @override
  int getFlags1() {
    if (!_supportsAnsi) return 0;
    return Header.flag1V4BoldfaceAvail | Header.flag1V4ItalicAvail | Header.flag1VSColorAvail;
  }

  void _writeToStatusLine(int column, String text) {
    for (int i = 0; i < text.length && column + i < cols; i++) {
      _statusLine[column + i] = text[i];
    }
  }

  void _emitStatusLine() {
    final line = _statusLine.join();
    if (line.trim().isNotEmpty) {
      // Status line is bold by default when ANSI is supported
      if (_supportsAnsi) {
        stdout.writeln('\x1B[1m$line\x1B[0m');
      } else {
        stdout.writeln(line);
      }
    }
    _resetStatusLine();
  }

  void _bufferOutput(int? windowID, String text) {
    if (text.isEmpty) return;

    // Filter out STATUS JSON format
    if (text.startsWith('["STATUS",') && text.endsWith(']')) {
      return;
    }

    if (windowID == 1) {
      // Suppress quote box content (Window 1 when split_window > 2 lines)
      if (_splitWindowLines > 2) {
        return; // Skip quote box content
      }
      // For 1-2 line Window 1 (status bar), use cursor positioning
      _writeToStatusLine(_cursorColumn, text.replaceAll('\n', ''));
      _cursorColumn += text.length;
    } else {
      _window0Buffer.add(text);
    }
  }

  void _flushBuffers() {
    // Print Window 0 (game text)
    for (int i = 0; i < _window0Buffer.length; i++) {
      var text = _window0Buffer[i];
      // For the last item, strip trailing prompt to avoid duplicate with our prompt
      if (i == _window0Buffer.length - 1) {
        text = text.replaceAll(RegExp(r'[\n\r]*>[\n\r]*$'), '');
      }
      if (text.isNotEmpty) {
        _printWithWordWrap(text);
      }
    }
    _window0Buffer.clear();
  }

  void _printWithWordWrap(String text) {
    final stylePrefix = _getAnsiStyle() + _getAnsiColor();
    final styleReset = (stylePrefix.isNotEmpty) ? _getAnsiReset() : '';

    var lines = text.split('\n');
    for (final l in lines) {
      var words = Queue<String>.from(l.split(' '));

      var s = StringBuffer();
      while (words.isNotEmpty) {
        var nextWord = words.removeFirst();

        if (s.length > cols) {
          stdout.writeln('$stylePrefix$s$styleReset');
          s = StringBuffer();
          s.write('$nextWord ');
        } else {
          if (words.isEmpty) {
            s.write('$nextWord ');
            stdout.writeln('$stylePrefix$s$styleReset');
            s = StringBuffer();
          } else {
            s.write('$nextWord ');
          }
        }
      }

      if (s.length > 0) {
        stdout.writeln('$stylePrefix$s$styleReset');
      }
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

  void debugOutput(String? text) => stdout.writeln(text);
}
