import 'dart:async';
import 'dart:io';

import 'package:dart_console/dart_console.dart';
import 'package:zart/src/io/glk/glk_cell.dart';
import 'package:zart/src/io/glk/glk_screen_model.dart';
import 'package:zart/src/io/glk/glk_styles.dart';
import 'package:zart/src/io/glk/glk_window.dart';

/// Terminal display for Glk/Glulx games.
///
/// Renders a GlkScreenModel to the terminal, handling:
/// - Multiple window layout
/// - Focus indicators for input windows
/// - Glk style to ANSI mapping
class GlkTerminalDisplay {
  final Console _console = Console();

  /// Screen dimensions.
  int cols = 80;
  int rows = 24;

  GlkTerminalDisplay() {
    _detectTerminalSize();
  }

  void _detectTerminalSize() {
    try {
      cols = _console.windowWidth;
      rows = _console.windowHeight;
    } catch (_) {
      cols = 80;
      rows = 24;
    }
  }

  /// Enter full-screen mode.
  void enterFullScreen() {
    _console.rawMode = true;
    stdout.write('\x1B[?1049h'); // Alternate screen buffer
    stdout.write('\x1B[?25l'); // Hide cursor
    stdout.write('\x1B[2J'); // Clear screen
  }

  /// Exit full-screen mode.
  void exitFullScreen() {
    stdout.write('\x1B[?25h'); // Show cursor
    stdout.write('\x1B[?1049l'); // Exit alternate screen buffer
    _console.rawMode = false;
  }

  /// Track cursor position for input
  int _cursorRow = 0;
  int _cursorCol = 0;

  /// Render the entire screen from the GlkScreenModel.
  void render(GlkScreenModel model) {
    _detectTerminalSize();
    model.setScreenSize(cols, rows);

    final visibleWindows = model.getVisibleWindows();

    final buf = StringBuffer();
    buf.write('\x1B[H'); // Move to home position

    // Create a screen buffer
    final screen = List.generate(
      rows,
      (_) => List.generate(cols, (_) => GlkCell.empty()),
    );

    // Track where to place cursor (end of focused window)
    _cursorRow = rows - 1;
    _cursorCol = 0;

    // Render each visible window to the buffer
    for (final winInfo in visibleWindows) {
      final window = model.getWindow(winInfo.windowId);
      if (window == null) continue;

      final isFocused = model.isFocused(winInfo.windowId);

      if (window is GlkTextGridWindow) {
        _renderGridWindow(screen, window, winInfo, isFocused);
      } else if (window is GlkTextBufferWindow) {
        _renderBufferWindow(screen, window, winInfo, isFocused);
      }
      // Blank and graphics windows just show empty space (already filled)
    }

    // Output the screen buffer
    for (var row = 0; row < rows; row++) {
      buf.write(_renderRow(screen[row]));
      if (row < rows - 1) buf.write('\n');
    }

    buf.write('\x1B[0m'); // Reset style
    // Position cursor at the input location (1-indexed for ANSI)
    buf.write('\x1B[${_cursorRow + 1};${_cursorCol + 1}H');
    stdout.write(buf.toString());
  }

  void _renderGridWindow(
    List<List<GlkCell>> screen,
    GlkTextGridWindow window,
    GlkWindowRenderInfo info,
    bool isFocused,
  ) {
    for (var row = 0; row < info.height && row < window.grid.length; row++) {
      final screenRow = info.y + row;
      if (screenRow >= rows) break;

      for (
        var col = 0;
        col < info.width && col < window.grid[row].length;
        col++
      ) {
        final screenCol = info.x + col;
        if (screenCol >= cols) break;

        screen[screenRow][screenCol] = window.grid[row][col];
      }
    }

    // If focused, set cursor to grid cursor position
    if (isFocused) {
      _cursorRow = info.y + window.cursorY;
      _cursorCol = info.x + window.cursorX;
    }
  }

