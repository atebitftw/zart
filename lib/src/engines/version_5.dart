import 'package:zart/src/engines/version_4.dart';
import 'package:zart/src/engines/engine.dart';
import 'package:zart/src/logging.dart' show log;
import 'package:zart/src/math_helper.dart';
import 'package:zart/src/operand.dart';
import 'package:zart/src/z_machine.dart';
import 'package:zart/zart.dart';
import 'package:zart/src/zscii.dart';

/// Implementation of Z-Machine v5
class Version5 extends Version4 {
  @override
  ZMachineVersions get version => ZMachineVersions.v5;

  //TODOs
  // check_arg_count (add arg count to stack frame)
  // output_stream to table
  // save
  // restore
  // catch
  // aread (read)
  // sound_effect
  // not
  // set_colour
  // throw
  // call_vs2
  // erase_line
  // get_cursor
  // buffer_mode
  // scan_table
  // call_vn2
  // tokenise
  // encode_text
  // copy_table
  // print_table
  // EXT save
  // EXT restore
  // EXT log_shift
  // EXT art_shift
  // EXT restore_undo
  // EXT print_unicode
  // EXT check_unicode

  /// Creates a new instance of [Version5].
  Version5() {
    ops[136] = call_1s;
    ops[168] = call_1s;
    ops[143] = call_1n;
    ops[175] = call_1n;
    ops[190] = visitExtendedInstruction;
    // call_2s: 2OP instruction #25 - all operand type encodings
    // (small/small=25, small/var=57, var/small=89, var/var=121, VAR=217)
    ops[25] = call_2s;
    ops[57] = call_2s;
    ops[89] = call_2s;
    ops[121] = call_2s;
    ops[217] = call_2s;
    // call_2n: 2OP instruction #26 - all operand type encodings
    // (small/small=26, small/var=58, var/small=90, var/var=122, VAR=218)
    ops[26] = call_2n;
    ops[58] = call_2n;
    ops[90] = call_2n;
    ops[122] = call_2n;
    ops[218] = call_2n;
    ops[234] = splitWindow;
    ops[235] = setWindow;
    ops[236] = callVS2;
    ops[237] = eraseWindow;
    ops[239] = setCursor;
    ops[241] = setTextStyle;
    ops[242] = bufferMode;
    ops[243] = outputStream;
    ops[246] = readChar;
    ops[249] = callVN;
    ops[250] = callVN2;
    ops[251] = tokenise;
    ops[253] = copyTable;
    ops[255] = checkArgCount;
    // the extended instruction visitExtendedInstruction() adds 300 to the value, so it's offset from the other op codes safely.
    ops[304] = extSetFont; //ext4
    ops[309] = extSaveUndo; //ext5
  }

  // Kb
  @override
  int get maxFileLength => 256;

  /// V4+ games have 63 property defaults (126 bytes) instead of 31 (62 bytes).
  /// This is critical for correct object address calculations.
  @override
  int get propertyDefaultsTableSize => 63;

  @override
  int unpack(int packedAddr) => packedAddr << 2;

  @override
  int pack(int unpackedAddr) => unpackedAddr >> 2;

  @override
  int fileLengthMultiplier() => 2;

  @override
  void visitRoutine(List<int?> params) {
    assert(params.length < 9);

    //Debugger.verbose('  Calling Routine at ${pc.toRadixString(16)}');

    // assign any params passed to locals and push locals onto the call stack
    var locals = readb();

    stack.push(Engine.stackMarker);

    ////Debugger.verbose('    # Locals: ${locals}');

    assert(locals < 17);

    // add param length to call stack (v5+ needs this)
    callStack.push(params.length);

    //set the params and locals
    for (int i = 0; i < locals; i++) {
      //in V5, we don't need to read locals from memory, they are all set to 0

      callStack.push(i < params.length ? params[i]! : 0x0);
    }
    //push total locals onto the call stack
    callStack.push(locals);
  }

