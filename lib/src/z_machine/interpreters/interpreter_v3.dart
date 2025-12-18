import 'package:zart/src/z_machine/d_random.dart';
import 'package:zart/src/io/quetzal.dart';
import 'package:zart/src/z_machine/binary_helper.dart';
import 'package:zart/src/z_machine/dictionary.dart';
import 'package:zart/src/z_machine/game_object.dart';
import 'package:zart/src/logging.dart' show log;
import 'package:zart/src/z_machine/math_helper.dart';
import 'package:zart/src/z_machine/memory_map.dart';
import 'package:zart/src/z_machine/operand.dart';
import 'package:zart/src/z_machine/stack.dart';
import 'package:zart/src/z_machine/z_machine.dart';
import 'package:zart/src/z_machine/zscii.dart';
import 'package:zart/zart.dart';

/// Base interpreter that is compatible with Z-Machine V1 - V3.
class InterpreterV3 {
  /// Stack marker
  static const int stackMarker = -0x10000;

  /// Z-Machine False = 0
  static const int gameFalse = 0;

  /// Z-Machine True = 1
  static const int gameTrue = 1;

  /// Stack pointer
  static const int stackPointer = 0;

  /// Stack
  final Stack stack;

  /// Call stack
  final Stack callStack;

  /// Z-Machine Program Counter
  int programCounter = 0;

  /// Current window
  int currentWindow = 0;

  /// Screen
  bool outputStream1 = true;

  /// Printer lol
  bool outputStream2 = true;

  /// Memory Table
  bool outputStream3 = false;

  /// Player input script
  bool outputStream4 = false;

  late DRandom _r;

  /// Gets the program counter in hex format.
  String pcHex({int offset = 0}) =>
      '[0x${(programCounter + offset).toRadixString(16)}]';

  /// Memory map
  late MemoryMap mem;

  /// Operations
  late Map<int, Function> ops;

  /// Property defaults table size
  int get propertyDefaultsTableSize => 31;

  /// Z-Machine Version
  ZMachineVersions get version => ZMachineVersions.v3;

  /// Maximum file length
  int get maxFileLength => 128;

  /// Unpacks an address
  int unpack(int packedAddr) {
    return packedAddr << 1;
  }

  /// Packs an address
  int pack(int unpackedAddr) {
    return unpackedAddr >> 1;
  }

  /// File length multiplier
  int fileLengthMultiplier() => 2;

  /// Visits a routine
  void visitRoutine(List<int?> params) {
    //Debugger.verbose('  Calling Routine at ${pc.toRadixString(16)}');

    // assign any params passed to locals and push locals onto the call stack
    final locals = readb();

    stack.push(stackMarker);

    //Debugger.verbose('    # Locals: ${locals}');

    assert(locals < 17);

    // add param length to call stack (v5+ needs this)
    callStack.push(params.length);

    //set the routine to default locals (V3...)

    for (int i = 0; i < locals; i++) {
      if (i < params.length) {
        //if param avail, store it
        callStack.push(params[i]!);
        //Debugger.verbose('    Local ${i}: 0x${(params[i-1]).toRadixString(16)}');
        //mem.storew(pc, params[i - 1]);
      } else {
        //push otherwise push the local
        callStack.push(mem.loadw(programCounter));
        //Debugger.verbose('    Local ${i}: 0x${mem.loadw(pc).toRadixString(16)}');
      }

      programCounter += 2;
    }

    //push total locals onto the call stack
    callStack.push(locals);
  }

  /// Returns from a routine
  void doReturn(int result) {
    // return address
    programCounter = callStack.pop();
    assert(programCounter > 0);

    // result store address byte
    final resultAddrByte = callStack.pop();

    //unwind locals and params length
    callStack.stack.removeRange(0, callStack.pop() + 1);

    //unwind game stack
    while (stack.pop() != stackMarker) {}

    writeVariable(resultAddrByte, result);
  }

  /// Reads the next instruction at memory location [programCounter] and executes it.
  Future<void> visitInstruction() async {
    final i = readb();

    if (ops.containsKey(i)) {
      if (Debugger.enableDebug) {
        if (Debugger.enableTrace && !Z.inBreak) {
          Debugger.debug(
            '>>> (0x${(programCounter - 1).toRadixString(16)}) ($i)',
          );
          Debugger.debug(Debugger.dumpLocals());
        }

        if (Debugger.enableStackTrace) {
          Debugger.debug('Call Stack: $callStack');
          Debugger.debug('Game Stack: $stack');
        }

        if (Debugger.isBreakPoint(programCounter - 1)) {
          Z.inBreak = true;
          Debugger.debugStartAddr = programCounter - 1;
        }
      }
      // call the instruction and await if it's async
      await ops[i]!();
    } else {
      notFound();
    }

    // final result = readb();
    // log.finest("visitInstruction() Calling Operation: $result");
    // ops[result]();
  }

  /// Throws a [GameException] for an unsupported op code.
  void notFound() {
    throw GameException(
      'Unsupported Op Code: ${mem.loadb(programCounter - 1)}',
    );
  }

  /// Restores the game state from a save file.
  void restore() async {
    if (Z.inInterrupt) {
      return;
    }

    Z.inInterrupt = true;

    final result = await Z.sendIO({"command": IoCommands.restore});

    Z.inInterrupt = false;

    if (result == null) {
      branch(false);
    } else {
      final restoreResult = Quetzal.restore(result);
      if (!restoreResult) {
        branch(false);
      }
    }

    //PC should be set by restore here
    // Only call runIt in traditional mode - in pump mode, the caller's loop resumes execution
    if (!Z.isPumpMode) {
      Z.callAsync(Z.runIt);
    }
  }

  /// Initiates a save operation.
  /// Sends an IO command to the Z-Engine to handle the save process.
  /// ### IO Command
  /// ```json
  /// {
  ///   "command": "save",
  ///   "file_data": "<save_data>"
  /// }
  /// ```
  void save() async {
    if (Z.inInterrupt) {
      return;
    }

    Z.inInterrupt = true;

    //calculates the local jump offset (ref 4.7)
    int jumpToLabelOffset(int jumpByte) {
      if (BinaryHelper.isSet(jumpByte, 6)) {
        //single byte offset
        return BinaryHelper.bottomBits(jumpByte, 6);
      } else {
        //create the 14-bit offset value with next byte
        final val = (BinaryHelper.bottomBits(jumpByte, 6) << 8) | readb();

        //convert to Dart signed int (14-bit MSB is the sign bit)
        return ((val & 0x2000) == 0x2000) ? -(16384 - val) : val;
      }
    }

    final jumpByte = readb();

    bool branchOn = BinaryHelper.isSet(jumpByte, 7);

    final offset = jumpToLabelOffset(jumpByte);

    if (branchOn) {
      final result = await Z.sendIO({
        "command": IoCommands.save,
        "file_data": Quetzal.save(programCounter + (offset - 2)),
      });
      Z.inInterrupt = false;
      if (result) programCounter += offset - 2;
      // Only call runIt in traditional mode - in pump mode, the caller's loop resumes execution
      if (!Z.isPumpMode) {
        Z.callAsync(Z.runIt);
      }
    } else {
      final result = await Z.sendIO({
        "command": IoCommands.save,
        "file_data": Quetzal.save(programCounter),
      });
      Z.inInterrupt = false;
      if (!result) programCounter += offset - 2;
      // Only call runIt in traditional mode - in pump mode, the caller's loop resumes execution
      if (!Z.isPumpMode) {
        Z.callAsync(Z.runIt);
      }
    }
  }

