import 'package:zart/src/z_machine/game_object.dart';
import 'package:zart/src/z_machine/interpreters/interpreter_v3.dart';
import 'package:zart/src/z_machine/interpreters/interpreter_v5.dart';
import 'package:zart/src/z_machine/interpreters/interpreter_v7.dart';
import 'package:zart/src/z_machine/interpreters/interpreter_v8.dart';
import 'package:zart/src/z_machine/memory_map.dart';
import 'package:zart/src/z_machine/z_machine.dart';
import 'package:zart/zart.dart';

/// A runtime debugger for Z-Machine.
class Debugger {
  /// For unit test constraints.
  static const int maxSteps = 300; // do not change this without permission.

  /// Set a flag whether to enable verbose output.
  static bool enableVerbose = false;

  /// Set a flag whether to enable trace output.
  static bool enableTrace = false;

  /// Set a flag whether to enable debug output.
  static bool enableDebug = false;

  /// Set a flag whether to enable stack trace output.
  static bool enableStackTrace = false;

  /// This flag is meant to alert the game engine that it is being
  /// run for unit testing purposes, but is currently not supported.
  static bool isUnitTestRun = false;

  /// The address where the debugger will start.
  static int? debugStartAddr;

  /// The list of break points.
  static List<int>? _breakPoints;

  /// The instruction counter.
  static int instructionCounter = 0;

  static InterpreterV3 _getEngineByVersion(ZMachineVersions? version) {
    switch (version) {
      case ZMachineVersions.v1:
      case ZMachineVersions.v3:
        return InterpreterV3();
      case ZMachineVersions.v5:
        return InterpreterV5();
      case ZMachineVersions.v7:
        return InterpreterV7();
      case ZMachineVersions.v8:
        return InterpreterV8();
      default:
        throw GameException("Unsupported gamefile version.  This interpreter does not support $version");
    }
  }

  /// Selects the best suited [InterpreterV3] version for the game file.
  /// will also accept optional [newEngine] which will be used
  /// to run the game (throws a [GameException] if [newEngine] version
  /// and game version do not match).
  static void initializeEngine([InterpreterV3? newEngine]) {
    Z.inInterrupt = true;
    if (!Z.isLoaded) {
      throw GameException("Unable to initialize Z-Machine.  No game file is loaded.");
    }

    if (newEngine != null && newEngine.version != Z.ver) {
      throw GameException('Machine/Story version mismatch. Expected ${Z.ver}. Got ${newEngine.version}');
    }

    Z.engine = newEngine ?? _getEngineByVersion(Z.ver);
    Z.engine.mem = MemoryMap(Z.rawBytes);
    Z.engine.visitHeader();
    debug('<<< machine installed: v${Z.engine.version} >>>');
    Z.inInterrupt = false;
  }

  /// Start the debugger.
  static Future<void> startBreak() async {
    await Z.sendIO({
      "command": ZIoCommands.printDebug,
      "message":
          '(break)>>> 0x${debugStartAddr!.toRadixString(16)}:'
          ' opCode: ${Z.engine.mem.loadb(debugStartAddr!)}'
          '\n'
          '    Locals ${dumpLocals()}\n',
    });

    Z.callAsync(_repl);
  }

  static void _repl() async {
    void parse(String command) {
      var cl = command.toLowerCase().trim();
      var args = cl.split(' ');

      switch (args[0]) {
        case 'dump':
          var addr = int.parse(args[1]);
          var howMany = int.parse(args[2]);
          debug(Z.engine.mem.dump(addr, howMany));
          Z.callAsync(_repl);
          break;
        case 'move':
          var obj1 = GameObject(int.parse(args[1]));
          var obj2 = GameObject(int.parse(args[2]));
          obj1.insertTo(obj2.id);
          Z.callAsync(_repl);
          break;
        case 'enable':
          switch (args[1]) {
            case 'trace':
              Debugger.enableTrace = true;
              debug('Trace Enabled.');
              break;
            case 'verbose':
              Debugger.enableVerbose = true;
              debug('Verbose Enabled.');
              break;
            case 'stacktrace':
              Debugger.enableStackTrace = true;
              debug('Stack Trace Enabled.');
              break;
          }
          Z.callAsync(_repl);
          break;
        case 'disable':
          switch (args[1]) {
            case 'trace':
              Debugger.enableTrace = false;
              debug('Trace Disabled.');
              break;
            case 'verbose':
              Debugger.enableVerbose = false;
              debug('Verbose Disabled.');
              break;
            case 'stacktrace':
              Debugger.enableStackTrace = false;
              debug('Stack Trace Disabled.');
              break;
          }
          Z.callAsync(_repl);
          break;
        case '':
        case 'n':
          debugStartAddr = Z.engine.programCounter;
          Z.engine.visitInstruction();
          break;
        case 'q':
          Z.inBreak = false;
          Z.callAsync(Z.runIt);
          break;
        case 'dictionary':
          debug(Z.engine.mem.dictionary.dump());
          Z.callAsync(Z.runIt);
          break;
        case 'globals':
          final s = StringBuffer();

          var col = args.length == 2 ? int.parse(args[1]) : 10;
          if (col < 1) col = 1;

          for (int i = 0x10; i < 0xff; i++) {
            s.write(
              'g${i - 16 < 10 ? "0" : ""}${i - 16}:'
              ' 0x${Z.engine.mem.readGlobal(i).toRadixString(16)}',
            );

            if ((i - 15) % col != 0) {
              s.write('\t');
            } else {
              s.write('\n');
            }
          }
          debug('$s');
          Z.callAsync(_repl);
          break;
        case 'locals':
          debug(dumpLocals());
          Z.callAsync(_repl);
          break;
        case 'stacks':
          debug('call stack: ${Z.engine.callStack}');
          debug('eval stack: ${Z.engine.stack}');
          Z.callAsync(_repl);
          break;
        case 'object':
          var obj = GameObject(int.parse(args[1]));
          debug(obj.toString());
          Z.callAsync(_repl);
          break;
        case 'header':
          debug(dumpHeader());
          Z.callAsync(_repl);
          break;
        default:
          debug('Unknown Command.');
          Z.callAsync(_repl);
          break;
      }
    }

    final line = await Z.sendIO({"command": ZIoCommands.read});
    parse(line);
  }

