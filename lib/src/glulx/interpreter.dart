import 'dart:typed_data';

import 'package:zart/src/glulx/opcodes.dart';
import 'package:zart/src/io/io_provider.dart';

/// Exceptions specific to Glulx execution.
class GlulxException implements Exception {
  final String message;
  GlulxException(this.message);
  @override
  String toString() => 'GlulxException: $message';
}

/// Constants for the Glulx Header.
class GlulxHeader {
  static const int magicNumber = 0x00; // 'Glul'
  static const int version = 0x04;
  static const int ramStart = 0x08;
  static const int extStart = 0x0C;
  static const int endMem = 0x10;
  static const int stackSize = 0x14;
  static const int startFunc = 0x18;
  static const int decodingTbl = 0x1C;
  static const int checksum = 0x20;
  static const int size = 36;
}

class GlulxInterpreter {
  late ByteData _memory;
  // We keep the raw Uint8List for easy resizing/copying if needed, unique to Glulx memory model
  late Uint8List _rawMemory;

  // Registers
  int _pc = 0; // Program Counter
  int _sp = 0; // Stack Pointer
  int _fp = 0; // Frame Pointer

  late int _stackStart; // Where the stack technically begins in memory?
  // Glulx stack is separate from main memory in spec, but typically implemented as a separate array.
  // "The stack is an array of values. It is not a part of main memory; the terp maintains it separately."
  late ByteData _stack;

  // Header Info
  int _ramStart = 0;
  int _extStart = 0;
  int _endMem = 0;

  final IoProvider? io;

  GlulxInterpreter({this.io});

  void load(Uint8List gameBytes) {
    if (gameBytes.length < GlulxHeader.size) {
      throw GlulxException('File too small to be a Glulx game.');
    }

    final header = ByteData.sublistView(gameBytes);

    // Check Magic Number 'Glul' (0x476C756C)
    final magic = header.getUint32(GlulxHeader.magicNumber);
    if (magic != 0x476C756C) {
      throw GlulxException('Invalid Magic Number: ${magic.toRadixString(16)}');
    }

    _ramStart = header.getUint32(GlulxHeader.ramStart);
    _extStart = header.getUint32(GlulxHeader.extStart);
    _endMem = header.getUint32(GlulxHeader.endMem);
    final stackLen = header.getUint32(GlulxHeader.stackSize);
    final startFunc = header.getUint32(GlulxHeader.startFunc);

    // Initialize Memory
    // "The section marked ROM never changes... Glulx game-file only stores the data from 0 to EXTSTART."
    // "When the terp loads it in, it allocates memory up to ENDMEM; everything above EXTSTART is initialized to zeroes."

    // We allocate the full memory.
    _rawMemory = Uint8List(_endMem);

    // Copy file data up to extStart (or file length if smaller? Spec says file stores 0 to EXTSTART)
    // We should copy the whole gameBytes provided, but adhere to extStart.
    // Spec: "EXTSTART: The end of the game-file's stored initial memory (and therefore the length of the game file.)"
    int initialSize = gameBytes.length;
    if (initialSize > _extStart) initialSize = _extStart;

    for (int i = 0; i < initialSize; i++) {
      _rawMemory[i] = gameBytes[i];
    }
    // Zero out the rest is automatic in Uint8List new allocation, but explicit if needed.
    // Since we created new Uint8List, it's zeroed.

    _memory = ByteData.sublistView(_rawMemory);

    // Initialize Stack
    _stack = ByteData(stackLen);
    _sp = 0;
    _fp = 0;

    // Set PC
    _pc = startFunc;
  }

