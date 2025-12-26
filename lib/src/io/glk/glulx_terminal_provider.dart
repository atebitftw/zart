import 'dart:async';
import 'dart:typed_data';
import 'package:zart/src/zart_debugger.dart' show ZartDebugger, debugger;
import 'package:zart/src/glulx/glulx_gestalt_selectors.dart';
import 'package:zart/src/io/glk/glk_gestalt_selectors.dart' show GlkGestaltSelectors;
import 'package:zart/src/io/glk/glk_io_selectors.dart';
import 'package:zart/src/io/glk/glk_provider.dart';
import 'package:zart/src/io/glk/glk_screen_model.dart';
import 'package:zart/src/io/glk/glk_terminal_display.dart' show GlkTerminalDisplay;
import 'package:zart/src/io/glk/glk_window.dart';
import 'package:zart/src/io/platform/platform_provider.dart';
import 'package:zart/src/cli/cli_configuration_manager.dart' show cliConfigManager;
import 'package:zart/src/loaders/blorb_resource_manager.dart';

/// IO provider for Glulx interpreter.
class GlulxTerminalProvider implements GlkProvider {
  /// The Glk terminal display.
  late final GlkTerminalDisplay glkDisplay;

  /// The platform provider for file I/O operations.
  PlatformProvider? _platformProvider;

  /// Set the platform provider for file I/O.
  void setPlatformProvider(PlatformProvider provider) {
    _platformProvider = provider;
  }

  /// Creates a terminal provider, optionally accepting a display for testing.
  GlulxTerminalProvider({GlkTerminalDisplay? display}) {
    glkDisplay = display ?? GlkTerminalDisplay();

    _lastCols = glkDisplay.cols;
    _lastRows = glkDisplay.rows;

    // ID 1001 is the default stream (terminal window0)
    _streams[1001] = _GlkStream(id: 1001, type: 1);
    // Initialize screen model with terminal dimensions
    _screenModel.setScreenSize(glkDisplay.cols, glkDisplay.rows);
    // Initialize color preference from config
    _screenModel.forceTextColor(cliConfigManager.textColor);
  }

  /// Queue for chained commands (split by '.')
  final List<String> _commandQueue = [];

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
  DateTime? _lastTimerEvent = null;

  // Last reported terminal dimensions
  int _lastCols = 0;
  int _lastRows = 0;

  /// Callback to get the current heap start from the VM.
  int Function()? getHeapStart;

  // Stack access callbacks (set by interpreter)
  // Per Glk spec, address 0xFFFFFFFF means 'use stack'
  void Function(int val) _pushToStack = (v) {};
  int Function() _popFromStack = () => 0;

  final Map<int, _GlkStream> _streams = {};
  int _nextStreamId = 1002;
  int _currentStreamId = 1001;

  // Buffer for screen output logging (accumulates until newline)
  final StringBuffer _screenOutputBuffer = StringBuffer();

  // Glk Screen Model for window management and rendering
  final GlkScreenModel _screenModel = GlkScreenModel();

  /// Public getter for screen model (for rendering)
  GlkScreenModel get screenModel => _screenModel;

  /// Render the current screen state
  @override
  void renderScreen() {
    glkDisplay.renderGlk(_screenModel);
    if (debugger.enabled) {
      debugger.flushLogs();
    }
  }

  /// Show exit message in root window and wait for keypress
  @override
  Future<void> showExitAndWait(String message) async {
    // Find a suitable visible window to show the message.
    // Pair windows are not writable, so we look for the first text buffer.
    final visible = _screenModel.getVisibleWindows();
    int? targetWin;

    for (final info in visible) {
      if (info.type == GlkWindowType.textBuffer) {
        targetWin = info.windowId;
        break;
      }
    }

    // Fallback to absolute root if no text buffer found (unlikely but safe)
    targetWin ??= _screenModel.rootWindow?.id;

    if (targetWin != null) {
      _screenModel.putString(targetWin, '\n$message');
    }

    renderScreen();
    await glkDisplay.readChar();
  }

