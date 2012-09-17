
/**
* Implementation of Z-Machine v5
*/
class Version5 extends Version3
{
  ZVersion get version() => ZVersion.V5;


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

  Version5(){
    ops['136'] = call_1s;
    ops['168'] = call_1s;
    ops['143'] = call_1n;
    ops['175'] = call_1n;
    ops['190'] = extended;
    ops['121'] = call_2s;
    ops['217'] = call_2s;
    ops['218'] = call_2n;
    ops['234'] = split_window;
    ops['235'] = set_window;
    ops['236'] = call_vs2;
    ops['237'] = erase_window;
    ops['239'] = set_cursor;
    ops['241'] = set_text_style;
    ops['242'] = buffer_mode;
    ops['243'] = output_stream;
    ops['246'] = read_char;
    ops['249'] = call_vn;
    ops['250'] = call_vn2;
    ops['251'] = tokenise;
    ops['253'] = copy_table;
    ops['255'] = check_arg_count;
    ops['ext4'] = ext_set_font;
    ops['ext9'] = ext_save_undo;
  }

  // Kb
  int get maxFileLength() => 256;

  int unpack(int packedAddr) => packedAddr << 2;

  int pack(int unpackedAddr) => unpackedAddr >> 2;

  int fileLengthMultiplier() => 2;


  void visitRoutine(List<int> params){
    assert(params.length < 9);

    //Debugger.verbose('  Calling Routine at ${pc.toRadixString(16)}');

    // assign any params passed to locals and push locals onto the call stack
    var locals = readb();

    stack.push(Machine.STACK_MARKER);

    ////Debugger.verbose('    # Locals: ${locals}');

    assert(locals < 17);

    // add param length to call stack (v5+ needs this)
    callStack.push(params.length);

    //set the params and locals
    for(int i = 0; i < locals; i++){
      //in V5, we don't need to read locals from memory, they are all set to 0

      callStack.push(i < params.length ? params[i] : 0x0);
    }
    //push total locals onto the call stack
    callStack.push(locals);
  }


  void copy_table(){
    //Debugger.verbose('${pcHex(-1)} [copy_table]');

    var operands = visitOperandsVar(3, false);

    var t1Addr = operands[0].value;

    var t2Addr = operands[1].value;

    var size = operands[2].value;

    if (t2Addr == 0){
      //write size of 0's into t1
      mem.storew(t1Addr, size >> 1);
      t1Addr += 2;
      for(int i = 0; i < size; i++){
        mem.storeb(t1Addr++, 0);
      }
    }else{
      var absSize = size.abs();
      var t1End = t1Addr + mem.loadw(t1Addr);
      if (t2Addr >= t1Addr && t2Addr <= t1End){
        //overlap copy...

        Debugger.todo('implement overlap copy: t1 end: 0x${(t1Addr + mem.loadw(t1Addr)).toRadixString(16)}, t2 start: 0x${t2Addr.toRadixString(16)}');
      }else{
        //copy
        Debugger.debug('>>> Copying $absSize bytes.');
        for(int i = 0; i < absSize; i++){
          var offset = 2 + i;
          mem.storeb(t2Addr + offset, mem.loadb(t1Addr + offset));
        }
        mem.storew(t2Addr, absSize);
      }
    }
  }

  void buffer_mode(){
    //Debugger.verbose('${pcHex(-1)} [buffer_mode]');

    visitOperandsVar(1, false);

    //this is basically a no op
  }