  /// Branches to a label based on a test result.
  void branch(bool testResult) {
    //calculates the local jump offset (ref 4.7)

    final jumpByte = readb();
    int offset;

    if (BinaryHelper.isSet(jumpByte, 6)) {
      //single byte offset
      offset = BinaryHelper.bottomBits(jumpByte, 6);
    } else {
      //create the 14-bit offset value with next byte
      final val = (BinaryHelper.bottomBits(jumpByte, 6) << 8) | readb();

      //convert to Dart signed int (14-bit MSB is the sign bit)
      offset = ((val & 0x2000) == 0x2000) ? -(16384 - val) : val;
    }

    //Debugger.verbose('    (branch condition: $branchOn)');

    //compare test result to branchOn (true|false) bit
    if (BinaryHelper.isSet(jumpByte, 7) == testResult) {
      // If the offset is 0 or 1 (FALSE or TRUE), perform a return
      // operation.
      if (offset == InterpreterV3.gameFalse ||
          offset == InterpreterV3.gameTrue) {
        doReturn(offset);
        return;
      }

      //jump to the offset and continue...
      programCounter += (offset - 2);
      //Debugger.verbose('    (branching to 0x${pc.toRadixString(16)})');
    }

    //otherwise just continue to the next instruction...
    //Debugger.verbose('    (continuing to next instruction)');
  }

  /// Sends the status of the game to the IO handler.
  void sendStatus() {
    final oid = readVariable(0x10);
    final roomName = oid != 0 ? GameObject(oid).shortName : "";

    Z.sendIO({
      "command": IoCommands.status,
      "game_type": Header.isScoreGame() ? 'SCORE' : 'TIME',
      "room_name": roomName,
      "score_one": readVariable(0x11).toString(),
      "score_two": readVariable(0x12).toString(),
    });
  }

  /// Calls a routine with variable arguments.
  void callVS() {
    //Debugger.verbose('${pcHex(-1)} [call_vs]');
    final operands = visitOperandsVar(4, true);

    final resultStore = readb();
    final returnAddr = programCounter;

    assert(operands.isNotEmpty);

    if (operands[0].value == 0) {
      //calling routine at address 0x00 automatically returns FALSE (ref 6.4.3)

      writeVariable(resultStore, InterpreterV3.gameFalse);
    } else {
      //unpack function address
      operands[0].rawValue = unpack(operands[0].value!);

      //move to the routine address
      programCounter = operands[0].rawValue!;

      operands.removeAt(0);

      //setup the routine stack frame and locals
      visitRoutine(operands.map((o) => o.value).toList());

      //push the result store address onto the call stack
      callStack.push(resultStore);

      //push the return address onto the call stack
      callStack.push(returnAddr);
    }
  }

  /// Reads input from the user and stores it in a buffer.
  /// Reads input from the user and stores it in a buffer.
  Future<void> read() async {
    log.finest("read()");
    //Debugger.verbose('${pcHex(-1)} [read]');

    sendStatus();

    await Z.printBuffer();

    final operands = visitOperandsVar(4, true);

    final maxBytes = mem.loadb(operands[0].value!);

    var textBuffer = operands[0].value! + 1;

    final maxWords = mem.loadb(operands[1].value!);

    var parseBuffer = operands[1].value! + 1;

    log.fine(
      "read() operands: $operands maxBytes: $maxBytes, textBuffer: $textBuffer, maxWords: $maxWords, parseBuffer: $parseBuffer",
    );

    void processLine(String line) {
      line = line.trim().toLowerCase();

      //Debugger.verbose('    (processing: "$line")');

      if (line.length > maxBytes - 1) {
        line = line.substring(0, maxBytes - 2);
        //Debugger.verbose('    (text buffer truncated to "$line")');
      }

      final zChars = ZSCII.toZCharList(line);

      log.fine("zChars:  $zChars");

      log.fine("textBuffer address: $textBuffer");

      //store the zscii chars in text buffer
      for (final c in zChars) {
        mem.storeb(textBuffer++, c);
      }

      //terminator
      mem.storeb(textBuffer, 0);

      final tokens = Z.engine.mem.dictionary.tokenize(line);

      log.fine('(tokenized: $tokens)');

      final parsed = Z.engine.mem.dictionary.parse(tokens, line);
      log.fine('parsed: $parsed');

      final maxParseBufferBytes = (4 * maxWords) + 2;

      var i = 0;
      for (final p in parsed) {
        i++;
        if (i > maxParseBufferBytes) break;
        mem.storeb(parseBuffer++, p);
      }
    }

    log.finest("sending read command");

    // In pump mode, store callback and return (execution pauses)
    // In traditional mode, send to IoProvider and wait
    if (Z.isPumpMode) {
      Z.requestLineInput((String l) {
        if (l == '/!') {
          Z.inBreak = true;
          Debugger.debugStartAddr = programCounter - 1;
          log.finest("read() debug break");
        } else {
          log.finest("read() processing input");
          processLine(l);
          log.fine("pc: $programCounter");
        }
      });
      return; // Exit - execution will resume when submitLineInput is called
    }

    // Traditional mode
    final l = await Z.sendIO({"command": IoCommands.read});
    if (l == '/!') {
      Z.inBreak = true;
      Debugger.debugStartAddr = programCounter - 1;
      log.finest("read() callAsync(Debugger.startBreak)");
      Z.callAsync(Debugger.startBreak);
    } else {
      log.finest("read() processing input");
      processLine(l);
      log.fine("pc: $programCounter");
    }
  }

  /// Generates a random number.
  void random() {
    //Debugger.verbose('${pcHex(-1)} [random]');

    final operands = visitOperandsVar(1, false);

    final resultTo = readb();

    final range = operands[0].value!;

    //default return value in first two cases
    var result = 0;

    if (range < 0) {
      _r = DRandom.withSeed(range);
      //Debugger.verbose('    (set RNG to seed: $range)');
    } else if (range == 0) {
      _r = DRandom.withSeed(DateTime.now().millisecondsSinceEpoch);
      //Debugger.verbose('    (set RNG to random seed)');
    } else {
      result = _r.nextFromMax(range) + 1;
      //Debugger.verbose('    (Rolled [1 - $range] number: $result)');
    }

    writeVariable(resultTo, result);
  }

  /// Pops a value from the stack and stores it in a variable.
  void pull() {
    //Debugger.verbose('${pcHex(-1)} [pull]');
    final operand = visitOperandsVar(1, false);

    // Get the actual target variable number FIRST, before popping the value.
    // This is important for [sp=X] cases where the operand is itself read from stack.
    // For variable-type operands, we dereference to get the target
    final targetVarNum = operand[0].oType == OperandType.variable
        ? readVariable(operand[0].rawValue!)
        : operand[0].rawValue!;

    // NOW pop the value to pull
    final valueToPull = stack.pop();

    //Debugger.verbose('    Pulling 0x${valueToPull.toRadixString(16)} from to the stack.');

    // Per Z-Machine spec 6.3.4: indirect reference to sp writes in place
    if (targetVarNum == InterpreterV3.stackPointer) {
      // Write the pulled value to the current top of stack (in-place)
      stack[0] = valueToPull;
      return;
    }

    writeVariable(targetVarNum, valueToPull);
  }

