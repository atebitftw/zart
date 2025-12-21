import 'dart:typed_data';
import 'glulx_exception.dart';
import 'glulx_heap.dart';

/// The Glulx memory map, divided into ROM and RAM segments.
///
/// Spec: "Memory is a simple array of bytes, numbered from zero up."
/// Spec: "Multibyte values are stored big-endian."
///
/// Memory segments (Spec: "The Memory Map"):
/// ```
///     Segment    Address (hex)
///   +---------+  00000000
///   | Header  |
///   | - - - - |  00000024
///   |   ROM   |
///   +---------+  RAMSTART
///   |   RAM   |
///   | - - - - |  EXTSTART
///   +---------+  ENDMEM
/// ```
class GlulxMemoryMap {
  late Uint8List _memory;

  /// The first address which the program can write to.
  /// Spec: "RAMSTART: The first address which the program can write to."
  late final int ramStart;

  /// The end of the game-file's stored initial memory (and therefore the length of the game file).
  /// Spec: "EXTSTART: The end of the game-file's stored initial memory."
  late final int extStart;

  /// The current end of the program's memory map.
  /// Spec: "ENDMEM: The end of the program's memory map."
  /// Note: This can change during execution via setmemsize or malloc/mfree opcodes.
  int _endMem = 0;

  /// The original ENDMEM as specified in the header (for restart/setmemsize validation).
  late final int origEndMem;

  /// The size of the stack needed by the program.
  /// Spec: "Stack size: The size of the stack needed by the program."
  late final int stackSize;

  /// Memory protection range start address.
  /// Spec: "Protect a range of memory from restart, restore, restoreundo."
  int _protectStart = 0;

  /// Memory protection range end address.
  int _protectEnd = 0;

  /// The starting address of the heap, or 0 if the heap is inactive.
  /// Spec: "When you first allocate a block of memory, the heap becomes active.
  /// The current end of memory – that is, the current getmemsize value – becomes
  /// the beginning address of the heap."
  final GlulxHeap _heap = GlulxHeap();

  /// Gets the current end of memory.
  int get endMem => _endMem;

  /// Gets the current heap start address (0 if heap is inactive).
  int get heapStart => _heap.heapStart;

  /// Gets the current size of the memory map (alias for endMem).
  int get size => _endMem;

  /// The original game data (ROM + initial RAM) for undo XOR compression.
  late final Uint8List _originalGameData;

  /// Returns whether the heap is currently active.
  bool get heapIsActive => _heap.isActive;

  /// Gets the heap summary for save/restore.
  List<int> get heapSummary => _heap.getSummary();

  /// Initialize the memory map from the game data.
  ///
  /// Spec: "The header is the first 36 bytes of memory."
  /// See Glulx Spec sections "The Memory Map" and "The Header".
  GlulxMemoryMap(Uint8List gameData) {
    if (gameData.length < 36) {
      throw GlulxException('Game data too short to contain header');
    }

    // Verify Magic Number: 47 6C 75 6C ('Glul')
    // Spec: "Magic number: 47 6C 75 6C, which is to say the ASCII string 'Glul'."
    if (gameData[0] != 0x47 ||
        gameData[1] != 0x6C ||
        gameData[2] != 0x75 ||
        gameData[3] != 0x6C) {
      throw GlulxException('Invalid Glulx magic number');
    }

    // Read header values (big-endian)
    // Spec: "Recall that values in memory are always big-endian."
    ramStart = _read32(gameData, 8);
    extStart = _read32(gameData, 12);
    origEndMem = _read32(gameData, 16);
    stackSize = _read32(gameData, 20);

    // Validate 256-byte alignment
    // Spec: "For the convenience of paging interpreters, the three boundaries
    // RAMSTART, EXTSTART, and ENDMEM must be aligned on 256-byte boundaries."
    if ((ramStart & 0xFF) != 0 ||
        (extStart & 0xFF) != 0 ||
        (origEndMem & 0xFF) != 0 ||
        (stackSize & 0xFF) != 0) {
      throw GlulxException(
        'Segment boundaries in the header are not 256-byte aligned',
      );
    }

    // Validate segment ordering
    // Spec: "ROM must be at least 256 bytes long (so that the header fits in it)."
    // Spec: The segments must be in order: 0 < RAMSTART <= EXTSTART <= ENDMEM
    if (ramStart < 0x100) {
      throw GlulxException(
        'RAMSTART must be at least 0x100 (ROM must contain the header)',
      );
    }
    if (extStart < ramStart) {
      throw GlulxException('EXTSTART must be >= RAMSTART');
    }
    if (origEndMem < extStart) {
      throw GlulxException('ENDMEM must be >= EXTSTART');
    }

    // Validate stack size minimum
    // Reference interpreter: "if (stacksize < 0x100) fatal_error(...)"
    if (stackSize < 0x100) {
      throw GlulxException('Stack size in the header is too small');
    }

    // Initialize memory
    // Spec: "Initial memory is allocated up to ENDMEM."
    _endMem = origEndMem;
    _memory = Uint8List(_endMem);

    // Copy ROM and initial RAM from game data
    // Spec: "Data from 0 up to EXTSTART is loaded from gameData."
    // Spec: "Above EXTSTART is initialized to zero."
    final dataToCopy = extStart < gameData.length ? extStart : gameData.length;
    _memory.setRange(0, dataToCopy, gameData);

    // Keep a copy of the original game data for undo XOR compression
    // Reference: serial.c uses ramcache for this purpose
    _originalGameData = Uint8List.fromList(gameData);

    // Protection range starts disabled
    _protectStart = 0;
    _protectEnd = 0;
  }

