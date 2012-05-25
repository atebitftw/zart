
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

  int unpack(int packedAddr){
    return packedAddr << 2;
  }

  int pack(int unpackedAddr){
    return unpackedAddr >> 2;
  }

  int fileLengthMultiplier() => 2;


  void visitRoutine(List<int> params){

    //V3
    if (callStack.length == 0){
      //main routine
      pc--;
    }

    if (params.length > 8){
      throw new GameException('Maximum parameter count (8) exceeded.');
    }

    Debugger.verbose('  Calling Routine at ${pc.toRadixString(16)}');

    // assign any params passed to locals and push locals onto the call stack
    var locals = readb();

    stack.push(Machine.STACK_MARKER);

    Debugger.verbose('    # Locals: ${locals}');

    if (locals > 16){
      throw new GameException('Maximum local variable allocations (16) exceeded.');
    }

    // add param length to call stack (v5+ needs this)
    callStack.push(params.length);

    //set the params and locals
    if (locals > 0){
      for(int i = 1; i <= locals; i++){
        //in V5, we don't need to read locals from memory, they are all set to 0
        if (i <= params.length){
          //if param avail, store it
          callStack.push(params[i - 1]);
          Debugger.verbose('    Local ${i}: 0x${(params[i-1]).toRadixString(16)}');
        }else{
          callStack.push(0x0);
        }
      }
    }

    //push total locals onto the call stack
    callStack.push(locals);

  }


  void copy_table(){
    Debugger.verbose('${pcHex(-1)} [copy_table]');

    var operands = this.visitOperandsVar(3, false);

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
    Debugger.verbose('${pcHex(-1)} [buffer_mode]');

    var operands = this.visitOperandsVar(1, false);


    //this is basically a no op
  }

  void tokenise(){
    Debugger.verbose('${pcHex(-1)} [tokenise]');

    var operands = this.visitOperandsVar(4, true);

    if (operands.length > 2){
      Debugger.todo('implement tokenise');
    }

    var maxBytes = mem.loadb(operands[0].value);

    var textBuffer = operands[0].value + 2;

    var maxWords = mem.loadb(operands[1].value);

    var parseBuffer = operands[1].value + 1;

    var line = Z._mostRecentInput;

    Debugger.verbose('    (processing: "$line")');

    var charCount = mem.loadb(textBuffer - 1);
    //Debugger.debug('existing chars: $charCount');

    if (charCount > 0){
      //continuation of previous input
      maxBytes -= charCount;
    }

    if (line.length > maxBytes - 1){
      line = line.substring(0, maxBytes - 2);
      Debugger.verbose('    (text buffer truncated to "$line")');
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

    Debugger.verbose('    (tokenized: $tokens)');

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
    Debugger.verbose('${pcHex(-1)} [output_stream]');

    var operands = this.visitOperandsVar(2, true);

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
    Debugger.verbose('${pcHex(-1)} [set_text_style]');

    var operands = this.visitOperandsVar(1, false);

    Z.inInterrupt = true;
    Z.sendIO(IOCommands.SET_FONT, ['STYLE', operands[0].value])
    .then((_){
      Z.inInterrupt = false;
      Z.callAsync(Z.runIt);
    });
  }

  void extended(){
    Debugger.verbose('${pcHex(-1)} [extended]');

    visitExtendedInstruction();

  }

  void ext_save_undo(){
    Debugger.verbose('${pcHex(-1)} [ext_save_undo]');

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
          if (opCodes.containsKey('$i')){
            Debugger.debug('>>> (0x${(pc - 1).toRadixString(16)}) ${opCodes[i.toString()]} ($i)');
          }else{
            Debugger.debug('>>> (0x${(pc - 1).toRadixString(16)}) UNKNOWN ($i)');
          }
          Debugger.debug('${Debugger.dumpLocals()}');
        }

        if (Debugger.enableStackTrace){
             Debugger.debug('Call Stack: $callStack');
             Debugger.debug('Game Stack: $stack');
        }

        if (Debugger.isBreakPoint(pc - 1)){
          Z.inBreak = true;
          Debugger.debugStartAddr = pc - 1;
        }
      }

      ops[i]();
    }else{
      throw new GameException('Unsupported EXT Op Code: $i');
    }
  }

  void read(){
    Debugger.verbose('${pcHex(-1)} [aread]');

    Z.inInterrupt = true;

//    sendStatus();

    Z._printBuffer();

    var operands = this.visitOperandsVar(4, true);

    var storeTo = readb();

    if (operands.length > 2){
      Debugger.todo('implement aread optional args');
    }

    var maxBytes = mem.loadb(operands[0].value);

    var textBuffer = operands[0].value + 2;

    var maxWords;
    var parseBuffer;

    if (operands.length > 2){
      maxWords = mem.loadb(operands[1].value);

      parseBuffer = operands[1].value + 1;
    }

    void processLine(String line){
      line = line.trim().toLowerCase();
      Z._mostRecentInput = line;

      Debugger.verbose('    (processing: "$line")');

      var charCount = mem.loadb(textBuffer - 1);
      if (charCount > 0){
        //continuation of previous input
        maxBytes -= charCount;
      }

      if (line.length > maxBytes - 1){
        line = line.substring(0, maxBytes - 2);
        Debugger.verbose('    (text buffer truncated to "$line")');
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
        // buffer (etude.z5 does this... )
        writeVariable(storeTo, 10);
        return;
      }

      Debugger.verbose('    (tokenized: $tokens)');

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
          Debugger.debugStartAddr = pc - 1;
          Z.callAsync(Debugger.startBreak);
        }else{
          processLine(l);
          Z.callAsync(Z.runIt);
        }
      });
  }

  void check_arg_count(){
    Debugger.verbose('${pcHex(-1)} [check_arg_count]');

    var operands = this.visitOperandsVar(1, false);

    var locals = callStack[2];
    var argCount = callStack[3 + callStack[2]];

    branch(argCount == operands[0].value);
  }

  void ext_set_font(){
    Debugger.verbose('${pcHex(-1)} [ext_set_font]');
    Z.inInterrupt = true;

    var operands = this.visitOperandsVar(1, false);
    
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
    Debugger.verbose('${pcHex(-1)} [set_cursor]');

    var operands = this.visitOperandsVar(2, false);
    Z.inInterrupt = true;
    
    Z.sendIO(IOCommands.SET_CURSOR, [operands[0].value, operands[1].value])
    .then((_){
      Z.inInterrupt = false;
      Z.callAsync(Z.runIt);
    });
  }

  void set_window(){
    Debugger.verbose('${pcHex(-1)} [set_window]');
    var operands = this.visitOperandsVar(1, false);

    Z._printBuffer();

    currentWindow = operands[0].value;
  }

  void call_vs2(){
    Debugger.verbose('${pcHex(-1)} [call_vn2]');

    var operands = this.visitOperandsVar(8, true);

    var resultStore = readb();

    var returnAddr = pc;

    if (operands.isEmpty())
      throw new GameException('Call function address not given.');

    //unpack function address
    operands[0].rawValue = this.unpack(operands[0].value);

    if (operands[0].value == 0){
      //calling routine at address 0x00 automatically returns FALSE (ref 6.4.3)

      writeVariable(resultStore, Machine.FALSE);
    }else{
      //move to the routine address
      pc = operands[0].rawValue;

      //setup the routine stack frame and locals
      visitRoutine(new List.from(operands.getRange(1, operands.length - 1).map((o) => o.value)));

      //push the result store address onto the call stack
      callStack.push(resultStore);

      //push the return address onto the call stack
      callStack.push(returnAddr);
    }
  }

  void call_vn2(){
    Debugger.verbose('${pcHex(-1)} [call_vn2]');

    var operands = this.visitOperandsVar(8, true);

    var resultStore = Machine.STACK_MARKER;

    var returnAddr = pc;

    if (operands.isEmpty())
      throw new GameException('Call function address not given.');

    //unpack function address
    operands[0].rawValue = this.unpack(operands[0].value);

    if (operands[0].value == 0){
      //calling routine at address 0x00 automatically returns FALSE (ref 6.4.3)

      writeVariable(resultStore, Machine.FALSE);
    }else{
      //move to the routine address
      pc = operands[0].rawValue;

      //setup the routine stack frame and locals
      visitRoutine(new List.from(operands.getRange(1, operands.length - 1).map((o) => o.value)));

      //push the result store address onto the call stack
      callStack.push(resultStore);

      //push the return address onto the call stack
      callStack.push(returnAddr);
    }
  }

  void call_vn(){
    Debugger.verbose('${pcHex(-1)} [call_vn]');

    var operands = this.visitOperandsVar(4, true);

    var resultStore = Machine.STACK_MARKER;
    var returnAddr = pc;

    if (operands.isEmpty())
      throw new GameException('Call function address not given.');

    //unpack function address
    operands[0].rawValue = this.unpack(operands[0].value);

    if (operands[0].value == 0){
      //calling routine at address 0x00 automatically returns FALSE (ref 6.4.3)

      writeVariable(resultStore, Machine.FALSE);
    }else{
      //move to the routine address
      pc = operands[0].rawValue;

      //setup the routine stack frame and locals
      visitRoutine(new List.from(operands.getRange(1, operands.length - 1).map((o) => o.value)));

      //push the result store address onto the call stack
      callStack.push(resultStore);

      //push the return address onto the call stack
      callStack.push(returnAddr);
    }
  }

  void call_1s(){
    Debugger.verbose('${pcHex(-1)} [call_1s]');

    var operand = this.visitOperandsShortForm();

    var storeTo = readb();

    var returnAddr = pc;

    pc = unpack(operand.value);

    visitRoutine([]);

    //push the result store address onto the call stack
    callStack.push(storeTo);

    //push the return address onto the call stack
    callStack.push(returnAddr);
  }


  void call_2s(){
    Debugger.verbose('${pcHex(-1)} [call_2s]');

    var operands = mem.loadb(pc - 1) < 193
        ? this.visitOperandsLongForm()
        : this.visitOperandsVar(2, false);

    var storeTo = readb();

    var returnAddr = pc;

    pc = unpack(operands[0].value);

    visitRoutine([operands[1].value]);

    //push the result store address onto the call stack
    callStack.push(storeTo);

    //push the return address onto the call stack
    callStack.push(returnAddr);
  }


  void call_1n(){
    Debugger.verbose('${pcHex(-1)} [call_1n]');

    var operand = this.visitOperandsShortForm();

    var returnAddr = pc;

    pc = unpack(operand.value);

    visitRoutine([]);

    //push the result store address onto the call stack
    callStack.push(Machine.STACK_MARKER);

    //push the return address onto the call stack
    callStack.push(returnAddr);
  }

  void call_2n(){
    Debugger.verbose('${pcHex(-1)} [call_2n]');

    var operands = mem.loadb(pc - 1) < 193
        ? this.visitOperandsLongForm()
        : this.visitOperandsVar(2, false);

    var resultStore = Machine.STACK_MARKER;

    var returnAddr = pc;

    var addr = unpack(operands[0].value);

    //move to the routine address
    pc = unpack(operands[0].value);

    //setup the routine stack frame and locals
    visitRoutine([operands[1].value]);

    //push the result store address onto the call stack
    callStack.push(resultStore);

    //push the return address onto the call stack
    callStack.push(returnAddr);

  }

  void erase_window(){
    Debugger.verbose('${pcHex(-1)} [erase_window]');

    var operands = this.visitOperandsVar(1, false);

    Z.inInterrupt = true;
    Z.sendIO(IOCommands.CLEAR_SCREEN, [operands[0].value])
    .then((_){
      Z.inInterrupt = false;
      Z.callAsync(Z.runIt);
    });
  }

  void split_window(){
    Debugger.verbose('${pcHex(-1)} [split_window]');

    var operands = this.visitOperandsVar(1, false);

    Z.inInterrupt = true;
    Z.sendIO(IOCommands.SPLIT_SCREEN, [operands[0].value])
    .then((_){
      Z.inInterrupt = false;
      Z.callAsync(Z.runIt);
    });
  }

  void read_char(){
    Debugger.verbose('${pcHex(-1)} [read_char]');
    Z.inInterrupt = true;

    Z._printBuffer();

    var operands = this.visitOperandsVar(4, true);

    if (operands.length == 3){
      Debugger.todo('read_char time & routine operands');
    }

    var resultTo = readb();

    Z.sendIO(IOCommands.READ_CHAR)
    .then((char){
      this.writeVariable(resultTo, ZSCII.CharToZChar(char));
        Z.inInterrupt = false;
        Z.callAsync(Z.runIt);
    });
  }

  //Version 5+ supports call routines that throw
  //away return results.  Machine.STACK_MARKER is used
  //in the resultTo byte in order to mark this case.
  void doReturn(){
    // pop the return value from whoever is returning
    var result = callStack.pop();

    // return address
    var returnAddr = callStack.pop();

    // result store address byte
    // this may not be a byte if the Machine.STACK_MARKER
    // is being used.
    var resultAddrByte = callStack.pop();

    if (returnAddr == 0)
      throw new GameException('Illegal return from entry routine.');

    // unwind the locals from the stack
    var frameSize = callStack.peek();

    Debugger.verbose('(unwinding stack 1 frame)');

    //unwind locals
    while(frameSize >= 0){
      callStack.pop();
      frameSize--;
    }

    //unwind params length
    callStack.pop();

    //unwind game stack
    var gs = stack.pop();

    while(gs != Machine.STACK_MARKER){
      gs = stack.pop();
    }

    //stack marker is used in the result byte to
    //mark call routines that want to throw away the result
    if (resultAddrByte != Machine.STACK_MARKER){
      writeVariable(resultAddrByte, result);
    }

    pc = returnAddr;
  }

  List<Operand> visitOperandsVar(int howMany, bool isVariable){
    var operands = new List<Operand>();

    //load operand types
    var shiftStart = howMany > 4 ? 14 : 6;
    var os = howMany > 4 ? readw() : readb();

    while(shiftStart > -2){
      var to = os >> shiftStart; //shift
      to &= 3; //mask higher order bits we don't care about
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
      switch (o.type){
        case OperandType.LARGE:
          o.rawValue = readw();
          break;
        case OperandType.SMALL:
          o.rawValue = readb();
          break;
        case OperandType.VARIABLE:
          o.rawValue = readb();
          break;
        default:
          throw new GameException('Illegal Operand Type found: ${o.type.toRadixString(16)}');
      }
    });

    Debugger.verbose('    ${operands.length} operands:');

    operands.forEach((Operand o) {
      if (o.type == OperandType.VARIABLE){
        if (o.rawValue == 0){
          Debugger.verbose('      ${OperandType.asString(o.type)}: SP (0x${o.peekValue.toRadixString(16)})');
        }else{
          Debugger.verbose('      ${OperandType.asString(o.type)}: 0x${o.rawValue.toRadixString(16)} (0x${o.peekValue.toRadixString(16)})');
        }

      }else{
        Debugger.verbose('      ${OperandType.asString(o.type)}: 0x${o.peekValue.toRadixString(16)}');
      }
    });

    if (!isVariable && (operands.length != howMany)){
      throw new Exception('Operand count mismatch.  Expected ${howMany}, found ${operands.length}');
    }

    return operands;
  }
}
