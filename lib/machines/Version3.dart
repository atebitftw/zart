
/**
* Implementation of Z-Machine v3
*/
class Version3 implements IMachine
{
  Map<String, Function> ops;

  bool mainCalled = false;

  int get propertyDefaultsTableSize() => 31;

//  00 -- 31  long      2OP     small constant, small constant
//  32 -- 63  long      2OP     small constant, variable
//  64 -- 95  long      2OP     variable, small constant
//  96 -- 127  long      2OP     variable, variable
//  128 -- 143  short     1OP     large constant
//  144 -- 159  short     1OP     small constant
//  160 -- 175  short     1OP     variable
//  176 -- 191  short     0OP
//  except $be (190)  extended opcode given in next byte
//  192 -- 223  variable  2OP     (operand types in next byte)
//  224 -- 255  variable  VAR     (operand types in next byte(s))
  Version3()
  {
    ops =
      {
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
       '13' : store,
       '45' : store,
       '77' : store,
       '109' : store,
       '16' : loadb,
       '48' : loadb,
       '80' : loadb,
       '112' : loadb,
       '17' : get_prop,
       '49' : get_prop,
       '81' : get_prop,
       '113' : get_prop,
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
       '6' : jin,
       '38' : jin,
       '70' : jin,
       '102' : jin,
       '1' : je,
       '33' : je,
       '65' : je,
       '97' : je,
       '2' : jl,
       '35' : jl,
       '66' : jl,
       '98' : jl,
       '3' : jg,
       '36' : jg,
       '67' : jg,
       '99' : jg,
       '193' : jeV,
       '140' : jump,
       '165' : jump,
       '130' : get_child,
       '146' : get_child,
       '162' : get_child,
       '131' : get_parent,
       '147' : get_parent,
       '163' : get_parent,
       '161' : get_sibling,
       '145' : get_sibling,
       '129' : get_sibling,
       '160' : jz,
       '144' : jz,
       '128' : jz,
       '139' : ret,
       '155' : ret,
       '171' : ret,
       '135' : print_addr,
       '151' : print_addr,
       '167' : print_addr,
       '141' : print_paddr,
       '157' : print_paddr,
       '173' : print_paddr,
       '178' : printf,
       '187' : newline,
       '201' : andV,
       '9' : and,
       '230' : print_num,
       '229' : print_char,
       '176' : rtrue,
       '177' : rfalse,
       '138' : print_obj,
       '154' : print_obj,
       '170' : print_obj,
       '184' : ret_popped
      };
  }

  ZVersion get version() => ZVersion.V3;

  int get maxFileLength() => 128;

  int unpack(int packedAddr){
    return packedAddr * 2;
  }

  int fileLengthMultiplier() => 2;

  visitMainRoutine(){
    if (mainCalled){
      throw const Exception('Attempt to call entry routine more than once.');
    }

    mainCalled = true;

    Z.pc -= 1; //move to the main routine header;
    visitRoutine([]);

    //throw if this routine returns (it never should)
    throw const Exception('Illegal return from entry routine.');
  }

  visitRoutine(List<int> params){

    //push routine start onto the stack
    Z.callStack.push(Z.pc);

    out('  Calling Routine at ${Z.pc.toRadixString(16)}');
    var locals = Z.readb();
    out('    # Locals: ${locals}');
    if (locals > 16)
      throw const Exception('Maximum local variable allocations (16) exceeded.');

    if (locals > 0){
      for(int i = 1; i <= locals; i++){
        if (i <= params.length){
          //if param avail, store it
          Z.mem.storew(Z.pc, params[i - 1]);
        }

        //push local to call stack
        Z.callStack.push(Z.mem.loadw(Z.pc));

        out('    Local ${i}: 0x${Z.mem.loadw(Z.pc).toRadixString(16)}');

        Z.pc += 2;
      }
    }

    //push total locals onto the call stack
    Z.callStack.push(locals);

    //we are now past the routine header. start processing instructions.
    int returnVal = null;

    while(returnVal == null){
      returnVal = visitInstruction();
    }

    out('Instruction returned: 0x${returnVal.toRadixString(16)}');
    Z._unwind1();
    return returnVal;
    //TODO unwind stack frame and assign returnVal;
    todo('unwind stack and assign returnVal');
  }

