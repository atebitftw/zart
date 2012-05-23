/**
* Base machine that is compatible with Z-Machine V1.
*
*/
class Machine
{
  static final int STACK_MARKER = -0x10000;
  /// Z-Machine False = 0
  static final int FALSE = 0;
  /// Z-Machine True = 1
  static final int TRUE = 1;
  static final int SP = 0;

  final _Stack stack;
  final _Stack callStack;

  int currentWindow = 0;

  // Screen
  bool outputStream1 = true;

  // Printer lol
  bool outputStream2 = true;

  // Memory Table
  bool outputStream3 = false;

  // Player input script
  bool outputStream4 = false;

  DRandom r;

  String pcHex([int offset = 0]) => '[0x${(pc + offset).toRadixString(16)}]';

  /// Z-Machine Program Counter
  int pc = 0;

  _MemoryMap mem;

  Map<String, Function> ops;

  int get propertyDefaultsTableSize() => 31;

  /**
  * Takes any Dart int between -32768 & 32767 and makes a machine-readable
  * 16-bit signed 'word' from it.
  *
  * ref(2.2)
  */
  static int dartSignedIntTo16BitSigned(int val){
    assert(val >= -32768 && val <= 32767);

    if (val >= 0) return val;

    val = val.abs();

    return 65536 - val;
  }

  /**
  * Converts a game 16-bit 'word' into a signed Dart int.
  *
  * ref(2.2)
  */
  static int toSigned(int val){
    if (val == 0) return val;

    // game 16-bit word is always positive number to Dart
    assert(val > 0);

    // convert to signed if 16-bit MSB is set
    return (val & 0x8000) == 0x8000
        ? -(65536 - val)
        : val;
  }


  ZVersion get version() => ZVersion.V1;

  // Kb
  int get maxFileLength() => 128;

  int unpack(int packedAddr){
    return packedAddr << 1;
  }

  int pack(int unpackedAddr){
    return unpackedAddr >> 1;
  }

  int fileLengthMultiplier() => 2;

  void visitRoutine(List<int> params){

    //V3
    if (callStack.length == 0){
      //main routine
      pc--;
    }

    Debugger.verbose('  Calling Routine at ${pc.toRadixString(16)}');

    // assign any params passed to locals and push locals onto the call stack
    var locals = readb();

    stack.push(STACK_MARKER);

    Debugger.verbose('    # Locals: ${locals}');

    if (locals > 16){
      throw new GameException('Maximum local variable allocations (16) exceeded.');
    }

    // add param length to call stack (v5+ needs this)
    callStack.push(params.length);

    //set the routine to default locals (V3...)

    if (locals > 0){
      for(int i = 1; i <= locals; i++){
        if (i <= params.length){
          //if param avail, store it
          callStack.push(params[i - 1]);
          Debugger.verbose('    Local ${i}: 0x${(params[i-1]).toRadixString(16)}');
          //mem.storew(pc, params[i - 1]);
        }else{
          //push otherwise push the local
          callStack.push(mem.loadw(pc));
          Debugger.verbose('    Local ${i}: 0x${mem.loadw(pc).toRadixString(16)}');
        }

        pc += 2;
      }
    }

    //push total locals onto the call stack
    callStack.push(locals);
  }

  void doReturn(){
    // pop the return value from whoever is returning
    var result = callStack.pop();

    // return address
    var returnAddr = callStack.pop();

    // result store address byte
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

    while(gs != STACK_MARKER){
      gs = stack.pop();
    }

    writeVariable(resultAddrByte, result);

    pc = returnAddr;
  }

  void visitInstruction(){
    var i = readb();
    if (ops.containsKey('$i')){
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

      ops['$i']();
    }else{
      notFound();
    }

  }

  void notFound(){
    throw new GameException('Unsupported Op Code: ${mem.loadb(pc - 1)}');
  }

  void restore(){
    if (Z.inInterrupt) {
      return;
    }

    Z.inInterrupt = true;

    Z.sendIO(IOCommands.RESTORE).then((stream){
      Z.inInterrupt = false;
      if (stream == null) {
        branch(false);
      }else{
        var result = Quetzal.restore(stream);
        if (!result){
          branch(false);
        }
      }

      //PC should be set by restore here
      Z.callAsync(Z.runIt);
    });
  }

  void save(){
    if (Z.inInterrupt) {
      return;
    }

    Z.inInterrupt = true;

    //calculates the local jump offset (ref 4.7)
    int jumpToLabelOffset(int jumpByte){

      if (BinaryHelper.isSet(jumpByte, 6)){
        //single byte offset
        return BinaryHelper.bottomBits(jumpByte, 6);
      }else{
        //create the 14-bit offset value with next byte
        var val = (BinaryHelper.bottomBits(jumpByte, 6) << 8) | readb();

        //convert to Dart signed int (14-bit MSB is the sign bit)
        return ((val & 0x2000) == 0x2000)
            ? -(16384 - val)
            : val;
      }
    }

    var jumpByte = readb();

    bool branchOn = BinaryHelper.isSet(jumpByte, 7);

    var offset = jumpToLabelOffset(jumpByte);

    var saveData = [];
    saveData.add(IOCommands.SAVE.toString());
    if (branchOn){
      saveData.addAll(Quetzal.save(pc + (offset - 2)));

      Z.IOConfig
      .command(JSON.stringify(saveData))
      .then((result){
        Z.inInterrupt = false;
        if (result) pc += offset - 2;
        Z.callAsync(Z.runIt);
      });
    }else{
      saveData.addAll(Quetzal.save(pc));

      Z.IOConfig
      .command(JSON.stringify(saveData))
      .then((result){
        Z.inInterrupt = false;
        if (!result) pc += offset - 2;
        Z.callAsync(Z.runIt);
      });
    }
  }

