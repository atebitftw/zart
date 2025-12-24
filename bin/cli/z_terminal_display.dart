import 'dart:io';

import 'package:dart_console/dart_console.dart';
import 'configuration_manager.dart';
import 'cli_renderer.dart';
import 'z_terminal_colors.dart';
import 'package:zart/src/logging.dart';
import 'package:zart/src/io/z_screen_model.dart';
import 'package:zart/src/z_machine/z_machine.dart';
import 'package:zart/src/io/render/render_cell.dart';
import 'package:zart/src/io/platform/platform_provider.dart' show ZMachineDisplay;
import 'package:zart/src/io/render/screen_compositor.dart';
import 'zart_terminal.dart';

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
class ZTerminalDisplay implements ZartTerminal, ZMachineDisplay {
  /// Shared CLI renderer for unified rendering.
  CliRenderer? _renderer;

  /// Screen compositor for converting RenderFrames to ScreenFrames.
  final ScreenCompositor _compositor = ScreenCompositor();

  /// Create standard terminal display (creates own renderer).
  ZTerminalDisplay() {
    _renderer = CliRenderer();
    detectTerminalSize();
  }

  /// Create with a shared renderer for unified rendering path.
  ZTerminalDisplay.withRenderer(CliRenderer renderer) : _renderer = renderer {
    detectTerminalSize();
  }

  /// Terminal dimensions
  int _cols = 80;
  int _rows = 24;

  /// Terminal columns
  int get cols => _cols;

  /// Terminal rows
  int get rows => (enableStatusBar && (config?.zartBarVisible ?? true)) ? _rows - 1 : _rows; // Dynamic sizing

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

  /// Hook for quicksave trigger (injected input)
  void Function()? onQuickSave;

  /// Hook for quickload trigger (injected input)
  void Function()? onQuickLoad;

  /// Whether to show the bottom status bar (default false)
  bool enableStatusBar = false;

  String _inputBuffer = '';
  int _inputLine = -1; // Line in buffer where input is happening (-1 = not in input)

  // Transient status message support
  // Isolate logic removed as rendering is now handled by CliRenderer

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
    _currentTextColorIndex = (_currentTextColorIndex + 1) % _customTextColors.length;
    final newColor = _customTextColors[_currentTextColorIndex];
    _screen.forceWindow0Color(newColor);