  visitInstruction(){
    var i = Z.readb();
    if (ops.containsKey('$i')){
      var func = ops['$i'];
      if (Z.debug){
        if (Z.trace){
          if (opCodes.containsKey('$i')){
            print('>>> (0x${(Z.pc - 1).toRadixString(16)}) ${opCodes[i.toString()]} ($i)');          
          }else{
            print('>>> (0x${(Z.pc - 1).toRadixString(16)}) UNKNOWN ($i)');
          }
        }
        
        if (Z._breakPoints.indexOf(Z.pc - 1) != -1){
          //TODO add REPL inspection and continue
          throw const Exception('BREAK POINT');
        }
      }
      return func();
    }else{
      _throwAndDump('Unsupported Op Code: $i', 0, howMany:30);
    }
  }

  int ret_popped(){
    out('  [ret_popped]');
    return Z.stack.pop();
  }
  
  int rtrue(){
    out('  [rtrue]');
    return Z.TRUE;
  }
  
  int rfalse(){
    out('  [rfalse]');
    return Z.FALSE;
  }
  
  
  int jz(){
    out('  [jz]');
    var operand = this.visitOperandsShortForm();

    var jumpByte = Z.readb();
    bool testTrueOrFalse = BinaryHelper.isSet(jumpByte, 7);

    var offset = _jumpToLabelOffset(jumpByte);

    //if testing for true, operand must == FALSE(0)
    if (testTrueOrFalse){
      out('    [true]');
      if (operand.value == Z.FALSE){
        if (offset == Z.FALSE) return Z.FALSE;
        if (offset == Z.TRUE) return Z.TRUE;
        Z.pc += (offset - 2);
        out('    jumping to ${Z.pc.toRadixString(16)}');
        return this.visitInstruction();
      }
    }else{
      out('    [false]');
      if (operand.value == Z.TRUE){
        if (offset == Z.FALSE) return Z.FALSE;
        if (offset == Z.TRUE) return Z.TRUE;
        Z.pc += (offset - 2);
        out('    jumping to ${Z.pc.toRadixString(16)}');
        return this.visitInstruction();
      }
    }
  }
  
  int newline(){
    out('  [newline]');
    
    Z.printBuffer();
  }
  
  int print_obj(){
    out('  [print_obj');
    var operand = this.visitOperandsShortForm();
    
    var obj = new GameObjectV3(operand.value);
    
    Z.sbuff.add(obj.shortName);
  }
  
  int print_addr(){
    out('  [print_addr]');
    var operand = this.visitOperandsShortForm();
    
    var addr = operand.value;
    
    Z.sbuff.add(ZSCII.readZString(addr));
    Z.callStack.pop();
  }
  
  int print_paddr(){
    out('  [print_paddr]');
    
    var operand = this.visitOperandsShortForm();
    
    var addr = this.unpack(operand.value);
    
    Z.sbuff.add(ZSCII.readZString(addr));
    Z.callStack.pop();
  }
 
  int print_char(){
    out('  [print_char]');
      
    var operands = this.visitOperandsVar(1, false);
    
    var z = operands[0].value;
    
    if (z < 0 || z > 1023){
      throw const Exception('ZSCII char is out of bounds.');
    }

    Z.sbuff.add(ZSCII.ZCharToChar(z));
  }
  
  int print_num(){
    out('  [print_num]');
    
    var operands = this.visitOperandsVar(1, false);
    
    //TODO support signed nums (ref http://www.gnelson.demon.co.uk/zspec/sect15.html#print_num)
    
    var n = this._convertToSigned(operands[0].value);
    
    Z.sbuff.add('$n');
  }
  
