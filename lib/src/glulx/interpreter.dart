import 'dart:typed_data';

import 'package:zart/src/glulx/glulx_debugger.dart';
import 'package:zart/src/glulx/glulx_memory_map.dart';
import 'package:zart/src/glulx/glulx_stack.dart';
import 'package:zart/src/glulx/op_code_info.dart';
import 'package:zart/src/io/glk/glk_io_provider.dart';

/// The Glulx interpreter.
class GlulxInterpreter {
  /// The Glk Dispatcher Interface
  final GlkIoProvider glkDispatcher;

  /// Debugger
  final GlulxDebugger debugger = GlulxDebugger();

  /// The memory map for this interpreter.
  late GlulxMemoryMap memoryMap;

  /// The stack for this interpreter.
  late GlulxStack stack;

  int _pc = 0;

  /// The program counter.
  int get pc => _pc;

  /// Creates a new Glulx interpreter.
  GlulxInterpreter(this.glkDispatcher);

  /// Loads a game file into memory.
  Future<void> load(Uint8List gameData) async {
    memoryMap = GlulxMemoryMap(gameData);
    stack = GlulxStack(memoryMap.stackSize);
    _pc = memoryMap.ramStart;

    glkDispatcher.setMemoryAccess(
      write: (addr, val, {size = 1}) {
        if (size == 1) {
          memoryMap.writeByte(addr, val);
        } else if (size == 2) {
          memoryMap.writeShort(addr, val);
        } else if (size == 4) {
          memoryMap.writeWord(addr, val);
        }
      },
      read: (addr, {size = 1}) {
        if (size == 1) {
          return memoryMap.readByte(addr);
        } else if (size == 2) {
          return memoryMap.readShort(addr);
        } else if (size == 4) {
          return memoryMap.readWord(addr);
        }
        return 0;
      },
    );
  }

  /// Runs the interpreter.
  Future<void> run({int maxStep = GlulxDebugger.maxSteps}) async {
    /// interpreter code here
  }

  void executeInstruction() {
    final opcode = _readOpCode();
    final info = OpcodeInfo.get(opcode);
    final modes = _readAddressingModes(info.operandCount);
    // ignore: unused_local_variable
    final operands = _fetchOperands(opcode, info, modes);

    // Opcode dispatch would happen here.
  }

  /// Reads an opcode from the current PC.
  ///
  /// Spec Section 2.3.1: "The opcode number OP... may be packed into fewer than four bytes:
  /// 00..7F: One byte, OP; 0000..3FFF: Two bytes, OP+8000;
  /// 00000000..0FFFFFFF: Four bytes, OP+C0000000"
  int _readOpCode() {
    final first = _nextByte();
    if ((first & 0x80) == 0) {
      return first;
    } else if ((first & 0xC0) == 0x80) {
      final second = _nextByte();
      return ((first & 0x3F) << 8) | second;
    } else {
      final second = _nextByte();
      final third = _nextByte();
      final fourth = _nextByte();
      return ((first & 0x3F) << 24) | (second << 16) | (third << 8) | fourth;
    }
  }

  /// Reads addressing modes for the given number of operands.
  ///
  /// Spec Section 2.3.1: "Each is four bits long, and they are packed two to a byte.
  /// (They occur in the same order as the arguments, low bits first.)"
  List<int> _readAddressingModes(int count) {
    final modes = <int>[];
    for (var i = 0; i < count; i += 2) {
      final b = _nextByte();
      modes.add(b & 0x0F);
      if (i + 1 < count) {
        modes.add((b >> 4) & 0x0F);
      }
    }
    return modes;
  }

  int _nextByte() {
    final val = memoryMap.readByte(_pc);
    _pc++;
    return val;
  }

  int _nextShort() {
    final val = memoryMap.readShort(_pc);
    _pc += 2;
    return val;
  }

  int _nextWord() {
    final val = memoryMap.readWord(_pc);
    _pc += 4;
    return val;
  }

  int _nextInt() {
    final val = memoryMap.readWord(_pc).toSigned(32);
    _pc += 4;
    return val;
  }

  /// Loads an operand value based on the given addressing mode.
  ///
  /// Spec Section 2.3.1: Addressing Modes
  int loadOperand(int mode) {
    switch (mode) {
      case 0: // Constant zero.
        return 0;
      case 1: // Constant, -80 to 7F (1 byte).
        return _nextByte().toSigned(8);
      case 2: // Constant, -8000 to 7FFF (2 bytes).
        return _nextShort().toSigned(16);
      case 3: // Constant, any value (4 bytes).
        return _nextInt();
      case 5: // Contents of address 00 to FF (1 byte).
        return memoryMap.readWord(_nextByte());
      case 6: // Contents of address 0000 to FFFF (2 bytes).
        return memoryMap.readWord(_nextShort());
      case 7: // Contents of any address (4 bytes).
        return memoryMap.readWord(_nextWord());
      case 8: // Value popped off stack.
        return stack.pop32();
      case 0x9: // Call frame local at address 00 to FF (1 byte).
        return stack.readLocal32(_nextByte());
      case 0xA: // Call frame local at address 0000 to FFFF (2 bytes).
        return stack.readLocal32(_nextShort());
      case 0xB: // Call frame local at any address (4 bytes).
        return stack.readLocal32(_nextWord());
      case 0xD: // Contents of RAM address 00 to FF (1 byte).
        return memoryMap.readWord(memoryMap.ramStart + _nextByte());
      case 0xE: // Contents of RAM address 0000 to FFFF (2 bytes).
        return memoryMap.readWord(memoryMap.ramStart + _nextShort());
      case 0xF: // Contents of RAM, any address (4 bytes).
        return memoryMap.readWord(memoryMap.ramStart + _nextWord());
      default:
        throw Exception('Illegal load addressing mode: $mode');
    }
  }

