/// Represents a contract for IO (Presentation) providers.
abstract class IoProvider {
  Future<dynamic> command(Map<String, dynamic> commandMessage);
}

IoCommands toIOCommand(String cmd) {
  switch (cmd) {
    case "IOCommands.PRINT":
      return IoCommands.print;
    case "IOCommands.STATUS":
      return IoCommands.status;
    case "IOCommands.CLEAR_SCREEN":
      return IoCommands.clearScreen;
    case "IOCommands.SPLIT_SCREEN":
      return IoCommands.splitScreen;
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
    default:
      throw Exception("IOCommand not recognized: $cmd");
  }
}

/// Enumerates IO Commands
enum IoCommands {
  print,
  status,
  clearScreen,
  splitScreen,
  setWindow,
  setFont,
  save,
  restore,
  read,
  readChar,
  quit,
  printDebug,
  async,
  setCursor,
}