  void tokenise(){
    //Debugger.verbose('${pcHex(-1)} [tokenise]');

    var operands = visitOperandsVar(4, true);

    if (operands.length > 2){
      Debugger.todo('implement tokenise');
    }

    var maxBytes = mem.loadb(operands[0].value);

    var textBuffer = operands[0].value + 2;

    var maxWords = mem.loadb(operands[1].value);

    var parseBuffer = operands[1].value + 1;

    var line = Z._mostRecentInput;

    //Debugger.verbose('    (processing: "$line")');

    var charCount = mem.loadb(textBuffer - 1);
    //Debugger.debug('existing chars: $charCount');

    if (charCount > 0){
      //continuation of previous input
      maxBytes -= charCount;
    }

    if (line.length > maxBytes - 1){
      line = line.substring(0, maxBytes - 2);
      //Debugger.verbose('    (text buffer truncated to "$line")');
    }

    //Debugger.debug('>> $line');

    //write the total to the textBuffer (adjust if continuation)
    mem.storeb(textBuffer - 1, line.length + charCount > 0 ? charCount : 0);

    var zChars = ZSCII.toZCharList(line);

    //adjust if continuation
    textBuffer += charCount > 0 ? charCount : 0;

    //store the zscii chars in text buffer
    for(final c in zChars){
      mem.storeb(textBuffer++, c);
    }

    var tokens = Z.machine.mem.dictionary.tokenize(line);

    //Debugger.verbose('    (tokenized: $tokens)');

    var parsed = Z.machine.mem.dictionary.parse(tokens, line);
    //Debugger.debug('$tokens $charCount');
    //Debugger.debug('$parsed');

    var maxParseBufferBytes = (4 * maxWords) + 2;

    var i = 0;
    for(final p in parsed){
      i++;
      if (i > maxParseBufferBytes) break;
      mem.storeb(parseBuffer++, p);
    }
  }

  void output_stream(){
    //Debugger.verbose('${pcHex(-1)} [output_stream]');

    var operands = visitOperandsVar(2, true);

    var stream = Machine.toSigned(operands[0].value);

    switch(stream.abs()){
      case 1:
        outputStream1 = stream < 0 ? false : true;
        break;
      case 2:
        outputStream2 = stream < 0 ? false : true;
        break;
      case 3:
        if (stream < 0){
          if (Z._memoryStreams.isEmpty()) return;

          //write out to memory
          var addr = Z._memoryStreams.last();
          Z._memoryStreams.removeLast();

          var data = Z.sbuff.toString();
          Z.sbuff = new StringBuffer();
          //Debugger.debug('(streams: ${Z._memoryStreams.length}}>>> Writing "$data"');
          mem.storew(addr, data.length);

          addr += 2;

          for(int i = 0; i < data.length; i++){
            mem.storeb(addr++, ZSCII.CharToZChar(data[i]));
          }

          //if the output stream queue is empty then
          if (Z._memoryStreams.isEmpty()){
            outputStream3 = false;
          }
        }else{
          //adding a new buffer location to the output stream stack
          outputStream3 = true;
          Z.sbuff = new StringBuffer();
          Z._memoryStreams.add(operands[1].value);
         // Debugger.debug('>>>> Starting Memory Stream: ${Z.sbuff}');
          if (Z._memoryStreams.length > 16){
            //(ref 7.1.2.1)
            throw new GameException('Maximum memory streams (16) exceeded.');
          }
        }
        break;
      case 4:
        outputStream3 = stream < 0 ? false : true;
        break;
    }
  }

  void set_text_style(){
    //Debugger.verbose('${pcHex(-1)} [set_text_style]');

    var operands = visitOperandsVar(1, false);

    Z.inInterrupt = true;
    Z.sendIO(IOCommands.SET_FONT, ['STYLE', operands[0].value])
    .then((_){
      Z.inInterrupt = false;
      Z.callAsync(Z.runIt);
    });
  }

  void extended(){
    //Debugger.verbose('${pcHex(-1)} [extended]');

    visitExtendedInstruction();

  }

  void ext_save_undo(){
    //Debugger.verbose('${pcHex(-1)} [ext_save_undo]');

    readb(); //throw away byte

    var resultTo = readb();

    //we don't support this yet.
    writeVariable(resultTo, -1);
  }

