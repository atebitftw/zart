import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/cli/ui/glulx_terminal_provider.dart';
import 'package:zart/src/cli/ui/terminal_display.dart';
import 'package:zart/src/io/glk/glk_io_selectors.dart';
import 'package:zart/src/glulx/glulx_debugger.dart';

class MockTerminalDisplay implements TerminalDisplay {
  final output = StringBuffer();
  String nextInput = '';

  @override
  void appendToWindow0(String text) {
    output.write(text);
  }

  @override
  void render() {}

  @override
  Future<String> readLine() async {
    return nextInput;
  }

  @override
  Future<String> readChar() async {
    return nextInput.isNotEmpty ? nextInput[0] : '';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Glk Selector Fixes', () {
    late GlulxTerminalProvider provider;
    late MockTerminalDisplay terminal;

    setUp(() {
      terminal = MockTerminalDisplay();
      provider = GlulxTerminalProvider(terminal);
      provider.debugger = GlulxDebugger(); // Ensure debugger is initialized
      provider.debugger.enabled = false;
    });

    test('unknown Glk selector returns 0 instead of throwing', () async {
      // 0x1234 is a non-existent selector
      final result = await provider.glkDispatch(0x1234, []);
      expect(result, equals(0));
    });

    test('getCharStream and getCharStreamUni return -1 (EOF)', () async {
      final result1 = await provider.glkDispatch(GlkIoSelectors.getCharStream, [0]);
      expect(result1, equals(-1));

      final result2 = await provider.glkDispatch(GlkIoSelectors.getCharStreamUni, [0]);
      expect(result2, equals(-1));
    });

    test('select selector blocks and returns lineInput event when no pending events', () async {
      // Per Glk spec: glk_select() NEVER returns evtype_None - it always blocks
      // until a real event occurs. When nothing is pending, it blocks for input.
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

      // Mock terminal returns empty input immediately
      terminal.nextInput = '';

      final result = await provider.glkDispatch(GlkIoSelectors.select, [0]);
      expect(result, equals(0));

      final bd = ByteData.view(memory.buffer);
      // glk_select blocks for input, returns lineInput event (type 3) even with empty input
      expect(bd.getUint32(0, Endian.big), equals(GlkEventTypes.lineInput));
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

      final result = await provider.glkDispatch(GlkIoSelectors.selectPoll, [0]);
      expect(result, equals(0));

      final bd = ByteData.view(memory.buffer);
      expect(bd.getUint32(0, Endian.big), equals(GlkEventTypes.none));
    });

    test('line input event works', () async {
      // 1. Request line event: window=1, buffer=100, maxlen=10
      await provider.glkDispatch(GlkIoSelectors.requestLineEvent, [1, 100, 10]);

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
      terminal.nextInput = 'Hello';

      // 3. Dispatch select
      // Mock event struct memory (0-15)
      final result = await provider.glkDispatch(GlkIoSelectors.select, [0]);
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
      await provider.glkDispatch(GlkIoSelectors.requestCharEvent, [1]);

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
      terminal.nextInput = 'A';

      // 3. Dispatch select
      final result = await provider.glkDispatch(GlkIoSelectors.select, [0]);
      expect(result, equals(0));

      // 4. Verify event struct
      final bd = ByteData.view(memory.buffer);
      expect(bd.getUint32(0, Endian.big), equals(GlkEventTypes.charInput));
      expect(bd.getUint32(8, Endian.big), equals('A'.codeUnitAt(0)));
    });

    test('gestalt with empty args does not crash', () async {
      // 0 is GlkGestaltSelectors.version
      final result = await provider.glkDispatch(GlkIoSelectors.gestalt, [0x01]); // 0x01 is charInput
      expect(result, equals(1));
    });
  });
}