  /// Pushes a value onto the stack.
  void push() {
    //Debugger.verbose('${pcHex(-1)} [push]');
    final operand = visitOperandsVar(1, false);

    //Debugger.verbose('    Pushing 0x${operand[0].value.toRadixString(16)} to the stack.');

    stack.push(operand[0].value!);

    //    if (operand[0].rawValue == 0){
    //      //pushing SP into SP would be counterintuitive...
    //      stack.push(0);
    //    }else{
    //      stack.push(readVariable(operand[0].value));
    //    }
  }

  /// Pops a value from the stack and returns it.
  void retPopped() {
    //Debugger.verbose('${pcHex(-1)} [ret_popped]');
    final v = stack.pop();

    assertNotMarker(v);

    //Debugger.verbose('    Popping 0x${v.toRadixString(16)} from the stack and returning.');
    doReturn(v);
  }

  /// Asserts that a value is not a stack marker.
  void assertNotMarker(int m) {
    if (m == InterpreterV3.stackMarker) {
      throw GameException('Stack Underflow.');
    }
  }

  /// Returns with a true value.
  void rtrue() {
    //Debugger.verbose('${pcHex(-1)} [rtrue]');
    doReturn(InterpreterV3.gameTrue);
  }

  /// Returns with a false value.
  void rfalse() {
    //Debugger.verbose('${pcHex(-1)} [rfalse]');
    doReturn(InterpreterV3.gameFalse);
  }

  /// Does nothing.
  void nop() {
    //Debugger.verbose('${pcHex(-1)} [nop]');
  }

  /// Pops a value from the stack.
  void pop() {
    //Debugger.verbose('${pcHex(-1)} [pop]');

    stack.pop();
  }

  /// Treats the instruction as a NOP.
  void showStatus() {
    //Debugger.verbose('${pcHex(-1)} [show_status]');

    //treat as NOP
  }

  /// Always verifies the game.
  void verify() {
    //Debugger.verbose('${pcHex(-1)} [verify]');

    //always verify
    branch(true);
  }

  /// Always branches.
  void piracy() {
    //Debugger.verbose('${pcHex(-1)} [piracy]');

    //always branch (game disk is genuine ;)
    branch(true);
  }

  /// Jumps to a label if the operand is zero.
  void jz() {
    //Debugger.verbose('${pcHex(-1)} [jz]');

    final operand = visitOperandsShortForm();

    branch(operand.value == 0);
  }

  /// Gets the sibling of an object.
  void getSibling() {
    //Debugger.verbose('${pcHex(-1)} [get_sibling]');

    final operand = visitOperandsShortForm();

    final resultTo = readb();

    GameObject obj = GameObject(operand.value);

    writeVariable(resultTo, obj.sibling);

    branch(obj.sibling != 0);
  }

  /// Gets the child of an object.
  void getChild() {
    //Debugger.verbose('${pcHex(-1)} [get_child]');

    final operand = visitOperandsShortForm();

    final resultTo = readb();

    GameObject obj = GameObject(operand.value);

    writeVariable(resultTo, obj.child);

    branch(obj.child != 0);
  }

  /// Increments a variable.
  void inc() {
    //Debugger.verbose('${pcHex(-1)} [inc]');

    final operand = visitOperandsShortForm();

    // Get the actual target variable number
    // For variable-type operands, we dereference to get the target
    final targetVarNum = operand.oType == OperandType.variable
        ? readVariable(operand.rawValue!)
        : operand.rawValue!;

    // Per Z-Machine spec 6.3.4: indirect reference to sp reads/writes in place
    if (targetVarNum == InterpreterV3.stackPointer) {
      final value = MathHelper.toSigned(stack.peek()) + 1;
      stack[0] = MathHelper.dartSignedIntTo16BitSigned(value);
      return;
    }

    final value = MathHelper.toSigned(readVariable(targetVarNum)) + 1;
    writeVariable(targetVarNum, value);
  }

  /// Decrements a variable.
  void dec() {
    //Debugger.verbose('${pcHex(-1)} [dec]');

    final operand = visitOperandsShortForm();

    // Get the actual target variable number
    // For variable-type operands, we dereference to get the target
    final targetVarNum = operand.oType == OperandType.variable
        ? readVariable(operand.rawValue!)
        : operand.rawValue!;

    // Per Z-Machine spec 6.3.4: indirect reference to sp reads/writes in place
    if (targetVarNum == InterpreterV3.stackPointer) {
      final value = MathHelper.toSigned(stack.peek()) - 1;
      stack[0] = MathHelper.dartSignedIntTo16BitSigned(value);
      return;
    }

    final value = MathHelper.toSigned(readVariable(targetVarNum)) - 1;
    writeVariable(targetVarNum, value);
  }

  /// Tests a bitmap against a set of flags.
  void test() {
    //Debugger.verbose('${pcHex(-1)} [test]');
    //final pp = PC - 1;

    final operands = mem.loadb(programCounter - 1) < 193
        ? visitOperandsLongForm()
        : visitOperandsVar(2, false);

    // final jumpByte = mem.loadb(PC);

    // bool branchOn = BinaryHelper.isSet(jumpByte, 7);
    final bitmap = operands[0].value!;
    final flags = operands[1].value!;

    //Debugger.verbose('   [0x${pp.toRadixString(16)}] testing bitmap($branchOn) "${bitmap.toRadixString(2)}" against "${flags.toRadixString(2)}" ${(bitmap & flags) == flags}');

    branch((bitmap & flags) == flags);
  }

  /// Decrements a variable and branches if the result is less than a specified value.
  void decChk() {
    //Debugger.verbose('${pcHex(-1)} [dec_chk]');

    final operands = mem.loadb(programCounter - 1) < 193
        ? visitOperandsLongForm()
        : visitOperandsVar(2, false);

    // Get the actual target variable number
    // For variable-type operands, we dereference to get the target
    final targetVarNum = operands[0].oType == OperandType.variable
        ? readVariable(operands[0].rawValue!)
        : operands[0].rawValue!;

    int value;

    // Per Z-Machine spec 6.3.4: indirect reference to sp reads/writes in place
    if (targetVarNum == InterpreterV3.stackPointer) {
      value = MathHelper.toSigned(stack.peek()) - 1;
      stack[0] = MathHelper.dartSignedIntTo16BitSigned(value);
    } else {
      value = MathHelper.toSigned(readVariable(targetVarNum)) - 1;
      //(ref http://www.gnelson.demon.co.uk/zspec/sect14.html notes #5)
      writeVariable(targetVarNum, value);
    }

    branch(value < MathHelper.toSigned(operands[1].value!));
  }

  /// Increments a variable and branches if the result is greater than a specified value.
  void incChk() {
    //Debugger.verbose('${pcHex(-1)} [inc_chk]');

    final operands = mem.loadb(programCounter - 1) < 193
        ? visitOperandsLongForm()
        : visitOperandsVar(2, false);

    // Get the actual target variable number
    // For variable-type operands, we dereference to get the target
    final targetVarNum = operands[0].oType == OperandType.variable
        ? readVariable(operands[0].rawValue!)
        : operands[0].rawValue!;

    int value;

    // Per Z-Machine spec 6.3.4: indirect reference to sp reads/writes in place
    if (targetVarNum == InterpreterV3.stackPointer) {
      value = MathHelper.toSigned(stack.peek()) + 1;
      stack[0] = MathHelper.dartSignedIntTo16BitSigned(value);
    } else {
      value = MathHelper.toSigned(readVariable(targetVarNum)) + 1;
      //(ref http://www.gnelson.demon.co.uk/zspec/sect14.html notes #5)
      writeVariable(targetVarNum, value);
    }

    branch(value > MathHelper.toSigned(operands[1].value!));
  }

