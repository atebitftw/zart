import 'package:zart/src/io/z_machine/z_terminal_display.dart';
import 'package:zart/src/io/platform/platform_provider.dart';
import 'package:zart/src/zart_internal.dart';

/// Terminal provider for Z-Machine IO.
class ZMachineIoDispatcher implements ZIoDispatcher {
  final ZTerminalDisplay _terminal;
  final PlatformProvider _provider;

  /// Default constructor.
  ZMachineIoDispatcher(this._terminal, this._provider);

  @override
  int getFlags1() {
    final caps = _provider.capabilities;
    int flags = 0;
    if (caps.supportsColors) flags |= 1;
    if (caps.supportsBold) flags |= 4;
    if (caps.supportsItalic) flags |= 8;
    if (caps.supportsFixedPitch) flags |= 16;
    if (caps.supportsTimedInput) flags |= 128;
    return flags;
  }

  @override
  (int, int) getScreenSize() {
    final caps = _provider.capabilities;
    return (caps.screenWidth, caps.screenHeight);
  }

  @override
  Future<String?> quickSave(List<int> data) => _provider.quickSave(data);

  @override
  Future<List<int>?> quickRestore() => _provider.quickRestore();

  // Method mapping implementation...
  @override
  Future<dynamic> command(Map<String, dynamic> commandMessage) async {
    final cmd = commandMessage['command'] as ZIoCommands;
    switch (cmd) {
      case ZIoCommands.print:
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
      case ZIoCommands.splitWindow:
        final lines = commandMessage['lines'] as int;
        _terminal.splitWindow(lines);
        break;
      case ZIoCommands.setWindow:
        // Current window is implicit in print command usage in Z-Machine
        // But we track it in IoProvider? No, ScreenModel manages where text goes?
        // Z-Machine ops: `set_window`.
        // The interpreter passes `window` arg only to `print`.
        // We're good.
        break;
      case ZIoCommands.clearScreen:
        final window = commandMessage['window_id'] as int;
        if (window == -1 || window == -2) {
          _terminal.clearAll();
        } else if (window == 0) {
          _terminal.clearWindow0();
        } else if (window == 1) {
          _terminal.clearWindow1();
        }
        break;
      case ZIoCommands.setCursor:
        final line = commandMessage['line'] as int;
        final col = commandMessage['column'] as int;
        _terminal.setCursor(line, col);
        break;
      case ZIoCommands.getCursor:
        return _terminal.getCursor();
      case ZIoCommands.setTextStyle:
        final style = commandMessage['style'] as int;
        _terminal.setStyle(style);
        break;
      case ZIoCommands.setColour:
        final fg = commandMessage['foreground'] as int;
        final bg = commandMessage['background'] as int;
        _terminal.setColors(fg, bg);
        break;
      case ZIoCommands.setFont:
        final fontId = commandMessage['font_id'] as int;
        return _terminal.setFont(fontId);
      case ZIoCommands.eraseLine:
        // Erase line in current window?
        // Z-machine standard: erase to end of line.
        // We'll leave unimplemented for now.
        break;
      case ZIoCommands.status:
        // V3 Status Line
        final room = commandMessage['room_name'] as String;
        final score1 = commandMessage['score_one'] as String;
        final score2 = commandMessage['score_two'] as String;
        final isTime = (commandMessage['game_type'] as String) == 'TIME';

        // Format: "Room Name" (left) ... "Score: A Moves: B" (right)
        final rightText = isTime ? 'Time: $score1:$score2' : 'Score: $score1 Moves: $score2';

        // Ensure window 1 has at least 1 line
        if (_terminal.screen.window1Height < 1) {
          _terminal.splitWindow(1); // Force 1 line for status
        }

        // Enable White on Grey + Bold
        _terminal.setStyle(3); // 3=Bold+Reverse
        _terminal.setColors(9, 10); // White on Grey

        // Move to top-left of Window 1
        _terminal.setCursor(1, 1);

        // 1. Write Room Name
        _terminal.writeToWindow1(' $room');

        // 2. Calculate padding
        final width = _terminal.cols;
        final leftLen = room.length + 1; // +1 for leading space
        final rightLen = rightText.length + 1; // +1 for trailing space? or just visual?
        final pad = width - leftLen - rightLen;

        if (pad > 0) {
          _terminal.writeToWindow1(' ' * pad);
        }

        // 3. Write Score/Moves
        _terminal.writeToWindow1('$rightText ');

        // Reset style
        _terminal.setStyle(0);
        _terminal.setColors(1, 1); // Reset to defaults
        break;
      case ZIoCommands.save:
        final fileData = commandMessage['file_data'] as List<int>;
        return _provider.saveGame(fileData);
      case ZIoCommands.restore:
        return _provider.restoreGame();

      default:
        break;
    }
  }
}
