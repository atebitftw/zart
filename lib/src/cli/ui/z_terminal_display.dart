import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:dart_console/dart_console.dart';
import 'package:zart/src/cli/config/configuration_manager.dart';
import 'package:zart/src/cli/ui/cli_renderer.dart';
import 'package:zart/src/cli/ui/z_terminal_colors.dart';
import 'package:zart/src/logging.dart';
import 'package:zart/src/io/z_screen_model.dart';
import 'package:zart/src/z_machine/z_machine.dart';
import 'package:zart/src/io/cell.dart';
import 'package:zart/src/cli/ui/zart_terminal.dart';

const _zartBarText =
    "(Zart) F1=Settings, F2=QuickSave, F3=QuickLoad, F4=Text Color, PgUp/PgDn=Scroll";

/// Z-Machine Terminal Display.
/// Used by the unified [CliRenderer] for rendering.
///
/// Layout:
/// ```text
/// ┌────────────────────────────────┐
/// │ Window 1 (status/upper)        │
/// ├────────────────────────────────┤ ← Separator
/// │ Window 0 (main, scrollable)    │
/// │ (text, text)                   │
/// │ > [input line]                 │
/// └────────────────────────────────┘
/// ```
class ZTerminalDisplay implements ZartTerminal {
  /// Create standard terminal display.
  ZTerminalDisplay();

  /// Create with a shared renderer.
  /// Note: Currently uses its own rendering; will migrate to CliRenderer.
  factory ZTerminalDisplay.withRenderer(CliRenderer renderer) {
    // TODO: Migrate to use CliRenderer for unified rendering
    return ZTerminalDisplay();
  }

  /// Terminal dimensions
  int _cols = 80;
  int _rows = 24;

  /// Terminal columns
  int get cols => _cols;

  /// Terminal rows
  int get rows => (enableStatusBar && (config?.zartBarVisible ?? true))
      ? _rows - 1
      : _rows; // Dynamic sizing

  final ZScreenModel _screen = ZScreenModel();

  /// Screen model
  ZScreenModel get screen => _screen;

  final Console _console = Console();

  /// Reference to configuration
  ConfigurationManager? config;

  /// Hook for opening settings
  Future<void> Function()? onOpenSettings;

  /// Hook for autosave trigger
  void Function()? onAutosave;

  /// Hook for autorestore trigger
  void Function()? onRestore;

  /// Whether to show the bottom status bar (default false)
  bool enableStatusBar = false;

  String _inputBuffer = '';
  int _inputLine =
      -1; // Line in buffer where input is happening (-1 = not in input)

  // Transient status message support
  String? _tempStatusMessage;
  DateTime? _tempStatusExpiry;
  // We use an isolate to update the UI while the main isolate is blocked on readKey
  Isolate? _statusResetIsolate;

  // Custom Text Color Cycling Options
  final List<int> _customTextColors = [
    ZTerminalColors.lightGrey,
    ZTerminalColors.darkGrey,
    ZTerminalColors.white,
    ZTerminalColors.red,
    ZTerminalColors.green,
    ZTerminalColors.yellow,
    ZTerminalColors.blue,
    ZTerminalColors.magenta,
    ZTerminalColors.cyan,
  ];

  int _currentTextColorIndex = 0;

  void _cycleTextColor() {
    _currentTextColorIndex =
        (_currentTextColorIndex + 1) % _customTextColors.length;
    final newColor = _customTextColors[_currentTextColorIndex];
    _screen.forceWindow0Color(newColor);

    // Save preference
    if (config != null) {
      config!.textColor = newColor;
    }
  }

  /// Apply settings from configuration (e.g. initial color)
  void applySavedSettings() {
    if (config != null) {
      final savedColor = config!.textColor;
      // Sync index
      _currentTextColorIndex = _customTextColors.indexOf(savedColor);
      if (_currentTextColorIndex == -1) {
        _currentTextColorIndex = 0; // Default
      }
      _screen.forceWindow0Color(savedColor);
    }
  }

