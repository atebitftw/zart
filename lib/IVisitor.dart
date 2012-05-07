interface IVisitor {
  visitHeader();

  visit2Operand(Operation2Operand op);

  visit1Operand(Operation1Operand op);

  visit0Operand(Operation0Operand op);

  visitVarOperand(OperationVarOperand op);

  visitExtOperand(OperationExtOperand op);

  visitInstruction(int instruction);
}
