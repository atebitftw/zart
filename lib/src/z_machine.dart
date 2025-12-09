import 'dart:async';
import 'package:zart/src/engines/engine.dart' show Engine;
import 'package:zart/src/logging.dart' show log;
import 'package:zart/src/memory_map.dart' show MemoryMap;
import 'package:zart/zart.dart';
import 'engines/version_3.dart' show Version3;
import 'engines/version_4.dart' show Version4;
import 'engines/version_5.dart' show Version5;
import 'engines/version_7.dart' show Version7;
import 'engines/version_8.dart' show Version8;

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

  /// The version of the Z-Machine.
  ZMachineVersions? ver;

  /// The most recent input.
  late String mostRecentInput;

  /// The string buffer.
  StringBuffer sbuff = StringBuffer();

  /// The memory streams.
  final List<int?> memoryStreams = <int>[];

  /// The raw bytes.
  final List<int> rawBytes = <int>[];

  static ZMachine? _context;

  //contains machine version which are supported by z-machine.
  final List<Engine Function()> _supportedEngines = [
    () => Version3(),
    () => Version4(),
    () => Version5(),
    () => Version7(),
    () => Version8(),
  ];

  /// Represents the underlying interpreter engine used to run the
  /// game (different versions require different engines).
  late Engine engine;

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
        throw Exception("Version number not recognized: $ver");
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
    // rawBytes is cleared below

    rawBytes.clear();
    rawBytes.addAll(storyBytes);
    // print("First 10 Story Bytes");
    // print(rawBytes.getRange(0,10));

    ver = ZMachine.intToVer(rawBytes[Header.version]);

    final result = _supportedEngines.where(((m) => m().version == ver)).toList();

    if (result.length != 1) {
      throw Exception('Z-Machine version $ver not supported.');
    } else {
      engine = result[0]();
    }

    log.info('Zart: Using Z-Machine ${engine.version}.');

    engine.mem = MemoryMap(rawBytes);

    engine.visitHeader();

    isLoaded = true;
  }

  /// Calls the given [func] asynchronously.
  void callAsync(Function() func) {
    Timer(const Duration(seconds: 0), () => func());
  }

  /// Runs the Z-Machine using the detected machine version from the story
  /// file.  This can be overridden by passing [machineOverride] to the function.
  /// Doing so will cause given [Engine] to be used for execution.
  void run([Engine? machineOverride]) {
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
      engine.visitInstruction();
    }

    if (inBreak) {
      await Z.sendIO({"command": IoCommands.printDebug, "message": "<<< DEBUG MODE >>>"});
      callAsync(Debugger.startBreak);
    }
  }

  /// Sends IO to the [io] provider.
  Future<dynamic> sendIO(Map<String, dynamic> ioData) async {
    return await io.command(ioData);
  }

  /// Prints the buffer.
  void printBuffer() {
    //if output stream 3 is active then we don't print,
    //Just preserve the buffer until the stream is de-selected.
    if (!engine.outputStream3) {
      sendIO({"command": IoCommands.print, "window": engine.currentWindow, "buffer": sbuff.toString()}).then((_) {
        sbuff.clear();
      });
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

  void _assertLoaded() {
    if (!isLoaded) {
      throw Exception('Z-Machine state not loaded. Use load() first.');
    }
  }
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
