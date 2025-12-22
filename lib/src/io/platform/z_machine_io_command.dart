/// Typed Z-machine IO commands.
///
/// These replace the string-based command dispatch in the old `ZIoDispatcher`.
/// Each command type carries its specific parameters in a type-safe way.
sealed class ZMachineIOCommand {}

/// Print text to a window.
class PrintCommand extends ZMachineIOCommand {
  /// The window to print to (0 = main, 1 = status).
  final int window;

  /// The text to print.
  final String text;

  PrintCommand({required this.window, required this.text});
}

/// Split the screen into windows.
class SplitWindowCommand extends ZMachineIOCommand {
  /// Number of lines for the upper window.
  final int lines;

  SplitWindowCommand({required this.lines});
}

/// Set the active window for output.
class SetWindowCommand extends ZMachineIOCommand {
  /// The window ID to make active.
  final int window;

  SetWindowCommand({required this.window});
}

/// Clear a window or the entire screen.
class ClearScreenCommand extends ZMachineIOCommand {
  /// Window ID to clear, or -1/-2 for special clear operations.
  /// - -1: Clear all windows
  /// - -2: Clear all windows and reset
  /// - 0: Clear main window
  /// - 1: Clear status window
  final int windowId;

  ClearScreenCommand({required this.windowId});
}

/// Set cursor position in the upper window.
class SetCursorCommand extends ZMachineIOCommand {
  /// Row (1-indexed).
  final int row;

  /// Column (1-indexed).
  final int column;

  SetCursorCommand({required this.row, required this.column});
}

/// Get current cursor position.
class GetCursorCommand extends ZMachineIOCommand {}

/// Set text style flags.
class SetTextStyleCommand extends ZMachineIOCommand {
  /// Style flags:
  /// - 0: Roman (normal)
  /// - 1: Reverse video
  /// - 2: Bold
  /// - 4: Italic
  /// - 8: Fixed-pitch
  final int style;

  SetTextStyleCommand({required this.style});
}

/// Set text colors.
class SetColourCommand extends ZMachineIOCommand {
  /// Foreground color (1-12, 0 for no change).
  final int foreground;

  /// Background color (1-12, 0 for no change).
  final int background;

  SetColourCommand({required this.foreground, required this.background});
}

/// Set true (RGB) colors.
class SetTrueColourCommand extends ZMachineIOCommand {
  /// Foreground color in RGB format.
  final int foreground;

  /// Background color in RGB format.
  final int background;

  SetTrueColourCommand({required this.foreground, required this.background});
}

/// Erase to end of line.
class EraseLineCommand extends ZMachineIOCommand {}

/// Set the font.
class SetFontCommand extends ZMachineIOCommand {
  /// Font number (1 = normal, 3 = fixed, 4 = graphics).
  final int font;

  SetFontCommand({required this.font});
}

/// Request to save game state.
class SaveCommand extends ZMachineIOCommand {
  /// The game state data to save.
  final List<int> fileData;

  SaveCommand({required this.fileData});
}

/// Request to restore game state.
class RestoreCommand extends ZMachineIOCommand {}

/// Display the status line (V3 games).
class StatusCommand extends ZMachineIOCommand {
  /// The room/location name.
  final String roomName;

  /// First score field (score or hours).
  final String scoreOne;

  /// Second score field (moves or minutes).
  final String scoreTwo;

  /// Whether this is a time game ("TIME") or score game ("SCORE").
  final String gameType;

  StatusCommand({
    required this.roomName,
    required this.scoreOne,
    required this.scoreTwo,
    required this.gameType,
  });
}

/// Play a sound effect.
class SoundEffectCommand extends ZMachineIOCommand {
  /// Sound number.
  final int sound;

  /// Effect (1 = prepare, 2 = play, 3 = stop, 4 = finish).
  final int effect;

  /// Volume (1-8).
  final int volume;

  SoundEffectCommand({
    required this.sound,
    required this.effect,
    required this.volume,
  });
}

/// Switch input stream.
class InputStreamCommand extends ZMachineIOCommand {
  /// Stream number (0 = keyboard, 1 = file).
  final int stream;

  InputStreamCommand({required this.stream});
}

/// Game is quitting.
class QuitCommand extends ZMachineIOCommand {}

/// Debug print (for interpreter debugging).
class PrintDebugCommand extends ZMachineIOCommand {
  /// Debug message.
  final String message;

  PrintDebugCommand({required this.message});
}

/// Async operation (for timed input, etc).
class AsyncCommand extends ZMachineIOCommand {
  /// The async operation type.
  final String operation;

  AsyncCommand({required this.operation});
}
