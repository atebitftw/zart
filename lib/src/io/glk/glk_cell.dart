import 'glk_styles.dart';

/// A single character cell for Glk windows.
///
/// Unlike Z-machine Cell which uses color codes (1-12), GlkCell uses
/// Glk style indices (0-10) with optional RGB color overrides from stylehints.
///
/// Glk Spec: Styles are used "to indicate the meaning of text, not the way
/// it should look." The presentation layer maps styles to actual formatting.
class GlkCell {
  /// The character to display.
  String char;

  /// Glk style index (0-10): Normal, Emphasized, Preformatted, etc.
  /// See [GlkStyle] for constants.
  int style;

  /// Optional foreground color override from stylehints (0x00RRGGBB format).
  /// If null, use the default color for the style.
  int? fgColor;

  /// Optional background color override from stylehints (0x00RRGGBB format).
  /// If null, use the default color for the style.
  int? bgColor;

  /// Create a cell with a character and optional style/color.
  GlkCell(this.char, {this.style = GlkStyle.normal, this.fgColor, this.bgColor});

  /// Create an empty (space) cell with default style.
  GlkCell.empty() : char = ' ', style = GlkStyle.normal, fgColor = null, bgColor = null;

  /// Create a copy of this cell.
  GlkCell clone() => GlkCell(char, style: style, fgColor: fgColor, bgColor: bgColor);

  @override
  bool operator ==(Object other) =>
      other is GlkCell &&
      other.char == char &&
      other.style == style &&
      other.fgColor == fgColor &&
      other.bgColor == bgColor;

  @override
  int get hashCode => Object.hash(char, style, fgColor, bgColor);

  @override
  String toString() =>
      'GlkCell("$char", style: ${GlkStyle.names[style]}${fgColor != null ? ", fg: 0x${fgColor!.toRadixString(16)}" : ""}${bgColor != null ? ", bg: 0x${bgColor!.toRadixString(16)}" : ""})';
}
