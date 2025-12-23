import 'dart:math';
import 'package:logging/logging.dart';
import 'package:zart/src/io/render/render_cell.dart';
import 'package:zart/src/io/render/render_frame.dart';
import 'package:zart/src/io/render/z_colors.dart';

final _log = Logger('ScreenModel');

/// Screen Model for the Zart Z-Machine Interpreter.
///
/// The screen model presents a common API for any player app to use,
/// and then manages the presentation layer logic.  It emits [RenderCell]
/// objects for the player app to render.  Each cell contains a character with
/// styling information.
///
/// It also contain API methods that allow the player to control the layout,
/// for example if they want to create custom screens (the CLI player does this
/// to display a settings screen)
///
/// Layout:
/// ```text
/// ┌────────────────────────────────┐
/// │ Window 1 (status/upper)        │ ← Window 1
/// ├────────────────────────────────┤ ← Separator (optional visible)
/// │ Window 0 (main, scrollable)    │ ← Window 0.
/// │ (text, text)                   │
/// │ > [input line]                 │
/// │                                │
/// └────────────────────────────────┘
///```
///
/// # In the Z-Machine Windowing System
/// The z-machine spec calls for interpreters to implement a stacked dual window
/// system.  The layout of the windows (height of each) is determined by the game
/// and the interpreter is expected to implement this.  Interpreters do have some
/// leeway in how they manage the presentation layer.  In Zart, we choose to
/// abstract the windowing/layout into this [ZScreenModel] class, so that
/// multiple interpreter "player" apps can use the same API to display the game,
/// and then manaage their own presentation layer logic. (CLI, Flutter, etc.)
///
/// ## Window 1
/// Window 1 is the upper window and allows for
/// positioning of text.  It is used for status lines, menus, and other
/// positional UI components.
///
/// Window 1 expands and contracts at game request.
///
/// Window 1, in some versions of z-machine can also display graphics.
/// Zart does not yet support this.
///
/// ## Window 0
/// Window 0 is the main window and is used for the main text of the game.
///
/// It is generally scrollable, but does not have to be.  Most modern players
/// should try to support scrolling.
///
/// It is always expanded to fill the remaining space after window 1.
class ZScreenModel {
  /// The number of columns in the screen.
  int cols;

  /// The number of rows in the screen.
  int rows;

  /// The width to wrap text at in Window 0.
  /// If 0 or >= cols, text wraps at [cols].
  int wrapWidth = 0;

  /// Effective wrap width.
  int get _effectiveWrapWidth => (wrapWidth > 0 && wrapWidth < cols) ? wrapWidth : cols;

  /// The grid for Window 1 (upper/status window) content.
  /// Grid is [row][col]
  List<List<RenderCell>> _window1Grid = [];

  /// The effective visible height of Window 1.
  int _window1Height = 0;

  /// The height explicitly requested by splitWindow.
  int _requestedHeight = 0;

  /// The maximum row index that contains content (written to).
  int _contentHeight = 0;

  /// Recomputes the effective window height based on request and content.
  void _recomputeEffectiveHeight() {
    // Calculate desired height based on request and content
    var newHeight = max(_requestedHeight, _contentHeight);

    // Clamp to terminal rows - games may write to high row numbers
    // (e.g., row 123 for quote box trick) but we can't expand beyond screen
    if (newHeight > rows) {
      newHeight = rows;
    }

    if (newHeight != _window1Height) {
      _log.info(
        'Auto-sizing Window 1: Requested $_requestedHeight, Content $_contentHeight -> Effective $newHeight (rows=$rows)',
      );
      _window1Height = newHeight;
      _ensureGridRows(_window1Height);
    }
  }

  /// The grid for Window 0 (lower/main window) scroll buffer.
  final List<List<RenderCell>> _window0Grid = [];

  /// The maximum number of lines to keep in the scroll buffer.
  int maxScrollback = 1000;

  /// The cursor position for Window 1 (1-indexed as per Z-Machine).
  int _cursorRow = 1;
  int _cursorCol = 1;