  /// Tests an object's attribute.
  void testAttr() {
    //Debugger.verbose('${pcHex(-1)} [test_attr]');

    final operands = mem.loadb(programCounter - 1) < 193
        ? visitOperandsLongForm()
        : visitOperandsVar(2, false);

    GameObject obj = GameObject(operands[0].value);

    //Debugger.verbose('    (test Attribute) >>> object: ${obj.shortName}(${obj.id}) ${operands[1].value}: ${obj.isFlagBitSet(operands[1].value)}');
    branch(obj.isFlagBitSet(operands[1].value!));
  }

  /// Tests if an object is a child of another object.
  void jin() {
    //Debugger.verbose('${pcHex(-1)} [jin]');

    final operands = mem.loadb(programCounter - 1) < 193
        ? visitOperandsLongForm()
        : visitOperandsVar(2, false);

    final child = GameObject(operands[0].value);
    final parent = GameObject(operands[1].value);

    branch(child.parent == parent.id);
  }

  /// Tests if a value matches any of the given values.
  void jeV() {
    //Debugger.verbose('${pcHex(-1)} [jeV]');
    final operands = visitOperandsVar(4, true);

    if (operands.length < 2) {
      throw GameException('At least 2 operands required for jeV instruction.');
    }

    var foundMatch = false;

    final testVal = MathHelper.toSigned(operands[0].value!);

    for (int i = 1; i < operands.length; i++) {
      if (foundMatch == true) break;
      final against = MathHelper.toSigned(operands[i].value!);

      if (testVal == against) {
        foundMatch = true;
      }
    }

    branch(foundMatch);
  }

  /// Quits the game.
  void quit() async {
    //Debugger.verbose('${pcHex(-1)} [quit]');

    Z.inInterrupt = true;
    await Z.sendIO({
      "command": IoCommands.print,
      "window": currentWindow,
      "buffer": Z.sbuff.toString(),
    });

    Z.inInterrupt = false;
    Z.sbuff.clear();
    Z.quit = true;

    await Z.sendIO({"command": IoCommands.quit});
  }

  /// Restarts the game.
  void restart() {
    //Debugger.verbose('${pcHex(-1)} [restart]');

    Z.softReset();

    // main routine only
    programCounter--;

    // visit the main 'routine'
    visitRoutine([]);

    //push dummy result store onto the call stack
    callStack.push(0);

    //push dummy return address onto the call stack
    callStack.push(0);

    if (Z.inBreak) {
      Z.callAsync(Debugger.startBreak);
    } else {
      log.finest("run() callAsync(runIt)");
      Z.callAsync(Z.runIt);
    }
  }

  /// Branches if the first operand is less than the second.
  void jl() {
    //Debugger.verbose('${pcHex(-1)} [jl]');

    final operands = mem.loadb(programCounter - 1) < 193
        ? visitOperandsLongForm()
        : visitOperandsVar(2, false);

    branch(
      MathHelper.toSigned(operands[0].value!) <
          MathHelper.toSigned(operands[1].value!),
    );
  }

  /// Branches if the first operand is greater than the second.
  void jg() {
    //Debugger.verbose('${pcHex(-1)} [jg]');

    final operands = mem.loadb(programCounter - 1) < 193
        ? visitOperandsLongForm()
        : visitOperandsVar(2, false);

    branch(
      MathHelper.toSigned(operands[0].value!) >
          MathHelper.toSigned(operands[1].value!),
    );
  }

  /// Branches if the first operand is equal to any of the others (2OP:1).
  ///
  /// ### Z-Machine Spec Reference
  /// 2OP:1 (je a b c d ?(label))
  /// In VAR form, can have up to 4 operands. Branches if a equals any of b, c, d.
  void je() {
    //Debugger.verbose('${pcHex(-1)} [je]');

    // In VAR form (opcode >= 193), we can have up to 4 operands
    // In long form, we have exactly 2 operands
    final operands = mem.loadb(programCounter - 1) < 193
        ? visitOperandsLongForm()
        : visitOperandsVar(4, true); // Allow up to 4 operands

    if (operands.length < 2) {
      throw GameException('je instruction requires at least 2 operands');
    }

    final testVal = MathHelper.toSigned(operands[0].value!);

    // Check if testVal equals ANY of the remaining operands
    bool foundMatch = false;
    for (int i = 1; i < operands.length; i++) {
      if (testVal == MathHelper.toSigned(operands[i].value!)) {
        foundMatch = true;
        break;
      }
    }

    branch(foundMatch);
  }

  /// Adds a newline to the output buffer.
  void newline() {
    //Debugger.verbose('${pcHex(-1)} [newline]');

    Z.sbuff.write('\n');
  }

  /// Prints the short name of an object.
  void printObj() {
    //Debugger.verbose('${pcHex(-1)} [print_obj]');
    final operand = visitOperandsShortForm();

    final obj = GameObject(operand.value);

    Z.sbuff.write(obj.shortName);
  }

  /// Prints a string from memory.
  void printAddr() {
    //Debugger.verbose('${pcHex(-1)} [print_addr]');
    final operand = visitOperandsShortForm();

    final addr = operand.value!;

    final str = ZSCII.readZStringAndPop(addr);

    // DEBUG: Trace print_addr
    //print('[print_addr] addr=0x${addr.toRadixString(16)} str="$str"');

    Z.sbuff.write(str);
  }

  /// Prints a string from memory with unpacked address.
  void printPAddr() {
    //Debugger.verbose('${pcHex(-1)} [print_paddr]');

    final operand = visitOperandsShortForm();

    final addr = unpack(operand.value!);

    final str = ZSCII.readZStringAndPop(addr);

    // DEBUG: Trace print_paddr
    //print('[print_paddr] addr=0x${addr.toRadixString(16)} str="$str"');

    Z.sbuff.write(str);
  }

  /// Prints a character from the ZSCII table.
  void printChar() {
    //Debugger.verbose('${pcHex(-1)} [print_char]');

    final operands = visitOperandsVar(1, false);

    final z = operands[0].value!;

    if (z < 0 || z > 255) {
      throw GameException('ZSCII char is out of bounds.');
    }

    Z.sbuff.write(ZSCII.zCharToChar(z));
  }

  /// Prints a number.
  void printNum() {
    //Debugger.verbose('${pcHex(-1)} [print_num]');

    final operands = visitOperandsVar(1, false);

    Z.sbuff.write('${MathHelper.toSigned(operands[0].value!)}');
  }

  /// Prints a string from memory and returns.
  void printRet() {
    //Debugger.verbose('${pcHex(-1)} [print_ret]');

    final str = ZSCII.readZStringAndPop(programCounter);

    Z.sbuff.write('$str\n');

    //Debugger.verbose('${pcHex()} "$str"');

    doReturn(InterpreterV3.gameTrue);
  }

  /// Prints a string from memory and returns.
  void printf() {
    //Debugger.verbose('${pcHex(-1)} [print]');

    final str = ZSCII.readZString(programCounter);

    // DEBUG: Trace printf
    //print('[printf] pc=0x${programCounter.toRadixString(16)} str="$str"');

    Z.sbuff.write(str);

    //Debugger.verbose('${pcHex()} "$str"');

    programCounter = callStack.pop();
  }

