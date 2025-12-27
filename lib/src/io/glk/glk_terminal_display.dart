import 'dart:async';

import 'package:zart/src/io/glk/glk_screen_model.dart';
import 'package:zart/src/io/render/screen_compositor.dart';
import 'package:zart/src/io/render/screen_frame.dart';
import 'package:zart/src/io/z_machine/z_screen_model.dart';
import 'package:zart/src/io/z_machine/zart_terminal.dart' show ZartTerminal;
import 'package:zart/src/io/z_machine/z_terminal_colors.dart';
import 'package:zart/src/io/platform/platform_provider.dart';
import 'package:zart/src/io/platform/input_event.dart';

/// Terminal display for Glk/Glulx games.
///
/// Uses `ScreenCompositor` to produce `ScreenFrame` objects that are
/// sent to the platform layer via the `onScreenReady` callback.
/// Handles input directly with scroll support (matches Z-machine pattern).
class GlkTerminalDisplay implements ZartTerminal {
  @override
  PlatformProvider? platformProvider;

  /// Reference to the Glk provider for setting quick save/restore flags
  dynamic glkProvider;

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

  /// Whether the zart bar (status bar) is enabled for this display.
  bool _enableStatusBar = true;

  @override
  bool get enableStatusBar => _enableStatusBar;
  @override
  set enableStatusBar(bool value) => _enableStatusBar = value;

  /// Screen dimensions - must be set by the platform layer.
  int _cols = 80;
  int _rows = 24;

  /// Screen width in columns.
  int get cols => _cols;
  set cols(int value) => _cols = value;

  /// Screen height in rows (adjusted for zart bar).
  int get rows {
    final zartBarVisible = platformProvider?.capabilities.zartBarVisible ?? true;
    return (_enableStatusBar && zartBarVisible) ? _rows - 1 : _rows;
  }

  /// Set the raw terminal rows (before adjustment for zart bar).
  set rows(int value) => _rows = value;

  /// Whether zart bar is visible (alias for enableStatusBar).
  bool get zartBarVisible => _enableStatusBar;
  set zartBarVisible(bool value) => _enableStatusBar = value;

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
  GlkTerminalDisplay();

  /// Apply settings from platform capabilities (e.g. initial color)
  void applySavedSettings() {
    final savedColor = platformProvider?.capabilities.textColor ?? 1;
    _currentTextColorIndex = _customTextColors.indexOf(savedColor);
    if (_currentTextColorIndex == -1) _currentTextColorIndex = 0;
    _lastModel?.forceTextColor(savedColor);
  }

  void _cycleTextColor() {
    _currentTextColorIndex = (_currentTextColorIndex + 1) % _customTextColors.length;
    final newColor = _customTextColors[_currentTextColorIndex];
    _lastModel?.forceTextColor(newColor);

    // Notify platform of preference change
    platformProvider?.setTextColor(newColor);
  }

  /// Enter full-screen mode.
  void enterFullScreen() => onEnterFullScreen?.call();

  /// Exit full-screen mode.
  void exitFullScreen() => onExitFullScreen?.call();

  /// Screen compositor for converting RenderFrames to ScreenFrames.
  final ScreenCompositor _compositor = ScreenCompositor();

  /// Last GlkScreenModel for re-rendering during scroll.
  GlkScreenModel? _lastModel;

  /// Detect terminal size and update stored dimensions.
  void detectTerminalSize() {
    if (platformProvider != null) {
      _cols = platformProvider!.capabilities.screenWidth;
      _rows = platformProvider!.capabilities.screenHeight;
    }

    if (_cols <= 0) _cols = 80;
    if (_rows <= 0) _rows = 24;
  }

  /// Re-render the last model with the current scroll offset.
  void rerenderWithScroll() {
    if (_lastModel != null) {
      renderGlk(_lastModel!);
    }
  }

  /// Render the entire screen from the GlkScreenModel.
  void renderGlk(GlkScreenModel model) {
    detectTerminalSize();
    model.setScreenSize(_cols, rows);
    _lastModel = model; // Store for scroll re-rendering
    // Sync scroll offset with compositor
    _compositor.setScrollOffset(_scrollOffset);
    final frame = model.toRenderFrame();
    final zartBarVisible = platformProvider?.capabilities.zartBarVisible ?? true;
    final screenFrame = _compositor.composite(
      frame,
      screenWidth: _cols,
      screenHeight: rows,
      hideStatusBar: !_enableStatusBar || !zartBarVisible,
    );
    // Update scroll offset from compositor (in case it was clamped)
    _scrollOffset = _compositor.scrollOffset;
    onScreenReady?.call(screenFrame);
  }

  /// Scroll by the specified delta.
  /// Positive values scroll up (back in history), negative values scroll down.
  void scroll(int delta) {
    _scrollOffset += delta;
    if (_scrollOffset < 0) _scrollOffset = 0;
    // Note: totalMaxScroll clamping happens in the compositor during render
    rerenderWithScroll();
  }