  /// The current text style (bitmask: 1=Reverse, 2=Bold, 4=Italic, 8=Fixed).
  int currentStyle = 0;

  /// The current foreground color (Z-machine code 1-12).
  int fgColor = 1;

  /// The current background color (Z-machine code 1-12).
  int bgColor = 1;

  /// The user's preferred color for Window 0 (Z-machine code, overrides default/1).
  int _window0ColorPref = 1;

  /// The user's preferred color for Window 0 (Z-machine code, overrides default/1).
  int get window0ColorPref => _window0ColorPref;

  /// Creates a new screen model.
  ZScreenModel({this.cols = 80, this.rows = 24});

  /// The grid for Window 1 (upper/status window) content.
  List<List<RenderCell>> get window1Grid => _window1Grid;

  /// The grid for Window 0 (lower/main window) scroll buffer.
  List<List<RenderCell>> get window0Grid => _window0Grid;

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
    final oldCols = cols;
    cols = newCols;
    rows = newRows;

    // Resize existing Window 1 grid rows
    for (var row in _window1Grid) {
      if (newCols > oldCols) {
        // Growing - add missing cells
        row.addAll(List.generate(newCols - oldCols, (_) => RenderCell.empty()));
      } else if (newCols < oldCols) {
        // Shrinking - truncate
        row.removeRange(newCols, oldCols);
      }
    }