  void visitExtendedInstruction(){
    var i = 'ext${readb()}';

    if (ops.containsKey(i)){
      if (Debugger.enableDebug){
        if (Debugger.enableTrace && !Z.inBreak){
          Debugger.debug('>>> (0x${(PC - 1).toRadixString(16)}) ($i)');
          Debugger.debug('${Debugger.dumpLocals()}');
        }

        if (Debugger.enableStackTrace){
             Debugger.debug('Call Stack: $callStack');
             Debugger.debug('Game Stack: $stack');
        }

        if (Debugger.isBreakPoint(PC - 1)){
          Z.inBreak = true;
          Debugger.debugStartAddr = PC - 1;
        }
      }
      ops[i]();
    }else{
      throw new GameException('Unsupported EXT Op Code: $i');
    }
  }

  void read(){
    //Debugger.verbose('${pcHex(-1)} [aread]');

    Z.inInterrupt = true;

//    sendStatus();

    Z._printBuffer();

    var operands = visitOperandsVar(4, true);

    var storeTo = readb();

    if (operands.length > 2){
      Debugger.todo('implement aread optional args');
    }

    var maxBytes = mem.loadb(operands[0].value);

    var textBuffer = operands[0].value + 2;

    var maxWords;
    num parseBuffer;

    if (operands.length > 2){
      maxWords = mem.loadb(operands[1].value);

      parseBuffer = operands[1].value + 1;
    }

    void processLine(String line){
      line = line.trim().toLowerCase();
      Z._mostRecentInput = line;

      //Debugger.verbose('    (processing: "$line")');

      var charCount = mem.loadb(textBuffer - 1);
      if (charCount > 0){
        //continuation of previous input
        maxBytes -= charCount;
      }

      if (line.length > maxBytes - 1){
        line = line.substring(0, maxBytes - 2);
        //Debugger.verbose('    (text buffer truncated to "$line")');
      }

      var tbTotalAddr = textBuffer - 1;

      //write the total to the textBuffer (adjust if continuation)
      mem.storeb(tbTotalAddr, line.length + charCount > 0 ? line.length + charCount : 0);

      var zChars = ZSCII.toZCharList(line);

      //adjust if continuation
      textBuffer += charCount > 0 ? charCount : 0;

      //store the zscii chars in text buffer
      for(final c in zChars){
        mem.storeb(textBuffer++, c);
      }

      //Debugger.debug('${Z.machine.mem.dump(tbTotalAddr - 1, line.length + 2)}');

      var tokens = Z.machine.mem.dictionary.tokenize(line);

      if (maxWords == null){
        //second parameter was not passed, so
        // we are not going to write to the parse
        // buffer (etude.z5 does .. )
        writeVariable(storeTo, 10);
        return;
      }

      //Debugger.verbose('    (tokenized: $tokens)');

      var parsed = Z.machine.mem.dictionary.parse(tokens, line);
      //Debugger.debug('$parsed');

      var maxParseBufferBytes = (4 * maxWords) + 2;

      var i = 0;
      for(final p in parsed){
        i++;
        if (i > maxParseBufferBytes) break;
        mem.storeb(parseBuffer++, p);
      }

      writeVariable(storeTo, 10);
    }

    Z.sendIO(IOCommands.READ)
      .then((String l){
        Z.inInterrupt = false;
        if (l == '/!'){
          Z.inBreak = true;
          Debugger.debugStartAddr = PC - 1;
          Z.callAsync(Debugger.startBreak);
        }else{
          processLine(l);
          Z.callAsync(Z.runIt);
        }
      });
  }

  void check_arg_count(){
    //Debugger.verbose('${pcHex(-1)} [check_arg_count]');

    var operands = visitOperandsVar(1, false);

    var locals = callStack[2];
    var argCount = callStack[3 + callStack[2]];

    branch(argCount == operands[0].value);
  }

  void ext_set_font(){
    //Debugger.verbose('${pcHex(-1)} [ext_set_font]');
    Z.inInterrupt = true;

    var operands = visitOperandsVar(1, false);

    Z.sendIO(IOCommands.SET_FONT, [operands[0].value])
    .then((result){
      Z.inInterrupt = false;
      if (result != null){
        writeVariable(readb(), result);
      }else{
        writeVariable(readb(), 0);
      }
      Z.callAsync(Z.runIt);
    });
  }

