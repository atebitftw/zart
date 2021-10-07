/// Represents a contract for IO (Presentation) providers.
abstract class IOProvider {
  Future<dynamic> command(Map<String, dynamic> commandMessage);
}

ioCommands toIOCommand(String cmd) {
  switch (cmd) {
    case "IOCommands.PRINT":
      return ioCommands.print;
    case "IOCommands.STATUS":
      return ioCommands.status;
    case "IOCommands.CLEAR_SCREEN":
      return ioCommands.clearScreen;
    case "IOCommands.SPLIT_SCREEN":
      return ioCommands.splitScreen;
    case "IOCommands.SET_WINDOW":
      return ioCommands.setWindow;
    case "IOCommands.SET_FONT":
      return ioCommands.setFont;
    case "IOCommands.SAVE":
      return ioCommands.save;
    case "IOCommands.RESTORE":
      return ioCommands.restore;
    case "IOCommands.READ":
      return ioCommands.read;
    case "IOCommands.READ_CHAR":
      return ioCommands.readChar;
    case "IOCommands.QUIT":
      return ioCommands.quit;
    case "IOCommands.PRINT_DEBUG":
      return ioCommands.printDebug;
    case "IOCommands.ASYNC":
      return ioCommands.async;
    case "IOCommands.SET_CURSOR":
      return ioCommands.setCursor;
    default:
      throw Exception("IOCommand not recognized: $cmd");
  }
}

/// Enumerates IO Commands
enum ioCommands { print, status, clearScreen, splitScreen, setWindow, setFont, save, restore, read, readChar, quit, printDebug, async, setCursor }