  Future<void> run() async {
    // Main Loop
    bool running = true;
    while (running) {
      // Fetch Opcode
      // Opcode can be 1, 2, or 4 bytes.
      // "00..7F: One byte, OP"
      // "0000..3FFF: Two bytes, OP+8000"
      // "00000000..0FFFFFFF: Four bytes, OP+C0000000"

      int opcode = _memRead8(_pc);
      int opLen = 1;

      if ((opcode & 0x80) == 0) {
        // 1 byte
        _pc += 1;
      } else if ((opcode & 0x40) == 0) {
        // 2 bytes
        opcode = ((opcode & 0x7F) << 8) | _memRead8(_pc + 1);
        opLen = 2;
        _pc += 2;
      } else {
        // 4 bytes
        opcode = ((opcode & 0x3F) << 24) | (_memRead8(_pc + 1) << 16) | (_memRead8(_pc + 2) << 8) | _memRead8(_pc + 3);
        opLen = 4;
        _pc += 4;
      }

      // Decode Operands
      final opInfo = OpcodeInfo.get(opcode);
      final operands = <int>[];
      final destTypes = <int>[]; // Store types for store operands, 0 for load

      if (opInfo.operandCount > 0) {
        // Mode bytes are stored contiguously after opcode
        int numModeBytes = (opInfo.operandCount + 1) ~/ 2;
        int modeStart = _pc; // Start of mode bytes
        _pc += numModeBytes; // PC now points to start of operand data

        for (int i = 0; i < opInfo.operandCount; i++) {
          int modeByte = _memRead8(modeStart + (i ~/ 2));
          int mode;
          if (i % 2 == 0) {
            mode = modeByte & 0x0F;
          } else {
            mode = (modeByte >> 4) & 0x0F;
          }
          _decodeOperand(mode, operands, destTypes, i, opInfo);
        }
      }

      // Execute Opcode
      switch (opcode) {
        case 0x00: // nop
          break;
        case 0x70: // streamchar
          // args: char
          final charCode = operands[0];
          // 0x81 is glk_put_char_stream
          // Default stream ID should be tracked, for now passing 0 or handling in provider
          // Actually, Glulx spec says streamchar uses "current output system".
          // If we assume Glk, we need the current stream.
          // Since we don't track stream yet, we'll send a custom selector or just 0x81 with implicit stream?
          // Let's assume provider handles "current stream" if we pass 0, or we pass a dummy.
          if (io != null) {
            // selector 0x51 = glk_put_char (to current stream) -- Wait, glk_put_char (0x81) takes stream_id.
            // glk_put_char_uni (0x82).
            // There is NO "put char to current stream" in Glk. VM tracks current stream.
            // We'll treat this as a generic "print char" command for now,
            // or define our own selector for "print to default/current".
            // Let's use 0x81 and stream 0 (assuming 0 is console/stdout if not mapped).
            io!.glulxGlk(0x81, [0, charCode]);
          } else {
            print(String.fromCharCode(charCode));
          }
          break;
        case 0x10: // add
          var val = (operands[0] + operands[1]) & 0xFFFFFFFF;
          _storeResult(destTypes[2], operands[2], val);
          break;
        case 0x11: // sub
          var val = (operands[0] - operands[1]) & 0xFFFFFFFF;
          _storeResult(destTypes[2], operands[2], val);
          break;
        case 0x12: // mul
          var val = (operands[0] * operands[1]) & 0xFFFFFFFF;
          _storeResult(destTypes[2], operands[2], val);
          break;
        case 0x13: // div
          if (operands[1] == 0) throw GlulxException('Division by zero');
          // Dart integer division ~/ works for signed 32-bit?
          // Glulx integers are signed 32-bit.
          // operands are Dart ints (64-bit). If they were decoded properly, they carry sign?
          // Operand decoding handles sign extension for 1, 2 bytes. 4 bytes is read as Int32?
          // My _memRead32 uses getUint32... so it returns unsigned.
          // I need to ensure inputs are treated as signed 32-bit for arithmetic.
          int op1 = operands[0].toSigned(32);
          int op2 = operands[1].toSigned(32);
          var val = (op1 ~/ op2);
          _storeResult(destTypes[2], operands[2], val);
          break;
        case 0x14: // mod
          // Remainder with sign of dividend
          int op1 = operands[0].toSigned(32);
          int op2 = operands[1].toSigned(32);
          if (op2 == 0) throw GlulxException('Division by zero');
          var val = op1.remainder(op2);
          _storeResult(destTypes[2], operands[2], val);
          break;
        case 0x15: // neg
          var val = (-operands[0]) & 0xFFFFFFFF;
          _storeResult(destTypes[1], operands[1], val);
          break;
        case 0x40: // copy
          _storeResult(destTypes[1], operands[1], operands[0]);
          break;

        case 0x18: // bitand
          var val = (operands[0] & operands[1]) & 0xFFFFFFFF;
          _storeResult(destTypes[2], operands[2], val);
          break;
        case 0x19: // bitor
          var val = (operands[0] | operands[1]) & 0xFFFFFFFF;
          _storeResult(destTypes[2], operands[2], val);
          break;
        case 0x1A: // bitxor
          var val = (operands[0] ^ operands[1]) & 0xFFFFFFFF;
          _storeResult(destTypes[2], operands[2], val);
          break;
        case 0x1B: // bitnot
          var val = (~operands[0]) & 0xFFFFFFFF;
          _storeResult(destTypes[1], operands[1], val);
          break;

        case 0x20: // jump
          _branch(operands[0]);
          break;
        case 0x22: // jz
          if (operands[0] == 0) _branch(operands[1]);
          break;
        case 0x23: // jnz
          if (operands[0] != 0) _branch(operands[1]);
          break;
        case 0x24: // jeq
          if (operands[0] == operands[1]) _branch(operands[2]);
          break;
        case 0x25: // jne
          if (operands[0] != operands[1]) _branch(operands[2]);
          break;

        case 0x26: // jlt (signed)
          if (operands[0].toSigned(32) < operands[1].toSigned(32)) _branch(operands[2]);
          break;
        case 0x27: // jge (signed)
          if (operands[0].toSigned(32) >= operands[1].toSigned(32)) _branch(operands[2]);
          break;
        case 0x28: // jgt
          if (operands[0].toSigned(32) > operands[1].toSigned(32)) _branch(operands[2]);
          break;
        case 0x29: // jle
          if (operands[0].toSigned(32) <= operands[1].toSigned(32)) _branch(operands[2]);
          break;

        case 0x2A: // jltu (unsigned)
          if ((operands[0] & 0xFFFFFFFF) < (operands[1] & 0xFFFFFFFF)) _branch(operands[2]);
          break;
        case 0x2B: // jgeu (unsigned)
          if ((operands[0] & 0xFFFFFFFF) >= (operands[1] & 0xFFFFFFFF)) _branch(operands[2]);
          break;

        case 0x120: // quit
          running = false;
          break;
        default:
          throw GlulxException('Unimplemented Opcode: 0x${opcode.toRadixString(16)} (Length: $opLen)');
      }
    }
  }

