import 'dart:async';
import 'dart:io';

import 'package:dart_console/dart_console.dart';
import 'package:zart/src/cli/config/configuration_manager.dart';
import 'package:zart/src/cli/ui/cli_renderer.dart';
import 'package:zart/src/cli/ui/glk_terminal_display.dart';
import 'package:zart/src/cli/ui/glulx_terminal_provider.dart';
import 'package:zart/src/cli/ui/settings_screen.dart';
import 'package:zart/src/cli/ui/z_machine_io_dispatcher.dart';
import 'package:zart/src/cli/ui/z_terminal_display.dart';
import 'package:zart/src/io/platform/input_event.dart';
import 'package:zart/src/io/platform/platform_capabilities.dart';
import 'package:zart/src/io/platform/platform_provider.dart';
import 'package:zart/src/io/platform/z_machine_io_command.dart';
import 'package:zart/src/io/render/render_frame.dart';

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
class CliPlatformProvider implements PlatformProvider {
  final Console _console = Console();
  late final CliRenderer _renderer;
  late PlatformCapabilities _capabilities;

  /// Configuration manager for settings.
  final ConfigurationManager? config;

  /// Game filename (for save/restore operations).
  String gameName = 'game';

  // === Glulx/Glk Support ===
  GlulxTerminalProvider? _glulxProvider;
  GlkTerminalDisplay? _glkDisplay;

  // === Z-machine Support ===
  ZTerminalDisplay? _zDisplay;
  ZMachineIoDispatcher? _zDispatcher;