  /// Shows a temporary status message in the bottom bar.
  void showTempMessage(String message, {int seconds = 3}) {
    _tempStatusMessage = message;
    _tempStatusExpiry = DateTime.now().add(Duration(seconds: seconds));

    // Kill existing reset isolate if any
    _statusResetIsolate?.kill(priority: Isolate.immediate);

    // Render immediate message
    // Only if visible
    if (config?.zartBarVisible ?? true) {
      render();
    }

    // Spawn isolate to visually reset the status bar after [seconds]
    // The isolate writes directly to stdout using ANSI codes since main loop is blocked.
    // It blindly overwrites the status bar area with the default text.
    final row = _console.windowHeight; // Status bar row
    final col = _cols;

    Isolate.spawn(_restoreStatusBarIsolate, {
      'seconds': seconds,
      'row': row,
      'cols': col,
      'fgAnsi': _fgAnsi(config?.zartBarForeground ?? 9),
      'bgAnsi': _bgAnsi(config?.zartBarBackground ?? 10),
      'visible': config?.zartBarVisible ?? true,
    }).then((iso) => _statusResetIsolate = iso);
  }

  /// Static function for the isolate to run
  static void _restoreStatusBarIsolate(Map<String, dynamic> args) {
    final seconds = args['seconds'] as int;
    final row = args['row'] as int;
    final visible = args['visible'] as bool;

    if (!visible) return;

    final cols = args['cols'] as int; // Width to pad

    sleep(Duration(seconds: seconds));

    final paddedText = _zartBarText.padRight(cols);
    final finalText = paddedText.length > cols
        ? paddedText.substring(0, cols)
        : paddedText;

    // ANSI Sequence:
    // 1. Save Cursor (\x1b7)
    // 2. Move to Status Row (\x1b[<row>;1H)
    // 3. Set Inverse Video (\x1b[7m)
    // 4. Write Text
    // 5. Reset Attributes (\x1b[0m)
    // 6. Restore Cursor (\x1b8)

    final fgAnsi = args['fgAnsi'] as String;
    final bgAnsi = args['bgAnsi'] as String;

    stdout.write('\x1b7\x1b[$row;1H$fgAnsi$bgAnsi$finalText\x1b[0m\x1b8');
  }

  // ignore: unused_field
  int _inputCol = 0; // Column where input started

  // ANSI helper via console?
  bool get _supportsAnsi =>
      true; // dart_console handles this internally usually

  // helper to get key string

  int _scrollOffset = 0; // 0 = at bottom

