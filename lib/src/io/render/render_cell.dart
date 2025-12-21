/// A universal cell representation for rendering.
///
/// Both Z-machine's [Cell] and Glulx's [GlkCell] convert to this format,
/// allowing presentation layers to be VM-agnostic.
class RenderCell {
  /// The character to display.
  final String char;

  /// Foreground color in 0xRRGGBB format, or null for terminal default.
  final int? fgColor;

  /// Background color in 0xRRGGBB format, or null for terminal default.
  final int? bgColor;

  /// Whether to render in bold.
  final bool bold;

  /// Whether to render in italic.
  final bool italic;

  /// Whether to swap foreground/background (reverse video).
  final bool reverse;

  const RenderCell(
    this.char, {
    this.fgColor,
    this.bgColor,
    this.bold = false,
    this.italic = false,
    this.reverse = false,
  });

  /// An empty cell (space with default styling).
  static const empty = RenderCell(' ');

  /// Create a copy with optional overrides.
  RenderCell copyWith({String? char, int? fgColor, int? bgColor, bool? bold, bool? italic, bool? reverse}) {
    return RenderCell(
      char ?? this.char,
      fgColor: fgColor ?? this.fgColor,
      bgColor: bgColor ?? this.bgColor,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      reverse: reverse ?? this.reverse,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RenderCell &&
      other.char == char &&
      other.fgColor == fgColor &&
      other.bgColor == bgColor &&
      other.bold == bold &&
      other.italic == italic &&
      other.reverse == reverse;

  @override
  int get hashCode => Object.hash(char, fgColor, bgColor, bold, italic, reverse);

  @override
  String toString() =>
      'RenderCell("$char"${bold ? ", bold" : ""}${italic ? ", italic" : ""}${reverse ? ", reverse" : ""})';
}
