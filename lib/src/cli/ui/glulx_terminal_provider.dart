import 'package:zart/src/cli/ui/terminal_display.dart';
import 'package:zart/src/glulx/glulx_debugger.dart';
import 'package:zart/src/glulx/glulx_exception.dart';
import 'package:zart/src/io/glk/glk_gestalt_selectors.dart'
    show GlkGestaltSelectors;
import 'package:zart/src/io/glk/glk_io_provider.dart';
import 'package:zart/src/io/glk/glk_io_selectors.dart';
import 'package:zart/src/logging.dart' show log;

/// IO provider for Glulx interpreter.
class GlulxTerminalProvider implements GlkIoProvider {
  /// The terminal display.
  final TerminalDisplay terminal;

  /// Creates a new GlulxTerminalProvider.
  GlulxTerminalProvider(this.terminal);

  int _tickCount = 0;

  int get tickCount => _tickCount;

  // --- Input State Tracking ---
  // Pending line input request
  int? _pendingLineInputWindow;
  int? _pendingLineInputBuffer;
  int? _pendingLineInputMaxLen;

  // Pending char input request
  int? _pendingCharInputWindow;

  // Memory access callbacks (set by interpreter)
  void Function(int addr, int value, {int size})? _writeMemory;
  int Function(int addr, {int size})? _readMemory;

  @override
  void writeMemory(int addr, int value, {int size = 1}) {
    _writeMemory?.call(addr, value, size: size);
  }

  @override
  int readMemory(int addr, {int size = 1}) {
    return _readMemory?.call(addr, size: size) ?? 0;
  }

  @override
  void setMemoryAccess({
    required void Function(int addr, int value, {int size}) write,
    required int Function(int addr, {int size}) read,
  }) {
    _writeMemory = write;
    _readMemory = read;
  }