  // Window ID to stream ID mapping (each window has its own stream)
  final Map<int, int> _windowStreams = {};

  // File system simulation (for filerefs and streams)
  final Map<int, _GlkFile> _files = {};
  int _nextFileRefId = 2001;

  // Blorb resource manager for images and sounds
  BlorbResourceManager? _blorbResources;

  /// Set the Blorb resource manager for image/sound access.
  void setBlorbResources(BlorbResourceManager manager) {
    _blorbResources = manager;
  }

  @override
  int vmGestalt(int selector, int arg) {
    switch (selector) {
      case GlulxGestaltSelectors.glulxVersion:
        return 0x00030103;
      case GlulxGestaltSelectors.terpVersion:
        return 0x00010000; // Version 1.0.0
      case GlulxGestaltSelectors.resizeMem:
        return 1;
      case GlulxGestaltSelectors.undo:
        return 1;
      case GlulxGestaltSelectors.ioSystem:
        return (arg >= 0 && arg <= 2) ? 1 : 0;
      case GlulxGestaltSelectors.unicode:
        return 1;
      case GlulxGestaltSelectors.memCopy:
        return 1;
      case GlulxGestaltSelectors.mAlloc:
        return 1;
      case GlulxGestaltSelectors.mAllocHeap:
        return getHeapStart?.call() ?? 0;
      case GlulxGestaltSelectors.acceleration:
        return 1; // We support acceleration (functions 1-13)
      case GlulxGestaltSelectors.accelFunc:
        // Return 1 if we support this function index (1-13)
        return (arg >= 1 && arg <= 13) ? 1 : 0;
      case GlulxGestaltSelectors.float:
        return 1;
      case GlulxGestaltSelectors.extUndo:
        return 1;
      case GlulxGestaltSelectors.doubleValue:
        return 1;
      default:
        return 0;
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
  FutureOr<int> dispatch(int selector, List<int> args) {
    if (debugger.enabled && debugger.showInstructions) {
      debugger.bufferedLog(
        '[${debugger.step}] Glk -> selector: 0x${selector.toRadixString(16)}(${ZartDebugger.glkSelectorNames[selector] ?? 'UNKNOWN'}) args: $args',
      );
      if (debugger.showFlightRecorder) {
        debugger.flightRecorderEvent(
          '[${debugger.step}] Glk -> selector: 0x${selector.toRadixString(16)}(${ZartDebugger.glkSelectorNames[selector] ?? 'UNKNOWN'}) args: $args',
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
      case 0: // gidispa
        if (args.isEmpty) return 0;
        final realSelector = args[0];
        final realArgs = args.length > 1 ? args.sublist(1) : <int>[];
        return _dispatch(realSelector, realArgs);

      case GlkIoSelectors.tick:
        return Future.delayed(const Duration(milliseconds: 1)).then((_) {
          return 0;
        });
      case GlkIoSelectors.gestalt:
        return _handleGlkGestalt(args[0], args.length > 1 ? args.sublist(1) : <int>[]);

      case GlkIoSelectors.putChar:
        _writeToStream(_currentStreamId, args[0] & 0xFF);
        return 0;
      case GlkIoSelectors.putCharStream:
        _writeToStream(args[0], args[1] & 0xFF);
        return 0;
      case GlkIoSelectors.putCharUni:
        _writeToStream(_currentStreamId, args[0]);
        return 0;
      case GlkIoSelectors.putCharStreamUni:
        _writeToStream(args[0], args[1]);
        return 0;

      case GlkIoSelectors.getCharStream:
      case GlkIoSelectors.getCharStreamUni:
        return _readFromStream(args[0], selector == GlkIoSelectors.getCharStreamUni);

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
        final style = args[0];
        final winId = _streams[_currentStreamId]?.windowId;
        if (winId != null) {
          _screenModel.setStyle(winId, style);
        }
        return 0;

      case GlkIoSelectors.setStyleStream:
        final streamId = args[0];
        final style = args[1];
        final winId = _streams[streamId]?.windowId;
        if (winId != null) {
          _screenModel.setStyle(winId, style);
        }
        return 0;

      case GlkIoSelectors.stylehintSet:
        // args: wintype, style, hint, val
        _screenModel.styleHintSet(args[0], args[1], args[2], args[3]);
        return 0;

      case GlkIoSelectors.stylehintClear:
        // args: wintype, style, hint
        _screenModel.styleHintClear(args[0], args[1], args[2]);
        return 0;

      case GlkIoSelectors.windowOpen:
        // args: splitFromId, method, size, type, rock
        final splitFromId = args.isNotEmpty ? args[0] : 0;
        final method = args.length > 1 ? args[1] : 0;
        final size = args.length > 2 ? args[2] : 0;
        final winType = args.length > 3 ? args[3] : 0;
        final rock = args.length > 4 ? args[4] : 0;
        // Map Glk window types to GlkWindowType enum
        // Glk spec: pair=1, blank=2, textBuffer=3, textGrid=4, graphics=5
        GlkWindowType type;
        switch (winType) {
          case 1:
            type = GlkWindowType.pair; // Should not happen via windowOpen
          case 2:
            type = GlkWindowType.blank;
          case 3:
            type = GlkWindowType.textBuffer;
          case 4:
            type = GlkWindowType.textGrid;
          case 5:
            type = GlkWindowType.graphics;
          default:
            type = GlkWindowType.textBuffer;
        }
        final winId = _screenModel.windowOpen(splitFromId == 0 ? null : splitFromId, method, size, type, rock);
        if (winId != null) {
          // Create a stream for this window
          final streamId = _nextStreamId++;
          _streams[streamId] = _GlkStream(id: streamId, type: 1, windowId: winId);
          _windowStreams[winId] = streamId;
        }
        return winId ?? 0;
      case GlkIoSelectors.windowClose:
        final winId = args[0];
        _screenModel.windowClose(winId);
        // Remove associated stream
        final streamId = _windowStreams.remove(winId);
        if (streamId != null) _streams.remove(streamId);
        return 0;
      case GlkIoSelectors.windowGetSize:
        final winId = args[0];
        final (w, h) = _screenModel.windowGetSize(winId);
        if (args.length > 1 && args[1] != 0) writeMemory(args[1], w, size: 4);
        if (args.length > 2 && args[2] != 0) writeMemory(args[2], h, size: 4);
        return 0;
      case GlkIoSelectors.setWindow:
        // Set current stream to the window's stream
        final winId = args[0];
        if (winId != 0 && _windowStreams.containsKey(winId)) {
          _currentStreamId = _windowStreams[winId]!;
        }
        return 0;
      case GlkIoSelectors.windowClear:
        _screenModel.windowClear(args[0]);
        return 0;
      case GlkIoSelectors.windowMoveCursor:
        _screenModel.windowMoveCursor(args[0], args[1], args[2]);
        return 0;
      case GlkIoSelectors.windowSetArrangement:
        // args: win (pair window), method, size, keywin
        _screenModel.windowSetArrangement(args[0], args[1], args[2], args.length > 3 ? args[3] : 0);
        return 0;
      case GlkIoSelectors.windowGetParent:
        // Return the parent window ID (pair window)
        final win = _screenModel.getWindow(args[0]);
        return win?.parent?.id ?? 0;

      case GlkIoSelectors.streamOpenFile:
      case GlkIoSelectors.streamOpenFileUni:
        final frefId = args[0];
        final mode = args[1];
        final id = _nextStreamId++;
        final stream = _GlkStream(
          id: id,
          type: 3, // File-backed
          mode: mode,
          frefId: frefId,
          isUnicode: selector == GlkIoSelectors.streamOpenFileUni,
        );
        _streams[id] = stream;

        if (!_files.containsKey(frefId)) {
          _files[frefId] = _GlkFile();
        }

        if (mode == 0x01) {
          // Write mode - clear file for new data
          _files[frefId]!.data = Uint8List(0);
          _files[frefId]!.length = 0;
        } else if (mode == 0x02 && _platformProvider != null) {
          // Read mode - load data from platform provider
          return _platformProvider!.restoreGame().then((data) {
            if (data != null) {
              _files[frefId]!.data = Uint8List.fromList(data);
              _files[frefId]!.length = data.length;
            }
            return id;
          });
        }

        return id;
      case GlkIoSelectors.streamOpenResource:
      case GlkIoSelectors.streamOpenResourceUni:
        return 0;

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
        final rCount = stream?.readCount ?? 0;
        final wCount = stream?.writeCount ?? 0;

        // If closing a file stream that was written to, save via platform provider
        if (stream != null && stream.type == 3 && stream.mode == 0x01) {
          final file = _files[stream.frefId];
          if (file != null && file.length > 0 && _platformProvider != null) {
            final saveData = file.data.sublist(0, file.length);
            return _platformProvider!.saveGame(saveData).then((_) {
              if (resultAddr == -1 || resultAddr == 0xFFFFFFFF) {
                pushToStack(rCount);
                pushToStack(wCount);
              } else if (resultAddr != 0) {
                writeMemory(resultAddr, rCount, size: 4);
                writeMemory(resultAddr + 4, wCount, size: 4);
              }
              return 0;
            });
          }
        }

        if (resultAddr == -1 || resultAddr == 0xFFFFFFFF) {
          pushToStack(rCount);
          pushToStack(wCount);
        } else if (resultAddr != 0) {
          writeMemory(resultAddr, rCount, size: 4);
          writeMemory(resultAddr + 4, wCount, size: 4);
        }
        return 0;

      case GlkIoSelectors.streamSetCurrent:
        final prev = _currentStreamId;
        _currentStreamId = args[0];
        return prev;
      case GlkIoSelectors.streamGetCurrent:
        return _currentStreamId;
      case GlkIoSelectors.streamGetPosition:
        return _streams[args[0]]?.pos ?? 0;
      case GlkIoSelectors.streamSetPosition:
        final str = _streams[args[0]];
        if (str != null) {
          final pos = args[1];
          final seekMode = args[2];
          if (seekMode == 0) {
            str.pos = pos;
          } else if (seekMode == 1) {
            str.pos += pos;
          } else if (seekMode == 2) {
            final len = str.type == 2 ? str.bufLen : (_files[str.frefId]?.length ?? 0);
            str.pos = len + pos;
          }
        }
        return 0;

      case GlkIoSelectors.filerefCreateTemp:
      case GlkIoSelectors.filerefCreateByName:
      case GlkIoSelectors.filerefCreateByPrompt:
      case GlkIoSelectors.filerefCreateByFileUni:
      case GlkIoSelectors.filerefCreateByNameUni:
      case GlkIoSelectors.filerefCreateByPromptUni:
        final id = _nextFileRefId++;
        _files[id] = _GlkFile();
        return id;

      case GlkIoSelectors.filerefDestroy:
      case GlkIoSelectors.filerefDeleteFile:
      case GlkIoSelectors.filerefDoesFileExist:
        return 0;

      case GlkIoSelectors.selectPoll:
        _writeEventStruct(args[0], GlkEventTypes.none, 0, 0, 0);
        return 0;

      case GlkIoSelectors.windowIterate:
        final prevWin = args[0];
        final rockAddr = args.length > 1 ? args[1] : 0;
        final visible = _screenModel.getVisibleWindows();
        final windowIds = visible.map((w) => w.windowId).toList();
        int? nextWin;
        if (prevWin == 0) {
          nextWin = windowIds.isNotEmpty ? windowIds.first : null;
        } else {
          final idx = windowIds.indexOf(prevWin);
          if (idx >= 0 && idx + 1 < windowIds.length) {
            nextWin = windowIds[idx + 1];
          }
        }

        if (nextWin != null) {
          final win = _screenModel.getWindow(nextWin);
          if (win != null) {
            if (rockAddr != 0 && rockAddr != 0xFFFFFFFF) {
              writeMemory(rockAddr, win.rock, size: 4);
            } else if (rockAddr == 0xFFFFFFFF) {
              pushToStack(win.rock);
            }
          }
          return nextWin;
        }
        return 0;

      case GlkIoSelectors.windowGetRock:
        return _screenModel.getWindow(args[0])?.rock ?? 0;

      case GlkIoSelectors.requestLineEvent:
      case GlkIoSelectors.requestLineEventUni:
        _pendingLineEventWin = args[0];
        _pendingLineEventAddr = args[1];
        _pendingLineEventMaxLen = args[2];
        // Also register with screen model
        _screenModel.requestLineEvent(args[0], args[1], args[2]);
        return 0;
      case GlkIoSelectors.requestCharEvent:
      case GlkIoSelectors.requestCharEventUni:
        _pendingCharEventWin = args[0];
        _screenModel.requestCharEvent(args[0]);
        return 0;
      case GlkIoSelectors.cancelLineEvent:
        _pendingLineEventWin = null;
        _screenModel.cancelLineEvent(args[0]);
        return 0;
      case GlkIoSelectors.cancelCharEvent:
        _pendingCharEventWin = null;
        _screenModel.cancelCharEvent(args[0]);
        return 0;
      case GlkIoSelectors.select:
        return _handleSelect(args[0]);

      case GlkIoSelectors.requestTimerEvents:
        _timerInterval = args[0];
        _lastTimerEvent = _timerInterval > 0 ? DateTime.now() : null;
        return 0;

      case GlkIoSelectors.bufferToLowerCaseUni:
      case GlkIoSelectors.bufferToUpperCaseUni:
        final bufAddr = args[0];
        final bufLen = args[1];
        final numChars = args[2];
        final toUpper = selector == GlkIoSelectors.bufferToUpperCaseUni;
        var resultLen = 0;
        for (var i = 0; i < numChars && i < bufLen; i++) {
          var ch = readMemory(bufAddr + i * 4, size: 4);
          final s = String.fromCharCode(ch);
          final converted = toUpper ? s.toUpperCase() : s.toLowerCase();
          ch = converted.codeUnitAt(0);
          writeMemory(bufAddr + i * 4, ch, size: 4);
          resultLen++;
        }
        return resultLen;

      // Image opcodes (graphics window support)
      case GlkIoSelectors.imageGetInfo:
        // args: imageId, widthAddr, heightAddr
        // Returns 1 if image exists, 0 otherwise
        // Writes width/height to provided addresses
        final imageId = args[0];
        final widthAddr = args.length > 1 ? args[1] : 0;
        final heightAddr = args.length > 2 ? args[2] : 0;

        final info = _getImageInfo(imageId);
        if (info != null) {
          if (widthAddr != 0 && widthAddr != 0xFFFFFFFF) {
            writeMemory(widthAddr, info.width, size: 4);
          } else if (widthAddr == 0xFFFFFFFF) {
            pushToStack(info.width);
          }
          if (heightAddr != 0 && heightAddr != 0xFFFFFFFF) {
            writeMemory(heightAddr, info.height, size: 4);
          } else if (heightAddr == 0xFFFFFFFF) {
            pushToStack(info.height);
          }
          return 1;
        }
        return 0;

      case GlkIoSelectors.imageDraw:
        // args: winId, imageId, val1, val2
        // val1/val2 depend on window type (position for graphics, alignment for text)
        final winId = args[0];
        final imageId = args[1];
        final val1 = args.length > 2 ? args[2] : 0;
        final val2 = args.length > 3 ? args[3] : 0;

        final info = _getImageInfo(imageId);
        if (info != null) {
          _drawImageToWindow(winId, imageId, val1, val2, info.width, info.height);
          return 1;
        }
        return 0;

      case GlkIoSelectors.imageDrawScaled:
        // args: winId, imageId, val1, val2, width, height
        final winId = args[0];
        final imageId = args[1];
        final val1 = args.length > 2 ? args[2] : 0;
        final val2 = args.length > 3 ? args[3] : 0;
        final width = args.length > 4 ? args[4] : 0;
        final height = args.length > 5 ? args[5] : 0;

        if (_getImageInfo(imageId) != null) {
          _drawImageToWindow(winId, imageId, val1, val2, width, height);
          return 1;
        }
        return 0;

      case GlkIoSelectors.windowSetBackgroundColor:
        // args: winId, color (0x00RRGGBB)
        final winId = args[0];
        final color = args.length > 1 ? args[1] : 0xFFFFFF;
        final window = _screenModel.getWindow(winId);
        if (window is GlkGraphicsWindow) {
          window.setBackgroundColor(color);
        }
        return 0;

      case GlkIoSelectors.windowEraseRect:
      case GlkIoSelectors.windowFillRect:
        // Stub - graphics rectangle operations
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
      // Window stream - route through screen model
      final codepoint = (value >= 0 && value <= 0x10FFFF) ? value : 0xFFFD;
      final char = String.fromCharCode(codepoint);

      // Write to screen model (explicit window or root window)
      final targetWin = stream.windowId ?? _screenModel.rootWindow?.id;
      if (targetWin != null) {
        _screenModel.putString(targetWin, char);
      }
      // If no windows exist, output is silently discarded

      if (debugger.enabled && debugger.showScreen) {
        if (value == 10) {
          debugger.logScreenOutput(_screenOutputBuffer.toString());
          _screenOutputBuffer.clear();
        } else {
          _screenOutputBuffer.write(char);
        }
      }
    } else if (stream.type == 2) {
      if (stream.bufAddr == 0) return;
      if (stream.pos < stream.bufLen) {
        if (stream.isUnicode) {
          writeMemory(stream.bufAddr + (stream.pos * 4), value, size: 4);
        } else {
          writeMemory(stream.bufAddr + stream.pos, value & 0xFF, size: 1);
        }
        stream.pos++;
      }
    } else if (stream.type == 3) {
      final file = _files[stream.frefId];
      if (file == null) return;

      final bytesNeeded = stream.isUnicode ? 4 : 1;
      if (stream.pos + bytesNeeded > file.data.length) {
        final newSize = (stream.pos + bytesNeeded + 1024) & ~1023;
        final newData = Uint8List(newSize);
        newData.setAll(0, file.data);
        file.data = newData;
      }

      if (stream.isUnicode) {
        final bd = ByteData(4)..setUint32(0, value);
        for (var i = 0; i < 4; i++) {
          file.data[stream.pos++] = bd.getUint8(i);
        }
      } else {
        file.data[stream.pos++] = value & 0xFF;
      }
      if (stream.pos > file.length) file.length = stream.pos;
    }
  }

  int _readFromStream(int streamId, bool unicode) {
    if (streamId == 0) return -1;
    final stream = _streams[streamId];
    if (stream == null) return -1;
    stream.readCount++;

    if (stream.type == 2) {
      if (stream.pos < stream.bufLen) {
        final val = unicode
            ? readMemory(stream.bufAddr + (stream.pos * 4), size: 4)
            : readMemory(stream.bufAddr + stream.pos, size: 1);
        stream.pos++;
        return val;
      }
    } else if (stream.type == 3) {
      final file = _files[stream.frefId];
      if (file != null && stream.pos < file.length) {
        if (unicode) {
          if (stream.pos + 4 <= file.length) {
            final val = ByteData.sublistView(file.data, stream.pos, stream.pos + 4).getUint32(0);
            stream.pos += 4;
            return val;
          }
        } else {
          return file.data[stream.pos++];
        }
      }
    }
    return -1;
  }

  void _writeStringToStream(int streamId, int addr, bool unicode) {
    if (addr == 0) return;
    var p = addr;
    final typeByte = readMemory(p, size: 1);
    if (typeByte == 0xE0) {
      p += 1;
    } else if (typeByte == 0xE2) {
      p += 4;
    }

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
    // Detect terminal size and check for resize
    glkDisplay.detectTerminalSize();
    if (glkDisplay.cols != _lastCols || glkDisplay.rows != _lastRows) {
      _lastCols = glkDisplay.cols;
      _lastRows = glkDisplay.rows;
      _screenModel.setScreenSize(_lastCols, _lastRows);
      _writeEventStruct(eventAddr, GlkEventTypes.arrange, 0, 0, 0);
      return 0;
    }

    // Check for pending input using screen model
    final awaiting = _screenModel.getWindowsAwaitingInput();

    if (awaiting.isNotEmpty) {
      glkDisplay.renderGlk(_screenModel);
      final focusedWin = _screenModel.focusedWindowId ?? awaiting.first;
      final window = _screenModel.getWindow(focusedWin);

      if (window != null && window.lineInputPending) {
        final line = await _getLineInput(focusedWin);

        var count = 0;
        for (var i = 0; i < line.length && i < window.lineInputMaxLen; i++) {
          writeMemory(window.lineInputBufferAddr + i, line.codeUnitAt(i), size: 1);
          count++;
        }
        _screenModel.cancelLineEvent(focusedWin);
        _writeEventStruct(eventAddr, GlkEventTypes.lineInput, focusedWin, count, 0);
        return 0;
      }

      if (window != null && window.charInputPending) {
        final char = await glkDisplay.readChar();
        final code = char.isNotEmpty ? char.codeUnitAt(0) : 0;
        _screenModel.cancelCharEvent(focusedWin);
        _writeEventStruct(eventAddr, GlkEventTypes.charInput, focusedWin, code, 0);
        return 0;
      }
    }

    // Legacy path for pending input tracked locally
    if (_pendingLineEventAddr != null) {
      glkDisplay.renderGlk(_screenModel);
      final line = await _getLineInput(_pendingLineEventWin!);
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
      glkDisplay.renderGlk(_screenModel);
      final char = await glkDisplay.readChar();
      final code = char.isNotEmpty ? char.codeUnitAt(0) : 0;
      _writeEventStruct(eventAddr, GlkEventTypes.charInput, _pendingCharEventWin!, code, 0);
      _pendingCharEventWin = null;
      return 0;
    }
    if (_timerInterval > 0) {
      final elapsed = _lastTimerEvent != null ? DateTime.now().difference(_lastTimerEvent!).inMilliseconds : 0;
      final remaining = _timerInterval - elapsed;
      if (remaining > 0) {
        await Future<void>.delayed(Duration(milliseconds: remaining));
      }
      _lastTimerEvent = DateTime.now();
      _writeEventStruct(eventAddr, GlkEventTypes.timer, 0, 0, 0);
      return 0;
    }
    // Fallback: render and wait for input
    glkDisplay.renderGlk(_screenModel);
    final line = await _getLineInput(1); // 1 is default window ID
    _writeEventStruct(eventAddr, GlkEventTypes.lineInput, 1, line.length, 0);
    return 0;
  }

  /// Gets a line of input, either from the command queue or the terminal.
  /// Handles command splitting ('.') and echoes to the screen model.
  Future<String> _getLineInput(int windowId) async {
    if (_commandQueue.isNotEmpty) {
      final line = _commandQueue.removeAt(0);
      _screenModel.putString(windowId, '$line\n');
      return line;
    }

    final line = await glkDisplay.readLine();

    final commands = line.split('.').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();

    if (commands.isEmpty) {
      _screenModel.putString(windowId, '\n');
      return '';
    }

    final firstCommand = commands.removeAt(0);
    _commandQueue.addAll(commands);

    _screenModel.putString(windowId, '$firstCommand\n');
    return firstCommand;
  }

  void _writeEventStruct(int addr, int type, int win, int val1, int val2) {
    if (addr == -1 || addr == 0xFFFFFFFF) {
      pushToStack(val2);
      pushToStack(val1);
      pushToStack(win);
      pushToStack(type);
    } else {
      writeMemory(addr, type, size: 4);
      writeMemory(addr + 4, win, size: 4);
      writeMemory(addr + 8, val1, size: 4);
      writeMemory(addr + 12, val2, size: 4);
    }
  }

  int _handleGlkGestalt(int gestaltSelector, List<int> args) {
    final arg = args.isNotEmpty ? args[0] : 0;
    switch (gestaltSelector) {
      case GlkGestaltSelectors.version:
        return 0x00070600;
      case GlkGestaltSelectors.charInput:
        // arg is the window type: 2=TextBuffer, 3=TextGrid
        // Return 1 if we support char input for this window type
        if (arg == 2 || arg == 3) return 1;
        return 0;
      case GlkGestaltSelectors.lineInput:
        // arg is the window type: 2=TextBuffer, 3=TextGrid
        // Return 1 if we support line input for this window type
        if (arg == 2 || arg == 3) return 1;
        return 0;
      case GlkGestaltSelectors.charOutput:
        // arg is a character, return if we can print it
        return 2; // gestalt_CharOutput_ExactPrint
      case GlkGestaltSelectors.mouseInput:
        // arg is window type - we don't support mouse input
        return 0;
      case GlkGestaltSelectors.timer:
        return 1; // We support timer events
      case GlkGestaltSelectors.graphics:
        return 0; // No graphics support in CLI
      case GlkGestaltSelectors.drawImage:
        return 0;
      case GlkGestaltSelectors.unicode:
        return 1;
      default:
        return 0;
    }
  }

  // === Image Helper Methods ===

  /// Get image info (width/height) from Blorb resources.
  _ImageInfo? _getImageInfo(int imageId) {
    final image = _blorbResources?.getImage(imageId);
    if (image == null) return null;

    // Parse image dimensions from PNG/JPEG header
    final (width, height) = _parseImageDimensions(image.data, image.format);
    return _ImageInfo(width: width, height: height);
  }

  /// Parse image dimensions from PNG or JPEG data.
  (int, int) _parseImageDimensions(Uint8List data, BlorbImageFormat format) {
    if (format == BlorbImageFormat.png) {
      // PNG IHDR chunk starts at offset 8, width at 16, height at 20
      if (data.length >= 24 && data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47) {
        final width = (data[16] << 24) | (data[17] << 16) | (data[18] << 8) | data[19];
        final height = (data[20] << 24) | (data[21] << 16) | (data[22] << 8) | data[23];
        return (width, height);
      }
    } else if (format == BlorbImageFormat.jpeg) {
      // JPEG: search for SOF0 marker (0xFF 0xC0) and read dimensions
      for (var i = 0; i < data.length - 9; i++) {
        if (data[i] == 0xFF && (data[i + 1] == 0xC0 || data[i + 1] == 0xC2)) {
          final height = (data[i + 5] << 8) | data[i + 6];
          final width = (data[i + 7] << 8) | data[i + 8];
          return (width, height);
        }
      }
    }
    return (0, 0); // Unknown
  }

  /// Draw an image to a graphics window.
  void _drawImageToWindow(int winId, int imageId, int x, int y, int width, int height) {
    final window = _screenModel.getWindow(winId);
    if (window is GlkGraphicsWindow) {
      window.drawImage(resourceId: imageId, x: x, y: y, width: width, height: height);
    }
    // For text buffer windows, image would go in margin - not yet implemented
  }
}

/// Simple image info holder.
class _ImageInfo {
  final int width;
  final int height;
  _ImageInfo({required this.width, required this.height});
}

class _GlkStream {
  final int id;
  final int type;
  final int mode;
  final int bufAddr;
  final int bufLen;
  final bool isUnicode;
  final int frefId;
  final int? windowId; // Associated window for window streams
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
    this.frefId = 0,
    this.windowId,
  });
}

class _GlkFile {
  Uint8List data = Uint8List(0);
  int length = 0;
}