  /// Enable all debugging channels.
  static void enableAll() {
    Debugger.enableDebug = true;
    Debugger.enableStackTrace = true;
    Debugger.enableVerbose = true;
    Debugger.enableTrace = true;
  }

  /// Disable all debugging channels.
  static void disableAll() {
    Debugger.enableDebug = false;
    Debugger.enableStackTrace = false;
    Debugger.enableVerbose = false;
    Debugger.enableTrace = false;
  }

  /// Return true if the [addr] is a break point.
  static bool isBreakPoint(int addr) {
    if (_breakPoints == null) return false;
    return _breakPoints!.contains(addr);
  }

  /// Set the break points with a list of [breakPoints] addresses.
  static void setBreaks(List<int> breakPoints) {
    if (_breakPoints == null) {
      _breakPoints = <int>[];
    } else {
      _breakPoints!.clear();
    }
    _breakPoints!.addAll(breakPoints);
  }

  /// Return a crash report as a formatted string.
  static String crashReport() {
    var s = StringBuffer();
    s.write('Call Stack: ${Z.engine.callStack}\n');
    s.write('Game Stack: ${Z.engine.stack}\n');
    s.write(dumpLocals());
    return s.toString();
  }

  /// Return local variables as a formatted string.
  static String dumpLocals() {
    var locals = Z.engine.callStack[2];
    StringBuffer s = StringBuffer();

    for (int i = 0; i < locals; i++) {
      s.write('(L$i: 0x${Z.engine.readLocal(i + 1).toRadixString(16)}) ');
    }
    s.write('\n');
    return s.toString();
  }

  /// Return header information as a formatted string.
  static String dumpHeader() {
    if (!Z.isLoaded) return '<<< Machine Not Loaded >>>\n';

    var s = StringBuffer();

    s.write('(Story contains ${Z.engine.mem.size} bytes.)\n');
    s.write('\n');
    s.write('------- START HEADER -------\n');
    s.write('Z-Machine Version: ${Z.engine.version}\n');
    s.write('Flags1(binary): 0b${Z.engine.mem.loadw(Header.flags1).toRadixString(2)}\n');
    // word after flags1 is used by Inform
    s.write('Abbreviations Location: 0x${Z.engine.mem.abbrAddress.toRadixString(16)}\n');
    s.write('Object Table Location: 0x${Z.engine.mem.objectsAddress.toRadixString(16)}\n');
    s.write('Global Variables Location: 0x${Z.engine.mem.globalVarsAddress.toRadixString(16)}\n');
    s.write('Static Memory Start: 0x${Z.engine.mem.staticMemAddress.toRadixString(16)}\n');
    s.write('Dictionary Location: 0x${Z.engine.mem.dictionaryAddress!.toRadixString(16)}\n');
    s.write('High Memory Start: 0x${Z.engine.mem.highMemAddress.toRadixString(16)}\n');
    s.write('Program Counter Start: 0x${Z.engine.mem.programStart!.toRadixString(16)}\n');
    s.write('Flags2(binary): 0b${Z.engine.mem.loadb(Header.flags2).toRadixString(2)}\n');
    s.write('Length Of File: ${Z.engine.mem.loadw(Header.lengthOfFile) * Z.engine.fileLengthMultiplier()}\n');
    s.write('Checksum Of File: ${Z.engine.mem.loadw(Header.checkSumOfFile)}\n');

    s.write('Standard Revision: ${Z.engine.mem.loadw(Header.revisionNumberN)}\n');
    s.write('-------- END HEADER ---------\n');

    //s.write('main Routine: ${Z.machine.mem.getRange(Z.pc - 4, 10)}');

    s.write('\n');
    return s.toString();
  }

  /// Displays a message on the verbose channel.
  static void verbose(String outString) {
    if (Debugger.enableDebug && Debugger.enableVerbose) {
      debug(outString);
    }
  }

  /// Displays a message on the debug channel.
  static void debug(String debugString) async {
    await Z.sendIO({"command": ZIoCommands.printDebug, "message": debugString});
  }

  /// Displays a message on the todo channel.
  static void todo([String? message]) async {
    await Z.sendIO({
      "command": ZIoCommands.printDebug,
      "message":
          'Stopped At: 0x${Z.engine.programCounter.toRadixString(16)}\n\n'
          'Text Buffer:\n'
          '${Z.sbuff}\n'
          '${message != null ? "TODO: $message" : ""}\n',
    });

    throw Exception("Not Implemented");
  }
}
