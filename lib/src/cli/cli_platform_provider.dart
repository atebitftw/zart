import 'dart:async';
import 'dart:io';

import 'package:dart_console/dart_console.dart';
import 'package:zart/src/io/glk/glk_terminal_display.dart';
import 'package:zart/src/io/glk/glulx_terminal_provider.dart' show GlulxTerminalProvider;
import 'package:zart/src/cli/cli_renderer.dart' show CliRenderer;
import 'package:zart/src/cli/cli_configuration_manager.dart' show configManager;
import 'package:zart/src/cli/cli_settings_screen.dart';
import 'package:zart/zart.dart';

/// CLI/Terminal implementation of [PlatformProvider].
///
/// Provides terminal-based rendering and input for running Z-machine and
/// Glulx games in a command-line environment.
///
/// This implementation delegates to:
/// - [CliRenderer] for rendering RenderFrames
/// - [GlulxTerminalProvider] for Glk dispatch
/// - [ZMachineIoDispatcher] for Z-machine commands
/// - Terminal input for keyboard/mouse handling
class CliPlatformProvider extends PlatformProvider {
  final Console _console = Console();
  late final CliRenderer _renderer;

  /// Renderer for emitting [RenderFrame]s.
  CliRenderer get renderer => _renderer;
  late PlatformCapabilities _capabilities;

  // === Glulx/Glk Support ===
  GlulxTerminalProvider? _glulxProvider;
  GlkTerminalDisplay? _glkDisplay;

  /// Whether a quick action is in progress.
  bool _isQuickSave = false;
  bool _isQuickRestore = false;

  /// Create a CLI platform provider.
  CliPlatformProvider({required String gameName}) : _gameName = gameName {
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

  String _gameName;

  @override
  String get gameName => _gameName;

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

  @override
  void init(GameFileType fileType) {
    switch (fileType) {
      case GameFileType.glulx:
        _initGlulx();
      default:
        break;
    }
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
  // GLULX / GLK SUPPORT
  // ============================================================

  /// Initialize Glulx/Glk support.
  /// Called by GameRunner when starting a Glulx game.
  void _initGlulx() {
    // Share the renderer with GlkTerminalDisplay to ensure unified rendering path
    _glkDisplay = GlkTerminalDisplay.withRenderer(_renderer);
    _glulxProvider = GlulxTerminalProvider(display: _glkDisplay);

    // Wire up settings callback
    _glkDisplay!.onOpenSettings = () async {
      await CliSettingsScreen(_glkDisplay!).show(isGameStarted: true);
    };
  }

  @override
  FutureOr<int> dispatch(int selector, List<int> args) {
    if (_glulxProvider == null) {
      throw StateError('Glulx not initialized. Call initGlulx() first.');
    }
    return _glulxProvider!.dispatch(selector, args);
  }

  @override
  int vmGestalt(int selector, int arg) {
    if (_glulxProvider != null) {
      return _glulxProvider!.vmGestalt(selector, arg);
    }
    // Fallback implementation for unit tests that don't initialize Glulx
    return _defaultVmGestalt(selector, arg);
  }

  /// Default Glulx gestalt values.
  /// Used when _glulxProvider is not initialized (e.g., in unit tests).
  int _defaultVmGestalt(int selector, int arg) {
    // Reference: packages/glulxe/gestalt.c
    switch (selector) {
      case 0: // GlulxVersion
        return 0x00030103; // Glulx spec 3.1.3
      case 1: // TerpVersion
        return 0x00000100; // Zart 0.1.0
      case 2: // ResizeMem
        return 1;
      case 3: // Undo
        return 1;
      case 4: // IOSystem
        return (arg >= 0 && arg <= 2) ? 1 : 0;
      case 5: // Unicode
        return 1;
      case 6: // MemCopy
        return 1;
      case 7: // MAlloc
        return 1;
      case 11: // Float
        return 1;
      case 12: // ExtUndo
        return 1;
      case 13: // Double
        return 1;
      default:
        return 0;
    }
  }

  /// Get the Glulx provider for direct access (e.g., for rendering).
  GlulxTerminalProvider? get glulxProvider => _glulxProvider;

  /// Get the Glk display for direct access.
  GlkTerminalDisplay? get glkDisplay => _glkDisplay;

  @override
  void renderScreen() {
    _glulxProvider?.renderScreen();
  }

  @override
  Future<void> showExitAndWait(String message) async {
    await _glulxProvider?.showExitAndWait(message);
  }

  // ============================================================
  // GLKIOPROVIDER INTERFACE IMPLEMENTATION
  // ============================================================

  // These methods are required by GlkIoProvider interface.
  // They delegate to _glulxProvider when Glulx is initialized.

  @override
  void writeMemory(int addr, int value, {int size = 1}) {
    _glulxProvider?.writeMemory(addr, value, size: size);
  }

  @override
  int readMemory(int addr, {int size = 1}) {
    return _glulxProvider?.readMemory(addr, size: size) ?? 0;
  }

  @override
  void setMemoryAccess({
    required void Function(int addr, int value, {int size}) write,
    required int Function(int addr, {int size}) read,
  }) {
    _glulxProvider?.setMemoryAccess(write: write, read: read);
  }

  @override
  void setVMState({int Function()? getHeapStart}) {
    _glulxProvider?.setVMState(getHeapStart: getHeapStart);
  }

  @override
  void pushToStack(int value) {
    _glulxProvider?.pushToStack(value);
  }

  @override
  int popFromStack() {
    return _glulxProvider?.popFromStack() ?? 0;
  }

  @override
  void setStackAccess({required void Function(int value) push, required int Function() pop}) {
    _glulxProvider?.setStackAccess(push: push, pop: pop);
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
    _glulxProvider = null;
    _glkDisplay = null;
  }
}
