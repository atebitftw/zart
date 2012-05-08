interface IVisitor {
  visitHeader();

  visitInstruction(int instruction);
  
  visitOperation_callvs();
  
  List<Operand> visitOperands(int howMany, bool isVariable);
}
