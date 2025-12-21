import 'glk_cell.dart';
import 'glk_styles.dart';
import 'glk_window.dart';
import 'glk_winmethod.dart';
import '../render/render_cell.dart';
import '../render/render_frame.dart';

/// Info about a window for rendering.
class GlkWindowRenderInfo {
  /// Window ID.
  final int windowId;

  /// Window type.
  final GlkWindowType type;

  /// Position on screen (in chars), X coordinate.
  final int x;

  /// Position on screen (in chars), Y coordinate.
  final int y;

  /// Width in chars.
  final int width;

  /// Height in chars.
  final int height;

  GlkWindowRenderInfo({
    required this.windowId,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

/// Screen Model for the Zart Glulx/Glk interpreter.
///
/// Manages the Glk window tree and provides a Cell-based abstraction
/// for any player app (CLI, Flutter, Web) to render.
///
/// Glk Spec: "The Glk screen space is a rectangle, which you can divide
/// into panels for various purposes."
class GlkScreenModel {
  // === Screen Dimensions ===

  /// Screen width in characters.
  int screenCols = 80;

  /// Screen height in characters.
  int screenRows = 24;

  // === Window Tree ===

  /// Root of the window tree.
  GlkWindow? _rootWindow;

  /// Map of window ID to window object.
  final Map<int, GlkWindow> _windowsById = {};

  /// Next window ID to assign.
  int _nextWindowId = 1;

  // === API: Window Management ===

  /// Create a new window by splitting an existing one.
  ///
  /// If [splitFromId] is null, creates the root window.
  /// Returns window ID or null if creation failed.
  ///
  /// Glk Spec: "glk_window_open() [creates windows] by splitting existing ones."
  int? windowOpen(
    int? splitFromId,
    int method,
    int size,
    GlkWindowType type,
    int rock,
  ) {
    // Validate - can't create pair windows directly.
    if (type == GlkWindowType.pair) {
      return null;
    }

    final newId = _nextWindowId++;
    GlkWindow newWindow;

    // Create the new window based on type.
    switch (type) {
      case GlkWindowType.textBuffer:
        newWindow = GlkTextBufferWindow(id: newId, rock: rock);
      case GlkWindowType.textGrid:
        newWindow = GlkTextGridWindow(id: newId, rock: rock);
      case GlkWindowType.graphics:
        newWindow = GlkGraphicsWindow(id: newId, rock: rock);
      case GlkWindowType.blank:
        newWindow = GlkBlankWindow(id: newId, rock: rock);
      case GlkWindowType.pair:
        return null; // Already checked above.
    }

    // If no existing window, this becomes the root.
    if (splitFromId == null || _rootWindow == null) {
      _rootWindow = newWindow;
      _windowsById[newId] = newWindow;
      recalculateLayout();
      return newId;
    }

    // Find the window to split.
    final splitFrom = _windowsById[splitFromId];
    if (splitFrom == null) {
      return null;
    }

    // Create a pair window to contain both.
    final pairId = _nextWindowId++;
    final pairWindow = GlkPairWindow(id: pairId, rock: 0);
    pairWindow.method = method;
    pairWindow.size = size;
    pairWindow.child1 = splitFrom;
    pairWindow.child2 = newWindow;
    pairWindow.keyWindow = newWindow; // New window is the key for size.

    // Update parent pointers.
    final oldParent = splitFrom.parent;
    pairWindow.parent = oldParent;
    splitFrom.parent = pairWindow;
    newWindow.parent = pairWindow;

    // Update parent's child pointer or root.
    if (oldParent == null) {
      _rootWindow = pairWindow;
    } else if (oldParent is GlkPairWindow) {
      if (oldParent.child1 == splitFrom) {
        oldParent.child1 = pairWindow;
      } else {
        oldParent.child2 = pairWindow;
      }
    }

    _windowsById[newId] = newWindow;
    _windowsById[pairId] = pairWindow;

    recalculateLayout();
    return newId;
  }

  /// Close a window.
  ///
  /// Glk Spec: "glk_window_close() closes a window."
  void windowClose(int windowId) {
    final window = _windowsById[windowId];
    if (window == null) return;

    // If closing root, clear everything.
    if (window == _rootWindow) {
      _rootWindow = null;
      _windowsById.clear();
      return;
    }

    final parent = window.parent;
    if (parent is! GlkPairWindow) return;

    // Find the sibling.
    final sibling = parent.child1 == window ? parent.child2 : parent.child1;
    if (sibling == null) return;

    // Replace parent with sibling in grandparent.
    final grandparent = parent.parent;
    sibling.parent = grandparent;

    if (grandparent == null) {
      _rootWindow = sibling;
    } else if (grandparent is GlkPairWindow) {
      if (grandparent.child1 == parent) {
        grandparent.child1 = sibling;
      } else {
        grandparent.child2 = sibling;
      }
    }

    // Remove closed window and pair from map.
    _windowsById.remove(windowId);
    _windowsById.remove(parent.id);

    recalculateLayout();
  }

  /// Get window size.
  ///
  /// Glk Spec: "glk_window_get_size() returns the actual size."
  (int width, int height) windowGetSize(int windowId) {
    final window = _windowsById[windowId];
    if (window == null) return (0, 0);
    return (window.width, window.height);
  }

  /// Set the arrangement of a pair window.
  ///
  /// Glk Spec: "glk_window_set_arrangement() changes the size of a window
  /// (and the constraint that defines that size)."
  ///
  /// This is called on a **pair window** to change how its children are split.
  /// The [keyWindowId] identifies which child's size is being constrained.
  void windowSetArrangement(
    int pairWindowId,
    int method,
    int size,
    int keyWindowId,
  ) {
    final window = _windowsById[pairWindowId];
    if (window is! GlkPairWindow) {
      return;
    }

    window.method = method;
    window.size = size;
    if (keyWindowId != 0) {
      window.keyWindow = _windowsById[keyWindowId];
    }

    recalculateLayout();
  }

  /// Move cursor in a text grid window.
  ///
  /// Glk Spec: "glk_window_move_cursor() sets cursor position."
  void windowMoveCursor(int windowId, int x, int y) {
    final window = _windowsById[windowId];
    if (window is GlkTextGridWindow) {
      window.moveCursor(x, y);
    }
  }

  /// Clear a window.
  ///
  /// Glk Spec: "glk_window_clear() clears a window."
  void windowClear(int windowId) {
    final window = _windowsById[windowId];
    if (window is GlkTextBufferWindow) {
      window.clear();
    } else if (window is GlkTextGridWindow) {
      window.clear();
    } else if (window is GlkGraphicsWindow) {
      window.clear();
    }
  }

  /// Get a window by ID.
  GlkWindow? getWindow(int windowId) => _windowsById[windowId];

  /// Get the root window.
  GlkWindow? get rootWindow => _rootWindow;

  // === API: Output ===

  /// Print text to a window.
  ///
  /// For text buffers, appends to end. For text grids, writes at cursor.
  void putString(int windowId, String text) {
    final window = _windowsById[windowId];
    if (window == null) return;

    if (window is GlkTextBufferWindow) {
      _putStringBuffer(window, text);
    } else if (window is GlkTextGridWindow) {
      _putStringGrid(window, text);
    }
  }

  void _putStringBuffer(GlkTextBufferWindow window, String text) {
    for (final char in text.runes) {
      if (char == 10) {
        // Explicit newline from game.
        window.newLine();
      } else {
        // Add the character to current line
        window.currentLine.add(
          GlkCell(String.fromCharCode(char), style: window.style),
        );

        // Check if we need to wrap (line exceeds window width)
        if (window.width > 0 && window.currentLine.length >= window.width) {
          // Find the last space for word-boundary wrap
          int lastSpace = -1;
          for (int i = window.currentLine.length - 1; i >= 0; i--) {
            if (window.currentLine[i].char == ' ') {
              lastSpace = i;
              break;
            }
          }

          if (lastSpace > 0) {
            // Word wrap: move characters after the space to the next line
            final overflow = window.currentLine.sublist(lastSpace + 1);
            window.currentLine.removeRange(
              lastSpace,
              window.currentLine.length,
            );
            window.newLine();
            window.currentLine.addAll(overflow);
          } else {
            // No space found - hard break at width
            window.newLine();
          }
        }
      }
    }
  }

  void _putStringGrid(GlkTextGridWindow window, String text) {
    for (final char in text.runes) {
      if (char == 10) {
        // Newline - move to start of next row.
        window.cursorX = 0;
        window.cursorY++;
        if (window.cursorY >= window.height) {
          window.cursorY = window.height - 1;
        }
      } else if (window.cursorY < window.height &&
          window.cursorX < window.width) {
        window.grid[window.cursorY][window.cursorX] = GlkCell(
          String.fromCharCode(char),
          style: window.style,
        );
        window.cursorX++;
        if (window.cursorX >= window.width) {
          window.cursorX = 0;
          window.cursorY++;
          if (window.cursorY >= window.height) {
            window.cursorY = window.height - 1;
          }
        }
      }
    }
  }

  /// Set current style for a window.
  void setStyle(int windowId, int style) {
    final window = _windowsById[windowId];
    if (window != null) {
      window.style = style.clamp(0, GlkStyle.count - 1);
    }
  }

  // === API: Input State ===

  /// Request line input from a window.
  void requestLineEvent(int windowId, int bufferAddr, int maxLen) {
    final window = _windowsById[windowId];
    if (window != null) {
      window.lineInputPending = true;
      window.lineInputBufferAddr = bufferAddr;
      window.lineInputMaxLen = maxLen;
      updateFocus();
    }
  }

  /// Cancel pending line input.
  void cancelLineEvent(int windowId) {
    final window = _windowsById[windowId];
    if (window != null) {
      window.lineInputPending = false;
      updateFocus();
    }
  }

  /// Request character input from a window.
  void requestCharEvent(int windowId) {
    final window = _windowsById[windowId];
    if (window != null) {
      window.charInputPending = true;
      updateFocus();
    }
  }

  /// Cancel pending character input.
  void cancelCharEvent(int windowId) {
    final window = _windowsById[windowId];
    if (window != null) {
      window.charInputPending = false;
      updateFocus();
    }
  }

  /// Request mouse input from a window.
  void requestMouseEvent(int windowId) {
    final window = _windowsById[windowId];
    if (window != null) {
      window.mouseInputPending = true;
    }
  }

  /// Cancel pending mouse input.
  void cancelMouseEvent(int windowId) {
    final window = _windowsById[windowId];
    if (window != null) {
      window.mouseInputPending = false;
    }
  }

  /// Get all windows with pending input requests.
  ///
  /// Returns list of window IDs.
  List<int> getWindowsAwaitingInput() {
    return _windowsById.values
        .where(
          (w) =>
              w.lineInputPending || w.charInputPending || w.mouseInputPending,
        )
        .map((w) => w.id)
        .toList();
  }

  // === API: Focus Management ===

  /// Currently focused window ID (for input).
  /// The presentation layer uses this to show focus indicators.
  int? focusedWindowId;

  /// Update focus to a valid window awaiting input.
  /// Call this after input requests change.
  void updateFocus() {
    final awaiting = getWindowsAwaitingInput();
    if (awaiting.isEmpty) {
      focusedWindowId = null;
    } else if (focusedWindowId == null || !awaiting.contains(focusedWindowId)) {
      // Focus first window awaiting input.
      focusedWindowId = awaiting.first;
    }
  }

  /// Cycle focus to the next window awaiting input.
  /// Returns true if focus changed.
  bool cycleFocus() {
    final awaiting = getWindowsAwaitingInput();
    if (awaiting.length <= 1) return false;

    final currentIndex = awaiting.indexOf(focusedWindowId ?? -1);
    final nextIndex = (currentIndex + 1) % awaiting.length;
    focusedWindowId = awaiting[nextIndex];
    return true;
  }

  /// Check if a window is currently focused.
  bool isFocused(int windowId) => focusedWindowId == windowId;

  // === API: Rendering ===

  /// Get all visible windows in render order (depth-first tree traversal).
  List<GlkWindowRenderInfo> getVisibleWindows() {
    final result = <GlkWindowRenderInfo>[];
    if (_rootWindow != null) {
      _collectVisibleWindows(_rootWindow!, result);
    }
    return result;
  }

  void _collectVisibleWindows(GlkWindow window, List<GlkWindowRenderInfo> out) {
    if (window is GlkPairWindow) {
      if (window.child1 != null) _collectVisibleWindows(window.child1!, out);
      if (window.child2 != null) _collectVisibleWindows(window.child2!, out);
    } else {
      out.add(
        GlkWindowRenderInfo(
          windowId: window.id,
          type: window.type,
          x: window.screenX,
          y: window.screenY,
          width: window.width,
          height: window.height,
        ),
      );
    }
  }

  /// Get the cell grid for a text grid window.
  List<List<GlkCell>>? getTextGridCells(int windowId) {
    final window = _windowsById[windowId];
    if (window is GlkTextGridWindow) {
      return window.grid;
    }
    return null;
  }

  /// Get the line buffer for a text buffer window.
  List<List<GlkCell>>? getTextBufferLines(int windowId) {
    final window = _windowsById[windowId];
    if (window is GlkTextBufferWindow) {
      return window.lines;
    }
    return null;
  }

  // === Screen Layout ===

  /// Recalculate all window sizes after screen resize or window changes.
  void recalculateLayout() {
    if (_rootWindow == null) return;
    _layoutWindow(_rootWindow!, 0, 0, screenCols, screenRows);
  }

  void _layoutWindow(GlkWindow window, int x, int y, int width, int height) {
    window.screenX = x;
    window.screenY = y;
    window.width = width;
    window.height = height;

    if (window is GlkPairWindow) {
      _layoutPairWindow(window, x, y, width, height);
    } else if (window is GlkTextGridWindow) {
      window.resize(width, height);
    }
  }

  void _layoutPairWindow(GlkPairWindow pair, int x, int y, int w, int h) {
    if (pair.child1 == null || pair.child2 == null) return;

    final isHorizontal = GlkWinmethod.isHorizontal(pair.method);
    final totalSize = isHorizontal ? w : h;

    // Calculate size for the key window (child2).
    int keySize;
    if (GlkWinmethod.isFixed(pair.method)) {
      keySize = pair.size;
    } else {
      keySize = (totalSize * pair.size) ~/ 100;
    }
    keySize = keySize.clamp(0, totalSize);
    final otherSize = totalSize - keySize;

    final dir = pair.method & GlkWinmethod.dirMask;
    switch (dir) {
      case GlkWinmethod.left:
        _layoutWindow(pair.child2!, x, y, keySize, h);
        _layoutWindow(pair.child1!, x + keySize, y, otherSize, h);
      case GlkWinmethod.right:
        _layoutWindow(pair.child1!, x, y, otherSize, h);
        _layoutWindow(pair.child2!, x + otherSize, y, keySize, h);
      case GlkWinmethod.above:
        _layoutWindow(pair.child2!, x, y, w, keySize);
        _layoutWindow(pair.child1!, x, y + keySize, w, otherSize);
      case GlkWinmethod.below:
        _layoutWindow(pair.child1!, x, y, w, otherSize);
        _layoutWindow(pair.child2!, x, y + otherSize, w, keySize);
    }
  }

  /// Set screen dimensions and recalculate layout.
  void setScreenSize(int cols, int rows) {
    screenCols = cols;
    screenRows = rows;
    recalculateLayout();
  }

  // === Unified Rendering API ===

  /// Convert a GlkCell to a RenderCell.
  RenderCell _cellToRenderCell(GlkCell cell) {
    // Map Glk styles to bold/italic flags
    bool bold = false;
    bool italic = false;

    switch (cell.style) {
      case GlkStyle.header:
      case GlkStyle.subheader:
      case GlkStyle.input:
        bold = true;
      case GlkStyle.emphasized:
      case GlkStyle.note:
        italic = true;
      case GlkStyle.alert:
        bold = true;
    }

    return RenderCell(
      cell.char,
      fgColor: cell.fgColor,
      bgColor: cell.bgColor,
      bold: bold,
      italic: italic,
      reverse: false, // Glk doesn't have reverse video style
    );
  }

  /// Convert the screen state to a RenderFrame for unified rendering.
  ///
  /// Returns all visible Glk windows converted to RenderWindows.
  RenderFrame toRenderFrame() {
    final windows = <RenderWindow>[];
    final awaitingInput = getWindowsAwaitingInput();
    int? focusedId;

    for (final info in getVisibleWindows()) {
      final window = _windowsById[info.windowId];
      if (window == null) continue;

      final cells = <List<RenderCell>>[];
      final acceptsInput = awaitingInput.contains(info.windowId);
      if (acceptsInput) focusedId = info.windowId;

      int cursorX = 0, cursorY = 0;

      if (window is GlkTextGridWindow) {
        for (final row in window.grid) {
          cells.add(row.map(_cellToRenderCell).toList());
        }
        cursorX = window.cursorX;
        cursorY = window.cursorY;
      } else if (window is GlkTextBufferWindow) {
        for (final line in window.lines) {
          cells.add(line.map(_cellToRenderCell).toList());
        }
        // Cursor at end of last line
        if (window.lines.isNotEmpty) {
          cursorY = window.lines.length - 1;
          cursorX = window.lines.last.length;
        }
      }
      // Blank and graphics windows emit empty cells (already handled)

      windows.add(
        RenderWindow(
          id: info.windowId,
          x: info.x,
          y: info.y,
          width: info.width,
          height: info.height,
          cells: cells,
          acceptsInput: acceptsInput,
          cursorX: cursorX,
          cursorY: cursorY,
          isTextBuffer: window is GlkTextBufferWindow,
        ),
      );
    }

    return RenderFrame(
      windows: windows,
      screenWidth: screenCols,
      screenHeight: screenRows,
      focusedWindowId: focusedId,
    );
  }
}