    // Save preference
    if (config != null) {
      config!.textColor = newColor;
    }
  }

  // State for tracking mouse escape sequences
  String _mouseSeqBuffer = '';

  /// Checks if char is part of an ongoing mouse sequence and updates state.
  /// Returns true if the char should be discarded (is part of mouse sequence).
  ///
  /// Handles multiple formats:
  /// - SGR: CSI < button ; col ; row M/m
  /// - X10: CSI M button col row (but chars arrive as digit;digit;digitM)
  bool _isMouseSequenceChar(String char) {
    if (char.length != 1) return false;
    final c = char.codeUnitAt(0);

    // Characters that can be part of mouse sequences
    final isMouseChar =
        c == 60 || // '<'
        c == 59 || // ';'
        c == 77 || // 'M'
        c == 109 || // 'm'
        (c >= 48 && c <= 57); // 0-9

    // If we're in the middle of a mouse sequence
    if (_mouseSeqBuffer.isNotEmpty) {
      if (isMouseChar) {
        _mouseSeqBuffer += char;
        // Check if sequence is complete (ends with M or m)
        if (char == 'M' || char == 'm') {
          // Validate it looks like a mouse sequence
          // SGR: <num;num;numM or X10: num;num;numM
          if (RegExp(r'^<?(\d+;)+\d+[Mm]$').hasMatch(_mouseSeqBuffer)) {
            _mouseSeqBuffer = ''; // Reset
            return true; // Discard
          }
          // Doesn't match expected pattern - reset
          _mouseSeqBuffer = '';
          return true; // Still discard malformed sequence
        }
        return true; // Still collecting
      } else {
        // Non-mouse char breaks the sequence
        // This wasn't a real mouse sequence
        _mouseSeqBuffer = '';
        return false; // Allow this char through
      }
    }

    // Check if this starts a new mouse sequence
    // SGR starts with '<', X10 starts with digit followed by ';'
    if (char == '<') {
      _mouseSeqBuffer = '<';
      return true;
    }

    // Don't start sequence on just a digit - need to see the pattern first
    // This is tricky - let's be more conservative and only filter when
    // we see the pattern digit;digit;digitM retroactively

    return false;
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
    _renderer?.showTempMessage(message, seconds: seconds);
    // Render immediate message if visible
    if (config?.zartBarVisible ?? true) {
      render();
    }
  }

  // ignore: unused_field
  int _inputCol = 0; // Column where input started

  // ANSI helper via console?
  bool get _supportsAnsi => true; // dart_console handles this internally usually

  // helper to get key string

  int _scrollOffset = 0; // 0 = at bottom

  /// Enter full-screen mode using alternate screen buffer.
  void enterFullScreen() {
    // Try to switch to alternate buffer manually
    stdout.write('\x1B[?1049h');

    _console.rawMode = true;
    _console.hideCursor();
    _console.clearScreen();

    detectTerminalSize();
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
  void detectTerminalSize() {
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

          // Signal a redraw to the game (Standard 1.1, Bit 2 of Flags 2)
          // Flags 2 is at 0x10. Bit 2 is in the low byte at 0x11.
          final currentFlags2 = Z.engine.mem.loadb(0x11);
          Z.engine.mem.storeb(0x11, currentFlags2 | 0x04);
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
    _savedTerminalState = {'inputLine': _inputLine, 'inputBuffer': _inputBuffer, 'inputCol': _inputCol};
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
    detectTerminalSize(); // Updates _screen cols/rows

    if (!_supportsAnsi) {
      _renderFallback();
      return;
    }

    // Use the compositor to create a flat ScreenFrame from the ZScreenModel
    final frame = _screen.toRenderFrame(focusedWindowId: 0);

    // Sync scroll offset with compositor
    _compositor.setScrollOffset(_scrollOffset);

    final screenFrame = _compositor.composite(
      frame,
      screenWidth: _cols,
      screenHeight: rows, // Use rows getter which accounts for status bar
    );

    // Update our scroll offset from compositor (in case it was clamped)
    _scrollOffset = _compositor.scrollOffset;

    // Sync status bar settings before render
    if (_renderer != null) {
      _renderer!.zartBarVisible = enableStatusBar && (config?.zartBarVisible ?? true);
      if (config != null) {
        _renderer!.zartBarForeground = config!.zartBarForeground;
        _renderer!.zartBarBackground = config!.zartBarBackground;
      }
    }

    // Delegate to CliRenderer for actual terminal output
    _renderer?.renderScreen(screenFrame);
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

  /// Process global keys (F1-F4, etc). Returns (consumed, restored).
  Future<(bool, bool)> _handleGlobalKeys(Key key) async {
    if (key.controlChar == ControlCharacter.F1) {
      if (onOpenSettings != null) {
        await onOpenSettings!();
        render(); // Re-render after returning
      }
      return (true, false);
    } else if (key.controlChar == ControlCharacter.F2) {
      // Set quicksave flag so platform auto-fills filename
      onQuickSave?.call();
      // Inject "save" command and signal input should return it
      _inputBuffer = 'save';
      appendToWindow0('save\n');
      _scrollOffset = 0;
      render();
      _inputLine = -1;
      return (true, false);
    } else if (key.controlChar == ControlCharacter.F3) {
      // Set quickrestore flag so platform auto-fills filename
      onQuickLoad?.call();
      // Inject "restore" command and signal input should return it
      _inputBuffer = 'restore';
      appendToWindow0('restore\n');
      _scrollOffset = 0;
      render();
      _inputLine = -1;
      return (true, false);
    } else if (key.controlChar == ControlCharacter.F4) {
      _cycleTextColor();
      render();
      return (true, false);
    } else if (key.controlChar == ControlCharacter.pageUp) {
      // Scroll up (back in history)
      final maxScroll = (_screen.window0Grid.length > _screen.window0Lines)
          ? _screen.window0Grid.length - _screen.window0Lines
          : 0;
      _scrollOffset += 5; // Scroll 5 lines at a time
      if (_scrollOffset > maxScroll) _scrollOffset = maxScroll;
      render();
      return (true, false);
    } else if (key.controlChar == ControlCharacter.pageDown) {
      // Scroll down (toward current)
      _scrollOffset -= 5;
      if (_scrollOffset < 0) _scrollOffset = 0;
      render();
      return (true, false);
    }
    return (false, false);
  }

  /// Read a line of input from the user.
  Future<String> readLine() async {
    // Disable mouse tracking to prevent mouse events from appearing in input
    // These codes disable various mouse modes that terminals may have enabled
    stdout.write('\x1b[?1000l'); // Disable X10 mouse tracking
    stdout.write('\x1b[?1002l'); // Disable cell motion tracking
    stdout.write('\x1b[?1003l'); // Disable all motion tracking
    stdout.write('\x1b[?1006l'); // Disable SGR extended mouse mode

    _inputBuffer = '';
    // Reset scroll when starting new input?
    // Usually yes, if typing, we want to see what we type.
    _scrollOffset = 0;

    // Remember where input starts (end of current content)
    _inputLine = _screen.window0Grid.isNotEmpty ? _screen.window0Grid.length - 1 : 0;
    if (_screen.window0Grid.isEmpty) {
      _inputLine = 0;
      _screen.appendToWindow0('');
      _screen.window0Grid.add([]);
    }
    _inputCol = _screen.window0Grid.isNotEmpty ? _screen.window0Grid.last.length : 0;

    render();

    while (true) {
      // Blocking read (sync) but in async function
      final key = _console.readKey();

      final (consumed, restored) = await _handleGlobalKeys(key);
      if (consumed) {
        if (restored) {
          _inputBuffer = '';
          _inputLine = -1;
          return '__RESTORED__';
        }
        // F2/F3 may have set _inputBuffer directly - return it
        if (_inputBuffer.isNotEmpty && _inputLine == -1) {
          final result = _inputBuffer;
          _inputBuffer = '';
          return result;
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
      key.controlChar.toString().contains('.ctrl') && key.controlChar != ControlCharacter.ctrlC) {
        // Extract letter
        final s = key.controlChar.toString();
        // Handle both ControlCharacter.ctrlA and ctrlA formats
        final match = RegExp(r'ctrl([a-z])$', caseSensitive: false).firstMatch(s);
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
          if (_screen.window0Grid.isNotEmpty && _inputLine < _screen.window0Grid.length) {
            final rowList = _screen.window0Grid[_inputLine];
            if (rowList.isNotEmpty) {
              rowList.removeLast();
            }
          }
          render();
        }
      } else if (key.char.isNotEmpty) {
        // Printable character
        final char = key.char;

        // SGR mouse sequences start with '<' - filter proactively
        if (_isMouseSequenceChar(char)) {
          continue;
        }

        // Add char to buffer
        _inputBuffer += char;

        // Check if this char completes a mouse sequence (M or m terminator)
        // X10/Normal mouse format: digit;digit;digitM
        if (char == 'M' || char == 'm') {
          // Check if buffer ends with mouse sequence pattern
          final mousePattern = RegExp(r'\d+;\d+;\d+[Mm]$');
          final match = mousePattern.firstMatch(_inputBuffer);
          if (match != null) {
            // Strip the mouse sequence from buffer
            _inputBuffer = _inputBuffer.substring(0, match.start);
            // Re-sync the grid - remove chars from end
            if (_screen.window0Grid.isNotEmpty && _inputLine < _screen.window0Grid.length) {
              final rowList = _screen.window0Grid[_inputLine];
              while (rowList.length > _inputCol + _inputBuffer.length) {
                if (rowList.isNotEmpty) rowList.removeLast();
              }
            }
            render();
            continue;
          }
        }

        // Update Grid (add cell for this char)
        if (_screen.window0Grid.isNotEmpty && _inputLine < _screen.window0Grid.length) {
          final rowList = _screen.window0Grid[_inputLine];
          if (rowList.length < _cols) {
            // Force user input to be White using RenderCell with RGB
            rowList.add(
              RenderCell.fromZMachine(char, fgColor: 9, bgColor: _screen.bgColor, style: _screen.currentStyle),
            );
          }
        }
        render();
      }
    }
  }

  /// Read a single character for char input mode.
  Future<String> readChar() async {
    // Disable mouse tracking to prevent mouse events from appearing in input
    stdout.write('\x1b[?1000l\x1b[?1002l\x1b[?1003l\x1b[?1006l');

    while (true) {
      final key = _console.readKey();

      // Handle Ctrl+C to exit
      if (key.controlChar == ControlCharacter.ctrlC) {
        throw Exception('User pressed Ctrl+C');
      }

      final (consumed, restored) = await _handleGlobalKeys(key);
      if (consumed) {
        if (restored) {
          return '__RESTORED__';
        }
        continue;
      }

      // Map control characters to their expected values
      if (key.controlChar == ControlCharacter.enter) return '\n';
      if (key.controlChar == ControlCharacter.backspace) return '\x7F';
      if (key.controlChar == ControlCharacter.arrowUp) return '\x81';
      if (key.controlChar == ControlCharacter.arrowDown) return '\x82';
      if (key.controlChar == ControlCharacter.arrowLeft) return '\x83';
      if (key.controlChar == ControlCharacter.arrowRight) return '\x84';

      // Only return if we have a valid character
      if (key.char.isNotEmpty) {
        return key.char;
      }
      // Otherwise continue waiting for valid input
    }
  }
}