  int printf(){
    out('  [print]');
    
    Z.sbuff.add(ZSCII.readZString(Z.pc));
    
    Z.pc = Z.callStack.pop();
  }
  
  int insertObj(){
    out('  [insert_obj]');
    
    var operands = this.visitOperandsLongForm();

    GameObjectV3 from = new GameObjectV3(operands[0].value);
    GameObjectV3 to = new GameObjectV3(operands[1].value);
    
    out('Insert Object ${from.id}(${from.shortName}) into ${to.id}(${to.shortName})');
    
    from.insertTo(to.id);    
  }

  int removeObj(){
    out('  [remove_obj]');
    var operand = this.visitOperandsShortForm();
    
    GameObjectV3 o = new GameObjectV3(operand.value);
    
    out('Removing Object ${o.id}(${o.shortName}) from object tree.');
    o.removeFromTree();
  }
  
  int store(){
    out('  [store]');

    var operands = this.visitOperandsLongForm();

    Z.writeVariable(operands[0].rawValue, operands[1].value);
 }

  int jump(){
    out('  [jump]');

    var operand = this.visitOperandsShortForm();

    var offset = _convertToSigned(operand.value) - 2;

    Z.pc += offset;
  }


  int ret(){
    out('  [ret]');
    var operand = this.visitOperandsShortForm();

    out('    returning 0x${operand.peekValue.toRadixString(16)}');
    return operand.value;
  }
  
  int get_parent(){
    out('  [get_parent]');
    
    var operand = this.visitOperandsShortForm();
    
    var resultTo = Z.readb();
    
    GameObjectV3 obj = new GameObjectV3(operand.value);
    
    Z.writeVariable(resultTo, obj.parent);
    
  }
  
  int get_sibling(){
    out('  [get_sibling]');
    
    var operand = this.visitOperandsShortForm();
    
    var resultTo = Z.readb();
    
    var jumpByte = Z.readb();
    
    bool testTrueOrFalse = BinaryHelper.isSet(jumpByte, 7);
    
    var offset = _jumpToLabelOffset(jumpByte);
    
    GameObjectV3 obj = new GameObjectV3(operand.value);
    
    Z.writeVariable(resultTo, obj.sibling);
    
    if (testTrueOrFalse){
      if (obj.sibling != 0){
        if (offset == Z.FALSE) return Z.FALSE;
        if (offset == Z.TRUE) return Z.TRUE;
        Z.pc += (offset - 2);
        out('    jumping to ${Z.pc.toRadixString(16)}');
        return this.visitInstruction();
      }
    }else{
      if (obj.sibling == 0){
        if (offset == Z.FALSE) return Z.FALSE;
        if (offset == Z.TRUE) return Z.TRUE;
        Z.pc += (offset - 2);
        out('    jumping to ${Z.pc.toRadixString(16)}');
        return this.visitInstruction();
      }
    }
    out('    continuing to next instruction');
  }
  
  int get_child(){
    out('  [get_child]');
    
    var operand = this.visitOperandsShortForm();
    
    var resultTo = Z.readb();
    
    var jumpByte = Z.readb();
    
    bool testTrueOrFalse = BinaryHelper.isSet(jumpByte, 7);
    
    var offset = _jumpToLabelOffset(jumpByte);
    
    GameObjectV3 obj = new GameObjectV3(operand.value);
    
    Z.writeVariable(resultTo, obj.child);
    
    if (testTrueOrFalse){
      if (obj.child != 0){
        if (offset == Z.FALSE) return Z.FALSE;
        if (offset == Z.TRUE) return Z.TRUE;
        Z.pc += (offset - 2);
        out('    jumping to ${Z.pc.toRadixString(16)}');
        return this.visitInstruction();
      }
    }else{
      if (obj.child == 0){
        if (offset == Z.FALSE) return Z.FALSE;
        if (offset == Z.TRUE) return Z.TRUE;
        Z.pc += (offset - 2);
        out('    jumping to ${Z.pc.toRadixString(16)}');
        return this.visitInstruction();
      }
    }
    out('    continuing to next instruction');
  }