  void set_cursor(){
    //Debugger.verbose('${pcHex(-1)} [set_cursor]');

    var operands = visitOperandsVar(2, false);
    Z.inInterrupt = true;

    Z.sendIO(IOCommands.SET_CURSOR, [operands[0].value, operands[1].value])
    .then((_){
      Z.inInterrupt = false;
      Z.callAsync(Z.runIt);
    });
  }

  void set_window(){
    //Debugger.verbose('${pcHex(-1)} [set_window]');
    var operands = visitOperandsVar(1, false);

    Z._printBuffer();

    currentWindow = operands[0].value;
  }

  void call_vs2(){
    //Debugger.verbose('${pcHex(-1)} [call_vn2]');

    var operands = visitOperandsVar(8, true);

    var resultStore = readb();

    var returnAddr = PC;

    assert(operands.length > 0);

    if (operands[0].value == 0){
      //calling routine at address 0x00 automatically returns FALSE (ref 6.4.3)

      writeVariable(resultStore, Machine.FALSE);
    }else{
      //unpack function address
      operands[0].rawValue = unpack(operands[0].value);

      //move to the routine address
      PC = operands[0].rawValue;

      //peel off the first operand
      operands.removeRange(0, 1);

      //setup the routine stack frame and locals
      visitRoutine(operands.map((o) => o.value));

      //push the result store address onto the call stack
      callStack.push(resultStore);

      //push the return address onto the call stack
      callStack.push(returnAddr);
    }
  }

  void call_vn2(){
    //Debugger.verbose('${pcHex(-1)} [call_vn2]');

    var operands = visitOperandsVar(8, true);

    var resultStore = Machine.STACK_MARKER;

    var returnAddr = PC;

    assert(operands.length > 0);

    if (operands[0].value == 0){
      //calling routine at address 0x00 automatically returns FALSE (ref 6.4.3)

      writeVariable(resultStore, Machine.FALSE);
    }else{
      //unpack function address
      operands[0].rawValue = unpack(operands[0].value);

      //move to the routine address
      PC = operands[0].rawValue;

      operands.removeRange(0, 1);

      //setup the routine stack frame and locals
      visitRoutine(operands.map((o) => o.value));

      //push the result store address onto the call stack
      callStack.push(resultStore);

      //push the return address onto the call stack
      callStack.push(returnAddr);
    }
  }

  void call_vn(){
    //Debugger.verbose('${pcHex(-1)} [call_vn]');

    var operands = visitOperandsVar(4, true);

    var resultStore = Machine.STACK_MARKER;
    var returnAddr = PC;

    assert(operands.length > 0);

    if (operands[0].value == 0){
      //calling routine at address 0x00 automatically returns FALSE (ref 6.4.3)

      writeVariable(resultStore, Machine.FALSE);
    }else{
      //unpack function address
      operands[0].rawValue = unpack(operands[0].value);

      //move to the routine address
      PC = operands[0].rawValue;

      operands.removeRange(0, 1);

      //setup the routine stack frame and locals
      visitRoutine(operands.map((o) => o.value));

      //push the result store address onto the call stack
      callStack.push(resultStore);

      //push the return address onto the call stack
      callStack.push(returnAddr);
    }
  }

  void call_1s(){
    //Debugger.verbose('${pcHex(-1)} [call_1s]');

    var operand = visitOperandsShortForm();

    var storeTo = readb();

    var returnAddr = PC;

    PC = unpack(operand.value);

    visitRoutine([]);

    //push the result store address onto the call stack
    callStack.push(storeTo);

    //push the return address onto the call stack
    callStack.push(returnAddr);
  }


  void call_2s(){
    //Debugger.verbose('${pcHex(-1)} [call_2s]');

    var operands = mem.loadb(PC - 1) < 193
        ? visitOperandsLongForm()
        : visitOperandsVar(2, false);

    var storeTo = readb();

    var returnAddr = PC;

    PC = unpack(operands[0].value);

    visitRoutine([operands[1].value]);

    //push the result store address onto the call stack
    callStack.push(storeTo);

    //push the return address onto the call stack
    callStack.push(returnAddr);
  }