  /// Show a temporary status message.
  @override
  void showTempMessage(String message, {int seconds = 3}) => onShowTempMessage?.call(message, seconds: seconds);

  /// Process global keys (F1, PgUp/PgDn, etc). Returns true if key was consumed.
  Future<bool> _handleGlobalKeys(InputEvent event) async {
    if (event.type != InputEventType.character) return false;

    if (event.keyCode == SpecialKeys.f1) {
      if (onOpenSettings != null) {
        await onOpenSettings!();
        rerenderWithScroll(); // Re-render after returning
      }
      return true;
    } else if (event.keyCode == SpecialKeys.f2) {
      // Quick save - set flag on provider then inject "save" command
      if (glkProvider != null) {
        (glkProvider as dynamic).setQuickSaveFlag();
      }
      onQuickSave?.call();
      pushInput('save\n');
      return true;
    } else if (event.keyCode == SpecialKeys.f3) {
      // Quick restore - set flag on provider then inject "restore" command
      if (glkProvider != null) {
        (glkProvider as dynamic).setQuickRestoreFlag();
      }
      onQuickLoad?.call();
      pushInput('restore\n');
      return true;
    } else if (event.keyCode == SpecialKeys.f4) {
      _cycleTextColor();
      rerenderWithScroll();
      return true;
    }
    return false;
  }

  /// Read a line of input.
  /// Handles input directly using Console with scroll support (matches Z-machine pattern).
  @override
  Future<String> readLine({int? windowId}) async {
    // Check if there's injected input first
    if (_inputQueue.isNotEmpty) {
      final line = _popQueueLine();
      return line;
    }

    final buf = StringBuffer();
    // Reset scroll when starting new input
    _scrollOffset = 0;

    while (true) {
      InputEvent event;
      if (platformProvider != null) {
        event = await platformProvider!.readInput();
        if (event.type == InputEventType.none) continue;
      } else {
        throw StateError('GlkTerminalDisplay requires a platformProvider for input.');
      }

      // Handle global keys (F1, PgUp/PgDn)
      if (await _handleGlobalKeys(event)) {
        // If save/restore was injected, return the injected input
        if (_inputQueue.isNotEmpty) {
          final line = _popQueueLine();
          return line;
        }
        continue;
      }

      // Handle Macro Commands (simplified)
      if (event.type == InputEventType.macro && event.macroCommand != null) {
        final cmd = event.macroCommand!;
        return cmd;
      }

      // Handle regular keys
      if (event.keyCode == SpecialKeys.enter) {
        _scrollOffset = 0;
        final result = buf.toString();
        buf.clear();
        if (windowId != null && _lastModel != null) {
          _lastModel!.setLineInput(windowId, '');
        }
        return result;
      } else if (event.keyCode == SpecialKeys.delete) {
        if (buf.length > 0) {
          final str = buf.toString();
          buf.clear();
          buf.write(str.substring(0, str.length - 1));
        }
      } else if (event.character != null && event.character!.isNotEmpty) {
        if (_scrollOffset > 0) {
          _scrollOffset = 0;
          rerenderWithScroll();
        }
        buf.write(event.character!);
      }

      // Echo partial input to screen if windowId is provided
      if (windowId != null && _lastModel != null) {
        _lastModel!.setLineInput(windowId, buf.toString());
        renderGlk(_lastModel!);
      }
    }
  }

  /// Read a single character.
  /// Handles input directly using Console with scroll support.
  @override
  Future<String> readChar() async {
    while (true) {
      InputEvent event;
      if (platformProvider != null) {
        event = await platformProvider!.readInput();
        if (event.type == InputEventType.none) continue;
      } else {
        throw StateError('GlkTerminalDisplay requires a platformProvider for input.');
      }

      if (await _handleGlobalKeys(event)) continue;

      if (event.keyCode == SpecialKeys.enter) return '\n';
      if (event.keyCode == SpecialKeys.delete) return '\x7F';
      if (event.keyCode == SpecialKeys.arrowUp) return '\x81';
      if (event.keyCode == SpecialKeys.arrowDown) return '\x82';
      if (event.keyCode == SpecialKeys.arrowLeft) return '\x83';
      if (event.keyCode == SpecialKeys.arrowRight) return '\x84';

      if (event.character != null && event.character!.isNotEmpty) {
        _scrollOffset = 0;
        return event.character!;
      }
    }
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
      final zartBarVisible = platformProvider?.capabilities.zartBarVisible ?? true;
      final screenFrame = _compositor.composite(
        frame,
        screenWidth: _cols,
        screenHeight: rows,
        hideStatusBar: !_enableStatusBar || !zartBarVisible,
      );
      onScreenReady?.call(screenFrame);
    } else {
      rerenderWithScroll();
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