  int inc_chk(){
    out('  [inc_chk]');
    
    Z.mem.storeb(Z.pc - 1, 69); //force to var/small arguement types
    
    var operands = this.visitOperandsLongForm();
    
    var jumpByte = Z.readb();
        
    bool testTrueOrFalse = BinaryHelper.isSet(jumpByte, 7);
    
    var offset = _jumpToLabelOffset(jumpByte);
    
    var value = this._convertToSigned(operands[0].value) + 1;

    Z.writeVariable(operands[0].rawValue, value);
        
    if (testTrueOrFalse){
      if (value > this._convertToSigned(operands[1].value)){
        if (offset == Z.FALSE) return Z.FALSE;
        if (offset == Z.TRUE) return Z.TRUE;
        Z.pc += (offset - 2);
        out('    jumping to ${Z.pc.toRadixString(16)}');
        return this.visitInstruction();
      }
    }else{
      if (value <= this._convertToSigned(operands[1].value)){
        if (offset == Z.FALSE) return Z.FALSE;
        if (offset == Z.TRUE) return Z.TRUE;
        Z.pc += (offset - 2);
        out('    jumping to ${Z.pc.toRadixString(16)}');
        return this.visitInstruction();
      }
    }
    
    out('    continuing to next instruction');
  }
  
  test_attr(){
    out('  [test_attr]');
    var operands = this.visitOperandsLongForm();
    
    var jumpByte = Z.readb();
    bool testTrueOrFalse = BinaryHelper.isSet(jumpByte, 7);
    
    var offset = _jumpToLabelOffset(jumpByte);
    
    GameObjectV3 obj = new GameObjectV3(operands[0].value);
    
    if (testTrueOrFalse){
      if (obj.isFlagBitSet(operands[1].value)){
        if (offset == Z.FALSE) return Z.FALSE;
        if (offset == Z.TRUE) return Z.TRUE;
        Z.pc += (offset - 2);
        out('    jumping to ${Z.pc.toRadixString(16)}');
        return this.visitInstruction();
      }
    }else{
      if (!obj.isFlagBitSet(operands[1].value)){
        if (offset == Z.FALSE) return Z.FALSE;
        if (offset == Z.TRUE) return Z.TRUE;
        Z.pc += (offset - 2);
        out('    jumping to ${Z.pc.toRadixString(16)}');
        return this.visitInstruction();
      }
    }
    
    out('    continuing to next instruction');
  }
  
  int set_attr(){
    out('  [set_attr]');
    var operands = this.visitOperandsLongForm();
    
    GameObjectV3 obj = new GameObjectV3(operands[0].value);
    
    obj.setFlagBit(operands[1].value);

  }
  
  int jin()  {
    out('  [jin]');
    
    var operands = this.visitOperandsLongForm();

    var jumpByte = Z.readb();
    bool testTrueOrFalse = BinaryHelper.isSet(jumpByte, 7);

    var offset = _jumpToLabelOffset(jumpByte);
    
    var obj1 = new GameObjectV3(operands[0].value);
    var obj2 = new GameObjectV3(operands[1].value);
    
    if (testTrueOrFalse){
      if (obj1.parent == obj2.id){
        //(ref 4.7.2)
        if (offset == Z.FALSE) return Z.FALSE;
        if (offset == Z.TRUE) return Z.TRUE;
        Z.pc += (offset - 2);
        out('    jumping to ${Z.pc.toRadixString(16)}');
        return this.visitInstruction();
      }
    }else{
      if (obj1.parent != obj2.id){
        //(ref 4.7.2)
        if (offset == Z.FALSE) return Z.FALSE;
        if (offset == Z.TRUE) return Z.TRUE;
        Z.pc += (offset - 2);
        out('    jumping to ${Z.pc.toRadixString(16)}');
        return this.visitInstruction();
      }
    }
    out('    continuing to next instruction');
  }
  
