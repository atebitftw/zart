import 'package:zart/src/io/z_io_commands.dart' show ZIoCommands;

/// Dispatch layer interface for Z-Machine IO.
abstract class ZIoDispatcher {
  /// Sends a command to the provider.
  Future<dynamic> command(Map<String, dynamic> commandMessage);

  /// Returns the flags1 capabilities this provider supports.
  ///
  /// Override to declare capabilities (screen split, colors, bold, etc).
  /// Use constants from [Header] class, e.g.:
  /// - [Header.flag1V3ScreenSplitAvail] - split window support
  /// - [Header.flag1VSColorAvail] - color support
  /// - [Header.flag1V4BoldfaceAvail] - bold text support
  ///
  /// Default returns 0 (no capabilities advertised).
  int getFlags1() => 0;

  /// Returns the screen dimensions as (width, height) in characters.
  (int, int) getScreenSize() => (80, 24);

  /// Performs a non-interactive quick save.
  Future<String?> quickSave(List<int> data) async => null;

  /// Performs a non-interactive quick restore.
  Future<List<int>?> quickRestore() async => null;
}

/// Converts a string to an IO command.
ZIoCommands toIOCommand(String cmd) {
  switch (cmd) {
    case "IOCommands.PRINT":
      return ZIoCommands.print;
    case "IOCommands.STATUS":
      return ZIoCommands.status;
    case "IOCommands.CLEAR_SCREEN":
      return ZIoCommands.clearScreen;
    case "IOCommands.SPLIT_WINDOW":
      return ZIoCommands.splitWindow;
    case "IOCommands.SET_WINDOW":
      return ZIoCommands.setWindow;
    case "IOCommands.SET_FONT":
      return ZIoCommands.setFont;
    case "IOCommands.SAVE":
      return ZIoCommands.save;
    case "IOCommands.RESTORE":
      return ZIoCommands.restore;
    case "IOCommands.READ":
      return ZIoCommands.read;
    case "IOCommands.READ_CHAR":
      return ZIoCommands.readChar;
    case "IOCommands.QUIT":
      return ZIoCommands.quit;
    case "IOCommands.PRINT_DEBUG":
      return ZIoCommands.printDebug;
    case "IOCommands.ASYNC":
      return ZIoCommands.async;
    case "IOCommands.SET_CURSOR":
      return ZIoCommands.setCursor;
    case "IOCommands.SET_TEXT_STYLE":
      return ZIoCommands.setTextStyle;
    case "IOCommands.SET_COLOUR":
      return ZIoCommands.setColour;
    case "IOCommands.ERASE_LINE":
      return ZIoCommands.eraseLine;
    case "IOCommands.GET_CURSOR":
      return ZIoCommands.getCursor;
    case "IOCommands.INPUT_STREAM":
      return ZIoCommands.inputStream;
    case "IOCommands.SOUND_EFFECT":
      return ZIoCommands.soundEffect;
    case "IOCommands.SET_TRUE_COLOUR":
      return ZIoCommands.setTrueColour;
    default:
      throw Exception("IOCommand not recognized: $cmd");
  }
}
