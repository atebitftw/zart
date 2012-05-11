
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
       '13' : store,
       '45' : store,
       '77' : store,
       '109' : store,
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
       '1' : je,
       '33' : je,
       '65' : je,
       '97' : je,
       '160' : jz,
       '140' : jump,
       '165' : jump,
       '144' : jz,
       '128' : jz,
       '139' : ret,
       '155' : ret,
       '171' : ret
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
      return func();
    }else{
      _throwAndDump('Unsupported Op Code: $i', -1, howMany:10);
    }
  }

  int testAttribute()  {
    todo();
  }

  int setAttribute()  {
    todo();
  }

  int clearAttribute()  {
    todo();
  }

  int getProperty()  {
    todo();
  }

  int getPropertyAddress()  {
    todo();
  }

  int getNextProperty()  {
    todo();
  }

  int getObjectAddress(int objectNumber){
    // skip header bytes (ref 12.2)
    var objStart = Z.mem.objectsAddress + 62;

    // 9 bytes per object (ref 12.3.1)
    return objStart += (objectNumber - 1) * 9;
  }


  int jin()  {
    todo();
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
        Z.pc += (offset - 2);
        out('    jumping to ${Z.pc.toRadixString(16)}');
        return this.visitInstruction();
      }
    }else{
      out('    [false]');
      if (operand.value == Z.TRUE){
        Z.pc += (offset - 2);
        out('    jumping to ${Z.pc.toRadixString(16)}');
        return this.visitInstruction();
      }
    }
  }

  int insertObj(){
    out('  [insert_obj]');

    var operands = this.visitOperandsLongForm();

    out('Insert Object ${operands[0].peekValue} into ${operands[1].peekValue}');


    getObjectShortName(11);
//    getObjectShortName(4);
//    getObjectShortName(5);
//    getObjectShortName(operands[0].peekValue);
//    getObjectShortName(operands[1].peekValue);

    todo('complete insert object');
  }

  String getObjectShortName(int oNum){
    var addr = getObjectAddress(oNum);
//    out('object address: 0x${addr.toRadixString(16)}');

    var propertyTableAddr = Z.mem.loadw(addr + 7);

//    out('property table: ${Z.mem.getRange(propertyTableAddr, 20)}');
    out('${ZSCII.readZString(propertyTableAddr + 1)}');
  }

  int store(){
    out('  [store]');

    var operands = this.visitOperandsLongForm();

    Z.writeVariable(operands[0].rawValue, operands[1].value);
 }

  int jump(){
    out('  [jump]');

    int decodeOffset(int val){
      var sign = val & 0x8000;
      if (sign != 0){
        return -(65536 - val) - 2;
      }else{
        return val - 2;
      }
    }

    var operand = this.visitOperandsShortForm();

    var offset = decodeOffset(operand.value);

    Z.pc += offset;

    out('  (to 0x${Z.pc.toRadixString(16)})');
  }


  int ret(){
    out('  [ret]');
    var operand = this.visitOperandsShortForm();

    out('    returning 0x${operand.peekValue.toRadixString(16)}');
    return operand.value;
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
        Z.pc += (offset - 2);
        out('    jumping to ${Z.pc.toRadixString(16)}');
        return this.visitInstruction();
      }
    }else{
      out('    [false]');
      if (operands[0].value != operands[1].value){
        Z.pc += (offset - 2);
        out('    jumping to ${Z.pc.toRadixString(16)}');
        return this.visitInstruction();
      }
    }
    out('    continuing to next instruction');
  }

  int sub(){
    out('  [subtract]');
    var operands = this.visitOperandsLongForm();
    var resultTo = Z.readb();

    Z.writeVariable(resultTo, operands[0].value - operands[1].value);
    out('    Wrote 0x${(operands[0].value - operands[1].value).toRadixString(16)} (${operands[0].value} - ${operands[1].value}) to 0x${resultTo}');
  }

  int add(){
    out('  [add]');
    var operands = this.visitOperandsLongForm();
    var resultTo = Z.readb();

    Z.writeVariable(resultTo, operands[0].value + operands[1].value);
    out('    Wrote 0x${(operands[0].value + operands[1].value).toRadixString(16)} (${operands[0].value} + ${operands[1].value}) to 0x${resultTo}');
  }



  int loadw(){
    out('  [loadw]');

    var operands = this.visitOperandsLongForm();

    var resultTo = Z.readb();

    var addr = operands[0].value + (2 * operands[1].value);

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
    var addr = operands[0].value + (2 * operands[1].value);
    Z.mem.storew(addr, operands[2].value);
    out('    stored 0x${operands[2].peekValue.toRadixString(16)} at addr: 0x${addr.toRadixString(16)}');
  }

  int callVS(){
    out('  [call_vs]');
    var operands = this.visitOperandsVar(4, true);

    if (operands.isEmpty())
      throw const Exception('Call function address not given.');

    var storeTo = Z.readb();
//    out('>>>storing to: 0x${storeTo}');
    var returnTo = Z.pc;
//    out('>>>returning to: 0x${Z.pc.toRadixString(16)}');

    //unpack function address
    operands[0].rawValue = this.unpack(operands[0].value);

    out('    (unpacked first operand to: 0x${operands[0].peekValue.toRadixString(16)})');

    if (operands[0].value == 0){
      //calling routine at address 0x00 automatically returns FALSE (ref 6.4.3)
      Z.writeVariable(storeTo, Z.FALSE);
    }else{
      Z.pc = operands[0].value;
      var result = this.visitRoutine(new List.from(operands.getRange(1, operands.length - 1).map((o) => o.value)));
      Z.writeVariable(storeTo, result);
    }

    //Z.pc = Z.callStack.pop();
    out('>>> returning control to: 0x${returnTo.toRadixString(16)}');
    Z.pc = returnTo;
  }

  //calculates the local jump offset (ref 4.7)
  int _jumpToLabelOffset(int jumpByte){

    if (BinaryHelper.isSet(jumpByte, 6)){
      //single byte offset
      return BinaryHelper.bottomBits(jumpByte, 6);
    }else{
      //2-byte offset (signed)
      todo('implement 2-byte offset calc');
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