  int jeV(){
    out('  [jeV]');
    var operands = this.visitOperandsVar(4, true);
    
    var jumpByte = Z.readb();
    
    bool testTrueOrFalse = BinaryHelper.isSet(jumpByte, 7);

    var offset = _jumpToLabelOffset(jumpByte);
    
    if (operands.length < 2){
      throw const Exception('At least 2 operands required for jeV instruction.');
    }
    
    var l = operands.length;
    
    var foundMatch = false;
    for(int i = 1; i < l; i++){
      if (foundMatch == true) continue;
      if (operands[0].value == operands[i].value){
        foundMatch == true;
      }
    }
    
    //TODO refactor
    
    if (testTrueOrFalse){
      out('    [true]');
      if (foundMatch){
        //(ref 4.7.2)
        if (offset == Z.FALSE) return Z.FALSE;
        if (offset == Z.TRUE) return Z.TRUE;
        Z.pc += (offset - 2);
        out('    jumping to ${Z.pc.toRadixString(16)}');
        return this.visitInstruction();
      }
    }else{
      out('    [false]');
      if (!foundMatch){
        if (offset == Z.FALSE) return Z.FALSE;
        if (offset == Z.TRUE) return Z.TRUE;
        Z.pc += (offset - 2);
        out('    jumping to ${Z.pc.toRadixString(16)}');
        return this.visitInstruction();
      }
    }
    out('    continuing to next instruction');
  }
  
  int jl(){
    out('  [jl]');
    var operands = this.visitOperandsLongForm();

    var jumpByte = Z.readb();
    bool testTrueOrFalse = BinaryHelper.isSet(jumpByte, 7);

    var offset = _jumpToLabelOffset(jumpByte);
    
    //TODO refactor
    if (testTrueOrFalse){
      out('    [true]');
      if (this._convertToSigned(operands[0].value) < this._convertToSigned(operands[1].value)){
        //(ref 4.7.2)
        if (offset == Z.FALSE) return Z.FALSE;
        if (offset == Z.TRUE) return Z.TRUE;
        Z.pc += (offset - 2);
        out('    jumping to ${Z.pc.toRadixString(16)}');
        return this.visitInstruction();
      }
    }else{
      out('    [false]');
      if (this._convertToSigned(operands[0].value) >= this._convertToSigned(operands[1].value)){
        if (offset == Z.FALSE) return Z.FALSE;
        if (offset == Z.TRUE) return Z.TRUE;
        Z.pc += (offset - 2);
        out('    jumping to ${Z.pc.toRadixString(16)}');
        return this.visitInstruction();
      }
    }
    out('    continuing to next instruction');
  }
  
  int jg(){
    out('  [jg]');
    var operands = this.visitOperandsLongForm();

    var jumpByte = Z.readb();
    bool testTrueOrFalse = BinaryHelper.isSet(jumpByte, 7);

    var offset = _jumpToLabelOffset(jumpByte);
    
    //TODO refactor
    if (testTrueOrFalse){
      out('    [true]');
      if (this._convertToSigned(operands[0].value) > this._convertToSigned(operands[1].value)){
        //(ref 4.7.2)
        if (offset == Z.FALSE) return Z.FALSE;
        if (offset == Z.TRUE) return Z.TRUE;
        Z.pc += (offset - 2);
        out('    jumping to ${Z.pc.toRadixString(16)}');
        return this.visitInstruction();
      }
    }else{
      out('    [false]');
      if (this._convertToSigned(operands[0].value) <= this._convertToSigned(operands[1].value)){
        if (offset == Z.FALSE) return Z.FALSE;
        if (offset == Z.TRUE) return Z.TRUE;
        Z.pc += (offset - 2);
        out('    jumping to ${Z.pc.toRadixString(16)}');
        return this.visitInstruction();
      }
    }
    out('    continuing to next instruction');
  }
  
