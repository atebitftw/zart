import 'dart:io';
import 'dart:typed_data';

import 'package:zart/src/cli/config/configuration_manager.dart';
import 'package:zart/src/cli/ui/cli_renderer.dart';
import 'package:zart/src/cli/ui/glk_terminal_display.dart';
import 'package:zart/src/cli/ui/glulx_terminal_provider.dart';
import 'package:zart/src/cli/ui/settings_screen.dart';
import 'package:zart/src/cli/ui/z_terminal_display.dart';
import 'package:zart/src/cli/ui/z_machine_io_dispatcher.dart';
import 'package:zart/src/glulx/glulx_debugger.dart' show debugger;
import 'package:zart/src/glulx/glulx_interpreter.dart';
import 'package:zart/zart.dart';

/// Unified game runner for both Z-machine and Glulx games.
///
/// Takes a single [CliRenderer] - the same display works for both game types.
///
/// Example:
/// ```dart
/// final renderer = CliRenderer();
/// final runner = GameRunner(renderer);
/// await runner.run(gameBytes, filename: 'game.z5');
/// ```
class GameRunner {
  final CliRenderer renderer;
  final ConfigurationManager? config;
  final Map<String, dynamic> debugConfig;

  // Internal state
  GlulxInterpreter? _glulx;
  GlulxTerminalProvider? _glulxProvider;
  ZTerminalDisplay? _zDisplay;
  ZMachineIoDispatcher? _zProvider;

  /// Create a GameRunner with a renderer.
  GameRunner(this.renderer, {this.config, this.debugConfig = const {}});

  /// Run a game from raw bytes.
  ///
  /// Detects game type, initializes the correct interpreter, and runs
  /// the event loop until the game quits.
  Future<void> run(Uint8List bytes, {String filename = 'game'}) async {
    final (gameData, fileType) = Blorb.getStoryFileData(bytes);

    if (fileType == null) {
      throw GameRunnerException('Invalid or unsupported file type');
    }

    if (gameData == null) {
      throw GameRunnerException('Unable to extract game data from file');
    }

    // Each game type manages its own full-screen mode
    switch (fileType) {
      case GameFileType.glulx:
        await _runGlulx(gameData);
      case GameFileType.z:
        await _runZMachine(gameData, filename);
    }
  }

  Future<void> _runGlulx(Uint8List gameData) async {
    // Create Glk display
    final display = GlkTerminalDisplay();
    _glulxProvider = GlulxTerminalProvider(display: display, config: config);
    _glulx = GlulxInterpreter(_glulxProvider!);

    debugger.enabled = debugConfig['debug'] ?? false;
    debugger.startStep = debugConfig['startstep'];
    debugger.endStep = debugConfig['endstep'];
    debugger.showHeader = debugConfig['showheader'] ?? false;
    debugger.showBytes = debugConfig['showbytes'] ?? false;
    debugger.showModes = debugConfig['showmodes'] ?? false;
    debugger.showInstructions = debugConfig['showinstructions'] ?? false;
    debugger.showPCAdvancement = debugConfig['showpc'] ?? false;
    debugger.showFlightRecorder = debugConfig['flight-recorder'] ?? false;
    debugger.flightRecorderSize = debugConfig['flight-recorder-size'] ?? 100;
    debugger.showScreen = debugConfig['show-screen'] ?? false;
    debugger.logFilter = debugConfig['logfilter'];
    debugger.dumpDebugSettings();

    _glulx!.load(gameData);

    display.enterFullScreen();

    try {
      final maxStep = debugConfig['maxstep'] ?? -1;
      await _glulx!.run(maxStep: maxStep);
      _glulxProvider!.renderScreen();

      await _glulxProvider!.showExitAndWait('[Zart: Press any key to exit]');
      display.exitFullScreen();
    } catch (e) {
      display.exitFullScreen();
      rethrow;
    }
  }

  Future<void> _runZMachine(Uint8List gameData, String filename) async {
    var isGameRunning = false;
    // Create Z-machine display (uses its own terminal handling)
    _zDisplay = ZTerminalDisplay();

    if (config != null) {
      _zDisplay!.config = config;
      _zDisplay!.applySavedSettings();
    }

    _zDisplay!.onOpenSettings = () =>
        SettingsScreen(_zDisplay!, config ?? ConfigurationManager()).show(isGameStarted: isGameRunning);

    Debugger.enableDebug = false;
    Debugger.enableVerbose = false;
    Debugger.enableTrace = false;
    Debugger.enableStackTrace = false;

    _zProvider = ZMachineIoDispatcher(_zDisplay!, filename);
    Z.io = _zProvider as ZIoDispatcher;

    _zDisplay!.onAutosave = () => _zProvider!.isQuickSaveMode = true;
    _zDisplay!.onRestore = () => _zProvider!.isAutorestoreMode = true;

    Z.load(gameData);

    ProcessSignal.sigint.watch().listen((_) {
      _zDisplay?.exitFullScreen();
      stdout.writeln('Interrupted.');
      exit(0);
    });

    // Enter full-screen with Z-machine's mouse support
    _zDisplay!.enterFullScreen();
    isGameRunning = true;
    _zDisplay!.enableStatusBar = true;

    final commandQueue = <String>[];
    var state = await Z.runUntilInput();

    while (state != ZMachineRunState.quit) {
      switch (state) {
        case ZMachineRunState.needsLineInput:
          if (commandQueue.isEmpty) {
            _zDisplay!.render();
            final line = await _zDisplay!.readLine();
            _zDisplay!.appendToWindow0('\n');
            final commands = line.split('.').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
            if (commands.isEmpty) {
              state = await Z.submitLineInput('');
            } else {
              commandQueue.addAll(commands);
              state = await Z.submitLineInput(commandQueue.removeAt(0));
            }
          } else {
            final cmd = commandQueue.removeAt(0);
            _zDisplay!.appendInputEcho('$cmd\n');
            state = await Z.submitLineInput(cmd);
          }
        case ZMachineRunState.needsCharInput:
          _zDisplay!.render();
          final char = await _zDisplay!.readChar();
          if (char.isNotEmpty) {
            state = await Z.submitCharInput(char);
          }
        case ZMachineRunState.quit:
        case ZMachineRunState.error:
        case ZMachineRunState.running:
          break;
      }
    }

    _zDisplay!.appendToWindow0('\n[Press any key to exit]');
    _zDisplay!.render();
    await _zDisplay!.readChar();

    // Cleanup Z-machine display (restores terminal state)
    _zDisplay!.exitFullScreen();
  }

  void dispose() {
    _glulx = null;
    _glulxProvider = null;
    _zDisplay = null;
    _zProvider = null;
  }
}

class GameRunnerException implements Exception {
  final String message;
  GameRunnerException(this.message);

  @override
  String toString() => 'GameRunnerException: $message';
}
