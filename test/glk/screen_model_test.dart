// Unit tests for GlkScreenModel word wrap and window type fixes.
//
// Tests cover:
// - Word-boundary wrapping in text buffer windows
// - Window type mapping (Glk spec: pair=1, blank=2, textBuffer=3, textGrid=4, graphics=5)
import 'package:test/test.dart';
import 'package:zart/src/io/glk/glk_screen_model.dart';
import 'package:zart/src/io/glk/glk_window.dart';

void main() {
  group('GlkScreenModel word wrap', () {
    late GlkScreenModel model;

    setUp(() {
      model = GlkScreenModel();
      model.setScreenSize(20, 10);
    });

    test('wraps at word boundary when line exceeds width', () {
      // Open a text buffer window
      final winId = model.windowOpen(null, 0, 0, GlkWindowType.textBuffer, 0);
      expect(winId, isNotNull);

      // Write text that exceeds 20 chars - should wrap at word boundary
      // "Hello World This " = 17 chars, then "is a test" would exceed
      model.putString(winId!, 'Hello World This is a test');

      final window = model.getWindow(winId) as GlkTextBufferWindow;

      // Should have wrapped at space before "is"
      // Line 1: "Hello World This " (with "is" moved to next line)
      expect(window.lines.length, greaterThanOrEqualTo(2));

      // First line should not exceed width
      expect(window.lines[0].length, lessThanOrEqualTo(20));
    });

    test('hard breaks when no space found', () {
      final winId = model.windowOpen(null, 0, 0, GlkWindowType.textBuffer, 0);
      expect(winId, isNotNull);

      // Write a long word with no spaces
      model.putString(winId!, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ');

      final window = model.getWindow(winId) as GlkTextBufferWindow;

      // Should have hard-wrapped at column 20
      expect(window.lines.length, greaterThanOrEqualTo(2));
      expect(window.lines[0].length, lessThanOrEqualTo(20));
    });

    test('respects explicit newlines from game', () {
      final winId = model.windowOpen(null, 0, 0, GlkWindowType.textBuffer, 0);
      expect(winId, isNotNull);

      // Write text with explicit newline
      model.putString(winId!, 'Line 1\nLine 2');

      final window = model.getWindow(winId) as GlkTextBufferWindow;

      expect(window.lines.length, equals(2));
      expect(window.lines[0].map((c) => c.char).join(), equals('Line 1'));
      expect(window.lines[1].map((c) => c.char).join(), equals('Line 2'));
    });
  });

  group('GlkScreenModel window types', () {
    late GlkScreenModel model;

    setUp(() {
      model = GlkScreenModel();
      model.setScreenSize(80, 25);
    });

    test('creates text buffer window for type textBuffer', () {
      final winId = model.windowOpen(null, 0, 0, GlkWindowType.textBuffer, 0);
      expect(winId, isNotNull);

      final window = model.getWindow(winId!);
      expect(window, isA<GlkTextBufferWindow>());
      expect(window?.type, equals(GlkWindowType.textBuffer));
    });

    test('creates text grid window for type textGrid', () {
      final winId = model.windowOpen(null, 0, 0, GlkWindowType.textGrid, 0);
      expect(winId, isNotNull);

      final window = model.getWindow(winId!);
      expect(window, isA<GlkTextGridWindow>());
      expect(window?.type, equals(GlkWindowType.textGrid));
    });

    test('creates graphics window for type graphics', () {
      final winId = model.windowOpen(null, 0, 0, GlkWindowType.graphics, 0);
      expect(winId, isNotNull);

      final window = model.getWindow(winId!);
      expect(window, isA<GlkGraphicsWindow>());
      expect(window?.type, equals(GlkWindowType.graphics));
    });

    test('creates blank window for type blank', () {
      final winId = model.windowOpen(null, 0, 0, GlkWindowType.blank, 0);
      expect(winId, isNotNull);

      final window = model.getWindow(winId!);
      expect(window, isA<GlkBlankWindow>());
      expect(window?.type, equals(GlkWindowType.blank));
    });
  });

  group('GlkScreenModel window dimensions', () {
    late GlkScreenModel model;

    setUp(() {
      model = GlkScreenModel();
      model.setScreenSize(80, 25);
    });

    test('root window gets full screen dimensions', () {
      final winId = model.windowOpen(null, 0, 0, GlkWindowType.textBuffer, 0);
      expect(winId, isNotNull);

      final (w, h) = model.windowGetSize(winId!);
      expect(w, equals(80));
      expect(h, equals(25));
    });

    test('window dimensions update on screen resize', () {
      final winId = model.windowOpen(null, 0, 0, GlkWindowType.textBuffer, 0);
      expect(winId, isNotNull);

      // Resize screen
      model.setScreenSize(120, 40);

      final (w, h) = model.windowGetSize(winId!);
      expect(w, equals(120));
      expect(h, equals(40));
    });
  });
}
