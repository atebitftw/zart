


/** All inclusive (versions 1-8) instruction set implementation.
*
* InstructionSet is a singleton. */
class InstructionSet
{
  static InstructionSet _ref;

  factory InstructionSet(){
    if (_ref != null) return _ref;

    _ref = new InstructionSet._internal();

    return _ref;
  }

  InstructionSet._internal();

  int jz(IMachine m){
    out('  [jz]');
    var operand = m.visitOperandsShortForm();

    var jumpByte = Z.readb();
    bool testTrueOrFalse = BinaryHelper.isSet(jumpByte, 7);

    var offset = _jumpToLabelOffset(jumpByte);

    //if testing for true, operand must == FALSE(0)
    if (testTrueOrFalse){
      out('    [true]');
      if (operand.value == Z.FALSE){
        Z.pc += (offset - 2);
        out('    jumping to ${Z.pc.toRadixString(16)}');
        return m.visitInstruction();
      }
    }else{
      out('    [false]');
      if (operand.value == Z.TRUE){
        Z.pc += (offset - 2);
        out('    jumping to ${Z.pc.toRadixString(16)}');
        return m.visitInstruction();
      }
    }
  }

  int insertObj(IMachine m){
    out('  [insert_obj]');
    todo();
  }
  
  int store(IMachine m){
    out('  [store]');
    
    var operands = m.visitOperandsLongForm();
    
    Z.writeVariable(operands[0].rawValue, operands[1].value);   
 }

  int jump(IMachine m){   
    out('  [jump]');
    
    int decodeOffset(int val){
      var sign = val & 0x8000;
      if (sign != 0){
        return -(65536 - val) - 2;
      }else{
        return val - 2;
      }
    }
               
    var operand = m.visitOperandsShortForm();
    
    var offset = decodeOffset(operand.value);
   
    Z.pc += offset;
    
    out('  (to 0x${Z.pc.toRadixString(16)})');
  }
  
  
  int ret(IMachine m){
    out('  [ret]');
    var operand = m.visitOperandsShortForm();
    
    out('    returning 0x${operand.peekValue.toRadixString(16)}');
    return operand.value;
  }
  
  int je(IMachine m){
    out('  [je]');
    var operands = m.visitOperandsLongForm();

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
        return m.visitInstruction();
      }
    }else{
      out('    [false]');
      if (operands[0].value != operands[1].value){
        Z.pc += (offset - 2);
        out('    jumping to ${Z.pc.toRadixString(16)}');
        return m.visitInstruction();
      }
    }
    out('    continuing to next instruction');
  }

  void sub(IMachine m){
    out('  [subtract]');
    var operands = m.visitOperandsLongForm();
    var resultTo = Z.readb();

    Z.writeVariable(resultTo, operands[0].value - operands[1].value);
    out('    Wrote 0x${(operands[0].value - operands[1].value).toRadixString(16)} (${operands[0].value} - ${operands[1].value}) to 0x${resultTo}');
  }

  void add(IMachine m){
    out('  [add]');
    var operands = m.visitOperandsLongForm();
    var resultTo = Z.readb();

    Z.writeVariable(resultTo, operands[0].value + operands[1].value);
    out('    Wrote 0x${(operands[0].value + operands[1].value).toRadixString(16)} (${operands[0].value} + ${operands[1].value}) to 0x${resultTo}');
  }

  
  
  int loadw(IMachine m){
    out('  [loadw]');
    
    var operands = m.visitOperandsLongForm();
    
    var resultTo = Z.readb();
    
    var addr = operands[0].value + (2 * operands[1].value);
    
    Z.writeVariable(resultTo, Z.mem.loadw(addr));
    out('    loaded 0x${Z.peekVariable(resultTo).toRadixString(16)} from 0x${addr.toRadixString(16)} into 0x${resultTo.toRadixString(16)}');
  }
  
  //variable arguement version of storew
  int storewv(IMachine m){
    out('  [storewv]');

    var operands = m.visitOperandsVar(4, true);

    if (operands.length != 3){
      throw const Exception('Expected operand count of 3 for storew instruction.');
    }

    //(ref http://www.gnelson.demon.co.uk/zspec/sect15.html#storew)
    var addr = operands[0].value + (2 * operands[1].value);
    Z.mem.storew(addr, operands[2].value);
    out('    stored 0x${operands[2].peekValue.toRadixString(16)} at addr: 0x${addr.toRadixString(16)}');
  }

  int callVS(IMachine m){
    out('  [call_vs]');
    var operands = m.visitOperandsVar(4, true);

    if (operands.isEmpty())
      throw const Exception('Call function address not given.');
    
    var storeTo = Z.readb();
//    out('>>>storing to: 0x${storeTo}');
    var returnTo = Z.pc;
//    out('>>>returning to: 0x${Z.pc.toRadixString(16)}');
    
    //unpack function address
    operands[0].rawValue = m.unpack(operands[0].value);

    out('    (unpacked first operand to: 0x${operands[0].peekValue.toRadixString(16)})');

    if (operands[0].value == 0){
      //calling routine at address 0x00 automatically returns FALSE (ref 6.4.3)
      Z.writeVariable(storeTo, Z.FALSE);
    }else{
      Z.pc = operands[0].value;
      var result = m.visitRoutine(new List.from(operands.getRange(1, operands.length - 1).map((o) => o.value)));
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
}