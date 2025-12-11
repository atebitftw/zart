import 'dart:io';
import 'package:zart/src/logging.dart' show log;
import 'package:logging/logging.dart' show Level;
import 'package:zart/zart.dart';

/// A basic Console player for Z-Machine using the pump API
void main(List<String> args) async {
  log.level = Level.WARNING;

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
    final commandQueue = <String>[];

    // Pump API: run until input needed, then get input and continue
    var state = await Z.runUntilInput();

    while (state != ZMachineRunState.quit) {
      switch (state) {
        case ZMachineRunState.needsLineInput:
          // Check if we have queued commands from a previous chained input
          if (commandQueue.isEmpty) {
            (Z.io as ConsoleProvider).flush(addPrompt: true);
            final line = stdin.readLineSync() ?? '';
            stdout.writeln(); // Blank line after input for visual separation
            // Split by '.' to support chained commands like "get up.take all.n"
            final commands = line
                .split('.')
                .map((c) => c.trim())
                .where((c) => c.isNotEmpty)
                .toList();
            if (commands.isEmpty) {
              // Empty input, just submit empty string
              state = await Z.submitLineInput('');
            } else {
              // Queue all commands and process the first one
              commandQueue.addAll(commands);
              state = await Z.submitLineInput(commandQueue.removeAt(0));
            }
          } else {
            // Process next queued command - print as if user typed it
            (Z.io as ConsoleProvider).flush(addPrompt: true);
            final cmd = commandQueue.removeAt(0);
            stdout.writeln('$cmd');
            stdout.writeln();
            state = await Z.submitLineInput(cmd);
          }
          break;
        case ZMachineRunState.needsCharInput:
          (Z.io as ConsoleProvider).flush(addPrompt: true);
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

/// Console provider with ANSI styling support and proper output ordering.
/// - Buffers output to ensure status bar displays before game text
/// - Supports ANSI colors and text styles when terminal supports them
/// - Uses simple linear output (no cursor positioning or scroll regions)
class ConsoleProvider implements IoProvider {
  final int cols = 80;

  // ANSI escape code support
  final bool _supportsAnsi = stdout.supportsAnsiEscapes;

  // Current text style (Z-Machine bitmask)
  int _currentStyle = 0;

  // Current colors
  int _foregroundColor = 1;
  int _backgroundColor = 1;

  // Current window and split height
  int _currentWindow = 0;
  int _splitWindowLines = 0;

  // Status line buffer (fixed width, filled with spaces)
  late List<String> _statusLine;
  int _cursorColumn = 0;

  // Buffer for Window 0 output
  final List<String> _window0Buffer = [];

  ConsoleProvider() {
    _resetStatusLine();
  }

  void _resetStatusLine() {
    _statusLine = List.filled(cols, ' ');
    _cursorColumn = 0;
  }

  // Z-Machine color to ANSI mapping
  int _zColorToAnsiFg(int zColor) {
    const map = {2: 30, 3: 31, 4: 32, 5: 33, 6: 34, 7: 35, 8: 36, 9: 37};
    return map[zColor] ?? 39;
  }

  int _zColorToAnsiBg(int zColor) {
    const map = {2: 40, 3: 41, 4: 42, 5: 43, 6: 44, 7: 45, 8: 46, 9: 47};
    return map[zColor] ?? 49;
  }

  String _getAnsiPrefix() {
    if (!_supportsAnsi) return '';
    final codes = <String>[];
    if (_currentStyle & 1 != 0) codes.add('7');
    if (_currentStyle & 2 != 0) codes.add('1');
    if (_currentStyle & 4 != 0) codes.add('3');
    if (_foregroundColor > 1) codes.add('${_zColorToAnsiFg(_foregroundColor)}');
    if (_backgroundColor > 1) codes.add('${_zColorToAnsiBg(_backgroundColor)}');
    return codes.isEmpty ? '' : '\x1B[${codes.join(";")}m';
  }

  String _getAnsiReset() => _supportsAnsi ? '\x1B[0m' : '';

  @override
  Future<dynamic> command(Map<String, dynamic> command) async {
    final cmd = command['command'];

    switch (cmd) {
      case IoCommands.print:
        _handlePrint(command['window'], command['buffer']);
        return null;
      case IoCommands.splitWindow:
        _splitWindowLines = command['lines'] ?? 0;
        return null;
      case IoCommands.setWindow:
        final newWindow = command['window'] ?? 0;
        if (_currentWindow == 1 && newWindow == 0) {
          // Leaving Window 1 - emit status line, then flush Window 0 buffer
          _emitStatusLine();
          flush(addPrompt: false);
        } else if (_currentWindow == 0 && newWindow == 1) {
          // Entering Window 1 - reset status line
          _resetStatusLine();
        }
        _currentWindow = newWindow;
        return null;
      case IoCommands.setCursor:
        // Track cursor column for status line positioning
        _cursorColumn = (command['column'] ?? 1) - 1;
        return null;
      case IoCommands.setTextStyle:
        _currentStyle = command['style'] ?? 0;
        return null;
      case IoCommands.setColour:
        _foregroundColor = command['foreground'] ?? 1;
        _backgroundColor = command['background'] ?? 1;
        return null;
      case IoCommands.status:
        // V3-style status - format and print directly
        final roomName = (command['room_name'] ?? '').toString().toUpperCase();
        final score =
            'Score: ${command['score_one']} / ${command['score_two']}';
        _resetStatusLine();
        _writeToStatusLine(0, roomName);
        _writeToStatusLine(cols - score.length, score);
        _emitStatusLine();
        return null;
      case IoCommands.save:
        return await _saveGame(
          command['file_data']
              .getRange(1, command['file_data'].length - 1)
              .toList(),
        );
      case IoCommands.clearScreen:
        _resetStatusLine();
        _window0Buffer.clear();
        _currentStyle = 0;
        _foregroundColor = 1;
        _backgroundColor = 1;
        stdout.write(_getAnsiReset());
        stdout.writeln('\n' * 24);
        return null;
      case IoCommands.restore:
        return await _restore();
      case IoCommands.printDebug:
        stdout.writeln(command['message']);
        return null;
      case IoCommands.quit:
        _emitStatusLine();
        flush(addPrompt: false);
        stdout.write(_getAnsiReset());
        return null;
      case IoCommands.read:
      case IoCommands.readChar:
        // (This path is for non-pump mode, if ever used)
        // Emit any pending status and buffered text before input
        _emitStatusLine();
        flush(addPrompt: true);
        return null;
      default:
        return null;
    }
  }

  @override
  int getFlags1() {
    if (!_supportsAnsi) return 0;
    return Header.flag1V4BoldfaceAvail |
        Header.flag1V4ItalicAvail |
        Header.flag1VSColorAvail;
  }

  void _writeToStatusLine(int column, String text) {
    for (int i = 0; i < text.length && column + i < cols; i++) {
      _statusLine[column + i] = text[i];
    }
  }

  void _emitStatusLine() {
    final line = _statusLine.join();
    if (line.trim().isNotEmpty) {
      if (_supportsAnsi) {
        stdout.writeln('\x1B[1m$line\x1B[0m');
      } else {
        stdout.writeln(line);
      }
    }
    _resetStatusLine();
  }

  void flush({bool addPrompt = false}) {
    if (_window0Buffer.isEmpty && !addPrompt) return;

    var fullText = _window0Buffer.join('');

    // Always strip trailing prompt content from the buffer to avoid duplication
    // (Z5 games often include their own prompt, which we want to replace with our controlled one)
    // Regex matches a prompt '>' at the start of line/string, followed by optional whitespace and ANSI codes.
    fullText = fullText.replaceAll(
      RegExp(r'(?:^|[\n\r]+)>\s*(?:\x1B\[[\d;]*m)*$'),
      '',
    );

    if (fullText.isNotEmpty) {
      _printWrapped(fullText);
    }

    _window0Buffer.clear();
    // Print our prompt without newline so cursor stays on same line
    if (addPrompt) {
      stdout.write('> ');
    }
  }

  void _handlePrint(int? windowID, String text) {
    if (text.isEmpty) return;
    if (text.startsWith('["STATUS",') && text.endsWith(']')) return;

    if (windowID == 1) {
      // Skip quote box content (Window 1 when split > 2)
      if (_splitWindowLines > 2) return;
      // Status window - write to status line buffer at cursor column
      _writeToStatusLine(_cursorColumn, text.replaceAll('\n', ''));
      _cursorColumn += text.length;
    } else {
      // Main window - buffer for later
      _window0Buffer.add(text);
    }
  }

  void _printWrapped(String text) {
    final prefix = _getAnsiPrefix();
    final reset = prefix.isNotEmpty ? _getAnsiReset() : '';

    for (final line in text.split('\n')) {
      if (line.isEmpty) {
        stdout.writeln();
        continue;
      }

      final words = line.split(' ');
      var currentLine = StringBuffer();

      for (final word in words) {
        if (currentLine.length + word.length + 1 > cols &&
            currentLine.isNotEmpty) {
          stdout.writeln('$prefix${currentLine.toString().trimRight()}$reset');
          currentLine = StringBuffer();
        }
        if (currentLine.isNotEmpty) currentLine.write(' ');
        currentLine.write(word);
      }

      if (currentLine.isNotEmpty) {
        stdout.writeln('$prefix${currentLine.toString().trimRight()}$reset');
      }
    }
  }

  Future<bool> _saveGame(List<int>? saveBytes) async {
    stdout.writeln('(Caution: will overwrite existing file!)');
    stdout.writeln('Enter file name to save to (no extension):');

    final fn = stdin.readLineSync();
    if (fn == null || fn.isEmpty) {
      stdout.writeln('Invalid file name given.');
      return false;
    }

    try {
      stdout.writeln('Saving game "$fn.sav".');
      File('$fn.sav').writeAsBytesSync(saveBytes!);
      return true;
    } catch (_) {
      stderr.writeln('File IO error.');
      return false;
    }
  }

  Future<List<int>?> _restore() async {
    stdout.writeln('Enter game file name to load (no extension):');

    final fn = stdin.readLineSync();
    if (fn == null || fn.isEmpty) {
      stdout.writeln('Invalid file name given.');
      return null;
    }

    try {
      stdout.writeln('Restoring game "$fn.sav"...');
      return File('$fn.sav').readAsBytesSync();
    } catch (_) {
      stderr.writeln('File IO error.');
      return null;
    }
  }
}