  void branch(bool testResult)
  {
    //calculates the local jump offset (ref 4.7)
    int jumpToLabelOffset(int jumpByte){

      if (BinaryHelper.isSet(jumpByte, 6)){
        //single byte offset
        return BinaryHelper.bottomBits(jumpByte, 6);
      }else{
        //create the 14-bit offset value with next byte
        var val = (BinaryHelper.bottomBits(jumpByte, 6) << 8) | readb();

        //convert to Dart signed int (14-bit MSB is the sign bit)
        return ((val & 0x2000) == 0x2000)
            ? -(16384 - val)
            : val;
      }
    }

    var jumpByte = readb();

    bool branchOn = BinaryHelper.isSet(jumpByte, 7);

    Debugger.verbose('    (branch condition: $branchOn)');

    if (testResult == null || testResult is! bool){
      throw new GameException('Test function must return a boolean value.');
    }

    var offset = jumpToLabelOffset(jumpByte);

    if ((branchOn && testResult) || (!branchOn && !testResult)){
      // If the offset is 0 or 1 (FALSE or TRUE), perform a return
      // operation.
      if (offset == Machine.FALSE){
        Debugger.verbose('    (branch returning FALSE)');
        callStack.push(Machine.FALSE);
        doReturn();
        return;
      }

      if (offset == Machine.TRUE){
        Debugger.verbose('    (branch returning TRUE)');
        callStack.push(Machine.TRUE);
        doReturn();
        return;
      }

      //jump to the offset and continue...
      pc += offset - 2;
      Debugger.verbose('    (branching to 0x${pc.toRadixString(16)})');
      return;
    }

    //otherwise just continue to the next instruction...
    Debugger.verbose('    (continuing to next instruction)');
  }

  void sendStatus(){
    var oid = readVariable(0x10);

    var locObject = oid != 0 ? new GameObject(oid).shortName : '';

    Z.sendIO(IOCommands.STATUS, [
                              Header.isScoreGame() ? 'SCORE' : 'TIME',
                              locObject,
                              readVariable(0x11),
                              readVariable(0x12)
                                 ]);
  }

