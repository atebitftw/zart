import 'dart:async';
import 'dart:io';

import 'package:dart_console/dart_console.dart';
import 'package:zart/src/cli/cli_renderer.dart' show CliRenderer;
import 'package:zart/src/cli/cli_configuration_manager.dart' show configManager;
import 'package:zart/zart.dart';

/// CLI/Terminal implementation of [PlatformProvider].
///
/// Provides terminal-based rendering and input for running Z-machine and
/// Glulx games in a command-line environment.
///
/// This implementation delegates to:
/// - [CliRenderer] for rendering RenderFrames
/// - Terminal input for keyboard/mouse handling
class CliPlatformProvider extends PlatformProvider {
  final Console _console = Console();
  late final CliRenderer _renderer;

  /// Renderer for emitting [RenderFrame]s.
  CliRenderer get renderer => _renderer;
  late PlatformCapabilities _capabilities;

  /// Whether a quick action is in progress.
  bool _isQuickSave = false;
  bool _isQuickRestore = false;

  /// Create a CLI platform provider.
  CliPlatformProvider({required String gameName}) : _gameName = gameName;

  String _gameName;

  @override
  String get gameName => _gameName;

  @override
  void onInit(GameFileType fileType) {
    _renderer = CliRenderer();
    configManager.load();
    _updateCapabilities();

    _renderer.onQuickSave = () {
      _isQuickSave = true;
      stdout.write('save\n');
      _renderer.pushInput('save\n');
    };

    _renderer.onQuickLoad = () {
      _isQuickRestore = true;
      stdout.write('restore\n');
      _renderer.pushInput('restore\n');
    };
  }

  void _updateCapabilities() {
    _capabilities = PlatformCapabilities.terminal(width: _renderer.screenWidth, height: _renderer.screenHeight);
  }

  // ============================================================
  // CAPABILITIES
  // ============================================================

  @override
  PlatformCapabilities get capabilities {
    _updateCapabilities();
    return _capabilities;
  }

  // ============================================================
  // RENDERING
  // ============================================================

  @override
  void render(ScreenFrame frame) {
    _renderer.renderScreen(frame);
  }

  @override
  void enterDisplayMode() {
    _renderer.enterFullScreen();
  }

  @override
  void exitDisplayMode() {
    _renderer.exitFullScreen();
  }

  // ============================================================
  // INPUT
  // ============================================================

  @override
  Future<String> readLine({int? maxLength, int? timeout}) async {
    // TODO: Implement timeout support
    return _renderer.readLine();
  }

  @override
  Future<InputEvent> readInput({int? timeout}) async {
    stdout.write('\x1B[?25h'); // Show cursor
    final key = _console.readKey();
    stdout.write('\x1B[?25l'); // Hide cursor

    // Handle control characters
    if (key.controlChar == ControlCharacter.ctrlC) {
      exitDisplayMode();
      exit(0);
    }

    // Map control characters to input events
    switch (key.controlChar) {
      case ControlCharacter.enter:
        return const InputEvent.character('\n', keyCode: SpecialKeys.enter);
      case ControlCharacter.backspace:
        return const InputEvent.character('\x7F', keyCode: SpecialKeys.delete);
      case ControlCharacter.arrowUp:
        return const InputEvent.specialKey(SpecialKeys.arrowUp);
      case ControlCharacter.arrowDown:
        return const InputEvent.specialKey(SpecialKeys.arrowDown);
      case ControlCharacter.arrowLeft:
        return const InputEvent.specialKey(SpecialKeys.arrowLeft);
      case ControlCharacter.arrowRight:
        return const InputEvent.specialKey(SpecialKeys.arrowRight);
      case ControlCharacter.F1:
        return const InputEvent.specialKey(SpecialKeys.f1);
      case ControlCharacter.F2:
        return const InputEvent.specialKey(SpecialKeys.f2);
      case ControlCharacter.F3:
        return const InputEvent.specialKey(SpecialKeys.f3);
      case ControlCharacter.F4:
        return const InputEvent.specialKey(SpecialKeys.f4);
      case ControlCharacter.escape:
        return const InputEvent.specialKey(SpecialKeys.escape);
      default:
        if (key.char.isNotEmpty) {
          return InputEvent.character(key.char);
        }
        return const InputEvent.none();
    }
  }

  @override
  InputEvent? pollInput() {
    // Terminal doesn't support non-blocking input easily
    return null;
  }

  // ============================================================
  // FILE IO
  // ============================================================

  @override
  Future<String?> saveGame(List<int> data, {String? suggestedName}) async {
    String filename;
    if (_isQuickSave) {
      _isQuickSave = false;
      // Extract basename and remove extension
      String base = gameName.split(RegExp(r'[/\\]')).last;
      if (base.contains('.')) {
        base = base.substring(0, base.lastIndexOf('.'));
      }
      filename = 'quick_save_$base.sav';
    } else {
      // Manual/Interactive save
      stdout.write('\nEnter filename to save: ');
      filename = await readLine();
    }

    if (filename.isEmpty) return null;

    if (!filename.toLowerCase().endsWith('.sav')) {
      filename += '.sav';
    }

    try {
      final f = File(filename);
      f.writeAsBytesSync(data);
      return filename;
    } catch (e) {
      onError('Save failed: $e');
      return null;
    }
  }

  @override
  Future<List<int>?> restoreGame({String? suggestedName}) async {
    String filename;
    if (_isQuickRestore) {
      _isQuickRestore = false;
      // Extract basename and remove extension
      String base = gameName.split(RegExp(r'[/\\]')).last;
      if (base.contains('.')) {
        base = base.substring(0, base.lastIndexOf('.'));
      }
      filename = 'quick_save_$base.sav';
    } else {
      // Manual/Interactive restore
      stdout.write('\nEnter filename to restore: ');
      filename = await readLine();
    }

    if (filename.isEmpty) return null;

    if (!filename.toLowerCase().endsWith('.sav')) {
      filename += '.sav';
    }

    try {
      final f = File(filename);
      if (!f.existsSync()) {
        onError('File not found: "$filename"');
        return null;
      }
      return f.readAsBytesSync();
    } catch (e) {
      onError('Restore failed: $e');
      return null;
    }
  }

  @override
  Future<String?> quickSave(List<int> data) async {
    String base = gameName.split(RegExp(r'[/\\]')).last;
    if (base.contains('.')) {
      base = base.substring(0, base.lastIndexOf('.'));
    }
    String filename = 'quick_save_$base.sav';

    try {
      final f = File(filename);
      f.writeAsBytesSync(data);
      _renderer.showTempMessage('Game saved to $filename');
      return filename;
    } catch (e) {
      onError('QuickSave failed: $e');
      return null;
    }
  }

  @override
  Future<List<int>?> quickRestore() async {
    String base = gameName.split(RegExp(r'[/\\]')).last;
    if (base.contains('.')) {
      base = base.substring(0, base.lastIndexOf('.'));
    }
    String filename = 'quick_save_$base.sav';

    try {
      final f = File(filename);
      if (!f.existsSync()) {
        _renderer.showTempMessage('QuickSave File Not Found ($filename)', seconds: 3);
        return null;
      }

      final data = f.readAsBytesSync();
      _renderer.showTempMessage('Game restored from $filename', seconds: 3);
      return data;
    } catch (e) {
      onError('QuickRestore failed: $e');
      return null;
    }
  }

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void onQuit() {
    // Nothing special to do
  }

  @override
  void onError(String message) {
    stderr.writeln('Error: $message');
  }

  @override
  void dispose() {
    // Nothing special to clean up
  }
}
