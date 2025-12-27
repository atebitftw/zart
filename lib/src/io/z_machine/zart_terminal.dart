import 'dart:async';
import 'package:zart/src/io/platform/platform_provider.dart';

/// Unified interface for terminal display operations in Zart.
///
/// This allows UI components like SettingsScreen to work with
/// both Z-machine and Glulx terminal implementations.
abstract interface class ZartTerminal {
  /// Whether the status bar is enabled.
  bool get enableStatusBar;
  set enableStatusBar(bool value);

  /// The platform provider for IO operations.
  PlatformProvider? get platformProvider;
  set platformProvider(PlatformProvider? value);

  /// Callback for opening the settings screen.
  Future<void> Function()? get onOpenSettings;
  set onOpenSettings(Future<void> Function()? value);

  /// Saves the current terminal state (screen contents, cursor, etc).
  void saveState();

  /// Restores the previously saved terminal state.
  void restoreState();

  /// Splits the window at the given line count (sets Window 1 height).
  void splitWindow(int lines);

  /// Clears all terminal windows.
  void clearAll();

  /// Sets text foreground and background colors (Z-machine 1-15 scale).
  void setColors(int fg, int bg);

  /// Appends text to Window 0 (main area).
  void appendToWindow0(String text);

  /// Renders the current state to the terminal.
  void render();

  /// Reads a single character from the terminal.
  Future<String> readChar();

  /// Reads a line of input from the terminal.
  Future<String> readLine({int? windowId});

  /// Shows a temporary status message in the bottom bar.
  void showTempMessage(String message, {int seconds = 3});
}
