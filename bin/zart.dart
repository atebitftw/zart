import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:zart/src/cli/ui/glulx_terminal_provider.dart';
import 'package:zart/src/cli/ui/z_machine_terminal_provider.dart';
import 'package:zart/src/logging.dart' show log;
import 'package:logging/logging.dart' show Level;
import 'package:zart/zart.dart' hide getPreamble;
import 'package:zart/src/cli/config/configuration_manager.dart';
import 'package:zart/src/cli/ui/settings_screen.dart';
import 'package:zart/src/cli/ui/terminal_display.dart';
import 'package:zart/src/glulx/glulx_interpreter.dart';

/// A full-screen terminal-based console player for Z-Machine.
/// Uses dart_console for cross-platform support.
void main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag('debug', abbr: 'd', help: 'Enable Glulx debugger', defaultsTo: false)
    ..addOption('startstep', help: 'Start step for debugger output')
    ..addOption('endstep', help: 'End step for debugger output')
    ..addFlag('showheader', help: 'Show Glulx header info', defaultsTo: false)
    ..addFlag('showbytes', help: 'Show raw bytes (requires --debug)', defaultsTo: false)
    ..addFlag('showmodes', help: 'Show addressing modes (requires --debug)', defaultsTo: false)
    ..addFlag('showinstructions', help: 'Show instructions (requires --debug)', defaultsTo: false)
    ..addFlag('showpc', help: 'Show PC advancement (requires --debug)', defaultsTo: false)
    ..addFlag('flight-recorder', help: 'Enable flight recorder (last 100 instructions)', defaultsTo: false)
    ..addOption('flight-recorder-size', help: 'Flight recorder size (requires --flight-recorder)', defaultsTo: '100')
    ..addOption('logfilter', help: 'Only log messages containing this string')
    ..addOption('maxstep', help: 'Maximum steps to run');

  ArgResults results;
  try {
    results = parser.parse(args);
  } catch (e) {
    stdout.writeln('Error parsing arguments: $e');
    stdout.writeln(parser.usage);
    exit(1);
  }

  if (results.rest.isEmpty) {
    stdout.writeln('Usage: zart <game> [options]');
    stdout.writeln(parser.usage);
    exit(1);
  }

  final filename = results.rest.first;
  final enableDebug = results['debug'] as bool;

  if (enableDebug) {
    log.level = Level.INFO;
  } else {
    log.level = Level.WARNING;
  }

  final f = File(filename);

  if (!f.existsSync()) {
    stdout.writeln('Error: Game file not found at "$filename"');
    stdout.writeln('Current Directory: ${Directory.current.path}');
    exit(1);
  }

  try {
    final config = ConfigurationManager();
    config.load();

    final bytes = f.readAsBytesSync();
    final (gameData, fileType) = Blorb.getStoryFileData(bytes);

    if (fileType == null) {
      stdout.writeln("Zart: Invalid file type.");
      exit(1);
    }

    if (gameData == null) {
      stdout.writeln('Zart: Unable to load game.');
      exit(1);
    }

    if (fileType == GameFileType.glulx) {
      stdout.writeln("Zart: Loading Glulx game...");

      // Set IoProvider before loading
      int? startStepVal;
      if (results['startstep'] != null) {
        startStepVal = int.tryParse(results['startstep']);
        if (startStepVal == null && results['startstep'].startsWith('0x')) {
          startStepVal = int.tryParse(results['startstep'].substring(2), radix: 16);
        }
      }

      int? endStepVal;
      if (results['endstep'] != null) {
        endStepVal = int.tryParse(results['endstep']);
        if (endStepVal == null && results['endstep'].startsWith('0x')) {
          endStepVal = int.tryParse(results['endstep'].substring(2), radix: 16);
        }
      }

      int? maxStepVal;
      if (results['maxstep'] != null) {
        maxStepVal = int.tryParse(results['maxstep']);
      }

      await _runGlulxGame(
        filename,
        gameData,
        config,
        enableDebug: enableDebug,
        startStep: startStepVal,
        endStep: endStepVal,
        showHeader: results['showheader'] as bool,
        showBytes: results['showbytes'] as bool,
        showModes: results['showmodes'] as bool,
        showPCAdvancement: results['showpc'] as bool,
        enableFlightRecorder: results['flight-recorder'] as bool,
        flightRecorderSize: int.tryParse(results['flight-recorder-size']) ?? 100,
        showInstructions: results['showinstructions'] as bool,
        logFilter: results['logfilter'] as String?,
        maxStep: maxStepVal,
      );
      exit(0);
    }

    if (fileType == GameFileType.z) {
      await _runZMachineGame(filename, gameData, config);
      exit(0);
    }
  } catch (fe) {
    stdout.writeln("Exception occurred while trying to load game: $fe");
    exit(1);
  }
}

