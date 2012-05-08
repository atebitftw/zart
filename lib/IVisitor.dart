interface IVisitor {
  visitHeader();

  visit2Operand(Operation2Operand op);

  visit1Operand(Operation1Operand op);

  visit0Operand(Operation0Operand op);

  visitVar2Operand(OperationVar2Operand op);
 
  visitExtOperand(OperationExtOperand op);

  visitInstruction(int instruction);
}
