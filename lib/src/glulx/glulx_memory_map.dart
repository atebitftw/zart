import 'dart:typed_data';
import 'glulx_exception.dart';

/// The Glulx memory map, divided into ROM and RAM segments.
///
/// Memory is a simple array of bytes, numbered from zero up.
/// Multibyte values are stored big-endian.
class GlulxMemoryMap {
  late final Uint8List _memory;

  /// The first address which the program can write to.
  late final int ramStart;

  /// The end of the game-file's stored initial memory.
  late final int extStart;

  /// The end of the program's memory map.
  late final int endMem;

  /// The size of the stack needed by the program.
  late final int stackSize;

  /// Initialize the memory map from the game data.
  ///
  /// The header is the first 36 bytes and contains RAMSTART, EXTSTART, and ENDMEM.
  /// See Glulx Spec section "The Memory Map" and "The Header".
  GlulxMemoryMap(Uint8List gameData) {
    if (gameData.length < 36) {
      throw GlulxException('Game data too short to contain header');
    }

    // Verify Magic Number: 47 6C 75 6C ('Glul')
    if (gameData[0] != 0x47 || gameData[1] != 0x6C || gameData[2] != 0x75 || gameData[3] != 0x6C) {
      throw GlulxException('Invalid Glulx magic number');
    }

    // Read header values (big-endian)
    ramStart = _read32(gameData, 8);
    extStart = _read32(gameData, 12);
    endMem = _read32(gameData, 16);
    stackSize = _read32(gameData, 20);

    // Initial memory is allocated up to ENDMEM.
    // Data from 0 up to EXTSTART is loaded from gameData.
    // Above EXTSTART is initialized to zero.
    _memory = Uint8List(endMem);

    // Copy ROM and initial RAM
    final dataToCopy = extStart < gameData.length ? extStart : gameData.length;
    _memory.setRange(0, dataToCopy, gameData);

    // Remaining bytes are already zero-initialized by Uint8List
  }

  int _read32(Uint8List data, int offset) {
    return (data[offset] << 24) | (data[offset + 1] << 16) | (data[offset + 2] << 8) | data[offset + 3];
  }

  /// Read an 8-bit byte from memory.
  int readByte(int address) => _memory[address];

  /// Read a 16-bit short from memory (big-endian).
  int readShort(int address) {
    return (_memory[address] << 8) | _memory[address + 1];
  }

  /// Read a 32-bit word from memory (big-endian).
  int readWord(int address) => _read32(_memory, address);

  /// Write an 8-bit byte to memory. Throws [GlulxException] if writing to ROM.
  void writeByte(int address, int value) {
    _ensureInRam(address);
    _memory[address] = value & 0xFF;
  }

  /// Write a 16-bit short to memory (big-endian). Throws [GlulxException] if writing to ROM.
  void writeShort(int address, int value) {
    _ensureInRam(address);
    _memory[address] = (value >> 8) & 0xFF;
    _memory[address + 1] = value & 0xFF;
  }

  /// Write a 32-bit word to memory (big-endian). Throws [GlulxException] if writing to ROM.
  void writeWord(int address, int value) {
    _ensureInRam(address);
    _memory[address] = (value >> 24) & 0xFF;
    _memory[address + 1] = (value >> 16) & 0xFF;
    _memory[address + 2] = (value >> 8) & 0xFF;
    _memory[address + 3] = value & 0xFF;
  }

  void _ensureInRam(int address) {
    if (address < ramStart) {
      throw GlulxException('Illegal write to ROM at address 0x${address.toRadixString(16).toUpperCase()}');
    }
    if (address >= endMem) {
      throw GlulxException('Write beyond memory bounds at address 0x${address.toRadixString(16).toUpperCase()}');
    }
  }
}
