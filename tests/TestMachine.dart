class TestMachine implements IMachine {
  Map<String, Function> ops;
  
  Tester()
  {
    ops = 
      {
 //      '224' : visitOperation_callvs
      };
  }
    
  
  ZVersion get version() => ZVersion.S;

  int get maxFileLength() => 128;

  int unpack(int packedAddr){
    return packedAddr * 2;
  }

  int fileLengthMultiplier() => 2;


  visitHeader(){
    Z.mem.abbrAddress = Z.mem.loadw(Header.ABBREVIATIONS_TABLE_ADDR);
    Z.mem.objectsAddress = Z.mem.loadw(Header.OBJECT_TABLE_ADDR);
    Z.mem.globalVarsAddress = Z.mem.loadw(Header.GLOBAL_VARS_TABLE_ADDR);
    Z.mem.staticMemAddress = Z.mem.loadw(Header.STATIC_MEM_BASE_ADDR);
    Z.mem.dictionaryAddress = Z.mem.loadw(Header.DICTIONARY_ADDR);
    Z.mem.highMemAddress = Z.mem.loadw(Header.HIGHMEM_START_ADDR);

    Z.pc = Z.mem.loadw(Header.PC_INITIAL_VALUE_ADDR);
  }

  visitInstruction(int i){
    if (ops.containsKey('$i')){
      var func = ops['$i'];
      func();
    }else{
      throw new Exception('Unsupported Op Code: $i');
    }
  }

  visitOperation_callvs(){
    out('call_vs (variable operands)');
    var op = new CallVS();
    op.visit(this);
  }
    
  List<Operand> visitOperands(int howMany, bool isVariable){
    var operands = isVariable ? new List<Operand>() : new List<Operand>(howMany);
    
    //load operand types
    var shiftStart = howMany > 4 ? 14 : 6;
    var os = howMany > 4 ? Z.readw() : Z.readb();
    
    while(shiftStart > -2){
      var to = os >> shiftStart; //shift
      to &= 3; //mask higher order bits we don't care about
      if (to == OperandType.OMITTED){
        break;
      }else{
        operands.add(new Operand(to));
        if (operands.length == howMany) break;
        shiftStart -= 2;
      }
    }

    //load values
    operands.forEach((Operand o){
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
    
    out('  ${operands.length} operands.');
    out('  values:');
    operands.forEach((Operand o) =>  out('    ${OperandType.asString(o.type)}: ${o.value.toRadixString(16)}'));
    
    return operands;
  }
}
