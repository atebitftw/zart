import 'dart:io';
import 'dart:async';
import 'package:dart_console/dart_console.dart';
import 'package:zart/src/logging.dart' show log;
import 'package:logging/logging.dart' show Level;
import 'package:zart/src/z_machine.dart';
import 'package:zart/zart.dart';

/// A full-screen terminal-based console player for Z-Machine.
/// Uses dart_console for cross-platform support.
void main(List<String> args) async {
  log.level = Level.INFO;

  // final debugFile = File('debug.txt');
  // debugFile.writeAsStringSync(''); // Clear file
  // log.onRecord.listen((record) {
  //   debugFile.writeAsStringSync(
  //     '${record.level.name}: ${record.message}\n',
  //     mode: FileMode.append,
  //   );
  // });

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

  final terminal = TerminalDisplay();

  try {
    final bytes = f.readAsBytesSync();
    final gameData = Blorb.getZData(bytes);

    if (gameData == null) {
      stdout.writeln('Unable to load game.');
      exit(1);
    }

    // Set IoProvider before loading
    Z.io = TerminalProvider(terminal) as IoProvider;
    Z.load(gameData);
  } catch (fe) {
    stdout.writeln("Exception occurred while trying to load game: $fe");
    exit(1);
  }

  // Disable debugging for clean display
  Debugger.enableDebug = false;
  Debugger.enableVerbose = false;
  Debugger.enableTrace = false;
  Debugger.enableStackTrace = false;

  // Handle Ctrl+C to properly exit full-screen mode
  ProcessSignal.sigint.watch().listen((_) {
    try {
      terminal.exitFullScreen();
      stdout.writeln('Interrupted.');
      exit(0);
    } catch (e, stack) {
      terminal.exitFullScreen();
      stdout.writeln('Error: $e');
      stdout.writeln('Stack Trace: $stack');
      rethrow;
    }
  });

  try {
    // Enter full-screen mode
    terminal.enterFullScreen();
    terminal.showPreamble(getPreamble());

    // Command queue for chained commands (e.g., "get up.take all.north")
    final commandQueue = <String>[];

    // Pump API: run until input needed, then get input and continue
    var state = await Z.runUntilInput();

    while (state != ZMachineRunState.quit) {
      switch (state) {
        case ZMachineRunState.needsLineInput:
          if (commandQueue.isEmpty) {
            terminal.render();
            final line = await terminal.readLine();
            terminal.appendToWindow0('\n');
            // Split by '.' to support chained commands
            final commands = line
                .split('.')
                .map((c) => c.trim())
                .where((c) => c.isNotEmpty)
                .toList();
            if (commands.isEmpty) {
              state = await Z.submitLineInput('');
            } else {
              commandQueue.addAll(commands);
              state = await Z.submitLineInput(commandQueue.removeAt(0));
            }
          } else {
            final cmd = commandQueue.removeAt(0);
            terminal.appendToWindow0('$cmd\n');
            state = await Z.submitLineInput(cmd);
          }
          break;
        case ZMachineRunState.needsCharInput:
          terminal.render();
          final char = await terminal.readChar();
          if (char.isNotEmpty) {
            state = await Z.submitCharInput(char);
          }
          break;
        case ZMachineRunState.quit:
        case ZMachineRunState.error:
        case ZMachineRunState.running:
          break;
      }
    }

    terminal.appendToWindow0('\n[Press any key to exit]');
    terminal.render();
    await terminal.readChar();
  } on GameException catch (e) {
    terminal.exitFullScreen();
    log.severe('A game error occurred: $e');
    exit(1);
  } catch (err, stack) {
    terminal.exitFullScreen();
    stdout.writeln('A system error occurred: $err');
    stdout.writeln('Stack Trace:\n$stack');
    exit(1);
  } finally {
    terminal.exitFullScreen();
    exit(0);
  }
}

/// Layout:
/// ┌────────────────────────────────┐
/// │ Window 1 (status/upper)        │
/// ├────────────────────────────────┤ ← Separator
/// │ Window 0 (main, scrollable)    │
/// │ (text, text)                   │
/// │ > [input line]                 │
/// └────────────────────────────────┘
class TerminalDisplay {
  // Terminal dimensions
  int _cols = 80;
  int _rows = 24;

  final ScreenModel _screen = ScreenModel();

  final Console _console = Console();

  String _inputBuffer = '';
  int _inputLine =
      -1; // Line in buffer where input is happening (-1 = not in input)

  // ignore: unused_field
  int _inputCol = 0; // Column where input started

  // ANSI helper via console?
  bool get _supportsAnsi =>
      true; // dart_console handles this internally usually

