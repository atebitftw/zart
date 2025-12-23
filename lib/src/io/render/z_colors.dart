/// Z-Machine color code to RGB conversion utilities.
///
/// Z-Machine uses color codes 1-12 for foreground and background colors.
/// This file provides conversion to RGB format (0xRRGGBB) for unified rendering.
///
/// Standard Z-Machine color palette.
///
/// These RGB values are commonly used interpretations of the Z-Machine colors.
/// Implementers may customize these, but these defaults provide good contrast.
abstract final class ZColors {
  /// Default color (terminal default) - returns null
  static const int defaultColor = 1;

  /// Z-Machine color code to RGB mapping.
  ///
  /// Returns null for default color (code 1), RGB value for others.
  static int? toRgb(int zColor) {
    return switch (zColor) {
      1 => null, // Default - let terminal decide
      2 => 0x000000, // Black
      3 => 0xCC0000, // Red
      4 => 0x00CC00, // Green
      5 => 0xCCCC00, // Yellow
      6 => 0x0000CC, // Blue
      7 => 0xCC00CC, // Magenta
      8 => 0x00CCCC, // Cyan
      9 => 0xFFFFFF, // White
      10 => 0x444444, // Dark Grey (matches zart bar background)
      11 => 0x808080, // Medium Grey
      12 => 0xC0C0C0, // Light Grey
      _ => null, // Unknown - treat as default
    };
  }

  /// Color names for debugging/logging.
  static const List<String> names = [
    'Invalid', // 0 - not used
    'Default', // 1
    'Black', // 2
    'Red', // 3
    'Green', // 4
    'Yellow', // 5
    'Blue', // 6
    'Magenta', // 7
    'Cyan', // 8
    'White', // 9
    'Dark Grey', // 10
    'Medium Grey', // 11
    'Light Grey', // 12
  ];

  /// Get color name for debugging.
  static String name(int zColor) {
    if (zColor < 0 || zColor >= names.length) return 'Unknown';
    return names[zColor];
  }
}