  int _read32(Uint8List data, int offset) {
    return (data[offset] << 24) |
        (data[offset + 1] << 16) |
        (data[offset + 2] << 8) |
        data[offset + 3];
  }

  /// Validates that count bytes starting at address all fall within the memory map.
  void _verifyAddress(int address, int count) {
    if (address < 0 || address >= _endMem) {
      throw GlulxException(
        'Memory access out of range at address 0x${address.toRadixString(16).toUpperCase()}',
      );
    }
    if (count > 1) {
      final endAddress = address + count - 1;
      if (endAddress >= _endMem) {
        throw GlulxException(
          'Memory access out of range at address 0x${endAddress.toRadixString(16).toUpperCase()}',
        );
      }
    }
  }

  /// Validates that count bytes starting at address all fall within RAM.
  void _verifyAddressWrite(int address, int count) {
    if (address < ramStart) {
      throw GlulxException(
        'Illegal write to ROM at address 0x${address.toRadixString(16).toUpperCase()}',
      );
    }
    if (address >= _endMem) {
      throw GlulxException(
        'Write beyond memory bounds at address 0x${address.toRadixString(16).toUpperCase()}',
      );
    }
    if (count > 1) {
      final endAddress = address + count - 1;
      if (endAddress >= _endMem) {
        throw GlulxException(
          'Write beyond memory bounds at address 0x${endAddress.toRadixString(16).toUpperCase()}',
        );
      }
    }
  }

  /// Read an 8-bit byte from memory.
  int readByte(int address) {
    _verifyAddress(address, 1);
    return _memory[address];
  }

  /// Read a 16-bit short from memory (big-endian).
  int readShort(int address) {
    _verifyAddress(address, 2);
    return (_memory[address] << 8) | _memory[address + 1];
  }

  /// Read a 32-bit word from memory (big-endian).
  int readWord(int address) {
    _verifyAddress(address, 4);
    return _read32(_memory, address);
  }

  void writeByte(int address, int value) {
    _verifyAddressWrite(address, 1);
    _memory[address] = value & 0xFF;
  }

  /// Read the original byte value at the given address (from initial game data).
  /// Used for XOR compression in undo state.
  /// Reference: serial.c ramcache access
  int readOriginalByte(int address) {
    if (address < 0 || address >= _originalGameData.length) {
      return 0; // Beyond original game data, assume zero
    }
    return _originalGameData[address];
  }

  /// Write a 16-bit short to memory (big-endian).
  /// Throws [GlulxException] if writing to ROM or out of bounds.
  void writeShort(int address, int value) {
    _verifyAddressWrite(address, 2);
    _memory[address] = (value >> 8) & 0xFF;
    _memory[address + 1] = value & 0xFF;
  }

  /// Write a 32-bit word to memory (big-endian).
  /// Throws [GlulxException] if writing to ROM or out of bounds.
  void writeWord(int address, int value) {
    _verifyAddressWrite(address, 4);
    _memory[address] = (value >> 24) & 0xFF;
    _memory[address + 1] = (value >> 16) & 0xFF;
    _memory[address + 2] = (value >> 8) & 0xFF;
    _memory[address + 3] = value & 0xFF;
  }

