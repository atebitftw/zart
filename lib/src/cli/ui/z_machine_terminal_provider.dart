import 'dart:io';

import 'package:zart/src/cli/ui/terminal_display.dart';
import 'package:zart/zart.dart';

/// Terminal provider for Z-Machine IO.
class ZMachineTerminalProvider implements IoProvider {
  final TerminalDisplay _terminal;
  final String _gameName;
  bool isQuickSaveMode = false;
  bool isAutorestoreMode = false;
  ZMachineTerminalProvider(this._terminal, this._gameName);

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
            _terminal.writeToWindow1(buffer);
          } else {
            _terminal.appendToWindow0(buffer);
          }
        }
        break;
      case IoCommands.splitWindow:
        final lines = commandMessage['lines'] as int;
        _terminal.splitWindow(lines);
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
          _terminal.clearAll();
        } else if (window == 0) {
          _terminal.clearWindow0();
        } else if (window == 1) {
          _terminal.clearWindow1();
        }
        break;
      case IoCommands.setCursor:
        final line = commandMessage['line'] as int;
        final col = commandMessage['column'] as int;
        _terminal.setCursor(line, col);
        break;
      case IoCommands.getCursor:
        return _terminal.getCursor();
      case IoCommands.setTextStyle:
        final style = commandMessage['style'] as int;
        _terminal.setStyle(style);
        break;
      case IoCommands.setColour:
        final fg = commandMessage['foreground'] as int;
        final bg = commandMessage['background'] as int;
        _terminal.setColors(fg, bg);
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
        if (_terminal.screen.window1Height < 1) {
          _terminal.splitWindow(1); // Force 1 line for status
        }

        // We want to construct a single line of text with padding
        // But writeToWindow1 writes sequentially.
        // And we want INVERSE VIDEO.

        // Enable White on Grey + Bold
        _terminal.setStyle(2); // 2=Bold
        _terminal.setColors(9, 10); // White on Grey

        // Move to top-left of Window 1
        _terminal.setCursor(1, 1);

        // 1. Write Room Name
        _terminal.writeToWindow1(' $room');

        // 2. Calculate padding
        final width = _terminal.cols;
        final leftLen = room.length + 1; // +1 for leading space
        final rightLen =
            rightText.length + 1; // +1 for trailing space? or just visual?
        final pad = width - leftLen - rightLen;

        if (pad > 0) {
          _terminal.writeToWindow1(' ' * pad);
        }

        // 3. Write Score/Moves
        _terminal.writeToWindow1('$rightText ');

        // Reset style
        // Reset style
        _terminal.setStyle(0);
        _terminal.setColors(1, 1); // Reset to defaults
        break;
      case IoCommands.save:
        final fileData = commandMessage['file_data'] as List<int>;

        String filename;
        if (isQuickSaveMode) {
          // QuickSave logic
          // Use format "quick_save_{game_name}.sav"
          // Robustly handle path separators (both / and \) to get just the filename
          String base = _gameName.split(RegExp(r'[/\\]')).last;
          if (base.contains('.')) {
            base = base.substring(0, base.lastIndexOf('.'));
          }

          filename = 'quick_save_$base.sav';

          final f = File(filename);
          f.writeAsBytesSync(fileData);

          // Show transient message
          _terminal.showTempMessage('Game saved...');

          // Reset flag
          isQuickSaveMode = false;
          return true;
        }

        _terminal.appendToWindow0('\nEnter filename to save: ');
        _terminal.render();
        filename = await _terminal.readLine();
        _terminal.appendToWindow0('$filename\n');

        if (filename.isEmpty) return false;

        if (!filename.toLowerCase().endsWith('.sav')) {
          filename += '.sav';
        }

        try {
          final f = File(filename);
          f.writeAsBytesSync(fileData);
          _terminal.appendToWindow0('Saved to "$filename".\n');
          return true;
        } catch (e) {
          _terminal.appendToWindow0('Save failed: $e\n');
          return false;
        }
      case IoCommands.restore:
        String filename;

        if (isAutorestoreMode) {
          // Robustly handle path separators (both / and \) to get just the filename
          String base = _gameName.split(RegExp(r'[/\\]')).last;
          if (base.contains('.')) {
            base = base.substring(0, base.lastIndexOf('.'));
          }

          filename = 'quick_save_$base.sav';

          final f = File(filename);
          if (!f.existsSync()) {
            _terminal.showTempMessage(
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
          _terminal.showTempMessage('Game restored...', seconds: 3);

          isAutorestoreMode = false;
          return data;
        }

        _terminal.appendToWindow0('\nEnter filename to restore: ');
        _terminal.render();
        filename = await _terminal.readLine();
        _terminal.appendToWindow0('$filename\n');

        if (filename.isEmpty) return null;

        if (!filename.toLowerCase().endsWith('.sav')) {
          filename += '.sav';
        }

        try {
          final f = File(filename);
          if (!f.existsSync()) {
            _terminal.appendToWindow0('File not found: "$filename"\n');
            return null;
          }
          final data = f.readAsBytesSync();
          _terminal.appendToWindow0('Restored from "$filename".\n');
          return data;
        } catch (e) {
          _terminal.appendToWindow0('Restore failed: $e\n');
          return null;
        }

      default:
        break;
    }
  }
}
