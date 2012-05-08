interface IVisitor {
  visitHeader();

  visitMainRoutine();
  
  visitRoutine(List<int> params);
  
  visitInstruction();
  
  visitOperation_callvs();
  
  List<Operand> visitVarOperands(int howMany, bool isVariable);
  
  List<Operand> visitOperandLongForm();

  List<Operand> visitOperandShortForm();
}
