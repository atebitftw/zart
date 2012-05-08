class Version3 implements IMachine
{
  ZVersion get version() => ZVersion.V3;

  int get maxFileLength() => 128;

  int unpack(int packedAddr){
    return packedAddr * 2;
  }

  int fileLengthMultiplier() => 2;

  visitHeader(){}

  visitInstruction(int instruction){}

  visit2Operand(Operation2Operand op){}

  visit1Operand(Operation1Operand op){}

  visit0Operand(Operation0Operand op){}

  visitVarOperand(OperationVarVarOperand op){}

  visitExtOperand(OperationExtOperand op){}
}