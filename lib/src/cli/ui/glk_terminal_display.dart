import 'dart:async';

import 'package:zart/src/cli/config/configuration_manager.dart';
import 'package:zart/src/cli/ui/cli_renderer.dart';
import 'package:zart/src/cli/ui/zart_terminal.dart';
import 'package:zart/src/io/glk/glk_screen_model.dart';
import 'package:zart/src/io/z_screen_model.dart';

/// Terminal display for Glk/Glulx games.
///
/// Uses the unified [CliRenderer] for actual rendering,
/// providing the Glk-specific model-to-frame conversion.
class GlkTerminalDisplay implements ZartTerminal {
  final CliRenderer renderer;
  CliRenderer get _renderer => renderer;

  /// Optional UI model used for standalone UI screens (like settings).
  ZScreenModel? _uiModel;

  /// The configuration manager.
  ConfigurationManager? _config;
  ConfigurationManager? get config => _config;
  set config(ConfigurationManager? value) {
    _config = value;
    renderer.config = value;
  }

  /// Hook for opening settings.
  @override
  Future<void> Function()? get onOpenSettings => _renderer.onOpenSettings;
  @override
  set onOpenSettings(Future<void> Function()? value) =>
      _renderer.onOpenSettings = value;

  @override
  bool get enableStatusBar => _renderer.zartBarVisible;
  @override
  set enableStatusBar(bool value) => _renderer.zartBarVisible = value;

  /// Screen dimensions (delegates to renderer).
  int get cols => _renderer.screenWidth;
  int get rows => _renderer.screenHeight;

  /// Whether zart bar is visible.
  bool get zartBarVisible => _renderer.zartBarVisible;
  set zartBarVisible(bool value) => _renderer.zartBarVisible = value;

  /// Create with a new renderer.
  GlkTerminalDisplay() : renderer = CliRenderer();

  /// Create with an existing renderer (for shared display).
  GlkTerminalDisplay.withRenderer(this.renderer);

  /// Enter full-screen mode.
  void enterFullScreen() => _renderer.enterFullScreen();

  /// Exit full-screen mode.
  void exitFullScreen() => _renderer.exitFullScreen();

  /// Render the entire screen from the GlkScreenModel.
  void renderGlk(GlkScreenModel model) {
    final frame = model.toRenderFrame();
    _renderer.render(frame);
  }

  /// Show a temporary status message.
  @override
  void showTempMessage(String message, {int seconds = 3}) {
    _renderer.showTempMessage(message, seconds: seconds);
  }

  /// Read a line of input.
  @override
  Future<String> readLine() => _renderer.readLine();

  /// Read a single character.
  @override
  Future<String> readChar() => _renderer.readChar();

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
      _renderer.render(_uiModel!.toRenderFrame(), saveFrame: false);
    } else {
      // Synchronize settings from config only when back in game mode
      if (config != null) {
        _renderer.zartBarVisible = config!.zartBarVisible;
        _renderer.zartBarForeground = config!.zartBarForeground;
        _renderer.zartBarBackground = config!.zartBarBackground;
      }
      // Restore game screen
      _renderer.rerender();
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
      _uiModel = ZScreenModel(
        cols: _renderer.screenWidth,
        rows: _renderer.screenHeight,
      );
    }
  }
}