  /// Change the size of the memory map.
  ///
  /// Spec: "When the memory size grows, the new space is filled with zeroes.
  /// When it shrinks, the contents of the old space are lost."
  ///
  /// Spec: "If the allocation heap is active you may not use setmemsize –
  /// the memory map is under the control of the heap system."
  ///
  /// Returns 0 for success, 1 for failure.
  int setMemorySize(int newLength, {bool internal = false}) {
    if (newLength == _endMem) {
      return 0;
    }

    // Spec: "If the allocation heap is active you may not use setmemsize"
    if (!internal && heapIsActive) {
      return 1; // Cannot resize while heap is active (unless internal heap call)
    }

    // Spec: Cannot shrink below original size
    if (newLength < origEndMem) {
      return 1;
    }

    // Spec: "ENDMEM must be aligned on 256-byte boundaries."
    if ((newLength & 0xFF) != 0) {
      return 1;
    }

    // Reallocate memory
    final newMemory = Uint8List(newLength);
    final copyLength = newLength < _endMem ? newLength : _endMem;
    newMemory.setRange(0, copyLength, _memory);

    // New space is already zero-filled by Uint8List constructor
    _memory = newMemory;
    _endMem = newLength;

    return 0;
  }

  /// Set the memory protection range.
  ///
  /// Spec: "Protect a range of memory from restart, restore, restoreundo.
  /// The protected range starts at address L1 and has a length of L2 bytes.
  /// This memory is silently unaffected by the state-restoring operations."
  ///
  /// Spec: "Only one range can be protected at a time. Calling protect cancels
  /// any previous range. To turn off protection, call protect with L1 and L2 set to zero."
  void setProtection(int start, int length) {
    _protectStart = start;
    _protectEnd = start + length;
  }

  /// Get the current protection range.
  (int start, int end) get protectionRange => (_protectStart, _protectEnd);

  /// Returns whether the given address is within the protected range.
  bool isProtected(int address) {
    return address >= _protectStart && address < _protectEnd;
  }

  /// Activate the heap at the current end of memory.
  ///
  /// Spec: "When you first allocate a block of memory, the heap becomes active.
  /// The current end of memory – that is, the current getmemsize value – becomes
  /// the beginning address of the heap."
  void activateHeap() {
    _heap.activate(_endMem);
  }

  /// Deactivate the heap and shrink memory back to heap start.
  ///
  /// Spec: "When you free the last extant memory block, the heap becomes inactive.
  /// The interpreter will reduce the memory map size down to the heap-start address."
  void deactivateHeap() {
    if (_heap.isActive) {
      final start = _heap.heapStart;
      _heap.clear();
      setMemorySize(start, internal: true);
    }
  }

  /// Allocates a block of the given length on the heap.
  int malloc(int len) {
    return _heap.allocate(
      len,
      _endMem,
      (newSize) => setMemorySize(newSize, internal: true),
    );
  }

  /// Frees a heap block at the given address.
  void mfree(int addr) {
    _heap.free(addr);
    if (_heap.allocCount <= 0) {
      deactivateHeap();
    }
  }

  /// Provides raw access to memory for serialization.
  /// Use with caution - primarily for save/restore operations.
  Uint8List get rawMemory => _memory;

  /// Restores memory from a saved state, respecting the protection range.
  ///
  /// Spec: "The protected range ... is silently unaffected by the state-restoring operations."
  void restoreMemory(
    Uint8List savedMemory,
    int savedEndMem,
    List<int> heapSummary,
  ) {
    // Resize if necessary
    if (savedEndMem != _endMem) {
      setMemorySize(savedEndMem, internal: true);
    }

    // savedMemory corresponds to addresses [ramStart, ramStart + savedMemory.length)
    for (int i = 0; i < savedMemory.length; i++) {
      final addr = ramStart + i;
      if (addr >= _endMem) break;
      if (!isProtected(addr)) {
        final originalByte = readOriginalByte(addr);
        _memory[addr] = savedMemory[i] ^ originalByte;
      }
    }

    // Restore heap state
    _heap.applySummary(heapSummary, _endMem);
  }

  /// Restarts the memory map to its initial state.
  ///
  /// Spec Section 2.4.11: "restart: Restore VM to initial state."
  /// Spec Section 2.4.10: "The protected range ... is silently unaffected by the state-restoring operations."
  void restart() {
    // Deactivate the heap
    _heap.clear();

    // Reset memory size
    if (_endMem != origEndMem) {
      setMemorySize(origEndMem, internal: true);
    }

    // Reload RAM from original game data, respecting protection
    // Data from 0 to ramStart is ROM (already correct, but we reload to be sure)
    // Data from ramStart to extStart is initial RAM
    for (int i = ramStart; i < extStart && i < _originalGameData.length; i++) {
      if (!isProtected(i)) {
        _memory[i] = _originalGameData[i];
      }
    }

    // Above extStart is initialized to zero, respecting protection
    for (int i = extStart; i < origEndMem; i++) {
      if (!isProtected(i)) {
        _memory[i] = 0;
      }
    }
  }
}
