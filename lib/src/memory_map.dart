import 'package:zart/src/dictionary.dart';
import 'package:zart/src/game_exception.dart';
import 'package:zart/src/math_helper.dart';

/// Represents a memory map for a z-machine.
class MemoryMap {
  /// Initializes a new instance of the [MemoryMap] class from a list of [bytes].
  MemoryMap(List<int> bytes) {
    memList.addAll(bytes);
  }

  // A word address specifies an even address in the bottom 128K of memory
  // (by giving the address divided by 2). (Word addresses are used only in the abbreviations table.)

  /// The list of bytes representing the memory map.
  final List<int> memList =
      <
        int
      >[]; //each element in the array represents a byte of z-machine memory.

  // memory map address offsets
  /// The address of the abbreviations table.
  late int abbrAddress;

  /// The address of the objects table.
  late int objectsAddress;

  /// The address of the global variables table.
  late int globalVarsAddress;

  /// The address of the static memory table.
  late int staticMemAddress;

  /// The address of the dictionary table.
  int? dictionaryAddress;

  /// The address of the high memory table.
  late int highMemAddress;

  /// The address of the program start.
  int? programStart;

  /// The dictionary for the memory map.
  late Dictionary dictionary;

  /// Reads a global variable as a 2-byte word at [globalVarAddress] and returns it.
  int readGlobal(int globalVarAddress) {
    //if (which == 0) return Z.stack.pop();

    if (globalVarAddress < 0x10 || globalVarAddress > 0xff) {
      throw GameException('Global lookup register out of range.');
    }

    //global 0x00 means pop from stack
    return loadw(globalVarsAddress + ((globalVarAddress - 0x10) * 2));
  }

  /// Writes a global variable (word)
  void writeGlobal(int which, int value) {
    // if (which == 0) return Z.stack.push(value);

    if (which < 0x10 || which > 0xff) {
      throw GameException('Global lookup register out of range.');
    }

    storew(globalVarsAddress + ((which - 0x10) * 2), value);
  }

  /// Get byte from a given [address].
  int loadb(int address) {
    checkBounds(address);
    return memList[address] & 0xff;
  }

  /// Get a 2-byte word from given [address]
  int loadw(int address) {
    checkBounds(address);
    checkBounds(address + 1);
    return _getWord(address);
  }

  /// Stores a byte [value] into dynamic memory
  /// at [address].  Reference 1.1.1
  void storeb(int address, int value) {
    checkBounds(address);

    assert(value <= 0xff && value >= 0);

    memList[address] = value;
  }

  /// Stores a 2-byte word [value] into dynamic memory
  /// at [address].  Reference 1.1.1
  void storew(int address, int value) {
    checkBounds(address);
    checkBounds(address + 1);

    if (value > 0xffff) {
      throw GameException('word out of range');
    }

    if (value < 0) {
      //convert to zmachine 16-bit signed neg
      value = MathHelper.dartSignedIntTo16BitSigned(value);
    }

    assert(value >= 0);

    assert(((value >> 8) & 0xff) == (value >> 8));

    memList[address] = value >> 8;
    memList[address + 1] = value & 0xff;
  }

  int _getWord(int address) {
    var word = ((memList[address] << 8) | memList[address + 1]) & 0xffff;
    // if (address == 6){
    //   print("address index: ${address}, word: $word");
    //   print("address: ${BinaryHelper.binaryOf(memList[address])}, address << 8: ${BinaryHelper.binaryOf(memList[address] << 8)}, address + 1: ${BinaryHelper.binaryOf(memList[address+1])} ");
    //   print("address<<8 | address + 1: = ${BinaryHelper.binaryOf(((memList[address] << 8) | memList[address + 1]))}");
    //   print("final: ${BinaryHelper.binaryOf(((memList[address] << 8) | memList[address + 1]) & 0xffff)}");
    // }

    //no Dart negative values should be present.
    assert(word >= 0);
    return word;
  }

  /// Checks if the given [address] is within bounds of the memory map.
  void checkBounds(int address) {
    //  if ((address == null) || (address < 0) || (address > memList.length - 1)){

    //   // Debugger.debug('out of bounds memory. upper: ${_mem.length}, address: $address');

    //    throw GameException('Attempted access to memory address'
    //      ' that is out of bounds: $address (hex: 0x${address.toRadixString(16)}).  Max memory is: ${memList.length}');
    //  }
  }

  /// Dumps a range of memory from the given [address] to [address + howMany].
  String dump(int address, int howMany) {
    return getRange(
      address,
      howMany,
    ).map((o) => '0x${o.toRadixString(16)}').toString();
  }

  /// Gets a range of bytes from the memory map, starting at [address] and
  /// returning [howMany] bytes.
  List getRange(int address, int howMany) {
    checkBounds(address);
    checkBounds(address + howMany);
    return memList.getRange(address, address + howMany).toList();
  }

  /// Gets the current size of the memory map.
  int get size => memList.length;
}