  /// Inserts an object into another object.
  void insertObj() {
    //Debugger.verbose('${pcHex(-1)} [insert_obj]');

    final operands = mem.loadb(programCounter - 1) < 193
        ? visitOperandsLongForm()
        : visitOperandsVar(2, false);

    GameObject from = GameObject(operands[0].value);

    GameObject to = GameObject(operands[1].value);

    //Debugger.verbose('Insert Object ${from.id}(${from.shortName}) into ${to.id}(${to.shortName})');

    from.insertTo(to.id);
  }

  /// Removes an object from the object tree.
  void removeObj() {
    //Debugger.verbose('${pcHex(-1)} [remove_obj]');

    final operand = visitOperandsShortForm();

    GameObject o = GameObject(operand.value);

    //Debugger.verbose('Removing Object ${o.id}(${o.shortName}) from object tree.');
    o.removeFromTree();
  }

  /// Stores a value in a variable.
  void store() {
    //Debugger.verbose('${pcHex(-1)} [store]');

    final operands = mem.loadb(programCounter - 1) < 193
        ? visitOperandsLongForm()
        : visitOperandsVar(2, false);

    assert(operands[0].rawValue! <= 0xff);

    // Get the actual target variable number
    // For variable-type operands, we dereference to get the target
    final targetVarNum = operands[0].oType == OperandType.variable
        ? readVariable(operands[0].rawValue!)
        : operands[0].rawValue!;

    // Per Z-Machine spec 6.3.4: indirect reference to sp writes in place
    if (targetVarNum == InterpreterV3.stackPointer) {
      stack[0] = MathHelper.dartSignedIntTo16BitSigned(operands[1].value!);
      return;
    }

    writeVariable(targetVarNum, operands[1].value);
  }

  /// Loads a value from a variable.
  void load() {
    //Debugger.verbose('${pcHex(-1)} [load]');

    final operand = visitOperandsShortForm();

    final resultTo = readb();

    // Get the actual target variable number
    // For variable-type operands, we dereference to get the target
    final targetVarNum = operand.oType == OperandType.variable
        ? readVariable(operand.rawValue!)
        : operand.rawValue!;

    // Per Z-Machine spec 6.3.4: indirect reference to sp reads in place
    if (targetVarNum == InterpreterV3.stackPointer) {
      writeVariable(resultTo, stack.peek());
      return;
    }

    final v = readVariable(targetVarNum);
    writeVariable(resultTo, v);
  }

  /// Jumps to a specified offset.
  void jump() {
    //Debugger.verbose('${pcHex(-1)} [jump]');

    final operand = visitOperandsShortForm();

    final offset = MathHelper.toSigned(operand.value!) - 2;

    programCounter += offset;

    //Debugger.verbose('    (jumping to ${pcHex()})');
  }

  /// Returns from a routine.
  void ret() {
    //Debugger.verbose('${pcHex(-1)} [ret]');

    final operand = visitOperandsShortForm();

    //Debugger.verbose('    returning 0x${operand.peekValue.toRadixString(16)}');

    doReturn(operand.value!);
  }

  /// Gets the parent of an object.
  void getParent() {
    //Debugger.verbose('${pcHex(-1)} [get_parent]');

    final operand = visitOperandsShortForm();

    final resultTo = readb();

    GameObject obj = GameObject(operand.value);

    writeVariable(resultTo, obj.parent);
  }

  /// Clears an attribute of an object.
  void clearAttr() {
    //Debugger.verbose('${pcHex(-1)} [clear_attr]');

    final operands = mem.loadb(programCounter - 1) < 193
        ? visitOperandsLongForm()
        : visitOperandsVar(2, false);

    GameObject obj = GameObject(operands[0].value);

    obj.unsetFlagBit(operands[1].value!);
    //Debugger.verbose('    (clear Attribute) >>> object: ${obj.shortName}(${obj.id}) ${operands[1].value}: ${obj.isFlagBitSet(operands[1].value)}');
  }

  /// Sets an attribute of an object.
  void setAttr() {
    //Debugger.verbose('${pcHex(-1)} [set_attr]');

    final operands = mem.loadb(programCounter - 1) < 193
        ? visitOperandsLongForm()
        : visitOperandsVar(2, false);

    GameObject obj = GameObject(operands[0].value);

    obj.setFlagBit(operands[1].value!);
    //Debugger.verbose('    (set Attribute) >>> object: ${obj.shortName}(${obj.id}) ${operands[1].value}: ${obj.isFlagBitSet(operands[1].value)}');
  }

  /// Performs a bitwise OR operation.
  void or() {
    //Debugger.verbose('${pcHex(-1)} [or]');

    final operands = mem.loadb(programCounter - 1) < 193
        ? visitOperandsLongForm()
        : visitOperandsVar(2, false);

    final resultTo = readb();

    writeVariable(resultTo, (operands[0].value! | operands[1].value!));
  }

  /// Performs a bitwise AND operation.
  void and() {
    //Debugger.verbose('${pcHex(-1)} [and]');

    final operands = mem.loadb(programCounter - 1) < 193
        ? visitOperandsLongForm()
        : visitOperandsVar(2, false);

    final resultTo = readb();

    writeVariable(resultTo, (operands[0].value! & operands[1].value!));
  }

  /// Performs a subtraction operation.
  void sub() {
    //Debugger.verbose('${pcHex(-1)} [sub]');

    final operands = mem.loadb(programCounter - 1) < 193
        ? visitOperandsLongForm()
        : visitOperandsVar(2, false);

    final resultTo = readb();

    final result =
        MathHelper.toSigned(operands[0].value!) -
        MathHelper.toSigned(operands[1].value!);
    //Debugger.verbose('    >>> (sub ${pc.toRadixString(16)}) ${operands[0].value}(${toSigned(operands[0].value)}) - ${operands[1].value}(${toSigned(operands[1].value)}) = $result');
    writeVariable(resultTo, result);
  }

  /// Performs an addition operation.
  void add() {
    //Debugger.verbose('${pcHex(-1)} [add]');

    final operands = mem.loadb(programCounter - 1) < 193
        ? visitOperandsLongForm()
        : visitOperandsVar(2, false);

    final resultTo = readb();

    final result =
        MathHelper.toSigned(operands[0].value!) +
        MathHelper.toSigned(operands[1].value!);

    //Debugger.verbose('    >>> (add ${pc.toRadixString(16)}) ${operands[0].value}(${toSigned(operands[0].value)}) + ${operands[1].value}(${toSigned(operands[1].value)}) = $result');

    writeVariable(resultTo, result);
  }

  /// Performs a multiplication operation.
  void mul() {
    //Debugger.verbose('${pcHex(-1)} [mul]');

    final operands = mem.loadb(programCounter - 1) < 193
        ? visitOperandsLongForm()
        : visitOperandsVar(2, false);

    final resultTo = readb();

    final result =
        MathHelper.toSigned(operands[0].value!) *
        MathHelper.toSigned(operands[1].value!);

    //Debugger.verbose('    >>> (mul ${pc.toRadixString(16)}) ${operands[0].value}(${toSigned(operands[0].value)}) * ${operands[1].value}(${toSigned(operands[1].value)}) = $result');

    writeVariable(resultTo, result);
  }

