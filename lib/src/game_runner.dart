import 'dart:typed_data';

import 'package:zart/src/glulx/glulx_interpreter.dart';
import 'package:zart/src/io/glk/glk_terminal_display.dart'
    show GlkTerminalDisplay;
import 'package:zart/src/io/glk/glulx_terminal_provider.dart'
    show GlulxTerminalProvider;
import 'package:zart/src/io/z_machine/z_machine_io_dispatcher.dart';
import 'package:zart/src/io/z_machine/z_terminal_display.dart'
    show ZTerminalDisplay;
import 'package:zart/src/loaders/blorb.dart';
import 'package:zart/src/io/platform/title_screen.dart';
import 'package:zart/src/z_machine/z_machine.dart';
import 'package:zart/zart.dart';

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

    // Show title screen before starting the game
    provider.onInit(fileType);

    await _showTitleScreen();

    // Each game type manages its own setup and full-screen mode
    switch (fileType) {
      case GameFileType.glulx:
        await _runGlulx(gameData);
      case GameFileType.z:
        await _runZMachine(gameData);
    }
  }

  Future<void> _showTitleScreen() async {
    final caps = provider.capabilities;
    provider.enterDisplayMode();

    await ZartTitleScreen.show(
      width: caps.screenWidth,
      height: caps.screenHeight,
      renderCallback: provider.render,
      asyncKeyWait: provider.setupAsyncKeyWait(),
    );
    provider.exitDisplayMode();
  }

  Future<void> _runGlulx(Uint8List gameData) async {
    // Create Glk display without renderer - callbacks will be wired
    final glkDisplay = GlkTerminalDisplay();

    // Set screen dimensions from platform capabilities
    final caps = provider.capabilities;
    glkDisplay.cols = caps.screenWidth;
    glkDisplay.rows = caps.screenHeight;
    glkDisplay.platformProvider = provider;

    // Wire up screen rendering callback
    glkDisplay.onScreenReady = (frame) => provider.render(frame);

    // Wire up temp message callback (if platform supports it)
    glkDisplay.onShowTempMessage = (message, {int seconds = 3}) {
      provider.showTempMessage(message, seconds: seconds);
    };

    // Wire up scroll callback
    provider.setScrollCallback((delta) => glkDisplay.scroll(delta));

    final glulxProvider = GlulxTerminalProvider(display: glkDisplay);
    glulxProvider.setPlatformProvider(provider);

    // Wire up settings callback
    glkDisplay.onOpenSettings = () async {
      await provider.openSettings(glkDisplay, isGameStarted: true);
    };

    // Wire up quicksave/quickload callbacks to set flags on the platform provider
    glkDisplay.onQuickSave = () => provider.setQuickSaveFlag();
    glkDisplay.onQuickLoad = () => provider.setQuickRestoreFlag();

    // Create the interpreter with the Glk provider
    _glulx = GlulxInterpreter(glulxProvider);

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

      // Final render and exit message using Glk provider methods
      glulxProvider.renderScreen();
      debugger.flushLogs(); // Ensure final logs are flushed
      await glulxProvider.showExitAndWait('[Zart: Press any key to exit.]');

      provider.onQuit();
      provider.exitDisplayMode();
    } catch (e) {
      debugger.flushLogs(); // Flush logs on error
      provider.exitDisplayMode();
      rethrow;
    }
  }

  Future<void> _runZMachine(Uint8List gameData) async {
    // Create ZTerminalDisplay - callbacks will be wired
    final zDisplay = ZTerminalDisplay();
    zDisplay.platformProvider = provider;

    provider.enterDisplayMode();

    // Wire up screen rendering callback
    zDisplay.onScreenReady = (frame) => provider.render(frame);

    // Wire up temp message callback
    zDisplay.onShowTempMessage = (message, {int seconds = 3}) {
      provider.showTempMessage(message, seconds: seconds);
    };

    // Wire up scroll callback
    provider.setScrollCallback((delta) => zDisplay.scroll(delta));

    // IMPORTANT: Set Z.io BEFORE Z.load() so visitHeader() can read platform capabilities
    final dispatcher = ZMachineIoDispatcher(zDisplay, provider);
    Z.io = dispatcher;

    // Now load the game - this calls visitHeader() which needs Z.io to be set
    Z.load(gameData);

    zDisplay.detectTerminalSize();
    zDisplay.applySavedSettings();

    zDisplay.onOpenSettings = () =>
        provider.openSettings(zDisplay, isGameStarted: true);

    // Wire up quicksave/quickload callbacks to set flags on the platform provider
    zDisplay.onQuickSave = () => provider.setQuickSaveFlag();
    zDisplay.onQuickLoad = () => provider.setQuickRestoreFlag();

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

    zDisplay.appendToWindow0('\n[Zart: Press any key to exit.]');
    zDisplay.render();
    await zDisplay.readChar();

    provider.onQuit();
    provider.exitDisplayMode();
  }

  /// Dispose of resources used by the runner.
  void dispose() {
    _glulx = null;
    provider.dispose();
  }
}
