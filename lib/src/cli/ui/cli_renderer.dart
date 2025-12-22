import 'dart:async';
import 'dart:io';

import 'package:dart_console/dart_console.dart';
import 'package:zart/src/cli/config/configuration_manager.dart';
import 'package:zart/src/io/render/render_cell.dart';
import 'package:zart/src/io/render/render_frame.dart';
import 'package:zart/src/io/render/capability_provider.dart';

const _zartBarText =
    "(Zart) F1=Settings, F2=QuickSave, F3=QuickLoad, F4=Text Color, PgUp/PgDn=Scroll";

/// Unified CLI renderer for both Z-machine and Glulx games.
///
/// Renders a [RenderFrame] to the terminal using ANSI escape codes.
/// Implements [CapabilityProvider] so VMs can query terminal capabilities.
class CliRenderer with TerminalCapabilities {
  final Console _console = Console();

  /// Optional debug log callback.
  void Function(String)? onDebugLog;

  /// Callbacks for F-keys.
  Future<void> Function()? onOpenSettings;
  void Function()? onQuickSave;
  void Function()? onQuickLoad;
  void Function()? onCycleTextColor;

  /// Screen dimensions.
  int _cols = 80;
  int _rows = 24;

  @override
  int get screenWidth => _cols;

  @override
  int get screenHeight => _zartBarVisible ? _rows - 1 : _rows;

  /// Whether to show the zart bar at the bottom.
  bool _zartBarVisible = true;
  bool get zartBarVisible => _zartBarVisible;
  set zartBarVisible(bool value) => _zartBarVisible = value;

  /// Zart bar foreground color (Z-machine color code).
  int zartBarForeground = 9; // White

  /// Zart bar background color (Z-machine color code).
  int zartBarBackground = 10; // Dark Grey

  /// Temporary status message.
  String? _tempMessage;
  DateTime? _tempMessageExpiry;

  /// Scroll offset for buffer windows (0 = at bottom).
  int scrollOffset = 0;

  /// Last rendered frame (for re-rendering during scroll).
  RenderFrame? _lastFrame;

  /// The configuration manager.
  ConfigurationManager? config;

  /// Cursor position for input (row, col in screen coords).
  int _cursorRow = 0;
  int _cursorCol = 0;

  CliRenderer() {
    _detectTerminalSize();
  }

  void _detectTerminalSize() {
    try {
      _cols = _console.windowWidth;
      _rows = _console.windowHeight;
    } catch (_) {
      _cols = 80;
      _rows = 24;
    }
    if (_cols <= 0) _cols = 80;
    if (_rows <= 0) _rows = 24;
  }

  /// Enter full-screen mode using alternate screen buffer.
  void enterFullScreen() {
    stdout.write('\x1B[?1049h'); // Alternate screen buffer
    stdout.write('\x1B[?25l'); // Hide cursor
    stdout.write('\x1B[2J'); // Clear screen
    _console.rawMode = true;
  }

  /// Exit full-screen mode and restore normal terminal.
  void exitFullScreen() {
    stdout.write('\x1B[?25h'); // Show cursor
    stdout.write('\x1B[?1049l'); // Exit alternate screen buffer
    _console.rawMode = false;
  }

  /// Show a temporary status message in the zart bar.
  void showTempMessage(String message, {int seconds = 3}) {
    _tempMessage = message;
    _tempMessageExpiry = DateTime.now().add(Duration(seconds: seconds));
  }

  /// Render a frame to the terminal.
  void render(RenderFrame frame, {bool saveFrame = true}) {
    if (saveFrame) _lastFrame = frame; // Store for re-rendering on scroll
    _detectTerminalSize();

    _cursorRow = -1;
    _cursorCol = -1;

    final buf = StringBuffer();
    buf.write('\x1B[?25l'); // Hide cursor during render
    buf.write('\x1B[H'); // Home position

    // Create screen buffer
    final screen = List.generate(
      screenHeight,
      (_) => List.generate(_cols, (_) => RenderCell.empty),
    );

    // Composite windows to screen buffer
    for (final window in frame.windows) {
      _compositeWindow(screen, window, frame.focusedWindowId == window.id);
    }

    // Render screen buffer to terminal
    for (var row = 0; row < screenHeight; row++) {
      buf.write(_renderRow(screen[row], row));
      if (row < screenHeight - 1) buf.write('\n');
    }

    buf.write('\x1B[0m'); // Reset styles

    // Draw zart bar
    if (_zartBarVisible) {
      _drawZartBar(buf);
    }

    // Position cursor
    if (_cursorRow >= 0 && _cursorCol >= 0) {
      buf.write('\x1B[${_cursorRow + 1};${_cursorCol + 1}H');
      buf.write('\x1B[?25h'); // Show cursor
    }

    stdout.write(buf.toString());
  }