  /// Handle input (Not used with dart_console)
  // void _handleInputData(List<int> codes) { ... }

  // helper to get key string
  String _keyToString(Key key) {
    if (key.char.isNotEmpty) return key.char;

    switch (key.controlChar) {
      case ControlCharacter.enter:
        return '\n';
      case ControlCharacter.backspace:
        return String.fromCharCode(127);
      case ControlCharacter.arrowUp:
        return String.fromCharCode(129);
      case ControlCharacter.arrowDown:
        return String.fromCharCode(130);
      case ControlCharacter.arrowLeft:
        return String.fromCharCode(131);
      case ControlCharacter.arrowRight:
        return String.fromCharCode(132);
      default:
        return '';
    }
  }

  /// Enter full-screen mode using alternate screen buffer.
  void enterFullScreen() {
    // Try to switch to alternate buffer manually
    stdout.write('\x1B[?1049h');

    _console.rawMode = true;
    _console.hideCursor();
    _console.clearScreen();

    _detectTerminalSize();
    _screen.resize(_cols, _rows);
    _screen.clearWindow1(); // Init window 1
  }

  /// Exit full-screen mode and restore normal terminal.
  void exitFullScreen() {
    _console.showCursor();
    _console.rawMode = false;
    _console.resetColorAttributes();

    // Switch back to main screen buffer
    stdout.write('\x1B[?1049l');
  }

  /// Detect terminal size.
  void _detectTerminalSize() {
    _cols = _console.windowWidth;
    _rows = _console.windowHeight;
    if (_cols <= 0) _cols = 80;
    if (_rows <= 0) _rows = 24;
    _screen.resize(_cols, _rows);

    // Update Z-Machine Header with screen dimensions (Standard 1.0, 8.4)
    if (Z.isLoaded) {
      try {
        final oldRows = Z.engine.mem.loadb(0x20);
        final oldCols = Z.engine.mem.loadb(0x21);

        // Update Bytes (0x20, 0x21) - legacy/all versions, max 255
        Z.engine.mem.storeb(0x20, _rows > 255 ? 255 : _rows);
        Z.engine.mem.storeb(0x21, _cols > 255 ? 255 : _cols);

        // Update Words (0x22, 0x24) - V5+ units (1 unit = 1 char here)
        // Check version > 3 (actually V4 might use it, but V5 definitely does)
        if (ZMachine.verToInt(Z.ver!) >= 5) {
          Z.engine.mem.storew(0x22, _cols);
          Z.engine.mem.storew(0x24, _rows);
          // Standardize Units: 1 Unit = 1 Char
          Z.engine.mem.storeb(0x26, 1);
          Z.engine.mem.storeb(0x27, 1);
        }

        if (oldRows != _rows || oldCols != _cols) {
          log.info(
            'Updated Z-Header ScreenSize: ${_cols}x$_rows (was ${oldCols}x${oldRows})',
          );
        }
      } catch (e) {
        log.warning('Failed to update Z-Header: $e');
      }
    }
  }

  /// Show preamble text in Window 0.
  void showPreamble(List<String> lines) {
    for (final line in lines) {
      appendToWindow0(line);
      appendToWindow0('\n');
    }
    appendToWindow0('\n');
  }

  /// Split the window - set Window 1 height.
  void splitWindow(int lines) => _screen.splitWindow(lines);

  /// Apply any pending Window 1 height change (call after user input).
  void applyPendingWindowShrink() => _screen.applyPendingWindowShrink();

  /// Clear Window 1.
  void clearWindow1() => _screen.clearWindow1();

  /// Clear Window 0.
  void clearWindow0() => _screen.clearWindow0();

  /// Clear all windows.
  void clearAll() => _screen.clearAll();

  /// Set cursor position in Window 1 (1-indexed).
  void setCursor(int row, int col) => _screen.setCursor(row, col);

  /// Get current cursor position.
  Map<String, int> getCursor() {
    return {'row': _screen.cursorRow, 'column': _screen.cursorCol};
  }

  /// Set text style.
  void setStyle(int style) => _screen.setStyle(style);

  /// Set text colors.
  void setColors(int fg, int bg) => _screen.setColors(fg, bg);

  /// Convert Z-Machine color code to ANSI foreground code.
  String _fgAnsi(int zColor) {
    if (!_supportsAnsi) return '';
    switch (zColor) {
      case 1:
        return '\x1B[39m'; // Default
      case 2:
        return '\x1B[30m'; // Black
      case 3:
        return '\x1B[31m'; // Red
      case 4:
        return '\x1B[32m'; // Green
      case 5:
        return '\x1B[33m'; // Yellow
      case 6:
        return '\x1B[34m'; // Blue
      case 7:
        return '\x1B[35m'; // Magenta
      case 8:
        return '\x1B[36m'; // Cyan
      case 9:
        return '\x1B[37m'; // White
      default:
        return '';
    }
  }

