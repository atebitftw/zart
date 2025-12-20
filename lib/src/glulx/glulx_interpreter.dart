import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:zart/src/glulx/glulx_debugger.dart';
import 'package:zart/src/glulx/glulx_exception.dart';
import 'package:zart/src/glulx/glulx_function.dart';
import 'package:zart/src/glulx/glulx_header.dart';
import 'package:zart/src/glulx/glulx_memory_map.dart';
import 'package:zart/src/glulx/glulx_op.dart';
import 'package:zart/src/glulx/glulx_stack.dart';
import 'package:zart/src/glulx/op_code_info.dart';
import 'package:zart/src/glulx/glulx_string_decoder.dart';
import 'package:zart/src/glulx/xoshiro128.dart';
import 'package:zart/src/io/glk/glk_io_selectors.dart';
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

  int _step = 0;

  /// The step counter.
  int get step => _step;

  /// xoshiro128** random number generator.
  /// Spec Section 2.4.9 / Reference: osdepend.c
  final Xoshiro128 _random = Xoshiro128();
  late GlulxStringDecoder _stringDecoder;

  final Float32List _f32 = Float32List(1);
  late Uint32List _u32 = _f32.buffer.asUint32List();

  final Float64List _f64 = Float64List(1);
  late Uint32List _u32_64 = _f64.buffer.asUint32List();

  int _fsetroundMode = 0; // 0=nearest, 1=zero, 2=posinf, 3=neginf

  /// Creates a new Glulx interpreter.
  GlulxInterpreter(this.glkDispatcher) {
    glkDispatcher.debugger = debugger;
  }

  /// Loads a game file into memory.
  Future<void> load(Uint8List gameData) async {
    memoryMap = GlulxMemoryMap(gameData);
    glkDispatcher.setVMState(getHeapStart: () => memoryMap.heapStart);
    final header = GlulxHeader(memoryMap.rawMemory);
    _stringTableAddress = header.decodingTbl;
    _stringDecoder = GlulxStringDecoder(memoryMap);
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

    glkDispatcher.setStackAccess(push: (val) => stack.push32(val), pop: () => stack.pop32());
  }

  /// Whether the program has finished execution.
  bool _quit = false;

  /// I/O system mode (0=None, 1=Filter, 2=Glk).
  /// Spec: "setiosys L1 L2: Set the I/O system mode and rock."
  int _iosysMode = 0;

  /// I/O system rock (function address for filter mode).
  int _iosysRock = 0;

  /// String-decoding table address.
  int _stringTableAddress = 0;

  /// Runs the interpreter.
  ///
  /// Spec: "Execution commences by calling this function."
  /// The start function is found in the header at offset 0x18.
  Future<void> run({int maxStep = GlulxDebugger.maxSteps}) async {
    try {
      // Get the start function address from the header
      final header = GlulxHeader(memoryMap.rawMemory);
      final startFunc = header.startFunc;

      // Reset quit flag
      _quit = false;

      // Enter the start function directly with 0 arguments (no call stub)
      // This matches the C reference: enter_function(startfuncaddr, 0, NULL)
      // Unlike regular calls, the startup function has no caller to return to.
      _enterFunction(startFunc, []);

      // Main execution loop
      int steps = 0;
      while (!_quit && (maxStep == -1 || steps < maxStep)) {
        final instructionPc = _pc;
        debugger.step = steps; // Sync debugger step for step-aware logging
        try {
          final result = executeInstruction();
          _step++;
          if (result is Future<void>) {
            await result;
          }
        } catch (e, stackTrace) {
          debugger.bufferedLog('Error at PC=0x${instructionPc.toRadixString(16)}, step=$steps: $e');
          debugger.bufferedLog('Stack trace: $stackTrace');
          print('Saving debug data to log...');
          debugger.flushLogs();
          print('Finished saving debug data.');
          rethrow;
        }
        steps++;
      }

      if (maxStep != -1 && steps >= maxStep) {
        debugger.bufferedLog('Interpreter -> Max steps ($maxStep) exceeded. Terminating.');
        print('Saving debug data to log...');
        debugger.flushLogs();
        print('Finished saving debug data.');
        return;
      }
    } catch (e, stackTrace) {
      if (e is! GlulxException && e is! Exception) {
        // If it's something else (like TypeError) and we haven't already logged it
        // in the inner loop, log it here.
        debugger.bufferedLog('Fatal error in runner: $e');
        debugger.bufferedLog('Stack trace: $stackTrace');
      }

      if (debugger.enabled && debugger.showFlightRecorder) {
        debugger.dumpFlightRecorder();
      }
      print('Saving debug data to log...');
      debugger.flushLogs();
      print('Finished saving debug data.');
      rethrow;
    }
  }

  /// Executes a single instruction at the current program counter.
  FutureOr<void> executeInstruction() {
    final opcode = _readOpCode();
    final info = OpcodeInfo.get(opcode);
    final modes = _readAddressingModes(info.operandCount);
    final operands = _fetchOperands(opcode, info, modes);

    if (debugger.enabled && debugger.showInstructions) {
      debugger.bufferedLog(
        'Interpreter -> PC=0x${pc.toRadixString(16)}, step=$step: $opcode(${GlulxDebugger.getOpcodeName(opcode)}) operands: [${operands.join(', ')}] ($info)',
      );
    }

    if (debugger.enabled && debugger.showFlightRecorder) {
      debugger.flightRecorderEvent(
        'Interpreter -> PC=0x${pc.toRadixString(16)}, $opcode(${GlulxDebugger.getOpcodeName(opcode)}) operands: [${operands.join(', ')}] ($info)',
      );
    }

    return _executeOpcode(opcode, operands);
  }

  // / Executes the given opcode with the provided operands.
  FutureOr<void> _executeOpcode(int opcode, List<Object> operands) {
    switch (opcode) {
      /// Spec Section 2.4: "nop: Do nothing."
      case GlulxOp.nop:
        break;

      /// Spec Section 2.4.1: "add L1 L2 S1: Add L1 and L2, using standard 32-bit addition.
      /// Truncate the result to 32 bits if necessary. Store the result in S1."
      case GlulxOp.add:
        final l1 = operands[0] as int;
        final l2 = operands[1] as int;
        final dest = operands[2] as StoreOperand;
        _performStore(dest, (l1 + l2) & 0xFFFFFFFF);
        break;

      /// Spec Section 2.4.1: "sub L1 L2 S1: Compute (L1 - L2), and store the result in S1."
      case GlulxOp.sub:
        final l1 = operands[0] as int;
        final l2 = operands[1] as int;
        final dest = operands[2] as StoreOperand;
        _performStore(dest, (l1 - l2) & 0xFFFFFFFF);
        break;

      /// Spec Section 2.4.1: "mul L1 L2 S1: Compute (L1 * L2), and store the result in S1.
      /// Truncate the result to 32 bits if necessary."
      case GlulxOp.mul:
        final l1 = operands[0] as int;
        final l2 = operands[1] as int;
        final dest = operands[2] as StoreOperand;
        _performStore(dest, (l1 * l2) & 0xFFFFFFFF);
        break;

      /// Spec Section 2.4.1: "div L1 L2 S1: Compute (L1 / L2), and store the result in S1.
      /// This is signed integer division. Division by zero is of course an error.
      /// So is dividing the value -0x80000000 by -1."
      case GlulxOp.div:
        final l1 = (operands[0] as int).toSigned(32);
        final l2 = (operands[1] as int).toSigned(32);
        final dest = operands[2] as StoreOperand;
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
        final dest = operands[2] as StoreOperand;
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
        final dest = operands[1] as StoreOperand;
        _performStore(dest, (-l1) & 0xFFFFFFFF);
        break;

      /// Spec Section 2.4.2: "bitand L1 L2 S1: Compute the bitwise AND of L1 and L2."
      case GlulxOp.bitand:
        final l1 = operands[0] as int;
        final l2 = operands[1] as int;
        final dest = operands[2] as StoreOperand;
        _performStore(dest, (l1 & l2) & 0xFFFFFFFF);
        break;

      /// Spec Section 2.4.2: "bitor L1 L2 S1: Compute the bitwise OR of L1 and L2."
      case GlulxOp.bitor:
        final l1 = operands[0] as int;
        final l2 = operands[1] as int;
        final dest = operands[2] as StoreOperand;
        _performStore(dest, (l1 | l2) & 0xFFFFFFFF);
        break;

      /// Spec Section 2.4.2: "bitxor L1 L2 S1: Compute the bitwise XOR of L1 and L2."
      case GlulxOp.bitxor:
        final l1 = operands[0] as int;
        final l2 = operands[1] as int;
        final dest = operands[2] as StoreOperand;
        _performStore(dest, (l1 ^ l2) & 0xFFFFFFFF);
        break;

      /// Spec Section 2.4.2: "bitnot L1 S1: Compute the bitwise negation of L1."
      case GlulxOp.bitnot:
        final l1 = operands[0] as int;
        final dest = operands[1] as StoreOperand;
        _performStore(dest, (~l1) & 0xFFFFFFFF);
        break;

      /// Spec Section 2.4.2: "shiftl L1 L2 S1: Shift the bits of L1 to the left by L2 places.
      /// If L2 is 32 or more, the result is always zero."
      case GlulxOp.shiftl:
        final l1 = operands[0] as int;
        final l2 = operands[1] as int;
        final dest = operands[2] as StoreOperand;
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
        final dest = operands[2] as StoreOperand;
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
        final dest = operands[2] as StoreOperand;
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

      /// Spec: "jumpabs L1: Branch unconditionally to address L1."
      /// Unlike jump, this uses an absolute address rather than a relative offset.
      case GlulxOp.jumpabs:
        final address = operands[0] as int;
        _pc = address;
        break;

      // ========== Function Call Opcodes (Spec Section 2.4.4) ==========

      /// Spec Section 2.4.4: "call L1 L2 S1: Call function whose address is L1,
      /// passing in L2 arguments, and store the return result at S1."
      case GlulxOp.call:
        final address = operands[0] as int;
        final argCount = operands[1] as int;
        final dest = operands[2] as StoreOperand;
        // Pop args from stack (pushed in reverse order by caller)
        final args = <int>[];
        for (var i = 0; i < argCount; i++) {
          args.add(stack.pop32());
        }
        _callFunction(address, args, dest);
        break;

      /// Spec Section 2.4.4: "callf L1 S1: Call function with 0 arguments."
      case GlulxOp.callf:
        final address = operands[0] as int;
        final dest = operands[1] as StoreOperand;
        _callFunction(address, [], dest);
        break;

      /// Spec Section 2.4.4: "callfi L1 L2 S1: Call function with 1 argument."
      case GlulxOp.callfi:
        final address = operands[0] as int;
        final arg1 = operands[1] as int;
        final dest = operands[2] as StoreOperand;
        _callFunction(address, [arg1], dest);
        break;

      /// Spec Section 2.4.4: "callfii L1 L2 L3 S1: Call function with 2 arguments."
      case GlulxOp.callfii:
        final address = operands[0] as int;
        final arg1 = operands[1] as int;
        final arg2 = operands[2] as int;
        final dest = operands[3] as StoreOperand;
        _callFunction(address, [arg1, arg2], dest);
        break;

      /// Spec Section 2.4.4: "callfiii L1 L2 L3 L4 S1: Call function with 3 arguments."
      case GlulxOp.callfiii:
        final address = operands[0] as int;
        final arg1 = operands[1] as int;
        final arg2 = operands[2] as int;
        final arg3 = operands[3] as int;
        final dest = operands[4] as StoreOperand;
        _callFunction(address, [arg1, arg2, arg3], dest);
        break;

      /// Spec Section 2.4.4: "return L1: Return from the current function."
      case GlulxOp.ret:
        final value = operands[0] as int;
        _returnValue(value);
        break;

      /// Spec Section 2.4.4: "tailcall L1 L2: Call function, passing return result out."
      case GlulxOp.tailcall:
        final address = operands[0] as int;
        final argCount = operands[1] as int;

        // 1. Pop arguments from the top of the current stack.
        // These are the arguments to the function we are tailcalling into.
        final args = <int>[];
        for (var i = 0; i < argCount; i++) {
          args.add(stack.pop32());
        }

        // 2. Discard the current frame by resetting SP to FP.
        // Spec: "This destroys the current call-frame... but does not touch the
        // call stub below that."
        stack.sp = stack.fp;

        // 3. Enter the new function at the same stack position.
        // The call stub below FP remains unchanged and will be used when the
        // tailcalled function eventually returns.
        _enterFunction(address, args);
        break;

      /// Spec Section 2.4.4: "catch S1 L1: Generate catch token, branch to L1."
      case GlulxOp.catchEx:
        final dest = operands[0] as StoreOperand;
        final offset = operands[1] as int;
        // Convert addressing mode to call stub DestType/DestAddr
        // Spec Section 1.4.1: DestType 0=discard, 1=memory, 2=local, 3=stack
        final destType = _modeToDestType(dest.mode);
        final destAddr = _modeToDestAddr(dest.mode, dest.addr);
        // Push call stub (for throw to restore)
        stack.pushCallStub(destType, destAddr, _pc, stack.fp);
        // Token is current SP after pushing the stub
        final token = stack.sp;
        // Store token in destination
        _performStore(dest, token);
        // Branch to offset
        _performBranch(offset);
        break;

      /// Spec Section 2.4.4: "throw L1 L2: Jump back to catch with value L1, token L2."
      /// Reference: exec.c case op_throw - stackptr = token; pop_callstub(value);
      case GlulxOp.throwEx:
        final value = operands[0] as int;
        final token = operands[1] as int;
        // Restore stack pointer to the token position (per C reference: stackptr = token)
        stack.sp = token;
        // Pop call stub (just reads the 4 values)
        final stub = stack.popCallStub();
        // Restore frame pointer and cached bases (per C pop_callstub: frameptr = newframeptr)
        stack.restoreFp(stub[3]);
        // Store thrown value in destination
        stack.storeResult(
          value,
          stub[0],
          stub[1],
          onMemoryWrite: (addr, val) {
            memoryMap.writeWord(addr, val);
          },
        );
        // Continue with instruction after catch
        _pc = stub[2];
        break;

      // ========== Miscellaneous Opcodes (Spec Section 2.4.5) ==========

      /// Spec Section 2.4.5: "quit: Exit the program immediately."
      case GlulxOp.quit:
        _quit = true;
        if (debugger.enabled && debugger.showFlightRecorder) {
          debugger.dumpFlightRecorder();
        }
        break;

      /// Spec Section 2.4.5: "gestalt L1 L2 S1: Query capability L1."
      case GlulxOp.gestalt:
        final selector = operands[0] as int;
        final arg = operands[1] as int;
        final dest = operands[2] as StoreOperand;
        _performStore(dest, _doGestalt(selector, arg));
        break;

      // ========== I/O System Opcodes ==========

      /// Spec: "setiosys L1 L2: Set the I/O system mode and rock."
      /// Mode 0 = None (null I/O, output is discarded)
      /// Mode 1 = Filter (output is passed to function at address L2)
      /// Mode 2 = Glk (output goes to Glk library)
      case GlulxOp.setiosys:
        _setIosys(operands[0] as int, operands[1] as int);
        break;

      /// Spec: "getiosys S1 S2: Get the current I/O system mode and rock."
      case GlulxOp.getiosys:
        final modeDest = operands[0] as StoreOperand;
        final rockDest = operands[1] as StoreOperand;
        _performStore(modeDest, _iosysMode);
        _performStore(rockDest, _iosysRock);
        break;

      // ========== Copy Opcodes ==========

      /// Spec: "copy L1 S1: Copy L1 directly to storage S1."
      case GlulxOp.copy:
        final value = operands[0] as int;
        final dest = operands[1] as StoreOperand;
        _performStore(dest, value);
        break;

      /// Spec: "copys L1 S1: Read a 16-bit value and store it."
      /// The value is truncated to 16 bits when storing.
      case GlulxOp.copys:
        final value = operands[0] as int;
        final dest = operands[1] as StoreOperand;
        _performStoreS(dest, value & 0xFFFF);
        break;

      /// Spec: "copyb L1 S1: Read an 8-bit value and store it."
      /// The value is truncated to 8 bits when storing.
      case GlulxOp.copyb:
        final value = operands[0] as int;
        final dest = operands[1] as StoreOperand;
        _performStoreB(dest, value & 0xFF);
        break;

      case GlulxOp.sexb:
        final val = (operands[0] as int) & 0xFF;
        _performStore(operands[1] as StoreOperand, val.toSigned(8));
        break;

      case GlulxOp.sexs:
        final val = (operands[0] as int) & 0xFFFF;
        _performStore(operands[1] as StoreOperand, val.toSigned(16));
        break;

      // ========== Glk Opcode ==========

      /// Spec: "glk L1 L2 S1: Call the Glk API."
      /// L1 = Glk selector, L2 = argument count, S1 = result store
      /// Arguments are popped from the stack in reverse order.
      // ========== Array Opcodes (Spec Section 2.4.6) ==========

      /// Spec Section 2.4.6: "aload L1 L2 S1: Load a 32-bit value from (L1+4*L2)."
      case GlulxOp.aload:
        final addr = operands[0] as int;
        final index = (operands[1] as int).toSigned(32);
        final dest = operands[2] as StoreOperand;
        _performStore(dest, memoryMap.readWord(addr + 4 * index));
        break;

      /// Spec Section 2.4.6: "aloads L1 L2 S1: Load a 16-bit value from (L1+2*L2)."
      case GlulxOp.aloads:
        final addr = operands[0] as int;
        final index = (operands[1] as int).toSigned(32);
        final dest = operands[2] as StoreOperand;
        _performStore(dest, memoryMap.readShort(addr + 2 * index));
        break;

      /// Spec Section 2.4.6: "aloadb L1 L2 S1: Load an 8-bit value from (L1+L2)."
      case GlulxOp.aloadb:
        final addr = operands[0] as int;
        final index = (operands[1] as int).toSigned(32);
        final dest = operands[2] as StoreOperand;
        _performStore(dest, memoryMap.readByte(addr + index));
        break;

      /// Spec Section 2.4.6: "aloadbit L1 L2 S1: Test a single bit."
      case GlulxOp.aloadbit:
        final addr = operands[0] as int;
        final index = (operands[1] as int).toSigned(32);
        final dest = operands[2] as StoreOperand;
        final byteAddr = addr + (index >> 3);
        final bitPos = index & 7;
        final val = memoryMap.readByte(byteAddr);
        _performStore(dest, (val & (1 << bitPos)) != 0 ? 1 : 0);
        break;

      /// Spec Section 2.4.6: "astore L1 L2 L3: Store L3 into (L1+4*L2)."
      case GlulxOp.astore:
        final addr = operands[0] as int;
        final index = (operands[1] as int).toSigned(32);
        final val = operands[2] as int;
        memoryMap.writeWord(addr + 4 * index, val);
        break;

      /// Spec Section 2.4.6: "astores L1 L2 L3: Store L3 into (L1+2*L2)."
      case GlulxOp.astores:
        final addr = operands[0] as int;
        final index = (operands[1] as int).toSigned(32);
        final val = operands[2] as int;
        memoryMap.writeShort(addr + 2 * index, val & 0xFFFF);
        break;

      /// Spec Section 2.4.6: "astoreb L1 L2 L3: Store L3 into (L1+L2)."
      case GlulxOp.astoreb:
        final addr = operands[0] as int;
        final index = (operands[1] as int).toSigned(32);
        final val = operands[2] as int;
        memoryMap.writeByte(addr + index, val & 0xFF);
        break;

      /// Spec Section 2.4.6: "astorebit L1 L2 L3: Set or clear a single bit."
      case GlulxOp.astorebit:
        final addr = operands[0] as int;
        final index = (operands[1] as int).toSigned(32);
        final set = (operands[2] as int) != 0;
        final byteAddr = addr + (index >> 3);
        final bitPos = index & 7;
        var val = memoryMap.readByte(byteAddr);
        if (set) {
          val |= (1 << bitPos);
        } else {
          val &= ~(1 << bitPos);
        }
        memoryMap.writeByte(byteAddr, val);
        break;

      // ========== Stack Management Opcodes (Spec Section 2.4.7) ==========

      /// Spec Section 2.4.7: "stkcount S1: Store a count of values on the stack."
      case GlulxOp.stkcount:
        final dest = operands[0] as StoreOperand;
        _performStore(dest, stack.stkCount);
        break;

      /// Spec Section 2.4.7: "stkpeek L1 S1: Peek at the L1'th value on the stack."
      case GlulxOp.stkpeek:
        final index = operands[0] as int;
        final dest = operands[1] as StoreOperand;
        _performStore(dest, stack.peek32(index));
        break;

      /// Spec Section 2.4.7: "stkswap: Swap the top two values on the stack."
      case GlulxOp.stkswap:
        stack.stkSwap();
        break;

      /// Spec Section 2.4.7: "stkroll L1 L2: Rotate the top L1 values on the stack."
      case GlulxOp.stkroll:
        final count = operands[0] as int;
        final shift = (operands[1] as int).toSigned(32);
        stack.stkRoll(count, shift);
        break;

      /// Spec Section 2.4.7: "stkcopy L1: Peek at top L1 values and push duplicates."
      case GlulxOp.stkcopy:
        final count = operands[0] as int;
        stack.stkCopy(count);
        break;

      // ========== Memory Map Opcodes (Spec Section 2.4.10) ==========

      /// Spec Section 2.4.10: "getmemsize S1: Store the current size of the memory map."
      case GlulxOp.getmemsize:
        final dest = operands[0] as StoreOperand;
        _performStore(dest, memoryMap.endMem);
        break;

      /// Spec Section 2.4.10: "setmemsize L1 S1: Set the current size of memory."
      case GlulxOp.setmemsize:
        final newSize = operands[0] as int;
        final dest = operands[1] as StoreOperand;
        _performStore(dest, memoryMap.setMemorySize(newSize));
        break;

      /// Spec Section 2.4.14: "mzero L1 L2: Write L1 zero bytes at L2."
      case GlulxOp.mzero:
        final count = operands[0] as int;
        final addr = operands[1] as int;
        for (var i = 0; i < count; i++) {
          memoryMap.writeByte(addr + i, 0);
        }
        break;

      /// Spec Section 2.4.14: "mcopy L1 L2 L3: Copy L1 bytes from L2 to L3."
      case GlulxOp.mcopy:
        final count = operands[0] as int;
        final src = operands[1] as int;
        final dest = operands[2] as int;
        if (dest < src) {
          // Forward copy
          for (var i = 0; i < count; i++) {
            memoryMap.writeByte(dest + i, memoryMap.readByte(src + i));
          }
        } else if (dest > src) {
          // Backward copy for overlapping regions
          for (var i = count - 1; i >= 0; i--) {
            memoryMap.writeByte(dest + i, memoryMap.readByte(src + i));
          }
        }
        break;

      // ========== System Opcodes (Spec Section 2.4.11) ==========

      /// Spec Section 2.4.11: "verify S1: Perform sanity checks on game file."
      case GlulxOp.verify:
        final dest = operands[0] as StoreOperand;
        // Stub: assume everything is fine
        _performStore(dest, 0);
        break;

      /// Spec Section 2.4.11: "restart: Restore VM to initial state."
      case GlulxOp.restart:
        // This is a partial implementation. Full restart requires reloading
        // the original ROM and resetting all RAM above RAMSTART.
        // For now, we clear the stack and reset PC, but we don't fully reload RAM.
        // Actually, the easiest way to "restart" is to signal it or reload.
        stack.reset();
        _pc = memoryMap.ramStart;
        // The start function should be called again, but _executeOpcode
        // is called from the middle of the run loop.
        // A better approach is to set a flag.
        _quit = true; // Signal exit so run() can handle restart (if it supported it)
        // TODO: Full restart support
        break;

      /// Spec Section 2.4.8: "getstringtbl S1: Return current string table address."
      case GlulxOp.getstringtbl:
        final dest = operands[0] as StoreOperand;
        _performStore(dest, _stringTableAddress);
        break;

      /// Spec Section 2.4.8: "setstringtbl L1: Set current string table address."
      case GlulxOp.setstringtbl:
        final addr = operands[0] as int;
        _stringTableAddress = addr;
        break;

      // ========== Random Number Opcodes (Spec Section 2.4.9) ==========

      /// Spec Section 2.4.9: "random L1 S1: Return a random number."
      /// Reference: osdepend.c glulx_random()
      case GlulxOp.random:
        final range = (operands[0] as int).toSigned(32);
        final dest = operands[1] as StoreOperand;
        final rawRandom = _random.nextInt();

        int result;
        if (range == 0) {
          // Full 32-bit range
          result = rawRandom;
        } else if (range > 0) {
          result = rawRandom % range;
        } else {
          // Negative range: (L1+1) to 0
          result = -(rawRandom % (-range));
        }
        _performStore(dest, result & 0xFFFFFFFF);
        break;

      /// Spec Section 2.4.9: "setrandom L1: Seed the random-number generator."
      /// Reference: osdepend.c glulx_setrandom()
      case GlulxOp.setrandom:
        final seed = operands[0] as int;
        _random.seed(seed);
        break;

      // ========== Stream Opcodes (Spec Section 2.4.8) ==========

      /// Spec Section 2.4.8: "streamchar L1: Output a single character."
      case GlulxOp.streamchar:
        final ch = operands[0] as int;
        _streamChar(ch & 0xFF);
        break;

      /// Spec Section 2.4.8: "streamunichar L1: Output a Unicode character."
      case GlulxOp.streamunichar:
        final ch = operands[0] as int;
        _streamUniChar(ch);
        break;

      /// Spec Section 2.4.8: "streamnum L1: Output a signed decimal integer."
      case GlulxOp.streamnum:
        final num = (operands[0] as int).toSigned(32);
        _streamNum(num, inmiddle: false, charnum: 0);
        break;

      /// Spec Section 2.4.8: "streamstr L1: Output a string."
      case GlulxOp.streamstr:
        final addr = operands[0] as int;
        _streamString(addr);
        break;

      // ========== Search Opcodes (Spec Section 2.4.15) ==========

      /// Spec Section 2.4.15: "linearsearch Key KeySize Start StructSize NumStructs KeyOffset Options Result"
      case GlulxOp.linearsearch:
        final key = operands[0] as int;
        final keySize = operands[1] as int;
        final start = operands[2] as int;
        final structSize = operands[3] as int;
        final numStructs = operands[4] as int;
        final keyOffset = operands[5] as int;
        final options = operands[6] as int;
        final dest = operands[7] as StoreOperand;
        _performStore(dest, _doLinearSearch(key, keySize, start, structSize, numStructs, keyOffset, options));
        break;

      /// Spec Section 2.4.15: "binarysearch Key KeySize Start StructSize NumStructs KeyOffset Options Result"
      case GlulxOp.binarysearch:
        final key = operands[0] as int;
        final keySize = operands[1] as int;
        final start = operands[2] as int;
        final structSize = operands[3] as int;
        final numStructs = operands[4] as int;
        final keyOffset = operands[5] as int;
        final options = operands[6] as int;
        final dest = operands[7] as StoreOperand;
        _performStore(dest, _doBinarySearch(key, keySize, start, structSize, numStructs, keyOffset, options));
        break;

      /// Spec Section 2.4.15: "linkedsearch Key KeySize Start KeyOffset NextOffset Options Result"
      case GlulxOp.linkedsearch:
        final key = operands[0] as int;
        final keySize = operands[1] as int;
        final start = operands[2] as int;
        final keyOffset = operands[3] as int;
        final nextOffset = operands[4] as int;
        final options = operands[5] as int;
        final dest = operands[6] as StoreOperand;
        _performStore(dest, _doLinkedSearch(key, keySize, start, keyOffset, nextOffset, options));
        break;

      // ========== Floating Point Opcodes (Spec Section 2.4.9) ==========

      case GlulxOp.fadd:
        _performStore(operands[2] as StoreOperand, _f2u(_u2f(operands[0] as int) + _u2f(operands[1] as int)));
        break;
      case GlulxOp.fsub:
        _performStore(operands[2] as StoreOperand, _f2u(_u2f(operands[0] as int) - _u2f(operands[1] as int)));
        break;
      case GlulxOp.fmul:
        _performStore(operands[2] as StoreOperand, _f2u(_u2f(operands[0] as int) * _u2f(operands[1] as int)));
        break;
      case GlulxOp.fdiv:
        _performStore(operands[2] as StoreOperand, _f2u(_u2f(operands[0] as int) / _u2f(operands[1] as int)));
        break;
      case GlulxOp.fmod:
        final f1 = _u2f(operands[0] as int);
        final f2 = _u2f(operands[1] as int);
        final quot = (f1 / f2).truncateToDouble();
        _performStore(operands[2] as StoreOperand, _f2u(f1 - (quot * f2)));
        _performStore(operands[3] as StoreOperand, _f2u(quot));
        break;
      case GlulxOp.frem:
        final f1 = _u2f(operands[0] as int);
        final f2 = _u2f(operands[1] as int);
        _performStore(operands[2] as StoreOperand, _f2u(f1 % f2));
        break;
      case GlulxOp.sqrt:
        _performStore(operands[1] as StoreOperand, _f2u(math.sqrt(_u2f(operands[0] as int))));
        break;
      case GlulxOp.exp:
        _performStore(operands[1] as StoreOperand, _f2u(math.exp(_u2f(operands[0] as int))));
        break;
      case GlulxOp.log:
        _performStore(operands[1] as StoreOperand, _f2u(math.log(_u2f(operands[0] as int))));
        break;
      case GlulxOp.pow:
        _performStore(
          operands[2] as StoreOperand,
          _f2u(math.pow(_u2f(operands[0] as int), _u2f(operands[1] as int)).toDouble()),
        );
        break;
      case GlulxOp.sin:
        _performStore(operands[1] as StoreOperand, _f2u(math.sin(_u2f(operands[0] as int))));
        break;
      case GlulxOp.cos:
        _performStore(operands[1] as StoreOperand, _f2u(math.cos(_u2f(operands[0] as int))));
        break;
      case GlulxOp.tan:
        _performStore(operands[1] as StoreOperand, _f2u(math.tan(_u2f(operands[0] as int))));
        break;
      case GlulxOp.asin:
        _performStore(operands[1] as StoreOperand, _f2u(math.asin(_u2f(operands[0] as int))));
        break;
      case GlulxOp.acos:
        _performStore(operands[1] as StoreOperand, _f2u(math.acos(_u2f(operands[0] as int))));
        break;
      case GlulxOp.atan:
        _performStore(operands[1] as StoreOperand, _f2u(math.atan(_u2f(operands[0] as int))));
        break;
      case GlulxOp.atan2:
        _performStore(
          operands[2] as StoreOperand,
          _f2u(math.atan2(_u2f(operands[0] as int), _u2f(operands[1] as int))),
        );
        break;
      case GlulxOp.ceil:
        _performStore(operands[1] as StoreOperand, _f2u(_u2f(operands[0] as int).ceilToDouble()));
        break;
      case GlulxOp.floor:
        _performStore(operands[1] as StoreOperand, _f2u(_u2f(operands[0] as int).floorToDouble()));
        break;
      case GlulxOp.jisnan:
        if (_u2f(operands[0] as int).isNaN) {
          _performBranch(operands[1] as int);
        }
        break;
      case GlulxOp.jisinf:
        if (_u2f(operands[0] as int).isInfinite) {
          _performBranch(operands[1] as int);
        }
        break;
      case GlulxOp.jfeq:
        final f1 = _u2f(operands[0] as int);
        final f2 = _u2f(operands[1] as int);
        final tolerance = _u2f(operands[2] as int);
        if (f1.isNaN || f2.isNaN || tolerance.isNaN) break;
        if (f1.isInfinite && f2.isInfinite) {
          if (f1 == f2) _performBranch(operands[3] as int);
          break;
        }
        if ((f1 - f2).abs() <= tolerance.abs()) {
          _performBranch(operands[3] as int);
        }
        break;
      case GlulxOp.jfne:
        final f1 = _u2f(operands[0] as int);
        final f2 = _u2f(operands[1] as int);
        final tolerance = _u2f(operands[2] as int);
        if (f1.isNaN || f2.isNaN || tolerance.isNaN) {
          _performBranch(operands[3] as int);
          break;
        }
        if (f1.isInfinite && f2.isInfinite) {
          if (f1 != f2) _performBranch(operands[3] as int);
          break;
        }
        if ((f1 - f2).abs() > tolerance.abs()) {
          _performBranch(operands[3] as int);
        }
        break;
      case GlulxOp.jflt:
        final f1 = _u2f(operands[0] as int);
        final f2 = _u2f(operands[1] as int);
        if (f1.isNaN || f2.isNaN) break;
        if (f1 < f2) {
          _performBranch(operands[2] as int);
        }
        break;
      case GlulxOp.jfge:
        final f1 = _u2f(operands[0] as int);
        final f2 = _u2f(operands[1] as int);
        if (f1.isNaN || f2.isNaN) break;
        if (f1 >= f2) {
          _performBranch(operands[2] as int);
        }
        break;
      case GlulxOp.jfgt:
        final f1 = _u2f(operands[0] as int);
        final f2 = _u2f(operands[1] as int);
        if (f1.isNaN || f2.isNaN) break;
        if (f1 > f2) {
          _performBranch(operands[2] as int);
        }
        break;
      case GlulxOp.jfle:
        final f1 = _u2f(operands[0] as int);
        final f2 = _u2f(operands[1] as int);
        if (f1.isNaN || f2.isNaN) break;
        if (f1 <= f2) {
          _performBranch(operands[2] as int);
        }
        break;
      case GlulxOp.numtof:
        _performStore(operands[1] as StoreOperand, _f2u((operands[0] as int).toSigned(32).toDouble()));
        break;
      case GlulxOp.ftonumz:
        _performStore(operands[1] as StoreOperand, _u2f(operands[0] as int).truncate().toSigned(32) & 0xFFFFFFFF);
        break;
      case GlulxOp.ftonumn:
        final f = _u2f(operands[0] as int);
        if (f.isNaN || f.isInfinite) {
          _performStore(operands[1] as StoreOperand, 0);
        } else {
          // Round to even
          double rounded = f.roundToDouble();
          if ((f - rounded).abs() == 0.5) {
            if (rounded.toInt().isOdd) {
              rounded = (f < rounded) ? f.floorToDouble() : f.ceilToDouble();
            }
          }
          _performStore(operands[1] as StoreOperand, rounded.toInt().toSigned(32) & 0xFFFFFFFF);
        }
        break;
      case GlulxOp.fgetround:
        _performStore(operands[0] as StoreOperand, _fsetroundMode);
        break;
      case GlulxOp.fsetround:
        _fsetroundMode = operands[0] as int;
        break;

      // ========== Double Precision Opcodes (Spec Section 2.4.12) ==========

      case GlulxOp.dadd:
        final res = _d2u(_u2d(operands[0] as int, operands[1] as int) + _u2d(operands[2] as int, operands[3] as int));
        _performStore(operands[4] as StoreOperand, res[0]);
        _performStore(operands[5] as StoreOperand, res[1]);
        break;
      case GlulxOp.dsub:
        final res = _d2u(_u2d(operands[0] as int, operands[1] as int) - _u2d(operands[2] as int, operands[3] as int));
        _performStore(operands[4] as StoreOperand, res[0]);
        _performStore(operands[5] as StoreOperand, res[1]);
        break;
      case GlulxOp.dmul:
        final res = _d2u(_u2d(operands[0] as int, operands[1] as int) * _u2d(operands[2] as int, operands[3] as int));
        _performStore(operands[4] as StoreOperand, res[0]);
        _performStore(operands[5] as StoreOperand, res[1]);
        break;
      case GlulxOp.ddiv:
        final res = _d2u(_u2d(operands[0] as int, operands[1] as int) / _u2d(operands[2] as int, operands[3] as int));
        _performStore(operands[4] as StoreOperand, res[0]);
        _performStore(operands[5] as StoreOperand, res[1]);
        break;
      case GlulxOp.dmodr:
        final d1 = _u2d(operands[0] as int, operands[1] as int);
        final d2 = _u2d(operands[2] as int, operands[3] as int);
        final res = _d2u(d1 % d2);
        _performStore(operands[4] as StoreOperand, res[0]);
        _performStore(operands[5] as StoreOperand, res[1]);
        break;
      case GlulxOp.dmodq:
        final d1 = _u2d(operands[0] as int, operands[1] as int);
        final d2 = _u2d(operands[2] as int, operands[3] as int);
        final res = _d2u((d1 / d2).truncateToDouble());
        _performStore(operands[4] as StoreOperand, res[0]);
        _performStore(operands[5] as StoreOperand, res[1]);
        break;
      case GlulxOp.dsqrt:
        final res = _d2u(math.sqrt(_u2d(operands[0] as int, operands[1] as int)));
        _performStore(operands[2] as StoreOperand, res[0]);
        _performStore(operands[3] as StoreOperand, res[1]);
        break;
      case GlulxOp.dexp:
        final res = _d2u(math.exp(_u2d(operands[0] as int, operands[1] as int)));
        _performStore(operands[2] as StoreOperand, res[0]);
        _performStore(operands[3] as StoreOperand, res[1]);
        break;
      case GlulxOp.dlog:
        final res = _d2u(math.log(_u2d(operands[0] as int, operands[1] as int)));
        _performStore(operands[2] as StoreOperand, res[0]);
        _performStore(operands[3] as StoreOperand, res[1]);
        break;
      case GlulxOp.dpow:
        final res = _d2u(
          math
              .pow(_u2d(operands[0] as int, operands[1] as int), _u2d(operands[2] as int, operands[3] as int))
              .toDouble(),
        );
        _performStore(operands[4] as StoreOperand, res[0]);
        _performStore(operands[5] as StoreOperand, res[1]);
        break;
      case GlulxOp.dsin:
        final res = _d2u(math.sin(_u2d(operands[0] as int, operands[1] as int)));
        _performStore(operands[2] as StoreOperand, res[0]);
        _performStore(operands[3] as StoreOperand, res[1]);
        break;
      case GlulxOp.dcos:
        final res = _d2u(math.cos(_u2d(operands[0] as int, operands[1] as int)));
        _performStore(operands[2] as StoreOperand, res[0]);
        _performStore(operands[3] as StoreOperand, res[1]);
        break;
      case GlulxOp.dtan:
        final res = _d2u(math.tan(_u2d(operands[0] as int, operands[1] as int)));
        _performStore(operands[2] as StoreOperand, res[0]);
        _performStore(operands[3] as StoreOperand, res[1]);
        break;
      case GlulxOp.dasin:
        final res = _d2u(math.asin(_u2d(operands[0] as int, operands[1] as int)));
        _performStore(operands[2] as StoreOperand, res[0]);
        _performStore(operands[3] as StoreOperand, res[1]);
        break;
      case GlulxOp.dacos:
        final res = _d2u(math.acos(_u2d(operands[0] as int, operands[1] as int)));
        _performStore(operands[2] as StoreOperand, res[0]);
        _performStore(operands[3] as StoreOperand, res[1]);
        break;
      case GlulxOp.datan:
        final res = _d2u(math.atan(_u2d(operands[0] as int, operands[1] as int)));
        _performStore(operands[2] as StoreOperand, res[0]);
        _performStore(operands[3] as StoreOperand, res[1]);
        break;
      case GlulxOp.datan2:
        final res = _d2u(
          math.atan2(_u2d(operands[0] as int, operands[1] as int), _u2d(operands[2] as int, operands[3] as int)),
        );
        _performStore(operands[4] as StoreOperand, res[0]);
        _performStore(operands[5] as StoreOperand, res[1]);
        break;
      case GlulxOp.dceil:
        final res = _d2u(_u2d(operands[0] as int, operands[1] as int).ceilToDouble());
        _performStore(operands[2] as StoreOperand, res[0]);
        _performStore(operands[3] as StoreOperand, res[1]);
        break;
      case GlulxOp.dfloor:
        final res = _d2u(_u2d(operands[0] as int, operands[1] as int).floorToDouble());
        _performStore(operands[2] as StoreOperand, res[0]);
        _performStore(operands[3] as StoreOperand, res[1]);
        break;
      case GlulxOp.jdisnan:
        if (_u2d(operands[0] as int, operands[1] as int).isNaN) {
          _performBranch(operands[2] as int);
        }
        break;
      case GlulxOp.jdisinf:
        if (_u2d(operands[0] as int, operands[1] as int).isInfinite) {
          _performBranch(operands[2] as int);
        }
        break;
      case GlulxOp.jdeq:
        {
          final d1 = _u2d(operands[0] as int, operands[1] as int);
          final d2 = _u2d(operands[2] as int, operands[3] as int);
          final tolerance = _u2d(operands[4] as int, operands[5] as int);
          if (d1.isNaN || d2.isNaN || tolerance.isNaN) break;
          if (d1.isInfinite && d2.isInfinite) {
            if (d1 == d2) _performBranch(operands[6] as int);
            break;
          }
          if ((d1 - d2).abs() <= tolerance.abs()) {
            _performBranch(operands[6] as int);
          }
        }
        break;
      case GlulxOp.jdne:
        {
          final d1 = _u2d(operands[0] as int, operands[1] as int);
          final d2 = _u2d(operands[2] as int, operands[3] as int);
          final tolerance = _u2d(operands[4] as int, operands[5] as int);
          if (d1.isNaN || d2.isNaN || tolerance.isNaN) {
            _performBranch(operands[6] as int);
            break;
          }
          if (d1.isInfinite && d2.isInfinite) {
            if (d1 != d2) _performBranch(operands[6] as int);
            break;
          }
          if ((d1 - d2).abs() > tolerance.abs()) {
            _performBranch(operands[6] as int);
          }
        }
        break;
      case GlulxOp.jdlt:
        {
          final d1 = _u2d(operands[0] as int, operands[1] as int);
          final d2 = _u2d(operands[2] as int, operands[3] as int);
          if (d1.isNaN || d2.isNaN) break;
          if (d1 < d2) {
            _performBranch(operands[4] as int);
          }
        }
        break;
      case GlulxOp.jdge:
        {
          final d1 = _u2d(operands[0] as int, operands[1] as int);
          final d2 = _u2d(operands[2] as int, operands[3] as int);
          if (d1.isNaN || d2.isNaN) break;
          if (d1 >= d2) {
            _performBranch(operands[4] as int);
          }
        }
        break;
      case GlulxOp.jdgt:
        {
          final d1 = _u2d(operands[0] as int, operands[1] as int);
          final d2 = _u2d(operands[2] as int, operands[3] as int);
          if (d1.isNaN || d2.isNaN) break;
          if (d1 > d2) {
            _performBranch(operands[4] as int);
          }
        }
        break;
      case GlulxOp.jdle:
        {
          final d1 = _u2d(operands[0] as int, operands[1] as int);
          final d2 = _u2d(operands[2] as int, operands[3] as int);
          if (d1.isNaN || d2.isNaN) break;
          if (d1 <= d2) {
            _performBranch(operands[4] as int);
          }
        }
        break;
      case GlulxOp.numtod:
        final res = _d2u((operands[0] as int).toSigned(32).toDouble());
        _performStore(operands[1] as StoreOperand, res[0]);
        _performStore(operands[2] as StoreOperand, res[1]);
        break;
      case GlulxOp.dtonumz:
        _performStore(
          operands[2] as StoreOperand,
          _u2d(operands[0] as int, operands[1] as int).truncate().toSigned(32) & 0xFFFFFFFF,
        );
        break;
      case GlulxOp.ftod:
        final res = _d2u(_u2f(operands[0] as int));
        _performStore(operands[1] as StoreOperand, res[0]);
        _performStore(operands[2] as StoreOperand, res[1]);
        break;
      case GlulxOp.dtof:
        _performStore(operands[2] as StoreOperand, _f2u(_u2d(operands[0] as int, operands[1] as int)));
        break;

      case GlulxOp.glk:
        final selector = operands[0] as int;
        final argCount = operands[1] as int;
        final dest = operands[2] as StoreOperand;

        // Pop arguments from stack. Per spec, args are pushed backward (last first),
        // so popping yields them in forward order (first arg first).
        final args = <int>[];
        for (var i = 0; i < argCount; i++) {
          args.add(stack.pop32());
        }

        if (debugger.enabled && debugger.showInstructions) {
          debugger.bufferedLog('  Glk args: $args');
        }

        // Call Glk dispatcher
        final result = _callGlk(selector, args);
        if (result is Future<int>) {
          return result.then((val) => _performStore(dest, val));
        }
        _performStore(dest, result);
        break;

      default:
        throw GlulxException(
          'Unimplemented opcode: 0x${opcode.toRadixString(16)} (${GlulxDebugger.opCodeName[opcode]})',
        );
    }
  }

  // / Calls the Glk dispatcher.
  FutureOr<int> _callGlk(int selector, List<int> args) {
    final res = glkDispatcher.glkDispatch(selector, args);
    if (res is Future<int>) {
      return res.then((val) {
        if (debugger.enabled) {
          if (debugger.showInstructions) {
            debugger.bufferedLog('Interpreter -> Glk selector: 0x${selector.toRadixString(16)} ret: $val');
            if (debugger.showFlightRecorder) {
              debugger.flightRecorderEvent('Glk(0x${selector.toRadixString(16)})$args -> $val');
            }
          }
        }
        return val;
      });
    }
    if (debugger.enabled) {
      if (debugger.showInstructions) {
        debugger.bufferedLog('Interpreter -> Glk selector: 0x${selector.toRadixString(16)} ret: $res');
        if (debugger.showFlightRecorder) {
          debugger.flightRecorderEvent('Glk(0x${selector.toRadixString(16)})$args -> $res');
        }
      }
    }
    return res;
  }

  /// Sets the I/O system mode and rock.
  /// Reference: string.c stream_set_iosys()
  void _setIosys(int mode, int rock) {
    switch (mode) {
      case 0: // None - output discarded
        _iosysMode = 0;
        _iosysRock = 0;
        break;
      case 1: // Filter - output passed to function
        _iosysMode = 1;
        _iosysRock = rock;
        break;
      case 2: // Glk - output to Glk library
        _iosysMode = 2;
        _iosysRock = 0;
        break;
      default:
        // Unknown mode treated as None
        _iosysMode = 0;
        _iosysRock = 0;
        break;
    }
  }

  /// Handles the gestalt opcode by returning capability information.
  int _doGestalt(int selector, int arg) {
    return glkDispatcher.vmGestalt(selector, arg);
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
  /// [argSize] controls byte width for memory/local reads (1, 2, or 4).
  /// Reference: operand.c parse_operands() lines 450-494
  int loadOperand(int mode, {int argSize = 4}) {
    switch (mode) {
      case 0: // Constant zero.
        return 0;
      case 1: // Constant, -80 to 7F (1 byte).
        return _nextByte().toSigned(8);
      case 2: // Constant, -8000 to 7FFF (2 bytes).
        return _nextShort().toSigned(16);
      case 3: // Constant, any value (4 bytes).
        return _nextInt();
      case 5: // Contents of address 00 to FF (1 byte addr).
        return _readMemBySize(_nextByte(), argSize);
      case 6: // Contents of address 0000 to FFFF (2 bytes addr).
        return _readMemBySize(_nextShort(), argSize);
      case 7: // Contents of any address (4 bytes addr).
        return _readMemBySize(_nextWord(), argSize);
      case 8: // Value popped off stack.
        return stack.pop32();
      case 0x9: // Call frame local at address 00 to FF (1 byte).
        return _readLocalBySize(_nextByte(), argSize);
      case 0xA: // Call frame local at address 0000 to FFFF (2 bytes).
        return _readLocalBySize(_nextShort(), argSize);
      case 0xB: // Call frame local at any address (4 bytes).
        return _readLocalBySize(_nextWord(), argSize);
      case 0xD: // Contents of RAM address 00 to FF (1 byte addr).
        return _readMemBySize(memoryMap.ramStart + _nextByte(), argSize);
      case 0xE: // Contents of RAM address 0000 to FFFF (2 bytes addr).
        return _readMemBySize(memoryMap.ramStart + _nextShort(), argSize);
      case 0xF: // Contents of RAM, any address (4 bytes addr).
        return _readMemBySize(memoryMap.ramStart + _nextWord(), argSize);
      default:
        throw Exception('Illegal load addressing mode: $mode');
    }
  }

  /// Reads from memory using the specified byte width.
  /// Reference: operand.c lines 452-460
  int _readMemBySize(int addr, int argSize) {
    if (argSize == 1) return memoryMap.readByte(addr);
    if (argSize == 2) return memoryMap.readShort(addr);
    return memoryMap.readWord(addr);
  }

  /// Reads from stack locals using the specified byte width.
  /// Reference: operand.c lines 485-494
  int _readLocalBySize(int offset, int argSize) {
    if (argSize == 1) return stack.readLocal8(offset);
    if (argSize == 2) return stack.readLocal16(offset);
    return stack.readLocal32(offset);
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
        // Pass argSize for byte-width memory reads (copyb=1, copys=2, default=4)
        operands.add(loadOperand(mode, argSize: info.argSize));
      }
    }
    return operands;
  }

  StoreOperand _prepareStore(int mode) {
    switch (mode) {
      case 0:
        return StoreOperand(mode, 0);
      case 5:
      case 0x9:
      case 0xD:
        return StoreOperand(mode, _nextByte());
      case 6:
      case 0xA:
      case 0xE:
        return StoreOperand(mode, _nextShort());
      case 7:
      case 0xB:
      case 0xF:
        return StoreOperand(mode, _nextWord());
      case 8:
        return StoreOperand(mode, 0);
      default:
        throw Exception('Illegal store addressing mode: $mode');
    }
  }

  // ignore: unused_element
  void _performStore(StoreOperand dest, int value) {
    if (debugger.enabled) {
      if (debugger.showInstructions) {
        debugger.bufferedLog('[${debugger.step}]   StoreWord: $dest value: 0x${value.toRadixString(16)} ($value)');
      }
      if (debugger.showFlightRecorder) {
        debugger.flightRecorderEvent('StoreWord: $dest value: 0x${value.toRadixString(16)} ($value)');
      }
    }
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

  /// Performs a 16-bit store operation.
  /// Reference: store_operand_s in exec.c
  void _performStoreS(StoreOperand dest, int value) {
    if (debugger.enabled) {
      if (debugger.showInstructions) {
        debugger.bufferedLog('[${debugger.step}]   StoreShort: $dest value: 0x${value.toRadixString(16)} ($value)');
      }
      if (debugger.showFlightRecorder) {
        debugger.flightRecorderEvent('StoreShort: $dest value: 0x${value.toRadixString(16)} ($value)');
      }
    }
    switch (dest.mode) {
      case 0:
        break;
      case 5:
      case 6:
      case 7:
        memoryMap.writeShort(dest.addr, value);
        break;
      case 8:
        // Push 16-bit value as 32-bit on stack
        stack.push32(value & 0xFFFF);
        break;
      case 0x9:
      case 0xA:
      case 0xB:
        stack.writeLocal16(dest.addr, value);
        break;
      case 0xD:
      case 0xE:
      case 0xF:
        memoryMap.writeShort(memoryMap.ramStart + dest.addr, value);
        break;
    }
  }

  /// Performs an 8-bit store operation.
  /// Reference: store_operand_b in exec.c
  void _performStoreB(StoreOperand dest, int value) {
    if (debugger.enabled) {
      if (debugger.showInstructions) {
        debugger.bufferedLog('[${debugger.step}]   StoreByte: $dest value: 0x${value.toRadixString(16)} ($value)');
      }
      if (debugger.showFlightRecorder) {
        debugger.flightRecorderEvent('StoreByte: $dest value: 0x${value.toRadixString(16)} ($value)');
      }
    }
    switch (dest.mode) {
      case 0:
        break;
      case 5:
      case 6:
      case 7:
        memoryMap.writeByte(dest.addr, value);
        break;
      case 8:
        // Push 8-bit value as 32-bit on stack
        stack.push32(value & 0xFF);
        break;
      case 0x9:
      case 0xA:
      case 0xB:
        stack.writeLocal8(dest.addr, value);
        break;
      case 0xD:
      case 0xE:
      case 0xF:
        memoryMap.writeByte(memoryMap.ramStart + dest.addr, value);
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
      _returnValue(offset);
    } else {
      // Spec: "The actual destination address of the branch is computed as (Addr + Offset - 2)"
      // _pc is already at the instruction AFTER the branch, so we apply the offset directly.
      _pc = _pc + offset.toSigned(32) - 2;
    }
  }

  /// Calls a function at the given address with arguments.
  ///
  /// Spec Section 2.4.4: "call L1 L2 S1: Call function whose address is L1,
  /// passing in L2 arguments, and store the return result at S1."
  void _callFunction(int address, List<int> args, StoreOperand dest) {
    // Convert addressing mode to call stub DestType/DestAddr
    // Spec Section 1.4.1: DestType 0=discard, 1=memory, 2=local, 3=stack
    final destType = _modeToDestType(dest.mode);
    final destAddr = _modeToDestAddr(dest.mode, dest.addr);

    // Push call stub: destType, destAddr, PC, FP
    stack.pushCallStub(destType, destAddr, _pc, stack.fp);

    _enterFunction(address, args);
  }

  /// Sets up a new call frame and entries the function at the given address.
  /// Does NOT push a call stub. Reference: enter_function in funcs.c
  void _enterFunction(int address, List<int> args) {
    // Parse function header
    final func = GlulxFunction.parse(memoryMap, address);

    // Push new frame using function's format
    stack.pushFrame(func.localsDescriptor.formatBytes);

    // Handle arguments based on function type
    if (func is StackArgsFunction) {
      // C0: Spec says "last argument pushed first, first argument topmost.
      // Then the number of arguments is pushed on top of that."
      for (var i = args.length - 1; i >= 0; i--) {
        stack.push32(args[i]);
      }
      stack.push32(args.length);
    } else {
      // C1: Copy args into locals
      stack.setArguments(args, func.localsDescriptor.locals);
    }

    // Jump to entry point
    _pc = func.entryPoint;
  }

  /// Returns from the current function with the given value.
  ///
  /// Spec Section 2.4.4: "return L1: Return from the current function, with the given return value."
  /// Reference: exec.c case op_return - leave_function(), check stackptr == 0, then pop_callstub()
  void _returnValue(int value) {
    // Step 1: Leave the function (set SP = FP, like C's leave_function())
    stack.leaveFunction();

    // Step 2: Check if we're returning from the top-level function (no call stub)
    // Reference: exec.c lines 346-348: if (stackptr == 0) { done_executing = TRUE; break; }
    if (stack.sp == 0) {
      _quit = true;
      return;
    }

    // Step 3: Pop the call stub and restore state
    final stub = stack.popCallStub();
    final destType = stub[0];
    final destAddr = stub[1];
    final oldPc = stub[2];
    final oldFp = stub[3];

    // Restore FP and update cached bases
    stack.restoreFp(oldFp);

    // Handle 0x12 (streamnum resumption) specially since we need oldPc as the original number
    // Reference: funcs.c line 258 - stream_num(pc, TRUE, destaddr)
    if (destType == 0x12) {
      // oldPc contains the original number, destAddr contains charnum
      _streamNum(oldPc.toSigned(32), inmiddle: true, charnum: destAddr);
      return;
    }

    // Store result
    stack.storeResult(
      value,
      destType,
      destAddr,
      onMemoryWrite: (addr, val) {
        memoryMap.writeWord(addr, val);
      },
      onResumeString: (bitnum, type) {
        // Resume string printing
        _streamString(oldPc, type: type, bitnum: bitnum);
      },
    );

    // Restore PC (unless it's a string resume, but storeResult callback handles that)
    if (destType < 0x10 || destType > 0x14) {
      _pc = oldPc;
    }
  }

  /// Converts an addressing mode to a call stub DestType.
  ///
  /// Spec Section 1.4.1: DestType values:
  /// 0 = Do not store (discard)
  /// 1 = Store in main memory at DestAddr
  /// 2 = Store in local variable at DestAddr offset
  /// 3 = Push on stack
  int _modeToDestType(int mode) {
    switch (mode) {
      case 0:
        return 0; // Discard
      case 5:
      case 6:
      case 7:
        return 1; // Memory
      case 8:
        return 3; // Stack push
      case 0x9:
      case 0xA:
      case 0xB:
        return 2; // Local
      case 0xD:
      case 0xE:
      case 0xF:
        return 1; // RAM (still memory)
      default:
        throw Exception('Cannot convert addressing mode $mode to DestType');
    }
  }

  /// Converts an addressing mode and address to a call stub DestAddr.
  int _modeToDestAddr(int mode, int addr) {
    switch (mode) {
      case 0:
      case 8:
        return 0; // Discard/stack: addr not used
      case 5:
      case 6:
      case 7:
        return addr; // Memory: direct address
      case 0x9:
      case 0xA:
      case 0xB:
        return addr; // Local: offset
      case 0xD:
      case 0xE:
      case 0xF:
        return memoryMap.ramStart + addr; // RAM-relative
      default:
        return addr;
    }
  }

  // ========== Stream Support ==========

  void _streamChar(int ch) {
    switch (_iosysMode) {
      case 0:
        break; // None
      case 1:
        // Filter function: Call _iosysRock with ch
        _callFunction(_iosysRock, [ch & 0xFF], StoreOperand(0, 0));
        break;
      case 2:
        // Glk: glk_put_char(ch)
        _callGlk(GlkIoSelectors.putChar, [ch & 0xFF]);
        break;
    }
  }

  void _streamUniChar(int code) {
    switch (_iosysMode) {
      case 0:
        break;
      case 1:
        _callFunction(_iosysRock, [code], StoreOperand(0, 0));
        break;
      case 2:
        _callGlk(GlkIoSelectors.putCharUni, [code]);
        break;
    }
  }

  /// Streams a signed decimal integer to the current output.
  ///
  /// Reference: C interpreter string.c stream_num() lines 132-195
  /// For Filter mode, uses 0x12 stubs with charnum to track position.
  void _streamNum(int val, {required bool inmiddle, required int charnum}) {
    // Build digits in reverse order (matching C implementation)
    final List<int> buf = [];
    if (val == 0) {
      buf.add(0x30); // '0'
    } else {
      int ival = val < 0 ? -val : val;
      while (ival != 0) {
        buf.add((ival % 10) + 0x30);
        ival ~/= 10;
      }
      if (val < 0) {
        buf.add(0x2D); // '-'
      }
    }

    final ix = buf.length;

    switch (_iosysMode) {
      case 0:
        // Null mode - discard
        break;

      case 2:
        // Glk mode - output from end to start (reverse order)
        for (var i = ix - 1 - charnum; i >= 0; i--) {
          _callGlk(GlkIoSelectors.putChar, [buf[i]]);
        }
        break;

      case 1:
        // Filter mode - each char requires function call with 0x12 stub
        // Reference: string.c lines 171-183
        if (!inmiddle) {
          stack.pushCallStub(0x11, 0, _pc, stack.fp);
          inmiddle = true;
        }
        if (charnum < ix) {
          final ival = buf[(ix - 1) - charnum] & 0xFF;
          _pc = val; // Store original value in PC for resumption
          stack.pushCallStub(0x12, charnum + 1, val, stack.fp);
          _enterFunction(_iosysRock, [ival]);
          return; // Exit and let main loop run filter function
        }
        break;
    }

    // Completed - pop terminator stub if needed
    if (inmiddle) {
      final resumed = _popCallstubString();
      if (resumed != null) {
        throw GlulxException('String-on-string call stub while printing number.');
      }
    }
  }

  /// Streams a string to the current output.
  ///
  /// This is designed to match the C interpreter's stream_string() loop-based
  /// architecture (string.c:203-671). Key aspects:
  /// - `inmiddle` is 0 for new strings, or the string type (E0/E1/E2) for resumption
  /// - `substring` (local var) tracks if we've pushed a 0x11 terminator stub
  /// - When a function is called, we push stubs and return (letting main loop run it)
  /// - When a nested string is encountered, we push 0x10 stub and restart loop
  /// - On completion, if substring is true, we pop the 0x11 stub
  ///
  /// Reference: string.c lines 203-671
  void _streamString(int addr, {int? type, int? bitnum}) {
    if (addr == 0) return;

    // inmiddle logic: if type is provided, we're resuming a string
    final inmiddle = type ?? 0;
    // substring is LOCAL to this function, just like in C interpreter
    // Reference: string.c line 208: int substring = (inmiddle != 0);
    var substring = inmiddle != 0;

    var alldone = false;
    var currentAddr = addr;
    var currentType = inmiddle;
    var currentBitnum = bitnum ?? 0;

    while (!alldone) {
      // Determine string type
      if (currentType == 0) {
        currentType = memoryMap.readByte(currentAddr);
        if (currentType == 0xE2) {
          currentAddr += 4; // Skip type + 3 padding bytes
        } else {
          currentAddr += 1; // Skip type byte
        }
        currentBitnum = 0;
      }

      // done flag: 0 = continue inner loop, 1 = exit, 2 = restart with new string
      var done = 0;

      switch (currentType) {
        case 0xE0: // C-style string
          final result = _streamStringE0Loop(currentAddr, substring);
          if (result != null) {
            // Function was called, exit and let main loop run it
            return;
          }
          done = 1;
          break;

        case 0xE1: // Compressed string
          try {
            _streamStringE1Loop(currentAddr, currentBitnum, substring);
            done = 1; // Completed normally
          } on _StringNestedCall catch (call) {
            // Nested string encountered - C-style: push 0x10 stub and restart loop
            // Reference: string.c:386-391
            if (!substring) {
              stack.pushCallStub(0x11, 0, _pc, stack.fp);
              substring = true;
            }
            _pc = currentAddr;
            stack.pushCallStub(0x10, call.resumeBit, call.resumeAddr, stack.fp);
            // Update loop variables to process nested string
            currentAddr = call.stringAddr;
            currentType = 0; // Will determine type on next iteration
            currentBitnum = 0;
            done = 2; // Restart loop with nested string
          } on _StringFilterCall catch (call) {
            // Filter mode character - push stubs and call filter function
            // Reference: string.c:292-301 - each char calls filter function
            if (!substring) {
              stack.pushCallStub(0x11, 0, _pc, stack.fp);
            }
            _pc = call.resumeAddr;
            stack.pushCallStub(0x10, call.resumeBit, call.resumeAddr, stack.fp);
            _enterFunction(_iosysRock, [call.ch]);
            return; // Exit and let main loop run filter function
          } on _StringFunctionCall catch (call) {
            // Function encountered - push stubs and enter function
            // Reference: string.c:404-407
            if (!substring) {
              stack.pushCallStub(0x11, 0, _pc, stack.fp);
            }
            _pc = call.resumeAddr;
            stack.pushCallStub(0x10, call.resumeBit, call.resumeAddr, stack.fp);
            _enterFunction(call.funcAddr, call.args);
            return; // Exit and let main loop run function
          } on _StringEmbeddedCall catch (call) {
            // Embedded string node (0x03/0x05) in Filter mode - switch to E0/E2
            // Reference: string.c:330-340 - sets inmiddle to 0xE0/0xE2 and restarts
            if (!substring) {
              stack.pushCallStub(0x11, 0, _pc, stack.fp);
              substring = true;
            }
            _pc = currentAddr;
            stack.pushCallStub(0x10, call.resumeBit, call.resumeAddr, stack.fp);
            // Switch to E0/E2 processing for the embedded string data
            currentAddr = call.dataAddr;
            currentType = call.stringType; // 0xE0 or 0xE2
            currentBitnum = 0;
            done = 2; // Restart loop with embedded string type
          }
          break;

        case 0xE2: // Unicode string
          final result = _streamStringE2Loop(currentAddr, substring);
          if (result != null) {
            // Function was called, exit and let main loop run it
            return;
          }
          done = 1;
          break;

        default:
          throw GlulxException('Unknown string type: 0x${currentType.toRadixString(16)}');
      }

      // done == 2 means restart loop with new string (nested string case)
      if (done == 2) {
        continue;
      }

      // String processing completed for this segment
      if (!substring) {
        // No function calls happened, just exit
        alldone = true;
      } else {
        // Pop the next stub to see what to do
        final resumed = _popCallstubString();
        if (resumed == null) {
          // 0x11 stub was popped, we're done
          alldone = true;
        } else {
          // 0x10 stub was popped, continue with E1 string at resumed address
          currentAddr = resumed.$1;
          currentBitnum = resumed.$2;
          currentType = 0xE1;
        }
      }
    }
  }

  /// Streams a C-style (E0) string.
  /// Returns non-null if a function was called (filter mode), null if completed.
  /// Reference: string.c lines 593-619
  Object? _streamStringE0Loop(int addr, bool substring) {
    var p = addr;
    while (true) {
      final ch = memoryMap.readByte(p);
      p++;
      if (ch == 0) break;

      if (_iosysMode == 1) {
        // Filter mode: need to call function for each character
        if (!substring) {
          stack.pushCallStub(0x11, 0, _pc, stack.fp);
        }
        _pc = p; // Resume address after this character
        stack.pushCallStub(0x13, 0, p, stack.fp); // 0x13 = resume E0 string
        _enterFunction(_iosysRock, [ch & 0xFF]);
        return true; // Function called, exit
      } else {
        // Glk or null mode: output directly
        _streamCharDirect(ch);
      }
    }
    return null; // Completed
  }

  /// Streams a Unicode (E2) string.
  /// Returns non-null if a function was called (filter mode), null if completed.
  /// Reference: string.c lines 622-648
  Object? _streamStringE2Loop(int addr, bool substring) {
    var p = addr;
    while (true) {
      final ch = memoryMap.readWord(p);
      p += 4;
      if (ch == 0) break;

      if (_iosysMode == 1) {
        // Filter mode: need to call function for each character
        if (!substring) {
          stack.pushCallStub(0x11, 0, _pc, stack.fp);
        }
        _pc = p; // Resume address after this character
        stack.pushCallStub(0x14, 0, p, stack.fp); // 0x14 = resume E2 string
        _enterFunction(_iosysRock, [ch]);
        return true; // Function called, exit
      } else {
        // Glk or null mode: output directly
        _streamUniCharDirect(ch);
      }
    }
    return null; // Completed
  }

  /// Streams a compressed (E1) string.
  /// Returns null if completed normally.
  /// Throws _StringFunctionCall if a function was encountered.
  /// Throws _StringNestedCall if a nested string was encountered.
  /// Reference: string.c lines 228-588
  void _streamStringE1Loop(int addr, int bitnum, bool substring) {
    if (_stringTableAddress == 0) {
      throw GlulxException('Compressed string found but no string-decoding table set');
    }

    // Use the existing decoder - it will throw if it encounters indirect refs or Filter mode
    _stringDecoder.decode(
      addr - 1, // decode expects address of the E1 type byte
      _stringTableAddress,
      // Print char callback - for Filter mode, throw signal to call filter function
      // Reference: C interpreter string.c:292-301 - push stubs and call filter
      (ch, resumeAddr, resumeBit) {
        if (_iosysMode == 1) {
          throw _StringFilterCall(ch, resumeAddr, resumeBit);
        }
        _streamCharDirect(ch);
      },
      // Print unicode callback - for Filter mode, throw signal to call filter function
      // Reference: C interpreter string.c:310-319 - push stubs and call filter
      (ch, resumeAddr, resumeBit) {
        if (_iosysMode == 1) {
          throw _StringFilterCall(ch, resumeAddr, resumeBit);
        }
        _streamUniCharDirect(ch);
      },
      // Indirect string callback - throw to exit decoder and let main loop handle
      // Reference: C interpreter string.c:386-391 - pushes 0x10, restarts loop
      (resumeAddr, resumeBit, stringAddr) {
        throw _StringNestedCall(stringAddr, resumeAddr, resumeBit);
      },
      // Indirect function callback - throw to exit decoder and let main loop handle
      // Reference: C interpreter string.c:404-407 - pushes 0x10, enters function
      (resumeAddr, resumeBit, funcAddr, args) {
        throw _StringFunctionCall(funcAddr, args, resumeAddr, resumeBit);
      },
      startAddr: bitnum > 0 ? addr : null,
      startBit: bitnum > 0 ? bitnum : null,
      // Embedded string callback - only for Filter mode (0x03/0x05 nodes)
      // Reference: C interpreter string.c:330-340 - switches to E0/E2 processing
      callEmbeddedString: _iosysMode == 1
          ? (resumeAddr, resumeBit, dataAddr, stringType) {
              throw _StringEmbeddedCall(dataAddr, stringType, resumeAddr, resumeBit);
            }
          : null,
    );
    // If we get here, string completed normally (no indirect refs)
  }

  /// Direct character output to Glk (no function call).
  void _streamCharDirect(int ch) {
    if (_iosysMode == 2) {
      _callGlk(GlkIoSelectors.putChar, [ch & 0xFF]);
    }
    // Mode 0 = null, do nothing
  }

  /// Direct unicode character output to Glk (no function call).
  void _streamUniCharDirect(int ch) {
    if (_iosysMode == 2) {
      _callGlk(GlkIoSelectors.putCharUni, [ch]);
    }
    // Mode 0 = null, do nothing
  }

  /// Pops a call stub during string processing to determine next action.
  /// Returns (addr, bitnum) if 0x10 stub (continue E1 string), or null if 0x11 (done).
  /// Reference: funcs.c pop_callstub_string() lines 287-311
  (int, int)? _popCallstubString() {
    if (stack.sp < 16) {
      throw GlulxException('Stack underflow in callstub');
    }

    final stub = stack.popCallStub();
    final destType = stub[0];
    final destAddr = stub[1];
    final newPc = stub[2];
    // stub[3] is old FP, not needed here

    _pc = newPc;

    if (destType == 0x11) {
      // String terminator - we're done
      return null;
    } else if (destType == 0x10) {
      // Resume compressed string at newPc with bit number destAddr
      return (newPc, destAddr);
    } else {
      throw GlulxException('Function-terminator call stub at end of string (type 0x${destType.toRadixString(16)})');
    }
  }

  // ========== Floating Point Support ==========

  double _u2f(int u) {
    _u32[0] = u;
    return _f32[0];
  }

  int _f2u(double f) {
    _f32[0] = f;
    return _u32[0];
  }

  double _u2d(int hi, int lo) {
    _u32_64[1] = hi; // BIG ENDIAN: hi is index 1? No, buffer is local.
    // Spec says: "Double precision values are represented by two 32-bit values...
    // The first value contains the most significant bits... the second value contains the least."
    // In our Uint32List view of Float64List, it depends on host endianness.
    // Dart's ByteData might be safer.
    final bd = ByteData(8);
    bd.setUint32(0, hi);
    bd.setUint32(4, lo);
    return bd.getFloat64(0);
  }

  List<int> _d2u(double d) {
    final bd = ByteData(8);
    bd.setFloat64(0, d);
    return [bd.getUint32(0), bd.getUint32(4)];
  }

  // ========== Search Support ==========
  //
  // Spec Section "Searching":
  // - KeyIndirect (0x01): The Key argument is the address of the actual key.
  //   If this flag is not used, the Key value itself is the key.
  //   "In this case, the KeySize *must* be 1, 2, or 4."
  // - When KeyIndirect IS used, any KeySize is valid - keys are compared as
  //   big-endian byte arrays.

  /// Performs a linear search through an array of structures.
  ///
  /// Spec: "linearsearch L1 L2 L3 L4 L5 L6 L7 S1"
  /// Search through structures in order, returning first match or failure.
  int _doLinearSearch(int key, int keySize, int start, int structSize, int numStructs, int keyOffset, int options) {
    final keyIndirect = (options & 1) != 0;
    final zeroKeyTerminates = (options & 2) != 0;
    final returnIndex = (options & 4) != 0;

    // Spec: NumStructs may be -1 (0xFFFFFFFF) to indicate no upper limit
    final unlimited = numStructs == 0xFFFFFFFF;

    for (var i = 0; unlimited || i < numStructs; i++) {
      final structAddr = start + (i * structSize);

      // Check for zero key terminator before comparing
      if (zeroKeyTerminates && _isZeroKey(structAddr + keyOffset, keySize)) {
        break;
      }

      // Compare keys
      final cmp = _compareKeys(key, structAddr + keyOffset, keySize, keyIndirect);
      if (cmp == 0) {
        return returnIndex ? i : structAddr;
      }
    }

    return returnIndex ? 0xFFFFFFFF : 0; // Not found
  }

  /// Performs a binary search through a sorted array of structures.
  ///
  /// Spec: "binarysearch L1 L2 L3 L4 L5 L6 L7 S1"
  /// Structures must be sorted in forward order of keys (big-endian unsigned).
  /// NumStructs must be exact length; cannot be -1.
  int _doBinarySearch(int key, int keySize, int start, int structSize, int numStructs, int keyOffset, int options) {
    final keyIndirect = (options & 1) != 0;
    final returnIndex = (options & 4) != 0;

    var low = 0;
    var high = numStructs - 1;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final structAddr = start + (mid * structSize);

      // Compare keys: result is <0 if target<current, 0 if equal, >0 if target>current
      final cmp = _compareKeys(key, structAddr + keyOffset, keySize, keyIndirect);

      if (cmp == 0) {
        return returnIndex ? mid : structAddr;
      } else if (cmp > 0) {
        // Target key is greater than current key
        low = mid + 1;
      } else {
        // Target key is less than current key
        high = mid - 1;
      }
    }

    return returnIndex ? 0xFFFFFFFF : 0;
  }

  /// Performs a linked list search through structures.
  ///
  /// Spec: "linkedsearch L1 L2 L3 L4 L5 L6 S1"
  int _doLinkedSearch(int key, int keySize, int start, int keyOffset, int nextOffset, int options) {
    final keyIndirect = (options & 1) != 0;
    final zeroKeyTerminates = (options & 2) != 0;

    var currentAddr = start;
    while (currentAddr != 0) {
      // Check for zero key terminator
      if (zeroKeyTerminates && _isZeroKey(currentAddr + keyOffset, keySize)) {
        break;
      }

      // Compare keys
      final cmp = _compareKeys(key, currentAddr + keyOffset, keySize, keyIndirect);
      if (cmp == 0) {
        return currentAddr;
      }

      currentAddr = memoryMap.readWord(currentAddr + nextOffset);
    }

    return 0;
  }

  /// Compares the target key with the key at [structKeyAddr].
  ///
  /// Returns:
  /// - 0 if keys are equal
  /// - negative if target key < struct key
  /// - positive if target key > struct key
  ///
  /// Spec: When KeyIndirect is set, the [key] parameter is an address.
  /// Keys are compared as big-endian unsigned integers.
  int _compareKeys(int key, int structKeyAddr, int keySize, bool keyIndirect) {
    if (keyIndirect) {
      // Key is an address pointing to key data - compare byte by byte
      return _compareKeyBytes(key, structKeyAddr, keySize);
    } else {
      // Key is the actual value - keySize must be 1, 2, or 4
      final structKey = _readKeyValue(structKeyAddr, keySize);
      // Mask the target key to the appropriate size
      final maskedKey = _maskKeyToSize(key, keySize);
      if (maskedKey < structKey) return -1;
      if (maskedKey > structKey) return 1;
      return 0;
    }
  }

  /// Compares two keys byte-by-byte at the given addresses.
  /// Keys are treated as big-endian unsigned integers.
  int _compareKeyBytes(int keyAddr1, int keyAddr2, int keySize) {
    for (var i = 0; i < keySize; i++) {
      final b1 = memoryMap.readByte(keyAddr1 + i);
      final b2 = memoryMap.readByte(keyAddr2 + i);
      if (b1 < b2) return -1;
      if (b1 > b2) return 1;
    }
    return 0;
  }

  /// Checks if the key at [addr] is all zeros.
  bool _isZeroKey(int addr, int keySize) {
    for (var i = 0; i < keySize; i++) {
      if (memoryMap.readByte(addr + i) != 0) return false;
    }
    return true;
  }

  /// Reads a key value from memory. Only valid for sizes 1, 2, or 4.
  int _readKeyValue(int addr, int size) {
    switch (size) {
      case 1:
        return memoryMap.readByte(addr);
      case 2:
        return memoryMap.readShort(addr);
      case 4:
        return memoryMap.readWord(addr);
      default:
        throw GlulxException(
          'Invalid key size for direct key comparison: $size. '
          'KeyIndirect flag must be set for non-standard key sizes.',
        );
    }
  }

  /// Masks a key value to the appropriate size.
  /// Spec: "If the KeySize is 1 or 2, the lower bytes of the Key are used
  /// and the upper bytes ignored."
  int _maskKeyToSize(int key, int size) {
    switch (size) {
      case 1:
        return key & 0xFF;
      case 2:
        return key & 0xFFFF;
      case 4:
        return key & 0xFFFFFFFF;
      default:
        throw GlulxException(
          'Invalid key size for direct key comparison: $size. '
          'KeyIndirect flag must be set for non-standard key sizes.',
        );
    }
  }
}