  void _decodeOperand(int mode, List<int> operands, List<int> destTypes, int opSkip, OpcodeInfo opInfo) {
    // For store operands, we need to know if this specific operand index is a store.
    // OpcodeInfo needs to tell us which operands are stores.
    // However, the addressing mode determines how we read/write.
    // But we need to know whether to READ the value now, or just calculate the address.
    // "Some opcodes store values... Store operands use the same addressing modes... 8: pushed on stack instead of popped."

    bool isStore = opInfo.isStore(opSkip);

    int value = 0;

    switch (mode) {
      case 0x0: // Constant zero / Discard (store)
        value = 0;
        break;
      case 0x1: // Constant 1 byte
        value = _memRead8(_pc);
        if (value > 127) value -= 256; // Sign extend
        _pc++;
        break;
      case 0x2: // Constant 2 bytes
        value = (_memRead8(_pc) << 8) | _memRead8(_pc + 1);
        if (value > 32767) value -= 65536; // Sign extend
        _pc += 2;
        break;
      case 0x3: // Constant 4 bytes
        value = (_memRead8(_pc) << 24) | (_memRead8(_pc + 1) << 16) | (_memRead8(_pc + 2) << 8) | _memRead8(_pc + 3);
        _pc += 4;
        break;

      case 0x5: // Address 00-FF
        value = _memRead8(_pc++);
        if (!isStore) value = _memRead32(value);
        break;
      case 0x6: // Address 0000-FFFF
        value = (_memRead8(_pc) << 8) | _memRead8(_pc + 1);
        _pc += 2;
        if (!isStore) value = _memRead32(value);
        break;
      case 0x7: // Address any
        value = (_memRead8(_pc) << 24) | (_memRead8(_pc + 1) << 16) | (_memRead8(_pc + 2) << 8) | _memRead8(_pc + 3);
        _pc += 4;
        if (!isStore) value = _memRead32(value);
        break;

      case 0x8: // Stack
        if (isStore) {
          value = 0; // Stack push, value irrelevant for address
        } else {
          value = _pop();
        }
        break;

      case 0x9: // callf (Local byte offset)
        value = _memRead8(_pc++);
        if (!isStore)
          value = _memRead32(_fp + value);
        else
          value = _fp + value; // Address for storing
        break;
      case 0xA: // callf (Local short offset)
        value = (_memRead8(_pc) << 8) | _memRead8(_pc + 1);
        _pc += 2;
        if (!isStore)
          value = _memRead32(_fp + value);
        else
          value = _fp + value;
        break;
      case 0xB: // callf (Local int offset)
        value = (_memRead8(_pc) << 24) | (_memRead8(_pc + 1) << 16) | (_memRead8(_pc + 2) << 8) | _memRead8(_pc + 3);
        _pc += 4;
        if (!isStore)
          value = _memRead32(_fp + value);
        else
          value = _fp + value;
        break;

      case 0xD: // RAM byte offset
        value = _memRead8(_pc++);
        value = _ramStart + value;
        if (!isStore) value = _memRead32(value);
        break;
      case 0xE: // RAM short offset
        value = (_memRead8(_pc) << 8) | _memRead8(_pc + 1);
        _pc += 2;
        value = _ramStart + value;
        if (!isStore) value = _memRead32(value);
        break;
      case 0xF: // RAM int offset
        value = (_memRead8(_pc) << 24) | (_memRead8(_pc + 1) << 16) | (_memRead8(_pc + 2) << 8) | _memRead8(_pc + 3);
        _pc += 4; // _ramStart is uint32, so this wraps naturally if it overflows? Dart int is 64-bit.
        value = (_ramStart + value) & 0xFFFFFFFF; // Ensure 32-bit wrapping?
        if (!isStore) value = _memRead32(value);
        break;

      default:
        throw GlulxException('Unsupported Addressing Mode: $mode');
    }

    // If it's a store operand, we push the "address" (or indicator) to operands.
    // If it's a load operand, we pushed the value.
    operands.add(value);
    destTypes.add(isStore ? mode : -1);
  }