  int je(){
    out('  [je]');
    var operands = this.visitOperandsLongForm();

    var jumpByte = Z.readb();
    bool testTrueOrFalse = BinaryHelper.isSet(jumpByte, 7);

    var offset = _jumpToLabelOffset(jumpByte);
    
    //TODO refactor
    if (testTrueOrFalse){
      out('    [true]');
      if (operands[0].value == operands[1].value){
        //(ref 4.7.2)
        if (offset == Z.FALSE) return Z.FALSE;
        if (offset == Z.TRUE) return Z.TRUE;
        Z.pc += (offset - 2);
        out('    jumping to ${Z.pc.toRadixString(16)}');
        return this.visitInstruction();
      }
    }else{
      out('    [false]');
      if (operands[0].value != operands[1].value){
        if (offset == Z.FALSE) return Z.FALSE;
        if (offset == Z.TRUE) return Z.TRUE;
        Z.pc += (offset - 2);
        out('    jumping to ${Z.pc.toRadixString(16)}');
        return this.visitInstruction();
      }
    }
    out('    continuing to next instruction');
  }

  int andV(){
    out('  [andV]');
    var operands = this.visitOperandsVar(2, false);
    
    var resultTo = Z.readb();
    
    Z.writeVariable(resultTo, operands[0].value & operands[1].value);
  }
  
  int and(){
    out('  [and]');
    
    var operands = this.visitOperandsLongForm();
    
    var resultTo = Z.readb();
    
    Z.writeVariable(resultTo, operands[0].value & operands[1].value);
  }
  
  int sub(){
    out('  [subtract]');
    var operands = this.visitOperandsLongForm();
    var resultTo = Z.readb();

    Z.writeVariable(resultTo, this._convertToSigned(operands[0].value) - this._convertToSigned(operands[1].value));
  }

  int add(){
    out('  [add]');
    var operands = this.visitOperandsLongForm();
    var resultTo = Z.readb();

    Z.writeVariable(resultTo, this._convertToSigned(operands[0].value) + this._convertToSigned(operands[1].value));
  }
  
  int mul(){
    out('  [mul]');
    var operands = this.visitOperandsLongForm();
    var resultTo = Z.readb();
    
    Z.writeVariable(resultTo, this._convertToSigned(operands[0].value) * this._convertToSigned(operands[1].value));
  }
  
  int div(){
    out('  [div]');
    var operands = this.visitOperandsLongForm();
    var resultTo = Z.readb();
    
    if (operands[1].peekValue == 0){
      throw const Exception('Divide by 0.');
    }
    
    Z.writeVariable(resultTo, (this._convertToSigned(operands[0].value) / this._convertToSigned(operands[1].value)).toInt());
  }

  int mod(){
    out('  [mod]');
    var operands = this.visitOperandsLongForm();
    var resultTo = Z.readb();
    
    if (operands[1].peekValue == 0){
      throw const Exception('Divide by 0.');
    }
    
    Z.writeVariable(resultTo, this._convertToSigned(operands[0].value) % this._convertToSigned(operands[1].value));
  }

  int get_prop(){
    out('  [get_prop]');

    var operands = this.visitOperandsLongForm();
    var resultTo = Z.readb();
    
    var obj = new GameObjectV3(operands[0].value);

    var prop = obj.getPropertyValue(operands[1].value);
    
    Z.writeVariable(resultTo, prop);
  }
  
  int loadb(){
    out('  [loadb]');
    
    var operands = this.visitOperandsLongForm();

    var resultTo = Z.readb();

    var addr = operands[0].value + this._convertToSigned(operands[1].value);

    //todo();
    Z.writeVariable(resultTo, Z.mem.loadb(addr));
    out('    loaded 0x${Z.peekVariable(resultTo).toRadixString(16)} from 0x${addr.toRadixString(16)} into 0x${resultTo.toRadixString(16)}');
  }
  
