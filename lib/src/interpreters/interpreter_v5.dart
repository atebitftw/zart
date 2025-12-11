import 'package:zart/src/interpreters/interpreter_v4.dart';
import 'package:zart/src/interpreters/interpreter_v3.dart';
import 'package:zart/src/logging.dart' show log;
import 'package:zart/src/math_helper.dart';
import 'package:zart/src/operand.dart';
import 'package:zart/src/z_machine.dart';
import 'package:zart/zart.dart';
import 'package:zart/src/zscii.dart';

/// Implementation of Z-Machine v5
class InterpreterV5 extends InterpreterV4 {
  @override
  ZMachineVersions get version => ZMachineVersions.v5;

  /// Creates a new instance of [InterpreterV5].
  InterpreterV5() {
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
    // erase_line (VAR:238)
    ops[238] = eraseLine;
    ops[239] = setCursor;
    // get_cursor (VAR:240)
    ops[240] = getCursor;
    ops[241] = setTextStyle;
    ops[242] = bufferMode;
    ops[243] = outputStream;
    // input_stream (VAR:244)
    ops[244] = inputStream;
    // sound_effect (VAR:245)
    ops[245] = soundEffect;
    ops[246] = readChar;
    // scan_table (VAR:247)
    ops[247] = scanTable;
    ops[249] = callVN;
    ops[250] = callVN2;
    ops[251] = tokenise;
    // encode_text (VAR:252)
    ops[252] = encodeText;
    // set_colour (2OP:27) - all 4 byte forms
    ops[27] = setColour;
    ops[59] = setColour;
    ops[91] = setColour;
    ops[123] = setColour;
    ops[253] = copyTable;
    // print_table (VAR:254)
    ops[254] = printTable;
    ops[255] = checkArgCount;
    // not-VAR (opcode 248) - VAR form of bitwise not
    ops[248] = notVar;
    // catch (0OP:185 in V5+ replaces pop)
    ops[185] = catchOp;
    // throw (2OP:28) - all operand type encodings
    ops[28] = throwOp;
    ops[60] = throwOp;
    ops[92] = throwOp;
    ops[124] = throwOp;
    ops[220] = throwOp;
    // the extended instruction visitExtendedInstruction() adds 300 to the value, so it's offset from the other op codes safely.
    ops[300] = extSave; //ext0: save (V5+)
    ops[301] = extRestore; //ext1: restore (V5+)
    ops[302] = extLogShift; //ext2: log_shift
    ops[303] = extArtShift; //ext3: art_shift
    ops[304] = extSetFont; //ext4
    ops[309] = extSaveUndo; //ext9: save_undo
    ops[310] = extRestoreUndo; //ext10: restore_undo
    ops[311] = extCheckUnicode; //ext11: check_unicode
    ops[312] = extPrintUnicode; //ext12: print_unicode
    ops[313] = extSetTrueColour; //ext13: set_true_colour (Standard 1.1+)
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

    stack.push(InterpreterV3.stackMarker);

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

  // ==================== New V5 Opcodes ====================

  /// Catches the current stack frame (0OP:185 in V5+).
  ///
  /// Returns the current "stack frame" value which can be used with throw
  /// to unwind the call stack to this point.
  ///
  /// ### Z-Machine Spec Reference
  /// 0OP:185 (catch -> result)
  void catchOp() {
    final resultTo = readb();
    // Return the current call stack length as the "stack frame" identifier
    writeVariable(resultTo, callStack.length);
  }

  /// Throws to a previously caught stack frame (2OP:28).
  ///
  /// Resets the routine call state to when catch was called
  /// and returns the given value.
  ///
  /// ### Z-Machine Spec Reference
  /// 2OP:28 (throw value stack-frame)
  void throwOp() {
    final operands = mem.loadb(programCounter - 1) < 193
        ? visitOperandsLongForm()
        : visitOperandsVar(2, false);

    final value = operands[0].value!;
    final targetFrame = operands[1].value!;

    // Unwind call stack to the target frame
    while (callStack.length > targetFrame) {
      // Pop return address
      programCounter = callStack.pop();

      // Pop result store address
      final resultAddrByte = callStack.pop();

      // Unwind locals and params length
      callStack.stack.removeRange(0, callStack.peek() + 2);

      // Unwind game stack
      while (stack.pop() != InterpreterV3.stackMarker) {}

      // If we've reached the target frame, store the result
      if (callStack.length == targetFrame) {
        if (resultAddrByte != InterpreterV3.stackMarker) {
          writeVariable(resultAddrByte, value);
        }
        return;
      }
    }
  }

  /// Erases from cursor to end of line (VAR:238).
  ///
  /// If value is 1, erases from current cursor position to end of line.
  /// Other values do nothing (V4/5 behavior).
  ///
  /// ### Z-Machine Spec Reference
  /// VAR:238 (erase_line value)
  void eraseLine() async {
    final operands = visitOperandsVar(1, false);
    final value = operands[0].value!;

    if (value == 1) {
      await Z.sendIO({"command": IoCommands.eraseLine});
    }
    // Other values: do nothing (per V4/5 spec)
  }

  /// Gets the current cursor position (VAR:240).
  ///
  /// Writes the current cursor row to word 0 of the array,
  /// and the current cursor column to word 1.
  ///
  /// ### Z-Machine Spec Reference
  /// VAR:240 (get_cursor array)
  void getCursor() async {
    final operands = visitOperandsVar(1, false);
    final arrayAddr = operands[0].value!;

    final result = await Z.sendIO({"command": IoCommands.getCursor});

    // Result should be a map with "row" and "column", defaults to (1,1)
    final row = result?["row"] ?? 1;
    final column = result?["column"] ?? 1;

    mem.storew(arrayAddr, row);
    mem.storew(arrayAddr + 2, column);
  }

  /// Selects the current input stream (VAR:244).
  ///
  /// Stream 0 = keyboard (default), Stream 1 = file input.
  /// Most implementations only support keyboard input.
  ///
  /// ### Z-Machine Spec Reference
  /// VAR:244 (input_stream number)
  void inputStream() {
    final operands = visitOperandsVar(1, false);
    final streamNum = operands[0].value!;

    // Currently only keyboard input (stream 0) is supported
    // This is effectively a no-op but we consume the operand
    if (streamNum != 0) {
      log.warning(
        'input_stream $streamNum requested but only stream 0 (keyboard) is supported',
      );
    }
  }

  /// Plays a sound effect (VAR:245).
  ///
  /// Numbers 1 and 2 are bleeps with no other operands required.
  /// Higher numbers reference sound resources with effect, volume, and routine.
  ///
  /// ### Z-Machine Spec Reference
  /// VAR:245 (sound_effect number effect volume routine)
  void soundEffect() async {
    final operands = visitOperandsVar(4, true);

    if (operands.isEmpty) {
      // No operands = beep (per spec, should beep if possible)
      await Z.sendIO({"command": IoCommands.soundEffect, "number": 1});
      return;
    }

    final number = operands[0].value!;

    // Numbers 1 and 2 are bleeps - no other operands needed
    if (number == 1 || number == 2) {
      await Z.sendIO({"command": IoCommands.soundEffect, "number": number});
      return;
    }

    // For other sounds: effect (1=prepare, 2=start, 3=stop, 4=finish)
    final effect = operands.length > 1 ? operands[1].value : 2;
    // Volume: low byte = volume (1-8, 255=loudest), high byte = repeats
    final volume = operands.length > 2 ? operands[2].value : 0x00FF;
    // Routine to call when sound finishes (optional)
    final routine = operands.length > 3 ? operands[3].value : 0;

    await Z.sendIO({
      "command": IoCommands.soundEffect,
      "number": number,
      "effect": effect,
      "volume": volume,
      "routine": routine,
    });
  }

  /// Scans a table for a value (VAR:247).
  ///
  /// Searches table for value x. If found, returns address and branches.
  /// If not found, returns 0 and doesn't branch.
  ///
  /// ### Z-Machine Spec Reference
  /// VAR:247 (scan_table x table len form -> result)
  void scanTable() {
    final operands = visitOperandsVar(4, true);

    final x = operands[0].value!;
    final table = operands[1].value!;
    final len = operands[2].value!;
    // form: bit 7 set = words (default), clear = bytes; bits 0-6 = field length
    // Default form is 0x82 = words, field length 2
    final form = operands.length > 3 ? operands[3].value! : 0x82;

    final isWord = (form & 0x80) != 0;
    final fieldLen = form & 0x7F;

    final resultTo = readb();

    var addr = table;
    for (int i = 0; i < len; i++) {
      final value = isWord ? mem.loadw(addr) : mem.loadb(addr);
      if (value == x) {
        writeVariable(resultTo, addr);
        branch(true);
        return;
      }
      addr += fieldLen;
    }

    writeVariable(resultTo, 0);
    branch(false);
  }

  /// Encodes text to Z-encoded dictionary format (VAR:252).
  ///
  /// Translates a ZSCII word to Z-encoded text format (stored at coded-text),
  /// as if it were an entry in the dictionary.
  ///
  /// ### Z-Machine Spec Reference
  /// VAR:252 (encode_text zscii-text length from coded-text)
  void encodeText() {
    final operands = visitOperandsVar(4, false);

    final zsciiText = operands[0].value!;
    final length = operands[1].value!;
    final from = operands[2].value!;
    final codedText = operands[3].value!;

    // Read the substring from memory
    final chars = <String>[];
    for (int i = 0; i < length; i++) {
      final c = mem.loadb(zsciiText + from + i);
      if (c == 0) break;
      chars.add(ZSCII.zCharToChar(c));
    }

    // Get the dictionary entry byte width (6 bytes for V4+, 4 for older)
    final entryBytes = ZMachine.verToInt(version) >= 4 ? 6 : 4;

    // Encode to Z-string using dictionary encoding
    final encoded = _encodeZString(chars.join(), entryBytes);

    // Store encoded bytes at coded-text
    for (int i = 0; i < entryBytes && i < encoded.length; i++) {
      mem.storeb(codedText + i, encoded[i]);
    }
  }

  /// Encodes a string to Z-encoded dictionary format.
  ///
  /// Returns a list of bytes representing the encoded string.
  /// The output is padded to [byteCount] bytes with shift-5 characters.
  List<int> _encodeZString(String text, int byteCount) {
    // Convert to lowercase for dictionary matching
    text = text.toLowerCase();

    // The alphabet tables for encoding (A0)
    const a0 = 'abcdefghijklmnopqrstuvwxyz';

    final zchars = <int>[];

    for (
      int i = 0;
      i < text.length && zchars.length < (byteCount ~/ 2) * 3;
      i++
    ) {
      final c = text[i];
      final idx = a0.indexOf(c);

      if (idx >= 0) {
        // Character is in A0 alphabet
        zchars.add(idx + 6);
      } else if (c == ' ') {
        zchars.add(0);
      } else {
        // Use A2 escape sequence for other characters
        zchars.add(5); // Shift to A2
        zchars.add(6); // Escape code in A2
        final code = c.codeUnitAt(0);
        zchars.add((code >> 5) & 0x1F); // Top 5 bits
        zchars.add(code & 0x1F); // Bottom 5 bits
      }
    }

    // Pad with shift-5 (A1 shift, commonly used for padding)
    while (zchars.length < (byteCount ~/ 2) * 3) {
      zchars.add(5);
    }

    // Pack into bytes (3 z-chars per word, 2 bytes per word)
    final result = <int>[];
    for (int i = 0; i < zchars.length; i += 3) {
      final z1 = zchars[i];
      final z2 = i + 1 < zchars.length ? zchars[i + 1] : 5;
      final z3 = i + 2 < zchars.length ? zchars[i + 2] : 5;

      // Pack: bit 15 = terminator (set on last word), bits 14-10 = z1, 9-5 = z2, 4-0 = z3
      final isLast = i + 3 >= (byteCount ~/ 2) * 3;
      final word = (isLast ? 0x8000 : 0) | (z1 << 10) | (z2 << 5) | z3;

      result.add((word >> 8) & 0xFF);
      result.add(word & 0xFF);
    }

    return result;
  }

  /// Prints a table of text (VAR:254).
  ///
  /// Prints a rectangle of ZSCII text spreading right and down from
  /// the current cursor position.
  ///
  /// ### Z-Machine Spec Reference
  /// VAR:254 (print_table zscii-text width height skip)
  void printTable() async {
    final operands = visitOperandsVar(4, true);

    final text = operands[0].value!;
    final width = operands[1].value!;
    final height = operands.length > 2 ? operands[2].value! : 1;
    final skip = operands.length > 3 ? operands[3].value! : 0;

    await Z.printBuffer();

    var addr = text;
    for (int row = 0; row < height; row++) {
      for (int col = 0; col < width; col++) {
        final c = mem.loadb(addr++);
        Z.sbuff.write(ZSCII.zCharToChar(c));
      }
      if (row < height - 1) {
        Z.sbuff.write('\n');
        addr += skip;
      }
    }
  }

  /// Restores the undo state (EXT:10).
  ///
  /// Like restore, but restores state saved by save_undo.
  /// Returns 0 on failure, or the value stored when save was made.
  ///
  /// ### Z-Machine Spec Reference
  /// EXT:10 (restore_undo -> result)
  void extRestoreUndo() {
    readb(); // Consume operand types byte (always 0x00 for this instruction)
    final resultTo = readb();

    // Undo is not yet implemented - return 0 (failure)
    // A full implementation would restore from an in-memory undo buffer
    writeVariable(resultTo, 0);
  }

  /// Sets true colour using 15-bit RGB values (EXT:13).
  ///
  /// The foreground and background are 15-bit colour values:
  /// bit 15 = 0, bits 14-10 = blue, bits 9-5 = green, bits 4-0 = red.
  ///
  /// ### Z-Machine Spec Reference
  /// EXT:13 (set_true_colour foreground background)
  void extSetTrueColour() async {
    final operands = visitOperandsVar(2, false);

    final foreground = operands[0].value!;
    final background = operands[1].value!;

    await Z.sendIO({
      "command": IoCommands.setTrueColour,
      "foreground": foreground,
      "background": background,
    });
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
      throw GameException(
        "tokenise dictionary argument is not yet support in v5+",
      );
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
          // Deselecting stream 3
          if (Z.memoryStreams.isEmpty) return;

          // Get the memory address where we'll write
          var addr = Z.memoryStreams.last!;
          Z.memoryStreams.removeLast();

          // The buffer currently contains ONLY stream 3 captured text
          var capturedData = Z.sbuff.toString();

          // DEBUG: Trace output_stream 3 deselect
          // print(
          //   '[output_stream -3] Writing "${capturedData.replaceAll('\n', '\\n')}" to addr=0x${addr.toRadixString(16)}',
          // );

          // Write captured text to memory (per spec 7.1.2.1)
          mem.storew(addr, capturedData.length);
          addr += 2;
          for (int i = 0; i < capturedData.length; i++) {
            mem.storeb(addr++, ZSCII.charToZChar(capturedData[i]));
          }

          // Restore the saved screen buffer
          Z.sbuff.clear();
          if (Z.savedBuffers.isNotEmpty) {
            var restored = Z.savedBuffers.removeLast();
            Z.sbuff.write(restored);
            //print('[output_stream -3] Restored screen buffer: "${restored.replaceAll('\n', '\\n')}"');
          }

          // If the output stream queue is empty then disable stream 3
          if (Z.memoryStreams.isEmpty) {
            outputStream3 = false;
          }
        } else {
          // Selecting stream 3 (per spec 7.1.2.2: exclusive - no text to other streams)

          // Save current screen buffer content so we can restore it later
          var savedContent = Z.sbuff.toString();
          Z.savedBuffers.add(savedContent);

          // DEBUG: Trace output_stream 3 select
          //print('[output_stream 3] Saving screen buffer: "${savedContent.replaceAll('\n', '\\n')}"');

          outputStream3 = true;
          Z.sbuff.clear(); // Start fresh for memory capture
          Z.memoryStreams.add(operands[1].value);

          if (Z.memoryStreams.length > 16) {
            // (ref 7.1.2.1)
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

    await Z.sendIO({
      "command": IoCommands.setTextStyle,
      "style": operands[0].value,
    });
  }

  /// Sets the foreground and background colors.
  /// Opcode 2OP:27 (set_colour).
  void setColour() async {
    //Debugger.verbose('${pcHex(-1)} [set_colour]');

    // Read operands based on opcode byte form (consumes bytes from program stream)
    final operands = mem.loadb(programCounter - 1) < 193
        ? visitOperandsLongForm()
        : visitOperandsVar(2, false);

    // Color values: 0=current, 1=default, 2-9=colors, 10+=custom (v6)
    await Z.sendIO({
      "command": IoCommands.setColour,
      "foreground": operands[0].value,
      "background": operands[1].value,
    });
  }

  /// Performs a bitwise NOT operation (VAR form - opcode 248).
  /// This is the v5+ VAR version of the 1OP not instruction.
  void notVar() {
    //Debugger.verbose('${pcHex(-1)} [not-VAR]');

    final operands = visitOperandsVar(1, false);

    final resultTo = readb();

    writeVariable(resultTo, ~operands[0].value! & 0xFFFF);
  }

  /// V5+ extended save opcode (EXT:0).
  /// In V5+, save/restore are store instructions, not branch instructions.
  /// Returns: 0 = failure, 1 = success, 2 = game restored
  void extSave() {
    //Debugger.verbose('${pcHex(-1)} [ext_save]');

    // EXT save is VAR form with optional operands
    visitOperandsVar(4, true);
    final resultTo = readb();

    // For now, just return 0 (failure) - full implementation requires IO provider
    // TODO: Implement full save with optional memory region parameters
    writeVariable(resultTo, 0);
  }

  /// V5+ extended restore opcode (EXT:1).
  /// In V5+, save/restore are store instructions, not branch instructions.
  /// Returns: 0 = failure, or value stored when save was made
  void extRestore() {
    //Debugger.verbose('${pcHex(-1)} [ext_restore]');

    // EXT restore is VAR form with optional operands
    visitOperandsVar(4, true);
    final resultTo = readb();

    // For now, just return 0 (failure) - full implementation requires IO provider
    // TODO: Implement full restore with optional memory region parameters
    writeVariable(resultTo, 0);
  }

  /// Saves the undo stack.
  void extSaveUndo() {
    //Debugger.verbose('${pcHex(-1)} [ext_save_undo]');

    readb(); //throw away byte

    final resultTo = readb();

    //we don't support this yet.
    writeVariable(resultTo, -1);
  }

  /// Performs a logical shift operation (EXT:2).
  ///
  /// If `places` is positive, shifts left. If negative, shifts right.
  /// Logical shift treats the number as unsigned - zeros are shifted in.
  ///
  /// ### Z-Machine Spec Reference
  /// EXT:2
  void extLogShift() {
    final operands = visitOperandsVar(2, false);

    final number = operands[0].value!;
    final places = MathHelper.toSigned(operands[1].value!);

    final resultTo = readb();

    int result;
    if (places >= 0) {
      // Left shift
      result = (number << places) & 0xFFFF;
    } else {
      // Logical right shift (unsigned) - zeros shifted in
      result = (number >> (-places)) & 0xFFFF;
    }

    writeVariable(resultTo, result);
  }

  /// Performs an arithmetic shift operation (EXT:3).
  ///
  /// If `places` is positive, shifts left. If negative, shifts right.
  /// Arithmetic shift preserves the sign bit when shifting right.
  ///
  /// ### Z-Machine Spec Reference
  /// EXT:3
  void extArtShift() {
    final operands = visitOperandsVar(2, false);

    final number = MathHelper.toSigned(operands[0].value!);
    final places = MathHelper.toSigned(operands[1].value!);

    final resultTo = readb();

    int result;
    if (places >= 0) {
      // Arithmetic left shift (same as logical)
      result = (number << places) & 0xFFFF;
    } else {
      // Arithmetic right shift - sign bit is preserved
      // Dart's >> on signed integers preserves sign
      result = (number >> (-places)) & 0xFFFF;
    }

    writeVariable(resultTo, result);
  }

  /// Prints a unicode character (EXT:12).
  ///
  /// ### Z-Machine Spec Reference
  /// EXT:12 (print_unicode char-code)
  void extPrintUnicode() {
    final operands = visitOperandsVar(1, false);
    final charCode = operands[0].value!;

    // Convert unicode code point to string and output
    Z.sbuff.write(String.fromCharCode(charCode));
  }

  /// Checks unicode character support (EXT:11).
  ///
  /// Returns a bitmap:
  /// - Bit 0: Character can be printed
  /// - Bit 1: Character can be input
  ///
  /// ### Z-Machine Spec Reference
  /// EXT:11 (check_unicode char-code -> result)
  void extCheckUnicode() {
    visitOperandsVar(1, false); // Read and discard the char-code operand

    final resultTo = readb();

    // Return 3 (bits 0 and 1 set) - we support both printing and input of all characters
    writeVariable(resultTo, 3);
  }

  /// Visits an extended instruction.
  void visitExtendedInstruction() {
    // offset the extended instruction by 300 in order to offset it safely from other instructions
    // i.e. extended 1 = 301, extended 2 = 302, etc...
    var i = readb() + 300;

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
      ops[i]!();
    } else {
      throw GameException('Unsupported EXT Op Code: $i');
    }
  }

  @override
  void read() async {
    await Z.printBuffer();

    final operands = visitOperandsVar(4, true);

    final storeTo = readb();

    if (operands.length > 2) {
      //TODO implement aread optional args
      log.warning('implement aread optional args');
      throw GameException(
        "Sorry :( This interpreter doesn't yet support a required feature of this game.",
      );
    }

    int maxBytes = mem.loadb(operands[0].value!);

    int textBuffer = operands[0].value! + 2;

    int? maxWords;
    int? parseBuffer;

    // V5 read can have 1-4 operands:
    // 1: text-buffer only (no parsing)
    // 2: text-buffer + parse-buffer
    // 3+: additional time/routine args (not yet supported)
    if (operands.length >= 2) {
      maxWords = mem.loadb(operands[1].value!);
      parseBuffer = operands[1].value! + 1;
    } else {
      // Only text buffer provided - no parsing will occur
      maxWords = null;
      parseBuffer = null;
    }

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
      mem.storeb(
        tbTotalAddr,
        line.length + charCount > 0 ? line.length + charCount : 0,
      );

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

      // parseBuffer is guaranteed non-null here since we checked maxWords above
      var pbAddr = parseBuffer!;
      var i = 0;
      for (final p in parsed) {
        i++;
        if (i > maxParseBufferBytes) break;
        mem.storeb(pbAddr++, p);
      }

      // must return 13 v5+
      writeVariable(storeTo, 13);
    }

    // In pump mode, store callback and return (execution pauses)
    // In traditional mode, send to IoProvider and wait
    if (Z.isPumpMode) {
      Z.requestLineInput((String result) {
        if (result == '/!') {
          Z.inBreak = true;
          Debugger.debugStartAddr = programCounter - 1;
        } else {
          processLine(result);
        }
      });
      return; // Exit - execution will resume when submitLineInput is called
    }

    // Traditional mode
    final result = await Z.sendIO({"command": IoCommands.read});
    if (result == '/!') {
      Z.inBreak = true;
      Debugger.debugStartAddr = programCounter - 1;
      Z.callAsync(Debugger.startBreak);
    } else {
      processLine(result);
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

    var operands = visitOperandsVar(1, false);

    final result = await Z.sendIO({
      "command": IoCommands.setFont,
      "font_id": operands[0].value,
    });

    if (result != null) {
      writeVariable(readb(), int.tryParse(result) ?? 0);
    } else {
      writeVariable(readb(), 0);
    }
  }

  /// Sets the cursor.
  void setCursor() async {
    //Debugger.verbose('${pcHex(-1)} [set_cursor]');

    final operands = visitOperandsVar(2, false);

    // Flush any pending text before repositioning cursor
    await Z.printBuffer();

    // Z-Machine spec: set_cursor line column (operands[0]=line, operands[1]=column)
    await Z.sendIO({
      "command": IoCommands.setCursor,
      "line": operands[0].value,
      "column": operands[1].value,
    });
  }

  /// Sets the window.
  void setWindow() async {
    //Debugger.verbose('${pcHex(-1)} [set_window]');
    var operands = visitOperandsVar(1, false);

    await Z.printBuffer();

    currentWindow = operands[0].value!;
    //print('[DEBUG set_window] window=$currentWindow');

    await Z.sendIO({"command": IoCommands.setWindow, "window": currentWindow});
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

      writeVariable(resultStore, InterpreterV3.gameFalse);
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
      callStack.push(InterpreterV3.stackMarker);

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
      callStack.push(InterpreterV3.stackMarker);

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

    var operands = mem.loadb(programCounter - 1) < 193
        ? visitOperandsLongForm()
        : visitOperandsVar(2, false);

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
    callStack.push(InterpreterV3.stackMarker);

    //push the return address onto the call stack
    callStack.push(returnAddr);
  }

  /// Calls a routine.
  void call_2n() {
    //Debugger.verbose('${pcHex(-1)} [call_2n]');

    var operands = mem.loadb(programCounter - 1) < 193
        ? visitOperandsLongForm()
        : visitOperandsVar(2, false);

    var resultStore = InterpreterV3.stackMarker;

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

    await Z.sendIO({
      "command": IoCommands.clearScreen,
      "window_id": operands[0].value,
    });
  }

  /// Splits a window.
  void splitWindow() async {
    //Debugger.verbose('${pcHex(-1)} [split_window]');

    var operands = visitOperandsVar(1, false);
    //print('[DEBUG split_window] lines=${operands[0].value}');

    await Z.sendIO({
      "command": IoCommands.splitWindow,
      "lines": operands[0].value,
    });
  }

  /// Reads a character.
  void readChar() async {
    //Debugger.verbose('${pcHex(-1)} [read_char]');

    await Z.printBuffer();

    var operands = visitOperandsVar(4, true);

    if (operands.length == 3) {
      Debugger.todo('read_char time & routine operands');
    }

    var resultTo = readb();

    // In pump mode, store callback and return (execution pauses)
    // In traditional mode, send to IoProvider and wait
    if (Z.isPumpMode) {
      Z.requestCharInput((String char) {
        writeVariable(resultTo, ZSCII.charToZChar(char));
      });
      return; // Exit - execution will resume when submitCharInput is called
    }

    // Traditional mode
    final char = await Z.sendIO({"command": IoCommands.readChar});
    writeVariable(resultTo, ZSCII.charToZChar(char));
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
    while (stack.pop() != InterpreterV3.stackMarker) {}

    //stack marker is used in the result byte to
    //mark call routines that want to throw away the result
    if (resultAddrByte == InterpreterV3.stackMarker) return;

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
