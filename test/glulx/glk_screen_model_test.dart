import 'package:test/test.dart';
import 'package:zart/src/io/glk/glk_screen_model.dart';
import 'package:zart/src/io/glk/glk_window.dart';
import 'package:zart/src/io/glk/glk_cell.dart';
import 'package:zart/src/io/glk/glk_styles.dart';
import 'package:zart/src/io/glk/glk_winmethod.dart';

void main() {
  group('GlkScreenModel', () {
    late GlkScreenModel model;

    setUp(() {
      model = GlkScreenModel();
      model.setScreenSize(80, 24);
    });

    group('Window Creation', () {
      test('creates root text buffer window', () {
        final id = model.windowOpen(null, 0, 0, GlkWindowType.textBuffer, 100);

        expect(id, isNotNull);
        expect(model.rootWindow, isNotNull);
        expect(model.rootWindow!.id, id);
        expect(model.rootWindow!.rock, 100);
        expect(model.rootWindow!.type, GlkWindowType.textBuffer);
      });

      test('creates root text grid window', () {
        final id = model.windowOpen(null, 0, 0, GlkWindowType.textGrid, 200);

        expect(id, isNotNull);
        final window = model.getWindow(id!);
        expect(window, isA<GlkTextGridWindow>());
        expect(window!.rock, 200);
      });

      test('cannot create pair window directly', () {
        final id = model.windowOpen(null, 0, 0, GlkWindowType.pair, 0);
        expect(id, isNull);
      });

      test('splits window creating pair window', () {
        // Create root.
        final rootId = model.windowOpen(null, 0, 0, GlkWindowType.textBuffer, 0);
        expect(rootId, isNotNull);

        // Split above with 3 rows.
        final statusId = model.windowOpen(
          rootId,
          GlkWinmethod.above | GlkWinmethod.fixed,
          3,
          GlkWindowType.textGrid,
          0,
        );
        expect(statusId, isNotNull);

        // Root should now be a pair.
        expect(model.rootWindow, isA<GlkPairWindow>());
        final pair = model.rootWindow as GlkPairWindow;
        expect(pair.child1!.id, rootId);
        expect(pair.child2!.id, statusId);
      });
    });

    group('Window Close', () {
      test('closes root window', () {
        final id = model.windowOpen(null, 0, 0, GlkWindowType.textBuffer, 0);
        model.windowClose(id!);
        expect(model.rootWindow, isNull);
      });

      test('closing child promotes sibling to replace pair', () {
        final bufferId = model.windowOpen(null, 0, 0, GlkWindowType.textBuffer, 0);
        final gridId = model.windowOpen(
          bufferId,
          GlkWinmethod.above | GlkWinmethod.fixed,
          3,
          GlkWindowType.textGrid,
          0,
        );

        // Close the grid.
        model.windowClose(gridId!);

        // Buffer should now be root.
        expect(model.rootWindow, isA<GlkTextBufferWindow>());
        expect(model.rootWindow!.id, bufferId);
      });
    });

    group('Window Size', () {
      test('root window gets full screen size', () {
        final id = model.windowOpen(null, 0, 0, GlkWindowType.textBuffer, 0);
        final (w, h) = model.windowGetSize(id!);
        expect(w, 80);
        expect(h, 24);
      });

      test('fixed split allocates correct sizes', () {
        final bufferId = model.windowOpen(null, 0, 0, GlkWindowType.textBuffer, 0);
        final gridId = model.windowOpen(
          bufferId,
          GlkWinmethod.above | GlkWinmethod.fixed,
          3, // 3 rows for status
          GlkWindowType.textGrid,
          0,
        );

        final (gridW, gridH) = model.windowGetSize(gridId!);
        expect(gridW, 80);
        expect(gridH, 3);

        final (bufW, bufH) = model.windowGetSize(bufferId!);
        expect(bufW, 80);
        expect(bufH, 21); // 24 - 3
      });

      test('proportional split allocates percentage', () {
        final bufferId = model.windowOpen(null, 0, 0, GlkWindowType.textBuffer, 0);
        final statusId = model.windowOpen(
          bufferId,
          GlkWinmethod.left | GlkWinmethod.proportional,
          25, // 25% for sidebar
          GlkWindowType.textGrid,
          0,
        );

        final (sideW, sideH) = model.windowGetSize(statusId!);
        expect(sideW, 20); // 25% of 80
        expect(sideH, 24);

        final (bufW, bufH) = model.windowGetSize(bufferId!);
        expect(bufW, 60); // 75% of 80
        expect(bufH, 24);
      });
    });

    group('Text Grid Output', () {
      test('writes text at cursor position', () {
        final id = model.windowOpen(null, 0, 0, GlkWindowType.textGrid, 0);
        model.putString(id!, 'Hello');

        final cells = model.getTextGridCells(id);
        expect(cells, isNotNull);
        expect(cells![0][0].char, 'H');
        expect(cells[0][1].char, 'e');
        expect(cells[0][2].char, 'l');
        expect(cells[0][3].char, 'l');
        expect(cells[0][4].char, 'o');
      });

      test('cursor wraps at end of line', () {
        model.setScreenSize(5, 2);
        final id = model.windowOpen(null, 0, 0, GlkWindowType.textGrid, 0);
        model.putString(id!, 'Hello!');

        final cells = model.getTextGridCells(id);
        expect(cells![0][4].char, 'o');
        expect(cells[1][0].char, '!');
      });

      test('moveCursor positions correctly', () {
        final id = model.windowOpen(null, 0, 0, GlkWindowType.textGrid, 0);
        model.windowMoveCursor(id!, 5, 2);
        model.putString(id, 'X');

        final cells = model.getTextGridCells(id);
        expect(cells![2][5].char, 'X');
      });

      test('clear resets all cells', () {
        final id = model.windowOpen(null, 0, 0, GlkWindowType.textGrid, 0);
        model.putString(id!, 'AAA');
        model.windowClear(id);

        final cells = model.getTextGridCells(id);
        expect(cells![0][0].char, ' ');
        expect(cells[0][1].char, ' ');
      });
    });

    group('Text Buffer Output', () {
      test('appends text to buffer', () {
        final id = model.windowOpen(null, 0, 0, GlkWindowType.textBuffer, 0);
        model.putString(id!, 'Hello');

        final lines = model.getTextBufferLines(id);
        expect(lines, isNotNull);
        expect(lines!.length, 1);
        expect(lines[0].length, 5);
        expect(lines[0][0].char, 'H');
      });

      test('newline creates new line', () {
        final id = model.windowOpen(null, 0, 0, GlkWindowType.textBuffer, 0);
        model.putString(id!, 'Line1\nLine2');

        final lines = model.getTextBufferLines(id);
        expect(lines!.length, 2);
        expect(lines[0].map((c) => c.char).join(), 'Line1');
        expect(lines[1].map((c) => c.char).join(), 'Line2');
      });

      test('setStyle affects subsequent output', () {
        final id = model.windowOpen(null, 0, 0, GlkWindowType.textBuffer, 0);
        model.putString(id!, 'A');
        model.setStyle(id, GlkStyle.emphasized);
        model.putString(id, 'B');

        final lines = model.getTextBufferLines(id);
        expect(lines![0][0].style, GlkStyle.normal);
        expect(lines[0][1].style, GlkStyle.emphasized);
      });
    });

    group('Input State', () {
      test('tracks line input pending', () {
        final id = model.windowOpen(null, 0, 0, GlkWindowType.textBuffer, 0);
        expect(model.getWindowsAwaitingInput(), isEmpty);

        model.requestLineEvent(id!, 0x1000, 255);
        expect(model.getWindowsAwaitingInput(), [id]);

        final window = model.getWindow(id);
        expect(window!.lineInputPending, true);
        expect(window.lineInputBufferAddr, 0x1000);
        expect(window.lineInputMaxLen, 255);

        model.cancelLineEvent(id);
        expect(model.getWindowsAwaitingInput(), isEmpty);
      });

      test('tracks char input pending', () {
        final id = model.windowOpen(null, 0, 0, GlkWindowType.textBuffer, 0);
        model.requestCharEvent(id!);
        expect(model.getWindowsAwaitingInput(), [id]);

        model.cancelCharEvent(id);
        expect(model.getWindowsAwaitingInput(), isEmpty);
      });

      test('multiple windows can have pending input', () {
        final buf = model.windowOpen(null, 0, 0, GlkWindowType.textBuffer, 0);
        final grid = model.windowOpen(buf, GlkWinmethod.above | GlkWinmethod.fixed, 3, GlkWindowType.textGrid, 0);

        model.requestLineEvent(buf!, 0x1000, 255);
        model.requestCharEvent(grid!);

        final awaiting = model.getWindowsAwaitingInput();
        expect(awaiting, containsAll([buf, grid]));
      });
    });

    group('Visible Windows', () {
      test('returns all visible windows', () {
        final buf = model.windowOpen(null, 0, 0, GlkWindowType.textBuffer, 0);
        final grid = model.windowOpen(buf, GlkWinmethod.above | GlkWinmethod.fixed, 3, GlkWindowType.textGrid, 0);

        final visible = model.getVisibleWindows();
        expect(visible.length, 2);

        // Grid should be at top.
        final gridInfo = visible.firstWhere((w) => w.windowId == grid);
        expect(gridInfo.x, 0);
        expect(gridInfo.y, 0);
        expect(gridInfo.height, 3);

        // Buffer should be below.
        final bufInfo = visible.firstWhere((w) => w.windowId == buf);
        expect(bufInfo.x, 0);
        expect(bufInfo.y, 3);
        expect(bufInfo.height, 21);
      });
    });
  });

  group('GlkCell', () {
    test('creates cell with character and style', () {
      final cell = GlkCell('A', style: GlkStyle.header);
      expect(cell.char, 'A');
      expect(cell.style, GlkStyle.header);
    });

    test('empty cell has space and normal style', () {
      final cell = GlkCell.empty();
      expect(cell.char, ' ');
      expect(cell.style, GlkStyle.normal);
    });

    test('clone creates independent copy', () {
      final cell = GlkCell('X', style: GlkStyle.emphasized, fgColor: 0xFF0000);
      final copy = cell.clone();

      cell.char = 'Y';
      expect(copy.char, 'X');
      expect(copy.style, GlkStyle.emphasized);
      expect(copy.fgColor, 0xFF0000);
    });
  });

  group('GlkWinmethod', () {
    test('isHorizontal detects left/right', () {
      expect(GlkWinmethod.isHorizontal(GlkWinmethod.left), true);
      expect(GlkWinmethod.isHorizontal(GlkWinmethod.right), true);
      expect(GlkWinmethod.isHorizontal(GlkWinmethod.above), false);
      expect(GlkWinmethod.isHorizontal(GlkWinmethod.below), false);
    });

    test('isFixed and isProportional', () {
      expect(GlkWinmethod.isFixed(GlkWinmethod.fixed), true);
      expect(GlkWinmethod.isFixed(GlkWinmethod.proportional), false);
      expect(GlkWinmethod.isProportional(GlkWinmethod.proportional), true);
    });
  });
}