  /// Convert Z-Machine color code to ANSI background code.
  String _bgAnsi(int zColor) {
    if (!_supportsAnsi) return '';
    switch (zColor) {
      case 1:
        return '\x1B[49m'; // Default
      case 2:
        // Map Z-Machine Black to ANSI Default Background (\x1B[49m)
        // This prevents "Dark Grey" blocks on terminals where "Black" != "Background"
        return '\x1B[49m';
      case 3:
        return '\x1B[41m'; // Red
      case 4:
        return '\x1B[42m'; // Green
      case 5:
        return '\x1B[43m'; // Yellow
      case 6:
        return '\x1B[44m'; // Blue
      case 7:
        return '\x1B[45m'; // Magenta
      case 8:
        return '\x1B[46m'; // Cyan
      case 9:
        return '\x1B[47m'; // White
      default:
        return '';
    }
  }

  /// Reset ANSI colors to default.
  String get _resetAnsi {
    if (!_supportsAnsi) return '';
    return '\x1B[0m';
  }

  /// Write text to Window 1 .
  void writeToWindow1(String text) => _screen.writeToWindow1(text);

  /// Append text to Window 0 (main scrollable area).
  void appendToWindow0(String text) => _screen.appendToWindow0(text);

  /// Render the full screen.
  void render() {
    _detectTerminalSize(); // Updates _screen cols/rows

    if (!_supportsAnsi) {
      _renderFallback();
      return;
    }

    final buf = StringBuffer();
    // Hide cursor during render
    buf.write('\x1B[?25l');
    // Move to home
    buf.write('\x1B[H');

    // Calculate layout
    final separatorLine = _screen.separatorLine;
    final window1Lines = _screen.window1Height;
    final window0Lines = _screen.window0Lines;

    int currentRow = 1;

    // Render Window 1 (upper/status)
    int lastFg = -1;
    int lastBg = -1;
    int lastStyle = -1;

    // Helper to render a row of cells
    void renderRow(
      int screenRow,
      List<Cell> cells, {
      required bool forceFullWidth,
    }) {
      buf.write('\x1B[$screenRow;1H'); // Position cursor

      // Calculate effective cells
      final effectiveCols = _cols;
      final limit = forceFullWidth ? effectiveCols : cells.length;

      // ignore: unused_local_variable
      int colCount = 0;
      for (int j = 0; j < limit || (forceFullWidth && j < effectiveCols); j++) {
        if (j >= effectiveCols) break;

        Cell cell;
        if (j < cells.length) {
          cell = cells[j];
        } else {
          cell = Cell.empty();
        }

        // Color mapping
        int fg = cell.fg;
        int bg = cell.bg;
        final style = cell.style;
        final hasReverse = (style & 1) != 0;

        // Note: We delegate Reverse Video to the terminal (\x1B[7m)
        // instead of manually swapping colors. This is standard ANSI behavior.

        if (fg != lastFg || bg != lastBg || style != lastStyle) {
          buf.write(_resetAnsi);

          if (fg != 1) buf.write(_fgAnsi(fg));
          if (bg != 1) buf.write(_bgAnsi(bg));

          if (hasReverse) buf.write('\x1B[7m'); // Reverse
          if ((style & 2) != 0) buf.write('\x1B[1m'); // Bold
          if ((style & 4) != 0) buf.write('\x1B[3m'); // Italic

          lastFg = fg;
          lastBg = bg;
          lastStyle = style;
        }

        buf.write(cell.char);
        colCount++;
      }

      // Reset styles at EOL
      buf.write(_resetAnsi);
      lastFg = -1;
      lastBg = -1;
      lastStyle = -1;
    }

    // Render Window 1
    final w1Grid = _screen.window1Grid;
    for (int i = 0; i < window1Lines && i < w1Grid.length; i++) {
      renderRow(currentRow, w1Grid[i], forceFullWidth: true);
      currentRow++;
    }

    // Render Window 0 (main scrollable content)
    final w0Grid = _screen.window0Grid;
    final startLine = (w0Grid.length > window0Lines)
        ? w0Grid.length - window0Lines
        : 0;

    for (int i = 0; i < window0Lines; i++) {
      buf.write('\x1B[$currentRow;1H');
      buf.write('\x1B[K'); // Clear line to remove artifacts

      final lineIndex = startLine + i;
      if (lineIndex < w0Grid.length) {
        renderRow(currentRow, w0Grid[lineIndex], forceFullWidth: false);
      }
      currentRow++;
    }

    // Position cursor at end of input line if we're in input mode
    if (_inputLine >= 0 && _inputLine < w0Grid.length) {
      // Calculate which screen row the input line is on
      final inputScreenRow =
          _inputLine - startLine + window1Lines + separatorLine + 1;
      if (inputScreenRow >= 1 && inputScreenRow <= _rows) {
        final cursorCol = w0Grid[_inputLine].length + 1;
        buf.write('\x1B[$inputScreenRow;${cursorCol}H');
        buf.write('\x1B[?25h'); // Show cursor
      }
    } else {
      buf.write('\x1B[?25l'); // Hide cursor when not in input mode
    }

    stdout.write(buf.toString());
  }

