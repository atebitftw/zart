import 'dart:io';
import 'dart:async';

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

  // Initialize Configuration
  final config = ConfigurationManager();
  config.load();

  // final debugFile = File('debug.txt');
  // debugFile.writeAsStringSync(''); // Clear file
  // log.onRecord.listen((record) {
  //   debugFile.writeAsStringSync(
  //     '${record.level.name}: ${record.message}\n',
  //     mode: FileMode.append,
  //   );
  // });

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

  var isGameRunning = false;
  final terminal = TerminalDisplay();
  terminal.config = config;
  terminal.applySavedSettings();
  terminal.onOpenSettings = () =>
      SettingsScreen(terminal, config).show(isGameStarted: isGameRunning);

  try {
    final bytes = f.readAsBytesSync();
    final (gameData, fileType) = Blorb.getStoryFileData(bytes);

    if (fileType == GameFileType.glulx) {
      stdout.writeln("Glulx not yet supported.");
      exit(1);
    }

    if (gameData == null) {
      stdout.writeln('Unable to load game.');
      exit(1);
    }

    // Set IoProvider before loading
    final provider = TerminalProvider(terminal, filename);
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
  } catch (fe) {
    stdout.writeln("Exception occurred while trying to load game: $fe");
    exit(1);
  }

  // Disable debugging for clean display
  Debugger.enableDebug = false;
  Debugger.enableVerbose = false;
  Debugger.enableTrace = false;
  Debugger.enableStackTrace = false;

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

class TerminalProvider implements IoProvider {
  final TerminalDisplay terminal;
  final String gameName;
  bool isQuickSaveMode = false;
  bool isAutorestoreMode = false;
  TerminalProvider(this.terminal, this.gameName);

  @override
  int getFlags1() {
    // Flag 1 = Color available (bit 0)
    // Flag 4 = Bold available (bit 2)
    // Flag 5 = Italic available (bit 3)
    // Flag 6 = Fixed-width font available (bit 4)
    // Flag 8 = Timed input available (bit 7)
    return 1 | 4 | 8 | 16 | 128; // Color, Bold, Italic, Fixed, Timed input
    // Note: Timed input isn't fully implemented in run loop yet but we claim it.
  }