  int loadw(){
    out('  [loadw]');

    var operands = this.visitOperandsLongForm();

    var resultTo = Z.readb();

    var addr = operands[0].value + (2 * this._convertToSigned(operands[1].value));

    Z.writeVariable(resultTo, Z.mem.loadw(addr));
    out('    loaded 0x${Z.peekVariable(resultTo).toRadixString(16)} from 0x${addr.toRadixString(16)} into 0x${resultTo.toRadixString(16)}');
  }

  //variable arguement version of storew
  int storewv(){
    out('  [storewv]');

    var operands = this.visitOperandsVar(4, true);

    if (operands.length != 3){
      throw const Exception('Expected operand count of 3 for storew instruction.');
    }

    //(ref http://www.gnelson.demon.co.uk/zspec/sect15.html#storew)
    var addr = operands[0].value + (2 * this._convertToSigned(operands[1].value));
    Z.mem.storew(addr, operands[2].value);
    out('    stored 0x${operands[2].peekValue.toRadixString(16)} at addr: 0x${addr.toRadixString(16)}');
  }

  int callVS(){
    out('  [call_vs]');
    var operands = this.visitOperandsVar(4, true);

    if (operands.isEmpty())
      throw const Exception('Call function address not given.');

    var storeTo = Z.readb();

    var returnTo = Z.pc;

    //unpack function address
    operands[0].rawValue = this.unpack(operands[0].value);

    out('    (unpacked first operand to: 0x${operands[0].peekValue.toRadixString(16)})');

    if (operands[0].value == 0){
      //calling routine at address 0x00 automatically returns FALSE (ref 6.4.3)
      Z.writeVariable(storeTo, Z.FALSE);
    }else{
      Z.pc = operands[0].rawValue;
      var result = this.visitRoutine(new List.from(operands.getRange(1, operands.length - 1).map((o) => o.value)));
      Z.writeVariable(storeTo, result);
    }

    out('>>> returning control to: 0x${returnTo.toRadixString(16)}');
    Z.pc = returnTo;
  }

