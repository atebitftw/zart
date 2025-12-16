import 'package:zart/zart.dart' show IoCommands;

/// Represents a contract for IO (Presentation) providers.
abstract class IoProvider {
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
  /// Default returns 0 (no capabilities advertised).
  int getFlags1() => 0;

  /// Sends a Glulx Glk command.
  ///
  /// [selector] is the Glk function selector.
  /// [args] is the list of arguments.
  Future<int> glulxGlk(int selector, List<int> args) => Future.value(0);
}

/// Converts a string to an IO command.
IoCommands toIOCommand(String cmd) {
  switch (cmd) {
    case "IOCommands.PRINT":
      return IoCommands.print;
    case "IOCommands.STATUS":
      return IoCommands.status;
    case "IOCommands.CLEAR_SCREEN":
      return IoCommands.clearScreen;
    case "IOCommands.SPLIT_WINDOW":
      return IoCommands.splitWindow;
    case "IOCommands.SET_WINDOW":
      return IoCommands.setWindow;
    case "IOCommands.SET_FONT":
      return IoCommands.setFont;
    case "IOCommands.SAVE":
      return IoCommands.save;
    case "IOCommands.RESTORE":
      return IoCommands.restore;
    case "IOCommands.READ":
      return IoCommands.read;
    case "IOCommands.READ_CHAR":
      return IoCommands.readChar;
    case "IOCommands.QUIT":
      return IoCommands.quit;
    case "IOCommands.PRINT_DEBUG":
      return IoCommands.printDebug;
    case "IOCommands.ASYNC":
      return IoCommands.async;
    case "IOCommands.SET_CURSOR":
      return IoCommands.setCursor;
    case "IOCommands.SET_TEXT_STYLE":
      return IoCommands.setTextStyle;
    case "IOCommands.SET_COLOUR":
      return IoCommands.setColour;
    case "IOCommands.ERASE_LINE":
      return IoCommands.eraseLine;
    case "IOCommands.GET_CURSOR":
      return IoCommands.getCursor;
    case "IOCommands.INPUT_STREAM":
      return IoCommands.inputStream;
    case "IOCommands.SOUND_EFFECT":
      return IoCommands.soundEffect;
    case "IOCommands.SET_TRUE_COLOUR":
      return IoCommands.setTrueColour;
    default:
      throw Exception("IOCommand not recognized: $cmd");
  }
}
