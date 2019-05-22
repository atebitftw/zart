import 'dart:async';

/// Represents a contract for IO (Presentation) providers.
abstract class IOProvider {

  //TODO use isolates between IO and engine.

  Future<Object> command(String JSONCommand);
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