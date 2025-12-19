import 'dart:async';
import 'package:zart/src/cli/ui/terminal_display.dart';
import 'package:zart/src/glulx/glulx_debugger.dart';
import 'package:zart/src/glulx/glulx_gestalt_selectors.dart';
import 'package:zart/src/io/glk/glk_gestalt_selectors.dart' show GlkGestaltSelectors;
import 'package:zart/src/io/glk/glk_io_provider.dart';
import 'package:zart/src/io/glk/glk_io_selectors.dart';

/// IO provider for Glulx interpreter.
class GlulxTerminalProvider implements GlkIoProvider {
  /// The terminal display.
  final TerminalDisplay terminal;

  /// The debugger.
  late final GlulxDebugger debugger;

  /// Creates a new GlulxTerminalProvider.
  GlulxTerminalProvider(this.terminal);

  int _tickCount = 0;

  int get tickCount => _tickCount;

  // Memory access callbacks (set by interpreter)
  void Function(int addr, int value, {int size})? _writeMemory;
  int Function(int addr, {int size})? _readMemory;

  // Pending Event State
  int? _pendingLineEventWin;
  int? _pendingLineEventAddr;
  int? _pendingLineEventMaxLen;
  int? _pendingCharEventWin;

  // Timer state (in milliseconds, 0 = disabled)
  int _timerInterval = 0;
  DateTime? _lastTimerEvent;

  /// Callback to get the current heap start from the VM.
  int Function()? getHeapStart;

  @override
  int vmGestalt(int selector, int arg) {
    switch (selector) {
      case GlulxGestaltSelectors.glulxVersion:
        return 0x00030103; // Glulx spec version 3.1.3
      case GlulxGestaltSelectors.terpVersion:
        return 0x00000100; // Zart Glulx interpreter version 0.1.0
      case GlulxGestaltSelectors.resizeMem:
        return 1; // We support setmemsize
      case GlulxGestaltSelectors.undo:
        return 1; // We support saveundo/restoreundo
      case GlulxGestaltSelectors.ioSystem:
        // arg: 0=null, 1=filter, 2=Glk
        return (arg >= 0 && arg <= 2) ? 1 : 0;
      case GlulxGestaltSelectors.unicode:
        return 1; // We support Unicode
      case GlulxGestaltSelectors.memCopy:
        return 1; // We support mcopy/mzero
      case GlulxGestaltSelectors.mAlloc:
        return 1; // We support malloc/mfree
      case GlulxGestaltSelectors.mAllocHeap:
        return getHeapStart?.call() ?? 0;
      case GlulxGestaltSelectors.acceleration:
        return 0; // We don't support accelerated functions yet
      case GlulxGestaltSelectors.accelFunc:
        return 0; // We don't know any accelerated functions yet
      case GlulxGestaltSelectors.float:
        return 1; // We support floating-point
      case GlulxGestaltSelectors.extUndo:
        return 1; // We support hasundo/discardundo
      case GlulxGestaltSelectors.doubleValue:
        return 1; // We support double-precision
      default:
        return 0; // Unknown selector
    }
  }

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
  void setVMState({int Function()? getHeapStart}) {
    this.getHeapStart = getHeapStart;
  }

  @override
  FutureOr<int> glkDispatch(int selector, List<int> args) {
    if (debugger.enabled && debugger.showInstructions) {
      debugger.bufferedLog(
        '[${debugger.step}] Glk -> selector: 0x${selector.toRadixString(16)}(${GlulxDebugger.glkSelectorNames[selector] ?? 'UNKNOWN'}) args: $args',
      );
      if (debugger.showFlightRecorder) {
        debugger.flightRecorderEvent(
          '[${debugger.step}] Glk -> selector: 0x${selector.toRadixString(16)}(${GlulxDebugger.glkSelectorNames[selector] ?? 'UNKNOWN'}) args: $args',
        );
      }
    }
    final result = _dispatch(selector, args);
    if (result is Future<int>) {
      return result.then((val) {
        if (debugger.enabled) {
          if (debugger.showInstructions) {
            debugger.bufferedLog('Glk -> result: $val');
            if (debugger.showFlightRecorder) {
              debugger.flightRecorderEvent('GlkResult: $val');
            }
          }
        }

        return val;
      });
    }
    if (debugger.enabled) {
      if (debugger.showInstructions) {
        debugger.bufferedLog('Glk -> result: $result');
        if (debugger.showFlightRecorder) {
          debugger.flightRecorderEvent('GlkResult: $result');
        }
      }
    }
    return result;
  }

