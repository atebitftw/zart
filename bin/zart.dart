import 'dart:io';
import 'dart:typed_data';

import 'package:zart/src/cli/ui/z_machine_terminal_provider.dart';
import 'package:zart/src/logging.dart' show log;
import 'package:logging/logging.dart' show Level;
import 'package:zart/zart.dart' hide getPreamble;
import 'package:zart/src/cli/config/configuration_manager.dart';
import 'package:zart/src/cli/ui/settings_screen.dart';
import 'package:zart/src/cli/ui/terminal_display.dart';

/// A full-screen terminal-based console player for Z-Machine.
/// Uses dart_console for cross-platform support.
void main(List<String> args) async {
  log.level = Level.INFO;

  if (args.isEmpty) {
    stdout.writeln('Usage: zart <game>');
    exit(1);
  }

  final filename = args.first;
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
      stdout.writeln(
        "Zart: Glulx not yet supported. Game file size: ${gameData.length / 1024}kb.",
      );
      exit(1);
    }

    if (fileType == GameFileType.z) {
      await _runZMachineGame(filename, gameData, config);
    }
  } catch (fe) {
    stdout.writeln("Exception occurred while trying to load game: $fe");
    exit(1);
  }
}

Future<void> _runZMachineGame(
  String fileName,
  Uint8List gameData,
  ConfigurationManager config,
) async {
  var isGameRunning = false;
  final terminal = TerminalDisplay();
  terminal.config = config;
  terminal.applySavedSettings();
  terminal.onOpenSettings = () =>
      SettingsScreen(terminal, config).show(isGameStarted: isGameRunning);

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
