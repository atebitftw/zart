/// Platform capability descriptor.
///
/// Allows VMs to query what features the presentation layer supports.
/// Both Z-machine and Glulx games use this to adapt their output.
class PlatformCapabilities {
  // === Screen Dimensions ===

  /// Screen width in characters.
  final int screenWidth;

  /// Screen height in characters (excluding any system UI like status bars).
  final int screenHeight;

  // === Display Capabilities ===

  /// Whether the display supports color output.
  final bool supportsColors;

  /// Whether the display supports 24-bit RGB colors (true color).
  /// If false, only the standard 8-color palette is available.
  final bool supportsTrueColor;

  /// Whether the display supports bold text.
  final bool supportsBold;

  /// Whether the display supports italic text.
  final bool supportsItalic;

  /// Whether the display supports fixed-pitch (monospace) fonts.
  final bool supportsFixedPitch;

  /// Whether the display supports Unicode characters.
  final bool supportsUnicode;

  // === Rich Media ===

  /// Whether the display can show images.
  final bool supportsGraphics;

  /// Whether the platform can play sound effects.
  final bool supportsSound;

  /// Whether the platform can play music.
  final bool supportsMusic;

  // === Input Capabilities ===

  /// Whether the platform can receive mouse input.
  final bool supportsMouse;

  /// Whether the platform supports timed input (with timeout).
  final bool supportsTimedInput;

  /// Whether the platform supports single-character input.
  final bool supportsCharInput;

  // === Font Information ===

  /// Character width in pixels (for graphics-capable displays).
  final int? charWidth;

  /// Character height in pixels (for graphics-capable displays).
  final int? charHeight;

  /// Available font names, if any.
  final List<String> availableFonts;

  /// Default foreground color in 0xRRGGBB format.
  final int defaultForeground;

  /// Default background color in 0xRRGGBB format.
  final int defaultBackground;

  /// Create platform capabilities with specified values.
  const PlatformCapabilities({
    required this.screenWidth,
    required this.screenHeight,
    this.supportsColors = true,
    this.supportsTrueColor = false,
    this.supportsBold = true,
    this.supportsItalic = true,
    this.supportsFixedPitch = true,
    this.supportsUnicode = true,
    this.supportsGraphics = false,
    this.supportsSound = false,
    this.supportsMusic = false,
    this.supportsMouse = false,
    this.supportsTimedInput = true,
    this.supportsCharInput = true,
    this.charWidth,
    this.charHeight,
    this.availableFonts = const [],
    this.defaultForeground = 0xFFFFFF, // White
    this.defaultBackground = 0x000000, // Black
  });

  /// Create capabilities for a typical terminal/CLI environment.
  const PlatformCapabilities.terminal({required int width, required int height})
    : this(
        screenWidth: width,
        screenHeight: height,
        supportsColors: true,
        supportsTrueColor: true,
        supportsBold: true,
        supportsItalic: true,
        supportsFixedPitch: true,
        supportsUnicode: true,
        supportsGraphics: false,
        supportsSound: false,
        supportsMouse: true,
        supportsTimedInput: true,
      );

  /// Query Glk gestalt value for a given selector.
  ///
  /// [selector] is a Glk gestalt constant (e.g., gestalt_Version).
  /// [arg] is an optional argument for the gestalt query.
  ///
  /// Returns the gestalt result value.
  int glkGestalt(int selector, int arg) {
    // Default implementation returns 0 for unknown selectors.
    // The PlatformProvider implementation should override this for
    // full Glk gestalt support.
    return 0;
  }

  @override
  String toString() =>
      'PlatformCapabilities(${screenWidth}x$screenHeight, '
      'colors: $supportsColors, bold: $supportsBold, italic: $supportsItalic)';
}