  /// Copies a table.
  void copyTable() {
    //Debugger.verbose('${pcHex(-1)} [copy_table]');

    var operands = visitOperandsVar(3, false);

    int t1Addr = operands[0].value!;

    var t2Addr = operands[1].value;

    var size = operands[2].value;

    if (t2Addr == 0) {
      //write size of 0's into t1
      mem.storew(t1Addr, size! >> 1);
      t1Addr += 2;
      for (int i = 0; i < size; i++) {
        mem.storeb(t1Addr++, 0);
      }
    } else {
      var absSize = size!.abs();
      var t1End = t1Addr + mem.loadw(t1Addr);
      if (t2Addr! >= t1Addr && t2Addr <= t1End) {
        //overlap copy...

        Debugger.todo(
          'implement overlap copy: t1 end: 0x${(t1Addr + mem.loadw(t1Addr)).toRadixString(16)}, t2 start: 0x${t2Addr.toRadixString(16)}',
        );
      } else {
        //copy
        Debugger.debug('>>> Copying $absSize bytes.');
        for (int i = 0; i < absSize; i++) {
          var offset = 2 + i;
          mem.storeb(t2Addr + offset, mem.loadb(t1Addr + offset));
        }
        mem.storew(t2Addr, absSize);
      }
    }
  }

  /// Sets the buffer mode.
  void bufferMode() {
    //Debugger.verbose('${pcHex(-1)} [buffer_mode]');

    visitOperandsVar(1, false);

    //this is basically a no op
  }

  /// Tokenizes a string.
  void tokenise() {
    //Debugger.verbose('${pcHex(-1)} [tokenise]');

    var operands = visitOperandsVar(4, true);

    if (operands.length > 2) {
      throw GameException("tokenise dictionary argument is not yet support in v5+");
    }

    var maxBytes = mem.loadb(operands[0].value!);

    var textBuffer = operands[0].value! + 2;

    var maxWords = mem.loadb(operands[1].value!);

    var parseBuffer = operands[1].value! + 1;

    var line = Z.mostRecentInput.toLowerCase();

    //Debugger.verbose('    (processing: "$line")');

    var charCount = mem.loadb(textBuffer - 1);
    //Debugger.debug('existing chars: $charCount');

    if (charCount > 0) {
      //continuation of previous input
      maxBytes -= charCount;
    }

    if (line.length > maxBytes - 1) {
      final newLine = line.substring(0, maxBytes - 2);
      log.warning("text buffer truncated:  $line to $newLine");
      line = newLine;
      //Debugger.verbose('    (text buffer truncated to "$line")');
    }

    //Debugger.debug('>> $line');

    //write the total to the textBuffer (adjust if continuation)
    mem.storeb(textBuffer - 1, line.length + charCount > 0 ? charCount : 0);

    var zChars = ZSCII.toZCharList(line);

    //adjust if continuation
    textBuffer += charCount > 0 ? charCount : 0;

    //store the zscii chars in text buffer
    for (final c in zChars) {
      mem.storeb(textBuffer++, c);
    }

    var tokens = Z.engine.mem.dictionary.tokenize(line);

    //Debugger.verbose('    (tokenized: $tokens)');

    var parsed = Z.engine.mem.dictionary.parse(tokens, line);

    var maxParseBufferBytes = (4 * maxWords) + 2;

    var i = 0;
    for (final p in parsed) {
      i++;
      if (i > maxParseBufferBytes) break;
      mem.storeb(parseBuffer++, p);
    }
  }

  /// Sets the output stream.
  void outputStream() {
    //Debugger.verbose('${pcHex(-1)} [output_stream]');

    var operands = visitOperandsVar(2, true);

    var stream = MathHelper.toSigned(operands[0].value!);

    switch (stream.abs()) {
      case 1:
        outputStream1 = !(stream < 0);
        break;
      case 2:
        outputStream2 = !(stream < 0);
        break;
      case 3:
        if (stream < 0) {
          if (Z.memoryStreams.isEmpty) return;

          //write out to memory
          var addr = Z.memoryStreams.last!;
          Z.memoryStreams.removeLast();

          var data = Z.sbuff.toString();
          Z.sbuff.clear();
          //Debugger.debug('(streams: ${Z._memoryStreams.length}}>>> Writing "$data"');
          mem.storew(addr, data.length);

          addr += 2;

          for (int i = 0; i < data.length; i++) {
            mem.storeb(addr++, ZSCII.charToZChar(data[i]));
          }

          //if the output stream queue is empty then
          if (Z.memoryStreams.isEmpty) {
            outputStream3 = false;
          }
        } else {
          //adding a buffer location to the output stream stack
          outputStream3 = true;
          Z.sbuff.clear();
          Z.memoryStreams.add(operands[1].value);
          // Debugger.debug('>>>> Starting Memory Stream: ${Z.sbuff}');
          if (Z.memoryStreams.length > 16) {
            //(ref 7.1.2.1)
            throw GameException('Maximum memory streams (16) exceeded.');
          }
        }
        break;
      case 4:
        outputStream3 = !(stream < 0);
        break;
    }
  }