  /// Stores a value to an operand based on the given addressing mode.
  ///
  /// Spec Section 2.3.1: Addressing Modes (Store)
  void storeOperand(int mode, int value) {
    switch (mode) {
      case 0: // Throw value away.
        break;
      case 5: // Contents of address 00 to FF (1 byte).
        memoryMap.writeWord(_nextByte(), value);
        break;
      case 6: // Contents of address 0000 to FFFF (2 bytes).
        memoryMap.writeWord(_nextShort(), value);
        break;
      case 7: // Contents of any address (4 bytes).
        memoryMap.writeWord(_nextWord(), value);
        break;
      case 8: // Value pushed into stack.
        stack.push32(value);
        break;
      case 0x9: // Call frame local at address 00 to FF (1 byte).
        stack.writeLocal32(_nextByte(), value);
        break;
      case 0xA: // Call frame local at address 0000 to FFFF (2 bytes).
        stack.writeLocal32(_nextShort(), value);
        break;
      case 0xB: // Call frame local at any address (4 bytes).
        stack.writeLocal32(_nextWord(), value);
        break;
      case 0xD: // Contents of RAM address 00 to FF (1 byte).
        memoryMap.writeWord(memoryMap.ramStart + _nextByte(), value);
        break;
      case 0xE: // Contents of RAM address 0000 to FFFF (2 bytes).
        memoryMap.writeWord(memoryMap.ramStart + _nextShort(), value);
        break;
      case 0xF: // Contents of RAM, any address (4 bytes).
        memoryMap.writeWord(memoryMap.ramStart + _nextWord(), value);
        break;
      default:
        throw Exception('Illegal store addressing mode: $mode');
    }
  }

  List<Object> _fetchOperands(int opcode, OpcodeInfo info, List<int> modes) {
    final operands = <Object>[];
    for (var i = 0; i < info.operandCount; i++) {
      final mode = modes[i];
      if (info.isStore(i)) {
        operands.add(_prepareStore(mode));
      } else {
        operands.add(loadOperand(mode));
      }
    }
    return operands;
  }

  _StoreOperand _prepareStore(int mode) {
    switch (mode) {
      case 0:
        return _StoreOperand(mode, 0);
      case 5:
      case 0x9:
      case 0xD:
        return _StoreOperand(mode, _nextByte());
      case 6:
      case 0xA:
      case 0xE:
        return _StoreOperand(mode, _nextShort());
      case 7:
      case 0xB:
      case 0xF:
        return _StoreOperand(mode, _nextWord());
      case 8:
        return _StoreOperand(mode, 0);
      default:
        throw Exception('Illegal store addressing mode: $mode');
    }
  }

  // ignore: unused_element
  void _performStore(_StoreOperand dest, int value) {
    switch (dest.mode) {
      case 0:
        break;
      case 5:
        memoryMap.writeWord(dest.addr, value);
        break;
      case 6:
        memoryMap.writeWord(dest.addr, value);
        break;
      case 7:
        memoryMap.writeWord(dest.addr, value);
        break;
      case 8:
        stack.push32(value);
        break;
      case 0x9:
        stack.writeLocal32(dest.addr, value);
        break;
      case 0xA:
        stack.writeLocal32(dest.addr, value);
        break;
      case 0xB:
        stack.writeLocal32(dest.addr, value);
        break;
      case 0xD:
        memoryMap.writeWord(memoryMap.ramStart + dest.addr, value);
        break;
      case 0xE:
        memoryMap.writeWord(memoryMap.ramStart + dest.addr, value);
        break;
      case 0xF:
        memoryMap.writeWord(memoryMap.ramStart + dest.addr, value);
        break;
    }
  }
}

class _StoreOperand {
  final int mode;
  final int addr;
  _StoreOperand(this.mode, this.addr);
}

/// Used by unit tests to access private members of [GlulxInterpreter].
class GlulxInterpreterTestingHarness {
  /// The interpreter to test.
  final GlulxInterpreter interpreter;

  /// Creates a new [GlulxInterpreterTestingHarness].
  GlulxInterpreterTestingHarness(this.interpreter);

  /// Manually sets the program counter.
  void setProgramCounter(int pc) {
    interpreter._pc = pc;
  }

  /// Exposes [_readOpCode] for testing.
  int readOpCode() => interpreter._readOpCode();

  /// Exposes [_readAddressingModes] for testing.
  List<int> readAddressingModes(int count) => interpreter._readAddressingModes(count);
}
