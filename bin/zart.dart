import 'dart:io';
import 'package:zart/src/logging.dart' show log;
import 'package:logging/logging.dart' show Level;
import 'package:zart/src/z_machine.dart';
import 'package:zart/zart.dart';
import 'package:zart/src/io/screen_model.dart';

/// A full-screen terminal-based console player for Z-Machine.
/// Uses ANSI escape codes to manage the entire terminal display,
/// similar to text editors like micro, nano, or vim.
void main(List<String> args) async {
  log.level = Level.WARNING;

  // Write logs to file since we can't print in full-screen mode
  // final debugFile = File('debug.txt');
  // debugFile.writeAsStringSync(''); // Clear file
  // log.onRecord.listen((record) {
  //   debugFile.writeAsStringSync('${record.level.name}: ${record.message}\n', mode: FileMode.append);
  // });

  if (args.isEmpty) {
    stdout.writeln('Usage: zart2 <game>');
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
    terminal.exitFullScreen();
    stdout.writeln('Interrupted.');
    exit(0);
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
            final line = terminal.readLine();
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
            terminal.appendToWindow0('> $cmd\n');
            state = await Z.submitLineInput(cmd);
          }
          break;
        case ZMachineRunState.needsCharInput:
          terminal.render();
          final char = terminal.readChar();
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
    terminal.readChar();
  } on GameException catch (e) {
    terminal.exitFullScreen();
    log.severe('A game error occurred: $e');
    exit(1);
  } catch (err, stack) {
    terminal.exitFullScreen();
    log.severe('A system error occurred. $err\n$stack');
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

  // Input state
  String _inputBuffer = '';
  int _inputLine =
      -1; // Line in buffer where input is happening (-1 = not in input)

  // ignore: unused_field
  int _inputCol = 0; // Column where input started

  // ANSI support
  bool get _supportsAnsi => stdout.supportsAnsiEscapes;

  /// Enter full-screen mode using alternate screen buffer.
  void enterFullScreen() {
    _detectTerminalSize();
    _screen.resize(_cols, _rows);

    if (_supportsAnsi) {
      stdout.write('\x1B[?1049h'); // Switch to alternate screen buffer
      stdout.write(
        '\x1B[?1h',
      ); // Enable Application Cursor Keys (for arrow keys)
      stdout.write('\x1B[?25l'); // Hide cursor
      stdout.write('\x1B[2J'); // Clear screen
      stdout.write('\x1B[H'); // Move to home
    }
    _screen.clearWindow1(); // Init window 1
  }

  /// Exit full-screen mode and restore normal terminal.
  void exitFullScreen() {
    if (_supportsAnsi) {
      stdout.write('\x1B[?25h'); // Show cursor
      stdout.write('\x1B[0m'); // Reset styles
      stdout.write('\x1B[?1049l'); // Switch back to main screen buffer
    }
  }

  /// Detect terminal size.
  void _detectTerminalSize() {
    try {
      _cols = stdout.terminalColumns;
      _rows = stdout.terminalLines;
      _screen.resize(_cols, _rows);
    } catch (_) {
      _cols = 80;
      _rows = 24;
      _screen.resize(_cols, _rows);
    }

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
  String readLine() {
    _inputBuffer = '';
    // Remember where input starts (end of current content)
    _inputLine = _screen.window0Grid.isNotEmpty
        ? _screen.window0Grid.length - 1
        : 0;
    if (_screen.window0Grid.isEmpty) {
      _inputLine = 0;
      _screen.appendToWindow0(
        '',
      ); // Ensure grid has a line? screen append handles empty?
      // appendToWindow0 empty does nothing?
      // We need to force a line if grid empty.
      // Modifying grid directly is easier here.
      _screen.window0Grid.add([]);
    }
    _inputCol = _screen.window0Grid.isNotEmpty
        ? _screen.window0Grid.last.length
        : 0;

    render();

    try {
      stdin.echoMode = false;
      stdin.lineMode = false;
    } catch (_) {}

    while (true) {
      final byte = stdin.readByteSync();

      // Ctrl+C (3) or Ctrl+Q (17) = exit
      if (byte == 3 || byte == 17) {
        _inputLine = -1;
        try {
          stdin.lineMode = true;
          stdin.echoMode = true;
        } catch (_) {}
        exitFullScreen();
        stdout.writeln('Interrupted.');
        exit(0);
      }

      if (byte == 13 || byte == 10) {
        // Enter key
        final result = _inputBuffer;
        // The display grid already has the chars (from incremental updates below)
        // or simplistic fallback.

        // Finalize
        appendToWindow0('\n');
        _inputBuffer = '';
        _inputLine = -1;

        try {
          stdin.lineMode = true;
          stdin.echoMode = true;
        } catch (_) {}
        applyPendingWindowShrink();
        return result;
      } else if (byte == 127 || byte == 8) {
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
      } else if (byte >= 32 && byte < 127) {
        // Printable
        final char = String.fromCharCode(byte);
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
      } else if (byte == 0x1B) {
        try {
          final next = stdin.readByteSync();
          if (next == 0x5B) {
            stdin.readByteSync();
          }
        } catch (_) {}
      } else if (byte == 0xE0 || byte == 0x00) {
        try {
          stdin.readByteSync();
        } catch (_) {}
      }
    }
  }

  /// Read a single character for char input mode.
  String readChar() {
    // Verify terminal
    if (!stdin.hasTerminal) {
      // log.warning('readChar: stdin does not have a terminal! Input might be buffered.');
    }

    try {
      stdin.echoMode = false;
      stdin.lineMode = false;
    } catch (e) {
      // log.warning('readChar: Failed to set raw mode: $e');
    }

    final byte = stdin.readByteSync();
    String char;

    if (byte == 3) {
      try {
        stdin.lineMode = true;
        stdin.echoMode = true;
      } catch (_) {}
      exitFullScreen();
      stdout.writeln('Interrupted.');
      exit(0);
    }

    if (byte == 0x1B) {
      // Small wait to ensure we don't block indefinitely if it's just ESC
      // But readByteSync blocks...
      // In Dart for a console app, standard practice for escape sequences is tricky without non-blocking check.
      // We'll assume if it's ESC, the rest follows immediately if it's a sequence.

      final next = stdin.readByteSync();
      // Support both [ (CSI) and O (Application Cursor Keys)
      if (next == 0x5B || next == 0x4F) {
        final code = stdin.readByteSync();
        switch (code) {
          case 0x41: // A (Up)
            char = String.fromCharCode(129);
            break;
          case 0x42: // B (Down)
            char = String.fromCharCode(130);
            break;
          case 0x43: // C (Right)
            char = String.fromCharCode(132);
            break;
          case 0x44: // D (Left)
            char = String.fromCharCode(131);
            break;
          default:
            char = String.fromCharCode(0x1B);
        }
      } else {
        char = String.fromCharCode(0x1B);
      }
    } else if (byte == 0xE0 || byte == 0x00) {
      final scanCode = stdin.readByteSync();
      switch (scanCode) {
        case 0x48:
          char = String.fromCharCode(129);
          break;
        case 0x50:
          char = String.fromCharCode(130);
          break;
        case 0x4D:
          char = String.fromCharCode(132);
          break;
        case 0x4B:
          char = String.fromCharCode(131);
          break;
        default:
          char = '';
      }
    } else if (byte == 13 || byte == 10) {
      char = '\n';
    } else {
      char = String.fromCharCode(byte);
    }

    try {
      stdin.lineMode = true;
      stdin.echoMode = true;
    } catch (_) {}

    applyPendingWindowShrink();
    return char;
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
        // In window 1: overwrite with spaces.
        // In window 0: ignore/newline?
        // We'll leave unimplemented for now or implement in ScreenModel later.
        // (User said "Erase Line" implementation not critical for now)
        break;
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
