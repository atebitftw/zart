
/**
* A disassembler of z-machine code using visitor pattern.
*/
class Tester implements IMachine
{
  ZVersion get version() => ZVersion.S;

  int get maxFileLength() => 128;

  int unpack(int packedAddr){
    return packedAddr * 2;
  }

  int fileLengthMultiplier() => 2;


  visitHeader(){
    var abbrAddress = Z.mem.loadw(Header.ABBREVIATIONS_TABLE_ADDR);
    var objectsAddress = Z.mem.loadw(Header.OBJECT_TABLE_ADDR);
    var globalVarsAddress = Z.mem.loadw(Header.GLOBAL_VARS_TABLE_ADDR);
    var staticMemAddress = Z.mem.loadw(Header.STATIC_MEM_BASE_ADDR);
    var dictionaryAddress = Z.mem.loadw(Header.DICTIONARY_ADDR);
    var highMemAddress = Z.mem.loadw(Header.HIGHMEM_START_ADDR);

    Z.pc = Z.mem.loadw(Header.PC_INITIAL_VALUE_ADDR);

    out('Disassembly');
    out('-----------');
    out('(Story contains ${Z.mem.size} bytes.)');
    out('');
    out('------- START HEADER -------');
    out('Z-Machine Version: ${Z.version}');
    out('Flags1(binary): ${Z.mem.loadw(Header.FLAGS1+1).toRadixString(2)}');
    out('Abbreviations Location: ${abbrAddress}');
    out('Object Table Location: ${objectsAddress}');
    out('Global Variables Location: ${globalVarsAddress}');
    out('Static Memory Start: ${staticMemAddress}');
    out('Dictionary Location: ${dictionaryAddress}');
    out('High Memory Start: ${highMemAddress}');
    out('Program Counter Start: ${Z.pc}');
    out('Flags2(binary): ${Z.mem.loadb(Header.FLAGS2).toRadixString(2)}');
    out('Length Of File: ${Z.mem.loadw(Header.LENGTHOFFILE) * fileLengthMultiplier()}');
    out('Checksum Of File: ${Z.mem.loadw(Header.CHECKSUMOFFILE)}');
    //TODO v4+ header stuff here
    out('Standard Revision: ${Z.mem.loadw(Header.REVISION_NUMBER)}');
    out('-------- END HEADER ---------');

    out('');
    out('pc initial addr: ${Z.pc}, value: ${Z.mem.loadb(Z.pc)}');
    out('hmm: ${Z.mem.getRange(Z.pc, 5)}');


    out('first 10: ${Z.mem.getRange(0, 10)}');
    out('prove variable (should be 3): ${Z.mem.loadb(Z.pc) >> 6}');
  }

  visitInstruction(int i){
    //decode instruction to correct visitor

    switch(true){
      case i >= 0 && i <= 0x1f:
        out('$i; long form; 2OP; ');
        break;
      case i >= 0x20 && i <= 0x3f:
        out('$i; long form; 2OP; ');
        break;
      case i >= 0x40 && i <= 0x5f:
        out('$i; long form; 2OP; ');
        break;
      case i >= 0x60 && i <= 0x7f:
        out('$i; long form; 2OP; ');
        break;
      case i >= 0x80 && i <= 0x8f:
        out('$i; short form; 1OP; ');
        break;
      case i >= 0x90 && i <= 0x9f:
        out('$i; short form; 1OP; ');
        break;
      case i >= 0xa0 && i <= 0xaf:
        out('$i; short form; 1OP; ');
        break;
      case i == 0xbe:
        out('$i; extended; 1OP; ');
        //extended in v5+
        break;
      case i >= 0xb0 && i <= 0xbf:
        out('short form; 0OP; ');
        break;
      case i >= 0xc0 && i <= 0xdf:
        out('$i; variable form; 2OP; ');
        break;
      case i >= 0xe0 && i <= 0xff:
        out('$i; variable form; VAR; ');
        break;
      default:
        throw const Exception('Unable to decode Op Code.');
    }
  }

  visit2Operand(Operation2Operand op){}

  visit1Operand(Operation1Operand op){}

  visit0Operand(Operation0Operand op){}

  visitVarOperand(OperationVarOperand op){}

  visitExtOperand(OperationExtOperand op){}

  void out(String outString){
    print(outString);
  }
}
