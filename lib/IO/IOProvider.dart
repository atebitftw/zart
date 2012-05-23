
/**
* Represents a contract for IO (Presentation) providers.
*/
interface IOProvider {

  //TODO use isolates between IO and engine.

  Future<Object> command(String JSONCommand);
}

/** Enumerates supported IO command message */
class IOCommands{
  final String _str;

  const IOCommands(this._str);

  static final PRINT = const IOCommands('PRINT');
  static final STATUS = const IOCommands('STATUS');
  static final CLEAR_SCREEN = const IOCommands('CLEAR_SCREEN');
  static final SPLIT_SCREEN = const IOCommands('SPLIT_SCREEN');
  static final SET_WINDOW = const IOCommands('SET_WINDOW');
  static final SET_FONT = const IOCommands('SET_FONT');
  static final SAVE = const IOCommands('SAVE');
  static final RESTORE = const IOCommands('RESTORE');
  static final READ = const IOCommands('READ');
  static final READ_CHAR = const IOCommands('READ_CHAR');
  static final QUIT = const IOCommands('QUIT');
  static final PRINT_DEBUG = const IOCommands('PRINT_DEBUG');
  static final ASYNC = const IOCommands('ASYNC');
  static final SET_CURSOR = const IOCommands('SET_CURSOR');

  static IOCommands toIOCommand(String cmd){
    switch(cmd){
      case "PRINT": return IOCommands.PRINT;
      case "STATUS": return IOCommands.STATUS;
      case "CLEAR_SCREEN": return IOCommands.CLEAR_SCREEN;
      case "SPLIT_SCREEN": return IOCommands.SPLIT_SCREEN;
      case "SET_WINDOW": return IOCommands.SET_WINDOW;
      case "SET_FONT": return IOCommands.SET_FONT;
      case "SAVE": return IOCommands.SAVE;
      case "RESTORE": return IOCommands.RESTORE;
      case "READ": return IOCommands.READ;
      case "READ_CHAR": return IOCommands.READ_CHAR;
      case "QUIT": return IOCommands.QUIT;
      case "PRINT_DEBUG": return IOCommands.PRINT_DEBUG;
      case "ASYNC": return IOCommands.ASYNC;
      case "SET_CURSOR": return IOCommands.SET_CURSOR;
    }
  }

  String toString() => _str;

}