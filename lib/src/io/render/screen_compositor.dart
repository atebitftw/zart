import 'render_cell.dart';
import 'render_frame.dart';
import 'screen_frame.dart';

/// Composites a [RenderFrame] into a flat [ScreenFrame].
///
/// This utility extracts window composition logic from presentation layers,
/// providing a single flat grid that can be rendered directly to any display.
///
/// The compositor manages:
/// - Window-to-screen coordinate mapping
/// - Scroll offset for text buffer windows
/// - Cursor position tracking
/// - Scrollbar rendering for scrollable windows
class ScreenCompositor {
  /// Current scroll offset (0 = at bottom, positive = scrolled up).
  int _scrollOffset = 0;

  /// Get current scroll offset.
  int get scrollOffset => _scrollOffset;

  /// Scroll by the specified number of lines.
  ///
  /// Positive values scroll up (back in history), negative values scroll down.
  /// The actual offset is clamped during composition based on content size.
  void scroll(int lines) {
    _scrollOffset += lines;
    if (_scrollOffset < 0) _scrollOffset = 0;
  }

  /// Reset scroll offset to bottom.
  void scrollToBottom() {
    _scrollOffset = 0;
  }

  /// Set scroll offset directly.
  void setScrollOffset(int offset) {
    _scrollOffset = offset < 0 ? 0 : offset;
  }

  /// Composite a [RenderFrame] into a flat [ScreenFrame].
  ///
  /// The [screenWidth] and [screenHeight] parameters specify the current
  /// display dimensions. These should be queried from the platform before
  /// each render to handle window resizing.
  ///
  /// The returned [ScreenFrame] contains:
  /// - A flat grid of cells ready for direct rendering
  /// - Cursor position in screen coordinates
  ScreenFrame composite(RenderFrame frame, {required int screenWidth, required int screenHeight}) {
    // Create the screen buffer
    final screen = List.generate(screenHeight, (_) => List.generate(screenWidth, (_) => RenderCell.empty()));

    // Track cursor position
    int cursorX = -1;
    int cursorY = -1;
    bool cursorVisible = false;

    // Composite each window onto the screen buffer
    for (final window in frame.windows) {
      final isFocused = frame.focusedWindowId == window.id;
      final result = _compositeWindow(screen, window, isFocused, screenWidth, screenHeight);

      // Track cursor from focused window
      if (result.cursorVisible) {
        cursorX = result.cursorX;
        cursorY = result.cursorY;
        cursorVisible = true;
      }
    }

    return ScreenFrame(
      cells: screen,
      width: screenWidth,
      height: screenHeight,
      cursorX: cursorX,
      cursorY: cursorY,
      cursorVisible: cursorVisible,
    );
  }

  /// Composite a single window onto the screen buffer.
  ///
  /// Returns cursor information if this window is focused and accepts input.
  _CursorInfo _compositeWindow(
    List<List<RenderCell>> screen,
    RenderWindow window,
    bool isFocused,
    int screenWidth,
    int screenHeight,
  ) {
    var cursorInfo = _CursorInfo();

    // Determine which rows of content to show (for buffer windows with scroll)
    int contentStartRow = 0;
    int maxScroll = 0;
    int effectiveOffset = 0;

    if (window.cells.length > window.height) {
      // Scrollable content
      maxScroll = window.cells.length - window.height;
      effectiveOffset = _scrollOffset.clamp(0, maxScroll);
      contentStartRow = maxScroll - effectiveOffset;
    }

    // Copy window cells to screen buffer
    for (var row = 0; row < window.height; row++) {
      final screenRow = window.y + row;
      if (screenRow >= screenHeight) break;
      if (screenRow < 0) continue;

      final contentRow = contentStartRow + row;
      if (contentRow >= 0 && contentRow < window.cells.length) {
        for (var col = 0; col < window.width && col < window.cells[contentRow].length; col++) {
          final screenCol = window.x + col;
          if (screenCol >= screenWidth) break;
          if (screenCol < 0) continue;
          screen[screenRow][screenCol] = window.cells[contentRow][col];
        }
      }
    }

    // Track cursor position for focused window
    if (isFocused && window.acceptsInput) {
      final cursorContentRow = window.cursorY;
      final relativeRow = cursorContentRow - contentStartRow;
      if (relativeRow >= 0 && relativeRow < window.height) {
        cursorInfo.cursorY = window.y + relativeRow;
        cursorInfo.cursorX = window.x + window.cursorX;
        if (cursorInfo.cursorX >= window.x + window.width) {
          cursorInfo.cursorX = window.x + window.width - 1;
        }
        // Only show cursor if we're at the bottom (not scrolled up)
        cursorInfo.cursorVisible = _scrollOffset == 0;
      }
    }

    // Draw scrollbar for text buffer windows with scrollable content
    if (window.isTextBuffer && window.cells.length > window.height && window.width > 1) {
      _drawScrollbar(screen, window, maxScroll, effectiveOffset, screenWidth, screenHeight);
    }

    return cursorInfo;
  }

  /// Draw a scrollbar for a window with scrollable content.
  void _drawScrollbar(
    List<List<RenderCell>> screen,
    RenderWindow window,
    int maxScroll,
    int effectiveOffset,
    int screenWidth,
    int screenHeight,
  ) {
    final totalLines = window.cells.length;
    final visibleHeight = window.height;

    // Proportion-based thumb height (at least 1 cell)
    final thumbHeight = ((visibleHeight / totalLines) * visibleHeight).round().clamp(1, visibleHeight);

    // Positioning: scrollOffset=0 is bottom, scrollOffset=maxScroll is top
    final scrollRatio = maxScroll > 0 ? effectiveOffset / maxScroll : 0.0;
    final thumbTop = ((1.0 - scrollRatio) * (visibleHeight - thumbHeight)).round();

    final scrollBarCol = window.x + window.width - 1;
    for (var row = 0; row < visibleHeight; row++) {
      final screenRow = window.y + row;
      if (screenRow >= screenHeight || screenRow < 0) continue;
      if (scrollBarCol >= screenWidth || scrollBarCol < 0) continue;

      // Draw scrollbar: thumb is bright, track is dim
      final isThumb = row >= thumbTop && row < (thumbTop + thumbHeight);
      screen[screenRow][scrollBarCol] = RenderCell(
        isThumb ? '█' : '│',
        fgColor: isThumb ? 0xFFFFFF : 0x444444, // White thumb, grey track
        bgColor: 0x000000,
      );
    }
  }
}

/// Internal helper to track cursor information from window composition.
class _CursorInfo {
  int cursorX = -1;
  int cursorY = -1;
  bool cursorVisible = false;
}
