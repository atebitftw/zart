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
  int getFlags1() => 0;
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

/// Enumerates IO Commands sent from the Z-Machine to the IO provider.
///
/// Each command is sent as a Map with a "command" key containing the IoCommand,
/// plus additional keys for parameters specific to that command.
enum IoCommands {
  /// Split the screen to create an upper window.
  ///
  /// **Parameters:**
  /// - `lines`: Number of lines for the upper window (0 = close upper window)
  splitWindow,

  /// Set the current text style.
  ///
  /// **Parameters:**
  /// - `style`: Bitmask of style flags:
  ///   - 0 = Roman (clear all styles)
  ///   - 1 = Reverse video
  ///   - 2 = Bold
  ///   - 4 = Italic
  ///   - 8 = Fixed-pitch (monospace)
  setTextStyle,

  /// Set text colors.
  ///
  /// **Parameters:**
  /// - `foreground`: Color code (0=current, 1=default, 2-9=standard colors)
  /// - `background`: Color code
  setColour,

  /// Print text to the current window.
  ///
  /// **Parameters:**
  /// - `window`: Window number (0=lower, 1=upper)
  /// - `buffer`: String text to print
  print,

  /// Update the status line (V3 only).
  ///
  /// **Parameters:**
  /// - `game_type`: "SCORE" or "TIME"
  /// - `room_name`: Current room name
  /// - `score_one`: Score or hours
  /// - `score_two`: Turns or minutes
  status,

  /// Clear/erase a window.
  ///
  /// **Parameters:**
  /// - `window_id`: Signed value:
  ///   - -2 = Clear all windows and unsplit (close upper window)
  ///   - -1 = Clear all windows
  ///   - 0 = Clear lower window only
  ///   - 1 = Clear upper window only
  clearScreen,

  /// Set the current output window.
  ///
  /// **Parameters:**
  /// - `window`: Window number (0=lower/main, 1=upper/status)
  setWindow,

  /// Set the current font.
  ///
  /// **Parameters:**
  /// - `font_id`: Font number (1=normal, 4=fixed-pitch)
  ///
  /// **Returns:** Previous font number, or 0 if font not available
  setFont,

  /// Save the game state.
  ///
  /// **Parameters:**
  /// - `file_data`: Quetzal save data as bytes
  ///
  /// **Returns:** true on success, false on failure
  save,

  /// Restore the game state.
  ///
  /// **Returns:** Quetzal save data bytes, or null on failure/cancel
  restore,

  /// Request line input from the user.
  ///
  /// **Returns:** String of user input
  read,

  /// Request single character input.
  ///
  /// **Returns:** String containing single character
  readChar,

  /// Quit the game.
  quit,

  /// Print debug information (internal use).
  printDebug,

  /// Execute an async operation (internal use).
  async,

  /// Set the cursor position in the current window.
  ///
  /// **Parameters:**
  /// - `line`: 1-indexed line number
  /// - `column`: 1-indexed column number
  ///
  /// **Note:** Only valid when upper window is selected.
  setCursor,

  /// Erase from cursor to end of line.
  eraseLine,

  /// Get the current cursor position.
  ///
  /// **Returns:** Map with `row` and `column` keys (1-indexed)
  getCursor,

  /// Select input stream (rarely used).
  inputStream,

  /// Play a sound effect.
  ///
  /// **Parameters:**
  /// - `number`: Sound number (1-2 = bleeps, 3+ = resources)
  /// - `effect`: Optional (1=prepare, 2=start, 3=stop, 4=finish)
  /// - `volume`: Optional volume/repeats
  /// - `routine`: Optional callback routine address
  soundEffect,

  /// Set true colors using 15-bit RGB values (Standard 1.1+).
  ///
  /// **Parameters:**
  /// - `foreground`: 15-bit color (0xFFFE=current, 0xFFFF=default)
  /// - `background`: 15-bit color
  setTrueColour,
}