Future<void> _runGlulxGame(
  String fileName,
  Uint8List gameData,
  ConfigurationManager config, {
  bool enableDebug = false,
  int? startStep,
  int? endStep,
  bool showHeader = false,
  bool showBytes = false,
  bool showModes = false,
  bool showPCAdvancement = false,
  bool enableFlightRecorder = false,
  int flightRecorderSize = 100,
  bool showInstructions = false,
  String? logFilter,
  int? maxStep,
}) async {
  final terminal = TerminalDisplay();
  terminal.config = config;
  terminal.applySavedSettings();

  final f = File("debug.log");
  f.writeAsStringSync("", mode: FileMode.write);

  log.onRecord.listen((record) {
    f.writeAsStringSync("${record.level.name}: ${record.message}\n", mode: FileMode.append);
    //terminal.appendToWindow0("${record.level.name}: ${record.message}\n");
  });

  // Create provider
  final provider = GlulxTerminalProvider(terminal);
  GlulxInterpreter? glulx;

  try {
    glulx = GlulxInterpreter(provider);

    if (enableDebug || enableFlightRecorder) {
      glulx.debugger
        ..enabled = enableDebug
        ..showHeader = showHeader
        ..showBytes = showBytes
        ..showModes = showModes
        ..showPCAdvancement = showPCAdvancement
        ..startStep = startStep
        ..endStep = endStep
        ..showInstructions = showInstructions
        ..showFlightRecorder = enableFlightRecorder
        ..flightRecorderSize = flightRecorderSize
        ..logFilter = logFilter;
    }

    glulx.debugger.dumpDebugSettings();

    glulx.load(gameData);

    // Enter full-screen mode to show the game display
    terminal.enterFullScreen();
    log.warning('Game started');
    // keeping maxSteps here for now to handle infinite loops, etc.
    await glulx.run(maxStep: -1);
    log.warning('Game ended. Tick Count: ${provider.tickCount}. Step Count: ${glulx.step}');
    // Render what we have so far
    terminal.render();

    if (glulx.debugger.showFlightRecorder) {
      glulx.debugger.dumpFlightRecorder();
    }

    // Wait for keypress before exiting
    terminal.appendToWindow0('\n[Zart: Press any key to exit]');
    terminal.render();
    await terminal.readChar();
  } catch (e, stackTrace) {
    stdout.writeln("Glulx Error: $e");
    stdout.writeln("Stack Trace:\n$stackTrace");
  } finally {
    terminal.exitFullScreen();
    glulx?.debugger.flushLogs();
  }
}

Future<void> _runZMachineGame(String fileName, Uint8List gameData, ConfigurationManager config) async {
  var isGameRunning = false;
  final terminal = TerminalDisplay();
  terminal.config = config;
  terminal.applySavedSettings();
  terminal.onOpenSettings = () => SettingsScreen(terminal, config).show(isGameStarted: isGameRunning);

  // Disable debugging for clean display
  Debugger.enableDebug = false;
  Debugger.enableVerbose = false;
  Debugger.enableTrace = false;
  Debugger.enableStackTrace = false;

  // Set IoProvider before loading
  final provider = ZMachineTerminalProvider(terminal, fileName);
  Z.io = provider as IoProvider;
  // Map autosave trigger to provider flag
  terminal.onAutosave = () {
    provider.isQuickSaveMode = true;
  };
  // Map autorestore trigger
  terminal.onRestore = () {
    provider.isAutorestoreMode = true;
  };

  Z.load(gameData);

  // Handle Ctrl+C to properly exit full-screen mode
  ProcessSignal.sigint.watch().listen((_) {
    try {
      terminal.exitFullScreen();
      stdout.writeln('Interrupted.');
      exit(0);
    } catch (e, stack) {
      terminal.exitFullScreen();
      stdout.writeln('Error: $e');
      stdout.writeln('Stack Trace: $stack');
      rethrow;
    }
  });

  try {
    // Enter full-screen mode
    terminal.enterFullScreen();

    // Jump straight into game
    isGameRunning = true;
    terminal.enableStatusBar = true; // Show status bar in game

    // Command queue for chained commands (e.g., "get up.take all.north")
    final commandQueue = <String>[];

    // Pump API: run until input needed, then get input and continue
    var state = await Z.runUntilInput();

    while (state != ZMachineRunState.quit) {
      switch (state) {
        case ZMachineRunState.needsLineInput:
          if (commandQueue.isEmpty) {
            terminal.render();
            final line = await terminal.readLine();
            terminal.appendToWindow0('\n');
            // Split by '.' to support chained commands
            final commands = line.split('.').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
            if (commands.isEmpty) {
              state = await Z.submitLineInput('');
            } else {
              commandQueue.addAll(commands);
              state = await Z.submitLineInput(commandQueue.removeAt(0));
            }
          } else {
            final cmd = commandQueue.removeAt(0);
            terminal.appendToWindow0('$cmd\n');
            state = await Z.submitLineInput(cmd);
          }
          break;
        case ZMachineRunState.needsCharInput:
          terminal.render();
          final char = await terminal.readChar();
          if (char.isNotEmpty) {
            state = await Z.submitCharInput(char);
          }
          break;
        case ZMachineRunState.quit:
        case ZMachineRunState.error:
        case ZMachineRunState.running:
          break;
      }
    }

    terminal.appendToWindow0('\n[Press any key to exit]');
    terminal.render();
    await terminal.readChar();
  } on GameException catch (e) {
    terminal.exitFullScreen();
    log.severe('A game error occurred: $e');
    exit(1);
  } catch (err, stack) {
    terminal.exitFullScreen();
    stdout.writeln('A system error occurred: $err');
    stdout.writeln('Stack Trace:\n$stack');
    exit(1);
  } finally {
    terminal.exitFullScreen();
    exit(0);
  }
}
