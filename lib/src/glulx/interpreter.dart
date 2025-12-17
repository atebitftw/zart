import 'dart:typed_data';
import 'dart:math' as math;

import 'package:zart/src/glulx/glulx_header.dart';
import 'package:zart/src/glulx/glulx_exception.dart';
import 'package:zart/src/glulx/glulx_op.dart';
import 'package:zart/src/glulx/glulx_stack.dart';
import 'package:zart/src/glulx/op_code_info.dart';
import 'package:zart/src/io/glk/glk_io_provider.dart';
import 'package:zart/src/io/glk/glk_io_selectors.dart';
import 'package:zart/src/logging.dart';

/// Glulx Interpreter
class GlulxInterpreter {
  late ByteData _memory;

  /// Currently public for unit testing.
  ByteData get memory => _memory;
  // We keep the raw Uint8List for easy resizing/copying if needed, unique to Glulx memory model
  late Uint8List _rawMemory;

  // Registers
  int _pc = 0; // Program Counter
  int _fp = 0; // Frame Pointer

  // The Stack
  GlulxStack _stack = GlulxStack();

  // Header Info
  int _ramStart = 0;
  int _extStart = 0;
  int _endMem = 0;

  /// Gets the ram start address.
  int get ramStart => _ramStart;

  /// Gets the external memory start address.
  int get extStart => _extStart;

  /// Gets the end of memory address.
  int get endMem => _endMem;

  /// IO provider for Glulx interpreter.
  final GlkIoProvider? io;

  /// Debug mode flag.
  bool debugMode = false;

  bool _running = false;

  // I/O system state
  int _ioSysMode = 0; // 0=null, 1=filter, 2=glk
  int _ioSysRock = 0;

  // Float conversion buffers
  final Float32List _floatBuf = Float32List(1);
  late final Int32List _floatIntView = Int32List.view(_floatBuf.buffer);

  // ignore: unused_field
  int _stringTbl = 0; // String decoding table address

  math.Random _random_rng = math.Random();

  void _setRandom(int seed) {
    if (seed == 0) {
      _random_rng = math.Random();
    } else {
      _random_rng = math.Random(seed);
    }
  }

  /// Create a new Glulx interpreter.
  GlulxInterpreter({this.io});

  /// Load a Glulx game file into memory.
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
    _rawMemory = Uint8List(_endMem);
    int initialSize = gameBytes.length;
    if (initialSize > _extStart) initialSize = _extStart;

    for (int i = 0; i < initialSize; i++) {
      _rawMemory[i] = gameBytes[i];
    }
    _memory = ByteData.sublistView(_rawMemory);

    // Initialize Stack
    _stack = GlulxStack(size: stackLen);
    _fp = 0;

