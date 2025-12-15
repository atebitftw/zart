/// A single cell which represents a character in the [ScreenModel].
class Cell {
  /// The character in the cell.
  String char;

  /// The foreground color (1-10).
  /// The colors are:
  /// | Code | Color        |
  /// |------|--------------|
  /// | 1    | Default      |
  /// | 2    | Black        |
  /// | 3    | Red          |
  /// | 4    | Green        |
  /// | 5    | Yellow       |
  /// | 6    | Blue         |
  /// | 7    | Magenta      |
  /// | 8    | Cyan         |
  /// | 9    | White        |
  /// | 10   | Light Grey   |
  /// | 11   | Medium Grey  |
  /// | 12   | Dark Grey    |
  int fg;

  /// The background color (1-12).
  /// The colors are:
  /// | Code | Color        |
  /// |------|--------------|
  /// | 1    | Default      |
  /// | 2    | Black        |
  /// | 3    | Red          |
  /// | 4    | Green        |
  /// | 5    | Yellow       |
  /// | 6    | Blue         |
  /// | 7    | Magenta      |
  /// | 8    | Cyan         |
  /// | 9    | White        |
  /// | 10   | Light Grey   |
  /// | 11   | Medium Grey  |
  /// | 12   | Dark Grey    |
  int bg;

  /// The style of the cell.
  ///
  /// The styles are:
  /// | Code | Style        |
  /// |------|--------------|
  /// | 1    | Reverse      |
  /// | 2    | Bold         |
  /// | 4    | Italic       |
  /// | 8    | Fixed        |
  int style;

  /// Creates a new cell.
  Cell(this.char, {this.fg = 1, this.bg = 2, this.style = 0});

  /// Creates an empty cell.
  factory Cell.empty() => Cell(' ');

  /// Creates a clone of this cell.
  Cell clone() => Cell(char, fg: fg, bg: bg, style: style);

  @override
  String toString() => char;
}