  void callVS(){
    Debugger.verbose('${pcHex(-1)} [call_vs]');
    var operands = this.visitOperandsVar(4, true);

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

  void read(){
    Debugger.verbose('${pcHex(-1)} [read]');

    Z.inInterrupt = true;

    sendStatus();

    Z._printBuffer();

    var operands = this.visitOperandsVar(4, true);

    var maxBytes = mem.loadb(operands[0].value);

    var textBuffer = operands[0].value + 1;

    var maxWords = mem.loadb(operands[1].value);

    var parseBuffer = operands[1].value + 1;

    void processLine(String line){
      line = line.trim().toLowerCase();

      Debugger.verbose('    (processing: "$line")');

      if (line.length > maxBytes - 1){
        line = line.substring(0, maxBytes - 2);
        Debugger.verbose('    (text buffer truncated to "$line")');
      }

      var zChars = ZSCII.toZCharList(line);

      //store the zscii chars in text buffer
      for(final c in zChars){
        mem.storeb(textBuffer++, c);
      }

      //terminator
      mem.storeb(textBuffer, 0);

      var tokens = Z.machine.mem.dictionary.tokenize(line);

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

//      Z._io.callAsync(Z._runIt);
    }

    Future<String> line = Z.IOConfig.command(JSON.stringify([IOCommands.READ.toString()]));

    doIt(foo){
      if (line.isComplete){
        Z.inInterrupt = false;
        if (line == '/!'){
          Z.inBreak = true;
//          Z._io.callAsync(Debugger.startBreak);
        }else{
          processLine(line.value);
        }
      }else{
        line.then((String l){
          Z.inInterrupt = false;
          if (l == '/!'){
            Z.inBreak = true;
            Debugger.debugStartAddr = pc - 1;
            Z.callAsync(Debugger.startBreak);
//            Z._io.callAsync(Debugger.startBreak);
          }else{
            processLine(l);
            Z.callAsync(Z.runIt);
          }
        });
      }
    }

    doIt(null);

//    Z._io.callAsync(doIt);
  }

  void random(){
    Debugger.verbose('${pcHex(-1)} [random]');

    Math.random();

    var operands = this.visitOperandsVar(1, false);

    var resultTo = readb();

    var range = operands[0].value;

    //default return value in first two cases
    var result = 0;

    if (range < 0){
      r = new DRandom.withSeed(range);
      Debugger.verbose('    (set RNG to seed: $range)');
    }else if(range == 0){
      r = new DRandom.withSeed(new Date.now().milliseconds);
      Debugger.verbose('    (set RNG to random seed)');
    }else{
      result = r.NextFromMax(range) + 1;
      Debugger.verbose('    (Rolled [1 - $range] number: $result)');
    }

    writeVariable(resultTo, result);
  }

  void pull(){
    Debugger.verbose('${pcHex(-1)} [pull]');
    var operand = this.visitOperandsVar(1, false);

    var value = stack.pop();

    Debugger.verbose('    Pulling 0x${value.toRadixString(16)} from to the stack.');

    writeVariable(operand[0].rawValue, value);
  }

  void push(){
    Debugger.verbose('${pcHex(-1)} [push]');
    var operand = this.visitOperandsVar(1, false);

    Debugger.verbose('    Pushing 0x${operand[0].value.toRadixString(16)} to the stack.');

    stack.push(operand[0].value);

//    if (operand[0].rawValue == 0){
//      //pushing SP into SP would be counterintuitive...
//      stack.push(0);
//    }else{
//      stack.push(this.readVariable(operand[0].value));
//    }
  }

  void ret_popped(){
    Debugger.verbose('${pcHex(-1)} [ret_popped]');
    var v = stack.pop();

    assertNotMarker(v);

    Debugger.verbose('    Popping 0x${v.toRadixString(16)} from the stack and returning.');
    callStack.push(v);
    doReturn();
  }

  assertNotMarker(m) {
    if (m == Machine.STACK_MARKER){
      throw new GameException('Stack Underflow.');
    }
  }

  void rtrue(){
    Debugger.verbose('${pcHex(-1)} [rtrue]');
    callStack.push(Machine.TRUE);
    doReturn();
  }

  void rfalse(){
    Debugger.verbose('${pcHex(-1)} [rfalse]');
    callStack.push(Machine.FALSE);
    doReturn();
  }

  void nop(){
    Debugger.verbose('${pcHex(-1)} [nop]');
  }

  void pop(){
    Debugger.verbose('${pcHex(-1)} [pop]');

    stack.pop();
  }

  void show_status(){
    Debugger.verbose('${pcHex(-1)} [show_status]');

    //treat as NOP
  }

  void verify(){
    Debugger.verbose('${pcHex(-1)} [verify]');

    //always verify
    branch(true);
  }

  void piracy(){
    Debugger.verbose('${pcHex(-1)} [piracy]');

    //always branch (game disk is genuine ;)
    branch(true);
  }

  void jz(){
    Debugger.verbose('${pcHex(-1)} [jz]');

    var operand = this.visitOperandsShortForm();

    branch(operand.value == 0);
  }

  void get_sibling(){
    Debugger.verbose('${pcHex(-1)} [get_sibling]');

    var operand = this.visitOperandsShortForm();

    var resultTo = readb();

    GameObject obj = new GameObject(operand.value);

    writeVariable(resultTo, obj.sibling);

    branch(obj.sibling != 0);
  }

  void get_child(){
    Debugger.verbose('${pcHex(-1)} [get_child]');

    var operand = this.visitOperandsShortForm();

    var resultTo = readb();

    GameObject obj = new GameObject(operand.value);

    writeVariable(resultTo, obj.child);

    branch(obj.child != 0);
  }

  void inc(){
    Debugger.verbose('${pcHex(-1)} [inc]');

    var operand = this.visitOperandsShortForm();

    var value = toSigned(readVariable(operand.rawValue)) + 1;

    writeVariable(operand.rawValue, value);

  }

  void dec(){
    Debugger.verbose('${pcHex(-1)} [dec]');

    var operand = this.visitOperandsShortForm();

    var value = toSigned(readVariable(operand.rawValue)) - 1;

    writeVariable(operand.rawValue, value);
  }

  void test(){
    Debugger.verbose('${pcHex(-1)} [test]');
    var pp = pc - 1;

    var operands = mem.loadb(pc - 1) < 193
        ? this.visitOperandsLongForm()
        : this.visitOperandsVar(2, false);

    var jumpByte = mem.loadb(pc);

    bool branchOn = BinaryHelper.isSet(jumpByte, 7);
    var bitmap = operands[0].value;
    var flags = operands[1].value;

    Debugger.verbose('   [0x${pp.toRadixString(16)}] testing bitmap($branchOn) "${bitmap.toRadixString(2)}" against "${flags.toRadixString(2)}" ${(bitmap & flags) == flags}');

    branch((bitmap & flags) == flags);
  }

  void dec_chk(){
    Debugger.verbose('${pcHex(-1)} [dec_chk]');

    var operands = mem.loadb(pc - 1) < 193
        ? this.visitOperandsLongForm()
        : this.visitOperandsVar(2, false);

    var value = toSigned(readVariable(operands[0].rawValue)) - 1;

    //(ref http://www.gnelson.demon.co.uk/zspec/sect14.html notes #5)
    writeVariable(operands[0].rawValue, value);

    branch(value < toSigned(operands[1].value));
  }

  void inc_chk(){
    Debugger.verbose('${pcHex(-1)} [inc_chk]');

    var operands = mem.loadb(pc - 1) < 193
        ? this.visitOperandsLongForm()
        : this.visitOperandsVar(2, false);

 //   var value = toSigned(readVariable(operands[0].rawValue)) + 1;
    var varValue = readVariable(operands[0].rawValue);

    var value = toSigned(readVariable(operands[0].rawValue)) + 1;

    //(ref http://www.gnelson.demon.co.uk/zspec/sect14.html notes #5)
    writeVariable(operands[0].rawValue, value);

    branch(value > toSigned(operands[1].value));
  }

  void test_attr(){
    Debugger.verbose('${pcHex(-1)} [test_attr]');

    var operands = mem.loadb(pc - 1) < 193
        ? this.visitOperandsLongForm()
        : this.visitOperandsVar(2, false);

    GameObject obj = new GameObject(operands[0].value);

    Debugger.verbose('    (test Attribute) >>> object: ${obj.shortName}(${obj.id}) ${operands[1].value}: ${obj.isFlagBitSet(operands[1].value)}');
    branch(obj.isFlagBitSet(operands[1].value));
  }

  void jin()  {
    Debugger.verbose('${pcHex(-1)} [jin]');

    var operands = mem.loadb(pc - 1) < 193
        ? this.visitOperandsLongForm()
        : this.visitOperandsVar(2, false);

    var child = new GameObject(operands[0].value);
    var parent = new GameObject(operands[1].value);

    branch(child.parent == parent.id);
  }

  void jeV(){
    Debugger.verbose('${pcHex(-1)} [jeV]');
    var operands = this.visitOperandsVar(4, true);

    if (operands.length < 2){
      throw new GameException('At least 2 operands required for jeV instruction.');
    }

    var foundMatch = false;

    var testVal = toSigned(operands[0].value);

    for(int i = 1; i < operands.length; i++){
      if (foundMatch == true) break;
      var against = toSigned(operands[i].value);

      if (testVal == against){
        foundMatch = true;
      }
    }

    branch(foundMatch);
  }

  void quit(){
    Debugger.verbose('${pcHex(-1)} [quit]');

    Z.quit = true;

    Z.sendIO(IOCommands.QUIT);
  }

  void restart(){
    Debugger.verbose('${pcHex(-1)} [restart]');

    Z.softReset();

    var obj = new GameObject(4);

    assert(obj.child == 0);

    // visit the main 'routine'
    visitRoutine([]);

    //push dummy result store onto the call stack
    callStack.push(0);

    //push dummy return address onto the call stack
    callStack.push(0);

    Z.callAsync(Z.runIt);
  }

  void jl(){
    Debugger.verbose('${pcHex(-1)} [jl]');

    var operands = mem.loadb(pc - 1) < 193
        ? this.visitOperandsLongForm()
        : this.visitOperandsVar(2, false);

    branch(toSigned(operands[0].value) < toSigned(operands[1].value));
  }

  void jg(){
    Debugger.verbose('${pcHex(-1)} [jg]');

    var operands = mem.loadb(pc - 1) < 193
        ? this.visitOperandsLongForm()
        : this.visitOperandsVar(2, false);

    branch(toSigned(operands[0].value) > toSigned(operands[1].value));
  }

  void je(){
    Debugger.verbose('${pcHex(-1)} [je]');

    var operands = mem.loadb(pc - 1) < 193
        ? this.visitOperandsLongForm()
        : this.visitOperandsVar(2, false);

    branch(toSigned(operands[0].value) == toSigned(operands[1].value));
  }

  void newline(){
    Debugger.verbose('${pcHex(-1)} [newline]');

    Z.sbuff.add('\n');
  }

  void print_obj(){
    Debugger.verbose('${pcHex(-1)} [print_obj]');
    var operand = this.visitOperandsShortForm();

    var obj = new GameObject(operand.value);

    Z.sbuff.add(obj.shortName);
  }

  void print_addr(){
    Debugger.verbose('${pcHex(-1)} [print_addr]');
    var operand = this.visitOperandsShortForm();

    var addr = operand.value;

    var str = ZSCII.readZStringAndPop(addr);

    //print('${pcHex()} "$str"');

    Z.sbuff.add(str);
  }

  void print_paddr(){
    Debugger.verbose('${pcHex(-1)} [print_paddr]');

    var operand = this.visitOperandsShortForm();

    var addr = this.unpack(operand.value);

    var str = ZSCII.readZStringAndPop(addr);

    Debugger.verbose('${pcHex()} "$str"');

    Z.sbuff.add(str);
  }

  void print_char(){
    Debugger.verbose('${pcHex(-1)} [print_char]');

    var operands = this.visitOperandsVar(1, false);

    var z = operands[0].value;

    if (z < 0 || z > 1023){
      throw new GameException('ZSCII char is out of bounds.');
    }

    Z.sbuff.add(ZSCII.ZCharToChar(z));
  }

  void print_num(){
    Debugger.verbose('${pcHex(-1)} [print_num]');

    var operands = this.visitOperandsVar(1, false);

    Z.sbuff.add('${toSigned(operands[0].value)}');
  }

  void print_ret(){
    Debugger.verbose('${pcHex(-1)} [print_ret]');

    var str = ZSCII.readZStringAndPop(pc);

    Z.sbuff.add('${str}\n');

    Debugger.verbose('${pcHex()} "$str"');

    callStack.push(Machine.TRUE);

    doReturn();
  }

  void printf(){
    Debugger.verbose('${pcHex(-1)} [print]');

    var str = ZSCII.readZString(pc);
    Z.sbuff.add(str);

    Debugger.verbose('${pcHex()} "$str"');

    pc = callStack.pop();
  }

  void insert_obj(){
    Debugger.verbose('${pcHex(-1)} [insert_obj]');

    var operands = mem.loadb(pc - 1) < 193
        ? this.visitOperandsLongForm()
        : this.visitOperandsVar(2, false);

    GameObject from = new GameObject(operands[0].value);

    GameObject to = new GameObject(operands[1].value);

    Debugger.verbose('Insert Object ${from.id}(${from.shortName}) into ${to.id}(${to.shortName})');

    from.insertTo(to.id);
  }

  void remove_obj(){
    Debugger.verbose('${pcHex(-1)} [remove_obj]');

    var operand = this.visitOperandsShortForm();

    GameObject o = new GameObject(operand.value);

    Debugger.verbose('Removing Object ${o.id}(${o.shortName}) from object tree.');
    o.removeFromTree();
  }

  void store(){
    Debugger.verbose('${pcHex(-1)} [store]');

    var operands = mem.loadb(pc - 1) < 193
        ? this.visitOperandsLongForm()
        : this.visitOperandsVar(2, false);

    assert(operands[0].rawValue <= 0xff);

    if (operands[0].rawValue == Machine.SP){
      operands[0].rawValue = readVariable(Machine.SP);
    }

    writeVariable(operands[0].rawValue, operands[1].value);
 }

  void load(){
    Debugger.verbose('${pcHex(-1)} [load]');

    var operand = this.visitOperandsShortForm();

    var resultTo = readb();

    if (operand.rawValue == Machine.SP){
      operand.rawValue = readVariable(Machine.SP);
    }


    var v = readVariable(operand.rawValue);

    writeVariable(resultTo, v);
  }

  void jump(){
    Debugger.verbose('${pcHex(-1)} [jump]');

    var operand = this.visitOperandsShortForm();

    var offset = toSigned(operand.value) - 2;

    pc += offset;

    Debugger.verbose('    (jumping to ${pcHex()})');
  }


  void ret(){
    Debugger.verbose('${pcHex(-1)} [ret]');

    var operand = this.visitOperandsShortForm();

    Debugger.verbose('    returning 0x${operand.peekValue.toRadixString(16)}');

    callStack.push(operand.value);

    doReturn();
  }

  void get_parent(){
    Debugger.verbose('${pcHex(-1)} [get_parent]');

    var operand = this.visitOperandsShortForm();

    var resultTo = readb();

    GameObject obj = new GameObject(operand.value);

    writeVariable(resultTo, obj.parent);

  }

  void clear_attr(){
    Debugger.verbose('${pcHex(-1)} [clear_attr]');

    var operands = mem.loadb(pc - 1) < 193
        ? this.visitOperandsLongForm()
        : this.visitOperandsVar(2, false);

    GameObject obj = new GameObject(operands[0].value);

    obj.unsetFlagBit(operands[1].value);
    Debugger.verbose('    (clear Attribute) >>> object: ${obj.shortName}(${obj.id}) ${operands[1].value}: ${obj.isFlagBitSet(operands[1].value)}');
  }

  void set_attr(){
    Debugger.verbose('${pcHex(-1)} [set_attr]');

    var operands = mem.loadb(pc - 1) < 193
        ? this.visitOperandsLongForm()
        : this.visitOperandsVar(2, false);

    GameObject obj = new GameObject(operands[0].value);

    obj.setFlagBit(operands[1].value);
    Debugger.verbose('    (set Attribute) >>> object: ${obj.shortName}(${obj.id}) ${operands[1].value}: ${obj.isFlagBitSet(operands[1].value)}');
  }

  void or(){
    Debugger.verbose('${pcHex(-1)} [or]');

    var operands = mem.loadb(pc - 1) < 193
        ? this.visitOperandsLongForm()
        : this.visitOperandsVar(2, false);

    var resultTo = readb();

    writeVariable(resultTo, (operands[0].value | operands[1].value));
  }

  void and(){
    Debugger.verbose('${pcHex(-1)} [and]');

    var operands = mem.loadb(pc - 1) < 193
        ? this.visitOperandsLongForm()
        : this.visitOperandsVar(2, false);

    var resultTo = readb();

    writeVariable(resultTo, (operands[0].value & operands[1].value));
  }

  void sub(){
    Debugger.verbose('${pcHex(-1)} [sub]');

    var operands = mem.loadb(pc - 1) < 193
        ? this.visitOperandsLongForm()
        : this.visitOperandsVar(2, false);

    var resultTo = readb();

    var result = toSigned(operands[0].value) - toSigned(operands[1].value);
    Debugger.verbose('    >>> (sub ${pc.toRadixString(16)}) ${operands[0].value}(${toSigned(operands[0].value)}) - ${operands[1].value}(${toSigned(operands[1].value)}) = $result');
    writeVariable(resultTo, result);
  }

  void add(){
    Debugger.verbose('${pcHex(-1)} [add]');

    var operands = mem.loadb(pc - 1) < 193
        ? this.visitOperandsLongForm()
        : this.visitOperandsVar(2, false);

    var resultTo = readb();

    var result = toSigned(operands[0].value) + toSigned(operands[1].value);

    Debugger.verbose('    >>> (add ${pc.toRadixString(16)}) ${operands[0].value}(${toSigned(operands[0].value)}) + ${operands[1].value}(${toSigned(operands[1].value)}) = $result');

    writeVariable(resultTo, result);
  }

  void mul(){
    Debugger.verbose('${pcHex(-1)} [mul]');

    var operands = mem.loadb(pc - 1) < 193
        ? this.visitOperandsLongForm()
        : this.visitOperandsVar(2, false);

    var resultTo = readb();

    var result = toSigned(operands[0].value) * toSigned(operands[1].value);

    Debugger.verbose('    >>> (mul ${pc.toRadixString(16)}) ${operands[0].value}(${toSigned(operands[0].value)}) * ${operands[1].value}(${toSigned(operands[1].value)}) = $result');

    writeVariable(resultTo, result);
  }

  void div(){
    Debugger.verbose('${pcHex(-1)} [div]');

    var operands = mem.loadb(pc - 1) < 193
        ? this.visitOperandsLongForm()
        : this.visitOperandsVar(2, false);

    var resultTo = readb();

    if (operands[1].value == 0){
      throw new GameException('Divide by 0.');
    }

    var result = (toSigned(operands[0].value) / toSigned(operands[1].value)).toInt();

    Debugger.verbose('    >>> (div ${pc.toRadixString(16)}) ${operands[0].value}(${toSigned(operands[0].value)}) / ${operands[1].value}(${toSigned(operands[1].value)}) = $result');

    writeVariable(resultTo, result);
  }

  void mod(){
    Debugger.verbose('${pcHex(-1)} [mod]');

    var operands = mem.loadb(pc - 1) < 193
        ? this.visitOperandsLongForm()
        : this.visitOperandsVar(2, false);

    var resultTo = readb();

    if (operands[1].peekValue == 0){
      throw new GameException('Divide by 0.');
    }

    var x = toSigned(operands[0].value);
    var y = toSigned(operands[1].value);

    var result = x.abs() % y.abs();
    if (x < 0) result = -result;

    Debugger.verbose('    >>> (mod ${pc.toRadixString(16)}) ${operands[0].value}(${toSigned(operands[0].value)}) % ${operands[1].value}(${toSigned(operands[1].value)}) = $result');

    writeVariable(resultTo, result);
  }

  void get_prop_len(){
    Debugger.verbose('${pcHex(-1)} [get_prop_len]');

    var operand = this.visitOperandsShortForm();

    var resultTo = readb();

    var propLen = GameObject.propertyLength(operand.value - 1);
    Debugger.verbose('    (${pcHex()}) property length: $propLen , addr: 0x${operand.value.toRadixString(16)}');
    writeVariable(resultTo, propLen);
  }

  void not(){
    Debugger.verbose('${pcHex(-1)} [not]');

    var operand = this.visitOperandsShortForm();

    var resultTo = readb();

    writeVariable(resultTo, ~(operand.value));
  }

  void get_next_prop(){
    Debugger.verbose('${pcHex(-1)} [get_next_prop]');

    var operands = mem.loadb(pc - 1) < 193
        ? this.visitOperandsLongForm()
        : this.visitOperandsVar(2, false);

    var resultTo = readb();

    var obj = new GameObject(operands[0].value);

    var nextProp = obj.getNextProperty(operands[1].value);
    Debugger.verbose('    (${pcHex()}) [${obj.id}] prop: ${operands[1].value} next prop:  ${nextProp}');
    writeVariable(resultTo, nextProp);
  }

  void get_prop_addr(){
    Debugger.verbose('${pcHex(-1)} [get_prop_addr]');

    var operands = mem.loadb(pc - 1) < 193
        ? this.visitOperandsLongForm()
        : this.visitOperandsVar(2, false);

    var resultTo = readb();

    var obj = new GameObject(operands[0].value);

    var addr = obj.getPropertyAddress(operands[1].value);

    Debugger.verbose('    (${pc.toRadixString(16)}) [${obj.id}] propAddr(${operands[1].value}): ${addr.toRadixString(16)}');

    writeVariable(resultTo, addr);
  }

  void get_prop(){
    Debugger.verbose('${pcHex(-1)} [get_prop]');

    var operands = mem.loadb(pc - 1) < 193
        ? this.visitOperandsLongForm()
        : this.visitOperandsVar(2, false);

    var resultTo = readb();

    var obj = new GameObject(operands[0].value);

    var value = obj.getPropertyValue(operands[1].value);

    Debugger.verbose('    (${pc.toRadixString(16)}) [${obj.id}] getPropValue(${operands[1].value}): ${value.toRadixString(16)}');

    writeVariable(resultTo, value);
  }

  void put_prop(){
    Debugger.verbose('${pcHex(-1)} [put_prop]');

    var operands = this.visitOperandsVar(3, false);

    var obj = new GameObject(operands[0].value);

    Debugger.verbose('    (${pc.toRadixString(16)}) [${obj.id}] putProp(${operands[1].value}): ${operands[2].value.toRadixString(16)}');

    obj.setPropertyValue(operands[1].value, operands[2].value);
  }

  void loadb(){
    Debugger.verbose('${pcHex(-1)} [loadb]');

    var operands = mem.loadb(pc - 1) < 193
        ? this.visitOperandsLongForm()
        : this.visitOperandsVar(2, false);

    var resultTo = readb();

    var addr = operands[0].value + Machine.toSigned(operands[1].value);

    //Debugger.todo();
    writeVariable(resultTo, mem.loadb(addr));

    Debugger.verbose('    loaded 0x${peekVariable(resultTo).toRadixString(16)} from 0x${addr.toRadixString(16)} into 0x${resultTo.toRadixString(16)}');
  }

  void loadw(){
    Debugger.verbose('${pcHex(-1)} [loadw]');

    var operands = mem.loadb(pc - 1) < 193
        ? this.visitOperandsLongForm()
        : this.visitOperandsVar(2, false);

    var resultTo = readb();

    var addr = operands[0].value + 2 * Machine.toSigned(operands[1].value);

//    assert(addr <= mem.highMemAddress);

    writeVariable(resultTo, mem.loadw(addr));
    Debugger.verbose('    loaded 0x${peekVariable(resultTo).toRadixString(16)} from 0x${addr.toRadixString(16)} into 0x${resultTo.toRadixString(16)}');
  }



  void storebv(){
    Debugger.verbose('${pcHex(-1)} [storebv]');

    var operands = this.visitOperandsVar(3, false);

    if (operands.length != 3){
      throw new GameException('Expected operand count of 3 for storeb instruction.');
    }

    var addr = operands[0].value + Machine.toSigned(operands[1].value);
//
//    assert(operands[2].value <= 0xff);

    mem.storeb(addr, operands[2].value & 0xFF);

    Debugger.verbose('    stored 0x${operands[2].value.toRadixString(16)} at addr: 0x${addr.toRadixString(16)}');
  }


  //variable arguement version of storew
  void storewv(){
    Debugger.verbose('${pcHex(-1)} [storewv]');

    var operands = this.visitOperandsVar(3, false);

    //(ref http://www.gnelson.demon.co.uk/zspec/sect15.html#storew)
    var addr = operands[0].value + 2 * Machine.toSigned(operands[1].value);

    assert(addr <= mem.highMemAddress);

    mem.storew(addr, operands[2].value);

    Debugger.verbose('    stored 0x${operands[2].value.toRadixString(16)} at addr: 0x${addr.toRadixString(16)}');
  }



  Operand visitOperandsShortForm(){
    var oc = mem.loadb(pc - 1);

    //(ref 4.4.1)
    var operand = new Operand((oc & 48) >> 4);

    if (operand.type == OperandType.LARGE){
      operand.rawValue = readw();
    }else{
      operand.rawValue = readb();
    }
    Debugger.verbose('    ${operand}');
    return operand;
  }

  List<Operand> visitOperandsLongForm(){
    var oc = mem.loadb(pc - 1);

    var o1 = BinaryHelper.isSet(oc, 6)
        ? new Operand(OperandType.VARIABLE) : new Operand(OperandType.SMALL);

    var o2 = BinaryHelper.isSet(oc, 5)
        ? new Operand(OperandType.VARIABLE) : new Operand(OperandType.SMALL);

    o1.rawValue = readb();
    o2.rawValue = readb();

    Debugger.verbose('    ${o1}, ${o2}');

    return [o1, o2];
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

  void visitHeader(){
    mem.abbrAddress = mem.loadw(Header.ABBREVIATIONS_TABLE_ADDR);
    mem.objectsAddress = mem.loadw(Header.OBJECT_TABLE_ADDR);
    mem.globalVarsAddress = mem.loadw(Header.GLOBAL_VARS_TABLE_ADDR);
    mem.staticMemAddress = mem.loadw(Header.STATIC_MEM_BASE_ADDR);
    mem.dictionaryAddress = mem.loadw(Header.DICTIONARY_ADDR);
    mem.highMemAddress = mem.loadw(Header.HIGHMEM_START_ADDR);

    //initialize the game dictionary
    mem.dictionary = new Dictionary();

    mem.programStart = mem.loadw(Header.PC_INITIAL_VALUE_ADDR);
    pc = mem.programStart;

    Debugger.verbose(Debugger.dumpHeader());
  }

  /** Reads 1 byte from the current program counter
  * address and advances the program counter to the next
  * unread address.
  */
  int readb(){
    return mem.loadb(pc++);
  }

  /** Reads 1 word from the current program counter
  * address and advances the program counter to the next
  * unread address.
  */
  int readw(){
    pc += 2;
    return mem.loadw(pc - 2);
  }

  int peekVariable(int varNum){
    if (varNum == 0x00){
      //top of stack
      var result = stack.peek();
      return result;
    }else if (varNum <= 0x0f){
      return _readLocal(varNum);
    }else if (varNum <= 0xff){
      return mem.readGlobal(varNum);
    }else{
      return varNum;
      throw new Exception('Variable referencer byte'
        ' out of range (0-255): ${varNum}');
    }
  }

  int readVariable(int varNum){
    if (varNum == 0x00){
      //top of stack
      var result = stack.pop();
      assertNotMarker(result);
      Debugger.verbose('    (popped 0x${result.toRadixString(16)} from stack)');
      return result;
    }else if (varNum <= 0x0f){
      return _readLocal(varNum);
    }else if (varNum <= 0xff){
      return mem.readGlobal(varNum);
    }else{
      return varNum;
      Debugger.verbose('${mem.getRange(pc - 10, 20)}');
      throw new Exception('Variable referencer byte out'
        ' of range (0-255): ${varNum}');
    }
  }

  void writeVariable(int varNum, int value){
    if (varNum == 0x00){
      //top of stack
      Debugger.verbose('    (pushed 0x${value.toRadixString(16)} to stack)');
      stack.push(value);
    }else if (varNum <= 0x0f){
      Debugger.verbose('    (wrote 0x${value.toRadixString(16)}'
      ' to local 0x${varNum.toRadixString(16)})');
      _writeLocal(varNum, value);
    }else if (varNum <= 0xff){
      Debugger.verbose('    (wrote 0x${value.toRadixString(16)}'
      ' to global 0x${varNum.toRadixString(16)})');
      mem.writeGlobal(varNum, value);
    }else{
      throw new GameException('Variable referencer byte out of range (0-255)');
    }
 }

  void _writeLocal(int local, int value){
    var locals = callStack[2];

    if (locals < local){
      throw new GameException('Attempted to access unallocated local variable.');
    }

    var index = locals - local;

    if (index == -1){
      Debugger.verbose('locals: $locals, local: $local');
      throw new GameException('bad index');
    }

    callStack[index + 3] = value;
  }

  int _readLocal(int local){
    var locals = callStack[2]; //locals header

    if (locals < local){
      throw new GameException('Attempted to access unallocated local variable.');
    }

    var index = locals - local;

    return callStack[index + 3];
  }

  Machine()
  :
    stack = new _Stack(),
    callStack = new _Stack.max(1024)
  {
    r = new DRandom.withSeed(new Date.now().milliseconds);
    ops =
      {

        /* 2OP, small, small */
        '1' : je,
        '2' : jl,
        '3' : jg,
        '4' : dec_chk,
        '5' : inc_chk,
        '6' : jin,
        '7' : test,
        '8' : or,
        '9' : and,
        '10' : test_attr,
        '11' : set_attr,
        '12' : clear_attr,
        '13' : store,
        '14' : insert_obj,
        '15' : loadw,
        '16' : loadb,
        '17' : get_prop,
        '18' : get_prop_addr,
        '19' : get_next_prop,
        '20' : add,
        '21' : sub,
        '22' : mul,
        '23' : div,
        '24' : mod,
        /* 25 : call_2s */
        '25' : notFound,
        /* 26 : call_2n */
        '26' : notFound,
        /* 27 : set_colour */
        '27' : notFound,
        /* 28 : throw */
        '28' : notFound,


        /* 2OP, small, variable */
        '33' : je,
        '34' : jg,
        '35' : jl,
        '36' : dec_chk,
        '37' : inc_chk,
        '38' : jin,
        '39' : test,
        '40' : or,
        '41' : and,
        '42' : test_attr,
        '43' : set_attr,
        '44' : clear_attr,
        '45' : store,
        '46' : insert_obj,
        '47' : loadw,
        '48' : loadb,
        '49' : get_prop,
        '50' : get_prop_addr,
        '51' : get_next_prop,
        '52' : add,
        '53' : sub,
        '54' : mul,
        '55' : div,
        '56' : mod,
        /* 57 : call_2s */
        '57' : notFound,
        /* 58 : call_2n */
        '58' : notFound,
        /* 59 : set_colour */
        '59' : notFound,
        /* 60 : throw */
        '60' : notFound,

        /* 2OP, variable, small */
        '65' : je,
        '66' : jl,
        '67' : jg,
        '68' : dec_chk,
        '69' : inc_chk,
        '70' : jin,
        '71' : test,
        '72' : or,
        '73' : and,
        '74' : test_attr,
        '75' : set_attr,
        '76' : clear_attr,
        '77' : store,
        '78' : insert_obj,
        '79' : loadw,
        '80' : loadb,
        '81' : get_prop,
        '82' : get_prop_addr,
        '83' : get_next_prop,
        '84' : add,
        '85' : sub,
        '86' : mul,
        '87' : div,
        '88' : mod,
        /* 89 : call_2s */
        '89' : notFound,
        /* 90 : call_2n */
        '90' : notFound,
        /* 91 : set_colour */
        '91' : notFound,
        /* 92 : throw */
        '92' : notFound,

        /* 2OP, variable, variable */
        '97' : je,
        '98' : jl,
        '99' : jg,
        '100' : dec_chk,
        '101' : inc_chk,
        '102' : jin,
        '103' : test,
        '104' : or,
        '105' : and,
        '106' : test_attr,
        '107' : set_attr,
        '108' : clear_attr,
        '109' : store,
        '110' : insert_obj,
        '111' : loadw,
        '112' : loadb,
        '113' : get_prop,
        '114' : get_prop_addr,
        '115' : get_next_prop,
        '116' : add,
        '117' : sub,
        '118' : mul,
        '119' : div,
        '120' : mod,
        /* 121 : call_2s */
        '121' : notFound,
        /* 122 : call_2n */
        '122' : notFound,
        /* 123 : set_colour */
        '123' : notFound,
        /* 124 : throw */
        '124' :notFound,

        /* 1OP, large */
        '128' : jz,
        '129' : get_sibling,
        '130' : get_child,
        '131' : get_parent,
        '132' : get_prop_len,
        '133' : inc,
        '134' : dec,
        '135' : print_addr,
        /* 136 : call_1s */
        '136' : notFound,
        '137' : remove_obj,
        '138' : print_obj,
        '139' : ret,
        '140' : jump,
        '141' : print_paddr,
        '142' : load,
        '143' : not,

        /*** 1OP, small ***/
        '144' : jz,
        '145' : get_sibling,
        '146' : get_child,
        '147' : get_parent,
        '148' : get_prop_len,
        '149' : inc,
        '150' : dec,
        '151' : print_addr,
        /* 152 : call_1s */
        '152' : notFound,
        '153' : remove_obj,
        '154' : print_obj,
        '155' : ret,
        '156' : jump,
        '157' : print_paddr,
        '158' : load,
        '159' : not,

        /*** 1OP, variable ***/
        '160' : jz,
        '161' : get_sibling,
        '162' : get_child,
        '163' : get_parent,
        '164' : get_prop_len,
        '165' : inc,
        '166' : dec,
        '167' : print_addr,
        /* 168 : call_1s */
        '168' : notFound,
        '169' : remove_obj,
        '170' : print_obj,
        '171' : ret,
        '172' : jump,
        '173' : print_paddr,
        '174' : load,
        '175' : not,

        /* 0 OP */
        '176' : rtrue,
        '177' : rfalse,
        '178' : printf,
        '179' : print_ret,
        '180' : nop,
        '181' : save,
        '182' : restore,
        '183' : restart,
        '184' : ret_popped,
        '185' : pop,
        '186' : quit,
        '187' : newline,
        '188' : show_status,
        '189' : verify,
        /* 190 : extended */
        '190' : notFound,
        '191' : piracy,

        /* 2OP, Variable of op codes 1-31 */
        '193' : jeV,
        '194' : jl,
        '195' : jg,
        '196' : dec_chk,
        '197' : inc_chk,
        '198' : jin,
        '199' : test,
        '200' : or,
        '201' : and,
        '202' : test_attr,
        '203' : set_attr,
        '204' : clear_attr,
        '205' : store,
        '206' : insert_obj,
        '207' : loadw,
        '208' : loadb,
        '209' : get_prop,
        '210' : get_prop_addr,
        '211' : get_next_prop,
        '212' : add,
        '213' : sub,
        '214' : mul,
        '215' : div,
        '216' : mod,
        /* 217 : call_2sV */
        '217' : notFound,
        /* 218 : call_2nV */
        '218' : notFound,
        /* 219 : set_colourV */
        '219' : notFound,
        /* 220 : throwV */
        '220' : notFound,

        /* xOP, Operands Vary */
        '224' : callVS,
        '225' : storewv,
        '226' : storebv,
        '227' : put_prop,
        '228' : read,
        '229' : print_char,
        '230' : print_num,
        '231' : random,
        '232' : push,
        '233' : pull,
        /* 234 : split_window */
        '234' : notFound,
        /* 235 : set_window */
        '235' : notFound,
        /* 236 : call_vs2 */
        '236' : notFound,
        /* 237 : erase_window */
        '237' : notFound,
        /* 238 : erase_line */
        '238' : notFound,
        /* 239 : set_cursor */
        '239' : notFound,
        /* 240 : get_cursor */
        '240' : notFound,
        /* 241 : set_text_style */
        '241' : notFound,
        /* 242 : buffer_mode_flag */
        '242' : notFound,
        /* 243 : output_stream */
        '243' : notFound,
        /* 244 : input_stream */
        '244' : notFound,
        /* 245 : sound_effect */
        '245' : notFound,
        /* 246 : read_char */
        '246' : notFound,
        /* 247 : scan_table */
        '247' : notFound,
        /* 248 : not */
        '248' : notFound,
        /* 249 : call_vn */
        '249' : notFound,
        /* 250 : call_vn2 */
        '250' : notFound,
        /* 251 : tokenise */
        '251' : notFound,
        /* 252 : encode_text */
        '252' : notFound,
        /* 253 : copy_table */
        '253' : notFound,
        /* 254 : print_table */
        '254' : notFound,
        /* 255 : check_arg_count */
        '255' : notFound
      };
  }
}
