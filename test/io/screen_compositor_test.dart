import 'package:test/test.dart';
import 'package:zart/src/io/render/render_cell.dart';
import 'package:zart/src/io/render/render_frame.dart';
import 'package:zart/src/io/render/screen_compositor.dart';
import 'package:zart/src/io/render/screen_frame.dart';

void main() {
  group('ScreenCompositor', () {
    late ScreenCompositor compositor;

    setUp(() {
      compositor = ScreenCompositor();
    });

    group('composite()', () {
      test('creates empty screen for empty frame', () {
        final frame = RenderFrame(windows: [], screenWidth: 80, screenHeight: 24);

        final result = compositor.composite(frame, screenWidth: 80, screenHeight: 24);

        expect(result.width, equals(80));
        expect(result.height, equals(24));
        expect(result.cells.length, equals(24));
        expect(result.cells[0].length, equals(80));
        expect(result.cursorVisible, isFalse);
      });

      test('composites single window at origin', () {
        final cells = [
          [RenderCell('A'), RenderCell('B')],
          [RenderCell('C'), RenderCell('D')],
        ];

        final frame = RenderFrame(
          windows: [RenderWindow(id: 1, x: 0, y: 0, width: 2, height: 2, cells: cells)],
          screenWidth: 10,
          screenHeight: 5,
        );

        final result = compositor.composite(frame, screenWidth: 10, screenHeight: 5);

        expect(result.cells[0][0].char, equals('A'));
        expect(result.cells[0][1].char, equals('B'));
        expect(result.cells[1][0].char, equals('C'));
        expect(result.cells[1][1].char, equals('D'));
        // Cells outside window should be empty
        expect(result.cells[0][2].char, equals(' '));
      });

      test('composites window at offset position', () {
        final cells = [
          [RenderCell('X')],
        ];

        final frame = RenderFrame(
          windows: [RenderWindow(id: 1, x: 5, y: 3, width: 1, height: 1, cells: cells)],
          screenWidth: 10,
          screenHeight: 5,
        );

        final result = compositor.composite(frame, screenWidth: 10, screenHeight: 5);

        // Check position (5, 3)
        expect(result.cells[3][5].char, equals('X'));
        // Other cells should be empty
        expect(result.cells[0][0].char, equals(' '));
      });

      test('composites multiple overlapping windows in order', () {
        final window1Cells = [
          [RenderCell('1')],
        ];
        final window2Cells = [
          [RenderCell('2')],
        ];

        final frame = RenderFrame(
          windows: [
            RenderWindow(id: 1, x: 0, y: 0, width: 1, height: 1, cells: window1Cells),
            RenderWindow(id: 2, x: 0, y: 0, width: 1, height: 1, cells: window2Cells),
          ],
          screenWidth: 10,
          screenHeight: 5,
        );

        final result = compositor.composite(frame, screenWidth: 10, screenHeight: 5);

        // Window 2 should overwrite window 1 (rendered later)
        expect(result.cells[0][0].char, equals('2'));
      });

      test('tracks cursor position for focused window', () {
        final cells = [
          [RenderCell('A'), RenderCell('B')],
        ];

        final frame = RenderFrame(
          windows: [
            RenderWindow(
              id: 1,
              x: 2,
              y: 3,
              width: 2,
              height: 1,
              cells: cells,
              acceptsInput: true,
              cursorX: 1,
              cursorY: 0,
            ),
          ],
          screenWidth: 10,
          screenHeight: 5,
          focusedWindowId: 1,
        );

        final result = compositor.composite(frame, screenWidth: 10, screenHeight: 5);

        expect(result.cursorVisible, isTrue);
        expect(result.cursorX, equals(3)); // 2 + 1
        expect(result.cursorY, equals(3)); // 3 + 0
      });

      test('clips window content to screen bounds', () {
        final cells = [
          [RenderCell('A'), RenderCell('B'), RenderCell('C')],
        ];

        final frame = RenderFrame(
          windows: [
            RenderWindow(
              id: 1,
              x: 8, // Near right edge
              y: 0,
              width: 3,
              height: 1,
              cells: cells,
            ),
          ],
          screenWidth: 10,
          screenHeight: 5,
        );

        final result = compositor.composite(frame, screenWidth: 10, screenHeight: 5);

        expect(result.cells[0][8].char, equals('A'));
        expect(result.cells[0][9].char, equals('B'));
        // 'C' would be at column 10, which is out of bounds (0-9)
      });
    });

    group('scroll()', () {
      test('scroll() increases offset', () {
        compositor.scroll(5);
        expect(compositor.scrollOffset, equals(5));

        compositor.scroll(3);
        expect(compositor.scrollOffset, equals(8));
      });

      test('scroll() with negative value decreases offset', () {
        compositor.scroll(10);
        compositor.scroll(-3);
        expect(compositor.scrollOffset, equals(7));
      });

      test('scroll() clamps to zero', () {
        compositor.scroll(-5);
        expect(compositor.scrollOffset, equals(0));

        compositor.scroll(10);
        compositor.scroll(-20);
        expect(compositor.scrollOffset, equals(0));
      });

      test('scrollToBottom() resets offset', () {
        compositor.scroll(10);
        compositor.scrollToBottom();
        expect(compositor.scrollOffset, equals(0));
      });

      test('setScrollOffset() sets offset directly', () {
        compositor.setScrollOffset(25);
        expect(compositor.scrollOffset, equals(25));
      });

      test('setScrollOffset() clamps negative values', () {
        compositor.setScrollOffset(-5);
        expect(compositor.scrollOffset, equals(0));
      });
    });

    group('scrollable windows', () {
      test('applies scroll offset to text buffer window', () {
        // Create a window with more content than visible height
        final cells = List.generate(10, (row) => [RenderCell('${row}')]);

        final frame = RenderFrame(
          windows: [
            RenderWindow(
              id: 1,
              x: 0,
              y: 0,
              width: 1,
              height: 3, // Only 3 rows visible
              cells: cells, // 10 rows of content
              isTextBuffer: true,
            ),
          ],
          screenWidth: 10,
          screenHeight: 5,
        );

        // At bottom (scrollOffset = 0), should show rows 7, 8, 9
        var result = compositor.composite(frame, screenWidth: 10, screenHeight: 5);

        expect(result.cells[0][0].char, equals('7'));
        expect(result.cells[1][0].char, equals('8'));
        expect(result.cells[2][0].char, equals('9'));

        // Scroll up by 3, should show rows 4, 5, 6
        compositor.scroll(3);
        result = compositor.composite(frame, screenWidth: 10, screenHeight: 5);

        expect(result.cells[0][0].char, equals('4'));
        expect(result.cells[1][0].char, equals('5'));
        expect(result.cells[2][0].char, equals('6'));
      });

      test('hides cursor when scrolled up', () {
        final cells = List.generate(10, (row) => [RenderCell('${row}')]);

        final frame = RenderFrame(
          windows: [
            RenderWindow(
              id: 1,
              x: 0,
              y: 0,
              width: 1,
              height: 3,
              cells: cells,
              isTextBuffer: true,
              acceptsInput: true,
              cursorY: 9, // At bottom of content
              cursorX: 0,
            ),
          ],
          screenWidth: 10,
          screenHeight: 5,
          focusedWindowId: 1,
        );

        // At bottom, cursor should be visible
        var result = compositor.composite(frame, screenWidth: 10, screenHeight: 5);
        expect(result.cursorVisible, isTrue);

        // Scroll up, cursor should be hidden
        compositor.scroll(3);
        result = compositor.composite(frame, screenWidth: 10, screenHeight: 5);
        expect(result.cursorVisible, isFalse);
      });
    });
  });

  group('ScreenFrame', () {
    test('empty() creates correctly sized frame', () {
      final frame = ScreenFrame.empty(40, 20);

      expect(frame.width, equals(40));
      expect(frame.height, equals(20));
      expect(frame.cells.length, equals(20));
      expect(frame.cells[0].length, equals(40));
      expect(frame.cursorX, equals(-1));
      expect(frame.cursorY, equals(-1));
      expect(frame.cursorVisible, isFalse);
    });

    test('getCell() returns cell at valid position', () {
      final frame = ScreenFrame(
        cells: [
          [RenderCell('A'), RenderCell('B')],
          [RenderCell('C'), RenderCell('D')],
        ],
        width: 2,
        height: 2,
      );

      expect(frame.getCell(0, 0)?.char, equals('A'));
      expect(frame.getCell(0, 1)?.char, equals('B'));
      expect(frame.getCell(1, 0)?.char, equals('C'));
      expect(frame.getCell(1, 1)?.char, equals('D'));
    });

    test('getCell() returns null for out-of-bounds positions', () {
      final frame = ScreenFrame.empty(10, 5);

      expect(frame.getCell(-1, 0), isNull);
      expect(frame.getCell(0, -1), isNull);
      expect(frame.getCell(5, 0), isNull);
      expect(frame.getCell(0, 10), isNull);
    });
  });

  group('Performance', () {
    test('composites full screen in under 50ms', () {
      final compositor = ScreenCompositor();

      // Create a realistic frame: 80x24 screen with status bar + main text buffer
      const screenWidth = 80;
      const screenHeight = 24;

      // Status bar: 1 row at top
      final statusCells = [List.generate(screenWidth, (col) => RenderCell('S', fgColor: 0xFFFFFF))];

      // Main text buffer: fill with realistic content (300 lines of text)
      final mainCells = List.generate(
        300, // Scrollback buffer
        (row) => List.generate(
          screenWidth,
          (col) => RenderCell(String.fromCharCode(32 + ((row + col) % 94)), fgColor: 0xCCCCCC),
        ),
      );

      final frame = RenderFrame(
        windows: [
          RenderWindow(id: 1, x: 0, y: 0, width: screenWidth, height: 1, cells: statusCells),
          RenderWindow(
            id: 0,
            x: 0,
            y: 1,
            width: screenWidth,
            height: screenHeight - 1,
            cells: mainCells,
            isTextBuffer: true,
            acceptsInput: true,
            cursorX: 10,
            cursorY: 299,
          ),
        ],
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        focusedWindowId: 0,
      );

      // Warm up
      compositor.composite(frame, screenWidth: screenWidth, screenHeight: screenHeight);

      // Measure
      final stopwatch = Stopwatch()..start();
      const iterations = 10;
      for (var i = 0; i < iterations; i++) {
        compositor.composite(frame, screenWidth: screenWidth, screenHeight: screenHeight);
      }
      stopwatch.stop();

      final avgMs = stopwatch.elapsedMilliseconds / iterations;
      // ignore: avoid_print
      print('Average composition time: ${avgMs.toStringAsFixed(2)}ms');

      expect(
        avgMs,
        lessThan(5),
        reason: 'Screen composition should complete in under 5ms (actual: ${avgMs.toStringAsFixed(2)}ms)',
      );
    });
  });
}
