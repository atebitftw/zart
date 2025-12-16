import 'dart:async';
import 'package:zart/src/logging.dart' show log;
import 'package:zart/src/z_machine/memory_map.dart' show MemoryMap;
import 'package:zart/src/z_machine/zscii.dart' show ZSCII;
import 'package:zart/zart.dart';
import 'package:zart/src/z_machine/interpreters/interpreter_v3.dart'
    show InterpreterV3;
import 'package:zart/src/z_machine/interpreters/interpreter_v4.dart'
    show InterpreterV4;
import 'package:zart/src/z_machine/interpreters/interpreter_v5.dart'
    show InterpreterV5;
import 'package:zart/src/z_machine/interpreters/interpreter_v7.dart'
    show InterpreterV7;
import 'package:zart/src/z_machine/interpreters/interpreter_v8.dart'
    show InterpreterV8;

/// The Z-Machine singleton.
ZMachine get Z => ZMachine();

/// This is a partial-interpreter for the Z-Machine.  It handles most interpreter
/// activites except actual IO, which is deferred to the IOConfig provider.
///
/// The IOConfig handles tasks for whatever presentation platform
/// is in use by the application.
class ZMachine {
  /// Whether the Z-Machine is loaded.
  bool isLoaded = false;

  /// Whether the Z-Machine is in break mode.
  bool inBreak = false;

  /// Whether the Z-Machine is in interrupt mode.
  bool inInterrupt = false;

  /// Whether the Z-Machine is in quit mode.
  bool quit = false;

  // ===== Pump Mode (for Flutter) =====

  /// Whether pump mode is active (Flutter controls execution instead of internal loop).
  bool _pumpMode = false;

  /// The current run state when in pump mode.
  ZMachineRunState _runState = ZMachineRunState.running;

  /// Callback to process line input when it arrives.
  void Function(String)? _pendingLineCallback;

  /// Callback to process char input when it arrives.
  void Function(String)? _pendingCharCallback;

  /// The version of the Z-Machine.
  ZMachineVersions? ver;

  /// The most recent input.
  late String mostRecentInput;

  /// The string buffer.
  StringBuffer sbuff = StringBuffer();

  /// The memory streams.
  final List<int?> memoryStreams = <int>[];

  /// Stack of saved screen buffer contents when stream 3 is selected.
  /// Per Z-Machine spec 7.1.2.2, stream 3 is exclusive - while selected, no
  /// text goes to other streams. We save the current buffer when stream 3
  /// opens and restore it when stream 3 closes.
  final List<String> savedBuffers = <String>[];

  /// The raw bytes.
  final List<int> rawBytes = <int>[];

  static ZMachine? _context;

  //contains machine version which are supported by z-machine.
  final List<InterpreterV3 Function()> _supportedEngines = [
    () => InterpreterV3(),
    () => InterpreterV4(),
    () => InterpreterV5(),
    () => InterpreterV7(),
    () => InterpreterV8(),
  ];

  /// Represents the underlying interpreter engine used to run the
  /// game (different versions require different engines).
  late InterpreterV3 engine;

  /// This field must be set so that the interpeter has a place to send
  /// commands and receive results from those commands (if any).
  IoProvider io = DefaultProvider([]) as IoProvider;

  /// Instantiates the Z-Machine singleton.
  factory ZMachine() {
    if (_context != null) return _context!;

    return _context = ZMachine._internal();
  }

  ZMachine._internal() {
    _context = this;
  }

  /// Converts a [ZMachineVersions] to an [int].
  static int verToInt(ZMachineVersions v) {
    switch (v) {
      case ZMachineVersions.s:
        return -1;
      case ZMachineVersions.v1:
        return 1;
      case ZMachineVersions.v2:
        return 2;
      case ZMachineVersions.v3:
        return 3;
      case ZMachineVersions.v4:
        return 4;
      case ZMachineVersions.v5:
        return 5;
      case ZMachineVersions.v6:
        return 6;
      case ZMachineVersions.v7:
        return 7;
      case ZMachineVersions.v8:
        return 8;
    }
  }

  /// Converts given [int] to a [ZMachineVersions]
  static ZMachineVersions intToVer(int ver) {
    switch (ver) {
      case -1:
        return ZMachineVersions.s;
      case 1:
        return ZMachineVersions.v1;
      case 2:
        return ZMachineVersions.v2;
      case 3:
        return ZMachineVersions.v3;
      case 4:
        return ZMachineVersions.v4;
      case 5:
        return ZMachineVersions.v5;
      case 6:
        return ZMachineVersions.v6;
      case 7:
        return ZMachineVersions.v7;
      case 8:
        return ZMachineVersions.v8;
      default:
        throw Exception("Z-Machine -> Version number not recognized: $ver");
    }
  }

