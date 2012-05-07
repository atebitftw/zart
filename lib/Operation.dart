/**
* Represents an atomic operation in the Z-Machine VM.
*/
class Operation implements Hashable
{
  abstract int get hex();

  abstract execute();

  abstract visit(IVisitor v);

  int hashCode() => hex;
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

class OperationVarOperand extends Operation
{

}

class OperationExtOperand extends Operation
{

}