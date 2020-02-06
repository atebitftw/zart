import 'dart:async';

/// Represents a contract for IO (Presentation) providers.
abstract class IOProvider {

  //TODO use isolates between IO and engine?

  Future<Object> command(String JSONCommand);
}

IOCommands toIOCommand(String cmd){
  switch(cmd){
    case "IOCommands.PRINT": return IOCommands.PRINT;
    case "IOCommands.STATUS": return IOCommands.STATUS;
    case "IOCommands.CLEAR_SCREEN": return IOCommands.CLEAR_SCREEN;
    case "IOCommands.SPLIT_SCREEN": return IOCommands.SPLIT_SCREEN;
    case "IOCommands.SET_WINDOW": return IOCommands.SET_WINDOW;
    case "IOCommands.SET_FONT": return IOCommands.SET_FONT;
    case "IOCommands.SAVE": return IOCommands.SAVE;
    case "IOCommands.RESTORE": return IOCommands.RESTORE;
    case "IOCommands.READ": return IOCommands.READ;
    case "IOCommands.READ_CHAR": return IOCommands.READ_CHAR;
    case "IOCommands.QUIT": return IOCommands.QUIT;
    case "IOCommands.PRINT_DEBUG": return IOCommands.PRINT_DEBUG;
    case "IOCommands.ASYNC": return IOCommands.ASYNC;
    case "IOCommands.SET_CURSOR": return IOCommands.SET_CURSOR;
    default:
      throw Exception("IOCommand not recognized: $cmd");
  }

}

/// Enumerates IO Commands
enum IOCommands{
  PRINT,
  STATUS,
  CLEAR_SCREEN,
  SPLIT_SCREEN,
  SET_WINDOW,
  SET_FONT,
  SAVE,
  RESTORE,
  READ,
  READ_CHAR,
  QUIT,
  PRINT_DEBUG,
  ASYNC,
  SET_CURSOR
}

