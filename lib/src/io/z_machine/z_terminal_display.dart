import 'package:zart/src/io/z_machine/z_terminal_colors.dart';
import 'package:zart/src/logging.dart';
import 'package:zart/src/io/z_machine/z_screen_model.dart';
import 'package:zart/src/z_machine/z_machine.dart';
import 'package:zart/src/io/render/render_cell.dart';
import 'package:zart/src/io/z_machine/z_machine_display.dart';
import 'package:zart/src/io/render/screen_compositor.dart';
import 'package:zart/src/io/render/screen_frame.dart';
import 'package:zart/src/io/z_machine/zart_terminal.dart';
import 'package:zart/src/io/platform/platform_provider.dart';
import 'package:zart/src/io/platform/input_event.dart';

/// Z-Machine Terminal Display.
/// Uses `ScreenCompositor` to produce `ScreenFrame` objects for rendering.
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
  /// Callback when a screen frame is ready to be rendered.
  void Function(ScreenFrame frame)? onScreenReady;

  /// Callback to show a temporary message.
  void Function(String message, {int seconds})? onShowTempMessage;

  /// Screen compositor for converting RenderFrames to ScreenFrames.
  final ScreenCompositor _compositor = ScreenCompositor();

  /// Create standard terminal display.
  ZTerminalDisplay() {
    detectTerminalSize();
  }

  /// Terminal dimensions
  int _cols = 80;
  int _rows = 24;

  /// Terminal columns
  int get cols => _cols;

  /// Set terminal columns.
  set cols(int value) => _cols = value;

  /// Terminal rows (adjusted for zart bar when enabled)
  int get rows {
    final zartBarVisible =
        platformProvider?.capabilities.zartBarVisible ?? true;
    return (enableStatusBar && zartBarVisible) ? _rows - 1 : _rows;
  }

  /// Set raw terminal rows.
  set rows(int value) => _rows = value;

  final ZScreenModel _screen = ZScreenModel();

  /// Screen model
  ZScreenModel get screen => _screen;

  @override
  PlatformProvider? platformProvider;

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
  // Isolate logic removed as rendering is now handled via callbacks

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
    final savedColor = platformProvider?.capabilities.textColor ?? 1;
    // Sync index
    _currentTextColorIndex = _customTextColors.indexOf(savedColor);
    if (_currentTextColorIndex == -1) {
      _currentTextColorIndex = 0; // Default
    }
    _screen.forceWindow0Color(savedColor);
  }

  /// Shows a temporary status message in the bottom bar.
  void showTempMessage(String message, {int seconds = 3}) {
    onShowTempMessage?.call(message, seconds: seconds);
    // Render immediate message if visible
    final zartBarVisible =
        platformProvider?.capabilities.zartBarVisible ?? true;
    if (zartBarVisible) {
      render();
    }
  }

  // ignore: unused_field
  int _inputCol = 0; // Column where input started

  // helper to get key string

  int _scrollOffset = 0; // 0 = at bottom

  /// Scroll by the specified delta.
  /// Positive values scroll up (back in history), negative values scroll down.
  void scroll(int delta) {
    _scrollOffset += delta;
    if (_scrollOffset < 0) _scrollOffset = 0;
    // Note: totalMaxScroll clamping happens in the compositor during render
    render();
  }

  /// Enter full-screen mode using alternate screen buffer.
  void enterFullScreen() {
    detectTerminalSize();
    // No redundant resize here, detectTerminalSize does it
    _screen.clearWindow1(); // Init window 1
  }

  /// Exit full-screen mode and restore normal terminal.
  void exitFullScreen() {
    // Platform handles screen buffer switching
  }

  /// Detect terminal size.
  void detectTerminalSize() {
    if (platformProvider != null) {
      _cols = platformProvider!.capabilities.screenWidth;
      _rows = platformProvider!.capabilities.screenHeight;
    }

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
          // log.info('Updated Z-Header ScreenSize: ${_cols}x$rows (was ${oldCols}x${oldRows}');

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

  /// Set font and return previous font, or 0 if unavailable.
  int setFont(int fontId) => _screen.setFont(fontId);

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

    // Use the compositor to create a flat ScreenFrame from the ZScreenModel
    final frame = _screen.toRenderFrame(focusedWindowId: 0);

    // Sync scroll offset with compositor
    _compositor.setScrollOffset(_scrollOffset);

    final zartBarVisible =
        platformProvider?.capabilities.zartBarVisible ?? true;
    final screenFrame = _compositor.composite(
      frame,
      screenWidth: _cols,
      screenHeight: rows, // Use rows getter which accounts for status bar
      hideStatusBar: !enableStatusBar || !zartBarVisible,
    );

    // Update our scroll offset from compositor (in case it was clamped)
    _scrollOffset = _compositor.scrollOffset;

    // Invoke callback to render the screen
    onScreenReady?.call(screenFrame);
  }

  /// Read a line of input from the user.
  @override
  Future<String> readLine({int? windowId}) async {
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
      InputEvent event;
      if (platformProvider != null) {
        event = await platformProvider!.readInput();
        if (event.type == InputEventType.none) {
          continue; // Global scroll key handled
        }
      } else {
        throw StateError(
          'ZTerminalDisplay requires a platformProvider for input.',
        );
      }

      // Check for Macro Commands (simplified)
      if (event.type == InputEventType.macro && event.macroCommand != null) {
        final cmd = event.macroCommand!;
        _inputBuffer = cmd;
        appendToWindow0(cmd); // Echo it
        appendToWindow0('\n');
        _scrollOffset = 0; // Reset scroll
        render();
        _inputBuffer = '';
        _inputLine = -1;
        return cmd;
      }

      if (event.keyCode == SpecialKeys.enter) {
        final result = _inputBuffer;
        appendToWindow0('\n');
        _scrollOffset = 0;
        render();
        _inputBuffer = '';
        _inputLine = -1;
        return result;
      } else if (event.keyCode == SpecialKeys.delete) {
        if (_inputBuffer.isNotEmpty) {
          _inputBuffer = _inputBuffer.substring(0, _inputBuffer.length - 1);
          if (_screen.window0Grid.isNotEmpty &&
              _inputLine < _screen.window0Grid.length) {
            final rowList = _screen.window0Grid[_inputLine];
            if (rowList.isNotEmpty) rowList.removeLast();
          }
          render();
        }
      } else if (event.character != null && event.character!.isNotEmpty) {
        final char = event.character!;
        if (_isMouseSequenceChar(char)) continue;

        if (_scrollOffset > 0) _scrollOffset = 0;
        _inputBuffer += char;

        if (char == 'M' || char == 'm') {
          final mousePattern = RegExp(r'\d+;\d+;\d+[Mm]$');
          final match = mousePattern.firstMatch(_inputBuffer);
          if (match != null) {
            _inputBuffer = _inputBuffer.substring(0, match.start);
            if (_screen.window0Grid.isNotEmpty &&
                _inputLine < _screen.window0Grid.length) {
              final rowList = _screen.window0Grid[_inputLine];
              while (rowList.length > _inputCol + _inputBuffer.length) {
                if (rowList.isNotEmpty) rowList.removeLast();
              }
            }
            render();
            continue;
          }
        }

        if (_screen.window0Grid.isNotEmpty &&
            _inputLine < _screen.window0Grid.length) {
          final rowList = _screen.window0Grid[_inputLine];
          if (rowList.length < _cols) {
            rowList.add(
              RenderCell.fromZMachine(
                char,
                fgColor: 9,
                bgColor: _screen.bgColor,
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
      InputEvent event;
      if (platformProvider != null) {
        event = await platformProvider!.readInput();
        if (event.type == InputEventType.none) continue;
      } else {
        throw StateError(
          'ZTerminalDisplay requires a platformProvider for input.',
        );
      }

      if (event.keyCode == SpecialKeys.enter) return '\n';
      if (event.keyCode == SpecialKeys.delete) return '\x7F';
      if (event.keyCode == SpecialKeys.arrowUp) return '\x81';
      if (event.keyCode == SpecialKeys.arrowDown) return '\x82';
      if (event.keyCode == SpecialKeys.arrowLeft) return '\x83';
      if (event.keyCode == SpecialKeys.arrowRight) return '\x84';

      if (event.character != null && event.character!.isNotEmpty) {
        if (_scrollOffset > 0) {
          _scrollOffset = 0;
          render();
        }
        return event.character!;
      }
    }
  }
}
