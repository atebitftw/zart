import 'dart:math';
import 'package:logging/logging.dart';

final _log = Logger('ScreenModel');

/// A single cell in the terminal grid styling.
class Cell {
  /// The character in the cell.
  String char;

  /// The foreground color (1-9).
  int fg;

  /// The background color (1-9).
  int bg;

  /// The style of the cell (bitmask: 1=Reverse, 2=Bold, 4=Italic, 8=Fixed).
  int style;

  /// Creates a new cell.
  Cell(this.char, {this.fg = 1, this.bg = 1, this.style = 0});

  /// Creates an empty cell.
  factory Cell.empty() => Cell(' ');

  /// Creates a clone of this cell.
  Cell clone() => Cell(char, fg: fg, bg: bg, style: style);

  @override
  String toString() => char;
}

/// A reusable model of a Z-Machine screen with two windows.
///
/// - Window 1 (Upper): Mixed text/graphics grid, fixed height.
/// - Window 0 (Lower): Buffered text stream, scrolling history.
class ScreenModel {
  /// The number of columns in the screen.
  int cols;

  /// The number of rows in the screen.
  int rows;

  /// The grid for Window 1 (upper/status window) content.
  /// Grid is [row][col]
  List<List<Cell>> _window1Grid = [];

  /// The effective visible height of Window 1.
  int _window1Height = 0;

  /// The height explicitly requested by splitWindow.
  int _requestedHeight = 0;

  /// The maximum row index that contains content (written to).
  int _contentHeight = 0;

  /// Recomputes the effective window height based on request and content.
  void _recomputeEffectiveHeight() {
    final newHeight = max(_requestedHeight, _contentHeight);
    if (newHeight != _window1Height) {
      _log.info(
        'Auto-sizing Window 1: Requested $_requestedHeight, Content $_contentHeight -> Effective $newHeight',
      );
      _window1Height = newHeight;
      _ensureGridRows(_window1Height);
    }
  }

  /// The grid for Window 0 (lower/main window) scroll buffer.
  final List<List<Cell>> _window0Grid = [];

  /// The maximum number of lines to keep in the scroll buffer.
  int maxScrollback = 1000;

  /// The cursor position for Window 1 (1-indexed as per Z-Machine).
  int _cursorRow = 1;
  int _cursorCol = 1;

  /// The current text style (bitmask: 1=Reverse, 2=Bold, 4=Italic, 8=Fixed).
  int currentStyle = 0;

  /// The current foreground color (1-9).
  int fgColor = 1;

  /// The current background color (1-9).
  int bgColor = 1;

  /// The user's preferred color for Window 0 (overrides default/1).
  int _window0ColorPref = 1;

  /// The user's preferred color for Window 0 (overrides default/1).
  int get window0ColorPref => _window0ColorPref;

  /// Creates a new screen model.
  ScreenModel({this.cols = 80, this.rows = 24});

  /// The grid for Window 1 (upper/status window) content.
  List<List<Cell>> get window1Grid => _window1Grid;

  /// The grid for Window 0 (lower/main window) scroll buffer.
  List<List<Cell>> get window0Grid => _window0Grid;

  /// The height of Window 1 (upper/status window).
  int get window1Height => _window1Height;

  /// The separator line between the two windows.
  int get separatorLine => 0; // No separator line

  /// The number of lines in Window 0 (lower/main window).
  int get window0Lines => rows - _window1Height;

  /// The cursor row in Window 1 (1-indexed as per Z-Machine).
  int get cursorRow => _cursorRow;

  /// The cursor column in Window 1 (1-indexed as per Z-Machine).
  int get cursorCol => _cursorCol;

  /// Resize the screen model.
  void resize(int newCols, int newRows) {
    if (newCols == cols && newRows == rows) return;
    cols = newCols;
    rows = newRows;
    // Window 1 grid persists, but we might need to truncate columns?
    // For now, we trust the grid to handle overflow or lazy resize.
    // _ensureGridRows checks length, not width.
  }

  /// Ensure Window 1 Grid has at least [count] rows.
  /// Grows the grid if needed, preserving existing content.
  void _ensureGridRows(int count) {
    while (_window1Grid.length < count) {
      _window1Grid.add(List.generate(cols, (_) => Cell.empty()));
    }
  }

