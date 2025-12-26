import 'dart:async';
import 'dart:io';

import 'package:dart_console/dart_console.dart';
import 'package:zart/src/io/glk/glk_screen_model.dart';
import 'package:zart/src/io/render/screen_compositor.dart';
import 'package:zart/src/io/render/screen_frame.dart';
import 'package:zart/src/cli/cli_configuration_manager.dart' show cliConfigManager;
import 'package:zart/src/io/z_machine/z_screen_model.dart';
import 'package:zart/src/io/z_machine/zart_terminal.dart' show ZartTerminal;
import 'package:zart/src/io/z_machine/z_terminal_colors.dart';

/// Terminal display for Glk/Glulx games.
///
/// Uses `ScreenCompositor` to produce `ScreenFrame` objects that are
/// sent to the platform layer via the `onScreenReady` callback.
/// Handles input directly with scroll support (matches Z-machine pattern).
class GlkTerminalDisplay implements ZartTerminal {
  /// Console for direct keyboard input.
  final Console _console = Console();

  /// Callback when a screen frame is ready to be rendered.
  void Function(ScreenFrame frame)? onScreenReady;

  /// Callback to enter full-screen mode.
  void Function()? onEnterFullScreen;

  /// Callback to exit full-screen mode.
  void Function()? onExitFullScreen;

  /// Callback to show a temporary message.
  void Function(String message, {int seconds})? onShowTempMessage;

  /// Optional UI model used for standalone UI screens (like settings).
  ZScreenModel? _uiModel;

  /// Hook for opening settings.
  @override
  Future<void> Function()? onOpenSettings;

  /// Hook for quick save trigger (F2 key).
  void Function()? onQuickSave;

  /// Hook for quick load trigger (F3 key).
  void Function()? onQuickLoad;

  /// Whether the zart bar (status bar) is visible.
  bool _zartBarVisible = true;

  @override
  bool get enableStatusBar => _zartBarVisible;
  @override
  set enableStatusBar(bool value) => _zartBarVisible = value;

  /// Screen dimensions - must be set by the platform layer.
  int _cols = 80;
  int _rows = 24;

  /// Screen width in columns.
  int get cols => _cols;
  set cols(int value) => _cols = value;

  /// Screen height in rows (adjusted for zart bar).
  int get rows => _zartBarVisible ? _rows - 1 : _rows;

  /// Set the raw terminal rows (before adjustment for zart bar).
  set rows(int value) => _rows = value;

  /// Whether zart bar is visible.
  bool get zartBarVisible => _zartBarVisible;
  set zartBarVisible(bool value) => _zartBarVisible = value;

  /// Scroll offset for text buffer windows (0 = at bottom).
  int _scrollOffset = 0;

  /// Input queue for injected commands (e.g. from F2/F3 quick save/restore).
  final List<String> _inputQueue = [];

  /// Push text into the input queue to be returned by readLine.
  void pushInput(String text) {
    _inputQueue.add(text);
  }

  String _popQueueLine() {
    if (_inputQueue.isEmpty) return '';
    final input = _inputQueue.removeAt(0);
    return input.endsWith('\n') ? input.substring(0, input.length - 1) : input;
  }

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

  /// Create with default dimensions.
  GlkTerminalDisplay() {
    // Initialize color preference
    final savedColor = cliConfigManager.textColor;
    _currentTextColorIndex = _customTextColors.indexOf(savedColor);
    if (_currentTextColorIndex == -1) _currentTextColorIndex = 0;
  }

  void _cycleTextColor() {
    _currentTextColorIndex = (_currentTextColorIndex + 1) % _customTextColors.length;
    final newColor = _customTextColors[_currentTextColorIndex];
    _lastModel?.forceTextColor(newColor);

    // Save preference
    cliConfigManager.textColor = newColor;
  }

  /// Enter full-screen mode.
  void enterFullScreen() => onEnterFullScreen?.call();

  /// Exit full-screen mode.
  void exitFullScreen() => onExitFullScreen?.call();

  /// Screen compositor for converting RenderFrames to ScreenFrames.
  final ScreenCompositor _compositor = ScreenCompositor();

  /// Last GlkScreenModel for re-rendering during scroll.
  GlkScreenModel? _lastModel;

  /// Get the current scroll offset.
  int get scrollOffset => _compositor.scrollOffset;

  /// Set the scroll offset for the compositor.
  void setScrollOffset(int offset) {
    _compositor.setScrollOffset(offset);
  }

  /// Re-render the last model with the current scroll offset.
  void rerenderWithScroll() {
    if (_lastModel != null) {
      renderGlk(_lastModel!);
    }
  }

  /// Render the entire screen from the GlkScreenModel.
  void renderGlk(GlkScreenModel model) {
    _lastModel = model; // Store for scroll re-rendering
    // Sync scroll offset with compositor
    _compositor.setScrollOffset(_scrollOffset);
    final frame = model.toRenderFrame();
    final screenFrame = _compositor.composite(frame, screenWidth: _cols, screenHeight: rows);
    // Update scroll offset from compositor (in case it was clamped)
    _scrollOffset = _compositor.scrollOffset;
    onScreenReady?.call(screenFrame);
  }