  /// Fallback render for non-ANSI terminals.
  void _renderFallback() {
    stdout.writeln('--- Status ---');
    for (final row in _screen.window1Grid) {
      stdout.writeln(row.map((c) => c.char).join());
    }
    stdout.writeln('-' * _cols);
    final w0Grid = _screen.window0Grid;
    final start = w0Grid.length > 20 ? w0Grid.length - 20 : 0;
    for (int i = start; i < w0Grid.length; i++) {
      stdout.writeln(w0Grid[i].map((c) => c.char).join());
    }
  }

  /// Read a line of input from the user.
  Future<String> readLine() async {
    _inputBuffer = '';
    // Remember where input starts (end of current content)
    _inputLine = _screen.window0Grid.isNotEmpty
        ? _screen.window0Grid.length - 1
        : 0;
    if (_screen.window0Grid.isEmpty) {
      _inputLine = 0;
      _screen.appendToWindow0('');
      _screen.window0Grid.add([]);
    }
    _inputCol = _screen.window0Grid.isNotEmpty
        ? _screen.window0Grid.last.length
        : 0;

    render();

    while (true) {
      // Blocking read (sync) but in async function
      final key = _console.readKey();

      if (key.controlChar == ControlCharacter.enter) {
        // Enter key
        final result = _inputBuffer;
        appendToWindow0('\n');
        render();
        _inputBuffer = '';
        _inputLine = -1;
        applyPendingWindowShrink();
        return result;
      } else if (key.controlChar == ControlCharacter.backspace) {
        // Backspace
        if (_inputBuffer.isNotEmpty) {
          _inputBuffer = _inputBuffer.substring(0, _inputBuffer.length - 1);
          // Update display grid
          if (_screen.window0Grid.isNotEmpty &&
              _inputLine < _screen.window0Grid.length) {
            final rowList = _screen.window0Grid[_inputLine];
            if (rowList.isNotEmpty) {
              rowList.removeLast();
            }
          }
          render();
        }
      } else if (key.char.isNotEmpty) {
        // Printable
        final char = key.char;
        _inputBuffer += char;
        // Update display grid
        if (_screen.window0Grid.isNotEmpty &&
            _inputLine < _screen.window0Grid.length) {
          final rowList = _screen.window0Grid[_inputLine];
          if (rowList.length < _cols) {
            rowList.add(
              Cell(
                char,
                fg: _screen.fgColor,
                bg: _screen.bgColor,
                style: _screen.currentStyle,
              ),
            );
          }
        }
        render();
      }
      // Ignore Arrows in Line Mode
    }
  }

  /// Read a single character for char input mode.
  Future<String> readChar() async {
    final key = _console.readKey();
    applyPendingWindowShrink();
    return _keyToString(key);
  }
}

class TerminalProvider implements IoProvider {
  final TerminalDisplay terminal;
  TerminalProvider(this.terminal);

  @override
  int getFlags1() {
    // Flag 1 = Color available (bit 0)
    // Flag 4 = Bold available (bit 2)
    // Flag 5 = Italic available (bit 3)
    // Flag 6 = Fixed-width font available (bit 4)
    // Flag 8 = Timed input available (bit 7)
    return 1 | 4 | 8 | 16 | 128; // Color, Bold, Italic, Fixed, Timed input
    // Note: Timed input isn't fully implemented in run loop yet but we claim it.
  }

