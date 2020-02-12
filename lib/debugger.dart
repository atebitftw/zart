import 'package:zart/IO/io_provider.dart';
import 'package:zart/game_exception.dart';
import 'package:zart/game_object.dart';
import 'package:zart/header.dart';
import 'package:zart/engines/engine.dart';
import 'package:zart/engines/version_3.dart';
import 'package:zart/engines/version_5.dart';
import 'package:zart/engines/version_7.dart';
import 'package:zart/engines/version_8.dart';
import 'package:zart/memory_map.dart';
import 'package:zart/mixins/loggable.dart';
import 'package:zart/z_machine.dart';
import 'package:zart/zart.dart';

/// A runtime debugger for Z-Machine.
class Debugger with Loggable {
  Debugger() {
    logName = "Debugger";
  }

  static bool enableVerbose = false;
  static bool enableTrace = false;
  static bool enableDebug = false;
  static bool enableStackTrace = false;
  /// This flag is meant to alert the game engine that it is being
  /// run for unit testing purposes, but is currently not supported.
  static bool isUnitTestRun = false;
  static int debugStartAddr;
  static List<int> _breakPoints;
  static int instructionCounter = 0;

  static Engine _getEngineByVersion(ZVersion version) {
    switch (version) {
      case ZVersion.V1:
        return Engine();
      case ZVersion.V3:
        return Version3();
      case ZVersion.V5:
        return Version5();
      case ZVersion.V7:
        return Version7();
      case ZVersion.V8:
        return Version8();
      default:
        throw GameException(
            "Unsupported gamefile version.  This interpreter does not support $version");
    }
  }

  /// Selects the best suited [Engine] version for the game file.
  /// will also accept optional [newEngine] which will be used
  /// to run the game (throws a [GameException] if [newEngine] version
  /// and game version do not match).
  static void initializeEngine([Engine newEngine]) {
    Z.inInterrupt = true;
    if (!Z.isLoaded) {
      throw GameException(
          "Unable to initialize Z-Machine.  No game file is loaded.");
    }

    if (newEngine != null && newEngine.version != Z.ver) {
      throw GameException(
          'Machine/Story version mismatch. Expected ${Z.ver}. Got ${newEngine.version}');
    }

    Z.engine = newEngine == null ? _getEngineByVersion(Z.ver) : newEngine;
    Z.engine.mem = MemoryMap(Z.rawBytes);
    Z.engine.visitHeader();
    debug('<<< machine installed: v${Z.engine.version} >>>');
    Z.inInterrupt = false;
  }