class StoreOperand {
  final int mode;
  final int addr;
  StoreOperand(this.mode, this.addr);

  @override
  String toString() {
    return 'Store(mode: $mode, addr: $addr)';
  }
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

/// Signal class thrown when a compressed string decoder encounters an indirect
/// function call. Used to escape from the decoder and let the main loop handle
/// the function call.
/// Reference: C interpreter uses return statements to exit stream_string for function calls.
class _StringFunctionCall {
  final int funcAddr;
  final List<int> args;
  final int resumeAddr;
  final int resumeBit;

  _StringFunctionCall(this.funcAddr, this.args, this.resumeAddr, this.resumeBit);
}

/// Signal class thrown when a compressed string decoder encounters an indirect
/// STRING reference. Used to exit decoder so main loop can push 0x10 stub for
/// parent before processing nested string.
/// Reference: C interpreter string.c:386-391 pushes 0x10 stub before nested string.
class _StringNestedCall {
  final int stringAddr;
  final int resumeAddr;
  final int resumeBit;

  _StringNestedCall(this.stringAddr, this.resumeAddr, this.resumeBit);
}

/// Signal class thrown when Filter iosys mode needs to output a character.
/// Each character output requires calling the filter function.
/// Reference: C interpreter string.c:292-301 - for each char, push stubs and call filter.
class _StringFilterCall {
  final int ch;
  final int resumeAddr;
  final int resumeBit;

  _StringFilterCall(this.ch, this.resumeAddr, this.resumeBit);
}

/// Signal class thrown when Filter mode encounters an embedded string node (0x03/0x05).
/// Used to switch from E1 to E0/E2 processing.
/// Reference: C interpreter string.c:330-340 - sets inmiddle to 0xE0/0xE2.
class _StringEmbeddedCall {
  final int dataAddr;
  final int stringType; // 0xE0 or 0xE2
  final int resumeAddr;
  final int resumeBit;

  _StringEmbeddedCall(this.dataAddr, this.stringType, this.resumeAddr, this.resumeBit);
}