  /// Re-render last frame (for scroll updates).
  void rerender() {
    if (_lastFrame != null) {
      render(_lastFrame!);
    }
  }

  void _compositeWindow(
    List<List<RenderCell>> screen,
    RenderWindow window,
    bool isFocused,
  ) {
    // Determine which rows of content to show (for buffer windows with scroll)
    int contentStartRow = 0;
    if (window.cells.length > window.height) {
      // Scrollable content
      final maxScroll = window.cells.length - window.height;
      final effectiveOffset = scrollOffset.clamp(0, maxScroll);
      contentStartRow = maxScroll - effectiveOffset;
    }

    for (var row = 0; row < window.height; row++) {
      final screenRow = window.y + row;
      if (screenRow >= screenHeight) break;

      final contentRow = contentStartRow + row;
      if (contentRow >= 0 && contentRow < window.cells.length) {
        for (
          var col = 0;
          col < window.width && col < window.cells[contentRow].length;
          col++
        ) {
          final screenCol = window.x + col;
          if (screenCol >= _cols) break;
          screen[screenRow][screenCol] = window.cells[contentRow][col];
        }
      }
    }

    // Track cursor position for focused window
    if (isFocused && window.acceptsInput) {
      final cursorContentRow = window.cursorY;
      final relativeRow = cursorContentRow - contentStartRow;
      if (relativeRow >= 0 && relativeRow < window.height) {
        _cursorRow = window.y + relativeRow;
        _cursorCol = window.x + window.cursorX;
        if (_cursorCol >= window.x + window.width) {
          _cursorCol = window.x + window.width - 1;
        }
      }
    }

    // DEBUG: Log window info
    onDebugLog?.call(
      'Window ${window.id}: isTextBuffer=${window.isTextBuffer}, cells=${window.cells.length}, height=${window.height}, width=${window.width}',
    );

    // Draw scrollbar for text buffer windows with scrollable content
    if (window.isTextBuffer &&
        window.cells.length > window.height &&
        window.width > 1) {
      final totalLines = window.cells.length;
      final visibleHeight = window.height;
      final maxScroll = totalLines - visibleHeight;
      final effectiveOffset = scrollOffset.clamp(0, maxScroll);

      // Proportion-based thumb height (at least 1 cell)
      final thumbHeight = ((visibleHeight / totalLines) * visibleHeight)
          .round()
          .clamp(1, visibleHeight);

      // Positioning: scrollOffset=0 is bottom, scrollOffset=maxScroll is top
      final scrollRatio = maxScroll > 0 ? effectiveOffset / maxScroll : 0.0;
      final thumbTop = ((1.0 - scrollRatio) * (visibleHeight - thumbHeight))
          .round();

      final scrollBarCol = window.x + window.width - 1;
      for (var row = 0; row < visibleHeight; row++) {
        final screenRow = window.y + row;
        if (screenRow >= screenHeight) break;
        if (scrollBarCol >= _cols) break;

        // Draw scrollbar: thumb is bright, track is dim
        final isThumb = row >= thumbTop && row < (thumbTop + thumbHeight);
        screen[screenRow][scrollBarCol] = RenderCell(
          isThumb ? '█' : '│',
          fgColor: isThumb ? 0xFFFFFF : 0x444444, // White thumb, grey track
          bgColor: 0x000000,
        );
      }
    }
  }

  String _renderRow(List<RenderCell> cells, int rowIndex) {
    final buf = StringBuffer();
    buf.write('\x1B[${rowIndex + 1};1H'); // Position cursor
    buf.write('\x1B[K'); // Clear line

    int? lastFg;
    int? lastBg;
    bool lastBold = false;
    bool lastItalic = false;
    bool lastReverse = false;

    for (final cell in cells) {
      // Check if style changed
      if (cell.fgColor != lastFg ||
          cell.bgColor != lastBg ||
          cell.bold != lastBold ||
          cell.italic != lastItalic ||
          cell.reverse != lastReverse) {
        buf.write('\x1B[0m'); // Reset

        // Apply foreground color
        if (cell.fgColor != null) {
          buf.write(_rgbToFgAnsi(cell.fgColor!));
        }

        // Apply background color
        if (cell.bgColor != null) {
          buf.write(_rgbToBgAnsi(cell.bgColor!));
        }

        // Apply styles
        if (cell.bold) buf.write('\x1B[1m');
        if (cell.italic) buf.write('\x1B[3m');
        if (cell.reverse) buf.write('\x1B[7m');

        lastFg = cell.fgColor;
        lastBg = cell.bgColor;
        lastBold = cell.bold;
        lastItalic = cell.italic;
        lastReverse = cell.reverse;
      }

      buf.write(cell.char);
    }

    buf.write('\x1B[0m'); // Reset at end of row
    return buf.toString();
  }

