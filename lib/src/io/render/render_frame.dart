import 'render_cell.dart';

/// A window region with its cell grid for rendering.
///
/// Represents a rectangular area on screen with its content.
class RenderWindow {
  /// Unique window identifier.
  final int id;

  /// X position (column, 0-indexed).
  final int x;

  /// Y position (row, 0-indexed).
  final int y;

  /// Width in characters.
  final int width;

  /// Height in characters.
  final int height;

  /// Cell grid (rows x cols). May be smaller than width/height if content is sparse.
  final List<List<RenderCell>> cells;

  /// True if this window is accepting input (line or character).
  final bool acceptsInput;

  /// Cursor column position within window (for text grid windows).
  final int cursorX;

  /// Cursor row position within window.
  final int cursorY;

  /// True if this is a text buffer window (scrollable).
  final bool isTextBuffer;

  const RenderWindow({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.cells,
    this.acceptsInput = false,
    this.cursorX = 0,
    this.cursorY = 0,
    this.isTextBuffer = false,
  });
}

/// A complete frame ready for rendering by a presentation layer.
///
/// Contains all visible windows and their content.
class RenderFrame {
  /// All visible windows, in render order (back to front).
  final List<RenderWindow> windows;

  /// ID of the window currently focused for input, or null if none.
  final int? focusedWindowId;

  /// Total screen width in characters.
  final int screenWidth;

  /// Total screen height in characters.
  final int screenHeight;

  const RenderFrame({
    required this.windows,
    required this.screenWidth,
    required this.screenHeight,
    this.focusedWindowId,
  });

  /// Get a window by ID.
  RenderWindow? getWindow(int id) {
    for (final w in windows) {
      if (w.id == id) return w;
    }
    return null;
  }
}