    _ensureGridRows(rows);
  }

  /// Ensure Window 1 Grid has at least [count] rows.
  /// Grows the grid if needed, preserving existing content.
  void _ensureGridRows(int count) {
    while (_window1Grid.length < count) {
      _window1Grid.add(List.generate(cols, (_) => RenderCell.empty()));
    }
  }

  /// Split the window - set Window 1 height (Viewport).
  void splitWindow(int lines) {
    _log.info('splitWindow: $lines (Request)');
    _requestedHeight = lines;
    _recomputeEffectiveHeight();
  }

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

  /// Set cursor position in Window 1 (1-indexed for z-machine spec compliance).
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

  /// Create a RenderCell from the current Z-machine style state.
  RenderCell _createCell(String char, {int? overrideFg}) {
    final effectiveFg = overrideFg ?? fgColor;
    return RenderCell(
      char,
      fgColor: ZColors.toRgb(effectiveFg),
      bgColor: ZColors.toRgb(bgColor),
      reverse: (currentStyle & 1) != 0,
      bold: (currentStyle & 2) != 0,
      italic: (currentStyle & 4) != 0,
      fixed: (currentStyle & 8) != 0,
    );
  }

  /// Write text to Window 1 at current cursor position.
  void writeToWindow1(String text) {
    // Log simplified text content
    _log.info('writeToWindow1: "${text.replaceAll('\n', '\\n')}" at $_cursorRow, $_cursorCol');

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
            cell.fgColor = ZColors.toRgb(fgColor);
            cell.bgColor = ZColors.toRgb(bgColor);
            cell.setZMachineStyle(currentStyle);
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
        _log.info('Suppressed bracketed Window 0 text during forced-open window: "${text.trim()}"');
        return;
      }
      if (trimmed.startsWith('[')) {
        _log.info('Suppressed bracketed (start) Window 0 text during forced-open window: "${text.trim()}"');
        return;
      }
    }

    // Tokenize text into words, spaces/tabs, and newlines
    final RegExp tokenizer = RegExp(r'([^\s\n]+)|([ \t]+)|(\n)');
    final matches = tokenizer.allMatches(text);

    // Get current line or start new one
    if (_window0Grid.isEmpty) _window0Grid.add([]);
    List<RenderCell> currentLine = _window0Grid.last;

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
        if (currentLine.isNotEmpty && currentLine.length + word.length > _effectiveWrapWidth) {
          newLine();
        }

        for (int i = 0; i < word.length; i++) {
          // Hard break if word is longer than entire line width (rare edge case)
          if (currentLine.length >= _effectiveWrapWidth) newLine();

          // Apply preference if fgColor is default (1), otherwise respect game color
          final effectiveFg = (fgColor == 1) ? _window0ColorPref : fgColor;
          currentLine.add(_createCell(word[i], overrideFg: effectiveFg));
        }
      }

      if (space != null) {
        for (int i = 0; i < space.length; i++) {
          if (currentLine.length >= _effectiveWrapWidth) {
            newLine();
            continue; // Skip adding the space that caused the wrap
          }
          // Apply preference if fgColor is default (1), otherwise respect game color
          final effectiveFg = (fgColor == 1) ? _window0ColorPref : fgColor;
          currentLine.add(_createCell(space[i], overrideFg: effectiveFg));
        }
      }
    }
  }

  /// internal state storage
  Map<String, dynamic>? _savedState;

  /// Saves the current state of the screen model (grids, cursor, etc).
  /// This is useful for storing the game screen while switching to some custom
  /// screen, like a settings screen.  You can later restore the game screen
  /// by calling [restoreState].  This is probably less useful for frameworks
  /// that have their own GUI system (like Flutter), but it definitely helps
  /// for CLI-based apps like the Zart CLI Player.
  void saveState() {
    _log.info('Saving ScreenModel state');
    _savedState = {
      'cols': cols,
      'rows': rows,
      'wrapWidth': wrapWidth,
      'window1Grid': _window1Grid.map((row) => row.map((c) => c.clone()).toList()).toList(),
      'window1Height': _window1Height,
      'requestedHeight': _requestedHeight,
      'contentHeight': _contentHeight,
      'window0Grid': _window0Grid.map((row) => row.map((c) => c.clone()).toList()).toList(),
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
    if (state.containsKey('wrapWidth')) {
      wrapWidth = state['wrapWidth'];
    }

    _window1Grid = (state['window1Grid'] as List).map((row) => (row as List).cast<RenderCell>()).toList();
    _window1Height = state['window1Height'];
    _requestedHeight = state['requestedHeight'];
    _contentHeight = state['contentHeight'];

    _window0Grid.clear();
    _window0Grid.addAll((state['window0Grid'] as List).map((row) => (row as List).cast<RenderCell>()).toList());

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
    // Convert Z-machine color to RGB and update all cells
    final rgbColor = ZColors.toRgb(fg);
    for (var row in _window0Grid) {
      for (var cell in row) {
        cell.fgColor = rgbColor;
      }
    }
  }

  // === Unified Rendering API ===

  /// Convert the screen state to a RenderFrame for unified rendering.
  ///
  /// Returns two windows:
  /// - Window ID 1: Status bar (text grid)
  /// - Window ID 0: Main text area (text buffer)
  RenderFrame toRenderFrame({int? focusedWindowId}) {
    final windows = <RenderWindow>[];

    // Window 1 (status bar) - if visible
    if (_window1Height > 0) {
      // Cells are already RenderCell, just copy for immutability
      final w1Cells = <List<RenderCell>>[];
      for (var row in _window1Grid) {
        w1Cells.add(row.map((c) => c.clone()).toList());
      }
      windows.add(
        RenderWindow(
          id: 1,
          x: 0,
          y: 0,
          width: cols,
          height: _window1Height,
          cells: w1Cells,
          acceptsInput: false,
          cursorX: _cursorCol - 1,
          cursorY: _cursorRow - 1,
        ),
      );
    }

    // Window 0 (main text area)
    final w0Cells = <List<RenderCell>>[];
    for (var row in _window0Grid) {
      w0Cells.add(row.map((c) => c.clone()).toList());
    }
    windows.add(
      RenderWindow(
        id: 0,
        x: 0,
        y: _window1Height,
        width: cols,
        height: rows - _window1Height,
        cells: w0Cells,
        acceptsInput: true, // Window 0 typically receives input
        cursorX: _window0Grid.isNotEmpty ? _window0Grid.last.length : 0,
        cursorY: _window0Grid.isNotEmpty ? _window0Grid.length - 1 : 0,
        isTextBuffer: true,
      ),
    );

    return RenderFrame(windows: windows, screenWidth: cols, screenHeight: rows, focusedWindowId: focusedWindowId ?? 0);
  }
}
