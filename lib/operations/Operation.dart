
class Operand
{
  final int type;
  int value;
  
  Operand(this.type);
}

/**
* Represents an atomic operation in the Z-Machine VM.
*/
interface Operation
{
  visit(IMachine v);
}

class Add implements Operation{
  
  visit(IMachine v){
    var operands = v.visitOperands(2, false);
    var test = Z.readb(); //where?
    out('where? ${test}');
  }
}

class CallVS implements Operation{
  
  visit(IMachine v){
    var operands = v.visitOperands(4, true);
    
    if (operands.isEmpty()) 
      throw const Exception('Call function address not given.');
    
    //unpack function address
    operands[0].value = v.unpack(operands[0].value);
    
    out('    (unpacked first operand to: ${operands[0].value.toRadixString(16)})');
    
    if (operands[0].value == 0){
      //calling routine at address 0x00 automatically returns FALSE (ref 6.4.3)
      return Z.FALSE;
    }else{
      Z.pc = operands[0].value;
      v.visitRoutine(new List.from(operands.getRange(1, operands.length - 1).map((o) => o.value)));
    }
  }
}