  /// Performs a division operation.
  void div() {
    //Debugger.verbose('${pcHex(-1)} [div]');

    final operands = mem.loadb(programCounter - 1) < 193
        ? visitOperandsLongForm()
        : visitOperandsVar(2, false);

    final resultTo = readb();

    if (operands[1].value == 0) {
      // Division by zero is undefined in Z-Machine spec, but Frotz returns 0
      // to be permissive. We do the same for compatibility with games like Beyond Zork.
      writeVariable(resultTo, 0);
      return;
    }

    // final result = (toSigned(operands[0].value) / toSigned(operands[1].value)).toInt();
    final result =
        MathHelper.toSigned(operands[0].value!) ~/
        MathHelper.toSigned(operands[1].value!);

    //Debugger.verbose('    >>> (div ${pc.toRadixString(16)}) ${operands[0].value}(${toSigned(operands[0].value)}) / ${operands[1].value}(${toSigned(operands[1].value)}) = $result');

    writeVariable(resultTo, result);
  }

  // This patch is required when the first term is negative,
  // otherwise dart calculates it incorrectly according to
  // the z-machine's expectations. 2.4.3

  /// Performs a modulo operation.
  static int doMod(int a, int b) {
    var result = a.abs() % b.abs();
    if (a < 0) {
      result = -result;
    }
    return result;
  }

  /// Performs a modulo operation.
  void mod() {
    //Debugger.verbose('${pcHex(-1)} [mod]');

    final operands = mem.loadb(programCounter - 1) < 193
        ? visitOperandsLongForm()
        : visitOperandsVar(2, false);

    final resultTo = readb();

    if (operands[1].peekValue == 0) {
      // Modulo by zero is undefined in Z-Machine spec. Return 0 for consistency with div().
      writeVariable(resultTo, 0);
      return;
    }

    final x = MathHelper.toSigned(operands[0].value!);
    final y = MathHelper.toSigned(operands[1].value!);

    final result = doMod(x, y);

    //Debugger.verbose('    >>> (mod ${pc.toRadixString(16)}) ${operands[0].value}(${toSigned(operands[0].value)}) % ${operands[1].value}(${toSigned(operands[1].value)}) = $result');

    writeVariable(resultTo, result);
  }

  /// Gets the length of a property.
  void getPropLen() {
    //Debugger.verbose('${pcHex(-1)} [get_prop_len]');

    final operand = visitOperandsShortForm();

    final resultTo = readb();

    final propLen = GameObject.propertyLength(operand.value! - 1);
    //Debugger.verbose('    (${pcHex()}) property length: $propLen , addr: 0x${operand.value.toRadixString(16)}');
    writeVariable(resultTo, propLen);
  }

  /// Performs a bitwise NOT operation.
  void not() {
    //Debugger.verbose('${pcHex(-1)} [not]');

    final operand = visitOperandsShortForm();

    final resultTo = readb();

    writeVariable(resultTo, ~operand.value!);
  }

  /// Gets the next property of an object.
  void getNextProp() {
    //Debugger.verbose('${pcHex(-1)} [get_next_prop]');

    final operands = mem.loadb(programCounter - 1) < 193
        ? visitOperandsLongForm()
        : visitOperandsVar(2, false);

    final resultTo = readb();

    final obj = GameObject(operands[0].value);

    final nextProp = obj.getNextProperty(operands[1].value);
    //Debugger.verbose('    (${pcHex()}) [${obj.id}] prop: ${operands[1].value} next prop:  ${nextProp}');
    writeVariable(resultTo, nextProp);
  }

  /// Gets the address of a property of an object.
  void getPropAddr() {
    //Debugger.verbose('${pcHex(-1)} [get_prop_addr]');

    final operands = mem.loadb(programCounter - 1) < 193
        ? visitOperandsLongForm()
        : visitOperandsVar(2, false);

    final resultTo = readb();

    final obj = GameObject(operands[0].value);

    final addr = obj.getPropertyAddress(operands[1].value);

    //Debugger.verbose('    (${pc.toRadixString(16)}) [${obj.id}] propAddr(${operands[1].value}): ${addr.toRadixString(16)}');

    writeVariable(resultTo, addr);
  }

  /// Gets the value of a property of an object.
  void getProp() {
    //Debugger.verbose('${pcHex(-1)} [get_prop]');

    final operands = mem.loadb(programCounter - 1) < 193
        ? visitOperandsLongForm()
        : visitOperandsVar(2, false);

    final resultTo = readb();

    final obj = GameObject(operands[0].value);

    final value = obj.getPropertyValue(operands[1].value!);

    //Debugger.verbose('    (${pc.toRadixString(16)}) [${obj.id}] getPropValue(${operands[1].value}): ${value.toRadixString(16)}');

    writeVariable(resultTo, value);
  }

  /// Sets the value of a property of an object.
  void putProp() {
    //Debugger.verbose('${pcHex(-1)} [put_prop]');

    final operands = visitOperandsVar(3, false);

    final obj = GameObject(operands[0].value);

    //Debugger.verbose('    (${pc.toRadixString(16)}) [${obj.id}] putProp(${operands[1].value}): ${operands[2].value.toRadixString(16)}');

    obj.setPropertyValue(operands[1].value, operands[2].value);
  }

  /// Loads a byte from memory.
  void loadByte() {
    //Debugger.verbose('${pcHex(-1)} [loadb]');

    final operands = mem.loadb(programCounter - 1) < 193
        ? visitOperandsLongForm()
        : visitOperandsVar(2, false);

    final resultTo = readb();

    // Z-Machine spec: address must be 0-65535, use unsigned arithmetic
    final addr = (operands[0].value! + operands[1].value!) & 0xFFFF;

    //Debugger.todo();
    writeVariable(resultTo, mem.loadb(addr));

    //Debugger.verbose('    loaded 0x${peekVariable(resultTo).toRadixString(16)} from 0x${addr.toRadixString(16)} into 0x${resultTo.toRadixString(16)}');
  }

  /// Loads a word from memory.
  void loadWord() {
    //Debugger.verbose('${pcHex(-1)} [loadw]');

    final operands = mem.loadb(programCounter - 1) < 193
        ? visitOperandsLongForm()
        : visitOperandsVar(2, false);

    final resultTo = readb();

    // Z-Machine spec: address must be 0-65535, use unsigned arithmetic
    final addr = (operands[0].value! + 2 * operands[1].value!) & 0xFFFF;

    //    assert(addr <= mem.highMemAddress);

    writeVariable(resultTo, mem.loadw(addr));
    //Debugger.verbose('    loaded 0x${peekVariable(resultTo).toRadixString(16)} from 0x${addr.toRadixString(16)} into 0x${resultTo.toRadixString(16)}');
  }

  /// Stores a byte in memory.
  void storebv() {
    //Debugger.verbose('${pcHex(-1)} [storebv]');

    final operands = visitOperandsVar(3, false);

    assert(operands.length == 3);

    // Z-Machine spec: address must be 0-65535, use unsigned arithmetic
    final addr = (operands[0].value! + operands[1].value!) & 0xFFFF;
    //
    //    assert(operands[2].value <= 0xff);

    mem.storeb(addr, operands[2].value! & 0xFF);

    //Debugger.verbose('    stored 0x${operands[2].value.toRadixString(16)} at addr: 0x${addr.toRadixString(16)}');
  }

  /// Variable arguement version of storew
  void storewv() {
    //Debugger.verbose('${pcHex(-1)} [storewv]');

    final operands = visitOperandsVar(3, false);

    //(ref http://www.gnelson.demon.co.uk/zspec/sect15.html#storew)
    // Z-Machine spec: address must be 0-65535, use unsigned arithmetic
    final addr = (operands[0].value! + 2 * operands[1].value!) & 0xFFFF;

    assert(addr <= mem.highMemAddress);

    mem.storew(addr, operands[2].value!);

    //Debugger.verbose('    stored 0x${operands[2].value.toRadixString(16)} at addr: 0x${addr.toRadixString(16)}');
  }

