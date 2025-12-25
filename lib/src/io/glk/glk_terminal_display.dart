import 'dart:async';

import 'package:zart/src/io/glk/glk_screen_model.dart';
import 'package:zart/src/io/render/screen_compositor.dart';
import 'package:zart/src/io/render/screen_frame.dart';
import 'package:zart/src/cli/cli_configuration_manager.dart' show configManager;
import 'package:zart/src/io/z_machine/z_screen_model.dart';
import 'package:zart/src/io/z_machine/zart_terminal.dart' show ZartTerminal;

/// Terminal display for Glk/Glulx games.
///
/// Uses `ScreenCompositor` to produce `ScreenFrame` objects that are
/// sent to the platform layer via the `onScreenReady` callback.
class GlkTerminalDisplay implements ZartTerminal {
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

  /// Create with default dimensions.
  GlkTerminalDisplay();

  /// Enter full-screen mode.
  void enterFullScreen() => onEnterFullScreen?.call();

  /// Exit full-screen mode.
  void exitFullScreen() => onExitFullScreen?.call();

  /// Screen compositor for converting RenderFrames to ScreenFrames.
  final ScreenCompositor _compositor = ScreenCompositor();

  /// Render the entire screen from the GlkScreenModel.
  void renderGlk(GlkScreenModel model) {
    final frame = model.toRenderFrame();
    final screenFrame = _compositor.composite(
      frame,
      screenWidth: _cols,
      screenHeight: rows,
    );
    onScreenReady?.call(screenFrame);
  }

  /// Show a temporary status message.
  @override
  void showTempMessage(String message, {int seconds = 3}) =>
      onShowTempMessage?.call(message, seconds: seconds);

  /// Read a line of input.
  /// This must be provided by the platform layer via a callback.
  Future<String> Function()? onReadLine;

  @override
  Future<String> readLine() async {
    if (onReadLine != null) return onReadLine!();
    throw StateError('onReadLine callback not set');
  }

  /// Read a single character.
  /// This must be provided by the platform layer via a callback.
  Future<String> Function()? onReadChar;

  @override
  Future<String> readChar() async {
    if (onReadChar != null) return onReadChar!();
    throw StateError('onReadChar callback not set');
  }

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
      final screenFrame = _compositor.composite(
        frame,
        screenWidth: _cols,
        screenHeight: rows,
      );
      onScreenReady?.call(screenFrame);
    } else {
      // Synchronize settings from config only when back in game mode
      _zartBarVisible = configManager.zartBarVisible;
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
