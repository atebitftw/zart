class _MemoryMap {

  // A word address specifies an even address in the bottom 128K of memory
  // (by giving the address divided by 2). (Word addresses are used only in the abbreviations table.)

  final List<int> _mem; //each element in the array represents a byte of z-machine memory.
  int dynamicUpper;
  int highMemoryLower;

  _MemoryMap(this._mem);

  void checkMem(){
    if (dynamicUpper == null || highMemoryLower == null) throw const Exception('One or more memory boundaries is not set.');
    if (dynamicUpper < 64) throw const Exception('Dynamic memory allocation must be at least 64 bytes.'); // 1.1
    if (highMemoryLower <= dynamicUpper) throw const Exception('High memory lower bound cannot overlap dynamic memory upper bound.'); //1.1
    if (highMemoryLower > KBtoB(64) - 0x02) throw const Exception('Dynamic & Static memory exceeds 64kb limit.'); // Seciton 1 remarks
  }

  int staticLower() => dynamicUpper + 1;

  //static and dynamic memory (1.1.1, 1.1.2)
  //get byte
  int loadb(int address){
    checkBounds(address);
    return _mem[address];
  }

  //get word
  int loadw(int address){
    checkBounds(address);
    checkBounds(address + 1);
    return _getWord(address);
  }

  //dynamic memory only (1.1.1)
  //put byte
  void storeb(int address, int value){
    throw const NotImplementedException();
  }

  //put word
  void storew(int address, int value){
    throw const NotImplementedException();
  }

  int _getWord(int address) => (_mem[address] << 8) | _mem[address + 1];

  void checkBounds(int address){
   if (address == null || address < 0 || address > _mem.length - 1){
     throw const Exception('Attempted access to memory address'
       ' that is out of bounds.');
   }
  }

  List getRange(int address, int howMany){
    checkBounds(address);
    checkBounds(address + howMany);
    return _mem.getRange(address, howMany);
  }

  int get size() => _mem.length;

  void memInfo() => print('size: $size, dynamicUpper: $dynamicUpper');

}


//enumerates addressTypes
class AddressType{
  final String _str;

  const AddressType(this._str);

  static final ByteAddress = const AddressType('ByteAddress');
  static final WordAddress = const AddressType('WordAddress');
  static final PackedAddress = const AddressType('PackedAddress');
}