  FutureOr<int> _dispatch(int selector, List<int> args) {
    switch (selector) {
      // Handle glk dispatch (gidispa) - selector 0 means the real selector is in args[0]
      case 0:
        if (args.isEmpty) {
          debugger.bufferedLog('[${debugger.step}] WARNING: glk dispatch with no args');
          return 0;
        }
        final realSelector = args[0];
        final realArgs = args.length > 1 ? args.sublist(1) : <int>[];
        if (debugger.enabled) {
          if (debugger.showInstructions) {
            debugger.bufferedLog(
              '[${debugger.step}] glk dispatch -> unwrapping selector: 0x${realSelector.toRadixString(16)} args: $realArgs',
            );
            if (debugger.showFlightRecorder) {
              debugger.flightRecorderEvent(
                '[${debugger.step}] glk dispatch -> unwrapping selector: 0x${realSelector.toRadixString(16)} args: $realArgs',
              );
            }
          }
        }
        return _dispatch(realSelector, realArgs);

      case GlkIoSelectors.tick:
        // yield back to Dart's event loop, per the Glk spec
        return Future.delayed(const Duration(milliseconds: 1)).then((_) {
          _tickCount++;
          return 0;
        });
      case GlkIoSelectors.gestalt:
        return _handleGlkGestalt(args[0], args.length > 1 ? args.sublist(1) : <int>[]);
      case GlkIoSelectors.putChar:
        terminal.appendToWindow0(String.fromCharCode(args[0]));
        if (args[0] == 10) terminal.render();
        return 0;
      case GlkIoSelectors.putCharStream:
        terminal.appendToWindow0(String.fromCharCode(args[1]));
        if (args[1] == 10) terminal.render();
        return 0;
      case GlkIoSelectors.putCharUni:
        terminal.appendToWindow0(String.fromCharCode(args[0]));
        if (args[0] == 10) terminal.render();
        return 0;
      case GlkIoSelectors.getCharStream:
      case GlkIoSelectors.getCharStreamUni:
        return -1; // EOF for now

      case GlkIoSelectors.charToLower:
        // Glk spec: glk_char_to_lower(ch) returns lowercase of ch
        // For Latin-1 characters, we can use Dart's toLowerCase
        final ch = args[0];
        if (ch >= 0x41 && ch <= 0x5A) {
          // A-Z -> a-z
          return ch + 32;
        } else if (ch >= 0xC0 && ch <= 0xDE && ch != 0xD7) {
          // Latin-1 uppercase accented (except multiplication sign)
          return ch + 32;
        }
        return ch; // Already lowercase or not a letter

      case GlkIoSelectors.charToUpper:
        // Glk spec: glk_char_to_upper(ch) returns uppercase of ch
        final chUp = args[0];
        if (chUp >= 0x61 && chUp <= 0x7A) {
          // a-z -> A-Z
          return chUp - 32;
        } else if (chUp >= 0xE0 && chUp <= 0xFE && chUp != 0xF7) {
          // Latin-1 lowercase accented (except division sign)
          return chUp - 32;
        }
        return chUp; // Already uppercase or not a letter

      case GlkIoSelectors.putString:
      case GlkIoSelectors.putStringUni:
        final s = _readString(args[0], selector == GlkIoSelectors.putStringUni);
        terminal.appendToWindow0(s);
        if (s.contains('\n')) terminal.render();
        return 0;

      case GlkIoSelectors.putStringStream:
      case GlkIoSelectors.putStringStreamUni:
        final s = _readString(args[1], selector == GlkIoSelectors.putStringStreamUni);
        terminal.appendToWindow0(s);
        if (s.contains('\n')) terminal.render();
        return 0;

      case GlkIoSelectors.putBuffer:
      case GlkIoSelectors.putBufferUni:
        final s = _readBuffer(args[0], args[1], selector == GlkIoSelectors.putBufferUni);
        terminal.appendToWindow0(s);
        if (s.contains('\n')) terminal.render();
        return 0;

      case GlkIoSelectors.putBufferStream:
      case GlkIoSelectors.putBufferStreamUni:
        final s = _readBuffer(args[1], args[2], selector == GlkIoSelectors.putBufferStreamUni);
        terminal.appendToWindow0(s);
        if (s.contains('\n')) terminal.render();
        return 0;

      case GlkIoSelectors.setStyle:
      case GlkIoSelectors.setStyleStream:
        return 0;

      case GlkIoSelectors.windowOpen:
        return 1;
      case GlkIoSelectors.windowClose:
        return 0;
      case GlkIoSelectors.windowGetSize:
        if (args.length > 1 && args[1] != 0) writeMemory(args[1], 80, size: 4);
        if (args.length > 2 && args[2] != 0) writeMemory(args[2], 24, size: 4);
        return 0;
      case GlkIoSelectors.setWindow:
        return 0;
      case GlkIoSelectors.windowClear:
        return 0;
      case GlkIoSelectors.windowMoveCursor:
        return 0;

      case GlkIoSelectors.streamOpenFile:
      case GlkIoSelectors.streamOpenMemory:
      case GlkIoSelectors.streamOpenResource:
      case GlkIoSelectors.streamOpenFileUni:
      case GlkIoSelectors.streamOpenMemoryUni:
      case GlkIoSelectors.streamOpenResourceUni:
        return 1001; // Fake stream handle

      case GlkIoSelectors.streamClose:
        return 0;
      case GlkIoSelectors.streamSetCurrent:
        return 0;
      case GlkIoSelectors.streamGetCurrent:
        return 1001;
      case GlkIoSelectors.streamGetPosition:
        return 0;
      case GlkIoSelectors.streamSetPosition:
        return 0;

      case GlkIoSelectors.filerefCreateTemp:
      case GlkIoSelectors.filerefCreateByName:
      case GlkIoSelectors.filerefCreateByPrompt:
      case GlkIoSelectors.filerefCreateByFileUni:
      case GlkIoSelectors.filerefCreateByNameUni:
      case GlkIoSelectors.filerefCreateByPromptUni:
        return 2001; // Fake fileref handle

      case GlkIoSelectors.filerefDestroy:
        return 0;
      case GlkIoSelectors.filerefDeleteFile:
        return 0;
      case GlkIoSelectors.filerefDoesFileExist:
        return 0;

      case GlkIoSelectors.selectPoll:
        _writeEventStruct(args[0], GlkEventTypes.none, 0, 0, 0);
        return 0;

      case GlkIoSelectors.windowIterate:
        if (args[0] == 0) {
          if (args.length > 1 && args[1] != 0) writeMemory(args[1], 100, size: 4);
          return 100;
        }
        return 0;

      case GlkIoSelectors.streamIterate:
        if (args[0] == 0) {
          if (args.length > 1 && args[1] != 0) writeMemory(args[1], 200, size: 4);
          return 200;
        }
        return 0;

      case GlkIoSelectors.filerefIterate:
        if (args[0] == 0) {
          if (args.length > 1 && args[1] != 0) writeMemory(args[1], 300, size: 4);
          return 300;
        }
        return 0;

      case GlkIoSelectors.stylehintSet:
      case GlkIoSelectors.stylehintClear:
      case GlkIoSelectors.styleDistinguish:
      case GlkIoSelectors.styleMeasure:
        return 0;

      case GlkIoSelectors.requestLineEvent:
      case GlkIoSelectors.requestLineEventUni:
        if (debugger.enabled && debugger.showFlightRecorder) {
          debugger.flightRecorderEvent('requestLineEvent: win=${args[0]}, buf=${args[1]}, maxlen=${args[2]}');
        }
        _pendingLineEventWin = args[0];
        _pendingLineEventAddr = args[1];
        _pendingLineEventMaxLen = args[2];
        return 0;
      case GlkIoSelectors.requestCharEvent:
      case GlkIoSelectors.requestCharEventUni:
        debugger.bufferedLog('requestCharEvent: win=${args[0]}');
        _pendingCharEventWin = args[0];
        return 0;
      case GlkIoSelectors.cancelLineEvent:
        _pendingLineEventWin = null;
        _pendingLineEventAddr = null;
        _pendingLineEventMaxLen = null;
        return 0;
      case GlkIoSelectors.cancelCharEvent:
        _pendingCharEventWin = null;
        return 0;
      case GlkIoSelectors.select:
        return _handleSelect(args[0]);

      case GlkIoSelectors.requestTimerEvents:
        // args[0] = milliseconds (0 = disable timer)
        _timerInterval = args[0];
        if (_timerInterval > 0) {
          _lastTimerEvent = DateTime.now();
        } else {
          _lastTimerEvent = null;
        }
        return 0;

      default:
        // Unknown selector already logged in glkDispatch()
        return 0;
    }
  }

