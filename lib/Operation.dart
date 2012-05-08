
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

class CallVS implements Operation{
  
  visit(IMachine v){
    var operands = v.visitOperands(4, true);
    
    if (operands.isEmpty()) 
      throw const Exception('Call function address not given.');   
    
    //unpack function address
    operands[0].value = v.unpack(operands[0].value);
    
    out('    (unpacked first operand to: ${operands[0].value.toRadixString(16)})');
    
    if (operands[0].value == 0){

    }else{
      //TODO handle address 0x00 call (returns FALSE)
    }
  }
}