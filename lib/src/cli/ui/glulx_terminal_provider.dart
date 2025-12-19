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

  GlulxTerminalProvider(this.terminal) {
    // ID 1001 is the default stream (terminal window0)
    _streams[1001] = _GlkStream(id: 1001, type: 1);
  }

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

  // Stack access callbacks (set by interpreter)
  // Per Glk spec, address 0xFFFFFFFF means 'use stack'
  void Function(int val) _pushToStack = (v) {};
  int Function() _popFromStack = () => 0;

  final Map<int, _GlkStream> _streams = {};
  int _nextStreamId = 1002;
  int _currentStreamId = 1001;

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
  void pushToStack(int value) {
    _pushToStack.call(value);
  }

  @override
  int popFromStack() {
    return _popFromStack.call();
  }

  @override
  void setStackAccess({required void Function(int value) push, required int Function() pop}) {
    _pushToStack = push;
    _popFromStack = pop;
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
        return _dispatch(realSelector, realArgs);

      case GlkIoSelectors.tick:
        return Future.delayed(const Duration(milliseconds: 1)).then((_) {
          _tickCount++;
          return 0;
        });
      case GlkIoSelectors.gestalt:
        return _handleGlkGestalt(args[0], args.length > 1 ? args.sublist(1) : <int>[]);

      case GlkIoSelectors.putChar:
        _writeToStream(_currentStreamId, args[0]);
        return 0;
      case GlkIoSelectors.putCharStream:
        _writeToStream(args[0], args[1]);
        return 0;
      case GlkIoSelectors.putCharUni:
        _writeToStream(_currentStreamId, args[0]);
        return 0;
      case GlkIoSelectors.putCharStreamUni:
        _writeToStream(args[0], args[1]);
        return 0;

      case GlkIoSelectors.getCharStream:
      case GlkIoSelectors.getCharStreamUni:
        return -1; // EOF for now

      case GlkIoSelectors.charToLower:
        final ch = args[0];
        if (ch >= 0x41 && ch <= 0x5A) return ch + 32;
        if (ch >= 0xC0 && ch <= 0xDE && ch != 0xD7) return ch + 32;
        return ch;

      case GlkIoSelectors.charToUpper:
        final chUp = args[0];
        if (chUp >= 0x61 && chUp <= 0x7A) return chUp - 32;
        if (chUp >= 0xE0 && chUp <= 0xFE && chUp != 0xF7) return chUp - 32;
        return chUp;

      case GlkIoSelectors.putString:
      case GlkIoSelectors.putStringUni:
        _writeStringToStream(_currentStreamId, args[0], selector == GlkIoSelectors.putStringUni);
        return 0;

      case GlkIoSelectors.putStringStream:
      case GlkIoSelectors.putStringStreamUni:
        _writeStringToStream(args[0], args[1], selector == GlkIoSelectors.putStringStreamUni);
        return 0;

      case GlkIoSelectors.putBuffer:
      case GlkIoSelectors.putBufferUni:
        _writeBufferToStream(_currentStreamId, args[0], args[1], selector == GlkIoSelectors.putBufferUni);
        return 0;

      case GlkIoSelectors.putBufferStream:
      case GlkIoSelectors.putBufferStreamUni:
        _writeBufferToStream(args[0], args[1], args[2], selector == GlkIoSelectors.putBufferStreamUni);
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
      case GlkIoSelectors.streamOpenFileUni:
      case GlkIoSelectors.streamOpenResource:
      case GlkIoSelectors.streamOpenResourceUni:
        return 1001; // Fake other streams for now

      case GlkIoSelectors.streamOpenMemory:
      case GlkIoSelectors.streamOpenMemoryUni:
        final id = _nextStreamId++;
        final stream = _GlkStream(
          id: id,
          type: 2,
          bufAddr: args[0],
          bufLen: args[1],
          mode: args[2],
          isUnicode: selector == GlkIoSelectors.streamOpenMemoryUni,
        );
        _streams[id] = stream;
        return id;

      case GlkIoSelectors.streamClose:
        final streamId = args[0];
        final resultAddr = args.length > 1 ? args[1] : 0;
        final stream = _streams.remove(streamId);
        if (stream == null) return 0;

        if (resultAddr == -1 || resultAddr == 0xFFFFFFFF) {
          pushToStack(stream.writeCount);
          pushToStack(stream.readCount);
        } else if (resultAddr != 0) {
          writeMemory(resultAddr, stream.readCount, size: 4);
          writeMemory(resultAddr + 4, stream.writeCount, size: 4);
        }
        return 0;

      case GlkIoSelectors.streamSetCurrent:
        _currentStreamId = args[0];
        return 0;
      case GlkIoSelectors.streamGetCurrent:
        return _currentStreamId;
      case GlkIoSelectors.streamGetPosition:
        return _streams[args[0]]?.pos ?? 0;
      case GlkIoSelectors.streamSetPosition:
        final str = _streams[args[0]];
        if (str != null) {
          final pos = args[1];
          final seekMode = args[2];
          if (seekMode == 0)
            str.pos = pos;
          else if (seekMode == 1)
            str.pos += pos;
          else if (seekMode == 2)
            str.pos = str.bufLen + pos;
        }
        return 0;

      case GlkIoSelectors.filerefCreateTemp:
      case GlkIoSelectors.filerefCreateByName:
      case GlkIoSelectors.filerefCreateByPrompt:
      case GlkIoSelectors.filerefCreateByFileUni:
      case GlkIoSelectors.filerefCreateByNameUni:
      case GlkIoSelectors.filerefCreateByPromptUni:
        return 2001;

      case GlkIoSelectors.filerefDestroy:
      case GlkIoSelectors.filerefDeleteFile:
      case GlkIoSelectors.filerefDoesFileExist:
        return 0;

      case GlkIoSelectors.selectPoll:
        _writeEventStruct(args[0], GlkEventTypes.none, 0, 0, 0);
        return 0;

      case GlkIoSelectors.windowIterate:
      case GlkIoSelectors.streamIterate:
      case GlkIoSelectors.filerefIterate:
        return 0;

      case GlkIoSelectors.stylehintSet:
      case GlkIoSelectors.stylehintClear:
      case GlkIoSelectors.styleDistinguish:
      case GlkIoSelectors.styleMeasure:
        return 0;

      case GlkIoSelectors.requestLineEvent:
      case GlkIoSelectors.requestLineEventUni:
        _pendingLineEventWin = args[0];
        _pendingLineEventAddr = args[1];
        _pendingLineEventMaxLen = args[2];
        return 0;
      case GlkIoSelectors.requestCharEvent:
      case GlkIoSelectors.requestCharEventUni:
        _pendingCharEventWin = args[0];
        return 0;
      case GlkIoSelectors.cancelLineEvent:
        _pendingLineEventWin = null;
        return 0;
      case GlkIoSelectors.cancelCharEvent:
        _pendingCharEventWin = null;
        return 0;
      case GlkIoSelectors.select:
        return _handleSelect(args[0]);

      case GlkIoSelectors.requestTimerEvents:
        _timerInterval = args[0];
        _lastTimerEvent = _timerInterval > 0 ? DateTime.now() : null;
        return 0;

      default:
        return 0;
    }
  }

  void _writeToStream(int streamId, int value) {
    if (streamId == 0) return;
    final stream = _streams[streamId];
    if (stream == null) return;

    stream.writeCount++;

    if (stream.type == 1) {
      terminal.appendToWindow0(String.fromCharCode(value));
      if (value == 10) terminal.render();
    } else if (stream.type == 2) {
      if (stream.pos < stream.bufLen) {
        if (stream.isUnicode) {
          writeMemory(stream.bufAddr + (stream.pos * 4), value, size: 4);
        } else {
          writeMemory(stream.bufAddr + stream.pos, value & 0xFF, size: 1);
        }
        stream.pos++;
      }
    }
  }

  void _writeStringToStream(int streamId, int addr, bool unicode) {
    if (addr == 0) return;
    var p = addr;
    while (true) {
      final ch = unicode ? readMemory(p, size: 4) : readMemory(p, size: 1);
      if (ch == 0) break;
      _writeToStream(streamId, ch);
      p += unicode ? 4 : 1;
    }
  }

  void _writeBufferToStream(int streamId, int addr, int len, bool unicode) {
    if (addr == 0) return;
    for (var i = 0; i < len; i++) {
      final ch = unicode ? readMemory(addr + i * 4, size: 4) : readMemory(addr + i, size: 1);
      _writeToStream(streamId, ch);
    }
  }

  Future<int> _handleSelect(int eventAddr) async {
    if (_pendingLineEventAddr != null) {
      terminal.render();
      final line = await terminal.readLine();
      var count = 0;
      for (var i = 0; i < line.length && i < _pendingLineEventMaxLen!; i++) {
        writeMemory(_pendingLineEventAddr! + i, line.codeUnitAt(i), size: 1);
        count++;
      }
      _writeEventStruct(eventAddr, GlkEventTypes.lineInput, _pendingLineEventWin!, count, 0);
      _pendingLineEventAddr = null;
      return 0;
    }

    if (_pendingCharEventWin != null) {
      terminal.render();
      final char = await terminal.readChar();
      final code = char.isNotEmpty ? char.codeUnitAt(0) : 0;
      _writeEventStruct(eventAddr, GlkEventTypes.charInput, _pendingCharEventWin!, code, 0);
      _pendingCharEventWin = null;
      return 0;
    }

    if (_timerInterval > 0) {
      final elapsed = _lastTimerEvent != null ? DateTime.now().difference(_lastTimerEvent!).inMilliseconds : 0;
      final remaining = _timerInterval - elapsed;
      if (remaining > 0) await Future<void>.delayed(Duration(milliseconds: remaining));
      _lastTimerEvent = DateTime.now();
      _writeEventStruct(eventAddr, GlkEventTypes.timer, 0, 0, 0);
      return 0;
    }

    terminal.render();
    final line = await terminal.readLine();
    _writeEventStruct(eventAddr, GlkEventTypes.lineInput, 1, line.length, 0);
    return 0;
  }

  void _writeEventStruct(int addr, int type, int win, int val1, int val2) {
    writeMemory(addr, type, size: 4);
    writeMemory(addr + 4, win, size: 4);
    writeMemory(addr + 8, val1, size: 4);
    writeMemory(addr + 12, val2, size: 4);
  }

  int _handleGlkGestalt(int gestaltSelector, List<int> args) {
    switch (gestaltSelector) {
      case GlkGestaltSelectors.version:
        return 0x00070600;
      case GlkGestaltSelectors.lineInput:
        return 1;
      case GlkGestaltSelectors.charInput:
        return 1;
      case GlkGestaltSelectors.unicode:
        return 1;
      default:
        return 0;
    }
  }
}

class _GlkStream {
  final int id;
  final int type;
  final int mode;
  final int bufAddr;
  final int bufLen;
  final bool isUnicode;

  int writeCount = 0;
  int readCount = 0;
  int pos = 0;

  _GlkStream({
    required this.id,
    required this.type,
    this.mode = 1,
    this.bufAddr = 0,
    this.bufLen = 0,
    this.isUnicode = false,
  });
}