  /// Handles glk_select: blocks until an event is available.
  /// Per Glk spec, glk_select() should NEVER return evtype_None.
  Future<int> _handleSelect(int eventAddr) async {
    // If line input is pending, wait for it
    if (_pendingLineEventAddr != null) {
      terminal.render();
      final line = await terminal.readLine();

      // Write to game memory
      var p = _pendingLineEventAddr!;
      final max = _pendingLineEventMaxLen!;

      int count = 0;
      for (var i = 0; i < line.length && i < max; i++) {
        writeMemory(p + i, line.codeUnitAt(i), size: 1);
        count++;
      }

      _writeEventStruct(eventAddr, GlkEventTypes.lineInput, _pendingLineEventWin!, count, 0);

      _pendingLineEventWin = null;
      _pendingLineEventAddr = null;
      _pendingLineEventMaxLen = null;
      return 0;
    }

    // If char input is pending, wait for it
    if (_pendingCharEventWin != null) {
      terminal.render();
      final char = await terminal.readChar();
      final code = char.isNotEmpty ? char.codeUnitAt(0) : 0;

      _writeEventStruct(eventAddr, GlkEventTypes.charInput, _pendingCharEventWin!, code, 0);
      _pendingCharEventWin = null;
      return 0;
    }

    // If timer is enabled, wait for the timer interval and return timer event
    if (_timerInterval > 0) {
      final now = DateTime.now();
      final elapsed = _lastTimerEvent != null ? now.difference(_lastTimerEvent!).inMilliseconds : 0;
      final remaining = _timerInterval - elapsed;

      if (remaining > 0) {
        await Future<void>.delayed(Duration(milliseconds: remaining));
      }

      _lastTimerEvent = DateTime.now();
      _writeEventStruct(eventAddr, GlkEventTypes.timer, 0, 0, 0);
      return 0;
    }

    // No events are pending and no timer is active.
    // Per Glk spec, glk_select should block forever waiting for an event.
    // In practice, for a terminal game, we'll wait for user input.
    // This renders the display and waits for any input.
    terminal.render();
    debugger.bufferedLog('[${debugger.step}] glk_select: No events pending, blocking for user input...');
    final line = await terminal.readLine();

    // The game didn't request line input, but the user typed something.
    // This is an unusual situation - return the input as a line event anyway
    // since glk_select must return a real event.
    // Write to address 0 (probably wrong, but game should have requested input)
    _writeEventStruct(eventAddr, GlkEventTypes.lineInput, 1, line.length, 0);
    return 0;
  }

