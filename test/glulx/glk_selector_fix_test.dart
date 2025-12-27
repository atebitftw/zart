import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/io/glk/glk_io_selectors.dart';
import 'package:zart/src/io/glk/glk_screen_model.dart';
import 'package:zart/src/zart_debugger.dart';
import 'package:zart/src/io/glk/glk_terminal_display.dart';
import 'package:zart/src/io/glk/glulx_terminal_provider.dart';

/// Mock GlkTerminalDisplay that returns preset input instead of reading stdin.
class MockGlkTerminalDisplay extends GlkTerminalDisplay {
  String nextInput = '';
  final StringBuffer output = StringBuffer();

  MockGlkTerminalDisplay() : super();
  // Dimensions are now read-only (delegated to CliRenderer)

  @override
  Future<String> readLine({int? windowId}) async => nextInput;

  @override
  Future<String> readChar() async => nextInput.isNotEmpty ? nextInput[0] : '';

  @override
  void showTempMessage(String message, {int seconds = 3}) {
    // No-op
  }

  @override
  void renderGlk(GlkScreenModel model) {
    // Don't write to stdout in tests
  }

  @override
  void appendToWindow0(String text) {}

  @override
  void clearAll() {}

  @override
  void render() {}

  @override
  void restoreState() {}

  @override
  void saveState() {}

  @override
  void setColors(int fg, int bg) {}

  @override
  void splitWindow(int lines) {}

  @override
  bool get enableStatusBar => false;

  @override
  set enableStatusBar(bool value) {}

  @override
  Future<void> Function()? onOpenSettings;

  @override
  void enterFullScreen() {
    // Don't change terminal mode in tests
  }

  @override
  void exitFullScreen() {
    // Don't change terminal mode in tests
  }
}

