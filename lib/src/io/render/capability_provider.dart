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

/// Mixin providing default capability values for terminal renderers.
mixin TerminalCapabilities implements CapabilityProvider {
  @override
  bool get supportsColors => true;

  @override
  bool get supportsBold => true;

  @override
  bool get supportsItalic => true;

  @override
  bool get supportsUnicode => true;

  @override
  bool get supportsGraphics => false;

  @override
  bool get supportsSound => false;

  @override
  int glkGestalt(int selector, int arg) => 0;

  @override
  int zMachineCapabilities() {
    int flags = 0;
    if (supportsColors) flags |= 0x01;
    if (supportsBold) flags |= 0x04;
    if (supportsItalic) flags |= 0x08;
    return flags;
  }
}