  @override
  Future<int> glkDispatch(int selector, List<int> args) async {
    switch (selector) {
      case GlkIoSelectors.tick:
        // yield back to Dart's event loop, per the Glk spec
        await Future.delayed(const Duration(milliseconds: 1));
        _tickCount++;
        return 0;
      case GlkIoSelectors.gestalt:
        return await _gestaltHandler(args[0], args.sublist(1));
      case GlkIoSelectors.putChar:
        // glk_put_char(ch) - output single character
        terminal.appendToWindow0(String.fromCharCode(args[0]));
        if (args[0] == 10) terminal.render(); // Render on newline
        return 0;
      case GlkIoSelectors.putCharStream:
        // glk_put_char_stream(str, ch) - args[0] is stream, args[1] is char
        terminal.appendToWindow0(String.fromCharCode(args[1]));
        if (args[1] == 10) terminal.render(); // Render on newline
        return 0;
      case GlkIoSelectors.putCharUni:
        // glk_put_char_uni(ch) - Unicode character output
        terminal.appendToWindow0(String.fromCharCode(args[0]));
        if (args[0] == 10) terminal.render(); // Render on newline
        return 0;
      case GlkIoSelectors.getCharStream:
        // Currently used by interpreter for char output (args[0]=stream, args[1]=char)
        terminal.appendToWindow0(String.fromCharCode(args[1]));
        if (args[1] == 10) terminal.render(); // Render on newline
        return 0;
      // ...
      case GlkGestaltSelectors.unicode:
        // We support unicode (Dart strings do)
        return 1;
      case GlkIoSelectors.windowOpen:
        // glk_window_open(split, method, size, wintype, rock) -> window
        // Stub: return fake window ID, all output goes to window0 for now
        return 1;
      case GlkIoSelectors.setWindow:
        // glk_set_window(win) - set current window for output
        // Stub: ignore, all output goes to window0 for now
        return 0;

      // --- Input Handling ---
      case GlkIoSelectors.requestLineEvent:
        // glk_request_line_event(win, buf, maxlen, initlen)
        // args[0] = window, args[1] = buffer addr, args[2] = maxlen, args[3] = initlen
        _pendingLineInputWindow = args[0];
        _pendingLineInputBuffer = args[1];
        _pendingLineInputMaxLen = args[2];
        // initlen is ignored for now (could pre-fill buffer)
        return 0;

      case GlkIoSelectors.requestCharEvent:
        // glk_request_char_event(win)
        _pendingCharInputWindow = args[0];
        return 0;

      case GlkIoSelectors.cancelLineEvent:
        // glk_cancel_line_event(win, event) - cancel pending line input
        // args[0] = window, args[1] = event address (may be 0/null)
        if (_pendingLineInputWindow != null) {
          // If event address provided, fill it with evtype_None
          if (args.length > 1 && args[1] != 0) {
            _writeEventStruct(args[1], GlkEventTypes.none, 0, 0, 0);
          }
          _pendingLineInputWindow = null;
          _pendingLineInputBuffer = null;
          _pendingLineInputMaxLen = null;
        }
        return 0;

      case GlkIoSelectors.cancelCharEvent:
        // glk_cancel_char_event(win) - cancel pending char input
        _pendingCharInputWindow = null;
        return 0;

      case GlkIoSelectors.select:
        // glk_select(event) - BLOCKING wait for input
        // args[0] = event structure address
        final eventAddr = args[0];

        // Render the terminal before waiting for input
        terminal.render();

        if (_pendingLineInputWindow != null) {
          // Wait for line input
          final line = await terminal.readLine();

          // Write line bytes to game memory at buffer address
          final bufAddr = _pendingLineInputBuffer!;
          final maxLen = _pendingLineInputMaxLen!;
          final lineLen = line.length > maxLen ? maxLen : line.length;

          for (int i = 0; i < lineLen; i++) {
            writeMemory(bufAddr + i, line.codeUnitAt(i), size: 1);
          }

          // Fill event structure: type=lineInput(3), win, val1=charCount, val2=0
          _writeEventStruct(
            eventAddr,
            GlkEventTypes.lineInput,
            _pendingLineInputWindow!,
            lineLen,
            0,
          );

          // Echo the input line to the display
          terminal.appendToWindow0('$line\n');

          // Clear pending request
          _pendingLineInputWindow = null;
          _pendingLineInputBuffer = null;
          _pendingLineInputMaxLen = null;
        } else if (_pendingCharInputWindow != null) {
          // Wait for character input
          final charStr = await terminal.readChar();
          final charCode = charStr.isNotEmpty ? charStr.codeUnitAt(0) : 0;

          // Fill event structure: type=charInput(2), win, val1=charCode, val2=0
          _writeEventStruct(
            eventAddr,
            GlkEventTypes.charInput,
            _pendingCharInputWindow!,
            charCode,
            0,
          );

          // Clear pending request
          _pendingCharInputWindow = null;
        } else {
          // No input pending - return evtype_None (shouldn't normally happen)
          log.warning('glk_select called with no pending input request');
          _writeEventStruct(eventAddr, GlkEventTypes.none, 0, 0, 0);
        }
        return 0;

      case GlkIoSelectors.selectPoll:
        // glk_select_poll(event) - non-blocking check for events
        // args[0] = event structure address
        // We don't have timer events etc, so just return none
        _writeEventStruct(args[0], GlkEventTypes.none, 0, 0, 0);
        return 0;

      case GlkIoSelectors.stylehintSet:
      case GlkIoSelectors.stylehintClear:
        // Stub: do nothing
        return 0;

      case GlkIoSelectors.styleDistinguish:
        // Stub: return 0 (indistinguishable in basic terminal)
        return 0;

      case GlkIoSelectors.styleMeasure:
        // Stub: return 0 (cannot measure)
        return 0;

      default:
        throw GlulxException(
          'GlulxTerminalProvider -> Unknown selector: 0x${selector.toRadixString(16)}',
        );
    }
  }

  /// Write a Glk event structure to memory.
  /// Event structure: type(4), win(4), val1(4), val2(4) = 16 bytes
  void _writeEventStruct(int addr, int type, int win, int val1, int val2) {
    writeMemory(addr, type, size: 4);
    writeMemory(addr + 4, win, size: 4);
    writeMemory(addr + 8, val1, size: 4);
    writeMemory(addr + 12, val2, size: 4);
  }

  Future<int> _gestaltHandler(int gestaltSelector, List<int> args) async {
    switch (gestaltSelector) {
      case GlkGestaltSelectors.version:
        // We will try to support the latest version at the time of this implementation.
        // The current version of the API is: 0.7.6 (0x00070600)
        return 0x00070600;
      case GlkGestaltSelectors.mouseInput:
        return 1;
      case GlkGestaltSelectors.lineInput:
        // We support line input for all characters
        return 1;
      case GlkGestaltSelectors.charInput:
        // We support char input
        return 1;
      case GlkGestaltSelectors.unicode:
        // Temporarily disable unicode to see if it speeds up startup (skips table verify?)
        return 0;
      case GlkGestaltSelectors.sound:
      case GlkGestaltSelectors.soundVolume:
        // No sound support
        return 0;
      default:
        log.warning(
          'GlulxTerminalProvider -> Unknown gestalt selector: ${GlulxDebugger.gestaltSelectorNames[gestaltSelector]}',
        );
        return 0;
    }
  }
}