  /// Visits operands in short form.
  Operand visitOperandsShortForm() {
    final oc = mem.loadb(programCounter - 1);

    //(ref 4.4.1)
    final operand = Operand((oc & 48) >> 4);

    operand.rawValue = (operand.oType == OperandType.large) ? readw() : readb();

    //Debugger.verbose('    ${operand}');
    return operand;
  }

  /// Visits operands in long form.
  List<Operand> visitOperandsLongForm() {
    final oc = mem.loadb(programCounter - 1);

    final o1 = BinaryHelper.isSet(oc, 6)
        ? Operand(OperandType.variable)
        : Operand(OperandType.small);

    final o2 = BinaryHelper.isSet(oc, 5)
        ? Operand(OperandType.variable)
        : Operand(OperandType.small);

    o1.rawValue = readb();
    o2.rawValue = readb();

    //Debugger.verbose('    ${o1}, ${o2}');

    return [o1, o2];
  }

  /// Visits operands in variable form.
  List<Operand> visitOperandsVar(int howMany, bool isVariable) {
    final operands = <Operand>[];

    //load operand types
    var shiftStart = howMany > 4 ? 14 : 6;
    final os = howMany > 4 ? readw() : readb();

    while (shiftStart > -2) {
      var to = os >> shiftStart; //shift
      to &= 3; //mask higher order bits we don't care about
      if (to == OperandType.omitted) {
        break;
      } else {
        operands.add(Operand(to));
        if (operands.length == howMany) break;
        shiftStart -= 2;
      }
    }

    //load values
    for (var o in operands) {
      assert(o.oType != OperandType.omitted);
      o.rawValue = o.oType == OperandType.large ? readw() : readb();
    }

    //    //Debugger.verbose('    ${operands.length} operands:');

    //    operands.forEach((Operand o) {
    //      if (o.type == OperandType.VARIABLE){
    //        if (o.rawValue == 0){
    //          //Debugger.verbose('      ${OperandType.asString(o.type)}: SP (0x${o.peekValue.toRadixString(16)})');
    //        }else{
    //          //Debugger.verbose('      ${OperandType.asString(o.type)}: 0x${o.rawValue.toRadixString(16)} (0x${o.peekValue.toRadixString(16)})');
    //        }
    //
    //      }else{
    //        //Debugger.verbose('      ${OperandType.asString(o.type)}: 0x${o.peekValue.toRadixString(16)}');
    //      }
    //    });

    if (!isVariable && (operands.length != howMany)) {
      throw Exception(
        'Operand count mismatch.  Expected $howMany, found ${operands.length}',
      );
    }

    return operands;
  }

  /// Visits the header.
  void visitHeader() {
    mem.abbrAddress = mem.loadw(Header.abbreviationsTableAddr);
    mem.objectsAddress = mem.loadw(Header.objectTableAddr);
    mem.globalVarsAddress = mem.loadw(Header.globalVarsTableAddr);
    mem.staticMemAddress = mem.loadw(Header.staticMemBaseAddr);
    mem.dictionaryAddress = mem.loadw(Header.dictionaryAddr);
    mem.highMemAddress = mem.loadw(Header.highMemStartAddr);

    // Store a screen height and width.
    // Height is capped at 254 (not 255) because 255 means "infinite" and breaks some games.
    // See ifvms.js reference implementation.
    mem.storeb(Header.screenHeight, 254);
    mem.storeb(Header.screenWidth, 80);

    // For V5+ games, set additional screen/font unit fields
    // These are words at 0x22 (width units) and 0x24 (height units)
    // For text-based interpreters, 1 unit = 1 character
    if (version.index >= ZMachineVersions.v5.index) {
      mem.storew(Header.screenWidthUnits, 80); // 0x22: screen width in units
      mem.storew(Header.screenHeightUnits, 254); // 0x24: screen height in units
      // Font height/width in "units" - set to 1x1 for character-based display
      mem.storew(
        Header.fontWidthUnits,
        0x0101,
      ); // 0x26: both font width and height = 1
    }

    // Set Interpreter Version (ASCII char) to 'S' (Standard) - Ref 0x1F
    // Used by some games to verify "Standard" compliance.
    mem.storeb(Header.interpreterVersion, 83); // 'S'

    // Using interpreter standard version 1.2 (matching ifvms.js)
    // 0x32 is a word: high byte = major, low byte = minor
    mem.storew(Header.revisionNumberN, 0x0102);

    // Get capability flags from IoProvider and merge with existing flags
    final providerFlags = Z.io.getFlags1();
    final currentFlags = mem.loadb(Header.flags1);
    final combinedFlags = currentFlags | providerFlags;
    //print('[DEBUG visitHeader] providerFlags=0x${providerFlags.toRadixString(16)}, currentFlags=0x${currentFlags.toRadixString(16)}, combined=0x${combinedFlags.toRadixString(16)}');
    mem.storeb(Header.flags1, combinedFlags);

    // Flags 2: Clear bits 3, 5, 7 to indicate no character graphics, mouse, or sound effects
    // This matches ifvms.js: ram.setUint8(0x11, ram.getUint8(0x11) & 0x57)
    // Header.flags2 is 0x10, so we must access 0x11 (low byte) for these bits.
    final currentFlags2 = mem.loadb(Header.flags2 + 1);
    mem.storeb(Header.flags2 + 1, currentFlags2 & 0x57);

    //initialize the game dictionary
    mem.dictionary = Dictionary(address: mem.dictionaryAddress);

    mem.programStart = mem.loadw(Header.programCounterInitialValueAddr);
    programCounter = mem.programStart!;

    //Debugger.verbose(Debugger.dumpHeader());
  }

  /// Reads 1 byte from the current program counter
  /// address and advances the program counter [programCounter] to the next
  /// unread address.
  ///
  /// ### Equivalency:
  /// ```
  /// final result = this.mem.loadb(PC);
  /// PC++;
  /// ```
  int readb() => mem.loadb(programCounter++);

  /// Reads 1 word from the current program counter
  /// address and advances the program counter [programCounter] to the next
  /// unread address.
  ///
  /// ### Equivalency:
  /// ```
  /// final result = this.mem.loadw(PC);
  /// PC += 2;
  /// ```
  int readw() {
    final word = mem.loadw(programCounter);
    programCounter += 2;
    return word;
  }

  /// Peeks at a variable.
  int? peekVariable(int? varNum) {
    if (varNum == 0x00) {
      //top of stack
      final result = stack.peek();
      return result;
    } else if (varNum! <= 0x0f) {
      return readLocal(varNum);
    } else if (varNum <= 0xff) {
      return mem.readGlobal(varNum);
    } else {
      return varNum;
      // throw Exception('Variable referencer byte'
      //   ' out of range (0-255): ${varNum}');
    }
  }

  /// Reads a variable.
  int readVariable(int varNum) {
    assert(varNum >= 0 && varNum <= 0xff);

    if (varNum > 0x0f) {
      return mem.readGlobal(varNum);
    }
    if (varNum == 0x00) {
      return stack.pop();
    }
    return readLocal(varNum);
  }