  static Future<void> startBreak() async {
    await Z.sendIO({
      "command": IOCommands.PRINT_DEBUG,
      "message": '(break)>>> 0x${debugStartAddr.toRadixString(16)}:'
          ' opCode: ${Z.engine.mem.loadb(debugStartAddr)}'
          '\n'
          '    Locals ${dumpLocals()}\n'
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
          debug('${Z.engine.mem.dump(addr, howMany)}');
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
          debugStartAddr = Z.engine.PC;
          Z.engine.visitInstruction();
          break;
        case 'q':
          Z.inBreak = false;
          Z.callAsync(Z.runIt);
          break;
        case 'dictionary':
          debug('${Z.engine.mem.dictionary.dump()}');
          Z.callAsync(Z.runIt);
          break;
        case 'globals':
          final s = StringBuffer();

          var col = args.length == 2 ? int.parse(args[1]) : 10;
          if (col < 1) col = 1;

          for (int i = 0x10; i < 0xff; i++) {
            s.write('g${i - 16 < 10 ? "0" : ""}${i - 16}:'
                ' 0x${Z.engine.mem.readGlobal(i).toRadixString(16)}');

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
          debug('${dumpLocals()}');
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
          debug('${dumpHeader()}');
          Z.callAsync(_repl);
          break;
        default:
          debug('Unknown Command.');
          Z.callAsync(_repl);
          break;
      }
    }

    final line = await Z.sendIO({"command": IOCommands.READ});
    parse(line);
  }

  static void enableAll() {
    Debugger.enableDebug = true;
    Debugger.enableStackTrace = true;
    Debugger.enableVerbose = true;
    Debugger.enableTrace = true;
  }

  static void disableAll() {
    Debugger.enableDebug = false;
    Debugger.enableStackTrace = false;
    Debugger.enableVerbose = false;
    Debugger.enableTrace = false;
  }

  static bool isBreakPoint(int addr) {
    if (_breakPoints == null) return false;
    return _breakPoints.indexOf(addr) != -1;
  }

  static void setBreaks(breakPoints) {
    if (_breakPoints == null) {
      _breakPoints = List<int>();
    } else {
      _breakPoints.clear();
    }
    _breakPoints.addAll(breakPoints);
  }

  static String crashReport() {
    var s = StringBuffer();
    s.write('Call Stack: ${Z.engine.callStack}\n');
    s.write('Game Stack: ${Z.engine.stack}\n');
    s.write(dumpLocals());
    return s.toString();
  }

  static String dumpLocals() {
    var locals = Z.engine.callStack[2];
    StringBuffer s = StringBuffer();

    for (int i = 0; i < locals; i++) {
      s.write('(L${i}: 0x${Z.engine.readLocal(i + 1).toRadixString(16)}) ');
    }
    s.write('\n');
    return s.toString();
  }

  static String dumpHeader() {
    if (!Z.isLoaded) return '<<< Machine Not Loaded >>>\n';

    var s = StringBuffer();

    s.write('(Story contains ${Z.engine.mem.size} bytes.)\n');
    s.write('\n');
    s.write('------- START HEADER -------\n');
    s.write('Z-Machine Version: ${Z.engine.version}\n');
    s.write(
        'Flags1(binary): 0b${Z.engine.mem.loadw(Header.FLAGS1).toRadixString(2)}\n');
    // word after flags1 is used by Inform
    s.write(
        'Abbreviations Location: 0x${Z.engine.mem.abbrAddress.toRadixString(16)}\n');
    s.write(
        'Object Table Location: 0x${Z.engine.mem.objectsAddress.toRadixString(16)}\n');
    s.write(
        'Global Variables Location: 0x${Z.engine.mem.globalVarsAddress.toRadixString(16)}\n');
    s.write(
        'Static Memory Start: 0x${Z.engine.mem.staticMemAddress.toRadixString(16)}\n');
    s.write(
        'Dictionary Location: 0x${Z.engine.mem.dictionaryAddress.toRadixString(16)}\n');
    s.write(
        'High Memory Start: 0x${Z.engine.mem.highMemAddress.toRadixString(16)}\n');
    s.write(
        'Program Counter Start: 0x${Z.engine.mem.programStart.toRadixString(16)}\n');
    s.write(
        'Flags2(binary): 0b${Z.engine.mem.loadb(Header.FLAGS2).toRadixString(2)}\n');
    s.write(
        'Length Of File: ${Z.engine.mem.loadw(Header.LENGTHOFFILE) * Z.engine.fileLengthMultiplier()}\n');
    s.write(
        'Checksum Of File: ${Z.engine.mem.loadw(Header.CHECKSUMOFFILE)}\n');
    //TODO v4+ header stuff here
    s.write(
        'Standard Revision: ${Z.engine.mem.loadw(Header.REVISION_NUMBER)}\n');
    s.write('-------- END HEADER ---------\n');

    //s.write('main Routine: ${Z.machine.mem.getRange(Z.pc - 4, 10)}');

    s.write('\n');
    return s.toString();
  }

  /// Verbose Channel (via Debug)
  static void verbose(String outString) {
    //TODO support redirect to file.
    if (Debugger.enableDebug && Debugger.enableVerbose) {
      debug(outString);
    }
  }

  /// Debug Channel
  static void debug(String debugString) async {
    await Z.sendIO({
      "command": IOCommands.PRINT_DEBUG,
      "message": '$debugString'
    });
  }

  static void todo([String message]) async {
    await Z.sendIO({
      "command": IOCommands.PRINT_DEBUG,
      "message": 'Stopped At: 0x${Z.engine.PC.toRadixString(16)}\n\n'
          'Text Buffer:\n'
          '${Z.sbuff}\n'
          '${message != null ? "TODO: $message" : ""}\n'
    });

    throw Exception("Not Implemented");
  }
}