  /// Sets the text style.
  void setTextStyle() async {
    //Debugger.verbose('${pcHex(-1)} [set_text_style]');

    var operands = visitOperandsVar(1, false);

    Z.inInterrupt = true;

    await Z.sendIO({"command": IoCommands.setFont, "style": operands[0].value});

    Z.inInterrupt = false;
    Z.callAsync(Z.runIt);
  }

  /// Saves the undo stack.
  void extSaveUndo() {
    //Debugger.verbose('${pcHex(-1)} [ext_save_undo]');

    readb(); //throw away byte

    var resultTo = readb();

    //we don't support this yet.
    writeVariable(resultTo, -1);
  }

  /// Visits an extended instruction.
  void visitExtendedInstruction() {
    // offset the extended instruction by 300 in order to offset it safely from other instructions
    // i.e. extended 1 = 301, extended 2 = 302, etc...
    var i = readb() + 300;

    if (ops.containsKey(i)) {
      if (Debugger.enableDebug) {
        if (Debugger.enableTrace && !Z.inBreak) {
          Debugger.debug('>>> (0x${(programCounter - 1).toRadixString(16)}) ($i)');
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
      ops[i]!();
    } else {
      throw GameException('Unsupported EXT Op Code: $i');
    }
  }

  // read
  // VAR:228 4 1 sread text parse

  // 4 sread text parse time routine

  // 5 aread text parse time routine -> (result)

  // (Note that Inform internally names the read opcode as aread in Versions 5 and later and sread in Versions 3 and 4.)

  // This opcode reads a whole command from the keyboard (no prompt is automatically displayed). It is legal for this to be called with the cursor at any position on any window.

  // In Versions 1 to 3, the status line is automatically redisplayed first.

  // A sequence of characters is read in from the current input stream until a carriage return (or, in Versions 5 and later, any terminating character) is found.

  // In Versions 1 to 4, byte 0 of the text-buffer should initially contain the maximum number of letters which can be typed,
  // minus 1 (the interpreter should not accept more than this). The text typed is reduced to lower case (so that it can tidily
  // be printed back by the program if need be) and stored in bytes 1 onward, with a zero terminator (but without any other terminator,
  // such as a carriage return code). (This means that if byte 0 contains n then the buffer must contain n+1 bytes, which makes it a
  // string array of length n in Inform terminology.)

  // In Versions 5 and later, byte 0 of the text-buffer should initially contain the maximum number of letters which can be typed
  // (the interpreter should not accept more than this). The interpreter stores the number of characters actually typed in byte 1
  // (not counting the terminating character), and the characters themselves (reduced to lower case) in bytes 2 onward (not storing
  // the terminating character). (Some interpreters wrongly add a zero byte after the text anyway, so it is wise for the buffer to contain at least n+3 bytes.)

  // Moreover, if byte 1 contains a positive value at the start of the input, then read assumes that number of characters are left over
  // from an interrupted previous input, and writes the new characters after those already there. Note that the interpreter does not redisplay
  // the characters left over: the game does this, if it wants to. This is unfortunate for any interpreter wanting to give input text a
  // distinctive appearance on-screen, but 'Beyond Zork', 'Zork Zero' and 'Shogun' clearly require it. ("Just a tremendous pain in my butt"
  // -- Andrew Plotkin; "the most unfortunate feature of the Z-machine design" -- Stefan Jokisch.)

  // In Version 4 and later, if the operands time and routine are supplied (and non-zero) then the routine call routine() is made every
  // time/10 seconds during the keyboard-reading process. If this routine returns true, all input is erased (to zero) and the reading
  // process is terminated at once. (The terminating character code is 0.) The routine is permitted to print to the screen even if it returns
  // false to signal "carry on": the interpreter should notice and redraw the input line so far, before input continues. (Frotz notices by looking
  // to see if the cursor position is at the left-hand margin after the interrupt routine has returned.)

  // If input was terminated in the usual way, by the player typing a carriage return, then a carriage return is printed (so the cursor
  // moves to the next line). If it was interrupted, the cursor is left at the rightmost end of the text typed in so far.

  // Next, lexical analysis is performed on the text (except that in Versions 5 and later, if parse-buffer is zero then this is omitted).
  // Initially, byte 0 of the parse-buffer should hold the maximum number of textual words which can be parsed. (If this is n, the buffer
  // must be at least 2 + 4*n bytes long to hold the results of the analysis.)

  // The interpreter divides the text into words and looks them up in the dictionary, as described in S 13. The number of words is written in byte 1
  // and one 4-byte block is written for each word, from byte 2 onwards (except that it should stop before going beyond the maximum number of words
  // specified). Each block consists of the byte address of the word in the dictionary, if it is in the dictionary, or 0 if it isn't; followed by a byte
  // giving the number of letters in the word; and finally a byte giving the position in the text-buffer of the first letter of the word.

  // In Version 5 and later, this is a store instruction: the return value is the terminating character (note that the user pressing his
  // "enter" key may cause either 10 or 13 to be returned; the interpreter must return 13). A timed-out input returns 0.

  // (Versions 1 and 2 and early Version 3 games mistakenly write the parse buffer length 240 into byte 0 of the parse buffer:
  // later games fix this bug and write 59, because 2+4*59 = 238 so that 59 is the maximum number of textual words which can
  // be parsed into a buffer of length 240 bytes. Old versions of the Inform 5 library commit the same error. Neither mistake has very serious consequences.)

  // (Interpreters are asked to halt with a suitable error message if the text or parse buffers have length of less than 3 or 6 bytes,
  // respectively: this sometimes occurs due to a previous array being overrun, causing bugs which are very difficult to find.)

  @override
  void read() async {
    Z.inInterrupt = true;

    Z.printBuffer();

    final operands = visitOperandsVar(4, true);

    final storeTo = readb();

    if (operands.length > 2) {
      //TODO implement aread optional args
      log.warning('implement aread optional args');
      throw GameException("Sorry :( This interpreter doesn't yet support a required feature of this game.");
    }

    int maxBytes = mem.loadb(operands[0].value!);

    int textBuffer = operands[0].value! + 2;

    int? maxWords;
    int parseBuffer;

    // if (operands.length > 2) {
    maxWords = mem.loadb(operands[1].value!);

    parseBuffer = operands[1].value! + 1;
    // }

    void processLine(String line) async {
      line = line.trim().toLowerCase();
      Z.mostRecentInput = line;

      var charCount = mem.loadb(textBuffer - 1);
      if (charCount > 0) {
        //continuation of previous input
        maxBytes -= charCount;
      }

      if (line.length > maxBytes - 1) {
        line = line.substring(0, maxBytes - 2);
        log.warning("Truncated line in v5 read(): $line");
      }

      var tbTotalAddr = textBuffer - 1;

      //write the total to the textBuffer (adjust if continuation)
      mem.storeb(tbTotalAddr, line.length + charCount > 0 ? line.length + charCount : 0);

      var zChars = ZSCII.toZCharList(line);

      //adjust if continuation
      textBuffer += charCount > 0 ? charCount : 0;

      //store the zscii chars in text buffer
      for (final c in zChars) {
        mem.storeb(textBuffer++, c);
      }

      var tokens = Z.engine.mem.dictionary.tokenize(line);

      log.fine("got tokens $tokens in v5 read()");

      if (maxWords == null) {
        log.fine("z5 read() maxWords == null");
        //second parameter was not passed, so
        // we are not going to write to the parse
        // buffer (etude.z5 does .. )
        writeVariable(storeTo, 10);
        return;
      }

      //Debugger.verbose('    (tokenized: $tokens)');

      var parsed = Z.engine.mem.dictionary.parse(tokens, line);
      //Debugger.debug('$parsed');

      var maxParseBufferBytes = (4 * maxWords) + 2;

      var i = 0;
      for (final p in parsed) {
        i++;
        if (i > maxParseBufferBytes) break;
        mem.storeb(parseBuffer++, p);
      }

      // must return 13 v5+
      writeVariable(storeTo, 13);
    }

    final result = await Z.sendIO({"command": IoCommands.read});

    Z.inInterrupt = false;
    if (result == '/!') {
      Z.inBreak = true;
      Debugger.debugStartAddr = programCounter - 1;
      Z.callAsync(Debugger.startBreak);
    } else {
      processLine(result);
      Z.callAsync(Z.runIt);
    }
  }

  /// Checks the argument count.
  void checkArgCount() {
    //Debugger.verbose('${pcHex(-1)} [check_arg_count]');

    var operands = visitOperandsVar(1, false);

    // var locals = callStack[2];
    var argCount = callStack[3 + callStack[2]];

    // Per Z-Machine Standard 1.1 section 15: check_arg_count "branches if the
    // given argument-number (counting from 1) has been provided". This means
    // we check if at least N arguments were provided, not exactly N.
    branch(argCount >= operands[0].value!);
  }

  /// Sets the font.
  void extSetFont() async {
    //Debugger.verbose('${pcHex(-1)} [ext_set_font]');
    Z.inInterrupt = true;

    var operands = visitOperandsVar(1, false);

    final result = await Z.sendIO({"command": IoCommands.setFont, "font_id": operands[0].value});
    Z.inInterrupt = false;

    if (result != null) {
      writeVariable(readb(), int.tryParse(result) ?? 0);
    } else {
      writeVariable(readb(), 0);
    }

    Z.callAsync(Z.runIt);
  }

  /// Sets the cursor.
  void setCursor() async {
    //Debugger.verbose('${pcHex(-1)} [set_cursor]');

    final operands = visitOperandsVar(2, false);

    Z.inInterrupt = true;

    await Z.sendIO({"command": IoCommands.setCursor, "x": operands[0].value, "y": operands[1].value});

    Z.inInterrupt = false;

    Z.callAsync(Z.runIt);
  }

  /// Sets the window.
  void setWindow() {
    //Debugger.verbose('${pcHex(-1)} [set_window]');
    var operands = visitOperandsVar(1, false);

    Z.printBuffer();

    currentWindow = operands[0].value!;
  }

  /// Calls a routine.
  void callVS2() {
    //Debugger.verbose('${pcHex(-1)} [call_vn2]');

    var operands = visitOperandsVar(8, true);

    var resultStore = readb();

    var returnAddr = programCounter;

    assert(operands.isNotEmpty);

    if (operands[0].value == 0) {
      //calling routine at address 0x00 automatically returns FALSE (ref 6.4.3)

      writeVariable(resultStore, Engine.gameFalse);
    } else {
      //unpack function address
      operands[0].rawValue = unpack(operands[0].value!);

      //move to the routine address
      programCounter = operands[0].rawValue!;

      //peel off the first operand
      operands.removeAt(0);

      //setup the routine stack frame and locals
      visitRoutine(operands.map<int?>((o) => o.value).toList());

      //push the result store address onto the call stack
      callStack.push(resultStore);

      //push the return address onto the call stack
      callStack.push(returnAddr);
    }
  }

  /// Calls a routine.
  void callVN2() {
    //Debugger.verbose('${pcHex(-1)} [call_vn2]');

    var operands = visitOperandsVar(8, true);

    // var resultStore = Engine.STACK_MARKER;

    var returnAddr = programCounter;

    assert(operands.isNotEmpty);

    if (operands[0].value == 0) {
      //calling routine at address 0x00 automatically returns FALSE (ref 6.4.3)
      log.fine("call_vn got a zero address but is skipping store");
      //writeVariable(resultStore, Engine.FALSE);
    } else {
      //unpack function address
      operands[0].rawValue = unpack(operands[0].value!);

      //move to the routine address
      programCounter = operands[0].rawValue!;

      // peel off the first operand
      operands.removeAt(0);

      //setup the routine stack frame and locals
      visitRoutine(operands.map<int?>((o) => o.value).toList());

      //push the result store address onto the call stack
      callStack.push(Engine.stackMarker);

      //push the return address onto the call stack
      callStack.push(returnAddr);
    }
  }

  /// Calls a routine.
  void callVN() {
    //Debugger.verbose('${pcHex(-1)} [call_vn]');

    var operands = visitOperandsVar(4, true);

    //
    // var resultStore = Engine.STACK_MARKER;
    var returnAddr = programCounter;

    assert(operands.isNotEmpty);

    if (operands[0].value == 0) {
      log.fine("call_vn got a zero address but is skipping store");

      //writeVariable(resultStore, Engine.FALSE);
    } else {
      //unpack function address
      operands[0].rawValue = unpack(operands[0].value!);

      //move to the routine address
      programCounter = operands[0].rawValue!;

      operands.removeRange(0, 1);

      //setup the routine stack frame and locals
      visitRoutine(operands.map<int?>((o) => o.value).toList());

      // "Lick call but throws away the result"
      callStack.push(Engine.stackMarker);

      //push the return address onto the call stack
      callStack.push(returnAddr);
    }
  }

  /// Calls a routine.
  void call_1s() {
    //Debugger.verbose('${pcHex(-1)} [call_1s]');

    var operand = visitOperandsShortForm();

    var storeTo = readb();

    var returnAddr = programCounter;

    programCounter = unpack(operand.value!);

    visitRoutine([]);

    //push the result store address onto the call stack
    callStack.push(storeTo);

    //push the return address onto the call stack
    callStack.push(returnAddr);
  }

  /// Calls a routine.
  void call_2s() {
    //Debugger.verbose('${pcHex(-1)} [call_2s]');

    var operands = mem.loadb(programCounter - 1) < 193 ? visitOperandsLongForm() : visitOperandsVar(2, false);

    var storeTo = readb();

    var returnAddr = programCounter;

    programCounter = unpack(operands[0].value!);

    visitRoutine([operands[1].value]);

    //push the result store address onto the call stack
    callStack.push(storeTo);

    //push the return address onto the call stack
    callStack.push(returnAddr);
  }

  /// Calls a routine.
  void call_1n() {
    //Debugger.verbose('${pcHex(-1)} [call_1n]');

    var operand = visitOperandsShortForm();

    var returnAddr = programCounter;

    programCounter = unpack(operand.value!);

    visitRoutine([]);

    //push the result store address onto the call stack
    callStack.push(Engine.stackMarker);

    //push the return address onto the call stack
    callStack.push(returnAddr);
  }

  /// Calls a routine.
  void call_2n() {
    //Debugger.verbose('${pcHex(-1)} [call_2n]');

    var operands = mem.loadb(programCounter - 1) < 193 ? visitOperandsLongForm() : visitOperandsVar(2, false);

    var resultStore = Engine.stackMarker;

    var returnAddr = programCounter;

    // var addr = unpack(operands[0].value);

    //move to the routine address
    programCounter = unpack(operands[0].value!);

    //setup the routine stack frame and locals
    visitRoutine([operands[1].value]);

    //push the result store address onto the call stack
    callStack.push(resultStore);

    //push the return address onto the call stack
    callStack.push(returnAddr);
  }

  /// Erases a window.
  void eraseWindow() async {
    //Debugger.verbose('${pcHex(-1)} [erase_window]');

    var operands = visitOperandsVar(1, false);

    Z.inInterrupt = true;
    await Z.sendIO({"command": IoCommands.clearScreen, "window_id": operands[0].value});
    Z.inInterrupt = false;
    Z.callAsync(Z.runIt);
  }

  /// Splits a window.
  void splitWindow() async {
    //Debugger.verbose('${pcHex(-1)} [split_window]');

    var operands = visitOperandsVar(1, false);

    Z.inInterrupt = true;

    await Z.sendIO({"command": IoCommands.splitScreen, "window_id": operands[0].value});
    Z.inInterrupt = false;
    Z.callAsync(Z.runIt);
  }

  /// Reads a character.
  void readChar() async {
    //Debugger.verbose('${pcHex(-1)} [read_char]');
    Z.inInterrupt = true;

    Z.printBuffer();

    var operands = visitOperandsVar(4, true);

    if (operands.length == 3) {
      Debugger.todo('read_char time & routine operands');
    }

    var resultTo = readb();

    final char = await Z.sendIO({"command": IoCommands.readChar});
    writeVariable(resultTo, ZSCII.charToZChar(char));
    Z.inInterrupt = false;
    Z.callAsync(Z.runIt);
  }

  // Version 5+ supports call routines that throw
  // away return results.  Machine.STACK_MARKER is used
  // in the resultTo byte in order to mark this case.
  @override
  void doReturn(var result) {
    // return address
    programCounter = callStack.pop();
    assert(programCounter > 0);

    // result store address byte
    // this may not be a byte if the Machine.STACK_MARKER
    // is being used.
    var resultAddrByte = callStack.pop();

    //unwind locals and params length
    callStack.stack.removeRange(0, callStack.peek() + 2);

    //unwind game stack
    while (stack.pop() != Engine.stackMarker) {}

    //stack marker is used in the result byte to
    //mark call routines that want to throw away the result
    if (resultAddrByte == Engine.stackMarker) return;

    writeVariable(resultAddrByte, result);
  }

  @override
  List<Operand> visitOperandsVar(int howMany, bool isVariable) {
    final operands = <Operand>[];

    //load operand types
    int shiftStart = howMany > 4 ? 14 : 6;
    final os = howMany > 4 ? readw() : readb();

    int to;
    while (shiftStart > -2) {
      to = (os >> shiftStart) & 3; //shift and mask bottom 2 bits

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
      o.rawValue = o.oType == OperandType.large ? readw() : readb();
    }

    //    if (!isVariable && (operands.length != howMany)){
    //      throw Exception('Operand count mismatch.  Expected ${howMany}, found ${operands.length}');
    //    }

    return operands;
  }
}
