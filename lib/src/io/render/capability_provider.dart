/// Interface for presentation layers to report their capabilities.
///
/// Both Z-machine and Glulx VMs query this to adapt their output.
/// CLI, Web, and Flutter implementations would provide different capabilities.
abstract class CapabilityProvider {
  /// Screen width in characters.
  int get screenWidth;

  /// Screen height in characters.
  int get screenHeight;

  /// Whether the display supports colors.
  bool get supportsColors;

  /// Whether the display supports bold text.
  bool get supportsBold;

  /// Whether the display supports italic text.
  bool get supportsItalic;

  /// Whether the display supports Unicode characters.
  bool get supportsUnicode;

  /// Whether the display supports graphics (images).
  bool get supportsGraphics;

  /// Whether the display supports sound.
  bool get supportsSound;

  /// Query Glk-specific capabilities (gestalt).
  ///
  /// Returns 0 for unknown selectors by default.
  /// Glulx games use this to check for specific features.
  int glkGestalt(int selector, int arg);

  /// Query Z-machine specific capabilities.
  ///
  /// Returns capability flags for the Z-machine header.
  int zMachineCapabilities();
}
