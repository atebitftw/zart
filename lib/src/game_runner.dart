import 'dart:io';
import 'dart:typed_data';

import 'package:zart/src/game_runner_exception.dart';
import 'package:zart/src/glulx/glulx_debugger.dart' show debugger;
import 'package:zart/src/glulx/glulx_interpreter.dart';
import 'package:zart/src/io/platform/platform_provider.dart';
import 'package:zart/src/loaders/blorb.dart';
import 'package:zart/src/z_machine/z_machine.dart';

/// Unified game runner for both Z-machine and Glulx games.
///
/// Takes a [PlatformProvider] implementation to handle all platform-specific
/// IO operations (rendering, input, save/restore).
///
/// Example:
/// ```dart
/// final provider = CliPlatformProvider(config, gameName: 'game.z5');
/// final runner = GameRunner(provider);
/// await runner.run(gameBytes);
/// ```
class GameRunner {
  /// The platform provider for IO operations.
  final PlatformProvider provider;

  /// Debug configuration options.
  final _debugConfig = const <String, dynamic>{
    'debug': false,
    'startstep': null,
    'endstep': null,
    'showheader': false,
    'showbytes': false,
    'showmodes': false,
    'showinstructions': false,
    'showpc': false,
    'flight-recorder': false,
    'flight-recorder-size': 100,
    'show-screen': false,
    'logfilter': null,
    'maxstep': -1,
  };

  // Internal state
  GlulxInterpreter? _glulx;

  /// Create a GameRunner with a platform provider.
  GameRunner(this.provider);

  /// Run a game from raw bytes.
  ///
  /// Detects game type, initializes the correct interpreter, and runs
  /// the event loop until the game quits.
  Future<void> run(Uint8List bytes) async {
    final (gameData, fileType) = Blorb.getStoryFileData(bytes);

    if (fileType == null) {
      throw GameRunnerException('Invalid or unsupported file type');
    }

    if (gameData == null) {
      throw GameRunnerException('Unable to extract game data from file');
    }

    // Initialize the provider for the detected game type
    provider.init(fileType);

    // Each game type manages its own full-screen mode
    switch (fileType) {
      case GameFileType.glulx:
        await _runGlulx(gameData);
      case GameFileType.z:
        await _runZMachine(gameData);
    }
  }

  Future<void> _runGlulx(Uint8List gameData) async {
    // Create the interpreter with the platform provider
    _glulx = GlulxInterpreter(provider);

    // Configure debugger from debug config
    debugger.enabled = _debugConfig['debug'] ?? false;
    debugger.startStep = _debugConfig['startstep'];
    debugger.endStep = _debugConfig['endstep'];
    debugger.showHeader = _debugConfig['showheader'] ?? false;
    debugger.showBytes = _debugConfig['showbytes'] ?? false;
    debugger.showModes = _debugConfig['showmodes'] ?? false;
    debugger.showInstructions = _debugConfig['showinstructions'] ?? false;
    debugger.showPCAdvancement = _debugConfig['showpc'] ?? false;
    debugger.showFlightRecorder = _debugConfig['flight-recorder'] ?? false;
    debugger.flightRecorderSize = _debugConfig['flight-recorder-size'] ?? 100;
    debugger.showScreen = _debugConfig['show-screen'] ?? false;
    debugger.logFilter = _debugConfig['logfilter'];
    debugger.dumpDebugSettings();

    _glulx!.load(gameData);

    provider.enterDisplayMode();

    try {
      final maxStep = _debugConfig['maxstep'] ?? -1;
      await _glulx!.run(maxStep: maxStep);

      // Final render and exit message using abstract provider methods
      provider.renderScreen();
      await provider.showExitAndWait('[Zart: Press any key to exit]');

      provider.exitDisplayMode();
    } catch (e) {
      provider.exitDisplayMode();
      rethrow;
    }
  }

  Future<void> _runZMachine(Uint8List gameData) async {
    // Set up Z-machine IO dispatcher from the provider
    final dispatcher = provider.zDispatcher;
    if (dispatcher != null) {
      Z.io = dispatcher;
    }

    Z.load(gameData);

    // Handle Ctrl+C
    ProcessSignal.sigint.watch().listen((_) {
      provider.exitDisplayMode();
      stdout.writeln('Interrupted.');
      exit(0);
    });

    provider.enterDisplayMode();

    // Access Z-machine display through the abstract interface
    final zDisplay = provider.zDisplay;
    if (zDisplay != null) {
      zDisplay.enableStatusBar = true;
      zDisplay.detectTerminalSize();

      final commandQueue = <String>[];
      var state = await Z.runUntilInput();

      while (state != ZMachineRunState.quit) {
        switch (state) {
          case ZMachineRunState.needsLineInput:
            if (commandQueue.isEmpty) {
              zDisplay.render();
              final line = await zDisplay.readLine();
              if (line == '__RESTORED__') {
                state = await Z.runUntilInput();
                continue;
              }
              zDisplay.appendToWindow0('\n');
              final commands = line
                  .split('.')
                  .map((c) => c.trim())
                  .where((c) => c.isNotEmpty)
                  .toList();
              if (commands.isEmpty) {
                state = await Z.submitLineInput('');
              } else {
                commandQueue.addAll(commands);
                state = await Z.submitLineInput(commandQueue.removeAt(0));
              }
            } else {
              final cmd = commandQueue.removeAt(0);
              zDisplay.appendInputEcho('$cmd\n');
              state = await Z.submitLineInput(cmd);
            }
          case ZMachineRunState.needsCharInput:
            zDisplay.render();
            final char = await zDisplay.readChar();
            if (char.isNotEmpty) {
              state = await Z.submitCharInput(char);
            }
          case ZMachineRunState.quit:
          case ZMachineRunState.error:
          case ZMachineRunState.running:
            break;
        }
      }

      zDisplay.appendToWindow0('\n[Press any key to exit]');
      zDisplay.render();
      await zDisplay.readChar();
    }

    provider.exitDisplayMode();
  }

  /// Dispose of resources used by the runner.
  void dispose() {
    _glulx = null;
    provider.dispose();
  }
}