  /// Writes [value] to [varNum] either global or local.
  void writeVariable(int varNum, int? value) {
    assert(varNum >= 0 && varNum <= 0xff);
    if (varNum < 0 || varNum > 0xff) {
      log.warning(
        "writeVariable expected range >= 0 and <=${0xff}, but got $varNum",
      );
    }

    if (varNum > 0x0f) {
      mem.writeGlobal(varNum, value!);
      return;
    }

    if (varNum == 0x0) {
      stack.push(value!);
      return;
    }

    _writeLocal(varNum, value!);
  }

  void _writeLocal(int local, int value) {
    assert(local <= callStack[2]);

    assert(callStack[2] - local > -1);

    callStack[(callStack[2] - local) + 3] = value;
  }

  /// Reads a local variable.
  int readLocal(int local) {
    // final locals = callStack[2]; //locals header
    assert(local <= callStack[2]);

    return callStack[(callStack[2] - local) + 3];
  }

  /// Initializes the engine.
  InterpreterV3()
    : stack = Stack(),
      // stack max  used to be 1024 for older games.
      // newer games required much larger sometimes.
      // 6.3.3.
      callStack = Stack.max(61440) {
    _r = DRandom.withSeed(DateTime.now().millisecond);
    ops = {
      /* 2OP, small, small */
      1: je,
      2: jl,
      3: jg,
      4: decChk,
      5: incChk,
      6: jin,
      7: test,
      8: or,
      9: and,
      10: testAttr,
      11: setAttr,
      12: clearAttr,
      13: store,
      14: insertObj,
      15: loadWord,
      16: loadByte,
      17: getProp,
      18: getPropAddr,
      19: getNextProp,
      20: add,
      21: sub,
      22: mul,
      23: div,
      24: mod,
      /* 25 : call_2s */
      25: notFound,
      /* 26 : call_2n */
      26: notFound,
      /* 27 : set_colour */
      27: notFound,
      /* 28 : throw */
      28: notFound,

      /* 2OP, small, variable */
      33: je,
      34: jl,
      35: jg,
      36: decChk,
      37: incChk,
      38: jin,
      39: test,
      40: or,
      41: and,
      42: testAttr,
      43: setAttr,
      44: clearAttr,
      45: store,
      46: insertObj,
      47: loadWord,
      48: loadByte,
      49: getProp,
      50: getPropAddr,
      51: getNextProp,
      52: add,
      53: sub,
      54: mul,
      55: div,
      56: mod,
      /* 57 : call_2s */
      57: notFound,
      /* 58 : call_2n */
      58: notFound,
      /* 59 : set_colour */
      59: notFound,
      /* 60 : throw */
      60: notFound,

      /* 2OP, variable, small */
      65: je,
      66: jl,
      67: jg,
      68: decChk,
      69: incChk,
      70: jin,
      71: test,
      72: or,
      73: and,
      74: testAttr,
      75: setAttr,
      76: clearAttr,
      77: store,
      78: insertObj,
      79: loadWord,
      80: loadByte,
      81: getProp,
      82: getPropAddr,
      83: getNextProp,
      84: add,
      85: sub,
      86: mul,
      87: div,
      88: mod,
      /* 89 : call_2s */
      89: notFound,
      /* 90 : call_2n */
      90: notFound,
      /* 91 : set_colour */
      91: notFound,
      /* 92 : throw */
      92: notFound,

      /* 2OP, variable, variable */
      97: je,
      98: jl,
      99: jg,
      100: decChk,
      101: incChk,
      102: jin,
      103: test,
      104: or,
      105: and,
      106: testAttr,
      107: setAttr,
      108: clearAttr,
      109: store,
      110: insertObj,
      111: loadWord,
      112: loadByte,
      113: getProp,
      114: getPropAddr,
      115: getNextProp,
      116: add,
      117: sub,
      118: mul,
      119: div,
      120: mod,
      /* 121 : call_2s */
      121: notFound,
      /* 122 : call_2n */
      122: notFound,
      /* 123 : set_colour */
      123: notFound,
      /* 124 : throw */
      124: notFound,

      /* 1OP, large */
      128: jz,
      129: getSibling,
      130: getChild,
      131: getParent,
      132: getPropLen,
      133: inc,
      134: dec,
      135: printAddr,
      /* 136 : call_1s */
      136: notFound,
      137: removeObj,
      138: printObj,
      139: ret,
      140: jump,
      141: printPAddr,
      142: load,
      143: not,

      /*** 1OP, small ***/
      144: jz,
      145: getSibling,
      146: getChild,
      147: getParent,
      148: getPropLen,
      149: inc,
      150: dec,
      151: printAddr,
      /* 152 : call_1s */
      152: notFound,
      153: removeObj,
      154: printObj,
      155: ret,
      156: jump,
      157: printPAddr,
      158: load,
      159: not,

      /*** 1OP, variable ***/
      160: jz,
      161: getSibling,
      162: getChild,
      163: getParent,
      164: getPropLen,
      165: inc,
      166: dec,
      167: printAddr,
      /* 168 : call_1s */
      168: notFound,
      169: removeObj,
      170: printObj,
      171: ret,
      172: jump,
      173: printPAddr,
      174: load,
      175: not,

      /* 0 OP */
      176: rtrue,
      177: rfalse,
      178: printf,
      179: printRet,
      180: nop,
      181: save,
      182: restore,
      183: restart,
      184: retPopped,
      185: pop,
      186: quit,
      187: newline,
      188: showStatus,
      189: verify,
      /* 190 : extended */
      190: notFound,
      191: piracy,

      /* 2OP, Variable of op codes 1-31 */
      193: jeV,
      194: jl,
      195: jg,
      196: decChk,
      197: incChk,
      198: jin,
      199: test,
      200: or,
      201: and,
      202: testAttr,
      203: setAttr,
      204: clearAttr,
      205: store,
      206: insertObj,
      207: loadWord,
      208: loadByte,
      209: getProp,
      210: getPropAddr,
      211: getNextProp,
      212: add,
      213: sub,
      214: mul,
      215: div,
      216: mod,
      /* 217 : call_2sV */
      217: notFound,
      /* 218 : call_2nV */
      218: notFound,
      /* 219 : set_colourV */
      219: notFound,
      /* 220 : throwV */
      220: notFound,

      /* xOP, Operands Vary */
      224: callVS,
      225: storewv,
      226: storebv,
      227: putProp,
      228: read,
      229: printChar,
      230: printNum,
      231: random,
      232: push,
      233: pull,
      /* 234 : split_window */
      234: notFound,
      /* 235 : set_window */
      235: notFound,
      /* 236 : call_vs2 */
      236: notFound,
      /* 237 : erase_window */
      237: notFound,
      /* 238 : erase_line */
      238: notFound,
      /* 239 : set_cursor */
      239: notFound,
      /* 240 : get_cursor */
      240: notFound,
      /* 241 : set_text_style */
      241: notFound,
      /* 242 : buffer_mode_flag */
      242: notFound,
      /* 243 : output_stream */
      243: notFound,
      /* 244 : input_stream */
      244: notFound,
      /* 245 : sound_effect */
      245: notFound,
      /* 246 : read_char */
      246: notFound,
      /* 247 : scan_table */
      247: notFound,
      /* 248 : not */
      248: notFound,
      /* 249 : call_vn */
      249: notFound,
      /* 250 : call_vn2 */
      250: notFound,
      /* 251 : tokenise */
      251: notFound,
      /* 252 : encode_text */
      252: notFound,
      /* 253 : copy_table */
      253: notFound,
      /* 254 : print_table */
      254: notFound,
      /* 255 : check_arg_count */
      255: notFound,
    };
  }
}
