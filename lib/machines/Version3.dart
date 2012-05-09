
/**
* Implementation of Z-Machine v3
*/
class Version3 implements IMachine
{
  Map<String, Function> ops;

  bool mainCalled = false;

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
       '224' : I.callVS,
       '225' : I.storew,
       '20' : I.add,
       '52' : I.add,
       '84' : I.add,
       '116' : I.add,
       '21' : I.sub,
       '53' : I.sub,
       '85' : I.sub,
       '117' : I.sub,
       '1' : I.je,
       '33' : I.je,
       '65' : I.je,
       '97' : I.je,
       '160' : I.jz,
       '144' : I.jz,
       '128' : I.jz,
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

    //TODO unwind stack frame and assign returnVal;
    todo('unwind stack and assign returnVal');
  }

  visitInstruction(){
    var i = Z.readb();
    if (ops.containsKey('$i')){
      var func = ops['$i'];
      func(this);
    }else{
      _throwAndDump('Unsupported Op Code: $i', -1, howMany:0);
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

    operands.forEach((Operand o) =>  out('      ${OperandType.asString(o.type)}: 0x${o.value.toRadixString(16)}'));

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