    // Set PC via _enterFunction to handle initial stack frame.
    // Spec: "Execution commences by calling this function."
    // DestType 0 (discard), DestAddr 0.
    // Arguments: none.
    _enterFunction(startFunc, [], 0, 0);
  }

  void _enterFunction(int addr, List<int> args, int destType, int destAddr) {
    // 1. Push Call Stub
    _stack.pushCallStub(destType, destAddr, _pc, _fp);

    // 2. Read Function Header
    final funcType = _memRead8(addr);

    // Locals Format List
    int localsPos = addr + 1; // Skip Type byte

    // 1st pass: Calculate frame size and locals offsets.
    int formatPtr = localsPos;
    while (true) {
      int lType = _memRead8(formatPtr);
      int lCount = _memRead8(formatPtr + 1);
      formatPtr += 2;
      if (lType == 0 && lCount == 0) break;
    }

    while ((formatPtr - localsPos) % 4 != 0) {
      formatPtr += 2;
    }

    final newFp = _stack.sp;

    // Locals Data starts...
    _stack.push(0); // Placeholder for FrameLen
    _stack.push(0); // Placeholder for LocalsPos

    // Copy format bytes.
    int fPtr = localsPos;
    int stackFormatStart = _stack.sp;

    while (true) {
      int lType = _memRead8(fPtr);
      int lCount = _memRead8(fPtr + 1);
      fPtr += 2;

      _stack.write8(_stack.sp, lType);
      _stack.write8(_stack.sp + 1, lCount);
      _stack.sp += 2;

      if (lType == 0 && lCount == 0) break;
    }

    // Align Stack to 4 bytes
    while ((_stack.sp - newFp) % 4 != 0) {
      _stack.write8(_stack.sp, 0);
      _stack.sp++;
    }

    // Value of LocalsPos (offset from FP where locals data starts)
    final localsDataStartOffset = _stack.sp - newFp;
    _stack.write32(newFp + 4, localsDataStartOffset);

    // Now initialize locals.
    int currentArgIndex = 0;
    int formatReadPtr = stackFormatStart;

    while (true) {
      int lType = _stack.read8(formatReadPtr);
      int lCount = _stack.read8(formatReadPtr + 1);
      formatReadPtr += 2;

      if (lType == 0 && lCount == 0) break; // End of list

      // Align _sp according to lType
      if (lType == 2) {
        while (_stack.sp % 2 != 0) {
          _stack.write8(_stack.sp, 0);
          _stack.sp++;
        }
      } else if (lType == 4) {
        while (_stack.sp % 4 != 0) {
          _stack.write8(_stack.sp, 0);
          _stack.sp++;
        }
      }

      for (int i = 0; i < lCount; i++) {
        int val = 0;

        if (funcType == 0xC1 && currentArgIndex < args.length) {
          val = args[currentArgIndex++];
        }

        if (lType == 1) {
          _stack.write8(_stack.sp, val);
          _stack.sp += 1;
        } else if (lType == 2) {
          _stack.write16(_stack.sp, val);
          _stack.sp += 2;
        } else if (lType == 4) {
          _stack.write32(_stack.sp, val);
          _stack.sp += 4;
        }
      }
    }

    // Align end of frame to 4 bytes
    while (_stack.sp % 4 != 0) {
      _stack.write8(_stack.sp, 0);
      _stack.sp++;
    }

    // Set FrameLen
    int frameLen = _stack.sp - newFp;
    _stack.write32(newFp, frameLen);

    // Set Registers
    _fp = newFp;
    _pc = fPtr; // Instruction start is right after the format bytes

    // If type C0, push arguments to stack now.
    if (funcType == 0xC0) {
      for (int i = args.length - 1; i >= 0; i--) {
        _stack.push(args[i]);
      }
      _stack.push(args.length);
    }
  }

  void _leaveFunction(int result) {
    if (_fp == 0) {
      // Returning from top-level?
      _running = false;
      return;
    }

    // 1. Restore SP
    _stack.sp = _fp;

    // 2. Pop Call Stub
    final stub = _stack.popCallStub();
    final destType = stub[0];
    final destAddr = stub[1];
    final oldPc = stub[2];
    final framePtr = stub[3];

    // 3. Restore Registers
    _fp = framePtr;
    _pc = oldPc;

    if (_fp == 0) {
      _running = false;
    }

    // 4. Store Result
    _storeResult(destType, destAddr, result);
  }

  Future<void> run({int maxSteps = -1}) async {
    _running = true;

    int steps = 0;
    while (_running) {
      if (maxSteps > 0 && steps++ >= maxSteps) {
        print('Aborting: Max steps reached ($maxSteps)');
        _running = false;
        break;
      }
      // Debug Logging
      if (debugMode) {
        int nextOp = _memRead8(_pc);
        if ((nextOp & 0x80) == 0x80) {
          // Multi-byte
          if ((nextOp & 0x40) == 0) {
            // 2 byte
            int op2 = _memRead8(_pc + 1);
            int fullOp = ((nextOp & 0x7F) << 8) | op2;
            log.info(
              'PC: ${_pc.toRadixString(16)} SP: ${_stack.sp.toRadixString(16)} FP: ${_fp.toRadixString(16)} Op: ${fullOp.toRadixString(16)}',
            );
          } else {
            // 4 byte
            log.info(
              'PC: ${_pc.toRadixString(16)} SP: ${_stack.sp.toRadixString(16)} FP: ${_fp.toRadixString(16)} Op: 4-byte...',
            );
          }
        } else {
          log.info(
            'PC: ${_pc.toRadixString(16)} SP: ${_stack.sp.toRadixString(16)} FP: ${_fp.toRadixString(16)} Op: ${nextOp.toRadixString(16)}',
          );
        }
      }

      // Fetch Opcode
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
        case GlulxOp.nop: // nop
          break;

        case GlulxOp.call: // call
          // call(func, numArgs, dest)
          int funcAddr = operands[0];
          int numArgs = operands[1];
          // Reads 'numArgs' arguments from the stack.
          List<int> funcArgs = [];
          for (int i = 0; i < numArgs; i++) {
            funcArgs.add(_stack.pop());
          }
          _enterFunction(funcAddr, funcArgs, destTypes[2], operands[2]);
          break;

        case GlulxOp.ret: // return (0x31)
          _leaveFunction(operands[0]);
          break;

        case GlulxOp.catchEx: // catch (0x32)
          // catch(dest, branch)
          int branchOffset = operands[1]; // L1
          int nextPC = _pc;

          // Push Call Stub (DestType, DestAddr, NextPC, FP)
          _stack.pushCallStub(destTypes[0], operands[0], nextPC, _fp);

          // Token is the value of SP after pushing the stub
          int token = _stack.sp;

          // Store the Token in S1
          _storeResult(destTypes[0], operands[0], token);

          // Branch to L1
          if (branchOffset == 0 || branchOffset == 1) {
            _leaveFunction(branchOffset);
          } else {
            // "The branch is to (Addr + L1 - 2)" where Addr is _pc (instruction end)
            _pc = (_pc + branchOffset - 2) & 0xFFFFFFFF;
          }
          break;

        case GlulxOp.throwEx: // throw (0x33)
          // throw(val, token)
          int val = operands[0];
          int token = operands[1];

          // Validation
          if (_stack.sp < token) throw GlulxException('throw: Invalid Token (SP < Token)');

          // Unwind Stack to Token
          _stack.sp = token;

          // Pop Call Stub (LIFO: FP, PC, Addr, Type)
          final stub = _stack.popCallStub();
          final destType = stub[0];
          final destAddr = stub[1];
          final oldPc = stub[2];
          final oldFp = stub[3];

          // Restore Registers
          _fp = oldFp;
          _pc = oldPc;

          // Store Thrown Value
          _storeResult(destType, destAddr, val);
          break;

        case GlulxOp.random: // random (0x100)
          int range = operands[0];
          int result = 0;
          if (range == 0) {
            result = _random_rng.nextInt(1 << 32);
          } else if (range > 0) {
            result = _random_rng.nextInt(range);
          } else {
            result = -(_random_rng.nextInt(-range));
          }
          _storeResult(destTypes[1], operands[1], result);
          break;

        case GlulxOp.setrandom: // setrandom (0x101)
          _setRandom(operands[0]);
          break;

        case GlulxOp.verify: // verify (0x128)
          // Stub: Always pass. Real verification requires original file checksumming.
          _storeResult(destTypes[0], operands[0], 0);
          break;

        case GlulxOp.streamnum: // streamnum (0x71)
          _streamNum(operands[0]);
          break;

        case GlulxOp.streamstr: // streamstr (0x72)
          _streamString(operands[0]);
          break;

        case GlulxOp.gestalt: // gestalt (0x04)
          // gestalt(selector, arg) -> val
          int val = 0;

          val = await io!.glkDispatch(GlkIoSelectors.gestalt, operands);

          _storeResult(destTypes[2], operands[2], val);
          break;

        case GlulxOp.debugtrap: // debugtrap (0x05)
          if (debugMode) {
            print('Glulx Debug Trap at 0x${(_pc - opLen).toRadixString(16)}');
          }
          break;

        case GlulxOp.getmemsize: // getmemsize (0x08)
          _storeResult(destTypes[0], operands[0], _memory.lengthInBytes);
          break;

        case GlulxOp.setmemsize: // setmemsize (0x09)
          int newSize = operands[0];
          int result = 0; // 0 Success, 1 Fail

          if (newSize < _endMem || newSize % 256 != 0) {
            result = 1;
          } else {
            try {
              if (newSize != _rawMemory.length) {
                Uint8List newRaw = Uint8List(newSize);
                // Copy existing
                int copyLen = math.min(_rawMemory.length, newSize);
                for (int i = 0; i < copyLen; i++) {
                  newRaw[i] = _rawMemory[i];
                }
                _rawMemory = newRaw;
                _memory = ByteData.sublistView(_rawMemory);
              }
              result = 0;
            } catch (e) {
              result = 1;
            }
          }
          _storeResult(destTypes[1], operands[1], result);
          break;

        case GlulxOp.jumpabs: // jumpabs (0x0A)
          _pc = operands[0];
          break;

        case GlulxOp.tailcall: // tailcall
          // tailcall(func, numArgs)
          int tFuncAddr = operands[0];
          int tNumArgs = operands[1];
          List<int> tArgs = [];
          for (int i = 0; i < tNumArgs; i++) {
            tArgs.add(_stack.pop());
          }

          // Logic:
          // 1. Grab current Stub info (DestType/DestAddr/PC/FP) from the stack *below* current frame.
          // Unwind mechanism: _sp = _fp.
          _stack.sp = _fp; // Discard locals

          // Peek at stub (don't pop).
          // However, `_enterFunction` pushes a NEW stub.
          // So we must POP the old stub temporarily to get its values, then pass those to `_enterFunction`.
          // Using popCallStub to get the list
          final stub = _stack.popCallStub();
          final oldDestType = stub[0];
          final oldDestAddr = stub[1];
          final oldPc = stub[2];
          final oldFp = stub[3];

          // Temporarily set registers to old values so _enterFunction pushes them correctly?
          // No, _enterFunction pushes _pc and _fp.
          // We want the new stub to match the OLD stub.
          // _enterFunction: `_pushCallStub(destType, destAddr, _pc, _fp);`
          // So we set _pc = oldPc, _fp = oldFp before calling.
          _fp = oldFp;
          _pc = oldPc;

          _enterFunction(tFuncAddr, tArgs, oldDestType, oldDestAddr);
          break;

        case GlulxOp.stkcount: // stkcount
          // Counts values on stack *above* the current call frame.
          // (_sp - (_fp + frameLen)) / 4
          int frameLen = _stack.read32(_fp);
          int countVal = (_stack.sp - (_fp + frameLen)) ~/ 4;
          _storeResult(destTypes[0], operands[0], countVal);
          break;

        case GlulxOp.stkpeek: // stkpeek
          // stkpeek(pos, dest)
          int pos = operands[0];
          if (_stack.sp - 4 * (pos + 1) < _fp + _stack.read32(_fp)) {
            throw GlulxException('stkpeek: Stack Underflow');
          }
          int peekVal = _stack.read32(_stack.sp - 4 * (pos + 1));
          _storeResult(destTypes[1], operands[1], peekVal);
          break;

        case GlulxOp.stkswap: // stkswap
          if (_stack.sp - 8 < _fp + _stack.read32(_fp)) throw GlulxException('stkswap: Stack Underflow');
          int v1 = _stack.pop();
          int v2 = _stack.pop();
          _stack.push(v1);
          _stack.push(v2);
          break;

        case GlulxOp.stkroll: // stkroll
          int items = operands[0];
          int dist = operands[1];
          if (items == 0) break;

          dist = dist % items;
          if (dist == 0) break;
          if (dist < 0) dist += items;

          List<int> vals = [];
          for (int i = 0; i < items; i++) {
            vals.add(_stack.pop());
          }

          List<int> rotated = vals.sublist(items - dist) + vals.sublist(0, items - dist);

          for (int i = rotated.length - 1; i >= 0; i--) {
            _stack.push(rotated[i]);
          }
          break;

        case GlulxOp.stkcopy: // stkcopy
          int count = operands[0];
          List<int> vals = [];
          for (int i = 0; i < count; i++) {
            vals.add(_stack.read32(_stack.sp - 4 * (i + 1)));
          }
          for (int i = count - 1; i >= 0; i--) {
            _stack.push(vals[i]);
          }
          break;

        case GlulxOp.streamchar: // streamchar
          final charCode = operands[0];
          if (io != null) {
            await io!.glkDispatch(GlkIoSelectors.getCharStream, [0, charCode]);
          }
          break;
        case GlulxOp.add: // add
          var val = (operands[0] + operands[1]) & 0xFFFFFFFF;
          _storeResult(destTypes[2], operands[2], val);
          break;
        case GlulxOp.sub: // sub
          var val = (operands[0] - operands[1]) & 0xFFFFFFFF;
          _storeResult(destTypes[2], operands[2], val);
          break;
        case GlulxOp.mul: // mul
          var val = (operands[0] * operands[1]) & 0xFFFFFFFF;
          _storeResult(destTypes[2], operands[2], val);
          break;
        case GlulxOp.div: // div
          if (operands[1] == 0) throw GlulxException('Division by zero');
          int op1 = operands[0].toSigned(32);
          int op2 = operands[1].toSigned(32);
          var val = (op1 ~/ op2);
          _storeResult(destTypes[2], operands[2], val);
          break;
        case GlulxOp.mod: // mod
          int op1 = operands[0].toSigned(32);
          int op2 = operands[1].toSigned(32);
          if (op2 == 0) throw GlulxException('Division by zero');
          var val = op1.remainder(op2);
          _storeResult(destTypes[2], operands[2], val);
          break;
        case GlulxOp.neg: // neg
          var val = (-operands[0]) & 0xFFFFFFFF;
          _storeResult(destTypes[1], operands[1], val);
          break;
        case GlulxOp.copy: // copy
          _storeResult(destTypes[1], operands[1], operands[0]);
          break;
        case GlulxOp.copys: // copys
          _storeResult(destTypes[1], operands[1], operands[0] & 0xFFFF, size: 2);
          break;
        case GlulxOp.copyb: // copyb
          _storeResult(destTypes[1], operands[1], operands[0] & 0xFF, size: 1);
          break;

        case GlulxOp.bitand: // bitand
          var val = (operands[0] & operands[1]) & 0xFFFFFFFF;
          _storeResult(destTypes[2], operands[2], val);
          break;
        case GlulxOp.bitor: // bitor
          var val = (operands[0] | operands[1]) & 0xFFFFFFFF;
          _storeResult(destTypes[2], operands[2], val);
          break;
        case GlulxOp.bitxor: // bitxor
          var val = (operands[0] ^ operands[1]) & 0xFFFFFFFF;
          _storeResult(destTypes[2], operands[2], val);
          break;
        case GlulxOp.bitnot: // bitnot
          var val = (~operands[0]) & 0xFFFFFFFF;
          _storeResult(destTypes[1], operands[1], val);
          break;

        case GlulxOp.jump: // jump
          _branch(operands[0]);
          break;
        case GlulxOp.jz: // jz
          if (operands[0] == 0) _branch(operands[1]);
          break;
        case GlulxOp.jnz: // jnz
          if (operands[0] != 0) _branch(operands[1]);
          break;
        case GlulxOp.jeq: // jeq
          if (operands[0] == operands[1]) _branch(operands[2]);
          break;
        case GlulxOp.jne: // jne
          if (operands[0] != operands[1]) _branch(operands[2]);
          break;

        case GlulxOp.jlt: // jlt (signed)
          if (operands[0].toSigned(32) < operands[1].toSigned(32)) _branch(operands[2]);
          break;
        case GlulxOp.jge: // jge (signed)
          if (operands[0].toSigned(32) >= operands[1].toSigned(32)) _branch(operands[2]);
          break;
        case GlulxOp.jgt: // jgt
          if (operands[0].toSigned(32) > operands[1].toSigned(32)) _branch(operands[2]);
          break;
        case GlulxOp.jle: // jle
          if (operands[0].toSigned(32) <= operands[1].toSigned(32)) _branch(operands[2]);
          break;

        case GlulxOp.jltu: // jltu (unsigned)
          if ((operands[0] & 0xFFFFFFFF) < (operands[1] & 0xFFFFFFFF)) _branch(operands[2]);
          break;
        case GlulxOp.jgeu: // jgeu (unsigned)
          if ((operands[0] & 0xFFFFFFFF) >= (operands[1] & 0xFFFFFFFF)) _branch(operands[2]);
          break;

        case GlulxOp.shiftl: // shiftl
          int val = (operands[0] << operands[1]) & 0xFFFFFFFF;
          _storeResult(destTypes[2], operands[2], val);
          break;
        case GlulxOp.sshiftr: // sshiftr (Arithmetic)
          int val = operands[0].toSigned(32) >> operands[1];
          _storeResult(destTypes[2], operands[2], val);
          break;
        case GlulxOp.ushiftr: // ushiftr (Logical)
          int val = (operands[0] & 0xFFFFFFFF) >> operands[1];
          _storeResult(destTypes[2], operands[2], val);
          break;
        case GlulxOp.sexs: // sexs
          int val = operands[0].toSigned(16) & 0xFFFFFFFF;
          _storeResult(destTypes[1], operands[1], val);
          break;
        case GlulxOp.sexb: // sexb
          int val = operands[0].toSigned(8) & 0xFFFFFFFF;
          _storeResult(destTypes[1], operands[1], val);
          break;
        case GlulxOp.aload: // aload
          int addr = operands[0] + 4 * operands[1];
          int val = _memRead32(addr);
          _storeResult(destTypes[2], operands[2], val);
          break;
        case GlulxOp.aloads: // aloads
          int addr = operands[0] + 2 * operands[1];
          int val = _memRead16(addr); // Zero extended
          _storeResult(destTypes[2], operands[2], val);
          break;
        case GlulxOp.aloadb: // aloadb
          int addr = operands[0] + operands[1];
          int val = _memRead8(addr);
          _storeResult(destTypes[2], operands[2], val);
          break;
        case GlulxOp.astore: // astore
          int addr = operands[0] + 4 * operands[1];
          _memWrite32(addr, operands[2]);
          break;
        case GlulxOp.astores: // astores
          int addr = operands[0] + 2 * operands[1];
          _memWrite16(addr, operands[2]);
          break;
        case GlulxOp.astoreb: // astoreb
          int addr = operands[0] + operands[1];
          _memWrite8(addr, operands[2]);
          break;

        case GlulxOp.glk: // glk
          // glk(id, numargs) -> res
          final id = operands[0];
          final numArgs = operands[1];
          final args = <int>[];
          for (var i = 0; i < numArgs; i++) {
            args.add(_stack.pop());
          }

          if (io != null) {
            final res = await io!.glkDispatch(id, args);
            _storeResult(destTypes[2], operands[2], res);
          } else {
            _storeResult(destTypes[2], operands[2], 0);
          }
          break;

        case GlulxOp.quit: // quit
          _running = false;
          break;

        // New opcodes - unsigned branch comparisons
        case GlulxOp.jgtu: // jgtu (unsigned >)
          if ((operands[0] & 0xFFFFFFFF) > (operands[1] & 0xFFFFFFFF)) _branch(operands[2]);
          break;
        case GlulxOp.jleu: // jleu (unsigned <=)
          if ((operands[0] & 0xFFFFFFFF) <= (operands[1] & 0xFFFFFFFF)) _branch(operands[2]);
          break;

        // Bit operations
        case GlulxOp.aloadbit: // aloadbit L1 L2 S1
          {
            int baseAddr = operands[0];
            int bitNum = operands[1].toSigned(32);
            int addr = baseAddr + (bitNum ~/ 8);
            int bit = bitNum % 8;
            if (bit < 0) {
              addr--;
              bit += 8;
            }
            int byteVal = _memRead8(addr);
            int result = (byteVal >> bit) & 1;
            _storeResult(destTypes[2], operands[2], result);
          }
          break;
        case GlulxOp.astorebit: // astorebit L1 L2 L3
          {
            int baseAddr = operands[0];
            int bitNum = operands[1].toSigned(32);
            int addr = baseAddr + (bitNum ~/ 8);
            int bit = bitNum % 8;
            if (bit < 0) {
              addr--;
              bit += 8;
            }
            int byteVal = _memRead8(addr);
            if (operands[2] != 0) {
              byteVal |= (1 << bit); // Set bit
            } else {
              byteVal &= ~(1 << bit); // Clear bit
            }
            _memWrite8(addr, byteVal);
          }
          break;

        // Unicode output
        case GlulxOp.streamunichar: // streamunichar L1
          if (_ioSysMode == 2) {
            // Glk mode - call put_char_uni (0x0080)
            io?.glkDispatch(GlkIoSelectors.putCharUni, [operands[0]]);
          }
          break;

        // Floating Point Operations
        case GlulxOp.numtof: // numtof L1 S1
          _floatBuf[0] = operands[0].toDouble();
          _storeResult(destTypes[1], operands[1], _floatIntView[0]);
          break;
        case GlulxOp.ftonumz: // ftonumz L1 S1
          _floatIntView[0] = operands[0];
          int valZ;
          if (_floatBuf[0].isNaN || _floatBuf[0].isInfinite) {
            valZ = _floatBuf[0] < 0 ? -2147483648 : 2147483647; // 0x80000000 or 0x7FFFFFFF
          } else {
            valZ = _floatBuf[0].truncate();
          }
          // Use raw 32-bit int cast for safety though .truncate() usually returns int
          _storeResult(destTypes[1], operands[1], valZ & 0xFFFFFFFF);
          break;
        case GlulxOp.ftonumn: // ftonumn L1 S1
          _floatIntView[0] = operands[0];
          int valN;
          if (_floatBuf[0].isNaN || _floatBuf[0].isInfinite) {
            valN = _floatBuf[0] < 0 ? -2147483648 : 2147483647;
          } else {
            valN = _floatBuf[0].round();
          }
          _storeResult(destTypes[1], operands[1], valN & 0xFFFFFFFF);
          break;

        case GlulxOp.ceil: // ceil L1 S1
          _floatIntView[0] = operands[0];
          _floatBuf[0] = _floatBuf[0].ceilToDouble();
          _storeResult(destTypes[1], operands[1], _floatIntView[0]);
          break;
        case GlulxOp.floor: // floor L1 S1
          _floatIntView[0] = operands[0];
          _floatBuf[0] = _floatBuf[0].floorToDouble();
          _storeResult(destTypes[1], operands[1], _floatIntView[0]);
          break;

        case GlulxOp.fadd: // fadd L1 L2 S1
          _floatIntView[0] = operands[0];
          double f1 = _floatBuf[0];
          _floatIntView[0] = operands[1];
          double f2 = _floatBuf[0];
          _floatBuf[0] = f1 + f2;
          _storeResult(destTypes[2], operands[2], _floatIntView[0]);
          break;
        case GlulxOp.fsub: // fsub L1 L2 S1
          _floatIntView[0] = operands[0];
          double f1 = _floatBuf[0];
          _floatIntView[0] = operands[1];
          double f2 = _floatBuf[0];
          _floatBuf[0] = f1 - f2;
          _storeResult(destTypes[2], operands[2], _floatIntView[0]);
          break;
        case GlulxOp.fmul: // fmul L1 L2 S1
          _floatIntView[0] = operands[0];
          double f1 = _floatBuf[0];
          _floatIntView[0] = operands[1];
          double f2 = _floatBuf[0];
          _floatBuf[0] = f1 * f2;
          _storeResult(destTypes[2], operands[2], _floatIntView[0]);
          break;
        case GlulxOp.fdiv: // fdiv L1 L2 S1
          _floatIntView[0] = operands[0];
          double f1 = _floatBuf[0];
          _floatIntView[0] = operands[1];
          double f2 = _floatBuf[0];
          _floatBuf[0] = f1 / f2;
          _storeResult(destTypes[2], operands[2], _floatIntView[0]);
          break;
        case GlulxOp.fmod: // fmod L1 L2 S1
          _floatIntView[0] = operands[0];
          double f1 = _floatBuf[0];
          _floatIntView[0] = operands[1];
          double f2 = _floatBuf[0];
          // fmod is remainder, typically f1 % f2 but for floats. Dart's % operator works on doubles.
          // Spec says: "remainder of the division f1 / f2"
          if (f2 == 0) {
            _floatBuf[0] = double.nan; // Or implementation defined? Spec implies NaN or Inf for /0?
            // Actually, modulo by zero is usually partial result or NaN. Dart % 0 is NaN.
          } else {
            _floatBuf[0] = f1 % f2;
          }
          _storeResult(destTypes[2], operands[2], _floatIntView[0]);
          break;

        case GlulxOp.sqrt: // sqrt L1 S1
          _floatIntView[0] = operands[0];
          _floatBuf[0] = math.sqrt(_floatBuf[0]);
          _storeResult(destTypes[1], operands[1], _floatIntView[0]);
          break;
        case GlulxOp.exp: // exp L1 S1
          _floatIntView[0] = operands[0];
          _floatBuf[0] = math.exp(_floatBuf[0]);
          _storeResult(destTypes[1], operands[1], _floatIntView[0]);
          break;
        case GlulxOp.log: // log L1 S1
          _floatIntView[0] = operands[0];
          _floatBuf[0] = math.log(_floatBuf[0]);
          _storeResult(destTypes[1], operands[1], _floatIntView[0]);
          break;
        case GlulxOp.pow: // pow L1 L2 S1
          _floatIntView[0] = operands[0];
          double f1 = _floatBuf[0];
          _floatIntView[0] = operands[1];
          double f2 = _floatBuf[0];
          _floatBuf[0] = math.pow(f1, f2).toDouble();
          _storeResult(destTypes[2], operands[2], _floatIntView[0]);
          break;

        case GlulxOp.sin: // sin L1 S1
          _floatIntView[0] = operands[0];
          _floatBuf[0] = math.sin(_floatBuf[0]);
          _storeResult(destTypes[1], operands[1], _floatIntView[0]);
          break;
        case GlulxOp.cos: // cos L1 S1
          _floatIntView[0] = operands[0];
          _floatBuf[0] = math.cos(_floatBuf[0]);
          _storeResult(destTypes[1], operands[1], _floatIntView[0]);
          break;
        case GlulxOp.tan: // tan L1 S1
          _floatIntView[0] = operands[0];
          _floatBuf[0] = math.tan(_floatBuf[0]);
          _storeResult(destTypes[1], operands[1], _floatIntView[0]);
          break;
        case GlulxOp.asin: // asin L1 S1
          _floatIntView[0] = operands[0];
          _floatBuf[0] = math.asin(_floatBuf[0]);
          _storeResult(destTypes[1], operands[1], _floatIntView[0]);
          break;
        case GlulxOp.acos: // acos L1 S1
          _floatIntView[0] = operands[0];
          _floatBuf[0] = math.acos(_floatBuf[0]);
          _storeResult(destTypes[1], operands[1], _floatIntView[0]);
          break;
        case GlulxOp.atan: // atan L1 S1
          _floatIntView[0] = operands[0];
          _floatBuf[0] = math.atan(_floatBuf[0]);
          _storeResult(destTypes[1], operands[1], _floatIntView[0]);
          break;
        case GlulxOp.atan2: // atan2 L1 L2 S1
          _floatIntView[0] = operands[0];
          double f1 = _floatBuf[0];
          _floatIntView[0] = operands[1];
          double f2 = _floatBuf[0];
          _floatBuf[0] = math.atan2(f1, f2);
          _storeResult(destTypes[2], operands[2], _floatIntView[0]);
          break;

        case GlulxOp.jfeq: // jfeq L1 L2 L3
          _floatIntView[0] = operands[0];
          double f1 = _floatBuf[0];
          _floatIntView[0] = operands[1];
          double f2 = _floatBuf[0];
          if (f1 == f2) {
            _branch(operands[2]);
          }
          break;

        case GlulxOp.jfne: // jfne L1 L2 L3
          _floatIntView[0] = operands[0];
          double f1 = _floatBuf[0];
          _floatIntView[0] = operands[1];
          double f2 = _floatBuf[0];
          if (f1 != f2) _branch(operands[2]);
          break;

        case GlulxOp.jflt: // jflt L1 L2 L3
          _floatIntView[0] = operands[0];
          double f1 = _floatBuf[0];
          _floatIntView[0] = operands[1];
          double f2 = _floatBuf[0];
          if (f1 < f2) _branch(operands[2]);
          break;

        case GlulxOp.jfle: // jfle L1 L2 L3
          _floatIntView[0] = operands[0];
          double f1 = _floatBuf[0];
          _floatIntView[0] = operands[1];
          double f2 = _floatBuf[0];
          if (f1 <= f2) _branch(operands[2]);
          break;

        case GlulxOp.jfgt: // jfgt L1 L2 L3
          _floatIntView[0] = operands[0];
          double f1 = _floatBuf[0];
          _floatIntView[0] = operands[1];
          double f2 = _floatBuf[0];
          if (f1 > f2) _branch(operands[2]);
          break;

        case GlulxOp.jfge: // jfge L1 L2 L3
          _floatIntView[0] = operands[0];
          double f1 = _floatBuf[0];
          _floatIntView[0] = operands[1];
          double f2 = _floatBuf[0];
          if (f1 >= f2) _branch(operands[2]);
          break;

        case GlulxOp.jisnan: // jisnan L1 L2
          _floatIntView[0] = operands[0];
          double f1 = _floatBuf[0];
          if (f1.isNaN) _branch(operands[1]);
          break;

        case GlulxOp.jisinf: // jisinf L1 L2
          _floatIntView[0] = operands[0];
          double f1 = _floatBuf[0];
          if (f1.isInfinite) _branch(operands[1]);
          break;

        // Direct function calls
        case GlulxOp.callf: // callf L1 S1
          _enterFunction(operands[0], [], destTypes[1], operands[1]);
          break;
        case GlulxOp.callfi: // callfi L1 L2 S1
          _enterFunction(operands[0], [operands[1]], destTypes[2], operands[2]);
          break;
        case GlulxOp.callfii: // callfii L1 L2 L3 S1
          _enterFunction(operands[0], [operands[1], operands[2]], destTypes[3], operands[3]);
          break;
        case GlulxOp.callfiii: // callfiii L1 L2 L3 L4 S1
          _enterFunction(operands[0], [operands[1], operands[2], operands[3]], destTypes[4], operands[4]);
          break;

        // I/O system
        case GlulxOp.setiosys: // setiosys L1 L2
          _ioSysMode = operands[0];
          _ioSysRock = operands[1];
          // Validate mode - default to null (0) if unsupported
          if (_ioSysMode != 0 && _ioSysMode != 1 && _ioSysMode != 2) {
            _ioSysMode = 0;
          }
          break;
        case GlulxOp.getiosys: // getiosys S1 S2
          _storeResult(destTypes[0], operands[0], _ioSysMode);
          _storeResult(destTypes[1], operands[1], _ioSysRock);
          break;

        // Block copy/clear opcodes
        case GlulxOp.mzero: // mzero L1 L2
          {
            // Write L1 zero bytes starting at address L2
            int count = operands[0];
            int addr = operands[1];
            for (int i = 0; i < count; i++) {
              _memWrite8(addr + i, 0);
            }
          }
          break;
        case GlulxOp.mcopy: // mcopy L1 L2 L3
          {
            // Copy L1 bytes from address L2 to address L3
            // Safe for overlapping regions
            int count = operands[0];
            int src = operands[1];
            int dest = operands[2];
            if (dest < src) {
              for (int i = 0; i < count; i++) {
                _memWrite8(dest + i, _memRead8(src + i));
              }
            } else {
              for (int i = count - 1; i >= 0; i--) {
                _memWrite8(dest + i, _memRead8(src + i));
              }
            }
          }
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
      case 0x7: // Address Any
        value = (_memRead8(_pc) << 24) | (_memRead8(_pc + 1) << 16) | (_memRead8(_pc + 2) << 8) | _memRead8(_pc + 3);
        _pc += 4;
        if (!isStore) value = _memRead32(value);
        break;

      case 0x8: // Stack
        if (!isStore) {
          value = _stack.pop();
        } else {
          value = 0;
        }
        break;

      case 0x9: // Local 00-FF
        value = _memRead8(_pc++);
        {
          int localsPos = _stack.read32(_fp + 4);
          if (!isStore) {
            value = _stack.read32(_fp + localsPos + value);
          } else {
            value = _fp + localsPos + value; // Address for storing
          }
        }
        break;
      case 0xA: // Local 0000-FFFF
        value = (_memRead8(_pc) << 8) | _memRead8(_pc + 1);
        _pc += 2;
        {
          int localsPos = _stack.read32(_fp + 4);
          if (!isStore) {
            value = _stack.read32(_fp + localsPos + value);
          } else {
            value = _fp + localsPos + value;
          }
        }
        break;
      case 0xB: // Local Any
        value = (_memRead8(_pc) << 24) | (_memRead8(_pc + 1) << 16) | (_memRead8(_pc + 2) << 8) | _memRead8(_pc + 3);
        _pc += 4;
        {
          int localsPos = _stack.read32(_fp + 4);
          if (!isStore) {
            value = _stack.read32(_fp + localsPos + value);
          } else {
            value = _fp + localsPos + value;
          }
        }
        break;

      case 0xC: // RAM 00-FF
        value = _memRead8(_pc++);
        value = _ramStart + value;
        if (!isStore) value = _memRead32(value);
        break;
      case 0xD: // RAM 0000-FFFF
        value = (_memRead8(_pc) << 8) | _memRead8(_pc + 1);
        _pc += 2;
        value = _ramStart + value;
        if (!isStore) value = _memRead32(value);
        break;
      case 0xE: // RAM Any
        value = (_memRead8(_pc) << 24) | (_memRead8(_pc + 1) << 16) | (_memRead8(_pc + 2) << 8) | _memRead8(_pc + 3);
        _pc += 4;
        value = (_ramStart + value) & 0xFFFFFFFF;
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

  /// Read a 32-bit value from memory.  Left public for unit testing.
  int memRead32(int addr) {
    return _memRead32(addr);
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

  int _memRead16(int addr) {
    if (addr + 2 > _rawMemory.length) return 0;
    return _memory.getUint16(addr);
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

  void _storeResult(int mode, int address, int value, {int size = 4}) {
    // Ensure value is 32-bit (signed or unsigned doesn't matter for storage bits)
    value &= 0xFFFFFFFF;

    switch (mode) {
      case 0x0: // Discard
        break;
      case 0x8: // Stack (Push)
        _stack.push(value);
        break;

      case 0x9: // Local 00-FF
      case 0xA: // Local 0000-FFFF
      case 0xB: // Local Any
        if (size == 1) {
          _stack.write8(address, value);
        } else if (size == 2) {
          _stack.write16(address, value);
        } else {
          _stack.write32(address, value);
        }
        break;

      case 0x5: // Address 00-FF
      case 0x6: // Address 0000-FFFF
      case 0x7: // Address Any
      case 0xC: // RAM 00-FF
      case 0xD: // RAM 0000-FFFF
      case 0xE: // RAM Any
        // address was calculated during decodeOperand
        if (size == 1) {
          _memWrite8(address, value);
        } else if (size == 2) {
          _memWrite16(address, value);
        } else {
          _memWrite32(address, value);
        }
        break;

      default:
        throw GlulxException('Unsupported Store Mode: $mode');
    }
  }

  void _branch(int offset) {
    // Offset 0 and 1 are special returns
    if (offset == 0 || offset == 1) {
      // Return from function with value 0 or 1
      _leaveFunction(offset); // Correctly allow returning 0/1 from branch
    } else {
      // Offset is from instruction *after* branch.
      _pc += offset.toSigned(32);
    }
  }

  void _streamNum(int val) {
    String s = val.toString();
    for (int char in s.runes) {
      io?.glkDispatch(GlkIoSelectors.putChar, [char]);
    }
  }

  void _streamString(int addr) {
    int type = _memRead8(addr);

    if (type == 0xE0) {
      // C-style string
      int ptr = addr + 1;
      while (true) {
        int char = _memRead8(ptr);
        if (char == 0) break;
        io?.glkDispatch(GlkIoSelectors.putChar, [char]);
        ptr++;
      }
    } else if (type == 0xE2) {
      // Unicode string
      int ptr = addr + 4; // Data starts 4 bytes after type byte
      while (true) {
        int char = _memRead32(ptr);
        if (char == 0) break;
        io?.glkDispatch(GlkIoSelectors.putChar, [char]);
        ptr += 4;
      }
    } else if (type == 0xE1) {
      // Compressed
      // TODO: Implement compressed strings
      _streamNum(60); // <
      // _streamNum(69); // E
      // _streamNum(49); // 1
      // _streamNum(62); // >
      // Compressed string decoding logic would go here
    } else {
      // Unknown
    }
  }
}
