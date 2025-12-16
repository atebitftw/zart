import 'dart:typed_data';
import 'dart:math';

import 'package:zart/src/glulx/glulx_header.dart';
import 'package:zart/src/glulx/glulx_exception.dart';
import 'package:zart/src/glulx/glulx_opcodes.dart';
import 'package:zart/src/glulx/op_code_info.dart';
import 'package:zart/src/io/io_provider.dart';
import 'package:zart/src/logging.dart';

// /// Constants for the Glulx Header.
// class GlulxHeader {
//   static const int magicNumber = 0x00; // 'Glul'
//   static const int version = 0x04;
//   static const int ramStart = 0x08;
//   static const int extStart = 0x0C;
//   static const int endMem = 0x10;
//   static const int stackSize = 0x14;
//   static const int startFunc = 0x18;
//   static const int decodingTbl = 0x1C;
//   static const int checksum = 0x20;
//   static const int size = 36;
// }

/// Glulx Interpreter
class GlulxInterpreter {
  late ByteData _memory;
  ByteData get memory => _memory;
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

  int get ramStart => _ramStart;
  int get extStart => _extStart;
  int get endMem => _endMem;

  /// IO provider for Glulx interpreter.
  final IoProvider? io;

  /// Debug mode flag.
  bool debugMode = false;

  bool _running = false;

  Random _random_rng = Random();