  /// Enter full-screen mode using alternate screen buffer.
  void enterFullScreen() {
    // Try to switch to alternate buffer manually
    stdout.write('\x1B[?1049h');

    _console.rawMode = true;
    _console.hideCursor();
    _console.clearScreen();

    _detectTerminalSize();
    // No redundant resize here, _detectTerminalSize does it
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

    // Resize based on dynamic 'rows' getter
    _screen.resize(_cols, rows);
    // Reserve 2 columns for scroll bar (1 for bar, 1 for padding)
    _screen.wrapWidth = _cols - 2;

    // Update Z-Machine Header with screen dimensions (Standard 1.0, 8.4)
    if (Z.isLoaded) {
      try {
        final oldRows = Z.engine.mem.loadb(0x20);
        final oldCols = Z.engine.mem.loadb(0x21);

        // Update Bytes (0x20, 0x21) - legacy/all versions, max 255
        // Use 'rows' getter here as well to reflect playable area
        Z.engine.mem.storeb(0x20, rows > 255 ? 255 : rows);
        Z.engine.mem.storeb(0x21, cols > 255 ? 255 : cols);

        // Update Words (0x22, 0x24) - V5+ units (1 unit = 1 char here)
        // Check version > 3 (actually V4 might use it, but V5 definitely does)
        if (ZMachine.verToInt(Z.ver!) >= 5) {
          Z.engine.mem.storew(0x22, cols);
          Z.engine.mem.storew(0x24, rows);
          // Standardize Units: 1 Unit = 1 Char
          Z.engine.mem.storeb(0x26, 1);
          Z.engine.mem.storeb(0x27, 1);
        }

        if (oldRows != rows || oldCols != _cols) {
          // Log verbose if needed, usually omitted to reduce spam
          // log.info('Updated Z-Header ScreenSize: ${_cols}x$rows (was ${oldCols}x${oldRows})');
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

  /// Clear Window 1.
  void clearWindow1() => _screen.clearWindow1();

  /// Clear Window 0.
  void clearWindow0() => _screen.clearWindow0();

  /// Clear all windows.
  void clearAll() {
    _screen.clearAll();
    // After clearing, we often want to re-render to show blank state + status bar
    // But usually clearAll is followed by text output.
    // If we just clear, the status bar might disappear if the terminal was cleared.
    // _screen.clearAll doesn't clear the actual terminal, it clears the model.
    // render() updates the terminal.
    // So we don't strictly need to change this if render is called.
    // However, if we want immediate feedback:
    render();
  }

  // Internal state storage for terminal-specific fields
  Map<String, dynamic>? _savedTerminalState;

  /// Save screen state (for settings/menus).
  void saveState() {
    _screen.saveState();
    _savedTerminalState = {
      'inputLine': _inputLine,
      'inputBuffer': _inputBuffer,
      'inputCol': _inputCol,
    };
  }

  /// Restore screen state.
  void restoreState() {
    _screen.restoreState();
    if (_savedTerminalState != null) {
      _inputLine = _savedTerminalState!['inputLine'];
      _inputBuffer = _savedTerminalState!['inputBuffer'];
      _inputCol = _savedTerminalState!['inputCol'];
      _savedTerminalState = null;
    }
  }

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
        return '\x1B[97m'; // Bright White
      case 10:
        return '\x1B[90m'; // Bright Black (Dark Grey)
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
      case 10:
        return '\x1B[100m'; // Bright Black (Dark Grey)
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

  /// Append player input text to Window 0 with forced white color.
  /// This makes input stand out from game output when colors are changed.
  void appendInputEcho(String text) {
    // Save current color, force white (9), append, restore
    final savedFg = _screen.fgColor;
    _screen.fgColor = 9; // White
    _screen.appendToWindow0(text);
    _screen.fgColor = savedFg;
  }

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
          // Smart Reverse Video Logic
          // If in reverse mode, the effective background is the current foreground.
          // We want to improve legibility.  This is a style choice based on the
          // testing of many games.
          if (hasReverse) {
            // Resolve effective background (current foreground)
            // Assume Default (1) is White (9) for this check
            final effectiveBg = (fg == 1) ? 9 : fg;

            if (effectiveBg == 9) {
              // Background is White -> Text (which comes from 'bg' in reverse) must be Black
              bg = 2;
            } else {
              // Background is NOT White -> Text must be White
              bg = 9;
            }
          }

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

    // Calculate maximum possible scroll
    // w0Grid.length is total history. window0Lines is viewport height.
    final maxScroll = (w0Grid.length > window0Lines)
        ? w0Grid.length - window0Lines
        : 0;

    // Clamp offset
    if (_scrollOffset > maxScroll) _scrollOffset = maxScroll;
    if (_scrollOffset < 0) _scrollOffset = 0;

    // Calculate start index based on scroll offset from bottom
    // If offset=0, start = maxScroll (which is length - window0Lines)
    final startLine = maxScroll - _scrollOffset;

    for (int i = 0; i < window0Lines; i++) {
      buf.write('\x1B[$currentRow;1H');
      buf.write('\x1B[K'); // Clear line to remove artifacts

      final lineIndex = startLine + i;
      if (lineIndex >= 0 && lineIndex < w0Grid.length) {
        renderRow(currentRow, w0Grid[lineIndex], forceFullWidth: false);
      }
      currentRow++;
    }

    // Draw Scroll Bar if needed
    if (maxScroll > 0) {
      _drawScrollBar(
        buf,
        window0Lines,
        startLine,
        w0Grid.length,
        window1Lines + separatorLine + 1,
      );
    }

    // Draw status bar
    if (enableStatusBar) {
      _drawStatusBar(buf);
    }

    // Position cursor at end of input line if we're in input mode
    // Only show cursor if we are at the bottom (scrollOffset == 0)
    // AND we are actually waiting for input.
    // However, if the user scrolls up, they usually want to see where they are scrolling.
    // The cursor should logically stay with the input line. If input line is scrolled off, cursor should hide.

    if (_inputLine >= 0 && _inputLine < w0Grid.length && _scrollOffset == 0) {
      // Calculate which screen row the input line is on
      // It's usually the last drawn line, or close to it.
      // inputLine is an index in window0Grid.
      // Our viewport starts at 'startLine'.
      final inputRelativeRaw = _inputLine - startLine;

      if (inputRelativeRaw >= 0 && inputRelativeRaw < window0Lines) {
        final inputScreenRow =
            inputRelativeRaw + window1Lines + separatorLine + 1;

        if (inputScreenRow >= 1 &&
            inputScreenRow <= _rows &&
            inputScreenRow < _console.windowHeight) {
          final cursorCol = w0Grid[_inputLine].length + 1;
          buf.write('\x1B[$inputScreenRow;${cursorCol}H');
          buf.write('\x1B[?25h'); // Show cursor
        }
      }
    } else {
      buf.write('\x1B[?25l'); // Hide cursor if scrolled up or not input
    }

    stdout.write(buf.toString());
  }

  void _drawScrollBar(
    StringBuffer buf,
    int height,
    int currentStart,
    int totalLines,
    int startRow,
  ) {
    if (totalLines <= height) return;

    // Calculate visible ratio
    final double ratio = height / totalLines;
    final int thumbSize = (height * ratio).ceil().clamp(1, height);

    // Calculate thumb position
    // currentStart ranges from 0 to (totalLines - height)
    final int maxStart = totalLines - height;
    final double posRatio = (maxStart > 0) ? currentStart / maxStart : 0.0;

    // Position 0 = Top of scrollbar area
    // Max Pos = height - thumbSize
    final int thumbPos = ((height - thumbSize) * posRatio).round();

    // Draw
    // We are overlaying on the rightmost column (_cols)
    final int col = _cols;

    // Save current cursor? We just move it and reset at end of render anyway.
    // Use slightly different colors for scrollbar track vs thumb

    // Track (Dark Grey or just standard background?)
    // Thumb (White or Bright)

    // Standard ASCII Block chars
    // Thumb: █ (\u2588)
    // Track: │ (\u2502) or just dimmer

    for (int i = 0; i < height; i++) {
      final int row = startRow + i;
      buf.write('\x1B[$row;${col}H');

      if (i >= thumbPos && i < thumbPos + thumbSize) {
        // Thumb
        buf.write('\x1B[37;40m'); // White on Black
        buf.write('█');
      } else {
        // Track
        buf.write('\x1B[90;40m'); // Dark Grey on Black
        buf.write('│');
      }
      buf.write('\x1B[0m'); // Reset
    }
  }

  void _drawStatusBar(StringBuffer buf) {
    if (!(config?.zartBarVisible ?? true)) return;

    if (_tempStatusMessage != null &&
        _tempStatusExpiry != null &&
        DateTime.now().isAfter(_tempStatusExpiry!)) {
      _tempStatusMessage = null;
    }

    String statusText;
    if (_tempStatusMessage != null) {
      statusText = " $_tempStatusMessage"; // Add leading space
    } else {
      statusText = _zartBarText;
    }

    // Pad with spaces to fill width
    final paddedText = statusText.padRight(_cols);
    // Truncate if too long to prevent wrapping
    final finalText = paddedText.length > _cols
        ? paddedText.substring(0, _cols)
        : paddedText;

    // Position at last row (using _console.windowHeight directly)
    // Note: _rows is now windowHeight - 1
    final statusRow = _console.windowHeight;

    buf.write('\x1B[$statusRow;1H'); // Move to last row

    // Configurable Colors (Default White on Dark Grey)
    final fg = config?.zartBarForeground ?? 9;
    final bg = config?.zartBarBackground ?? 10;

    buf.write(_fgAnsi(fg));
    buf.write(_bgAnsi(bg));
    buf.write(finalText);
    buf.write('\x1B[0m'); // Reset attributes
    // Cursor is now at end of status bar, need to move it back if we want input?
    // The render() method handles moving it back for input immediately after this call.
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

  /// Process global keys (F1-F4, etc). Returns true if handled.
  Future<bool> _handleGlobalKeys(Key key) async {
    if (key.controlChar == ControlCharacter.F1) {
      if (onOpenSettings != null) {
        await onOpenSettings!();
        render(); // Re-render after returning
      }
      return true;
    } else if (key.controlChar == ControlCharacter.F2) {
      if (onAutosave != null) {
        onAutosave!();
        // Return true to prevent default "Coming Soon" message
        // But we actually want to trigger the game command.
        // The issue is _handleGlobalKeys returns 'bool' meaning "Consumed".
        // If we want to return "save" to the caller (readLine), we can't do it easily from here purely with bool.
        // We need a side-channel or simply return false and let the caller handle it if it knows?
        // OR: readLine calls this.
        // Let's modify readLine/readChar to check for specific signal or just check here.
        // Actually, F2 handling in `readLine` loop (below) was consuming it.
        // Let's keep returning TRUE here so default logic doesn't run,
        // AND handle the command injection in `readLine`.
        return true;
      }
      return true; // Still consume it to prevent weird chars
    } else if (key.controlChar == ControlCharacter.F3) {
      if (onRestore != null) {
        onRestore!();
        return true;
      }
      return true;
    } else if (key.controlChar == ControlCharacter.F4) {
      _cycleTextColor();
      render();
      return true;
    } else if (key.controlChar == ControlCharacter.pageUp) {
      // Scroll up (back in history)
      final maxScroll = (_screen.window0Grid.length > _screen.window0Lines)
          ? _screen.window0Grid.length - _screen.window0Lines
          : 0;
      _scrollOffset += 5; // Scroll 5 lines at a time
      if (_scrollOffset > maxScroll) _scrollOffset = maxScroll;
      render();
      return true;
    } else if (key.controlChar == ControlCharacter.pageDown) {
      // Scroll down (toward current)
      _scrollOffset -= 5;
      if (_scrollOffset < 0) _scrollOffset = 0;
      render();
      return true;
    }
    return false;
  }

  /// Read a line of input from the user.
  Future<String> readLine() async {
    _inputBuffer = '';
    // Reset scroll when starting new input?
    // Usually yes, if typing, we want to see what we type.
    _scrollOffset = 0;

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

      if (await _handleGlobalKeys(key)) {
        if (key.controlChar == ControlCharacter.F2) {
          // Autosave triggered in _handleGlobalKeys (callback fired).
          // Now inject "save" command
          _inputBuffer = 'save';
          appendToWindow0('save\n');
          render();
          _inputBuffer = '';
          _inputLine = -1;
          return 'save';
        }
        if (key.controlChar == ControlCharacter.F3) {
          // Autorestore triggered
          _inputBuffer = 'restore';
          appendToWindow0('restore\n');
          render();
          _inputBuffer = '';
          _inputLine = -1;
          return 'restore';
        }

        if (key.controlChar == ControlCharacter.F4) {
          // Handled by _handleGlobalKeys, just refresh input line rendering if needed?
          // Actually _handleGlobalKeys calls render().
          // We just continue loop.
        }
        continue;
      }

      if (key.controlChar == ControlCharacter.enter) {
        // Enter key
        final result = _inputBuffer;
        appendToWindow0('\n');
        // Reset Scroll on Enter
        _scrollOffset = 0;
        render();
        _inputBuffer = '';
        _inputLine = -1;
        return result;
      } else if (key.controlChar == ControlCharacter.ctrlC) {
        // Ctrl+C - throw to allow cleanup in zart.dart finally block
        throw Exception('User pressed Ctrl+C');
      } else if (
      // Check for Ctrl+Key Macros
      // We assume mapped control attributes effectively.
      // Note: dart_console often maps Ctrl+A to unit separator etc or ControlCharacter.ctrlA
      key.controlChar.toString().contains('.ctrl') &&
          key.controlChar != ControlCharacter.ctrlC) {
        // Extract letter
        final s = key.controlChar.toString();
        // Handle both ControlCharacter.ctrlA and ctrlA formats
        final match = RegExp(
          r'ctrl([a-z])$',
          caseSensitive: false,
        ).firstMatch(s);
        if (match != null) {
          final letter = match.group(1)!.toLowerCase();
          final bindingKey = 'ctrl+$letter';

          if (config != null) {
            final cmd = config!.getBinding(bindingKey);
            if (cmd != null) {
              _inputBuffer = cmd;
              appendToWindow0(cmd); // Echo it
              appendToWindow0('\n');
              _scrollOffset = 0; // Reset scroll
              render();
              _inputBuffer = '';
              _inputLine = -1;
              return cmd;
            }
          }
        }
      } else if (key.controlChar == ControlCharacter.backspace) {
        // ... existing backspace logic ...
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

        // Update Grid
        if (_screen.window0Grid.isNotEmpty &&
            _inputLine < _screen.window0Grid.length) {
          final rowList = _screen.window0Grid[_inputLine];
          if (rowList.length < _cols) {
            // Force user input to be White (9) per user request
            rowList.add(
              Cell(
                char,
                fg: 9,
                bg: _screen.bgColor,
                style: _screen.currentStyle,
              ),
            );
          }
        }
        render();
      }
    }
  }

  /// Read a single character for char input mode.
  Future<String> readChar() async {
    while (true) {
      final key = _console.readKey();

      // Handle Ctrl+C to exit
      if (key.controlChar == ControlCharacter.ctrlC) {
        throw Exception('User pressed Ctrl+C');
      }

      if (await _handleGlobalKeys(key)) continue;

      // Map control characters to their expected values
      if (key.controlChar == ControlCharacter.enter) return '\n';
      if (key.controlChar == ControlCharacter.backspace) return '\x7F';
      if (key.controlChar == ControlCharacter.arrowUp) return '\x81';
      if (key.controlChar == ControlCharacter.arrowDown) return '\x82';
      if (key.controlChar == ControlCharacter.arrowLeft) return '\x83';
      if (key.controlChar == ControlCharacter.arrowRight) return '\x84';

      return key.char.isNotEmpty ? key.char : '';
    }
  }
}