  int _convertToSigned(int val){
    var sign = val & 0x8000;
    if (sign != 0){
      return -(65536 - val);
    }else{
      return val;
    }
  }
  
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
         // print('negative offset to: 0x${(Z.pc + -(16384 - val)).toRadixString(16)}');
          return -(16384 - val);
        }else{
          
         // print('val: $val, positive offset to: 0x${(Z.pc + val).toRadixString(16)}');
          return val;
        }
      }
     
      var secondByte = Z.readb();
      
      var jumpWord = (BinaryHelper.bottomBits(jumpByte, 6) << 8) | secondByte;
     // print('jumpByte: $jumpByte, secondByte: $secondByte, jumpWord: $jumpWord');
      
      return _convertTo14BitSigned(jumpWord);
    }
  }


  Operand visitOperandsShortForm(){
    var oc = Z.mem.loadb(Z.pc - 1);

    //(ref 4.4.1)
    var operand = new Operand((oc & 48) >> 4);

    if (operand.type == OperandType.LARGE){
      operand.rawValue = Z.readw();
    }else{
      operand.rawValue = Z.readb();
    }
    out('    ${operand}');
    return operand;
  }

  List<Operand> visitOperandsLongForm(){
    var oc = Z.mem.loadb(Z.pc - 1);

    var o1 = BinaryHelper.isSet(oc, 6)
        ? new Operand(OperandType.VARIABLE) : new Operand(OperandType.SMALL);

    var o2 = BinaryHelper.isSet(oc, 5)
        ? new Operand(OperandType.VARIABLE) : new Operand(OperandType.SMALL);

    o1.rawValue = Z.readb();
    o2.rawValue = Z.readb();

    out('    ${o1}, ${o2}');

    return [o1, o2];
  }

  List<Operand> visitOperandsVar(int howMany, bool isVariable){
    var operands = new List<Operand>();

    //load operand types
    var shiftStart = howMany > 4 ? 14 : 6;
    var os = howMany > 4 ? Z.readw() : Z.readb();

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
          o.rawValue = Z.readw();
          break;
        case OperandType.SMALL:
          o.rawValue = Z.readb();
          break;
        case OperandType.VARIABLE:

          o.rawValue = Z.readb();

          break;
        default:
          throw new Exception('Illegal Operand Type found: ${o.type.toRadixString(16)}');
      }
    });

    out('    ${operands.length} operands:');

    operands.forEach((Operand o) {
      if (o.type == OperandType.VARIABLE){
        if (o.rawValue == 0){
          out('      ${OperandType.asString(o.type)}: SP (0x${o.peekValue.toRadixString(16)})');
        }else{
          out('      ${OperandType.asString(o.type)}: 0x${o.rawValue.toRadixString(16)} (0x${o.peekValue.toRadixString(16)})');
        }

      }else{
        out('      ${OperandType.asString(o.type)}: 0x${o.peekValue.toRadixString(16)}');
      }
    });

    if (!isVariable && (operands.length != howMany)){
      throw new Exception('Operand count mismatch.  Expected ${howMany}, found ${operands.length}');
    }

    return operands;
  }

  visitHeader(){
    Z.mem.abbrAddress = Z.mem.loadw(Header.ABBREVIATIONS_TABLE_ADDR);
    Z.mem.objectsAddress = Z.mem.loadw(Header.OBJECT_TABLE_ADDR);
    Z.mem.globalVarsAddress = Z.mem.loadw(Header.GLOBAL_VARS_TABLE_ADDR);
    Z.mem.staticMemAddress = Z.mem.loadw(Header.STATIC_MEM_BASE_ADDR);
    Z.mem.dictionaryAddress = Z.mem.loadw(Header.DICTIONARY_ADDR);
    Z.mem.highMemAddress = Z.mem.loadw(Header.HIGHMEM_START_ADDR);

    Z.pc = Z.mem.loadw(Header.PC_INITIAL_VALUE_ADDR);

    out('(Story contains ${Z.mem.size} bytes.)');
    out('');
    out('------- START HEADER -------');
    out('Z-Machine Version: ${Z.version}');
    out('Flags1(binary): ${Z.mem.loadw(Header.FLAGS1).toRadixString(2)}');
    // word after flags1 is used by Inform
    out('Abbreviations Location: ${Z.mem.abbrAddress.toRadixString(16)}');
    out('Object Table Location: ${Z.mem.objectsAddress.toRadixString(16)}');
    out('Global Variables Location: ${Z.mem.globalVarsAddress.toRadixString(16)}');
    out('Static Memory Start: ${Z.mem.staticMemAddress.toRadixString(16)}');
    out('Dictionary Location: ${Z.mem.dictionaryAddress.toRadixString(16)}');
    out('High Memory Start: ${Z.mem.highMemAddress.toRadixString(16)}');
    out('Program Counter Start: ${Z.pc.toRadixString(16)}');
    out('Flags2(binary): ${Z.mem.loadb(Header.FLAGS2).toRadixString(2)}');
    out('Length Of File: ${Z.mem.loadw(Header.LENGTHOFFILE) * fileLengthMultiplier()}');
    out('Checksum Of File: ${Z.mem.loadw(Header.CHECKSUMOFFILE)}');
    //TODO v4+ header stuff here
    out('Standard Revision: ${Z.mem.loadw(Header.REVISION_NUMBER)}');
    out('-------- END HEADER ---------');

    //out('main Routine: ${Z.mem.getRange(Z.pc - 4, 10)}');

    out('');
  }

}



