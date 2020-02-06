import 'dart:math';

import 'package:zart/IO/io_provider.dart';
import 'package:zart/game_exception.dart';
import 'package:zart/game_object.dart';
import 'package:zart/header.dart';
import 'package:zart/machines/machine.dart';
import 'package:zart/memory_map.dart';
import 'package:zart/zart.dart';

/// A runtime debugger for Z-Machine.
class Debugger {
  static bool enableVerbose = false;
  static bool enableTrace = false;
  static bool enableDebug = false;
  static bool enableStackTrace = false;
  static bool isUnitTestRun = false;

  static int debugStartAddr;

  static List<int> _breakPoints;

  static int instructionsCounter = 0;

  static void setMachine(Machine newMachine) {
    Z.inInterrupt = true;
    if (Z.isLoaded) {
      if (newMachine.version != Z.ver) {
        throw GameException('Machine/Story version mismatch.');
      }
    }

    Z.machine = newMachine;
    Z.machine.mem = MemoryMap(Z.rawBytes);
    Z.machine.visitHeader();
    debug('<<< machine installed: v${newMachine.version} >>>');
    Z.inInterrupt = false;
  }

  static void startBreak() async {
    await Z.sendIO(IOCommands.PRINT_DEBUG, [
      '(break)>>> 0x${debugStartAddr.toRadixString(16)}:'
          ' opCode: ${Z.machine.mem.loadb(debugStartAddr)}'
          '\n'
          '    Locals ${dumpLocals()}\n'
    ]);

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
          debug('${Z.machine.mem.dump(addr, howMany)}');
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
          debugStartAddr = Z.machine.PC;
          Z.machine.visitInstruction();
          break;
        case 'q':
          Z.inBreak = false;
          Z.callAsync(Z.runIt);
          break;
        case 'dictionary':
          debug('${Z.machine.mem.dictionary.dump()}');
          Z.callAsync(Z.runIt);
          break;
        case 'globals':
          final s = StringBuffer();

          var col = args.length == 2 ? int.parse(args[1]) : 10;
          if (col < 1) col = 1;

          for (int i = 0x10; i < 0xff; i++) {
            s.write('g${i - 16 < 10 ? "0" : ""}${i - 16}:'
                ' 0x${Z.machine.mem.readGlobal(i).toRadixString(16)}');

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
          debug('call stack: ${Z.machine.callStack}');
          debug('eval stack: ${Z.machine.stack}');
          Z.callAsync(_repl);
          break;
        case 'object':
          var obj = GameObject(int.parse(args[1]));
          obj.dump();
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

    final line = await Z.sendIO(IOCommands.READ, []);
    parse(line);
  }

  static String whitespace(int amount, [String kind = ' ']) {
    final sb = StringBuffer();
    for (var i = 0; i < amount; i++) {
      sb.write(kind);
    }

    return sb.toString();
  }

  static Set<int> objects = Set<int>();
  static var highestObject = 0;

  static String _writeChildren(int objectNum, int indent) {
    final sb = StringBuffer();
    final obj = GameObject(objectNum);
    final child = obj.child != 0 ? GameObject(obj.child).shortName : "";
    final sibling = obj.sibling != 0 ? GameObject(obj.sibling).shortName : "";
    sb.writeln(
        "${whitespace(indent, '.')}${obj.shortName}(${obj.id}), child: $child(${obj.child}), sib: $sibling(${obj.sibling})");

    if (obj.child != 0) {
      updateObjectState(obj.child);
      sb.write(_writeChildren(obj.child, indent + 3));
    }

    if (obj.sibling != 0) {
      updateObjectState(obj.sibling);
      sb.write(_writeChildren(obj.sibling, indent));
    }

    return sb.toString();
  }

  static void updateObjectState(int objectNum) {
    highestObject = max<int>(objectNum, highestObject);
    objects.add(objectNum);
  }

  static int getNextAvailableObject(){
    int i = highestObject;

    while(i > 0){
      if (objects.contains(i)){
        i--;
        continue;
      }

      return i;
    }

    return -1;
  }

  static String getObjectTree([int objectNum = 1]) {
    highestObject = 0;
    objects.clear();
    updateObjectState(objectNum);

    final sb = StringBuffer();
          //first find root parent, which we assume is 0...
      var rootObject = GameObject(objectNum);

    void doTree(GameObject currentObject) {
      while (currentObject.parent != 0) {
        currentObject = GameObject(currentObject.parent);
      }

      sb.writeln(
          "${currentObject.shortName}(${currentObject.id}) child: ${currentObject.child}, sib: ${currentObject.sibling}");

      if (currentObject.child != 0) {
        updateObjectState(currentObject.child);
        sb.write(_writeChildren(currentObject.child, 3));
      }

      if (currentObject.sibling != 0) {
        updateObjectState(currentObject.sibling);
        sb.write(_writeChildren(currentObject.sibling, 0));
      }
    }

    doTree(rootObject);

    while(highestObject > objects.length){
      final nextObjectId = getNextAvailableObject();
      if (nextObjectId < 1) break;
      updateObjectState(nextObjectId);
      final next = GameObject(nextObjectId);
      doTree(next);
    }

    sb.writeln("");
    sb.writeln("Total Objects Found: ${objects.length}");
    sb.writeln(
        "Highest Object: ${GameObject(highestObject).shortName}($highestObject)");
    return sb.toString();
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
    s.write('Call Stack: ${Z.machine.callStack}\n');
    s.write('Game Stack: ${Z.machine.stack}\n');
    s.write(dumpLocals());
    return s.toString();
  }

  static String dumpLocals() {
    var locals = Z.machine.callStack[2];
    StringBuffer s = StringBuffer();

    for (int i = 0; i < locals; i++) {
      s.write('(L${i}: 0x${Z.machine.readLocal(i + 1).toRadixString(16)}) ');
    }
    s.write('\n');
    return s.toString();
  }

  static String dumpHeader() {
    if (!Z.isLoaded) return '<<< Machine Not Loaded >>>\n';

    var s = StringBuffer();

    s.write('(Story contains ${Z.machine.mem.size} bytes.)\n');
    s.write('\n');
    s.write('------- START HEADER -------\n');
    s.write('Z-Machine Version: ${Z.machine.version}\n');
    s.write(
        'Flags1(binary): 0b${Z.machine.mem.loadw(Header.FLAGS1).toRadixString(2)}\n');
    // word after flags1 is used by Inform
    s.write(
        'Abbreviations Location: 0x${Z.machine.mem.abbrAddress.toRadixString(16)}\n');
    s.write(
        'Object Table Location: 0x${Z.machine.mem.objectsAddress.toRadixString(16)}\n');
    s.write(
        'Global Variables Location: 0x${Z.machine.mem.globalVarsAddress.toRadixString(16)}\n');
    s.write(
        'Static Memory Start: 0x${Z.machine.mem.staticMemAddress.toRadixString(16)}\n');
    s.write(
        'Dictionary Location: 0x${Z.machine.mem.dictionaryAddress.toRadixString(16)}\n');
    s.write(
        'High Memory Start: 0x${Z.machine.mem.highMemAddress.toRadixString(16)}\n');
    s.write(
        'Program Counter Start: 0x${Z.machine.mem.programStart.toRadixString(16)}\n');
    s.write(
        'Flags2(binary): 0b${Z.machine.mem.loadb(Header.FLAGS2).toRadixString(2)}\n');
    s.write(
        'Length Of File: ${Z.machine.mem.loadw(Header.LENGTHOFFILE) * Z.machine.fileLengthMultiplier()}\n');
    s.write(
        'Checksum Of File: ${Z.machine.mem.loadw(Header.CHECKSUMOFFILE)}\n');
    //TODO v4+ header stuff here
    s.write(
        'Standard Revision: ${Z.machine.mem.loadw(Header.REVISION_NUMBER)}\n');
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
  static void debug(String debugString) {
    Z.sendIO(IOCommands.PRINT_DEBUG, ['(Zart Debug) $debugString']);
  }

  static void todo([String message]) async {
    await Z.sendIO(IOCommands.PRINT_DEBUG, [
      'Stopped At: 0x${Z.machine.PC.toRadixString(16)}\n\n'
          'Text Buffer:\n'
          '${Z.sbuff}\n'
          '${message != null ? "TODO: $message" : ""}\n'
    ]);

    throw Exception("Not Implemented");
  }
}