  /// Loads the given Z-Machine story file [storyBytes] into the
  /// interpreter memory.
  void load(List<int>? storyBytes) {
    if (storyBytes == null) return;

    // Reset state
    inBreak = false;
    inInterrupt = false;
    quit = false;
    sbuff.clear();
    memoryStreams.clear();
    savedBuffers.clear();
    // rawBytes is cleared below

    // Clear string cache when loading a new game
    ZSCII.clearCache();

    rawBytes.clear();
    rawBytes.addAll(storyBytes);
    // print("First 10 Story Bytes");
    // print(rawBytes.getRange(0,10));

    ver = ZMachine.intToVer(rawBytes[Header.version]);

    final result = _supportedEngines
        .where(((m) => m().version == ver))
        .toList();

    if (result.length != 1) {
      throw Exception('Z-Machine version $ver not supported.');
    } else {
      engine = result[0]();
    }

    log.info('Zart: Using Z-Machine ${engine.version}.');

    engine.mem = MemoryMap(rawBytes);

    // Set interpreter number to DECSystem-20 (1) to ensure Z-Machine games (like Beyond Zork)
    // recognize the interpreter and enable color/terminal features.
    // Defaulting to 0 or story-file values caused "No Color" regression.
    engine.mem.storeb(Header.interpreterNumber, 1);

    engine.visitHeader();

    isLoaded = true;
  }

  /// Calls the given [func] asynchronously.
  void callAsync(Function() func) {
    Timer(const Duration(seconds: 0), () => func());
  }

  /// Runs the Z-Machine using the detected machine version from the story
  /// file.  This can be overridden by passing [machineOverride] to the function.
  /// Doing so will cause given [InterpreterV3] to be used for execution.
  ///
  /// This method is mainly used for unit testing.
  ///
  /// Recommend using [runUntilInput] for normal game play.
  @Deprecated('Use runUntilInput instead.')
  void run([InterpreterV3? machineOverride]) {
    _assertLoaded();

    if (machineOverride != null) {
      engine = machineOverride;
      engine.mem = MemoryMap(rawBytes);
      engine.visitHeader();
    }

    //for main routine only.
    engine.programCounter--;

    // visit the main 'routine' (call stack required empty)
    engine.visitRoutine([]);

    //push dummy result store onto the call stack
    engine.callStack.push(0);

    //push dummy return address onto the call stack
    engine.callStack.push(0);

    if (inBreak) {
      callAsync(Debugger.startBreak);
    } else {
      log.finest("run() callAsync(runIt)");
      callAsync(runIt);
    }
  }

  /// Runs the Z-Machine.
  void runIt() async {
    log.finest("runIt() called.");
    //    while(!inBreak && !inInterrupt && !quit){
    while (!inInterrupt && !quit) {
      await engine.visitInstruction();
      // Yield to event loop to prevent Flutter Web from starving.
      // In JavaScript, a tight while loop with only synchronously-completing
      // awaits can block the event loop, preventing Futures from resolving.
      await Future.delayed(Duration.zero);
    }

    if (inBreak) {
      await Z.sendIO({
        "command": IoCommands.printDebug,
        "message": "<<< DEBUG MODE >>>",
      });
      callAsync(Debugger.startBreak);
    }
  }

  /// Sends IO to the [io] provider.
  Future<dynamic> sendIO(Map<String, dynamic> ioData) async {
    return await io.command(ioData);
  }

  /// Prints the buffer.
  /// Returns a Future that completes when the print command is sent.
  Future<void> printBuffer() async {
    //if output stream 3 is active then we don't print,
    //Just preserve the buffer until the stream is de-selected.
    if (!engine.outputStream3) {
      final text = sbuff.toString();
      // DEBUG: Trace all text output
      //if (text.isNotEmpty) {
      //  print('[PRINT DEBUG] window=${engine.currentWindow} text="${text.replaceAll('\n', '\\n')}"');
      //}
      await sendIO({
        "command": IoCommands.print,
        "window": engine.currentWindow,
        "buffer": text,
      });
      sbuff.clear();
    }
  }

