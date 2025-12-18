import 'dart:typed_data';

import 'package:zart/src/glulx/glulx_debugger.dart';
import 'package:zart/src/glulx/glulx_memory_map.dart';
import 'package:zart/src/glulx/glulx_op.dart';
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
    final operands = _fetchOperands(opcode, info, modes);

    _executeOpcode(opcode, operands);
  }

  /// Executes the given opcode with the provided operands.
  void _executeOpcode(int opcode, List<Object> operands) {
    switch (opcode) {
      /// Spec Section 2.4: "nop: Do nothing."
      case GlulxOp.nop:
        break;

      /// Spec Section 2.4.1: "add L1 L2 S1: Add L1 and L2, using standard 32-bit addition.
      /// Truncate the result to 32 bits if necessary. Store the result in S1."
      case GlulxOp.add:
        final l1 = operands[0] as int;
        final l2 = operands[1] as int;
        final dest = operands[2] as _StoreOperand;
        _performStore(dest, (l1 + l2) & 0xFFFFFFFF);
        break;

      /// Spec Section 2.4.1: "sub L1 L2 S1: Compute (L1 - L2), and store the result in S1."
      case GlulxOp.sub:
        final l1 = operands[0] as int;
        final l2 = operands[1] as int;
        final dest = operands[2] as _StoreOperand;
        _performStore(dest, (l1 - l2) & 0xFFFFFFFF);
        break;

      /// Spec Section 2.4.1: "mul L1 L2 S1: Compute (L1 * L2), and store the result in S1.
      /// Truncate the result to 32 bits if necessary."
      case GlulxOp.mul:
        final l1 = operands[0] as int;
        final l2 = operands[1] as int;
        final dest = operands[2] as _StoreOperand;
        _performStore(dest, (l1 * l2) & 0xFFFFFFFF);
        break;

      /// Spec Section 2.4.1: "div L1 L2 S1: Compute (L1 / L2), and store the result in S1.
      /// This is signed integer division. Division by zero is of course an error.
      /// So is dividing the value -0x80000000 by -1."
      case GlulxOp.div:
        final l1 = (operands[0] as int).toSigned(32);
        final l2 = (operands[1] as int).toSigned(32);
        final dest = operands[2] as _StoreOperand;
        if (l2 == 0) {
          throw Exception('Division by zero (Spec Section 2.4.1)');
        }
        if (l1 == -0x80000000 && l2 == -1) {
          throw Exception('Division overflow: -0x80000000 / -1 (Spec Section 2.4.1)');
        }
        _performStore(dest, (l1 ~/ l2) & 0xFFFFFFFF);
        break;

      /// Spec Section 2.4.1: "mod L1 L2 S1: Compute (L1 % L2), and store the result in S1.
      /// This is the remainder from signed integer division.
      /// As with division, taking the remainder modulo zero is an error, as is -0x80000000 % -1."
      /// Note: Dart's % operator is Euclidean modulo (sign of divisor).
      /// Glulx/C uses truncated remainder (sign matches dividend). Use .remainder().
      case GlulxOp.mod:
        final l1 = (operands[0] as int).toSigned(32);
        final l2 = (operands[1] as int).toSigned(32);
        final dest = operands[2] as _StoreOperand;
        if (l2 == 0) {
          throw Exception('Modulo by zero (Spec Section 2.4.1)');
        }
        if (l1 == -0x80000000 && l2 == -1) {
          throw Exception('Modulo overflow: -0x80000000 % -1 (Spec Section 2.4.1)');
        }
        _performStore(dest, l1.remainder(l2) & 0xFFFFFFFF);
        break;

      /// Spec Section 2.4.1: "neg L1 S1: Compute the negative of L1."
      case GlulxOp.neg:
        final l1 = operands[0] as int;
        final dest = operands[1] as _StoreOperand;
        _performStore(dest, (-l1) & 0xFFFFFFFF);
        break;

      /// Spec Section 2.4.2: "bitand L1 L2 S1: Compute the bitwise AND of L1 and L2."
      case GlulxOp.bitand:
        final l1 = operands[0] as int;
        final l2 = operands[1] as int;
        final dest = operands[2] as _StoreOperand;
        _performStore(dest, (l1 & l2) & 0xFFFFFFFF);
        break;

      /// Spec Section 2.4.2: "bitor L1 L2 S1: Compute the bitwise OR of L1 and L2."
      case GlulxOp.bitor:
        final l1 = operands[0] as int;
        final l2 = operands[1] as int;
        final dest = operands[2] as _StoreOperand;
        _performStore(dest, (l1 | l2) & 0xFFFFFFFF);
        break;

      /// Spec Section 2.4.2: "bitxor L1 L2 S1: Compute the bitwise XOR of L1 and L2."
      case GlulxOp.bitxor:
        final l1 = operands[0] as int;
        final l2 = operands[1] as int;
        final dest = operands[2] as _StoreOperand;
        _performStore(dest, (l1 ^ l2) & 0xFFFFFFFF);
        break;

      /// Spec Section 2.4.2: "bitnot L1 S1: Compute the bitwise negation of L1."
      case GlulxOp.bitnot:
        final l1 = operands[0] as int;
        final dest = operands[1] as _StoreOperand;
        _performStore(dest, (~l1) & 0xFFFFFFFF);
        break;

      /// Spec Section 2.4.2: "shiftl L1 L2 S1: Shift the bits of L1 to the left by L2 places.
      /// If L2 is 32 or more, the result is always zero."
      case GlulxOp.shiftl:
        final l1 = operands[0] as int;
        final l2 = operands[1] as int;
        final dest = operands[2] as _StoreOperand;
        // L2 is treated as unsigned per spec
        final shift = l2 & 0xFFFFFFFF;
        if (shift >= 32) {
          _performStore(dest, 0);
        } else {
          _performStore(dest, (l1 << shift) & 0xFFFFFFFF);
        }
        break;

      /// Spec Section 2.4.2: "ushiftr L1 L2 S1: Shift the bits of L1 to the right by L2 places.
      /// The top L2 bits are filled with zeroes. If L2 is 32 or more, the result is always zero."
      case GlulxOp.ushiftr:
        final l1 = operands[0] as int;
        final l2 = operands[1] as int;
        final dest = operands[2] as _StoreOperand;
        final shift = l2 & 0xFFFFFFFF;
        if (shift >= 32) {
          _performStore(dest, 0);
        } else {
          // Ensure unsigned shift by masking l1 to 32 bits
          _performStore(dest, ((l1 & 0xFFFFFFFF) >> shift) & 0xFFFFFFFF);
        }
        break;

      /// Spec Section 2.4.2: "sshiftr L1 L2 S1: Shift the bits of L1 to the right by L2 places.
      /// The top L2 bits are filled with copies of the top bit of L1.
      /// If L2 is 32 or more, the result is always zero or FFFFFFFF, depending on the top bit of L1."
      case GlulxOp.sshiftr:
        final l1 = (operands[0] as int).toSigned(32);
        final l2 = operands[1] as int;
        final dest = operands[2] as _StoreOperand;
        final shift = l2 & 0xFFFFFFFF;
        if (shift >= 32) {
          // Result depends on sign bit
          _performStore(dest, (l1 < 0) ? 0xFFFFFFFF : 0);
        } else {
          // Dart's >> on signed int does sign extension
          _performStore(dest, (l1 >> shift) & 0xFFFFFFFF);
        }
        break;

      // ========== Branch Opcodes (Spec Section 2.4.3) ==========

      /// Spec Section 2.4.3: "jump L1: Branch unconditionally to offset L1."
      case GlulxOp.jump:
        final offset = operands[0] as int;
        _performBranch(offset);
        break;

      /// Spec Section 2.4.3: "jz L1 L2: If L1 is equal to zero, branch to L2."
      case GlulxOp.jz:
        final l1 = operands[0] as int;
        final offset = operands[1] as int;
        if (l1 == 0) {
          _performBranch(offset);
        }
        break;

      /// Spec Section 2.4.3: "jnz L1 L2: If L1 is not equal to zero, branch to L2."
      case GlulxOp.jnz:
        final l1 = operands[0] as int;
        final offset = operands[1] as int;
        if (l1 != 0) {
          _performBranch(offset);
        }
        break;

      /// Spec Section 2.4.3: "jeq L1 L2 L3: If L1 is equal to L2, branch to L3."
      case GlulxOp.jeq:
        final l1 = operands[0] as int;
        final l2 = operands[1] as int;
        final offset = operands[2] as int;
        if (l1 == l2) {
          _performBranch(offset);
        }
        break;

      /// Spec Section 2.4.3: "jne L1 L2 L3: If L1 is not equal to L2, branch to L3."
      case GlulxOp.jne:
        final l1 = operands[0] as int;
        final l2 = operands[1] as int;
        final offset = operands[2] as int;
        if (l1 != l2) {
          _performBranch(offset);
        }
        break;

      /// Spec Section 2.4.3: "jlt L1 L2 L3: Branch if L1 < L2 (signed)"
      case GlulxOp.jlt:
        final l1 = (operands[0] as int).toSigned(32);
        final l2 = (operands[1] as int).toSigned(32);
        final offset = operands[2] as int;
        if (l1 < l2) {
          _performBranch(offset);
        }
        break;

      /// Spec Section 2.4.3: "jge L1 L2 L3: Branch if L1 >= L2 (signed)"
      case GlulxOp.jge:
        final l1 = (operands[0] as int).toSigned(32);
        final l2 = (operands[1] as int).toSigned(32);
        final offset = operands[2] as int;
        if (l1 >= l2) {
          _performBranch(offset);
        }
        break;

      /// Spec Section 2.4.3: "jgt L1 L2 L3: Branch if L1 > L2 (signed)"
      case GlulxOp.jgt:
        final l1 = (operands[0] as int).toSigned(32);
        final l2 = (operands[1] as int).toSigned(32);
        final offset = operands[2] as int;
        if (l1 > l2) {
          _performBranch(offset);
        }
        break;

      /// Spec Section 2.4.3: "jle L1 L2 L3: Branch if L1 <= L2 (signed)"
      case GlulxOp.jle:
        final l1 = (operands[0] as int).toSigned(32);
        final l2 = (operands[1] as int).toSigned(32);
        final offset = operands[2] as int;
        if (l1 <= l2) {
          _performBranch(offset);
        }
        break;

      /// Spec Section 2.4.3: "jltu L1 L2 L3: Branch if L1 < L2 (unsigned)"
      case GlulxOp.jltu:
        final l1 = (operands[0] as int) & 0xFFFFFFFF;
        final l2 = (operands[1] as int) & 0xFFFFFFFF;
        final offset = operands[2] as int;
        if (l1 < l2) {
          _performBranch(offset);
        }
        break;

      /// Spec Section 2.4.3: "jgeu L1 L2 L3: Branch if L1 >= L2 (unsigned)"
      case GlulxOp.jgeu:
        final l1 = (operands[0] as int) & 0xFFFFFFFF;
        final l2 = (operands[1] as int) & 0xFFFFFFFF;
        final offset = operands[2] as int;
        if (l1 >= l2) {
          _performBranch(offset);
        }
        break;

      /// Spec Section 2.4.3: "jgtu L1 L2 L3: Branch if L1 > L2 (unsigned)"
      case GlulxOp.jgtu:
        final l1 = (operands[0] as int) & 0xFFFFFFFF;
        final l2 = (operands[1] as int) & 0xFFFFFFFF;
        final offset = operands[2] as int;
        if (l1 > l2) {
          _performBranch(offset);
        }
        break;

      /// Spec Section 2.4.3: "jleu L1 L2 L3: Branch if L1 <= L2 (unsigned)"
      case GlulxOp.jleu:
        final l1 = (operands[0] as int) & 0xFFFFFFFF;
        final l2 = (operands[1] as int) & 0xFFFFFFFF;
        final offset = operands[2] as int;
        if (l1 <= l2) {
          _performBranch(offset);
        }
        break;

      default:
        throw Exception('Unimplemented opcode: 0x${opcode.toRadixString(16)}');
    }
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

  /// Performs a branch with the given offset.
  ///
  /// Spec Section 2.4.3: "The actual destination address of the branch is computed as
  /// (Addr + Offset - 2), where Addr is the address of the instruction *after* the branch opcode.
  /// The special offset values 0 and 1 are interpreted as 'return 0' and 'return 1' respectively."
  void _performBranch(int offset) {
    if (offset == 0 || offset == 1) {
      // Spec: "The special offset values 0 and 1 are interpreted as 'return 0' and 'return 1'"
      // This requires function return logic which needs call stub handling.
      // For now, we'll implement a simplified version that just flags the condition.
      // Full implementation will be done with call/return opcodes.
      throw Exception('Branch return ($offset) not yet implemented - needs call stub handling');
    } else {
      // Spec: "The actual destination address of the branch is computed as (Addr + Offset - 2)"
      // _pc is already at the instruction AFTER the branch, so we apply the offset directly.
      _pc = _pc + offset.toSigned(32) - 2;
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