  void call_1n(){
    //Debugger.verbose('${pcHex(-1)} [call_1n]');

    var operand = visitOperandsShortForm();

    var returnAddr = PC;

    PC = unpack(operand.value);

    visitRoutine([]);

    //push the result store address onto the call stack
    callStack.push(Machine.STACK_MARKER);

    //push the return address onto the call stack
    callStack.push(returnAddr);
  }

  void call_2n(){
    //Debugger.verbose('${pcHex(-1)} [call_2n]');

    var operands = mem.loadb(PC - 1) < 193
        ? visitOperandsLongForm()
        : visitOperandsVar(2, false);

    var resultStore = Machine.STACK_MARKER;

    var returnAddr = PC;

    var addr = unpack(operands[0].value);

    //move to the routine address
    PC = unpack(operands[0].value);

    //setup the routine stack frame and locals
    visitRoutine([operands[1].value]);

    //push the result store address onto the call stack
    callStack.push(resultStore);

    //push the return address onto the call stack
    callStack.push(returnAddr);

  }

  void erase_window(){
    //Debugger.verbose('${pcHex(-1)} [erase_window]');

    var operands = visitOperandsVar(1, false);

    Z.inInterrupt = true;
    Z.sendIO(IOCommands.CLEAR_SCREEN, [operands[0].value])
    .then((_){
      Z.inInterrupt = false;
      Z.callAsync(Z.runIt);
    });
  }

  void split_window(){
    //Debugger.verbose('${pcHex(-1)} [split_window]');

    var operands = visitOperandsVar(1, false);

    Z.inInterrupt = true;
    Z.sendIO(IOCommands.SPLIT_SCREEN, [operands[0].value])
    .then((_){
      Z.inInterrupt = false;
      Z.callAsync(Z.runIt);
    });
  }

  void read_char(){
    //Debugger.verbose('${pcHex(-1)} [read_char]');
    Z.inInterrupt = true;

    Z._printBuffer();

    var operands = visitOperandsVar(4, true);

    if (operands.length == 3){
      Debugger.todo('read_char time & routine operands');
    }

    var resultTo = readb();

    Z.sendIO(IOCommands.READ_CHAR)
    .then((char){
      writeVariable(resultTo, ZSCII.CharToZChar(char));
        Z.inInterrupt = false;
        Z.callAsync(Z.runIt);
    });
  }

  //Version 5+ supports call routines that throw
  //away return results.  Machine.STACK_MARKER is used
  //in the resultTo byte in order to mark this case.
  void doReturn(var result){

    // return address
    PC = callStack.pop();
    assert(PC > 0);

    // result store address byte
    // this may not be a byte if the Machine.STACK_MARKER
    // is being used.
    var resultAddrByte = callStack.pop();

    //unwind locals and params length
    callStack._stack.removeRange(0, callStack.peek() + 2);

    //unwind game stack
    while(stack.pop() != Machine.STACK_MARKER){}

    //stack marker is used in the result byte to
    //mark call routines that want to throw away the result
    if (resultAddrByte == Machine.STACK_MARKER) return;

    writeVariable(resultAddrByte, result);
  }

  List<Operand> visitOperandsVar(int howMany, bool isVariable){
    var operands = new List<Operand>();

    //load operand types
    var shiftStart = howMany > 4 ? 14 : 6;
    var os = howMany > 4 ? readw() : readb();

    var to;
    while(shiftStart > -2){
      to = (os >> shiftStart) & 3; //shift and mask bottom 2 bits

      if (to == OperandType.OMITTED){
        break;
      }else{
        operands.add(new Operand(to));
        if (operands.length == howMany) break;
        shiftStart -= 2;
      }
    }

    //load values
    operands.forEach((Operand o){
      o.rawValue = o.type == OperandType.LARGE ? readw() : readb();
    });

//    if (!isVariable && (operands.length != howMany)){
//      throw new Exception('Operand count mismatch.  Expected ${howMany}, found ${operands.length}');
//    }

    return operands;
  }
}
