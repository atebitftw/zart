interface IVisitor {
  visitHeader();

  visitMainRoutine();

  visitRoutine(List<int> params);

  visitInstruction();

  List<Operand> visitOperandsVar(int howMany, bool isVariable);

  List<Operand> visitOperandsLongForm();

  Operand visitOperandsShortForm();
}
