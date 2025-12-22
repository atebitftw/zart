import 'dart:io';
import 'dart:typed_data';

import 'package:zart/src/cli/ui/cli_platform_provider.dart';
import 'package:zart/src/glulx/glulx_debugger.dart' show debugger;
import 'package:zart/src/glulx/glulx_interpreter.dart';
import 'package:zart/src/io/platform/platform_provider.dart';
import 'package:zart/src/loaders/blorb.dart';
import 'package:zart/src/z_machine/z_machine.dart';
import 'package:zart/src/z_machine/debugger.dart';
import 'package:zart/src/io/z_io_dispatcher.dart';

/// Unified game runner for both Z-machine and Glulx games.
///
/// Takes a [PlatformProvider] implementation to handle all platform-specific
/// IO operations (rendering, input, save/restore).
///
/// Example:
/// ```dart
/// final provider = CliPlatformProvider();
/// final runner = GameRunner(provider);
/// await runner.run(gameBytes, filename: 'game.z5');
/// ```
class GameRunner {
  /// The platform provider for IO operations.
  final PlatformProvider provider;

  /// Debug configuration options.
  final Map<String, dynamic> debugConfig;

  // Internal state
  GlulxInterpreter? _glulx;

  /// Create a GameRunner with a platform provider.
  GameRunner(this.provider, {this.debugConfig = const {}});

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

    // Set the game name for save/restore operations
    if (provider is CliPlatformProvider) {
      (provider as CliPlatformProvider).gameName = filename;
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
    // Initialize Glulx support in the provider
    if (provider is CliPlatformProvider) {
      (provider as CliPlatformProvider).initGlulx();
    }

    // Create the interpreter with the platform provider
    _glulx = GlulxInterpreter(provider);

    // Configure debugger from debug config
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

    provider.enterDisplayMode();

    try {
      final maxStep = debugConfig['maxstep'] ?? -1;
      await _glulx!.run(maxStep: maxStep);

      // Final render and exit message
      if (provider is CliPlatformProvider) {
        final cliProvider = provider as CliPlatformProvider;
        cliProvider.glulxProvider?.renderScreen();
        await cliProvider.glulxProvider?.showExitAndWait(
          '[Zart: Press any key to exit]',
        );
      }

      provider.exitDisplayMode();
    } catch (e) {
      provider.exitDisplayMode();
      rethrow;
    }
  }

  Future<void> _runZMachine(Uint8List gameData, String filename) async {
    // Initialize Z-machine support in the provider
    if (provider is CliPlatformProvider) {
      (provider as CliPlatformProvider).initZMachine();
    }

    // Disable Z-machine debugger
    Debugger.enableDebug = false;
    Debugger.enableVerbose = false;
    Debugger.enableTrace = false;
    Debugger.enableStackTrace = false;

    // Set up Z-machine IO dispatcher
    if (provider is CliPlatformProvider) {
      final cliProvider = provider as CliPlatformProvider;
      Z.io = cliProvider.zDispatcher as ZIoDispatcher;
    }

    Z.load(gameData);

    // Handle Ctrl+C
    ProcessSignal.sigint.watch().listen((_) {
      provider.exitDisplayMode();
      stdout.writeln('Interrupted.');
      exit(0);
    });

    provider.enterDisplayMode();

    // Access Z-machine specific display functionality
    if (provider is CliPlatformProvider) {
      final cliProvider = provider as CliPlatformProvider;
      final zDisplay = cliProvider.zDisplay;
      if (zDisplay != null) {
        zDisplay.enableStatusBar = true;

        final commandQueue = <String>[];
        var state = await Z.runUntilInput();

        while (state != ZMachineRunState.quit) {
          switch (state) {
            case ZMachineRunState.needsLineInput:
              if (commandQueue.isEmpty) {
                zDisplay.render();
                final line = await zDisplay.readLine();
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
    }

    provider.exitDisplayMode();
  }

  void dispose() {
    _glulx = null;
    provider.dispose();
  }
}

class GameRunnerException implements Exception {
  final String message;
  GameRunnerException(this.message);

  @override
  String toString() => 'GameRunnerException: $message';
}