  void _setRandom(int seed) {
    if (seed == 0) {
      _random_rng = Random();
    } else {
      _random_rng = Random(seed);
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
    _stack = ByteData(stackLen);
    _sp = 0;
    _fp = 0;

    // Set PC via _enterFunction to handle initial stack frame.
    // Spec: "Execution commences by calling this function."
    // DestType 0 (discard), DestAddr 0.
    // Arguments: none.
    _enterFunction(startFunc, [], 0, 0);
  }

  void _pushCallStub(int destType, int destAddr, int pc, int framePtr) {
    _push(destType);
    _push(destAddr);
    _push(pc);
    _push(framePtr);
  }

  void _enterFunction(int addr, List<int> args, int destType, int destAddr) {
    // 1. Push Call Stub
    _pushCallStub(destType, destAddr, _pc, _fp);

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

    final newFp = _sp;

    // Locals Data starts...
    _push(0); // Placeholder for FrameLen
    _push(0); // Placeholder for LocalsPos

    // Copy format bytes.
    int fPtr = localsPos;
    int stackFormatStart = _sp;

    while (true) {
      int lType = _memRead8(fPtr);
      int lCount = _memRead8(fPtr + 1);
      fPtr += 2;

      _stackWrite8(_sp, lType);
      _stackWrite8(_sp + 1, lCount);
      _sp += 2;

      if (lType == 0 && lCount == 0) break;
    }

    // Align Stack to 4 bytes
    while ((_sp - newFp) % 4 != 0) {
      _stackWrite8(_sp, 0);
      _sp++;
    }

    // Value of LocalsPos (offset from FP where locals data starts)
    int localsDataStartOffset = _sp - newFp;
    _stackWrite32(newFp + 4, localsDataStartOffset);

    // Now initialize locals.
    int currentArgIndex = 0;
    int formatReadPtr = stackFormatStart;

    while (true) {
      int lType = _stackRead8(formatReadPtr);
      int lCount = _stackRead8(formatReadPtr + 1);
      formatReadPtr += 2;

      if (lType == 0 && lCount == 0) break; // End of list

      // Align _sp according to lType
      if (lType == 2) {
        while (_sp % 2 != 0) {
          _stackWrite8(_sp, 0);
          _sp++;
        }
      } else if (lType == 4) {
        while (_sp % 4 != 0) {
          _stackWrite8(_sp, 0);
          _sp++;
        }
      }

      for (int i = 0; i < lCount; i++) {
        int val = 0;

        if (funcType == 0xC1 && currentArgIndex < args.length) {
          val = args[currentArgIndex++];
        }

        if (lType == 1) {
          _stackWrite8(_sp, val);
          _sp += 1;
        } else if (lType == 2) {
          _stackWrite16(_sp, val);
          _sp += 2;
        } else if (lType == 4) {
          _stackWrite32(_sp, val);
          _sp += 4;
        }
      }
    }

    // Align end of frame to 4 bytes
    while (_sp % 4 != 0) {
      _stackWrite8(_sp, 0);
      _sp++;
    }

    // Set FrameLen
    int frameLen = _sp - newFp;
    _stackWrite32(newFp, frameLen);

    // Set Registers
    _fp = newFp;
    _pc = fPtr; // Instruction start is right after the format bytes

    // If type C0, push arguments to stack now.
    if (funcType == 0xC0) {
      for (int i = args.length - 1; i >= 0; i--) {
        _push(args[i]);
      }
      _push(args.length);
    }
  }

  void _leaveFunction(int result) {
    if (_fp == 0) {
      // Returning from top-level?
      _running = false;
      return;
    }

    // 1. Restore SP
    _sp = _fp;

    // 2. Pop Call Stub
    int framePtr = _pop();
    int pc = _pop();
    int destAddr = _pop();
    int destType = _pop();

    // 3. Restore Registers
    _fp = framePtr;
    _pc = pc;

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
      // Always print for debugging this issue
      int dbgOp = _memRead8(_pc);
      if (true) {
        // Force enable
        print('PC: ${_pc.toRadixString(16)} Op: ${dbgOp.toRadixString(16)}');
      }
      if (debugMode) {
        int nextOp = _memRead8(_pc);
        if ((nextOp & 0x80) == 0x80) {
          // Multi-byte
          if ((nextOp & 0x40) == 0) {
            // 2 byte
            int op2 = _memRead8(_pc + 1);
            int fullOp = ((nextOp & 0x7F) << 8) | op2;
            log.info(
              'PC: ${_pc.toRadixString(16)} SP: ${_sp.toRadixString(16)} FP: ${_fp.toRadixString(16)} Op: ${fullOp.toRadixString(16)}',
            );
          } else {
            // 4 byte
            log.info(
              'PC: ${_pc.toRadixString(16)} SP: ${_sp.toRadixString(16)} FP: ${_fp.toRadixString(16)} Op: 4-byte...',
            );
          }
        } else {
          log.info(
            'PC: ${_pc.toRadixString(16)} SP: ${_sp.toRadixString(16)} FP: ${_fp.toRadixString(16)} Op: ${nextOp.toRadixString(16)}',
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
        case GlulxOpcodes.nop: // nop
          break;

        case GlulxOpcodes.call: // call
          // call(func, numArgs, dest)
          int funcAddr = operands[0];
          int numArgs = operands[1];
          // Reads 'numArgs' arguments from the stack.
          List<int> funcArgs = [];
          for (int i = 0; i < numArgs; i++) {
            funcArgs.add(_pop());
          }
          _enterFunction(funcAddr, funcArgs, destTypes[2], operands[2]);
          break;

        case GlulxOpcodes.ret: // return (0x31)
          _leaveFunction(operands[0]);

        case GlulxOpcodes.catchEx: // catch (0x32)
          // catch(dest, branch)
          int branchOffset = operands[1]; // L1
          int nextPC = _pc;

          // Push Call Stub (DestType, DestAddr, NextPC, FP)
          _pushCallStub(destTypes[0], operands[0], nextPC, _fp);

          // Token is the value of SP after pushing the stub
          int token = _sp;

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

        case GlulxOpcodes.throwEx: // throw (0x33)
          // throw(val, token)
          int val = operands[0];
          int token = operands[1];

          // Validation
          if (_sp < token) throw GlulxException('throw: Invalid Token (SP < Token)');

          // Unwind Stack to Token
          _sp = token;

          // Pop Call Stub (LIFO: FP, PC, Addr, Type)
          int oldFp = _pop();
          int oldPc = _pop();
          int destAddr = _pop();
          int destType = _pop();

          // Restore Registers
          _fp = oldFp;
          _pc = oldPc;

          // Store Thrown Value
          _storeResult(destType, destAddr, val);
          break;

        case GlulxOpcodes.random: // random (0x100)
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

        case GlulxOpcodes.setrandom: // setrandom (0x101)
          _setRandom(operands[0]);
          break;

        case GlulxOpcodes.verify: // verify (0x128)
          // Stub: Always pass. Real verification requires original file checksumming.
          _storeResult(destTypes[0], operands[0], 0);
          break;

        case GlulxOpcodes.streamnum: // streamnum (0x71)
          _streamNum(operands[0]);
          break;

        case GlulxOpcodes.streamstr: // streamstr (0x72)
          _streamString(operands[0]);
          break;

        case GlulxOpcodes.gestalt: // gestalt (0x04)
          // gestalt(selector, arg) -> val
          int selector = operands[0];
          int val = 0;
          switch (selector) {
            case 0: // Glulx Version
              val = 0x00030103; // Version 3.1.3
              break;
            case 1: // Terp Version
              val = 0x00010000; // 1.0.0
              break;
            case 2: // ResizeMem
              val = 1;
              break;
            case 3: // Undo
              val = 1; // Support undo? Maybe later.
              break;
            case 4: // IOSystem
              // Supports 0 (Null), 1 (Filter), 2 (Glk).
              if (operands[1] == 0 || operands[1] == 1 || operands[1] == 2) val = 1;
              break;
            default:
              val = 0;
          }
          _storeResult(destTypes[2], operands[2], val);
          break;

        case GlulxOpcodes.debugtrap: // debugtrap (0x05)
          if (debugMode) {
            print('Glulx Debug Trap at 0x${(_pc - opLen).toRadixString(16)}');
          }
          break;

        case GlulxOpcodes.getmemsize: // getmemsize (0x08)
          _storeResult(destTypes[0], operands[0], _memory.lengthInBytes);
          break;

        case GlulxOpcodes.setmemsize: // setmemsize (0x09)
          int newSize = operands[0];
          int result = 0; // 0 Success, 1 Fail

          if (newSize < _endMem || newSize % 256 != 0) {
            result = 1;
          } else {
            try {
              if (newSize != _rawMemory.length) {
                Uint8List newRaw = Uint8List(newSize);
                // Copy existing
                int copyLen = min(_rawMemory.length, newSize);
                for (int i = 0; i < copyLen; i++) newRaw[i] = _rawMemory[i];
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

        case GlulxOpcodes.jumpabs: // jumpabs (0x0A)
          _pc = operands[0];
          break;

        case GlulxOpcodes.tailcall: // tailcall
          // tailcall(func, numArgs)
          int tFuncAddr = operands[0];
          int tNumArgs = operands[1];
          List<int> tArgs = [];
          for (int i = 0; i < tNumArgs; i++) {
            tArgs.add(_pop());
          }

          // Logic:
          // 1. Grab current Stub info (DestType/DestAddr/PC/FP) from the stack *below* current frame.
          // Unwind mechanism: _sp = _fp.
          _sp = _fp; // Discard locals

          // Peek at stub (don't pop).
          // However, `_enterFunction` pushes a NEW stub.
          // So we must POP the old stub temporarily to get its values, then pass those to `_enterFunction`.
          int oldFp = _pop();
          int oldPc = _pop();
          int oldDestAddr = _pop();
          int oldDestType = _pop();

          // Temporarily set registers to old values so _enterFunction pushes them correctly?
          // No, _enterFunction pushes _pc and _fp.
          // We want the new stub to match the OLD stub.
          // _enterFunction: `_pushCallStub(destType, destAddr, _pc, _fp);`
          // So we set _pc = oldPc, _fp = oldFp before calling.
          _fp = oldFp;
          _pc = oldPc;

          _enterFunction(tFuncAddr, tArgs, oldDestType, oldDestAddr);
          break;

        case GlulxOpcodes.stkcount: // stkcount
          // Counts values on stack *above* the current call frame.
          // (_sp - (_fp + frameLen)) / 4
          int frameLen = _stackRead32(_fp);
          int val = (_sp - (_fp + frameLen)) ~/ 4;
          _storeResult(destTypes[0], operands[0], val);
          break;

        case GlulxOpcodes.stkpeek: // stkpeek
          // stkpeek(pos, dest)
          int pos = operands[0];
          if (_sp - 4 * (pos + 1) < _fp + _stackRead32(_fp)) {
            throw GlulxException('stkpeek: Stack Underflow');
          }
          int peekVal = _stackRead32(_sp - 4 * (pos + 1));
          _storeResult(destTypes[1], operands[1], peekVal);
          break;

        case GlulxOpcodes.stkswap: // stkswap
          if (_sp - 8 < _fp + _stackRead32(_fp)) throw GlulxException('stkswap: Stack Underflow');
          int v1 = _pop();
          int v2 = _pop();
          _push(v1);
          _push(v2);
          break;

        case GlulxOpcodes.stkroll: // stkroll
          int items = operands[0];
          int dist = operands[1];
          if (items == 0) break;

          dist = dist % items;
          if (dist == 0) break;
          if (dist < 0) dist += items;

          List<int> vals = [];
          for (int i = 0; i < items; i++) vals.add(_pop());

          List<int> rotated = vals.sublist(items - dist) + vals.sublist(0, items - dist);

          for (int i = rotated.length - 1; i >= 0; i--) {
            _push(rotated[i]);
          }
          break;

        case GlulxOpcodes.stkcopy: // stkcopy
          int count = operands[0];
          List<int> vals = [];
          for (int i = 0; i < count; i++) {
            vals.add(_memRead32(_sp - 4 * (i + 1)));
          }
          for (int i = count - 1; i >= 0; i--) {
            _push(vals[i]);
          }
          break;

        case GlulxOpcodes.streamchar: // streamchar
          final charCode = operands[0];
          if (io != null) {
            await io!.glulxGlk(0x81, [0, charCode]);
          }
          break;
        case GlulxOpcodes.add: // add
          var val = (operands[0] + operands[1]) & 0xFFFFFFFF;
          _storeResult(destTypes[2], operands[2], val);
          break;
        case GlulxOpcodes.sub: // sub
          var val = (operands[0] - operands[1]) & 0xFFFFFFFF;
          _storeResult(destTypes[2], operands[2], val);
          break;
        case GlulxOpcodes.mul: // mul
          var val = (operands[0] * operands[1]) & 0xFFFFFFFF;
          _storeResult(destTypes[2], operands[2], val);
          break;
        case GlulxOpcodes.div: // div
          if (operands[1] == 0) throw GlulxException('Division by zero');
          int op1 = operands[0].toSigned(32);
          int op2 = operands[1].toSigned(32);
          var val = (op1 ~/ op2);
          _storeResult(destTypes[2], operands[2], val);
          break;
        case GlulxOpcodes.mod: // mod
          int op1 = operands[0].toSigned(32);
          int op2 = operands[1].toSigned(32);
          if (op2 == 0) throw GlulxException('Division by zero');
          var val = op1.remainder(op2);
          _storeResult(destTypes[2], operands[2], val);
          break;
        case GlulxOpcodes.neg: // neg
          var val = (-operands[0]) & 0xFFFFFFFF;
          _storeResult(destTypes[1], operands[1], val);
          break;
        case GlulxOpcodes.copy: // copy
          _storeResult(destTypes[1], operands[1], operands[0]);
          break;
        case GlulxOpcodes.copys: // copys
          _storeResult(destTypes[1], operands[1], operands[0] & 0xFFFF, size: 2);
          break;
        case GlulxOpcodes.copyb: // copyb
          _storeResult(destTypes[1], operands[1], operands[0] & 0xFF, size: 1);
          break;

        case GlulxOpcodes.bitand: // bitand
          var val = (operands[0] & operands[1]) & 0xFFFFFFFF;
          _storeResult(destTypes[2], operands[2], val);
          break;
        case GlulxOpcodes.bitor: // bitor
          var val = (operands[0] | operands[1]) & 0xFFFFFFFF;
          _storeResult(destTypes[2], operands[2], val);
          break;
        case GlulxOpcodes.bitxor: // bitxor
          var val = (operands[0] ^ operands[1]) & 0xFFFFFFFF;
          _storeResult(destTypes[2], operands[2], val);
          break;
        case GlulxOpcodes.bitnot: // bitnot
          var val = (~operands[0]) & 0xFFFFFFFF;
          _storeResult(destTypes[1], operands[1], val);
          break;

        case GlulxOpcodes.jump: // jump
          _branch(operands[0]);
          break;
        case GlulxOpcodes.jz: // jz
          if (operands[0] == 0) _branch(operands[1]);
          break;
        case GlulxOpcodes.jnz: // jnz
          if (operands[0] != 0) _branch(operands[1]);
          break;
        case GlulxOpcodes.jeq: // jeq
          if (operands[0] == operands[1]) _branch(operands[2]);
          break;
        case GlulxOpcodes.jne: // jne
          if (operands[0] != operands[1]) _branch(operands[2]);
          break;

        case GlulxOpcodes.jlt: // jlt (signed)
          if (operands[0].toSigned(32) < operands[1].toSigned(32)) _branch(operands[2]);
          break;
        case GlulxOpcodes.jge: // jge (signed)
          if (operands[0].toSigned(32) >= operands[1].toSigned(32)) _branch(operands[2]);
          break;
        case GlulxOpcodes.jgt: // jgt
          if (operands[0].toSigned(32) > operands[1].toSigned(32)) _branch(operands[2]);
          break;
        case GlulxOpcodes.jle: // jle
          if (operands[0].toSigned(32) <= operands[1].toSigned(32)) _branch(operands[2]);
          break;

        case GlulxOpcodes.jltu: // jltu (unsigned)
          if ((operands[0] & 0xFFFFFFFF) < (operands[1] & 0xFFFFFFFF)) _branch(operands[2]);
          break;
        case GlulxOpcodes.jgeu: // jgeu (unsigned)
          if ((operands[0] & 0xFFFFFFFF) >= (operands[1] & 0xFFFFFFFF)) _branch(operands[2]);
          break;

        case GlulxOpcodes.shiftl: // shiftl
          int val = (operands[0] << operands[1]) & 0xFFFFFFFF;
          _storeResult(destTypes[2], operands[2], val);
          break;
        case GlulxOpcodes.sshiftr: // sshiftr (Arithmetic)
          int val = operands[0].toSigned(32) >> operands[1];
          _storeResult(destTypes[2], operands[2], val);
          break;
        case GlulxOpcodes.ushiftr: // ushiftr (Logical)
          int val = (operands[0] & 0xFFFFFFFF) >> operands[1];
          _storeResult(destTypes[2], operands[2], val);
          break;
        case GlulxOpcodes.sexs: // sexs
          int val = operands[0].toSigned(16) & 0xFFFFFFFF;
          _storeResult(destTypes[1], operands[1], val);
          break;
        case GlulxOpcodes.sexb: // sexb
          int val = operands[0].toSigned(8) & 0xFFFFFFFF;
          _storeResult(destTypes[1], operands[1], val);
          break;
        case GlulxOpcodes.aload: // aload
          int addr = operands[0] + 4 * operands[1];
          int val = _memRead32(addr);
          _storeResult(destTypes[2], operands[2], val);
          break;
        case GlulxOpcodes.aloads: // aloads
          int addr = operands[0] + 2 * operands[1];
          int val = _memRead16(addr); // Zero extended
          _storeResult(destTypes[2], operands[2], val);
          break;
        case GlulxOpcodes.aloadb: // aloadb
          int addr = operands[0] + operands[1];
          int val = _memRead8(addr);
          _storeResult(destTypes[2], operands[2], val);
          break;
        case GlulxOpcodes.astore: // astore
          int addr = operands[0] + 4 * operands[1];
          _memWrite32(addr, operands[2]);
          break;
        case GlulxOpcodes.astores: // astores
          int addr = operands[0] + 2 * operands[1];
          _memWrite16(addr, operands[2]);
          break;
        case GlulxOpcodes.astoreb: // astoreb
          int addr = operands[0] + operands[1];
          _memWrite8(addr, operands[2]);
          break;

        case GlulxOpcodes.glk: // glk
          // glk(id, numargs) -> res
          final id = operands[0];
          final numArgs = operands[1];
          final args = <int>[];
          for (var i = 0; i < numArgs; i++) {
            args.add(_pop());
          }

          if (io != null) {
            final res = await io!.glulxGlk(id, args);
            _storeResult(destTypes[2], operands[2], res);
          } else {
            _storeResult(destTypes[2], operands[2], 0);
          }
          break;

        case GlulxOpcodes.quit: // quit
          _running = false;
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

      case 0x4: // Address 00-FF
        value = _memRead8(_pc++);
        if (!isStore) value = _memRead32(value);
        break;
      case 0x5: // Address 0000-FFFF
        value = (_memRead8(_pc) << 8) | _memRead8(_pc + 1);
        _pc += 2;
        if (!isStore) value = _memRead32(value);
        break;
      case 0x6: // Address Any
        value = (_memRead8(_pc) << 24) | (_memRead8(_pc + 1) << 16) | (_memRead8(_pc + 2) << 8) | _memRead8(_pc + 3);
        _pc += 4;
        if (!isStore) value = _memRead32(value);
        break;

      case 0x7: // Stack
        if (!isStore)
          value = _pop();
        else
          value = 0;
        break;

      case 0x8: // Local 00-FF
        value = _memRead8(_pc++);
        if (!isStore)
          value = _stackRead32(_fp + value);
        else
          value = _fp + value; // Address for storing
        break;
      case 0x9: // Local 0000-FFFF
        value = (_memRead8(_pc) << 8) | _memRead8(_pc + 1);
        _pc += 2;
        if (!isStore)
          value = _stackRead32(_fp + value);
        else
          value = _fp + value;
        break;
      case 0xA: // Local Any
        value = (_memRead8(_pc) << 24) | (_memRead8(_pc + 1) << 16) | (_memRead8(_pc + 2) << 8) | _memRead8(_pc + 3);
        _pc += 4;
        if (!isStore)
          value = _stackRead32(_fp + value);
        else
          value = _fp + value;
        break;

      case 0xB: // RAM 00-FF
        value = _memRead8(_pc++);
        value = _ramStart + value;
        if (!isStore) value = _memRead32(value);
        break;
      case 0xC: // RAM 0000-FFFF
        value = (_memRead8(_pc) << 8) | _memRead8(_pc + 1);
        _pc += 2;
        value = _ramStart + value;
        if (!isStore) value = _memRead32(value);
        break;
      case 0xD: // RAM Any
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

  // Stack Memory Access
  void _stackWrite8(int addr, int value) {
    if (addr >= _stack.lengthInBytes) throw GlulxException('Stack Overflow (Access)');
    _stack.setUint8(addr, value);
  }

  void _stackWrite16(int addr, int value) {
    if (addr + 2 > _stack.lengthInBytes) throw GlulxException('Stack Overflow (Access)');
    _stack.setUint16(addr, value);
  }

  void _stackWrite32(int addr, int value) {
    if (addr + 4 > _stack.lengthInBytes) throw GlulxException('Stack Overflow (Access)');
    _stack.setUint32(addr, value);
  }

  int _stackRead32(int addr) {
    if (addr + 4 > _stack.lengthInBytes) throw GlulxException('Stack Access Out of Bounds');
    return _stack.getUint32(addr);
  }

  int _stackRead8(int addr) {
    if (addr >= _stack.lengthInBytes) throw GlulxException('Stack Access Out of Bounds');
    return _stack.getUint8(addr);
  }

  int memRead32(int addr) => _memRead32(addr);

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
      case 0x7: // Stack (Push)
        _push(value);
        break;

      case 0x8: // Local 00-FF
      case 0x9: // Local 0000-FFFF
      case 0xA: // Local Any
        if (size == 1) {
          _stackWrite8(address, value);
        } else if (size == 2) {
          _stackWrite16(address, value);
        } else {
          _stackWrite32(address, value);
        }
        break;

      case 0x4: // Address 00-FF
      case 0x5: // Address 0000-FFFF
      case 0x6: // Address Any
      case 0xB: // RAM 00-FF
      case 0xC: // RAM 0000-FFFF
      case 0xD: // RAM Any
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
      io?.glulxGlk(0x0080, [char]);
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
        io?.glulxGlk(0x0080, [char]);
        ptr++;
      }
    } else if (type == 0xE2) {
      // Unicode string
      int ptr = addr + 4; // Data starts 4 bytes after type byte
      while (true) {
        int char = _memRead32(ptr);
        if (char == 0) break;
        io?.glulxGlk(0x0080, [char]);
        ptr += 4;
      }
    } else if (type == 0xE1) {
      // Compressed
      // TODO: Implement compressed strings
      _streamNum(60); // <
      _streamNum(69); // E
      _streamNum(49); // 1
      _streamNum(62); // >
    } else {
      // Unknown
    }
  }
}
