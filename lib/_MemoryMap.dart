class _MemoryMap {

  // A word address specifies an even address in the bottom 128K of memory
  // (by giving the address divided by 2). (Word addresses are used only in the abbreviations table.)

  final List<int> _mem; //each element in the array represents a byte of z-machine memory.

  // memory map address offsets
  int abbrAddress;
  int objectsAddress;
  int globalVarsAddress;
  int staticMemAddress;
  int dictionaryAddress;
  int highMemAddress;
  int programStart;
  Dictionary dictionary;

  _MemoryMap(List bytes)
  : _mem = new List.from(bytes);


  // Reads a global variable (word)
  int readGlobal(int which){

   //if (which == 0) return Z.stack.pop();

   if (which < 0x10 || which > 0xff)
     throw new GameException('Global lookup register out of range.');

   //global 0x00 means pop from stack
   return loadw(globalVarsAddress + ((which - 0x10) * 2));
  }

  // Writes a global variable (word)
  void writeGlobal(int which, int value){
   // if (which == 0) return Z.stack.push(value);

    if (which < 0x10 || which > 0xff)
      throw new GameException('Global lookup register out of range.');

      storew(globalVarsAddress + ((which - 0x10) * 2), value);
  }

  //static and dynamic memory (1.1.1, 1.1.2)
  //get byte
  int loadb(int address){
    assert(address != null);
    checkBounds(address);
    return _mem[address] & 0xff;
  }

  //get word
  int loadw(int address){
    assert(address != null);
    checkBounds(address);
    checkBounds(address + 1);
    return _getWord(address);
  }

  //dynamic memory only (1.1.1)
  //put byte
  void storeb(int address, int value){
    assert(address != null);
    checkBounds(address);
    //TODO validate

    assert(value != null && (value <= 0xff && value >= 0));

    _mem[address] = value;
  }

  //put word
  void storew(int address, int value){
    assert(address != null);
    checkBounds(address);
    checkBounds(address + 1);

    if (value > 0xffff)
      throw new GameException('word out of range');

    if (value < 0){
      //convert to 16-bit signed neg
      value = Machine.dartSignedIntTo16BitSigned(value);
    }

    assert(value >= 0);

    assert(((value >> 8) & 0xff) == (value >> 8));

    _mem[address] = value >> 8;
    _mem[address + 1] = value & 0xff;
  }

  int _getWord(int address) {
    var word = ((_mem[address] << 8) | _mem[address + 1]) & 0xffff;

    //no Dart-signed values should be present.
    assert(word >= 0);
    return word;
  }

  void checkBounds(int address){
   assert(address != null);

   if ((address == null) || (address < 0) || (address > _mem.length - 1)){

     Debugger.debug('memory upper: ${_mem.length}, address: $address');

     throw new GameException('Attempted access to memory address'
       ' that is out of bounds: $address 0x${address.toRadixString(16)}');
   }
  }

  String dump(int address, int howMany){
    var map = getRange(address, howMany).map((o)=> '0x${o.toRadixString(16)}');
    return '$map';
  }

  List getRange(int address, int howMany){
    checkBounds(address);
    checkBounds(address + howMany);
    return _mem.getRange(address, howMany);
  }

  int get size() => _mem.length;

}


//enumerates addressTypes
class AddressType{
  final String _str;

  const AddressType(this._str);

  static final ByteAddress = const AddressType('ByteAddress');
  static final WordAddress = const AddressType('WordAddress');
  static final PackedAddress = const AddressType('PackedAddress');
}