  /// Split the window - set Window 1 height (Viewport).
  void splitWindow(int lines) {
    _log.info('splitWindow: $lines (Request)');
    _requestedHeight = lines;
    _recomputeEffectiveHeight();
  }

  // Removed legacy _pendingWindow1Height logic and applyPendingWindowShrink
  // as persistent storage handles the "Quote Box" scenario natively.
  /// Deprecated.  will remove later.
  void applyPendingWindowShrink() {}

  /// Clear Window 1. Resets grid to empty and cursor to (1,1).
  void clearWindow1() {
    _log.info('clearWindow1');
    // We recreate the grid to be fresh.
    // Size? We reset to current Viewport height.
    // If hidden content existed, it is gone now (compliant with erase_window).
    _contentHeight = 0;
    _window1Grid = [];
    _cursorRow = 1;
    _cursorCol = 1;
    // Recompute will likely shrink window back to _requestedHeight
    _recomputeEffectiveHeight();
    // Ensure the grid actually has the rows we expect.
    // _recomputeEffectiveHeight only calls this if height CHANGED.
    // If height stayed the same (e.g. 3->3), grid is still [], but height is 3.
    _ensureGridRows(_window1Height);
  }

  /// Clear Window 0.
  void clearWindow0() {
    _log.info('clearWindow0');
    _window0Grid.clear();
  }

  /// Clear all windows.
  void clearAll() {
    clearWindow1();
    clearWindow0();
  }

  /// Set cursor position in Window 1 (1-indexed).
  void setCursor(int row, int col) {
    _log.info('setCursor: $row, $col');
    // Relaxed clamping: Cursor can go anywhere.
    // We will expand the grid if writing happens.
    _cursorRow = row.clamp(1, 255); // Arbitrary large limit
    _cursorCol = col.clamp(1, cols);
  }

  /// Set text style.
  void setStyle(int style) {
    _log.info('setStyle: $style (1=reverse, 2=bold, 4=italic, 8=fixed)');
    currentStyle = style;
  }

  /// Set text colors.
  void setColors(int fg, int bg) {
    _log.info('setColors: fg=$fg, bg=$bg');
    // 0 = current (no change), so only update if not 0
    if (fg != 0) fgColor = fg;
    if (bg != 0) bgColor = bg;
  }

  /// Write text to Window 1 at current cursor position.
  void writeToWindow1(String text) {
    // Log simplified text content
    _log.info(
      'writeToWindow1: "${text.replaceAll('\n', '\\n')}" at $_cursorRow, $_cursorCol',
    );

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == '\n') {
        _cursorRow++;
        _cursorCol = 1;
        continue;
      }

      // Track Max Content Height
      if (_cursorRow > _contentHeight) {
        _contentHeight = _cursorRow;
        _recomputeEffectiveHeight();
      }

      // Auto-expand Grid if needed (should be handled by recompute, but double check)
      if (_cursorRow > _window1Grid.length) {
        _ensureGridRows(_cursorRow);
      }

