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
}
