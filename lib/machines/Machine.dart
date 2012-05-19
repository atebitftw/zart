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

  final _Stack stack;
  final _Stack callStack;

  DRandom r;

  /// Z-Machine Program Counter
  int pc = 0;

  _MemoryMap mem;

  Map<String, Function> ops;

  int get propertyDefaultsTableSize() => 31;



  Machine()
  :
    stack = new _Stack(),
    callStack = new _Stack.max(1024)
  {
    r = new DRandom.withSeed(new Date.now().milliseconds);
    ops =
      {
       '183' : restart,
       '231' : random,
       '232' : push,
       '233' : pull,
       '224' : callVS,
       '225' : storewv,
       '79' : loadw,
       '15' : loadw,
       '47' : loadw,
       '111' : loadw,
       '10' : test_attr,
       '42' : test_attr,
       '74' : test_attr,
       '106' : test_attr,
       '11' : set_attr,
       '43' : set_attr,
       '75' : set_attr,
       '107' : set_attr,
       '12' : clear_attr,
       '44' : clear_attr,
       '76' : clear_attr,
       '108' : clear_attr,
       '13' : store,
       '45' : store,
       '77' : store,
       '109' : store,
       '205' : storev,
       '16' : loadb,
       '48' : loadb,
       '80' : loadb,
       '112' : loadb,
       '226' : storebv,
       '17' : get_prop,
       '49' : get_prop,
       '81' : get_prop,
       '113' : get_prop,
       '18' : get_prop_addr,
       '50' : get_prop_addr,
       '82' : get_prop_addr,
       '114' : get_prop_addr,
       '19' : get_next_prop,
       '51' : get_next_prop,
       '83' : get_next_prop,
       '115' : get_next_prop,
       '14' : insertObj,
       '46' : insertObj,
       '78' : insertObj,
       '110' : insertObj,
       '20' : add,
       '52' : add,
       '84' : add,
       '116' : add,
       '21' : sub,
       '53' : sub,
       '85' : sub,
       '117' : sub,
       '22' : mul,
       '54' : mul,
       '86' : mul,
       '118' : mul,
       '23' : div,
       '55' : div,
       '87' : div,
       '119' : div,
       '24' : mod,
       '56' : mod,
       '88' : mod,
       '120' : mod,
       '5' : inc_chk,
       '37' : inc_chk,
       '69' : inc_chk,
       '101' : inc_chk,
       '197' : inc_chkV,
       '4' : dec_chk,
       '36' : dec_chk,
       '68' : dec_chk,
       '100' : dec_chk,
       '6' : jin,
       '38' : jin,
       '70' : jin,
       '102' : jin,
       '7' : test,
       '39' : test,
       '71' : test,
       '103' : test,
       '1' : je,
       '33' : je,
       '65' : je,
       '97' : je,
       '2' : jl,
       '35' : jl,
       '66' : jl,
       '98' : jl,
       '3' : jg,
       '34' : jg,
       '67' : jg,
       '99' : jg,
       '195' : jgv,
       '193' : jeV,
       '140' : jump,
       '156' : jump,
       '130' : get_child,
       '146' : get_child,
       '162' : get_child,
       '131' : get_parent,
       '147' : get_parent,
       '163' : get_parent,
       '132' : get_prop_len,
       '148' : get_prop_len,
       '164' : get_prop_len,
       '161' : get_sibling,
       '145' : get_sibling,
       '129' : get_sibling,
       '160' : jz,
       '144' : jz,
       '128' : jz,
       '139' : ret,
       '155' : ret,
       '171' : ret,
       '133' : inc,
       '149' : inc,
       '165' : inc,
       '134' : dec,
       '150' : dec,
       '166' : dec,
       '135' : print_addr,
       '151' : print_addr,
       '167' : print_addr,
       '141' : print_paddr,
       '157' : print_paddr,
       '173' : print_paddr,
       '178' : printf,
       '179' : print_ret,
       '187' : newline,
       '201' : andV,
       '9' : and,
       '41' : and,
       '73' : and,
       '105' : and,
       '230' : print_num,
       '229' : print_char,
       '176' : rtrue,
       '177' : rfalse,
       '138' : print_obj,
       '154' : print_obj,
       '170' : print_obj,
       '184' : ret_popped,
       '227' : put_prop,
       '228' : read,
       '174' : load,
       '142' : load
      };
  }

  ZVersion get version() => ZVersion.V1;

  // Kb
  int get maxFileLength() => 128;

  int unpack(int packedAddr){
    return packedAddr * 2;
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

    if (locals > 0){
      for(int i = 1; i <= locals; i++){
        if (i <= params.length){
          //if param avail, store it
          mem.storew(pc, params[i - 1]);
        }

        //push local to call stack
        callStack.push(mem.loadw(pc));

        Debugger.verbose('    Local ${i}: 0x${mem.loadw(pc).toRadixString(16)}');

        pc += 2;
      }
    }

    //push total locals onto the call stack
    callStack.push(locals);
  }

  void callVS(){
    Debugger.verbose('  [call_vs]');
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

    //unwind game stack
    var gs = stack.pop();

    while(gs != STACK_MARKER){
      gs = stack.pop();
    }

    writeVariable(resultAddrByte, result);

    pc = returnAddr;
  }

  void visitInstruction(foo){
    var i = readb();
    if (ops.containsKey('$i')){
      if (Debugger.enableDebug){
        if (Debugger.enableTrace && !Z.dynamic.inBreak){
          if (opCodes.containsKey('$i')){
            Debugger.debug('>>> (0x${(pc - 1).toRadixString(16)}) ${opCodes[i.toString()]} ($i)');
          }else{
            Debugger.debug('>>> (0x${(pc - 1).toRadixString(16)}) UNKNOWN ($i)');
          }
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
      throw new GameException('Unsupported Op Code: $i');
    }

   // Z._runIt(null);
  }

  void branch(bool testResult)
  {
    var jumpByte = readb();

    bool branchOn = BinaryHelper.isSet(jumpByte, 7);

    if (testResult == null || testResult is! bool){
      throw new GameException('Test function must return a boolean value.');
    }

    var offset = _jumpToLabelOffset(jumpByte);

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

  String getStatusJSON(){

    var statusList = new List<String>();

    statusList.add('STATUS');
    statusList.add(Header.isScoreGame() ? 'SCORE' : 'TIME');

    var locObject = new GameObjectV3(readVariable(0x10));
    statusList.add(locObject.shortName);

    statusList.add(readVariable(0x11).toString());
    statusList.add(readVariable(0x12).toString());

    return JSON.stringify(statusList);
  }

  void read(){
    Debugger.verbose('  [read]');

    Z.inInput = true;

    Z._printBuffer();

    Z.sbuff.add(getStatusJSON());

    Z._printBuffer();

    var operands = this.visitOperandsVar(4, true);

    var maxBytes = mem.loadb(operands[0].value);

    var textBuffer = operands[0].value + 1;

    var maxWords = mem.loadb(operands[1].value);

    var parseBuffer = operands[1].value + 1;

    void processLine(String line){
      line = line.trim().toLowerCase();

      Debugger.verbose('    (processing: "$line")');

      if (line.length > maxBytes){
        line = line.substring(0, maxBytes - 1);
        Debugger.verbose('    (text buffer truncated to "$line")');
      }

      var zChars = ZSCII.toZCharList(line);

      //store the zscii chars in text buffer
      for(final c in zChars){
        mem.storeb(textBuffer++, c);
      }

      //terminator
      mem.storeb(textBuffer, 0);

      var tokens = Z._machine.mem.dictionary.tokenize(line);

      Debugger.verbose('    (tokenized: $tokens)');

      if (tokens.length >  maxWords){
        tokens = tokens.getRange(0, maxWords - 1);
        Debugger.verbose('    (truncating parse buffer to: $tokens)');
      }

      var parsed = Z._machine.mem.dictionary.parse(tokens, line);
      //Debugger.debug('$parsed');

      for(final p in parsed){
        mem.storeb(parseBuffer++, p);
      }

//      Z._io.callAsync(Z._runIt);
    }

    Future<String> line = Z._io.getLine();

    doIt(foo){
      if (line.isComplete){
        Z.inInput = false;
        if (line == '/!'){
          Z.inBreak = true;
//          Z._io.callAsync(Debugger.startBreak);
        }else{
          processLine(line.value);
        }
      }else{
        line.then((String l){
          Z.inInput = false;
          if (l == '/!'){
            Z.inBreak = true;
            Debugger.debugStartAddr = pc - 1;
            Debugger.startBreak(null);
//            Z._io.callAsync(Debugger.startBreak);
          }else{
            processLine(l);
            Z._runIt(null);
          }
        });
      }
    }

    doIt(null);

//    Z._io.callAsync(doIt);
  }

  void random(){
    Debugger.verbose('  [random]');

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
      result = r.NextFromMax(range + 1);
      Debugger.verbose('Rolled random number $result');
    }

    writeVariable(resultTo, result);
  }

  void pull(){
    Debugger.verbose('  [pull]');
    var operand = this.visitOperandsVar(1, false);

    var value = stack.pop();

    Debugger.verbose('    Pulling 0x${value.toRadixString(16)} from to the stack.');

    writeVariable(operand[0].value, value);
  }

  void push(){
    Debugger.verbose('  [push]');
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
    Debugger.verbose('  [ret_popped]');
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
    Debugger.verbose('  [rtrue]');
    callStack.push(Machine.TRUE);
    doReturn();
  }

  void rfalse(){
    Debugger.verbose('  [rfalse]');
    callStack.push(Machine.FALSE);
    doReturn();
  }

  void jz(){
    Debugger.verbose('  [jz]');
    var operand = this.visitOperandsShortForm();

    branch(operand.value == 0);
  }

  void get_sibling(){
    Debugger.verbose('  [get_sibling]');

    var operand = this.visitOperandsShortForm();

    var resultTo = readb();

    GameObjectV3 obj = new GameObjectV3(operand.value);

    writeVariable(resultTo, obj.sibling);

    branch(obj.sibling != 0);
  }

  void get_child(){
    Debugger.verbose('  [get_child]');

    var operand = this.visitOperandsShortForm();

    var resultTo = readb();

    GameObjectV3 obj = new GameObjectV3(operand.value);

    writeVariable(resultTo, obj.child);

    branch(obj.child != 0);
  }

  void inc(){
    Debugger.verbose('  [inc]');

    var operand = this.visitOperandsShortForm();

    var value = _toSigned(readVariable(operand.rawValue)) + 1;

    writeVariable(operand.rawValue, value);

  }

  void dec(){
    Debugger.verbose('  [dec]');

    var operand = this.visitOperandsShortForm();

    var value = _toSigned(readVariable(operand.rawValue)) - 1;

    writeVariable(operand.rawValue, value);
  }

  void load(){
    Debugger.verbose('  [load]');

    var operand = this.visitOperandsShortForm();

    var resultTo = readb();

    var v = readVariable(operand.value);

    writeVariable(resultTo, v);
  }

  void test(){
    Debugger.verbose('  [test]');

    var operands = this.visitOperandsLongForm();

    branch(((operands[0].value) & (operands[1].value)) == operands[1].value);
  }

  void dec_chk(){
    Debugger.verbose('  [dec_chk]');

    var operands = this.visitOperandsLongForm();

    var value = _toSigned(readVariable(operands[0].rawValue)) - 1;

    //(ref http://www.gnelson.demon.co.uk/zspec/sect14.html notes #5)
    writeVariable(operands[0].rawValue, value);

    branch(value < _toSigned(operands[1].value));
  }

  void inc_chkV(){
    Debugger.verbose('  [inc_chk]');

    var operands = this.visitOperandsVar(2, false);

    var value = _toSigned(readVariable(operands[0].rawValue)) + 1;

    //(ref http://www.gnelson.demon.co.uk/zspec/sect14.html notes #5)
    writeVariable(operands[0].rawValue, value);

    branch(value > _toSigned(operands[1].value));
  }

  void inc_chk(){
    Debugger.verbose('  [inc_chk]');

    var operands = this.visitOperandsLongForm();

    var value = _toSigned(readVariable(operands[0].rawValue)) + 1;

    //(ref http://www.gnelson.demon.co.uk/zspec/sect14.html notes #5)
    writeVariable(operands[0].rawValue, value);

    branch(value > _toSigned(operands[1].value));
  }

  void test_attr(){
    Debugger.verbose('  [test_attr]');

    var operands = this.visitOperandsLongForm();

    GameObjectV3 obj = new GameObjectV3(operands[0].value);

    branch(obj.isFlagBitSet(operands[1].value));
  }

  void jin()  {
    Debugger.verbose('  [jin]');

    var operands = this.visitOperandsLongForm();

    var child = new GameObjectV3(operands[0].value);
    var parent = new GameObjectV3(operands[1].value);

    branch(child.parent == parent.id);
  }

  void jeV(){
    Debugger.verbose('  [jeV]');
    var operands = this.visitOperandsVar(4, true);

    if (operands.length < 2){
      throw new GameException('At least 2 operands required for jeV instruction.');
    }

    var foundMatch = false;

    var testVal = _toSigned(operands[0].value);

    for(int i = 1; i < operands.length; i++){
      if (foundMatch == true) break;
      var against = _toSigned(operands[i].value);

      if (testVal == against){
        foundMatch = true;
      }
    }

    branch(foundMatch);
  }

  void restart(){
    Debugger.verbose('  [restart]');

    Z.softReset();

    // visit the main 'routine'
    visitRoutine([]);

    //push dummy result store onto the call stack
    callStack.push(0);

    //push dummy return address onto the call stack
    callStack.push(0);

    Z._io.callAsync(Z._runIt);
  }

  void jl(){
    Debugger.verbose('  [jl]');
    var operands = visitOperandsLongForm();

    branch(_toSigned(operands[0].value) < _toSigned(operands[1].value));
  }

  void jgv(){
    Debugger.verbose('  [jgv]');
    var operands = this.visitOperandsVar(2, false);

    branch(_toSigned(operands[0].value) > _toSigned(operands[1].value));
  }

  void jg(){
    Debugger.verbose('  [jg]');
    var operands = this.visitOperandsLongForm();

    branch(_toSigned(operands[0].value) > _toSigned(operands[1].value));
  }

  void je(){
    Debugger.verbose('  [je]');
    var operands = this.visitOperandsLongForm();

    branch(_toSigned(operands[0].value) == _toSigned(operands[1].value));
  }

  void newline(){
    Debugger.verbose('  [newline]');

    Z._printBuffer();
  }

  void print_obj(){
    Debugger.verbose('  [print_obj]');
    var operand = this.visitOperandsShortForm();

    var obj = new GameObjectV3(operand.value);

    Z.sbuff.add(obj.shortName);
  }

  void print_addr(){
    Debugger.verbose('  [print_addr]');
    var operand = this.visitOperandsShortForm();

    var addr = operand.value;

    Z.sbuff.add(ZSCII.readZStringAndPop(addr));
  }

  void print_paddr(){
    Debugger.verbose('  [print_paddr]');

    var operand = this.visitOperandsShortForm();

    var addr = this.unpack(operand.value);

    Z.sbuff.add(ZSCII.readZStringAndPop(addr));
  }

  void print_char(){
    Debugger.verbose('  [print_char]');

    var operands = this.visitOperandsVar(1, false);

    var z = operands[0].value;

    if (z < 0 || z > 1023){
      throw new GameException('ZSCII char is out of bounds.');
    }

    Z.sbuff.add(ZSCII.ZCharToChar(z));
  }

  void print_num(){
    Debugger.verbose('  [print_num]');

    var operands = this.visitOperandsVar(1, false);

    Z.sbuff.add('${_toSigned(operands[0].value)}');
  }

  void print_ret(){
    Debugger.verbose('  [print_ret]');

    Z.sbuff.add('${ZSCII.readZStringAndPop(pc)}\n');

    callStack.push(Machine.TRUE);

    doReturn();
  }

  void printf(){
    Debugger.verbose('  [print]');

    Z.sbuff.add(ZSCII.readZString(pc));

    pc = callStack.pop();
  }

  void insertObj(){
    Debugger.verbose('  [insert_obj]');

    var operands = this.visitOperandsLongForm();

    GameObjectV3 from = new GameObjectV3(operands[0].value);

    GameObjectV3 to = new GameObjectV3(operands[1].value);

    Debugger.verbose('Insert Object ${from.id}(${from.shortName}) into ${to.id}(${to.shortName})');

    from.insertTo(to.id);
  }

  void removeObj(){
    Debugger.verbose('  [remove_obj]');
    var operand = this.visitOperandsShortForm();

    GameObjectV3 o = new GameObjectV3(operand.value);

    Debugger.verbose('Removing Object ${o.id}(${o.shortName}) from object tree.');
    o.removeFromTree();
  }

  void storev(){
    Debugger.verbose('  [storev]');

    var operands = this.visitOperandsVar(2, false);

    writeVariable(operands[0].rawValue, operands[1].value);
  }

  void store(){
    Debugger.verbose('  [store]');

    var operands = this.visitOperandsLongForm();

    writeVariable(operands[0].rawValue, operands[1].value);
 }

  void jump(){
    Debugger.verbose('  [jump]');

    var operand = this.visitOperandsShortForm();

    var offset = _toSigned(operand.value) - 2;

    pc += offset;
  }


  void ret(){
    Debugger.verbose('  [ret]');
    var operand = this.visitOperandsShortForm();

    Debugger.verbose('    returning 0x${operand.peekValue.toRadixString(16)}');

    callStack.push(operand.value);

    doReturn();
  }

  void get_parent(){
    Debugger.verbose('  [get_parent]');

    var operand = this.visitOperandsShortForm();

    var resultTo = readb();

    GameObjectV3 obj = new GameObjectV3(operand.value);

    writeVariable(resultTo, obj.parent);

  }

  void clear_attr(){
    Debugger.verbose('  [clear_attr]');
    var operands = this.visitOperandsLongForm();

    GameObjectV3 obj = new GameObjectV3(operands[0].value);

    obj.unsetFlagBit(operands[1].value);

  }

  void set_attr(){
    Debugger.verbose('  [set_attr]');
    var operands = this.visitOperandsLongForm();

    GameObjectV3 obj = new GameObjectV3(operands[0].value);

    obj.setFlagBit(operands[1].value);

  }

  void andV(){
    Debugger.verbose('  [andV]');
    var operands = this.visitOperandsVar(2, false);

    var resultTo = readb();

    writeVariable(resultTo, operands[0].value & operands[1].value);
  }

  void orV(){
    Debugger.verbose('  [orV]');

    var operands = this.visitOperandsVar(2, false);

    var resultTo = readb();

    writeVariable(resultTo, operands[0].value | operands[1].value);
  }

  void or(){
    Debugger.verbose('  [or]');

    var operands = this.visitOperandsLongForm();

    var resultTo = readb();

    writeVariable(resultTo, operands[0].value | operands[1].value);
  }

  void and(){
    Debugger.verbose('  [and]');

    var operands = this.visitOperandsLongForm();

    var resultTo = readb();

    writeVariable(resultTo, operands[0].value & operands[1].value);
  }

  void sub(){
    Debugger.verbose('  [subtract]');
    var operands = this.visitOperandsLongForm();
    var resultTo = readb();

    writeVariable(resultTo, _toSigned(operands[0].value) - _toSigned(operands[1].value));
  }

  void add(){
    Debugger.verbose('  [add]');
    var operands = this.visitOperandsLongForm();
    var resultTo = readb();

    writeVariable(resultTo, _toSigned(operands[0].value) + _toSigned(operands[1].value));
  }

  void mul(){
    Debugger.verbose('  [mul]');
    var operands = this.visitOperandsLongForm();
    var resultTo = readb();

    writeVariable(resultTo, _toSigned(operands[0].value) * _toSigned(operands[1].value));
  }

  void div(){
    Debugger.verbose('  [div]');
    var operands = this.visitOperandsLongForm();
    var resultTo = readb();

    if (operands[1].peekValue == 0){
      throw new GameException('Divide by 0.');
    }

    var result = (_toSigned(operands[0].value) / _toSigned(operands[1].value)).toInt();

    if (result < 0){
      result = -(result.abs().floor());
    }else{
      result = result.floor();
    }


    writeVariable(resultTo, result);
  }

  void mod(){
    Debugger.verbose('  [mod]');
    var operands = this.visitOperandsLongForm();
    var resultTo = readb();

    if (operands[1].peekValue == 0){
      throw new GameException('Divide by 0.');
    }

    var f = _toSigned(operands[0].value);
    var s = _toSigned(operands[1].value);

    var result = (f.abs()) % (s.abs());

    if (f < 0) result = -result;

    writeVariable(resultTo, _toSigned(operands[0].value) % _toSigned(operands[1].value));
  }

  void get_prop_len(){
    Debugger.verbose('  [get_prop_len]');

    var operand = this.visitOperandsShortForm();
    var resultTo = readb();

    var propLen = GameObjectV3.propertyLength(operand.value - 1);
//    Debugger.todo('$propLen ${operand.value.toRadixString(16)}');
    writeVariable(resultTo, propLen);
  }

  void get_next_prop(){
    Debugger.verbose('  [get_next_prop]');

    var operands = this.visitOperandsLongForm();
    var resultTo = readb();

    var obj = new GameObjectV3(operands[0].value);

    var nextProp = obj.getNextProperty(operands[1].value);

    writeVariable(resultTo, nextProp);
  }

  void get_prop_addr(){
    Debugger.verbose('  [get_prop_addr]');

    var operands = this.visitOperandsLongForm();
    var resultTo = readb();

    var obj = new GameObjectV3(operands[0].value);

    var addr = obj.getPropertyAddress(operands[1].value);

    writeVariable(resultTo, addr);
  }

  void get_prop(){
    Debugger.verbose('  [get_prop]');

    var operands = this.visitOperandsLongForm();
    var resultTo = readb();

    var obj = new GameObjectV3(operands[0].value);

    var prop = obj.getPropertyValue(operands[1].value);

    writeVariable(resultTo, prop);
  }

  void put_prop(){
    Debugger.verbose('  [put_prop]');

    var operands = this.visitOperandsVar(3, false);

    var obj = new GameObjectV3(operands[0].value);

    obj.setPropertyValue(operands[1].value, operands[2].value);
  }

  void loadb(){
    Debugger.verbose('  [loadb]');

    var operands = this.visitOperandsLongForm();

    var resultTo = readb();

    var addr = operands[0].value + _toSigned(operands[1].value);

    //Debugger.todo();
    writeVariable(resultTo, mem.loadb(addr));
    Debugger.verbose('    loaded 0x${peekVariable(resultTo).toRadixString(16)} from 0x${addr.toRadixString(16)} into 0x${resultTo.toRadixString(16)}');
  }

  void loadw(){
    Debugger.verbose('  [loadw]');

    var operands = this.visitOperandsLongForm();

    var resultTo = readb();

    var addr = operands[0].value + (2 * _toSigned(operands[1].value));

    writeVariable(resultTo, mem.loadw(addr));
    Debugger.verbose('    loaded 0x${peekVariable(resultTo).toRadixString(16)} from 0x${addr.toRadixString(16)} into 0x${resultTo.toRadixString(16)}');
  }

  void storebv(){
    Debugger.verbose('  [storebv]');

    var operands = this.visitOperandsVar(4, true);

    if (operands.length != 3){
      throw new GameException('Expected operand count of 3 for storeb instruction.');
    }

    var addr = operands[0].value + _toSigned(operands[1].value);

    if (operands[2].value > 0xff){
      throw new GameException('Attempted to store value in byte that is > 0xff');
    }

    mem.storeb(addr, operands[2].value);

    Debugger.verbose('    stored 0x${operands[2].value.toRadixString(16)} at addr: 0x${addr.toRadixString(16)}');
  }


  //variable arguement version of storew
  void storewv(){
    Debugger.verbose('  [storewv]');

    var operands = this.visitOperandsVar(3, false);

    //(ref http://www.gnelson.demon.co.uk/zspec/sect15.html#storew)
    var addr = operands[0].value + (2 * _toSigned(operands[1].value));
    mem.storew(addr, operands[2].value);
    Debugger.verbose('    stored 0x${operands[2].value.toRadixString(16)} at addr: 0x${addr.toRadixString(16)}');
  }

  int _toSigned(int val) =>
      ((val & 0x8000) != 0) ? -(65536 - val) : val;

  //calculates the local jump offset (ref 4.7)
  int _jumpToLabelOffset(int jumpByte){

    if (BinaryHelper.isSet(jumpByte, 6)){
      //single byte offset
      return BinaryHelper.bottomBits(jumpByte, 6);
    }else{
      _convertTo14BitSigned(int val){
        var sign = val & 0x2000;
        if (sign != 0)
        {
          return -(16384 - val);
        }else{
          return val;
        }
      }

      var secondByte = readb();

      var jumpWord = (BinaryHelper.bottomBits(jumpByte, 6) << 8) | secondByte;

      return _convertTo14BitSigned(jumpWord);
    }
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

    pc = mem.loadw(Header.PC_INITIAL_VALUE_ADDR);

    Debugger.verbose(Debugger.dumpHeader());
  }

  /** Reads 1 byte from the current program counter
  * address and advances the program counter to the next
  * unread address.
  */
  int readb(){
    pc++;
    return mem.loadb(pc - 1);
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
}