void main() {
  group('Glk Selector Fixes', () {
    late GlulxTerminalProvider provider;
    late MockGlkTerminalDisplay mockDisplay;

    setUp(() {
      mockDisplay = MockGlkTerminalDisplay();
      provider = GlulxTerminalProvider(display: mockDisplay);
      debugger.enabled = false;
    });

    test('unknown Glk selector returns 0 instead of throwing', () async {
      // 0x1234 is a non-existent selector
      final result = await provider.dispatch(0x1234, []);
      expect(result, equals(0));
    });

    test('getCharStream and getCharStreamUni return -1 (EOF)', () async {
      final result1 = await provider.dispatch(GlkIoSelectors.getCharStream, [
        0,
      ]);
      expect(result1, equals(-1));

      final result2 = await provider.dispatch(GlkIoSelectors.getCharStreamUni, [
        0,
      ]);
      expect(result2, equals(-1));
    });

    test('selectPoll returns none event immediately', () async {
      // Per Glk spec: glk_select_poll() returns immediately with evtype_None
      // if no events are pending (unlike glk_select which blocks).
      final memory = Uint8List(16);
      provider.setMemoryAccess(
        write: (addr, val, {size = 1}) {
          if (size == 4) {
            final bd = ByteData.view(memory.buffer);
            bd.setUint32(addr, val, Endian.big);
          }
        },
        read: (addr, {size = 1}) => 0,
      );

      final result = await provider.dispatch(GlkIoSelectors.selectPoll, [0]);
      expect(result, equals(0));

      final bd = ByteData.view(memory.buffer);
      expect(bd.getUint32(0, Endian.big), equals(GlkEventTypes.none));
    });

    // Skipped: This test depends on MockTerminalDisplay but select now uses
    // GlkTerminalDisplay which reads from real stdin. Functionality verified manually.
    test('line input event works', () async {
      // 1. Request line event: window=1, buffer=100, maxlen=10
      await provider.dispatch(GlkIoSelectors.requestLineEvent, [1, 100, 10]);

      // 2. Setup mock memory and user input
      final memory = Uint8List(120);
      provider.setMemoryAccess(
        write: (addr, val, {size = 1}) {
          if (size == 4) {
            final bd = ByteData.view(memory.buffer);
            bd.setUint32(addr, val, Endian.big);
          } else {
            memory[addr] = val;
          }
        },
        read: (addr, {size = 1}) => memory[addr],
      );
      mockDisplay.nextInput = 'Hello';

      // 3. Dispatch select
      // Mock event struct memory (0-15)
      final result = await provider.dispatch(GlkIoSelectors.select, [0]);
      expect(result, equals(0));

      // 4. Verify memory
      // Buffer should contain "Hello"
      expect(String.fromCharCodes(memory.sublist(100, 105)), equals('Hello'));

      // Event struct should contain lineInput event (type 3)
      final bd = ByteData.view(memory.buffer);
      expect(bd.getUint32(0, Endian.big), equals(GlkEventTypes.lineInput));
      expect(bd.getUint32(8, Endian.big), equals(5)); // Length of "Hello"
    });

    test('char input event works', () async {
      // 1. Request char event: window=1
      await provider.dispatch(GlkIoSelectors.requestCharEvent, [1]);

      // 2. Setup mock memory and user input
      final memory = Uint8List(16);
      provider.setMemoryAccess(
        write: (addr, val, {size = 1}) {
          if (size == 4) {
            final bd = ByteData.view(memory.buffer);
            bd.setUint32(addr, val, Endian.big);
          }
        },
        read: (addr, {size = 1}) => 0,
      );
      mockDisplay.nextInput = 'A';

      // 3. Dispatch select
      final result = await provider.dispatch(GlkIoSelectors.select, [0]);
      expect(result, equals(0));

      // 4. Verify event struct
      final bd = ByteData.view(memory.buffer);
      expect(bd.getUint32(0, Endian.big), equals(GlkEventTypes.charInput));
      expect(bd.getUint32(8, Endian.big), equals('A'.codeUnitAt(0)));
    });

    test('gestalt with empty args does not crash', () async {
      // gestalt(charInput, window_type) should return 1 for text buffer (type 3)
      // Note: Glk window types are pair=1, blank=2, textBuffer=3, textGrid=4, graphics=5
      final result = await provider.dispatch(GlkIoSelectors.gestalt, [
        0x01,
        3,
      ]); // charInput, textBuffer
      expect(result, equals(1));
    });
    test('putCharStream writes to memory stream', () async {
      // Setup a memory stream first
      final bufAddr = 0x1000;
      final bufLen = 16;

      // Create memory backed by mock
      final memory = Uint8List(0x2000);
      provider.setMemoryAccess(
        write: (addr, val, {size = 1}) {
          if (size == 1) {
            memory[addr] = val;
          } else if (size == 4) {
            ByteData.view(memory.buffer).setUint32(addr, val, Endian.big);
          }
        },
        read: (addr, {size = 1}) => memory[addr],
      );

      // Open memory stream
      final streamId = await provider.dispatch(
        GlkIoSelectors.streamOpenMemory,
        [bufAddr, bufLen, 1],
      );

      // Write a char 'X' (0x58) to the stream
      final result = await provider.dispatch(GlkIoSelectors.putCharStream, [
        streamId,
        0x58,
      ]);
      expect(result, equals(0));

      // Verify it was written to memory at bufAddr
      expect(memory[bufAddr], equals(0x58));
    });

    test('streamSetCurrent returns previous stream ID', () async {
      // Initial stream is 1001
      final result1 = await provider.dispatch(
        GlkIoSelectors.streamGetCurrent,
        [],
      );
      expect(result1, equals(1001));

      // Open new stream (will be 1002)
      provider.setMemoryAccess(
        write: (_, __, {size = 1}) {},
        read: (_, {size = 1}) => 0,
      ); // Stub memory

      final newStreamId = await provider.dispatch(
        GlkIoSelectors.streamOpenMemory,
        [0x1000, 100, 1],
      );

      // Set current to new stream, should return 1001 (previous)
      final prevStreamId = await provider.dispatch(
        GlkIoSelectors.streamSetCurrent,
        [newStreamId],
      );
      expect(prevStreamId, equals(1001));

      // Verify new current
      final result2 = await provider.dispatch(
        GlkIoSelectors.streamGetCurrent,
        [],
      );
      expect(result2, equals(newStreamId));

      // Restore old stream, should return 1002
      final prevStreamId2 = await provider.dispatch(
        GlkIoSelectors.streamSetCurrent,
        [1001],
      );
      expect(prevStreamId2, equals(newStreamId));
    });
  });
}
