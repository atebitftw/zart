/// Represents a contract for IO (Presentation) providers.
abstract class IoProvider {
  /// Sends a command to the provider.
  Future<dynamic> command(Map<String, dynamic> commandMessage);
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

/// Enumerates IO Commands
enum IoCommands {
  /// The split window command.
  splitWindow,

  /// The set text style command.
  setTextStyle,

  /// The set colour command.
  setColour,

  /// The print command.
  print,

  /// The status command.
  status,

  /// The clear screen command.
  clearScreen,

  /// The set window command.
  setWindow,

  /// The set font command.
  setFont,

  /// The save command.
  save,

  /// The restore command.
  restore,

  /// The read command.
  read,

  /// The read char command.
  readChar,

  /// The quit command.
  quit,

  /// The print debug command.
  printDebug,

  /// The async command.
  async,

  /// The set cursor command.
  setCursor,

  /// The erase line command.
  eraseLine,

  /// The get cursor command.
  getCursor,

  /// The input stream command.
  inputStream,

  /// The sound effect command.
  soundEffect,

  /// The set true colour command (V5 Standard 1.1+).
  setTrueColour,
}