  // Method mapping implementation...
  @override
  Future<dynamic> command(Map<String, dynamic> commandMessage) async {
    final cmd = commandMessage['command'] as IoCommands;
    switch (cmd) {
      case IoCommands.print:
        final window = commandMessage['window'] as int;
        final buffer = commandMessage['buffer'] as String?;
        if (buffer != null) {
          if (window == 1) {
            terminal.writeToWindow1(buffer);
          } else {
            terminal.appendToWindow0(buffer);
          }
        }
        break;
      case IoCommands.splitWindow:
        final lines = commandMessage['lines'] as int;
        terminal.splitWindow(lines);
        break;
      case IoCommands.setWindow:
        // Current window is implicit in print command usage in Z-Machine
        // But we track it in IoProvider? No, ScreenModel manages where text goes?
        // Z-Machine ops: `set_window`.
        // The interpreter passes `window` arg only to `print`.
        // We're good.
        break;
      case IoCommands.clearScreen:
        final window = commandMessage['window_id'] as int;
        if (window == -1 || window == -2) {
          terminal.clearAll();
        } else if (window == 0) {
          terminal.clearWindow0();
        } else if (window == 1) {
          terminal.clearWindow1();
        }
        break;
      case IoCommands.setCursor:
        final line = commandMessage['line'] as int;
        final col = commandMessage['column'] as int;
        terminal.setCursor(line, col);
        break;
      case IoCommands.getCursor:
        return terminal.getCursor();
      case IoCommands.setTextStyle:
        final style = commandMessage['style'] as int;
        terminal.setStyle(style);
        break;
      case IoCommands.setColour:
        final fg = commandMessage['foreground'] as int;
        final bg = commandMessage['background'] as int;
        terminal.setColors(fg, bg);
        break;
      case IoCommands.eraseLine:
        // Erase line in current window?
        // Z-machine standard: erase to end of line.
        // We'll leave unimplemented for now.
        break;
      case IoCommands.status:
        // V3 Status Line
        final room = commandMessage['room_name'] as String;
        final score1 = commandMessage['score_one'] as String;
        final score2 = commandMessage['score_two'] as String;
        final isTime = (commandMessage['game_type'] as String) == 'TIME';

        // Format: "Room Name" (left) ... "Score: A Moves: B" (right)
        final rightText = isTime
            ? 'Time: $score1:$score2'
            : 'Score: $score1 Moves: $score2';

        // Ensure window 1 has at least 1 line
        if (terminal._screen.window1Height < 1) {
          terminal.splitWindow(1); // Force 1 line for status
        }

        // We want to construct a single line of text with padding
        // But writeToWindow1 writes sequentially.
        // And we want INVERSE VIDEO.

        // Enable Reverse Video + Bold
        terminal.setStyle(3); // 1=Reverse + 2=Bold

        // Move to top-left of Window 1
        terminal.setCursor(1, 1);

        // 1. Write Room Name
        terminal.writeToWindow1(' $room');

        // 2. Calculate padding
        final width = terminal._cols;
        final leftLen = room.length + 1; // +1 for leading space
        final rightLen =
            rightText.length + 1; // +1 for trailing space? or just visual?
        final pad = width - leftLen - rightLen;

        if (pad > 0) {
          terminal.writeToWindow1(' ' * pad);
        }

        // 3. Write Score/Moves
        terminal.writeToWindow1('$rightText ');

        // Reset style
        terminal.setStyle(0);
        break;
      case IoCommands.save:
        final fileData = commandMessage['file_data'] as List<int>;
        terminal.appendToWindow0('\nEnter filename to save: ');
        terminal.render();
        var filename = await terminal.readLine();
        terminal.appendToWindow0('$filename\n');

        if (filename.isEmpty) return false;

        if (!filename.toLowerCase().endsWith('.sav')) {
          filename += '.sav';
        }

        try {
          final f = File(filename);
          f.writeAsBytesSync(fileData);
          terminal.appendToWindow0('Saved to "$filename".\n');
          return true;
        } catch (e) {
          terminal.appendToWindow0('Save failed: $e\n');
          return false;
        }
      case IoCommands.restore:
        terminal.appendToWindow0('\nEnter filename to restore: ');
        terminal.render();
        var filename = await terminal.readLine();
        terminal.appendToWindow0('$filename\n');

        if (filename.isEmpty) return null;

        if (!filename.toLowerCase().endsWith('.sav')) {
          filename += '.sav';
        }

        try {
          final f = File(filename);
          if (!f.existsSync()) {
            terminal.appendToWindow0('File not found: "$filename"\n');
            return null;
          }
          final data = f.readAsBytesSync();
          terminal.appendToWindow0('Restored from "$filename".\n');
          return data;
        } catch (e) {
          terminal.appendToWindow0('Restore failed: $e\n');
          return null;
        }

      default:
        break;
    }
  }
}

// ... helper getPreamble ...
List<String> getPreamble() {
  return [
    'Zart Z-Machine Interpreter (Console)',
    'Loaded.',
    '------------------------------------------------',
  ];
}