  String _readString(int addr, bool unicode) {
    if (addr == 0) return "";
    final sb = StringBuffer();
    var p = addr;
    while (true) {
      final ch = unicode ? readMemory(p, size: 4) : readMemory(p, size: 1);
      if (ch == 0) break;
      sb.writeCharCode(ch);
      p += unicode ? 4 : 1;
    }
    return sb.toString();
  }

  String _readBuffer(int addr, int len, bool unicode) {
    if (addr == 0) return "";
    final sb = StringBuffer();
    for (var i = 0; i < len; i++) {
      final ch = unicode ? readMemory(addr + i * 4, size: 4) : readMemory(addr + i, size: 1);
      sb.writeCharCode(ch);
    }
    return sb.toString();
  }

  void _writeEventStruct(int addr, int type, int win, int val1, int val2) {
    writeMemory(addr, type, size: 4);
    writeMemory(addr + 4, win, size: 4);
    writeMemory(addr + 8, val1, size: 4);
    writeMemory(addr + 12, val2, size: 4);
  }

  FutureOr<int> _handleGlkGestalt(int gestaltSelector, List<int> args) {
    if (args.isEmpty && gestaltSelector != GlkGestaltSelectors.version) {
      // Most gestalt calls expect a second argument (e.g. for charInput, which character).
      // If empty, we just return 0 for now unless it's version.
    }
    switch (gestaltSelector) {
      case GlkGestaltSelectors.version:
        return 0x00070600;
      case GlkGestaltSelectors.mouseInput:
        return 0;
      case GlkGestaltSelectors.lineInput:
        return 1;
      case GlkGestaltSelectors.charInput:
        return 1;
      case GlkGestaltSelectors.unicode:
        return 1;
      case GlkGestaltSelectors.sound:
      case GlkGestaltSelectors.soundVolume:
        return 0;
      default:
        debugger.bufferedLog(
          '[${debugger.step}] Unknown Glk gestalt selector: ${GlulxDebugger.gestaltSelectorNames[gestaltSelector]}',
        );
        return 0;
    }
  }
}