  /// Convert RGB color to ANSI 24-bit foreground escape code.
  String _rgbToFgAnsi(int rgb) {
    final r = (rgb >> 16) & 0xFF;
    final g = (rgb >> 8) & 0xFF;
    final b = rgb & 0xFF;
    return '\x1B[38;2;$r;$g;${b}m';
  }

  /// Convert RGB color to ANSI 24-bit background escape code.
  String _rgbToBgAnsi(int rgb) {
    final r = (rgb >> 16) & 0xFF;
    final g = (rgb >> 8) & 0xFF;
    final b = rgb & 0xFF;
    return '\x1B[48;2;$r;$g;${b}m';
  }

  void _drawZartBar(StringBuffer buf) {
    // Check for expired temp message
    if (_tempMessage != null &&
        _tempMessageExpiry != null &&
        DateTime.now().isAfter(_tempMessageExpiry!)) {
      _tempMessage = null;
    }

    final text = _tempMessage ?? _zartBarText;
    final paddedText = text.padRight(_cols);
    final finalText = paddedText.length > _cols
        ? paddedText.substring(0, _cols)
        : paddedText;

    final barRow = _rows; // Last row (1-indexed)
    buf.write('\x1B[$barRow;1H');
    buf.write(_zColorToFgAnsi(zartBarForeground));
    buf.write(_zColorToBgAnsi(zartBarBackground));
    buf.write(finalText);
    buf.write('\x1B[0m');
  }

  /// Convert Z-machine color code (1-12) to ANSI foreground.
  String _zColorToFgAnsi(int zColor) {
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
        return '\x1B[90m'; // Dark Grey
      default:
        return '';
    }
  }

  /// Convert Z-machine color code (1-12) to ANSI background.
  String _zColorToBgAnsi(int zColor) {
    switch (zColor) {
      case 1:
        return '\x1B[49m'; // Default
      case 2:
        return '\x1B[49m'; // Black (use default)
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
        return '\x1B[100m'; // Dark Grey
      default:
        return '';
    }
  }

  /// Read a line of input from the terminal.
  Future<String> readLine() async {
    stdout.write('\x1B[?25h'); // Show cursor
    final buf = StringBuffer();

    while (true) {
      final key = _console.readKey();

      // Handle regular keys
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
      } else if (key.controlChar == ControlCharacter.F1) {
        if (onOpenSettings != null) {
          await onOpenSettings!();
          rerender();
        }
      } else if (key.controlChar == ControlCharacter.F2) {
        onQuickSave?.call();
      } else if (key.controlChar == ControlCharacter.F3) {
        onQuickLoad?.call();
      } else if (key.controlChar == ControlCharacter.F4) {
        if (onCycleTextColor != null) {
          onCycleTextColor!();
          rerender();
        }
      } else if (key.controlChar == ControlCharacter.pageUp) {
        // Scroll up (back in history)
        scrollOffset += 5;
        rerender();
      } else if (key.controlChar == ControlCharacter.pageDown) {
        // Scroll down (toward current)
        scrollOffset -= 5;
        if (scrollOffset < 0) scrollOffset = 0;
        rerender();
      } else if (key.controlChar.toString().contains('.ctrl') &&
          key.controlChar != ControlCharacter.ctrlC) {
        // Handle Ctrl+Key Macros
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
              buf.write(cmd);
              stdout.write('$cmd\n');
              return buf.toString();
            }
          }
        }
      } else if (key.char.isNotEmpty &&
          key.controlChar == ControlCharacter.none) {
        buf.write(key.char);
        stdout.write(key.char);
      }
    }

    stdout.write('\x1B[?25l'); // Hide cursor
    return buf.toString();
  }

  /// Read a single character from the terminal.
  Future<String> readChar() async {
    stdout.write('\x1B[?25h'); // Show cursor
    final key = _console.readKey();
    stdout.write('\x1B[?25l'); // Hide cursor

    if (key.controlChar == ControlCharacter.ctrlC) {
      exitFullScreen();
      exit(0);
    }

    // Map control characters to their expected values
    if (key.controlChar == ControlCharacter.enter) return '\n';
    if (key.controlChar == ControlCharacter.backspace) return '\x7F';
    if (key.controlChar == ControlCharacter.arrowUp) return '\x81';
    if (key.controlChar == ControlCharacter.arrowDown) return '\x82';
    if (key.controlChar == ControlCharacter.arrowLeft) return '\x83';
    if (key.controlChar == ControlCharacter.arrowRight) return '\x84';

    return key.char.isNotEmpty ? key.char : '';
  }

  /// Check if a function key was pressed and return its number (1-12), or null.
  int? checkFunctionKey(Key key) {
    switch (key.controlChar) {
      case ControlCharacter.F1:
        return 1;
      case ControlCharacter.F2:
        return 2;
      case ControlCharacter.F3:
        return 3;
      case ControlCharacter.F4:
        return 4;
      default:
        return null;
    }
  }

  /// Read a raw key from the terminal.
  Key readKey() => _console.readKey();
}