  /// Create a CLI platform provider.
  CliPlatformProvider({this.config}) {
    _renderer = CliRenderer();
    _renderer.config = config;
    _updateCapabilities();
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
  void render(RenderFrame frame) {
    _renderer.render(frame);
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
    // Manual/Interactive save
    stdout.write('\nEnter filename to save: ');
    var filename = await readLine();

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
    // Manual/Interactive restore
    stdout.write('\nEnter filename to restore: ');
    var filename = await readLine();

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
  void initGlulx() {
    _glkDisplay = GlkTerminalDisplay();
    _glulxProvider = GlulxTerminalProvider(display: _glkDisplay, config: config);

    // Wire up settings callback
    _glkDisplay!.onOpenSettings = () async {
      await SettingsScreen(_glkDisplay!, config ?? ConfigurationManager()).show(isGameStarted: true);
    };
  }

  @override
  FutureOr<int> glkDispatch(int selector, List<int> args) {
    if (_glulxProvider == null) {
      throw StateError('Glulx not initialized. Call initGlulx() first.');
    }
    return _glulxProvider!.glkDispatch(selector, args);
  }

  @override
  void setGlkMemoryAccess({
    required void Function(int addr, int value, {int size}) write,
    required int Function(int addr, {int size}) read,
  }) {
    _glulxProvider?.setMemoryAccess(write: write, read: read);
  }

  @override
  void setGlkStackAccess({required void Function(int value) push, required int Function() pop}) {
    _glulxProvider?.setStackAccess(push: push, pop: pop);
  }

  @override
  void setGlkVMState({int Function()? getHeapStart}) {
    _glulxProvider?.setVMState(getHeapStart: getHeapStart);
  }

  @override
  int vmGestalt(int selector, int arg) {
    return _glulxProvider?.vmGestalt(selector, arg) ?? 0;
  }

  /// Get the Glulx provider for direct access (e.g., for rendering).
  GlulxTerminalProvider? get glulxProvider => _glulxProvider;

  /// Get the Glk display for direct access.
  GlkTerminalDisplay? get glkDisplay => _glkDisplay;

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
  // Z-MACHINE SUPPORT
  // ============================================================

  /// Initialize Z-machine support.
  /// Called by GameRunner when starting a Z-machine game.
  void initZMachine() {
    _zDisplay = ZTerminalDisplay();
    if (config != null) {
      _zDisplay!.config = config;
      _zDisplay!.applySavedSettings();
    }

    _zDisplay!.onOpenSettings = () =>
        SettingsScreen(_zDisplay!, config ?? ConfigurationManager()).show(isGameStarted: true);

    _zDispatcher = ZMachineIoDispatcher(_zDisplay!, this);
  }

  @override
  int getZMachineFlags1() => _zDispatcher?.getFlags1() ?? capabilities.getZMachineFlags1();

  @override
  Future<dynamic> zCommand(ZMachineIOCommand command) async {
    if (_zDispatcher == null) {
      throw StateError('Z-machine not initialized. Call initZMachine() first.');
    }

    // Convert typed command to legacy command map
    final commandMessage = _commandToMap(command);
    return _zDispatcher!.command(commandMessage);
  }

  Map<String, dynamic> _commandToMap(ZMachineIOCommand command) {
    // This converts the new typed commands to the old map format
    // for backward compatibility with ZMachineIoDispatcher
    switch (command) {
      case PrintCommand():
        return {'command': ZIoCommands.print, 'window': command.window, 'buffer': command.text};
      case SplitWindowCommand():
        return {'command': ZIoCommands.splitWindow, 'lines': command.lines};
      case SetWindowCommand():
        return {'command': ZIoCommands.setWindow, 'window': command.window};
      case ClearScreenCommand():
        return {'command': ZIoCommands.clearScreen, 'window_id': command.windowId};
      case SetCursorCommand():
        return {'command': ZIoCommands.setCursor, 'line': command.row, 'column': command.column};
      case GetCursorCommand():
        return {'command': ZIoCommands.getCursor};
      case SetTextStyleCommand():
        return {'command': ZIoCommands.setTextStyle, 'style': command.style};
      case SetColourCommand():
        return {'command': ZIoCommands.setColour, 'foreground': command.foreground, 'background': command.background};
      case SetTrueColourCommand():
        return {
          'command': ZIoCommands.setTrueColour,
          'foreground': command.foreground,
          'background': command.background,
        };
      case EraseLineCommand():
        return {'command': ZIoCommands.eraseLine};
      case SetFontCommand():
        return {'command': ZIoCommands.setFont, 'font': command.font};
      case SaveCommand():
        return {'command': ZIoCommands.save, 'file_data': command.fileData};
      case RestoreCommand():
        return {'command': ZIoCommands.restore};
      case StatusCommand():
        return {
          'command': ZIoCommands.status,
          'room_name': command.roomName,
          'score_one': command.scoreOne,
          'score_two': command.scoreTwo,
          'game_type': command.gameType,
        };
      case SoundEffectCommand():
        return {
          'command': ZIoCommands.soundEffect,
          'sound': command.sound,
          'effect': command.effect,
          'volume': command.volume,
        };
      case InputStreamCommand():
        return {'command': ZIoCommands.inputStream, 'stream': command.stream};
      case QuitCommand():
        return {'command': ZIoCommands.quit};
      case PrintDebugCommand():
        return {'command': ZIoCommands.printDebug, 'message': command.message};
      case AsyncCommand():
        return {'command': ZIoCommands.async, 'operation': command.operation};
    }
  }

  /// Get the Z-machine display for direct access.
  ZTerminalDisplay? get zDisplay => _zDisplay;

  /// Get the Z-machine dispatcher for direct access.
  ZMachineIoDispatcher? get zDispatcher => _zDispatcher;

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
    _zDisplay = null;
    _zDispatcher = null;
  }
}

/// Z-machine IO command enum for backward compatibility.
/// These map to the old string-based command system.
enum ZIoCommands {
  print,
  status,
  clearScreen,
  splitWindow,
  setWindow,
  setFont,
  save,
  restore,
  read,
  readChar,
  quit,
  printDebug,
  async,
  setCursor,
  setTextStyle,
  setColour,
  eraseLine,
  getCursor,
  inputStream,
  soundEffect,
  setTrueColour,
}
