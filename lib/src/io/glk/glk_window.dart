import 'glk_cell.dart';
import 'glk_styles.dart';

/// Enum for Glk window types.
///
/// Glk Spec: "Currently there are four window types" (plus pair windows
/// which are internal containers created automatically by splits).
enum GlkWindowType {
  /// A text buffer window - linear stream of styled text.
  textBuffer,

  /// A text grid window - rectangular array of characters.
  textGrid,

  /// A graphics window - rectangular array of pixels.
  graphics,

  /// A blank window - displays nothing.
  blank,

  /// A pair window - internal container created by splits.
  pair,
}

/// Base class for all Glk windows.
///
/// Each window has a unique ID, an optional rock value for game use,
/// and tracks its own input state independently.
///
/// Glk Spec: "Every window has a type... A window also has a rock value."
abstract class GlkWindow {
  /// Unique window ID (maps to Glk winid_t).
  /// This is what gets passed back in event_t, not the rock.
  final int id;

  /// User-provided rock value for game's own use.
  final int rock;

  /// Window type.
  final GlkWindowType type;

  /// Parent window (always a pair window, or null for root).
  GlkWindow? parent;

  /// Current style for output (GlkStyle.normal = 0 by default).
  int style = GlkStyle.normal;

  /// Window width in measurement units (chars for text, pixels for graphics).
  int width = 0;

  /// Window height in measurement units.
  int height = 0;

  /// Screen position X (for rendering, computed by layout).
  int screenX = 0;

  /// Screen position Y (for rendering, computed by layout).
  int screenY = 0;

  // === Input State ===
  // Glk Spec: "It is legal to request input from several windows at the same time."
  // The screen model tracks pending input; focus switching is presentation layer's job.

  /// True if line input is pending for this window.
  bool lineInputPending = false;

  /// Buffer address for pending line input (VM memory address).
  int lineInputBufferAddr = 0;

  /// Maximum length for pending line input.
  int lineInputMaxLen = 0;

  /// True if character input is pending for this window.
  bool charInputPending = false;

  /// True if mouse input is pending for this window.
  bool mouseInputPending = false;

  GlkWindow({required this.id, required this.rock, required this.type});
}

/// Text buffer window - linear stream of styled text.
///
/// Glk Spec: "A text buffer contains a linear stream of text. You add
/// characters to the end... and the window wraps them into lines."
class GlkTextBufferWindow extends GlkWindow {
  /// Lines of text, each line is a list of cells.
  /// New text is appended to the last line (or a new line after newlines).
  /// Lines are trimmed to visible height - old text scrolls off forever.
  final List<List<GlkCell>> lines = [];

  /// Current line being written to.
  List<GlkCell> get currentLine {
    if (lines.isEmpty) {
      lines.add([]);
    }
    return lines.last;
  }

  GlkTextBufferWindow({required super.id, required super.rock})
    : super(type: GlkWindowType.textBuffer);

  /// Add a new line.
  void newLine() {
    lines.add([]);
    // Trim old lines if exceeding visible height (no scrollback).
    trimToVisibleHeight();
  }

  /// Trim lines to some reasonable maximum history (e.g. 1000 lines).
  void trimToVisibleHeight() {
    const maxHistory = 1000;
    while (lines.length > maxHistory) {
      lines.removeAt(0);
    }
  }

  /// Clear the buffer.
  void clear() {
    lines.clear();
    lines.add([]);
  }
}

/// Text grid window - fixed character grid with cursor.
///
/// Glk Spec: "A text grid contains a rectangular array of characters."
/// Characters are written at cursor position, which advances automatically.
class GlkTextGridWindow extends GlkWindow {
  /// 2D grid of cells: grid[row][col].
  late List<List<GlkCell>> grid;

  /// Cursor X position (0-indexed, unlike Z-machine which is 1-indexed).
  int cursorX = 0;

  /// Cursor Y position (0-indexed).
  int cursorY = 0;

  GlkTextGridWindow({required super.id, required super.rock})
    : super(type: GlkWindowType.textGrid) {
    grid = [];
  }

  /// Resize the grid, preserving content where possible.
  void resize(int newWidth, int newHeight) {
    final newGrid = List.generate(
      newHeight,
      (row) => List.generate(
        newWidth,
        (col) => (row < grid.length && col < grid[row].length)
            ? grid[row][col].clone()
            : GlkCell.empty(),
      ),
    );
    grid = newGrid;
    width = newWidth;
    height = newHeight;
    // Clamp cursor to valid range.
    cursorX = cursorX.clamp(0, newWidth > 0 ? newWidth - 1 : 0);
    cursorY = cursorY.clamp(0, newHeight > 0 ? newHeight - 1 : 0);
  }

  /// Move cursor to position.
  /// Glk Spec: "glk_window_move_cursor() sets the position of the cursor."
  void moveCursor(int x, int y) {
    cursorX = x.clamp(0, width > 0 ? width - 1 : 0);
    cursorY = y.clamp(0, height > 0 ? height - 1 : 0);
  }

  /// Clear the grid.
  void clear() {
    for (final row in grid) {
      for (var i = 0; i < row.length; i++) {
        row[i] = GlkCell.empty();
      }
    }
    cursorX = 0;
    cursorY = 0;
  }
}

/// Graphics window - pixel array (stub for future implementation).
///
/// Glk Spec: "A graphics window contains a rectangular array of pixels."
class GlkGraphicsWindow extends GlkWindow {
  /// Background color (0x00RRGGBB format).
  int backgroundColor = 0x00FFFFFF; // White

  // TODO: Implement pixel buffer when graphics support is needed.
  // For now, this is a stub to allow opening graphics windows without crashing.

  GlkGraphicsWindow({required super.id, required super.rock})
    : super(type: GlkWindowType.graphics);

  /// Clear the graphics window to background color.
  void clear() {
    // Stub - will fill pixel buffer with backgroundColor when implemented.
  }
}

/// Blank window - displays nothing, used for spacing.
///
/// Glk Spec: "A blank window is always empty."
class GlkBlankWindow extends GlkWindow {
  GlkBlankWindow({required super.id, required super.rock})
    : super(type: GlkWindowType.blank);
}

/// Pair window - internal container created by splits.
///
/// Glk Spec: "Pair windows are created automatically every time you split
/// a window... You should not try to create pair windows yourself."
class GlkPairWindow extends GlkWindow {
  /// First child window.
  GlkWindow? child1;

  /// Second child window (the newly created one from split).
  GlkWindow? child2;

  /// Key window for fixed splits (determines size).
  /// Glk Spec: "Recall that every pair window has a key window."
  GlkWindow? keyWindow;

  /// The split method (direction + fixed/proportional + border).
  int method = 0;

  /// Split size (rows/cols for fixed, percentage for proportional).
  int size = 0;

  GlkPairWindow({required super.id, required super.rock})
    : super(type: GlkWindowType.pair);
}
