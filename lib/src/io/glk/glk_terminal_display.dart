import 'dart:async';

import 'package:zart/src/io/glk/glk_screen_model.dart';
import 'package:zart/src/io/render/screen_compositor.dart';
import 'package:zart/src/cli/cli_renderer.dart';
import 'package:zart/src/cli/cli_configuration_manager.dart' show configManager;
import 'package:zart/src/io/z_machine/z_screen_model.dart';
import 'package:zart/src/io/z_machine/zart_terminal.dart' show ZartTerminal;

/// Terminal display for Glk/Glulx games.
///
/// Uses the unified [CliRenderer] for actual rendering,
/// providing the Glk-specific model-to-frame conversion.
class GlkTerminalDisplay implements ZartTerminal {
  final CliRenderer renderer;

  /// Optional UI model used for standalone UI screens (like settings).
  ZScreenModel? _uiModel;

  /// Hook for opening settings.
  @override
  Future<void> Function()? get onOpenSettings => renderer.onOpenSettings;
  @override
  set onOpenSettings(Future<void> Function()? value) => renderer.onOpenSettings = value;

  @override
  bool get enableStatusBar => renderer.zartBarVisible;
  @override
  set enableStatusBar(bool value) => renderer.zartBarVisible = value;

  /// Screen dimensions (delegates to renderer).
  int get cols => renderer.screenWidth;
  int get rows => renderer.screenHeight;

  /// Whether zart bar is visible.
  bool get zartBarVisible => renderer.zartBarVisible;
  set zartBarVisible(bool value) => renderer.zartBarVisible = value;

  /// Create with a new renderer.
  GlkTerminalDisplay() : renderer = CliRenderer();

  /// Create with an existing renderer (for shared display).
  GlkTerminalDisplay.withRenderer(this.renderer);

  /// Enter full-screen mode.
  void enterFullScreen() => renderer.enterFullScreen();

  /// Exit full-screen mode.
  void exitFullScreen() => renderer.exitFullScreen();

  /// Screen compositor for converting RenderFrames to ScreenFrames.
  final ScreenCompositor _compositor = ScreenCompositor();

  /// Render the entire screen from the GlkScreenModel.
  void renderGlk(GlkScreenModel model) {
    final frame = model.toRenderFrame();
    final screenFrame = _compositor.composite(
      frame,
      screenWidth: renderer.screenWidth,
      screenHeight: renderer.screenHeight,
    );
    renderer.renderScreen(screenFrame);
  }

  /// Show a temporary status message.
  @override
  void showTempMessage(String message, {int seconds = 3}) => renderer.showTempMessage(message, seconds: seconds);

  /// Read a line of input.
  @override
  Future<String> readLine() => renderer.readLine();

  /// Read a single character.
  @override
  Future<String> readChar() => renderer.readChar();

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
        screenWidth: renderer.screenWidth,
        screenHeight: renderer.screenHeight,
      );
      renderer.renderScreen(screenFrame, saveFrame: false);
    } else {
      // Synchronize settings from config only when back in game mode
      renderer.zartBarVisible = configManager.zartBarVisible;
      renderer.zartBarForeground = configManager.zartBarForeground;
      renderer.zartBarBackground = configManager.zartBarBackground;
      // Restore game screen
      renderer.rerender();
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
    // Current frame is already saved in renderer._lastFrame.
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
      _uiModel = ZScreenModel(cols: renderer.screenWidth, rows: renderer.screenHeight);
    }
  }
}
