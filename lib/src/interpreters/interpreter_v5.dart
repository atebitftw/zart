import 'package:zart/src/interpreters/interpreter_v4.dart';
import 'package:zart/src/interpreters/interpreter_v3.dart';
import 'package:zart/src/logging.dart' show log;
import 'package:zart/src/math_helper.dart';
import 'package:zart/src/operand.dart';
import 'package:zart/src/z_machine.dart';
import 'package:zart/src/io/quetzal.dart';
import 'package:zart/zart.dart';
import 'package:zart/src/zscii.dart';
import 'package:zart/src/dictionary.dart';

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
    ops[314] = extSoundData; //ext14: sound_data (brancher, for sound queries)
    ops[330] = extGestalt; //ext30: gestalt (Z-Machine 1.2 spec)
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
    final operands = mem.loadb(programCounter - 1) < 193 ? visitOperandsLongForm() : visitOperandsVar(2, false);

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
    await Z.printBuffer();
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
    await Z.printBuffer();
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
      log.warning('input_stream $streamNum requested but only stream 0 (keyboard) is supported');
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

    for (int i = 0; i < text.length && zchars.length < (byteCount ~/ 2) * 3; i++) {
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

    // Get start position
    final cursor = await Z.sendIO({"command": IoCommands.getCursor});
    final startRow = cursor?['row'] ?? 1;
    final startCol = cursor?['column'] ?? 1;

    var addr = text;
    for (int row = 0; row < height; row++) {
      final sb = StringBuffer();
      for (int col = 0; col < width; col++) {
        final c = mem.loadb(addr++);
        sb.write(ZSCII.zCharToChar(c));
      }

      // Explicitly set cursor for this row
      await Z.sendIO({"command": IoCommands.setCursor, "line": startRow + row, "column": startCol});

      // Print the row
      await Z.sendIO({"command": IoCommands.print, "window": currentWindow, "buffer": sb.toString()});

      if (row < height - 1) {
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
    await Z.printBuffer();
    final operands = visitOperandsVar(2, false);

    final foreground = operands[0].value!;
    final background = operands[1].value!;

    await Z.sendIO({"command": IoCommands.setTrueColour, "foreground": foreground, "background": background});
  }

  /// Copies a table (VAR:253).
  ///
  /// Per Z-Machine spec:
  /// - If t2Addr is 0, zeros `size` bytes starting at t1Addr
  /// - If size is negative, copies abs(size) bytes forward (allowing overlap corruption)
  /// - If size is positive and tables overlap, copies backward to prevent corruption
  /// - Beyond Zork uses negative size to fill arrays with spaces
  void copyTable() {
    //Debugger.verbose('${pcHex(-1)} [copy_table]');

    var operands = visitOperandsVar(3, false);

    int t1Addr = operands[0].value!;
    var t2Addr = operands[1].value;
    var size = MathHelper.toSigned(operands[2].value!);

    if (t2Addr == 0) {
      // Zero out abs(size) bytes at t1Addr
      var absSize = size.abs();
      Debugger.debug('>>> Zeroing $absSize bytes at 0x${t1Addr.toRadixString(16)}');
      for (int i = 0; i < absSize; i++) {
        mem.storeb(t1Addr + i, 0);
      }
    } else {
      var absSize = size.abs();
      final dest = t2Addr!; // Non-null destination address

      // Negative size means copy forward (intentionally allowing overlap corruption)
      // Positive size means copy safely (backward if destination overlaps source)
      if (size < 0) {
        // Forward copy (negative size)
        Debugger.debug('>>> Copying $absSize bytes forward (size negative)');
        for (int i = 0; i < absSize; i++) {
          mem.storeb(dest + i, mem.loadb(t1Addr + i));
        }
      } else {
        // Check for overlap: if destination is within source range, copy backward
        var t1End = t1Addr + absSize;
        if (dest > t1Addr && dest < t1End) {
          // Overlap detected - copy backward to prevent corruption
          Debugger.debug('>>> Overlap copy: $absSize bytes (reverse order)');
          for (int i = absSize - 1; i >= 0; i--) {
            mem.storeb(dest + i, mem.loadb(t1Addr + i));
          }
        } else {
          // No overlap or destination before source - copy forward
          Debugger.debug('>>> Copying $absSize bytes.');
          for (int i = 0; i < absSize; i++) {
            mem.storeb(dest + i, mem.loadb(t1Addr + i));
          }
        }
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

    // Check for optional dictionary argument (operand 2, 0-indexed)
    // If provided and non-zero, use it. Otherwise use default game dictionary.
    Dictionary dict = Z.engine.mem.dictionary;
    if (operands.length > 2 && operands[2].value! != 0) {
      int addr = operands[2].value!;

      try {
        dict = Dictionary(address: addr);

        if (dict.totalEntries == 0) {
          dict = Dictionary.unsorted(address: addr);
        }
      } catch (e) {
        log.warning("Failed to initialize custom dictionary at $addr: $e");
        try {
          dict = Dictionary.unsorted(address: addr);
        } catch (e2) {
          log.warning("Failed to initialize unsorted dictionary fallback: $e2");
        }
      }
    } else {
      // Use default dictionary
    }
    log.info("tokenise: using default dictionary.");

    var maxWords = mem.loadb(operands[1].value!);

    var parseBuffer = operands[1].value! + 1;

    // Read the text from the buffer as per Standard (and reference parity)
    // instead of relying on Z.mostRecentInput.
    // Text buffer V5: Byte 0=Max, Byte 1=Length, Bytes 2...=Chars
    var textBuffer = operands[0].value! + 2;
    var charCount = mem.loadb(textBuffer - 1);

    // Construct line from ZSCII bytes in buffer
    StringBuffer sb = StringBuffer();
    for (int i = 0; i < charCount; i++) {
      int zc = mem.loadb(textBuffer + i);
      sb.write(ZSCII.zCharToChar(zc));
    }
    var line = sb.toString().toLowerCase();

    // Note: tokenise does NOT modify the text buffer - it only reads from it.
    // The text buffer was already filled by the read() opcode or game code.

    // Check for flag operand (operand 3)
    bool flag = false;
    if (operands.length > 3 && operands[3].value != 0) {
      flag = true;
      log.info("tokenise: flag is set (do not overwrite unknown words)");
    }

    var tokens = dict.tokenize(line);

    //Debugger.verbose('    (tokenized: $tokens)');

    var parsed = dict.parse(tokens, line);

    // Parse buffer format:
    // Byte 0: Number of words
    // Then 4-byte blocks for each word:
    //   Byte 0-1: Address in dictionary (0 if not found)
    //   Byte 2: Length of word
    //   Byte 3: Offset in text buffer

    // Always update word count
    if (parsed.isNotEmpty) {
      mem.storeb(parseBuffer, parsed[0]);
    }

    int currentByte = 1; // Start after count byte
    int wordIndex = 0;

    // parsed[0] is count. Words start at parsed[1].
    // Each word uses 4 bytes in 'parsed'.
    while (currentByte < parsed.length && wordIndex < maxWords) {
      int addrHigh = parsed[currentByte];
      int addrLow = parsed[currentByte + 1];
      int len = parsed[currentByte + 2];
      int offset = parsed[currentByte + 3];

      int wordAddr = (addrHigh << 8) | addrLow;

      int parseBufSlot = parseBuffer + 1 + (wordIndex * 4);

      // If flag is set AND word was not found (addr == 0), skip writing
      if (flag && wordAddr == 0) {
        // Do not overwrite
        // We might still want to ensure length/offset are correct?
        // The standard says "slots are left unchanged".
        // This implies rely on previous tokenise.
      } else {
        mem.storeb(parseBufSlot, addrHigh);
        mem.storeb(parseBufSlot + 1, addrLow);
        mem.storeb(parseBufSlot + 2, len);
        mem.storeb(parseBufSlot + 3, offset);
      }

      currentByte += 4;
      wordIndex++;
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
    await Z.printBuffer();
    //Debugger.verbose('${pcHex(-1)} [set_text_style]');

    var operands = visitOperandsVar(1, false);

    await Z.sendIO({"command": IoCommands.setTextStyle, "style": operands[0].value});
  }

  /// Sets the foreground and background colors.
  /// Opcode 2OP:27 (set_colour).
  void setColour() async {
    await Z.printBuffer();
    //Debugger.verbose('${pcHex(-1)} [set_colour]');

    // Read operands based on opcode byte form (consumes bytes from program stream)
    final operands = mem.loadb(programCounter - 1) < 193 ? visitOperandsLongForm() : visitOperandsVar(2, false);

    // Color values: 0=current, 1=default, 2-9=colors, 10+=custom (v6)
    await Z.sendIO({"command": IoCommands.setColour, "foreground": operands[0].value, "background": operands[1].value});
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
  /// ### IO Command
  /// ```json
  /// {
  ///   "command": "save",
  ///   "file_data": "<save_data>"
  /// }
  /// ```
  void extSave() async {
    //Debugger.verbose('${pcHex(-1)} [ext_save]');

    if (Z.inInterrupt) {
      return;
    }

    Z.inInterrupt = true;

    // EXT save is VAR form with optional operands (table, bytes, name - for partial saves)
    final operands = visitOperandsVar(4, true);

    // Save PC BEFORE reading resultTo, so restore can re-read it to know where to store result 2
    final savePC = programCounter;
    final resultTo = readb();

    if (operands.isNotEmpty && operands[0].value != 0) {
      log.warning('extSave: partial memory save not yet implemented');
      Z.inInterrupt = false;
      writeVariable(resultTo, 0); // Failure
      return;
    }

    // Save with PC pointing BEFORE resultTo byte so restore can read it
    final saveData = Quetzal.save(savePC);

    final result = await Z.sendIO({"command": IoCommands.save, "file_data": saveData});

    Z.inInterrupt = false;

    // V5+ uses store semantics: 0 = failure, 1 = success
    writeVariable(resultTo, result == true ? 1 : 0);

    // Only call runIt in traditional mode - in pump mode, the caller's loop resumes execution
    if (!Z.isPumpMode) {
      Z.callAsync(Z.runIt);
    }
  }

  /// V5+ extended restore opcode (EXT:1).
  /// In V5+, save/restore are store instructions, not branch instructions.
  /// Returns: 0 = failure, 2 = success (per spec, restore returns 2 to indicate it was restored)
  /// ### IO Command
  /// ```json
  /// {
  ///   "command": "restore"
  /// }
  /// ```
  void extRestore() async {
    //Debugger.verbose('${pcHex(-1)} [ext_restore]');

    if (Z.inInterrupt) {
      return;
    }

    Z.inInterrupt = true;

    // EXT restore is VAR form with optional operands (table, bytes, name - for partial restores)
    final operands = visitOperandsVar(4, true);
    final resultTo = readb();

    if (operands.isNotEmpty && operands[0].value != 0) {
      log.warning('extRestore: partial memory restore not yet implemented');
      Z.inInterrupt = false;
      writeVariable(resultTo, 0); // Failure
      return;
    }

    final result = await Z.sendIO({"command": IoCommands.restore});

    Z.inInterrupt = false;

    if (result == null) {
      writeVariable(resultTo, 0); // Failure
    } else {
      final restoreResult = Quetzal.restore(result);
      if (!restoreResult) {
        writeVariable(resultTo, 0); // Failure
      } else {
        // Per Z-Machine spec, after successful restore, store 2 at the resultTo
        // that was saved in the Quetzal file (PC points after the save instruction)
        // The Quetzal.restore already set PC appropriately
        // We need to read the result store byte from where PC now points
        final restoredResultTo = readb();
        writeVariable(restoredResultTo, 2); // 2 = restored successfully
      }
    }

    // Only call runIt in traditional mode - in pump mode, the caller's loop resumes execution
    if (!Z.isPumpMode) {
      Z.callAsync(Z.runIt);
    }
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

  /// Queries about sound resource data (EXT:14).
  ///
  /// This is a brancher opcode that queries whether a sound resource exists
  /// or has finished loading. Since we don't support sound resources, we
  /// always branch false (sound not available).
  ///
  /// ### Z-Machine Spec Reference
  /// EXT:14 (sound_data number ?(label))
  void extSoundData() {
    // Read the operand types byte and the operand
    visitOperandsVar(1, false);

    // We don't support sound resources, so always branch false
    branch(false);
  }

  /// Queries interpreter capabilities (EXT:30).
  ///
  /// Returns information about the interpreter and Z-Machine implementation.
  /// This is part of the Z-Machine 1.2 specification.
  ///
  /// ### Z-Machine Spec Reference
  /// EXT:30 (gestalt id arg -> result)
  ///
  /// Known gestalt selectors:
  /// - 1: Return version number (0x0102 = version 1.2)
  void extGestalt() {
    final operands = visitOperandsVar(2, true);

    final id = operands.isNotEmpty ? operands[0].value! : 0;
    // arg is operands[1] if present, currently unused

    final resultTo = readb();

    int result;
    switch (id) {
      case 1:
        // Return interpreter version: 1.1 as per Z-Machine Standard 1.1
        result = 0x0101;
        break;
      default:
        // Unknown gestalt selector - return 0
        result = 0;
    }

    writeVariable(resultTo, result);
  }

  /// Visits an extended instruction.
  void visitExtendedInstruction() async {
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
      await ops[i]!();
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
      throw GameException("Sorry :( This interpreter doesn't yet support a required feature of this game.");
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

      if (maxWords == 0) {
        // Check if there's actually a parse buffer address (non-zero)
        if (operands[1].value! != 0) {
          maxWords = 8; // Reasonable default for most games
        }
      }
    } else {
      // Only text buffer provided - no parsing will occur
      maxWords = null;
      parseBuffer = null;
    }

    // V5 read (aread) operands: text, parse, time, routine.
    // There is NO dictionary argument in V5 read.
    // The Standard Dictionary is always used.
    Dictionary dict = Z.engine.mem.dictionary;

    void processLine(String line) {
      line = line.trim().toLowerCase();
      Z.mostRecentInput = line;

      var charCount = mem.loadb(textBuffer - 1);

      // Validate charCount - several conditions can indicate garbage data:
      // 1. charCount >= maxBytes (obviously invalid)
      // 2. charCount > 0 but first continuation byte isn't a valid printable ZSCII char
      //    (valid printable chars are roughly 0x20-0x7E)
      // This handles uninitialized text buffers that contain random data
      if (charCount > 0 && charCount < maxBytes) {
        // Check if first "continuation" character is actually printable
        final firstContChar = mem.loadb(textBuffer);
        if (firstContChar < 0x20 || firstContChar > 0x7E) {
          // First char isn't printable ASCII - this is garbage, not real continuation
          charCount = 0;
          mem.storeb(textBuffer - 1, 0); // Clear the garbage value
        }
      } else if (charCount >= maxBytes) {
        charCount = 0;
        mem.storeb(textBuffer - 1, 0); // Clear the garbage value
      }

      if (charCount > 0) {
        //continuation of previous input - reduce available space
        maxBytes -= charCount;
      }

      // Check if input is too long (should fit in maxBytes chars)
      if (line.length > maxBytes) {
        line = line.substring(0, maxBytes);
        log.warning("Truncated line in v5 read(): $line");
      }

      var tbTotalAddr = textBuffer - 1;

      //write the total to the textBuffer (adjust if continuation)
      // Write the character count to the text buffer header (V5+ format)
      final totalChars = line.length + (charCount > 0 ? charCount : 0);
      mem.storeb(tbTotalAddr, totalChars);

      var zChars = ZSCII.toZCharList(line);

      //adjust if continuation
      textBuffer += charCount > 0 ? charCount : 0;

      //store the zscii chars in text buffer
      for (final c in zChars) {
        mem.storeb(textBuffer++, c);
      }

      // Use the selected dictionary for tokenization
      var tokens = dict.tokenize(line);

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

      // Use the selected dictionary for parsing
      var parsed = dict.parse(tokens, line);

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

  /// Sets the font (EXT:4).
  ///
  /// Changes the current font and returns the previous font number.
  ///
  /// ### Font Numbers
  /// - 0: Query current font (no change)
  /// - 1: Normal (proportional) font
  /// - 3: Character graphics font (unsupported)
  /// - 4: Fixed-pitch (monospace) font
  ///
  /// ### Z-Machine Spec Reference
  /// EXT:4 (set_font font -> result)
  /// Returns previous font, or 0 if requested font unavailable.
  void extSetFont() async {
    await Z.printBuffer();
    //Debugger.verbose('${pcHex(-1)} [ext_set_font]');

    var operands = visitOperandsVar(1, false);
    final resultTo = readb();

    final result = await Z.sendIO({"command": IoCommands.setFont, "font_id": operands[0].value});

    // Result should be an int (previous font number, or 0 if not available)
    if (result is int) {
      writeVariable(resultTo, result);
    } else if (result is String) {
      // Fallback for legacy providers that may return strings
      writeVariable(resultTo, int.tryParse(result) ?? 0);
    } else {
      writeVariable(resultTo, 0);
    }
  }

  /// Sets the cursor position (VAR:239).
  ///
  /// Moves the cursor to the given line and column.
  /// Per Z-Machine spec 8.7.2.3: This opcode does nothing when the lower
  /// window (window 0) is selected.
  ///
  /// ### Z-Machine Spec Reference
  /// VAR:239 (set_cursor line column)
  /// Line and column are 1-indexed.
  void setCursor() async {
    //Debugger.verbose('${pcHex(-1)} [set_cursor]');

    final operands = visitOperandsVar(2, false);

    // Per Z-Machine spec 8.7.2.3: do nothing if the lower window is selected
    if (currentWindow == 0) {
      return;
    }

    // Flush any pending text before repositioning cursor
    await Z.printBuffer();

    // Z-Machine spec: set_cursor line column (1-indexed)
    await Z.sendIO({"command": IoCommands.setCursor, "line": operands[0].value, "column": operands[1].value});
  }

  /// Sets the current window (VAR:235).
  ///
  /// Switches output to the specified window.
  /// - Window 0: Lower (main) window - scrolling text window
  /// - Window 1: Upper (status) window - fixed position, non-scrolling
  ///
  /// When switching to the upper window (1), the cursor is automatically
  /// reset to position (1, 1) - the top-left corner.
  ///
  /// ### Z-Machine Spec Reference
  /// VAR:235 (set_window window)
  void setWindow() async {
    //Debugger.verbose('${pcHex(-1)} [set_window]');
    var operands = visitOperandsVar(1, false);

    await Z.printBuffer();

    final previousWindow = currentWindow;
    currentWindow = operands[0].value!;

    await Z.sendIO({"command": IoCommands.setWindow, "window": currentWindow});

    // Per Z-Machine spec: Switching to the upper window resets cursor to (1, 1)
    if (currentWindow != 0 && previousWindow == 0) {
      await Z.sendIO({"command": IoCommands.setCursor, "line": 1, "column": 1});
    }
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

  /// Calls a routine with 1 argument, storing result (1OP:8).
  ///
  /// ### Z-Machine Spec Reference
  /// Section 6.4.3: Calling address 0 is legal and returns false.
  void call_1s() {
    //Debugger.verbose('${pcHex(-1)} [call_1s]');

    var operand = visitOperandsShortForm();

    var storeTo = readb();

    // Per Z-Machine spec 6.4.3: calling routine at address 0 returns false
    if (operand.value == 0) {
      writeVariable(storeTo, InterpreterV3.gameFalse);
      return;
    }

    var returnAddr = programCounter;

    programCounter = unpack(operand.value!);

    visitRoutine([]);

    //push the result store address onto the call stack
    callStack.push(storeTo);

    //push the return address onto the call stack
    callStack.push(returnAddr);
  }

  /// Calls a routine with 2 arguments, storing result (2OP:25).
  ///
  /// ### Z-Machine Spec Reference
  /// Section 6.4.3: Calling address 0 is legal and returns false.
  void call_2s() {
    //Debugger.verbose('${pcHex(-1)} [call_2s]');

    var operands = mem.loadb(programCounter - 1) < 193 ? visitOperandsLongForm() : visitOperandsVar(2, false);

    var storeTo = readb();

    // Per Z-Machine spec 6.4.3: calling routine at address 0 returns false
    if (operands[0].value == 0) {
      writeVariable(storeTo, InterpreterV3.gameFalse);
      return;
    }

    var returnAddr = programCounter;

    programCounter = unpack(operands[0].value!);

    visitRoutine([operands[1].value]);

    //push the result store address onto the call stack
    callStack.push(storeTo);

    //push the return address onto the call stack
    callStack.push(returnAddr);
  }

  /// Calls a routine with 1 argument, discarding result (1OP:15).
  ///
  /// ### Z-Machine Spec Reference
  /// Section 6.4.3: Calling address 0 is legal and does nothing.
  void call_1n() {
    //Debugger.verbose('${pcHex(-1)} [call_1n]');

    var operand = visitOperandsShortForm();

    // Per Z-Machine spec 6.4.3: calling routine at address 0 does nothing
    if (operand.value == 0) {
      return;
    }

    var returnAddr = programCounter;

    programCounter = unpack(operand.value!);

    visitRoutine([]);

    //push the result store address onto the call stack
    callStack.push(InterpreterV3.stackMarker);

    //push the return address onto the call stack
    callStack.push(returnAddr);
  }

  /// Calls a routine with 2 arguments, discarding result (2OP:26).
  ///
  /// ### Z-Machine Spec Reference
  /// Section 6.4.3: Calling address 0 is legal and does nothing.
  void call_2n() {
    //Debugger.verbose('${pcHex(-1)} [call_2n]');

    var operands = mem.loadb(programCounter - 1) < 193 ? visitOperandsLongForm() : visitOperandsVar(2, false);

    // Per Z-Machine spec 6.4.3: calling routine at address 0 does nothing
    if (operands[0].value == 0) {
      return;
    }

    var resultStore = InterpreterV3.stackMarker;

    var returnAddr = programCounter;

    //move to the routine address
    programCounter = unpack(operands[0].value!);

    //setup the routine stack frame and locals
    visitRoutine([operands[1].value]);

    //push the result store address onto the call stack
    callStack.push(resultStore);

    //push the return address onto the call stack
    callStack.push(returnAddr);
  }

  /// Erases a window (VAR:237).
  ///
  /// Clears the specified window and resets its cursor.
  ///
  /// ### Window ID Values
  /// - **-2**: Unsplit the screen (closes upper window) and clear all windows
  /// - **-1**: Clear all windows without changing the split
  /// - **0**: Clear lower (main) window only
  /// - **1**: Clear upper (status) window only
  ///
  /// ### Z-Machine Spec Reference
  /// VAR:237 (erase_window window)
  /// Note: The window ID is treated as a signed value.
  void eraseWindow() async {
    await Z.printBuffer();
    //Debugger.verbose('${pcHex(-1)} [erase_window]');

    var operands = visitOperandsVar(1, false);

    // Convert to signed to handle -1 and -2 properly
    final windowId = MathHelper.toSigned(operands[0].value!);

    await Z.sendIO({"command": IoCommands.clearScreen, "window_id": windowId});
  }

  /// Splits the screen to create an upper window (VAR:234).
  ///
  /// Creates or resizes the upper window to have the specified number of lines.
  /// The upper window is positioned at the top of the screen and does not scroll.
  /// The lower window (main window) occupies the remaining space below.
  ///
  /// ### Behavior
  /// - If `lines` is 0, the upper window is closed (unsplit)
  /// - If `lines` is greater than 0, the upper window is created/resized
  /// - The upper window should be cleared when it is first created or expanded
  /// - In V3, the upper window is always cleared when split_window is called
  ///
  /// ### Z-Machine Spec Reference
  /// VAR:234 (split_window lines)
  void splitWindow() async {
    await Z.printBuffer();
    //Debugger.verbose('${pcHex(-1)} [split_window]');

    var operands = visitOperandsVar(1, false);

    await Z.sendIO({"command": IoCommands.splitWindow, "lines": operands[0].value});
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
