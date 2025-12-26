import 'dart:typed_data';

import 'render_cell.dart';

/// An image to render in a graphics window.
///
/// Contains raw image bytes and positioning information for display.
class RenderImage {
  /// The resource ID this image came from.
  final int resourceId;

  /// Raw image data bytes (PNG or JPEG format).
  final Uint8List data;

  /// Image format ('PNG ' or 'JPEG').
  final String format;

  /// X position within window (pixels).
  final int x;

  /// Y position within window (pixels).
  final int y;

  /// Display width (may differ from native if scaled).
  final int width;

  /// Display height (may differ from native if scaled).
  final int height;

  const RenderImage({
    required this.resourceId,
    required this.data,
    required this.format,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

/// A window region with its cell grid for rendering.
///
/// Represents a rectangular area on screen with its content.
class RenderWindow {
  /// Unique window identifier.
  final int id;

  /// X position (column, 0-indexed).
  final int x;

  /// Y position (row, 0-indexed).
  final int y;

  /// Width in characters (for text) or pixels (for graphics).
  final int width;

  /// Height in characters (for text) or pixels (for graphics).
  final int height;

  /// Cell grid (rows x cols). May be smaller than width/height if content is sparse.
  /// Used for text windows.
  final List<List<RenderCell>> cells;

  /// Images to render in this window (for graphics windows).
  final List<RenderImage> images;

  /// True if this window is accepting input (line or character).
  final bool acceptsInput;

  /// Cursor column position within window (for text grid windows).
  final int cursorX;

  /// Cursor row position within window.
  final int cursorY;

  /// True if this is a text buffer window (scrollable).
  final bool isTextBuffer;

  /// True if this is a graphics window (pixel-based).
  final bool isGraphics;

  /// Background color for graphics windows (0xRRGGBB format).
  final int? backgroundColor;

  const RenderWindow({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.cells,
    this.images = const [],
    this.acceptsInput = false,
    this.cursorX = 0,
    this.cursorY = 0,
    this.isTextBuffer = false,
    this.isGraphics = false,
    this.backgroundColor,
  });
}

/// A complete frame ready for rendering by a presentation layer.
///
/// Contains all visible windows and their content.
class RenderFrame {
  /// All visible windows, in render order (back to front).
  final List<RenderWindow> windows;

  /// ID of the window currently focused for input, or null if none.
  final int? focusedWindowId;

  /// Total screen width in characters.
  final int screenWidth;

  /// Total screen height in characters.
  final int screenHeight;

  const RenderFrame({
    required this.windows,
    required this.screenWidth,
    required this.screenHeight,
    this.focusedWindowId,
  });

  /// Get a window by ID.
  RenderWindow? getWindow(int id) {
    for (final w in windows) {
      if (w.id == id) return w;
    }
    return null;
  }
}