  /// Show a temporary status message.
  @override
  void showTempMessage(String message, {int seconds = 3}) => onShowTempMessage?.call(message, seconds: seconds);

  /// Process global keys (F1-F3, PgUp/PgDn, etc). Returns true if key was consumed.
  Future<bool> _handleGlobalKeys(Key key) async {
    if (key.controlChar == ControlCharacter.F1) {
      if (onOpenSettings != null) {
        await onOpenSettings!();
        rerenderWithScroll(); // Re-render after returning
      }
      return true;
    } else if (key.controlChar == ControlCharacter.F2) {
      // Quick save - set flag then inject "save" command
      onQuickSave?.call();
      pushInput('save\n');
      return true;
    } else if (key.controlChar == ControlCharacter.F3) {
      // Quick restore - set flag then inject "restore" command
      onQuickLoad?.call();
      pushInput('restore\n');
      return true;
    } else if (key.controlChar == ControlCharacter.F4) {
      _cycleTextColor();
      rerenderWithScroll();
      return true;
    } else if (key.controlChar == ControlCharacter.pageUp) {
      // Scroll up (back in history)
      _scrollOffset += 5;
      rerenderWithScroll();
      return true;
    } else if (key.controlChar == ControlCharacter.pageDown) {
      // Scroll down (toward current)
      _scrollOffset -= 5;
      if (_scrollOffset < 0) _scrollOffset = 0;
      rerenderWithScroll();
      return true;
    }
    return false;
  }

  /// Read a line of input.
  /// Handles input directly using Console with scroll support (matches Z-machine pattern).
  @override
  Future<String> readLine() async {
    // Check if there's injected input first
    if (_inputQueue.isNotEmpty) {
      final line = _popQueueLine();
      stdout.write('$line\n'); // Echo the injected input
      return line;
    }

    // Disable mouse tracking
    stdout.write('\x1b[?1000l\x1b[?1002l\x1b[?1003l\x1b[?1006l');
    stdout.write('\x1B[?25h'); // Show cursor

    final buf = StringBuffer();
    // Reset scroll when starting new input
    _scrollOffset = 0;

    while (true) {
      final key = _console.readKey();

      // Handle global keys (F1-F3, PgUp/PgDn)
      if (await _handleGlobalKeys(key)) {
        // If F2/F3 was pressed, input was injected - return it
        if (_inputQueue.isNotEmpty) {
          final line = _popQueueLine();
          stdout.write('$line\n'); // Echo the injected input
          stdout.write('\x1B[?25l'); // Hide cursor
          return line;
        }
        continue;
      }

      // Handle regular keys
      if (key.controlChar == ControlCharacter.enter) {
        stdout.write('\n');
        stdout.write('\x1B[?25l'); // Hide cursor
        return buf.toString();
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
      } else if (key.char.isNotEmpty && key.controlChar == ControlCharacter.none) {
        buf.write(key.char);
        stdout.write(key.char);
      }
    }
  }

  /// Read a single character.
  /// Handles input directly using Console with scroll support.
  @override
  Future<String> readChar() async {
    stdout.write('\x1B[?25h'); // Show cursor

    while (true) {
      final key = _console.readKey();

      // Handle global keys (F1, PgUp/PgDn)
      if (await _handleGlobalKeys(key)) {
        continue;
      }

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

      if (key.char.isNotEmpty) {
        return key.char;
      }
    }
  }

  // Legacy callbacks - no longer used, kept for API compatibility
  Future<String> Function()? onReadLine;
  Future<String> Function()? onReadChar;

  @override
  void appendToWindow0(String text) {
    _ensureUiModel();
    _uiModel!.appendToWindow0(text);
  }

  @override
  void clearAll() {
    _ensureUiModel();
    _uiModel!.clearAll();
  }

  @override
  void render() {
    if (_uiModel != null) {
      final frame = _uiModel!.toRenderFrame();
      final screenFrame = _compositor.composite(frame, screenWidth: _cols, screenHeight: rows);
      onScreenReady?.call(screenFrame);
    } else {
      // Synchronize settings from config only when back in game mode
      _zartBarVisible = cliConfigManager.zartBarVisible;
      // Signal to re-render game screen - platform layer handles this
      // by re-calling renderGlk with the cached model
    }
  }

  @override
  void restoreState() {
    // Restoration is handled by the caller or by re-rendering the game screen.
    // In SettingsScreen, restoreState() is followed by render().
    // We just need to clear our UI model to indicate we are back to game mode.
    _uiModel = null;
  }

  @override
  void saveState() {
    // Current frame is already saved in the game loop.
    // We start a fresh UI model for the settings screen.
    _ensureUiModel();
    _uiModel!.clearAll();
  }

  @override
  void setColors(int fg, int bg) {
    _ensureUiModel();
    _uiModel!.setColors(fg, bg);
  }

  @override
  void splitWindow(int lines) {
    _ensureUiModel();
    _uiModel!.splitWindow(lines);
  }

  void _ensureUiModel() {
    if (_uiModel == null) {
      _uiModel = ZScreenModel(cols: _cols, rows: rows);
    }
  }
}
