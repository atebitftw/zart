import 'package:test/test.dart';
import 'package:zart/src/io/screen_model.dart';

void main() {
  group('ScreenModel Window Management', () {
    late ScreenModel screen;

    setUp(() {
      screen = ScreenModel(cols: 80, rows: 24);
    });

    test(
      'Content Expansion: Window expands when content exceeds requested height',
      () {
        // Game requests 7 lines
        screen.splitWindow(7);
        expect(screen.window1Height, equals(7));

        // Write to line 10 (beyond requested 7)
        screen.setCursor(10, 1);
        screen.writeToWindow1('Row 10 Content');

        // Window should expand to 10
        expect(screen.window1Height, equals(10));
        expect(screen.window1Grid.length, greaterThanOrEqualTo(10));
      },
    );

    test('Persistent Grid: Content persists when requested height shrinks', () {
      // Write content to line 10
      screen.splitWindow(10);
      screen.setCursor(10, 1);
      screen.writeToWindow1('Persistent Content');
      expect(screen.window1Height, equals(10));

      // Game requests shrink to 5
      screen.splitWindow(5);

      // Window height should REMAIN 10 because content is at 10
      // (Content-Aware Sizing Logic)
      expect(screen.window1Height, equals(10));

      // But verify the "Requested" height is being tracked internally?
      // We can only verify visible height via public API.
      // The key behavior is that the window did NOT shrink visually to 5,
      // because content holds it open.
    });

    test('Smart Shrinking: Window shrinks when content is cleared', () {
      // Setup: Content holding window open at 10
      screen.splitWindow(5); // Request 5
      screen.setCursor(10, 1);
      screen.writeToWindow1('Holding Open');
      expect(screen.window1Height, equals(10));

      // Clear Window 1
      screen.clearWindow1();

      // Window should shrink back to the last REQUESTED height (5)
      expect(screen.window1Height, equals(5));
      expect(
        screen.window1Grid.length,
        greaterThanOrEqualTo(5),
      ); // Grid re-inited
    });

    test(
      'Quote Box Suppression: Suppresses bracketed text when forced open',
      () {
        // Setup: Window 1 forced open (Request 0, Content 10)
        screen.splitWindow(0);
        screen.setCursor(10, 1);
        screen.writeToWindow1('Quote Content');
        expect(screen.window1Height, equals(10)); // Forced open

        // write fallback text to Window 0 (with newline, which trim() handles)
        screen.appendToWindow0('[Quote Fallback]\n');

        // Verify Window 0 is empty (suppressed)
        expect(screen.window0Grid, isEmpty);

        // Verify normal text is NOT suppressed
        screen.appendToWindow0('Normal Text');
        expect(screen.window0Grid, isNotEmpty);
        expect(screen.window0Grid.first.first.char, equals('N'));
      },
    );

    test(
      'Quote Box Suppression: Does NOT suppress when request matches content',
      () {
        // Setup: Window 1 matches request (Request 10, Content 10)
        screen.splitWindow(10);
        screen.setCursor(10, 1);
        screen.writeToWindow1('Normal Menu');
        expect(screen.window1Height, equals(10));

        // write bracketed text (e.g. game UI element)
        screen.appendToWindow0('[Menu Option]');

        // Verify NOT suppressed
        expect(screen.window0Grid, isNotEmpty);
        expect(screen.window0Grid.first.first.char, equals('['));
      },
    );

    test('Bug Fix: clearWindow1 repopulates grid when height is unchanged', () {
      // Setup: requested height 3
      screen.splitWindow(3);
      expect(screen.window1Height, equals(3));

      // Clear logic
      screen.clearWindow1();

      // Verify grid has 3 rows (fix ensures this)
      // Before fix: would be 0 because height didn't change so recompute did nothing
      expect(screen.window1Grid.length, equals(3));
    });
  });
}
