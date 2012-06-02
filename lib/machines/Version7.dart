
class Version7 extends Version5
{
  ZVersion get version() => ZVersion.V7;

  // Kb
  int get maxFileLength() => 320;

  int unpack(int packedAddr){
    return (packedAddr << 2) + (mem.loadw(Header.ROUTINES_OFFSET) << 3);
  }

  int pack(int unpackedAddr){
    throw const NotImplementedException();
  }

  int unpack_paddr(int packed_print_addr){
    return (packed_print_addr << 2) + (mem.loadw(Header.STRINGS_OFFSET) << 3);
  }

  void print_paddr(){
    //Debugger.verbose('${pcHex(-1)} [print_paddr]');

    var operand = this.visitOperandsShortForm();

    var addr = this.unpack_paddr(operand.value);

    var str = ZSCII.readZStringAndPop(addr);

    Debugger.verbose('${pcHex()} "$str"');

    Z.sbuff.add(str);
  }
}
