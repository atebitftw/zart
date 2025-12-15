/// A single cell which represents a character in the [ScreenModel].
class Cell {
  /// The character in the cell.
  String char;

  /// The foreground color (1-9).
  int fg;

  /// The background color (1-9).
  int bg;

  /// The style of the cell (bitmask: 1=Reverse, 2=Bold, 4=Italic, 8=Fixed).
  int style;

  /// Creates a new cell.
  Cell(this.char, {this.fg = 1, this.bg = 1, this.style = 0});

  /// Creates an empty cell.
  factory Cell.empty() => Cell(' ');

  /// Creates a clone of this cell.
  Cell clone() => Cell(char, fg: fg, bg: bg, style: style);

  @override
  String toString() => char;
}