      // Write to grid
      if (_cursorRow >= 1 && _cursorCol >= 1 && _cursorCol <= cols) {
        // Safe access
        if (_cursorRow <= _window1Grid.length) {
          final rowList = _window1Grid[_cursorRow - 1];
          if (_cursorCol <= rowList.length) {
            final cell = rowList[_cursorCol - 1];
            cell.char = char;
            cell.fg = fgColor;
            cell.bg = bgColor;
            cell.style = currentStyle;
          }
        }

        _cursorCol++;
        if (_cursorCol > cols) {
          _cursorCol = 1;
          _cursorRow++;
        }
      }
    }
  }

  /// Append text to Window 0 (main scrollable area).
  void appendToWindow0(String text) {
    if (text.isEmpty) return;

    // Suppress generic helper text (often enclosed in brackets) that games might
    // print to Window 0 as a fallback for interpreters that don't support Window 1 or have closed it.
    // We only do this if we are "forcing" the window open (Effective > Requested).
    if (_window1Height > _requestedHeight) {
      final trimmed = text.trim();
      if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        _log.info(
          'Suppressed bracketed Window 0 text during forced-open window: "${text.trim()}"',
        );
        return;
      }
      if (trimmed.startsWith('[')) {
        _log.info(
          'Suppressed bracketed (start) Window 0 text during forced-open window: "${text.trim()}"',
        );
        return;
      }
    }

    // Tokenize text into words, spaces/tabs, and newlines
    final RegExp tokenizer = RegExp(r'([^\s\n]+)|([ \t]+)|(\n)');
    final matches = tokenizer.allMatches(text);

    // Get current line or start new one
    if (_window0Grid.isEmpty) _window0Grid.add([]);
    List<Cell> currentLine = _window0Grid.last;

    void newLine() {
      _window0Grid.add([]);
      currentLine = _window0Grid.last;
      if (_window0Grid.length > maxScrollback) {
        _window0Grid.removeAt(0);
      }
    }

    for (final match in matches) {
      final word = match.group(1);
      final space = match.group(2);
      final newline = match.group(3);

      if (newline != null) {
        newLine();
        continue;
      }

      if (word != null) {
        // Wrap if word doesn't fit
        if (currentLine.isNotEmpty && currentLine.length + word.length > cols) {
          newLine();
        }

        for (int i = 0; i < word.length; i++) {
          // Hard break if word is longer than entire line width (rare edge case)
          if (currentLine.length >= cols) newLine();

          // Apply preference if fgColor is default (1), otherwise respect game color
          final effectiveFg = (fgColor == 1) ? _window0ColorPref : fgColor;
          currentLine.add(
            Cell(word[i], fg: effectiveFg, bg: bgColor, style: currentStyle),
          );
        }
      }

      if (space != null) {
        for (int i = 0; i < space.length; i++) {
          if (currentLine.length >= cols) newLine();
          // Apply preference if fgColor is default (1), otherwise respect game color
          final effectiveFg = (fgColor == 1) ? _window0ColorPref : fgColor;
          currentLine.add(
            Cell(space[i], fg: effectiveFg, bg: bgColor, style: currentStyle),
          );
        }
      }
    }
  }

  /// internal state storage
  Map<String, dynamic>? _savedState;

  /// Saves the current state of the screen model (grids, cursor, etc).
  void saveState() {
    _log.info('Saving ScreenModel state');
    _savedState = {
      'cols': cols,
      'rows': rows,
      'window1Grid': _window1Grid
          .map((row) => row.map((c) => c.clone()).toList())
          .toList(),
      'window1Height': _window1Height,
      'requestedHeight': _requestedHeight,
      'contentHeight': _contentHeight,
      'window0Grid': _window0Grid
          .map((row) => row.map((c) => c.clone()).toList())
          .toList(),
      'cursorRow': _cursorRow,
      'cursorCol': _cursorCol,
      'currentStyle': currentStyle,
      'fgColor': fgColor,
      'bgColor': bgColor,
      'window0ColorPref': _window0ColorPref,
    };
  }

  /// Restores the saved state.
  void restoreState() {
    if (_savedState == null) {
      _log.warning('Attempted to restore state but no state was saved.');
      return;
    }
    _log.info('Restoring ScreenModel state');

    final state = _savedState!;
    cols = state['cols'];
    rows = state['rows'];

    _window1Grid = (state['window1Grid'] as List)
        .map((row) => (row as List).cast<Cell>())
        .toList();
    _window1Height = state['window1Height'];
    _requestedHeight = state['requestedHeight'];
    _contentHeight = state['contentHeight'];

    _window0Grid.clear();
    _window0Grid.addAll(
      (state['window0Grid'] as List)
          .map((row) => (row as List).cast<Cell>())
          .toList(),
    );

    _cursorRow = state['cursorRow'];
    _cursorCol = state['cursorCol'];
    currentStyle = state['currentStyle'];
    fgColor = state['fgColor'];
    bgColor = state['bgColor'];
    if (state.containsKey('window0ColorPref')) {
      _window0ColorPref = state['window0ColorPref'];
    }

    _savedState = null; // Consume save
  }

  /// Force updates the foreground color of all text in Window 0.
  /// Used for theme/color cycling features.
  void forceWindow0Color(int fg) {
    _log.info('forceWindow0Color: $fg');
    _window0ColorPref = fg;
    // We treat this as a theme change, so we update all cells.
    for (var row in _window0Grid) {
      for (var cell in row) {
        cell.fg = fg;
      }
    }
  }
}
