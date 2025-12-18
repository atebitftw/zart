import 'dart:async';
import 'package:zart/src/cli/ui/terminal_display.dart';
import 'package:zart/src/glulx/glulx_debugger.dart';
import 'package:zart/src/glulx/glulx_exception.dart';
import 'package:zart/src/io/glk/glk_gestalt_selectors.dart' show GlkGestaltSelectors;
import 'package:zart/src/io/glk/glk_io_provider.dart';
import 'package:zart/src/io/glk/glk_io_selectors.dart';
import 'package:zart/src/logging.dart' show log;
// GlkEventTypes is in glk_io_selectors.dart

/// IO provider for Glulx interpreter.
class GlulxTerminalProvider implements GlkIoProvider {
  /// The terminal display.
  final TerminalDisplay terminal;

  /// Creates a new GlulxTerminalProvider.
  GlulxTerminalProvider(this.terminal);

  int _tickCount = 0;

  int get tickCount => _tickCount;

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
  FutureOr<int> glkDispatch(int selector, List<int> args) {
    switch (selector) {
      case GlkIoSelectors.tick:
        // yield back to Dart's event loop, per the Glk spec
        return Future.delayed(const Duration(milliseconds: 1)).then((_) {
          _tickCount++;
          return 0;
        });
      case GlkIoSelectors.gestalt:
        final gestaltArgs = args.length > 1 ? args.sublist(1) : <int>[];
        return _gestaltHandler(args[0], gestaltArgs);
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
        throw GlulxException("requestLineEvent not implemented");

      case GlkIoSelectors.requestCharEvent:
        throw GlulxException("requestCharEvent not implemented");

      case GlkIoSelectors.cancelLineEvent:
        throw GlulxException("cancelLineEvent not implemented");

      case GlkIoSelectors.cancelCharEvent:
        throw GlulxException("cancelCharEvent not implemented");

      case GlkIoSelectors.select:
        throw GlulxException("select not implemented");

      case GlkIoSelectors.selectPoll:
        // glk_select_poll(event) - non-blocking check for events
        // args[0] = event structure address
        // We don't have timer events etc, so just return none
        _writeEventStruct(args[0], GlkEventTypes.none, 0, 0, 0);
        return 0;

      case GlkIoSelectors.windowIterate:
        // glk_window_iterate(win, rockptr) -> next_win
        // For now, only return window 1 once
        if (args[0] == 0) {
          if (args[1] != 0) writeMemory(args[1], 100, size: 4); // window rock
          return 1;
        }
        return 0;

      case GlkIoSelectors.streamIterate:
        // glk_stream_iterate(str, rockptr) -> next_str
        // For now, only return stream 1 once
        if (args[0] == 0) {
          if (args[1] != 0) writeMemory(args[1], 200, size: 4); // stream rock
          return 1;
        }
        return 0;

      case GlkIoSelectors.filerefIterate:
        // glk_fileref_iterate(fref, rockptr) -> next_fref
        // No files yet
        return 0;

      case GlkIoSelectors.filerefCreateByPrompt:
      case GlkIoSelectors.filerefCreateByPromptUni:
        // glk_fileref_create_by_prompt(usage, fmode, rock) -> fref
        // Not supporting actual file prompts yet
        return 0;

      case GlkIoSelectors.schannelIterate:
        // glk_schannel_iterate(chan, rockptr) -> next_chan
        // No sound channels yet
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
        throw GlulxException('GlulxTerminalProvider -> Unknown selector: 0x${selector.toRadixString(16)}');
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

  FutureOr<int> _gestaltHandler(int gestaltSelector, List<int> args) {
    switch (gestaltSelector) {
      case GlkGestaltSelectors.version:
        // We will try to support the latest version at the time of this implementation.
        // The current version of the API is: 0.7.6 (0x00070600)
        return 0x00070600;
      case GlkGestaltSelectors.mouseInput:
        // no mouse support just yet
        return 0;
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