  // Stack Helpers
  int _pop() {
    if (_sp == 0) throw GlulxException('Stack Underflow');
    _sp -= 4;
    return _stack.getUint32(_sp);
  }

  void _push(int value) {
    if (_sp + 4 > _stack.lengthInBytes) throw GlulxException('Stack Overflow');
    _stack.setUint32(_sp, value);
    _sp += 4;
  }

  // Memory Helper Methods
  int _memRead8(int addr) {
    if (addr >= _rawMemory.length) return 0; // OOB
    return _rawMemory[addr];
  }

  int _memRead32(int addr) {
    if (addr + 4 > _rawMemory.length) return 0;
    return _memory.getUint32(addr);
  }

  void _memWrite8(int addr, int value) {
    if (addr >= _rawMemory.length) return;
    _rawMemory[addr] = value & 0xFF;
  }

  void _memWrite16(int addr, int value) {
    if (addr + 2 > _rawMemory.length) return;
    _memory.setUint16(addr, value);
  }

  void _memWrite32(int addr, int value) {
    if (addr + 4 > _rawMemory.length) return;
    _memory.setUint32(addr, value);
  }

  void _storeResult(int mode, int address, int value) {
    // Ensure value is 32-bit (signed or unsigned doesn't matter for storage bits)
    value &= 0xFFFFFFFF;

    switch (mode) {
      case 0x0: // Discard
        break;
      case 0x8: // Stack
        _push(value);
        break;

      case 0x5: // Address 00-FF (Address provided in 'address')
      case 0x6: // Address 0000-FFFF
      case 0x7: // Address Any
      case 0xD: // RAM 00-FF
      case 0xE: // RAM 0000-FFFF
      case 0xF: // RAM Any
      case 0x9: // Local 00-FF
      case 0xA: // Local 0000-FFFF
      case 0xB: // Local Any
        // address was calculated during decodeOperand
        // For locals involving FP, calculate address in decode?
        // Yes, my _decodeOperand implementation for Mode 9,A,B, D,E,F writes the calculated address to 'operands' if isStore=true.
        _memWrite32(address, value);
        break;

      default:
        throw GlulxException('Unsupported Store Mode: $mode');
    }
  }

