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

  /// The height of Window 1 (upper/status window).
  int _window1Height = 0;

  /// The pending height of Window 1 (upper/status window).
  int _pendingWindow1Height = -1; // -1 means no pending height change

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
    // Re-init grids if needed?
    // Window 1 needs resize (truncate or expand)
    // Window 0 needs re-wrapping? That's hard. We just keep it as is.
    _initWindow1();
  }

  /// Initialize Window 1 buffer with the given height.
  void _initWindow1() {
    // Generate new grid. Ideally enforce cols limit.
    // Preserve existing content (truncate or expand)
    final newGrid = List.generate(
      _window1Height,
      (_) => List.generate(cols, (_) => Cell.empty()),
    );

    for (int r = 0; r < min(_window1Grid.length, newGrid.length); r++) {
      for (int c = 0; c < min(_window1Grid[r].length, newGrid[r].length); c++) {
        newGrid[r][c] = _window1Grid[r][c];
      }
    }
    _window1Grid = newGrid;
  }

  /// Split the window - set Window 1 height.
  /// If shrinking, defer until after user input (quote box counter-trick).
  void splitWindow(int lines) {
    if (lines < _window1Height && _window1Height > 1) {
      _log.info(
        'splitWindow: $lines (deferring shrink, current: $_window1Height)',
      );
      // Deferring shrink - save pending height
      _pendingWindow1Height = lines;
    } else {
      _log.info('splitWindow: $lines (applying immediately)');
      // Growing or no change - apply immediately

      // If we are growing, we just set the new height and re-init (which preserves content)
      _window1Height = lines;
      _initWindow1();
    }
  }

  /// Apply any pending Window 1 height change (call after user input).
  void applyPendingWindowShrink() {
    if (_pendingWindow1Height >= 0) {
      _log.info('applyPendingWindowShrink: $_pendingWindow1Height');
      _window1Height = _pendingWindow1Height;
      _initWindow1();
      _pendingWindow1Height = -1;
    }
  }

  /// Clear Window 1.
  void clearWindow1() {
    _log.info('clearWindow1');
    _window1Grid = List.generate(
      _window1Height,
      (_) => List.generate(cols, (_) => Cell.empty()),
    );
    _cursorRow = 1;
    _cursorCol = 1;
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
    _cursorRow = row.clamp(1, _window1Height > 0 ? _window1Height : 1);
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
    if (_window1Height == 0) return;
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

      if (_cursorRow >= 1 &&
          _cursorRow <= _window1Height &&
          _cursorCol >= 1 &&
          _cursorCol <= cols) {
        // Ensure grid has enough rows
        while (_window1Grid.length < _cursorRow) {
          _window1Grid.add(List.generate(cols, (_) => Cell.empty()));
        }

        final rowList = _window1Grid[_cursorRow - 1];
        if (_cursorCol <= rowList.length) {
          // Update cell with character and current style/colors
          final cell = rowList[_cursorCol - 1];
          cell.char = char;
          cell.fg = fgColor;
          cell.bg = bgColor;
          cell.style = currentStyle;
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
    // print to Window 0 as a fallback for interpreters that don't support Window 1.
    // We only do this if we are in a "pending shrink" state (e.g. quote box active).
    if (_pendingWindow1Height >= 0) {
      final trimmed = text.trim();
      if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        _log.info(
          'Suppressed bracketed Window 0 text during quote box: "${text.trim()}"',
        );
        return;
      }
      // Also catch cases where it starts with [ but the newline might be outside trim?
      // Or simple heuristic: starts with [
      if (trimmed.startsWith('[')) {
        _log.info(
          'Suppressed bracketed (start) Window 0 text during quote box: "${text.trim()}"',
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

          currentLine.add(
            Cell(word[i], fg: fgColor, bg: bgColor, style: currentStyle),
          );
        }
      }

      if (space != null) {
        for (int i = 0; i < space.length; i++) {
          if (currentLine.length >= cols) newLine();
          currentLine.add(
            Cell(space[i], fg: fgColor, bg: bgColor, style: currentStyle),
          );
        }
      }
    }
  }
}
