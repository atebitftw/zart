
class Operand
{
  final int type;
  int value;
  
  Operand(this.type);
}

/**
* Represents an atomic operation in the Z-Machine VM.
*/
class Operation
{
  /// {OperandType : Operand}
  final List<Operand> operands;
  
  Operation()
  :
    operands = new List<Operand>();

  abstract visit(IVisitor v);

  static void _loadOperands(Operation op, int upTo){
    var shiftStart = upTo > 4 ? 14 : 6;
    var os = upTo > 4 ? Z.readw() : Z.readb();
    print('$os');
    
    while(shiftStart > -2){
      var to = os >> shiftStart; //shift
      to &= 3; //mask higher order bits we don't care about
      if (to == OperandType.OMITTED){
        return;
      }else{
        op.operands.add(new Operand(to));
        if (op.operands.length == upTo) return;
        shiftStart -= 2;
      }
    }
  }

  static void _loadValues(Operation op){
    op.operands.forEach((Operand o){
      switch (o.type){
        case OperandType.LARGE:
          o.value = Z.readw();
          break;
        case OperandType.SMALL:
          o.value = Z.readb();
          break;
        case OperandType.VARIABLE:
          throw const NotImplementedException();
        default:
          throw new Exception('Illegal Operand Type found: ${o.type.toRadixString(16)}');
      }
    });
  }
}

class Call extends Operation{
  
  visit(IVisitor v){
    out('call');
    Operation._loadOperands(this, 4);
    out('  ${operands.length} operands.');
    Operation._loadValues(this);
    out('  values:');
    operands.forEach((Operand o) => out('    ${o.value}'));
  }
  
}


class Operation2Operand extends Operation
{

}

class Operation1Operand extends Operation
{

}

class Operation0Operand extends Operation
{

}

class OperationVar2Operand extends Operation
{

}

class OperationExtOperand extends Operation
{

}