  void _renderBufferWindow(
    List<List<GlkCell>> screen,
    GlkTextBufferWindow window,
    GlkWindowRenderInfo info,
    bool isFocused,
  ) {
    // Show the most recent lines that fit in the window
    final startLine = (window.lines.length > info.height)
        ? window.lines.length - info.height
        : 0;

    for (var i = 0; i < info.height; i++) {
      final lineIdx = startLine + i;
      final screenRow = info.y + i;
      if (screenRow >= rows) break;

      if (lineIdx < window.lines.length) {
        final line = window.lines[lineIdx];
        for (var col = 0; col < info.width && col < line.length; col++) {
          final screenCol = info.x + col;
          if (screenCol >= cols) break;
          screen[screenRow][screenCol] = line[col];
        }
      }
    }

    // If focused, set cursor to end of last line
    if (isFocused && window.lines.isNotEmpty) {
      final lastLineIdx = window.lines.length - 1;
      final screenLineIdx = lastLineIdx - startLine;
      if (screenLineIdx >= 0 && screenLineIdx < info.height) {
        _cursorRow = info.y + screenLineIdx;
        _cursorCol = info.x + window.lines[lastLineIdx].length;
        // Clamp to window bounds
        if (_cursorCol >= info.x + info.width) {
          _cursorCol = info.x + info.width - 1;
        }
      }
    }
  }

  String _renderRow(List<GlkCell> cells) {
    final buf = StringBuffer();
    var lastStyle = -1;

    for (final cell in cells) {
      if (cell.style != lastStyle) {
        buf.write(_styleToAnsi(cell.style));
        lastStyle = cell.style;
      }
      buf.write(cell.char);
    }

    buf.write('\x1B[0m'); // Reset at end of row
    return buf.toString();
  }

  /// Map Glk style to ANSI escape code.
  String _styleToAnsi(int style) {
    switch (style) {
      case GlkStyle.normal:
        return '\x1B[0m';
      case GlkStyle.emphasized:
        return '\x1B[3m'; // Italic
      case GlkStyle.preformatted:
        return '\x1B[0m'; // Monospace (terminal is already monospace)
      case GlkStyle.header:
        return '\x1B[1m'; // Bold
      case GlkStyle.subheader:
        return '\x1B[1m'; // Bold
      case GlkStyle.alert:
        return '\x1B[1;31m'; // Bold red
      case GlkStyle.note:
        return '\x1B[3m'; // Italic
      case GlkStyle.blockQuote:
        return '\x1B[2m'; // Dim
      case GlkStyle.input:
        return '\x1B[1m'; // Bold
      case GlkStyle.user1:
      case GlkStyle.user2:
      default:
        return '\x1B[0m';
    }
  }

  /// Read a line of input.
  Future<String> readLine() async {
    stdout.write('\x1B[?25h'); // Show cursor
    final buf = StringBuffer();

    while (true) {
      final key = _console.readKey();

      if (key.controlChar == ControlCharacter.enter) {
        stdout.write('\n');
        break;
      } else if (key.controlChar == ControlCharacter.backspace) {
        if (buf.length > 0) {
          final str = buf.toString();
          buf.clear();
          buf.write(str.substring(0, str.length - 1));
          stdout.write('\b \b');
        }
      } else if (key.controlChar == ControlCharacter.ctrlC) {
        exitFullScreen();
        exit(0);
      } else if (key.char.isNotEmpty &&
          key.controlChar == ControlCharacter.none) {
        buf.write(key.char);
        stdout.write(key.char);
      }
    }

    stdout.write('\x1B[?25l'); // Hide cursor
    return buf.toString();
  }

  /// Read a single character.
  Future<String> readChar() async {
    stdout.write('\x1B[?25h'); // Show cursor
    final key = _console.readKey();
    stdout.write('\x1B[?25l'); // Hide cursor

    if (key.controlChar == ControlCharacter.ctrlC) {
      exitFullScreen();
      exit(0);
    }

    return key.char.isNotEmpty ? key.char : '';
  }
}
