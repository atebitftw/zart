import 'dart:convert' as JSON;
import 'dart:async';
import 'package:zart/IO/default_provider.dart';
import 'package:zart/IO/io_provider.dart';
import 'package:zart/debugger.dart';
import 'package:zart/header.dart';
import 'package:zart/machines/machine.dart';
import 'package:zart/machines/version_3.dart';
import 'package:zart/machines/version_5.dart';
import 'package:zart/machines/version_7.dart';
import 'package:zart/machines/version_8.dart';
import 'package:zart/memory_map.dart';

ZMachine get Z => new ZMachine();

/**
* This is a partial-interpreter for the Z-Machine.  It handles most interpreter
* activites except actual IO, which is deferred to the IOConfig provider.
*
* The IOConfig handles tasks for whatever presentation platform
* is in use by the application.
*/
class ZMachine {
  bool isLoaded = false;
  bool inBreak = false;
  bool inInterrupt = false;
  bool quit = false;
  ZVersion ver;
  String mostRecentInput;

  StringBuffer sbuff = new StringBuffer();
  final List<int> memoryStreams = new List<int>();
  final List<int> rawBytes = new List<int>();

  static ZMachine _context;

  //contains machine version which are supported by z-machine.
  final List<Machine> _supportedMachines = [
    Version3(),
    Version5(),
    Version7(),
    Version8()
  ];

  Machine machine;

  IOProvider IOConfig;

  factory ZMachine() {
    if (_context != null) return _context;

    _context = new ZMachine._internal();
    return _context;
  }

  ZMachine._internal() {
    IOConfig = DefaultProvider([]);
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

  /**
  * Loads the given Z-Machine story file [storyBytes] into VM memory.
  */
  void load(List<int> storyBytes) {
    if (storyBytes == null) return;

    rawBytes.clear();
    rawBytes.addAll(storyBytes);
    print("First 10 Story Bytes");
    print(rawBytes.getRange(0,10));

    ver = ZMachine.intToVer(rawBytes[Header.VERSION]);

    var result = _supportedMachines.where(((Machine m) => m.version == ver)).toList();

    if (result.length != 1) {
      throw Exception('Z-Machine version ${ver} not supported.');
    } else {
      machine = result[0];
    }

    print('Zart: Using Z-Machine v${machine.version}.');

    machine.mem = new MemoryMap(rawBytes);

    machine.visitHeader();

    isLoaded = true;
  }

  // TODO Wtf??
  callAsync(func()) => Timer(Duration(seconds: 0), () => func());

  /**
  * Runs the Z-Machine using the detected machine version from the story
  * file.  This can be overridden by passing [machineOverride] to the function.
  * Doing so will cause given [Machine] to be used for execution.
  */
  void run([Machine machineOverride = null]) {
    _assertLoaded();

    if (machineOverride != null) {
      machine = machineOverride;
      machine.mem = new MemoryMap(rawBytes);
      machine.visitHeader();
    }

    //for main routine only.
    machine.PC--;

    // visit the main 'routine' (call stack required empty)
    machine.visitRoutine([]);

    //push dummy result store onto the call stack
    machine.callStack.push(0);

    //push dummy return address onto the call stack
    machine.callStack.push(0);

    if (inBreak) {
      callAsync(Debugger.startBreak);
    } else {
      callAsync(runIt);
    }
  }

  void runIt() {
//    while(!inBreak && !inInterrupt && !quit){
    while (!inInterrupt && !quit) {
      machine.visitInstruction();
//      Debugger.instructionsCounter++;
    }

    if (inBreak) {
      Z.sendIO(IOCommands.PRINT_DEBUG, ["<<< DEBUG MODE >>>"]);
      callAsync(Debugger.startBreak);
    }
  }

  Future<Object> sendIO(IOCommands command, [List<Object> messageData]) {
    messageData = messageData == null ? [] : messageData;
    List<String> msg = [command.toString()];

    for(final m in messageData){
      msg.add(m);
    }
    // messageData.forEach((m){
    //   msg
    // });
    // msg.addAll(messageData as Iterable<Object>);

    return IOConfig.command(JSON.json.encode(msg));
  }

  void printBuffer() async {
    //if output stream 3 is active then we don't print,
    //Just preserve the buffer until the stream is de-selected.
    if (!machine.outputStream3) {
      await sendIO(IOCommands.PRINT,
          [machine.currentWindow.toString(), sbuff.toString()]);
      sbuff.clear();
    }
  }

  /** Reset Z-Machine to state at first load */
  void softReset() {
    _assertLoaded();
    machine.PC = 0;
    machine.stack.clear();
    machine.callStack.clear();
    memoryStreams.clear();
    machine.mem = null;

    machine.mem = new MemoryMap(rawBytes);
    machine.visitHeader();
  }

  void _assertLoaded() {
    if (!isLoaded) {
      throw Exception('Z-Machine state not loaded. Use load() first.');
    }
  }
}

enum ZVersion { S, V1, V2, V3, V4, V5, V6, V7, V8 }
