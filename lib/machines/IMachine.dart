
/**
* Defines the contract for any Z-Machine implementations.
*/
interface IMachine default Version3
{

 // ZMachine version.
 ZVersion get version();

 Map<String, Function> ops;

 /// Max file length in Kilobytes.
 int get maxFileLength();

//conversion from packed address to high memory byte address
// 2P           versions 1, 2 and 3
// 4P           versions 4 and 5
// 4P + 8R_O    versions 6 and 7, for routine calls
// 4P + 8S_O    versions 6 and 7, for prvoid_paddr
// 8P           version 8
// R_O and S_O are the routine and strings offsets (specified in the header as words at $28 and $2a, respectively).
 int unpack(int packedAddr);

 int fileLengthMultiplier();

 void visitHeader();

 void visitRoutine(List<int> params);

 void visitInstruction();

 List<Operand> visitOperandsVar(int howMany, bool isVariable);

 List<Operand> visitOperandsLongForm();

 Operand visitOperandsShortForm();

 void get_prop();

 void je();

 void jin();

 void add();

 void sub();

 void loadw();

 void callVS();

 void insertObj();
 
 void removeObj();

 void ret();

 void jump();

 void store();

 void storewv();
}

