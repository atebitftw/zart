/// Glk window method flags for glk_window_open().
///
/// Glk Spec: "The winmethod constants" describe how windows are split.
/// The method argument combines direction, split type, and border hints.
class GlkWinmethod {
  // === Direction (bits 0-3) ===
  // Glk Spec: "winmethod_Left, Right, Above, Below"

  /// New window appears to the left of the old one.
  static const int left = 0x00;

  /// New window appears to the right of the old one.
  static const int right = 0x01;

  /// New window appears above the old one.
  static const int above = 0x02;

  /// New window appears below the old one.
  static const int below = 0x03;

  /// Mask to extract direction from method.
  static const int dirMask = 0x0F;

  // === Split Type (bits 4-5) ===
  // Glk Spec: "winmethod_Fixed, Proportional"

  /// The size is a fixed number of rows/columns.
  static const int fixed = 0x10;

  /// The size is a percentage of the split window.
  static const int proportional = 0x20;

  /// Mask to extract division type from method.
  static const int divisionMask = 0xF0;

  // === Border Hint (bit 8) ===
  // Glk Spec: "winmethod_Border, NoBorder"

  /// Draw a visible border between windows (default).
  static const int border = 0x000;

  /// Do not draw a border between windows.
  static const int noBorder = 0x100;

  /// Mask to extract border setting from method.
  static const int borderMask = 0x100;

  /// Helper to check if direction is horizontal (left/right).
  static bool isHorizontal(int method) {
    final dir = method & dirMask;
    return dir == left || dir == right;
  }

  /// Helper to check if direction is vertical (above/below).
  static bool isVertical(int method) {
    final dir = method & dirMask;
    return dir == above || dir == below;
  }

  /// Helper to check if split is fixed size.
  static bool isFixed(int method) => (method & divisionMask) == fixed;

  /// Helper to check if split is proportional.
  static bool isProportional(int method) =>
      (method & divisionMask) == proportional;

  /// Helper to check if border should be drawn.
  static bool hasBorder(int method) => (method & borderMask) == border;
}
