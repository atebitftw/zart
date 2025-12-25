/// Enumerates IO Commands sent from the Z-Machine to the IO provider.
///
/// Each command is sent as a Map with a "command" key containing the IoCommand,
/// plus additional keys for parameters specific to that command.
enum ZIoCommands {
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
