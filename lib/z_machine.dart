import 'dart:async';
import 'package:zart/IO/default_provider.dart';
import 'package:zart/IO/io_provider.dart';
import 'package:zart/debugger.dart';
import 'package:zart/engines/version_4.dart';
import 'package:zart/header.dart';
import 'package:zart/engines/engine.dart';
import 'package:zart/engines/version_3.dart';
import 'package:zart/engines/version_5.dart';
import 'package:zart/engines/version_7.dart';
import 'package:zart/engines/version_8.dart';
import 'package:zart/memory_map.dart';
import 'package:zart/mixins/loggable.dart';

ZMachine get Z => ZMachine();

/// This is a partial-interpreter for the Z-Machine.  It handles most interpreter
/// activites except actual IO, which is deferred to the IOConfig provider.
///
/// The IOConfig handles tasks for whatever presentation platform
/// is in use by the application.
class ZMachine with Loggable {
  bool isLoaded = false;
  bool inBreak = false;
  bool inInterrupt = false;
  bool quit = false;
  ZVersion ver;
  String mostRecentInput;

  StringBuffer sbuff = StringBuffer();
  final List<int> memoryStreams = List<int>();
  final List<int> rawBytes = List<int>();

  static ZMachine _context;

  //contains machine version which are supported by z-machine.
  final List<Engine> _supportedEngines = [
    Version3(),
    Version4(),
    Version5(),
    Version7(),
    Version8()
  ];

  /// Represents the underlying interpreter engine used to run the
  /// game (different versions require different engines).
  Engine engine;

  /// This field must be set so that the interpeter has a place to send
  /// commands and receive results from those commands (if any).
  IOProvider io = DefaultProvider([]);

  //singleton
  factory ZMachine() {
    if (_context != null) return _context;

    _context = ZMachine._internal();
    return _context;
  }

  ZMachine._internal() {
    logName = "ZMachine";
  }

  static int verToInt(ZVersion v) {
    switch (v) {
      case ZVersion.S:
        return -1;
      case ZVersion.V1:
        return 1;
      case ZVersion.V2:
        return 2;
      case ZVersion.V3:
        return 3;
      case ZVersion.V4:
        return 4;
      case ZVersion.V5:
        return 5;
      case ZVersion.V6:
        return 6;
      case ZVersion.V7:
        return 7;
      case ZVersion.V8:
        return 8;
    }
    throw Exception("ZVersion not recognized during conversion to int.");
  }

  /// Converts given [int] to a [ZVersion]
  static ZVersion intToVer(int ver) {
    switch (ver) {
      case -1:
        return ZVersion.S;
      case 1:
        return ZVersion.V1;
      case 2:
        return ZVersion.V2;
      case 3:
        return ZVersion.V3;
      case 4:
        return ZVersion.V4;
      case 5:
        return ZVersion.V5;
      case 6:
        return ZVersion.V6;
      case 7:
        return ZVersion.V7;
      case 8:
        return ZVersion.V8;
      default:
        throw Exception("Version number not recognized.");
    }
  }

  /// Loads the given Z-Machine story file [storyBytes] into the
  /// interpreter memory.
  void load(List<int> storyBytes) {
    if (storyBytes == null) return;

    rawBytes.clear();
    rawBytes.addAll(storyBytes);
    // print("First 10 Story Bytes");
    // print(rawBytes.getRange(0,10));

    ver = ZMachine.intToVer(rawBytes[Header.VERSION]);

    var result =
        _supportedEngines.where(((Engine m) => m.version == ver)).toList();

    if (result.length != 1) {
      throw Exception('Z-Machine version ${ver} not supported.');
    } else {
      engine = result[0];
    }

    log.info('Zart: Using Z-Machine ${engine.version}.');

    engine.mem = MemoryMap(rawBytes);

    engine.visitHeader();

    isLoaded = true;
  }

  void callAsync(func()) {
    Timer(Duration(seconds: 0), () => func());
  }

  /**
  * Runs the Z-Machine using the detected machine version from the story
  * file.  This can be overridden by passing [machineOverride] to the function.
  * Doing so will cause given [Engine] to be used for execution.
  */
  void run([Engine machineOverride = null]) {
    _assertLoaded();

    if (machineOverride != null) {
      engine = machineOverride;
      engine.mem = MemoryMap(rawBytes);
      engine.visitHeader();
    }

    //for main routine only.
    engine.PC--;

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

  void runIt() async {
    log.finest("runIt() called.");
//    while(!inBreak && !inInterrupt && !quit){
    while (!inInterrupt && !quit) {
      engine.visitInstruction();
    }

    if (inBreak) {
      await Z.sendIO(
          {"command": IOCommands.PRINT_DEBUG, "message": "<<< DEBUG MODE >>>"});
      callAsync(Debugger.startBreak);
    }
  }

  Future<dynamic> sendIO(Map<String, dynamic> ioData) async {
    return await io.command(ioData);
  }

  void printBuffer() {
    //if output stream 3 is active then we don't print,
    //Just preserve the buffer until the stream is de-selected.
    if (!engine.outputStream3) {
      sendIO({
        "command": IOCommands.PRINT,
        "window": engine.currentWindow,
        "buffer": sbuff.toString()
      }).then((_) {
        sbuff.clear();
      });
    }
  }

  /** Reset Z-Machine to state at first load */
  void softReset() {
    _assertLoaded();
    engine.PC = 0;
    engine.stack.clear();
    engine.callStack.clear();
    memoryStreams.clear();
    engine.mem = MemoryMap(rawBytes);
    engine.visitHeader();
  }

  void _assertLoaded() {
    if (!isLoaded) {
      throw Exception('Z-Machine state not loaded. Use load() first.');
    }
  }
}

enum ZVersion { S, V1, V2, V3, V4, V5, V6, V7, V8 }