  void _branch(int offset) {
    // Offset 0 and 1 are special returns
    if (offset == 0 || offset == 1) {
      // Return from function with value 0 or 1
      // We haven't implemented stack frames fully yet, so we can't pop frame.
      // For now, if we are in main, this terminates?
      // Actually, we should check _fp or call stack depth.
      throw GlulxException('Return values (0/1) not yet implemented for branching.');
    } else {
      // Offset is from instruction *after* branch.
      // _pc is already there. Assumes offset is signed 32-bit.
      // But operands might be unsigned if larger than 0x7FFFFFFF?
      // We should treat offset as signed.
      _pc += offset.toSigned(32); // Wait, offset is "destType". In jump it is operand 0.
      // Wait, jump(0x20) L1. OpcodeInfo says input.
      // My decode logic puts it in operands[0].
      // We assume it's correctly sign extended if it was a constant?
      // 1/2 byte constants are sign extended. 4 byte constants are not in my code (bug?)
      // Constant 4 bytes: `value` is loaded by shifting bytes.
      // Dart ints are 64 bit.
      // `(_memRead8(_pc) << 24)...`
      // This builds a positive number if high bit is set?
      // `<< 24` on 0xFF puts it at bits 24-31.
      // Dart int is 64 bit. `0xFF << 24` is positive.
      // So my constant decoder produces unsigned 32-bit for 4-byte constants.
      // But offsets are signed.
      // So I must toSigned(32) the offset.
    }
  }
}

class OpcodeInfo {
  final int operandCount;
  // Bitmask or list indicating which operands are stores?
  // Usually only the last one is a store in Glulx, but not always.
  // Spec: "L1 L2 S1".
  final List<bool> _stores;

  OpcodeInfo(this.operandCount, this._stores);

  bool isStore(int index) {
    if (index >= _stores.length) return false;
    return _stores[index];
  }

  static final Map<int, OpcodeInfo> _opcodes = {
    GlulxOpcodes.nop: OpcodeInfo(0, []), // nop
    GlulxOpcodes.add: OpcodeInfo(3, [false, false, true]), // add
    GlulxOpcodes.sub: OpcodeInfo(3, [false, false, true]), // sub
    GlulxOpcodes.mul: OpcodeInfo(3, [false, false, true]), // mul
    GlulxOpcodes.div: OpcodeInfo(3, [false, false, true]), // div
    GlulxOpcodes.mod: OpcodeInfo(3, [false, false, true]), // mod
    GlulxOpcodes.neg: OpcodeInfo(2, [false, true]), // neg
    GlulxOpcodes.bitand: OpcodeInfo(3, [false, false, true]), // bitand
    GlulxOpcodes.bitor: OpcodeInfo(3, [false, false, true]), // bitor
    GlulxOpcodes.bitxor: OpcodeInfo(3, [false, false, true]), // bitxor
    GlulxOpcodes.bitnot: OpcodeInfo(2, [false, true]), // bitnot
    GlulxOpcodes.jump: OpcodeInfo(1, [false]), // jump
    GlulxOpcodes.jz: OpcodeInfo(2, [false, false]), // jz
    GlulxOpcodes.jnz: OpcodeInfo(2, [false, false]), // jnz
    GlulxOpcodes.jeq: OpcodeInfo(3, [false, false, false]), // jeq
    GlulxOpcodes.jne: OpcodeInfo(3, [false, false, false]), // jne
    GlulxOpcodes.jlt: OpcodeInfo(3, [false, false, false]), // jlt
    GlulxOpcodes.jge: OpcodeInfo(3, [false, false, false]), // jge
    GlulxOpcodes.jgt: OpcodeInfo(3, [false, false, false]), // jgt
    GlulxOpcodes.jle: OpcodeInfo(3, [false, false, false]), // jle
    GlulxOpcodes.jltu: OpcodeInfo(3, [false, false, false]), // jltu
    GlulxOpcodes.jgeu: OpcodeInfo(3, [false, false, false]), // jgeu
    GlulxOpcodes.call: OpcodeInfo(3, [false, false, true]), // call
    GlulxOpcodes.ret: OpcodeInfo(1, [false]), // return
    GlulxOpcodes.copy: OpcodeInfo(2, [false, true]), // copy
    GlulxOpcodes.copys: OpcodeInfo(2, [false, true]), // copys
    GlulxOpcodes.copyb: OpcodeInfo(2, [false, true]), // copyb
    GlulxOpcodes.streamchar: OpcodeInfo(1, [false]), // streamchar
    GlulxOpcodes.quit: OpcodeInfo(0, []), // quit
    GlulxOpcodes.glk: OpcodeInfo(3, [false, false, true]), // glk
  };

  static OpcodeInfo get(int opcode) {
    return _opcodes[opcode] ?? OpcodeInfo(0, []);
    // Default 0 operands to avoid crash, will likely fail execution if it was supposed to have operands.
  }
}
