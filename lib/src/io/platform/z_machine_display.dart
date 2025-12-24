/// Abstract interface for Z-machine display operations.
///
/// Represents the display/input surface for Z-machine games.
/// [GameRunner] uses this interface to drive the Z-machine game loop
/// without knowing the concrete display implementation.
abstract class ZMachineDisplay {
  /// Whether the status bar is enabled.
  bool get enableStatusBar;
  set enableStatusBar(bool value);

  /// Render the current display state.
  void render();

  /// Detect and update terminal size.
  void detectTerminalSize();

  /// Read a line of text input.
  ///
  /// Returns the input text, or `'__RESTORED__'` if a quick restore
  /// was triggered and the game state was restored.
  Future<String> readLine();

  /// Read a single character.
  ///
  /// Returns the character as a string.
  Future<String> readChar();

  /// Append text to window 0 (main window).
  void appendToWindow0(String text);

  /// Append echoed input text to the display.
  void appendInputEcho(String text);
}