  // Method mapping implementation...
  @override
  Future<dynamic> command(Map<String, dynamic> commandMessage) async {
    final cmd = commandMessage['command'] as IoCommands;
    switch (cmd) {
      case IoCommands.print:
        final window = commandMessage['window'] as int;
        final buffer = commandMessage['buffer'] as String?;
        if (buffer != null) {
          if (window == 1) {
            terminal.writeToWindow1(buffer);
          } else {
            terminal.appendToWindow0(buffer);
          }
        }
        break;
      case IoCommands.splitWindow:
        final lines = commandMessage['lines'] as int;
        terminal.splitWindow(lines);
        break;
      case IoCommands.setWindow:
        // Current window is implicit in print command usage in Z-Machine
        // But we track it in IoProvider? No, ScreenModel manages where text goes?
        // Z-Machine ops: `set_window`.
        // The interpreter passes `window` arg only to `print`.
        // We're good.
        break;
      case IoCommands.clearScreen:
        final window = commandMessage['window_id'] as int;
        if (window == -1 || window == -2) {
          terminal.clearAll();
        } else if (window == 0) {
          terminal.clearWindow0();
        } else if (window == 1) {
          terminal.clearWindow1();
        }
        break;
      case IoCommands.setCursor:
        final line = commandMessage['line'] as int;
        final col = commandMessage['column'] as int;
        terminal.setCursor(line, col);
        break;
      case IoCommands.getCursor:
        return terminal.getCursor();
      case IoCommands.setTextStyle:
        final style = commandMessage['style'] as int;
        terminal.setStyle(style);
        break;
      case IoCommands.setColour:
        final fg = commandMessage['foreground'] as int;
        final bg = commandMessage['background'] as int;
        terminal.setColors(fg, bg);
        break;
      case IoCommands.eraseLine:
        // Erase line in current window?
        // Z-machine standard: erase to end of line.
        // We'll leave unimplemented for now.
        break;
      case IoCommands.status:
        // V3 Status Line
        final room = commandMessage['room_name'] as String;
        final score1 = commandMessage['score_one'] as String;
        final score2 = commandMessage['score_two'] as String;
        final isTime = (commandMessage['game_type'] as String) == 'TIME';

        // Format: "Room Name" (left) ... "Score: A Moves: B" (right)
        final rightText = isTime
            ? 'Time: $score1:$score2'
            : 'Score: $score1 Moves: $score2';

        // Ensure window 1 has at least 1 line
        if (terminal.screen.window1Height < 1) {
          terminal.splitWindow(1); // Force 1 line for status
        }

        // We want to construct a single line of text with padding
        // But writeToWindow1 writes sequentially.
        // And we want INVERSE VIDEO.

        // Enable White on Grey + Bold
        terminal.setStyle(2); // 2=Bold
        terminal.setColors(9, 10); // White on Grey

        // Move to top-left of Window 1
        terminal.setCursor(1, 1);

        // 1. Write Room Name
        terminal.writeToWindow1(' $room');

        // 2. Calculate padding
        final width = terminal.cols;
        final leftLen = room.length + 1; // +1 for leading space
        final rightLen =
            rightText.length + 1; // +1 for trailing space? or just visual?
        final pad = width - leftLen - rightLen;

        if (pad > 0) {
          terminal.writeToWindow1(' ' * pad);
        }

        // 3. Write Score/Moves
        terminal.writeToWindow1('$rightText ');

        // Reset style
        // Reset style
        terminal.setStyle(0);
        terminal.setColors(1, 1); // Reset to defaults
        break;
      case IoCommands.save:
        final fileData = commandMessage['file_data'] as List<int>;

        String filename;
        if (isQuickSaveMode) {
          // QuickSave logic
          // Use format "quick_save_{game_name}.sav"
          // Robustly handle path separators (both / and \) to get just the filename
          String base = gameName.split(RegExp(r'[/\\]')).last;
          if (base.contains('.')) {
            base = base.substring(0, base.lastIndexOf('.'));
          }

          filename = 'quick_save_$base.sav';

          final f = File(filename);
          f.writeAsBytesSync(fileData);

          // Show transient message
          terminal.showTempMessage('Game saved...');

          // Reset flag
          isQuickSaveMode = false;
          return true;
        }

        terminal.appendToWindow0('\nEnter filename to save: ');
        terminal.render();
        filename = await terminal.readLine();
        terminal.appendToWindow0('$filename\n');

        if (filename.isEmpty) return false;

        if (!filename.toLowerCase().endsWith('.sav')) {
          filename += '.sav';
        }

        try {
          final f = File(filename);
          f.writeAsBytesSync(fileData);
          terminal.appendToWindow0('Saved to "$filename".\n');
          return true;
        } catch (e) {
          terminal.appendToWindow0('Save failed: $e\n');
          return false;
        }
      case IoCommands.restore:
        String filename;

        if (isAutorestoreMode) {
          // Robustly handle path separators (both / and \) to get just the filename
          String base = gameName.split(RegExp(r'[/\\]')).last;
          if (base.contains('.')) {
            base = base.substring(0, base.lastIndexOf('.'));
          }

          filename = 'quick_save_$base.sav';

          final f = File(filename);
          if (!f.existsSync()) {
            terminal.showTempMessage(
              'QuickSave File Not Found! Cannot Restore',
              seconds: 3,
            );
            isAutorestoreMode = false;
            return null;
          }

          final data = f.readAsBytesSync();
          // We send success message only after we know we are returning data.
          // Note: The Z-Machine might take a moment to process, but from UI perspective 'Restoring...' is valid.
          // User asked for "Game restored." message after bytes sent.
          // Since we return 'data' here, the Z-Machine uses it *immediately*.
          // So "Game restored..." is appropriate here.
          terminal.showTempMessage('Game restored...', seconds: 3);

          isAutorestoreMode = false;
          return data;
        }

        terminal.appendToWindow0('\nEnter filename to restore: ');
        terminal.render();
        filename = await terminal.readLine();
        terminal.appendToWindow0('$filename\n');

        if (filename.isEmpty) return null;

        if (!filename.toLowerCase().endsWith('.sav')) {
          filename += '.sav';
        }

        try {
          final f = File(filename);
          if (!f.existsSync()) {
            terminal.appendToWindow0('File not found: "$filename"\n');
            return null;
          }
          final data = f.readAsBytesSync();
          terminal.appendToWindow0('Restored from "$filename".\n');
          return data;
        } catch (e) {
          terminal.appendToWindow0('Restore failed: $e\n');
          return null;
        }

      default:
        break;
    }
  }
}
