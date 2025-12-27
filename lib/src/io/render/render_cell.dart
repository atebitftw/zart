import 'z_colors.dart';

/// A universal cell representation for rendering.
///
/// This is the unified cell type used throughout the project.
/// Both Z-machine and Glulx screen models use this directly.
class RenderCell {
  /// The character to display.
  String char;

  /// Foreground color in 0xRRGGBB format, or null for terminal default.
  int? fgColor;

  /// Background color in 0xRRGGBB format, or null for terminal default.
  int? bgColor;

  /// Whether to render in bold.
  bool bold;

  /// Whether to render in italic.
  bool italic;

  /// Whether to swap foreground/background (reverse video).
  bool reverse;

  /// Whether to use fixed-width font.
  bool fixed;

  /// Create a new RenderCell.
  RenderCell(
    this.char, {
    this.fgColor,
    this.bgColor,
    this.bold = false,
    this.italic = false,
    this.reverse = false,
    this.fixed = false,
    this.glkStyle,
    this.glkWindowType,
  });

  /// Glk style index (0-10) for this cell (Glulx only).
  int? glkStyle;

  /// Glk window type index for this cell (Glulx only).
  int? glkWindowType;

  /// An empty cell (space with default styling).
  factory RenderCell.empty() => RenderCell(' ');

  /// Create a cell with Z-machine style bitmask and color codes.
  ///
  /// Z-machine style bitmask: 1=Reverse, 2=Bold, 4=Italic, 8=Fixed
  /// Z-machine colors: 1-12 (see [ZColors])
  factory RenderCell.fromZMachine(
    String char, {
    int style = 0,
    int fgColor = 1,
    int bgColor = 1,
  }) {
    return RenderCell(
      char,
      fgColor: ZColors.toRgb(fgColor),
      bgColor: ZColors.toRgb(bgColor),
      reverse: (style & 1) != 0,
      bold: (style & 2) != 0,
      italic: (style & 4) != 0,
      fixed: (style & 8) != 0,
    );
  }

  /// Create a copy of this cell.
  RenderCell clone() => RenderCell(
    char,
    fgColor: fgColor,
    bgColor: bgColor,
    bold: bold,
    italic: italic,
    reverse: reverse,
    fixed: fixed,
    glkStyle: glkStyle,
    glkWindowType: glkWindowType,
  );

  /// Create a copy with optional overrides.
  RenderCell copyWith({
    String? char,
    int? fgColor,
    int? bgColor,
    bool? bold,
    bool? italic,
    bool? reverse,
    bool? fixed,
  }) {
    return RenderCell(
      char ?? this.char,
      fgColor: fgColor ?? this.fgColor,
      bgColor: bgColor ?? this.bgColor,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      reverse: reverse ?? this.reverse,
      fixed: fixed ?? this.fixed,
      glkStyle: glkStyle ?? this.glkStyle,
      glkWindowType: glkWindowType ?? this.glkWindowType,
    );
  }

  /// Update this cell's style from a Z-machine style bitmask.
  void setZMachineStyle(int style) {
    reverse = (style & 1) != 0;
    bold = (style & 2) != 0;
    italic = (style & 4) != 0;
    fixed = (style & 8) != 0;
  }

  /// Update this cell's colors from Z-machine color codes.
  void setZMachineColors(int fg, int bg) {
    fgColor = ZColors.toRgb(fg);
    bgColor = ZColors.toRgb(bg);
  }

  @override
  bool operator ==(Object other) =>
      other is RenderCell &&
      other.char == char &&
      other.fgColor == fgColor &&
      other.bgColor == bgColor &&
      other.bold == bold &&
      other.italic == italic &&
      other.reverse == reverse &&
      other.fixed == fixed;

  @override
  int get hashCode =>
      Object.hash(char, fgColor, bgColor, bold, italic, reverse, fixed);

  @override
  String toString() =>
      'RenderCell("$char"${bold ? ", bold" : ""}${italic ? ", italic" : ""}${reverse ? ", reverse" : ""}${fixed ? ", fixed" : ""})';
}