  /// Reset Z-Machine to state at first load */
  void softReset() {
    _assertLoaded();
    engine.programCounter = 0;
    engine.stack.clear();
    engine.callStack.clear();
    memoryStreams.clear();
    engine.mem = MemoryMap(rawBytes);
    engine.visitHeader();
  }

  /// Hard reset Z-Machine to initial state */
  void hardReset() {
    engine.programCounter = 0;
    engine.stack.clear();
    engine.callStack.clear();
    memoryStreams.clear();
    rawBytes.clear();
    isLoaded = false;
  }

  /// Runs instructions until input is needed or game ends.
  /// This is the Flutter-friendly API where the caller controls execution.
  /// All print output is sent via [io.command()] as usual.
  Future<ZMachineRunState> runUntilInput() async {
    _assertLoaded();
    _pumpMode = true;
    _runState = ZMachineRunState.running;
    quit = false;

    // Initialize main routine if this is a fresh start
    if (engine.callStack.length == 0) {
      engine.programCounter--;
      engine.visitRoutine([]);
      engine.callStack.push(0); // dummy result store
      engine.callStack.push(0); // dummy return address
    }

    // Run instructions until we need input, quit, or are interrupted (save/restore)
    while (!quit && !inInterrupt && _runState == ZMachineRunState.running) {
      await engine.visitInstruction();
    }

    if (quit) {
      _runState = ZMachineRunState.quit;
    }

    return _runState;
  }

  /// Submits line input (for read opcode) and continues execution.
  /// Only call this after [runUntilInput()] returns [ZMachineRunState.needsLineInput].
  Future<ZMachineRunState> submitLineInput(String input) async {
    if (_pendingLineCallback == null ||
        _runState != ZMachineRunState.needsLineInput) {
      throw Exception('Not waiting for line input');
    }

    // Execute the pending callback with user input
    final callback = _pendingLineCallback!;
    _pendingLineCallback = null;
    _runState = ZMachineRunState.running;
    callback(input);

    // Continue running until next input, quit, or interrupted (save/restore)
    while (!quit && !inInterrupt && _runState == ZMachineRunState.running) {
      await engine.visitInstruction();
    }

    if (quit) {
      _runState = ZMachineRunState.quit;
    }

    return _runState;
  }

  /// Submits character input (for read_char opcode) and continues execution.
  /// Only call this after [runUntilInput()] returns [ZMachineRunState.needsCharInput].
  Future<ZMachineRunState> submitCharInput(String char) async {
    if (_pendingCharCallback == null ||
        _runState != ZMachineRunState.needsCharInput) {
      throw Exception('Not waiting for character input');
    }

    // Execute the pending callback with user input
    final callback = _pendingCharCallback!;
    _pendingCharCallback = null;
    _runState = ZMachineRunState.running;
    callback(char);

    // Continue running until next input, quit, or interrupted (save/restore)
    while (!quit && !inInterrupt && _runState == ZMachineRunState.running) {
      await engine.visitInstruction();
    }

    if (quit) {
      _runState = ZMachineRunState.quit;
    }

    return _runState;
  }

  /// Called by engine when read opcode needs input (pump mode only).
  /// Stores the callback and signals that input is needed.
  void requestLineInput(void Function(String) callback) {
    _runState = ZMachineRunState.needsLineInput;
    _pendingLineCallback = callback;
  }

  /// Called by engine when read_char opcode needs input (pump mode only).
  /// Stores the callback and signals that input is needed.
  void requestCharInput(void Function(String) callback) {
    _runState = ZMachineRunState.needsCharInput;
    _pendingCharCallback = callback;
  }

  /// Whether pump mode is active.
  bool get isPumpMode => _pumpMode;

  void _assertLoaded() {
    if (!isLoaded) {
      throw Exception('Z-Machine state not loaded. Use load() first.');
    }
  }
}

/// State returned after running instructions in pump mode.
enum ZMachineRunState {
  /// Engine is running instructions.
  running,

  /// Engine needs line input (read opcode was called).
  needsLineInput,

  /// Engine needs character input (read_char opcode was called).
  needsCharInput,

  /// Game has ended (quit opcode was called).
  quit,

  /// An error occurred.
  error,
}

/// The Z-Machine versions.
enum ZMachineVersions {
  /// Special version
  s,

  /// Version 1
  v1,

  /// Version 2
  v2,

  /// Version 3
  v3,

  /// Version 4
  v4,

  /// Version 5
  v5,

  /// Version 6
  v6,

  /// Version 7
  v7,

  /// Version 8
  v8,
}
