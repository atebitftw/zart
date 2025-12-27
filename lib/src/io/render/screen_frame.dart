import 'render_cell.dart';

/// A composited screen frame ready for direct rendering.
///
/// This represents the final output of the [ScreenCompositor] - a flat grid
/// of cells that can be rendered directly to any display without further
/// composition logic.
///
/// Unlike [RenderFrame] which contains a list of windows that need to be
/// composited, `ScreenFrame` is the result of that composition - a simple
/// 2D grid with cursor position.
class ScreenFrame {
  /// The composited cell grid (rows x cols).
  ///
  /// Access as `cells[row][col]`. Each cell contains the character and
  /// styling information ready for display.
  final List<List<RenderCell>> cells;

  /// Screen width in characters.
  final int width;

  /// Screen height in characters.
  final int height;

  /// Cursor X position (column, 0-indexed), or -1 if cursor is not visible.
  final int cursorX;

  /// Cursor Y position (row, 0-indexed), or -1 if cursor is not visible.
  final int cursorY;

  /// Whether the cursor should be displayed.
  final bool cursorVisible;

  /// Whether to hide any platform-specific status bar when rendering this frame.
  ///
  /// Platforms that have status bars (e.g., CLI with Zart bar) should check
  /// this flag and suppress the status bar when true.
  final bool hideStatusBar;

  /// Create a new ScreenFrame.
  const ScreenFrame({
    required this.cells,
    required this.width,
    required this.height,
    this.cursorX = -1,
    this.cursorY = -1,
    this.cursorVisible = false,
    this.hideStatusBar = false,
  });

  /// Create an empty screen frame filled with empty cells.
  factory ScreenFrame.empty(int width, int height) {
    return ScreenFrame(
      cells: List.generate(
        height,
        (_) => List.generate(width, (_) => RenderCell.empty()),
      ),
      width: width,
      height: height,
    );
  }

  /// Get a cell at the given position, or null if out of bounds.
  RenderCell? getCell(int row, int col) {
    if (row < 0 || row >= height || col < 0 || col >= width) return null;
    if (row >= cells.length) return null;
    if (col >= cells[row].length) return null;
    return cells[row][col];
  }
}
