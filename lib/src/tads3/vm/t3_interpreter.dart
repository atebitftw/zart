import 'dart:io';
import 'dart:typed_data';

import 'package:zart/src/loaders/tads/t3_block.dart';
import 'package:zart/src/loaders/tads/t3_exception.dart';
import 'package:zart/src/loaders/tads/t3_image.dart';

import 'package:zart/src/tads3/loaders/entp_parser.dart';
import 'package:zart/src/tads3/loaders/fnsd_parser.dart';
import 'package:zart/src/tads3/loaders/mcld_parser.dart';
import 'package:zart/src/tads3/loaders/objs_parser.dart';
import 'package:zart/src/tads3/loaders/symd_parser.dart';
import 'package:zart/src/tads3/vm/t3_utf8.dart';
import 'package:zart/src/tads3/vm/t3_code_pool.dart';
import 'package:zart/src/tads3/vm/t3_constant_pool.dart';
import 'package:zart/src/tads3/vm/t3_object_table.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_opcodes.dart';
import 'package:zart/src/tads3/vm/t3_registers.dart';
import 'package:zart/src/tads3/vm/t3_stack.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';
import 'package:zart/src/tads3/vm/t3_builtins.dart';
import 'package:zart/src/tads3/vm/t3_function_header.dart';

/// Execution result from a single instruction.
enum T3ExecutionResult {
  /// Continue to next instruction.
  continue_,

  /// Program has exited.
  quit,

  /// Waiting for input.
  waitingForInput,

  /// Error occurred.
  error,
}

/// TADS3 VM interpreter.
///
/// This is the main execution engine for TADS3 programs. It loads T3 image
/// files and executes bytecode instructions according to the T3 specification.
///
/// Usage:
/// ```dart
/// final interpreter = T3Interpreter();
/// interpreter.load(gameData);
/// await interpreter.run();
/// ```
class T3Interpreter {
  // ==================== VM State ====================

  /// Machine registers.
  final T3Registers _registers = T3Registers();

  /// The VM stack.
  late final T3Stack _stack;

  /// Constant pool (strings and lists).
  T3ConstantPool? _constantPool;

  /// Code pool (bytecode).
  T3CodePool? _codePool;

  /// Entrypoint information.
  T3Entrypoint? _entrypoint;

  /// Metaclass dependencies.
  T3MetaclassDepList? _metaclasses;

  /// Function set dependencies.
  T3FunctionSetDepList? _functionSets;

  /// Indices for primitive type metaclasses.
  int? _stringMetaclassIdx;
  int? _listMetaclassIdx;

  /// Object table containing all loaded objects.
  late T3ObjectTable _objectTable;

  /// The global symbol table.
  final Map<String, T3Value> _symbols = {};

  /// Dynamic strings created at runtime (concatenation, etc.)
  /// Maps offset to string content
  final Map<int, String> _dynamicStrings = {};
  int _nextDynamicStringOffset = 0x80000000; // Start at high offset to avoid conflicts

  /// Dynamic lists created at runtime (from varargs, etc.)
  /// Maps offset to list of T3Values
  final Map<int, List<T3Value>> _dynamicLists = {};
  int _nextDynamicListOffset = 0x90000000; // Start at high offset to avoid conflicts

  /// The loaded image.
  T3Image? _image;

  /// SAY instruction handler (property ID).
  int _sayMethod = 0; // VM_INVALID_PROP in reference is 0

  /// SAY instruction handler (function or object).
  T3Value _sayFunc = T3Value.nil();

  /// Depth of nested tags being ignored (e.g., <ABOUTBOX>, <TITLE>).
  int _outputIgnoreDepth = 0;

  /// Whether the interpreter has been loaded.
  bool get isLoaded => _image != null;

  Map<int, String> get dynamicStrings => _dynamicStrings;

  /// Method Header Size from Entrypoint
  int get methodHeaderSize => _entrypoint?.methodHeaderSize ?? 0;

  /// Set the property ID used for specialized SAY handling.
  set sayMethod(int propId) => _sayMethod = propId;
  int get sayMethod => _sayMethod;

  /// Set the function or object used for specialized SAY handling.
  set sayFunc(T3Value val) => _sayFunc = val;
  T3Value get sayFunc => _sayFunc;

  /// Adds a list to the dynamic list storage and returns its offset.
  int addDynamicList(List<T3Value> elements) {
    final offset = _nextDynamicListOffset++;
    _dynamicLists[offset] = elements;
    return offset;
  }

  /// Total instructions executed (for debugging).
  int _instructionCount = 0;

  /// Maximum instructions before auto-quit (-1 = unlimited).
  int maxInstructions = -1;

  /// Creates a new T3 interpreter.
  T3Interpreter() {
    _stack = T3Stack();
    _objectTable = T3ObjectTable();
  }

  // ==================== Loading ====================

  /// Loads a T3 image file.
  void load(Uint8List gameData) {
    _image = T3Image(gameData);
    _image!.validate();

    _loadEntrypoint();
    _loadMetaclasses();
    _loadFunctionSets();
    _loadConstantPools();
    _loadCodePools();
    _loadSymbols();
    _loadObjects();
  }

  /// Loads the ENTP block.
  void _loadEntrypoint() {
    final block = _image!.findBlock(T3Block.typeEntrypoint);
    if (block == null) {
      throw T3Exception('Missing ENTP block');
    }
    final data = _image!.getBlockData(block);
    _entrypoint = T3Entrypoint.parse(data);
  }

  /// Loads the MCLD block.
  void _loadMetaclasses() {
    final block = _image!.findBlock(T3Block.typeMetaclassDep);
    if (block == null) {
      // Metaclasses are optional (but usually present)
      _metaclasses = T3MetaclassDepList([]);
      return;
    }
    final data = _image!.getBlockData(block);
    _metaclasses = T3MetaclassDepList.parse(data);

    // Cache indices for primitive types
    _stringMetaclassIdx = _metaclasses!.byName('string')?.index;
    _listMetaclassIdx = _metaclasses!.byName('list')?.index;
  }

  /// Loads the FNSD block.
  void _loadFunctionSets() {
    final block = _image!.findBlock(T3Block.typeFunctionSetDep);
    if (block == null) {
      // Function sets are optional (but usually present)
      _functionSets = T3FunctionSetDepList([]);
      return;
    }
    final data = _image!.getBlockData(block);
    _functionSets = T3FunctionSetDepList.parse(data);
  }

  /// Loads constant pool definition and pages.
  void _loadConstantPools() {
    // Find CPDF blocks (pool definitions)
    final cpdfBlocks = _image!.findBlocks(T3Block.typeConstPoolDef);

    for (final cpdf in cpdfBlocks) {
      final data = _image!.getBlockData(cpdf);
      final view = ByteData.view(data.buffer, data.offsetInBytes);

      final poolId = view.getUint16(0, Endian.little);
      final pageCount = view.getUint32(2, Endian.little);
      final pageSize = view.getUint32(6, Endian.little);

      if (poolId == 2) {
        // Constant pool (strings/lists)
        _constantPool = T3ConstantPool(poolId: poolId, pageCount: pageCount, pageSize: pageSize);
      } else if (poolId == 1) {
        // Code pool
        _codePool = T3CodePool(poolId: poolId, pageCount: pageCount, pageSize: pageSize);
      }
    }

    // Load pages
    final cppgBlocks = _image!.findBlocks(T3Block.typeConstPoolPage);
    for (final cppg in cppgBlocks) {
      final data = _image!.getBlockData(cppg);
      final view = ByteData.view(data.buffer, data.offsetInBytes);

      final poolId = view.getUint16(0, Endian.little);
      final pageIndex = view.getUint32(2, Endian.little);
      final xorMask = data[6];

      // Page data starts at offset 7 (after pool ID, page index, and XOR mask)
      var pageData = data.sublist(7);

      // Apply XOR mask if non-zero
      if (xorMask != 0) {
        pageData = Uint8List.fromList([for (var byte in pageData) byte ^ xorMask]);
      }

      if (poolId == 2 && _constantPool != null) {
        _constantPool!.loadPage(pageIndex, pageData);
      } else if (poolId == 1 && _codePool != null) {
        _codePool!.loadPage(pageIndex, pageData);
      }
    }
  }

  /// Alias for constant pool loading (code pool is loaded with constant pools).
  void _loadCodePools() {
    // Already done in _loadConstantPools()
  }

  /// Loads all static objects from OBJS blocks.
  void _loadObjects() {
    _objectTable.clear();

    final objsBlocks = _image!.findBlocks(T3Block.typeStaticObjects);
    for (final block in objsBlocks) {
      final data = _image!.getBlockData(block);
      final parsed = T3ObjsBlock.parse(data);
      _objectTable.loadFromObjsBlock(parsed, _metaclasses!);
    }
  }

  /// Loads all global symbols from SYMD blocks.
  void _loadSymbols() {
    _symbols.clear();
    final blocks = _image!.findBlocks(T3Block.typeSymbolicNames);
    for (final block in blocks) {
      final data = _image!.getBlockData(block);
      final parsed = T3SymdBlock.parse(data);
      _symbols.addAll(parsed.symbols);
    }
  }

  /// Gets the object table for debugging/testing.
  T3ObjectTable get objectTable => _objectTable;

  /// Gets the global symbol table.
  Map<String, T3Value> get symbols => Map.unmodifiable(_symbols);

  /// Gets the VM stack.
  T3Stack get stack => _stack;

  /// Gets the VM registers.
  T3Registers get registers => _registers;

  /// Gets the entrypoint information.
  T3Entrypoint? get entrypoint => _entrypoint;

  /// Gets the constant pool.
  T3ConstantPool? get constantPool => _constantPool;

  /// Gets the code pool.
  T3CodePool? get codePool => _codePool;

  // ==================== Execution ====================

  /// Runs the interpreter until completion.
  Future<void> run() async {
    if (!isLoaded) {
      throw StateError('No image loaded');
    }

    // Set up initial state by "calling" the entrypoint.
    // The entrypoint expects 1 argument: a List of command-line arguments.
    // TODO: Create a proper T3 List object instead of nil
    _stack.push(T3Value.nil());
    _callFunction(_entrypoint!.codeOffset, 1);

    // Main execution loop
    while (true) {
      final result = executeInstruction();

      if (result == T3ExecutionResult.quit) break;
      if (result == T3ExecutionResult.error) break;

      if (maxInstructions > 0 && _instructionCount >= maxInstructions) {
        break;
      }
    }
  }

  /// Executes a single instruction at the current IP.
  T3ExecutionResult executeInstruction() {
    _instructionCount++;

    final opcode = _codePool!.readByte(_registers.ip++);
    return _executeOpcode(opcode);
  }

  /// Executes the given opcode.
  T3ExecutionResult _executeOpcode(int opcode) {
    switch (opcode) {
      // ==================== Push Operations ====================

      // Note: 0x00 appears in bytecode but is not documented. Treating as NOP.
      case 0x00:
        return T3ExecutionResult.continue_;

      case T3Opcodes.NOP:
        return T3ExecutionResult.continue_;

      case T3Opcodes.PUSH_0:
        _stack.push(T3Value.fromInt(0));
        return T3ExecutionResult.continue_;

      case T3Opcodes.PUSH_1:
        _stack.push(T3Value.fromInt(1));
        return T3ExecutionResult.continue_;

      case T3Opcodes.PUSHINT8:
        final val = _codePool!.readInt8(_registers.ip++);
        _stack.push(T3Value.fromInt(val));
        return T3ExecutionResult.continue_;

      case T3Opcodes.PUSHINT:
        final val = _codePool!.readInt32(_registers.ip);
        _registers.ip += 4;
        _stack.push(T3Value.fromInt(val));
        return T3ExecutionResult.continue_;

      case T3Opcodes.PUSHSTR:
        final offset = _codePool!.readUint32(_registers.ip);
        _registers.ip += 4;
        _stack.push(T3Value.fromString(offset));
        return T3ExecutionResult.continue_;

      case T3Opcodes.PUSHLST:
        final offset = _codePool!.readUint32(_registers.ip);
        _registers.ip += 4;
        _stack.push(T3Value.fromList(offset));
        return T3ExecutionResult.continue_;

      case T3Opcodes.PUSHOBJ:
        final objId = _codePool!.readUint32(_registers.ip);
        _registers.ip += 4;
        _stack.push(T3Value.fromObject(objId));
        return T3ExecutionResult.continue_;

      case T3Opcodes.PUSHNIL:
        _stack.push(T3Value.nil());
        return T3ExecutionResult.continue_;

      case T3Opcodes.PUSHTRUE:
        _stack.push(T3Value.true_());
        return T3ExecutionResult.continue_;

      case T3Opcodes.PUSHPROPID:
        final propId = _codePool!.readUint16(_registers.ip);
        _registers.ip += 2;
        _stack.push(T3Value.fromProp(propId));
        return T3ExecutionResult.continue_;

      case T3Opcodes.PUSHFNPTR:
        final offset = _codePool!.readUint32(_registers.ip);
        _registers.ip += 4;
        _stack.push(T3Value.fromFuncPtr(offset));
        return T3ExecutionResult.continue_;

      case T3Opcodes.PUSHSTRI:
        {
          final len = _codePool!.readUint16(_registers.ip);
          _registers.ip += 2;
          final bytes = _codePool!.readBytes(_registers.ip, len);
          _registers.ip += len;
          // For now, push as a string with offset 0 and inline data?
          // Actually, TADS3 usually puts these in the pool.
          // Inline strings are literal bytes in the code stream.
          _stack.push(T3Value.fromInlineString(bytes));
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.PUSHENUM:
        final enumVal = _codePool!.readUint32(_registers.ip);
        _registers.ip += 4;
        _stack.push(T3Value.fromEnum(enumVal));
        return T3ExecutionResult.continue_;

      case T3Opcodes.PUSHBIFPTR:
        final setIdx = _codePool!.readUint16(_registers.ip);
        _registers.ip += 2;
        final funcIdx = _codePool!.readUint16(_registers.ip);
        _registers.ip += 2;
        _stack.push(T3Value.fromBifPtr(setIdx, funcIdx));
        return T3ExecutionResult.continue_;

      case T3Opcodes.PUSHPARLST:
        // Push varargs parameter list: creates a list from excess args
        // Operand: UBYTE - number of fixed parameters
        {
          final fixedCount = _codePool!.readByte(_registers.ip++);
          final totalArgs = _stack.getArgCount();
          final varargCount = totalArgs - fixedCount;

          // Build the list from the variable arguments
          final elements = <T3Value>[];
          for (var i = 0; i < varargCount; i++) {
            elements.add(_stack.getArg(fixedCount + i).copy());
          }

          // Store as a dynamic list
          final offset = _nextDynamicListOffset++;
          _dynamicLists[offset] = elements;

          // Push as a list value
          _stack.push(T3Value.fromList(offset));
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.MAKELSTPAR:
        // Push varargs parameters from a list
        // Pop list, pop arg count, push list elements, push updated count
        {
          final listVal = _stack.pop();
          final countVal = _stack.pop();
          if (!countVal.isInt) {
            throw T3Exception('MAKELSTPAR: expected integer argument count on stack');
          }

          var currentCount = countVal.value;
          if (listVal.isList) {
            List<T3Value> elements;
            if (_dynamicLists.containsKey(listVal.value)) {
              elements = _dynamicLists[listVal.value]!;
            } else {
              elements = _constantPool!.readList(listVal.value);
            }

            // Push elements in reverse order so first is at top
            for (var i = elements.length - 1; i >= 0; i--) {
              _stack.push(elements[i]);
            }
            currentCount += elements.length;
          } else {
            // Not a list, push it as a single argument
            _stack.push(listVal);
            currentCount++;
          }

          // Push updated count
          _stack.push(T3Value.fromInt(currentCount));
        }
        return T3ExecutionResult.continue_;

      // ==================== Stack Operations ====================

      case T3Opcodes.DUP:
        _stack.push(_stack.peek().copy());
        return T3ExecutionResult.continue_;

      case T3Opcodes.DISC:
        _stack.discard();
        return T3ExecutionResult.continue_;

      case T3Opcodes.DISC1:
        final count = _codePool!.readByte(_registers.ip++);
        _stack.discard(count);
        return T3ExecutionResult.continue_;

      case T3Opcodes.SWAP:
        final a = _stack.pop();
        final b = _stack.pop();
        _stack.push(a);
        _stack.push(b);
        return T3ExecutionResult.continue_;

      case T3Opcodes.GETR0:
        _stack.push(_registers.r0.copy());
        return T3ExecutionResult.continue_;

      // ==================== Local Variable Access ====================

      case T3Opcodes.GETLCL1:
        final idx = _codePool!.readByte(_registers.ip++);
        _stack.push(_stack.getLocal(idx));
        return T3ExecutionResult.continue_;

      case T3Opcodes.GETLCL2:
        final idx = _codePool!.readUint16(_registers.ip);
        _registers.ip += 2;
        _stack.push(_stack.getLocal(idx));
        return T3ExecutionResult.continue_;

      case T3Opcodes.SETLCL1:
        final idx = _codePool!.readByte(_registers.ip++);
        _stack.setLocal(idx, _stack.pop());
        return T3ExecutionResult.continue_;

      case T3Opcodes.SETLCL2:
        final idx = _codePool!.readUint16(_registers.ip);
        _registers.ip += 2;
        _stack.setLocal(idx, _stack.pop());
        return T3ExecutionResult.continue_;

      case T3Opcodes.GETARG1:
        final idx = _codePool!.readByte(_registers.ip++);
        _stack.push(_stack.getArg(idx));
        return T3ExecutionResult.continue_;

      case T3Opcodes.GETARG2:
        final idx = _codePool!.readUint16(_registers.ip);
        _registers.ip += 2;
        _stack.push(_stack.getArg(idx));
        return T3ExecutionResult.continue_;

      // Optimized argument access opcodes
      case T3Opcodes.GETARGN0: // push argument 0
        _stack.push(_stack.getArg(0));
        return T3ExecutionResult.continue_;

      case T3Opcodes.GETARGN1: // push argument 1
        _stack.push(_stack.getArg(1));
        return T3ExecutionResult.continue_;

      case T3Opcodes.GETARGN2: // push argument 2
        _stack.push(_stack.getArg(2));
        return T3ExecutionResult.continue_;

      case T3Opcodes.GETARGN3: // push argument 3
        _stack.push(_stack.getArg(3));
        return T3ExecutionResult.continue_;

      case T3Opcodes.PUSHSELF:
        _stack.push(_stack.getSelf());
        return T3ExecutionResult.continue_;

      // Return opcodes
      case T3Opcodes.RETVAL: // return with value from stack
        _registers.r0 = _stack.pop();
        return _doReturn();

      case T3Opcodes.RETNIL: // return nil
        _registers.r0 = T3Value.nil();
        return _doReturn();

      case T3Opcodes.RET: // return (keeps R0)
        return _doReturn();

      case T3Opcodes.RETTRUE: // return true
        _registers.r0 = T3Value.true_();
        return _doReturn();

      // Zero local variable opcodes
      case T3Opcodes.ZEROLCL1: // set local to 0 (1-byte index)
        final localNumZero1 = _codePool!.readByte(_registers.ip++);
        _stack.setLocal(localNumZero1, T3Value.fromInt(0));
        return T3ExecutionResult.continue_;

      case T3Opcodes.ZEROLCL2: // set local to 0 (2-byte index)
        final localNumZero2 = _codePool!.readUint16(_registers.ip);
        _registers.ip += 2;
        _stack.setLocal(localNumZero2, T3Value.fromInt(0));
        return T3ExecutionResult.continue_;

      // Get local variable opcodes (optimized versions)
      case T3Opcodes.GETLCLN2: // push local 2
        _stack.push(_stack.getLocal(2));
        return T3ExecutionResult.continue_;

      case T3Opcodes.GETLCLN3: // push local 3
        _stack.push(_stack.getLocal(3));
        return T3ExecutionResult.continue_;

      case T3Opcodes.GETLCLN0: // push local 0
        _stack.push(_stack.getLocal(0));
        return T3ExecutionResult.continue_;

      case T3Opcodes.GETLCLN1: // push local 1
        _stack.push(_stack.getLocal(1));
        return T3ExecutionResult.continue_;

      case T3Opcodes.GETLCLN4: // push local 4
        _stack.push(_stack.getLocal(4));
        return T3ExecutionResult.continue_;

      case T3Opcodes.GETLCLN5: // push local 5
        _stack.push(_stack.getLocal(5));
        return T3ExecutionResult.continue_;

      case T3Opcodes.VARARGC:
        // Modifier: next call uses argument count from stack
        {
          final nextOpcode = _codePool!.readByte(_registers.ip++);
          // All call opcodes that can follow VARARGC have a 1-byte argc operand first.
          // We consume and ignore it.
          _codePool!.readByte(_registers.ip++);

          final countVal = _stack.pop();
          if (!countVal.isInt) {
            throw T3Exception('VARARGC: expected integer argument count on stack');
          }
          final argc = countVal.value;

          switch (nextOpcode) {
            case T3Opcodes.CALL:
              _handleCallOp(argc);
              break;
            case T3Opcodes.PTRCALL:
              _handlePtrCallOp(argc);
              break;
            case T3Opcodes.CALLPROP:
              _handleCallPropOp(argc);
              break;
            case T3Opcodes.CALLPROPSELF:
              _handleCallPropSelfOp(argc);
              break;
            case T3Opcodes.OBJCALLPROP:
              _handleObjCallPropOp(argc);
              break;
            case T3Opcodes.CALLPROPLCL1:
              _handleCallPropLcl1Op(argc);
              break;
            case T3Opcodes.CALLPROPR0:
              _handleCallPropR0Op(argc);
              break;
            case T3Opcodes.BUILTIN_A:
              _handleBuiltinOp(0, argc);
              break;
            case T3Opcodes.BUILTIN_B:
              _handleBuiltinOp(1, argc);
              break;
            case T3Opcodes.BUILTIN_C:
              _handleBuiltinOp(2, argc);
              break;
            case T3Opcodes.BUILTIN_D:
              _handleBuiltinOp(3, argc);
              break;
            case T3Opcodes.BUILTIN1:
              _handleBuiltin1Op(argc);
              break;
            case T3Opcodes.BUILTIN2:
              _handleBuiltin2Op(argc);
              break;
            default:
              throw T3Exception('VARARGC: unsupported modified opcode 0x${nextOpcode.toRadixString(16)}');
          }
        }
        return T3ExecutionResult.continue_;

      // Local variable modification opcodes
      case T3Opcodes.ADDILCL1: // add immediate 1-byte int to local (UBYTE index)
        final localNumAdd1 = _codePool!.readByte(_registers.ip++);
        final addVal1 = _codePool!.readInt8(_registers.ip++);
        final localVal1 = _stack.getLocal(localNumAdd1);
        if (localVal1.isInt) {
          _stack.setLocal(localNumAdd1, T3Value.fromInt(localVal1.value + addVal1));
        } else {
          throw T3Exception('ADDILCL1: local $localNumAdd1 is not an integer');
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.ADDILCL4: // add immediate 4-byte int to local (UINT2 index)
        final localNumAdd4 = _codePool!.readUint16(_registers.ip);
        _registers.ip += 2;
        final addVal4 = _codePool!.readInt32(_registers.ip);
        _registers.ip += 4;
        final localVal4 = _stack.getLocal(localNumAdd4);
        if (localVal4.isInt) {
          _stack.setLocal(localNumAdd4, T3Value.fromInt(localVal4.value + addVal4));
        } else {
          throw T3Exception('ADDILCL4: local $localNumAdd4 is not an integer');
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.ADDTOLCL: // add stack value to local (UINT2 index)
        final localNumAddTo = _codePool!.readUint16(_registers.ip);
        _registers.ip += 2;
        final addToVal = _stack.pop();
        final localValAddTo = _stack.getLocal(localNumAddTo);

        if (localValAddTo.isInt && addToVal.isInt) {
          _stack.setLocal(localNumAddTo, T3Value.fromInt(localValAddTo.value + addToVal.value));
        } else if (localValAddTo.isList || addToVal.isList) {
          final resultElements = <T3Value>[];
          if (localValAddTo.isList) {
            resultElements.addAll(_getListValues(localValAddTo));
          } else {
            resultElements.add(localValAddTo.copy());
          }

          if (addToVal.isList) {
            resultElements.addAll(_getListValues(addToVal));
          } else {
            resultElements.add(addToVal.copy());
          }

          final offset = addDynamicList(resultElements);
          _stack.setLocal(localNumAddTo, T3Value.fromList(offset));
        } else if (localValAddTo.isStringLike || addToVal.isStringLike) {
          // String concatenation
          final s1 = getStringValue(localValAddTo);
          final s2 = getStringValue(addToVal);

          final resultStr = s1 + s2;
          final offset = _nextDynamicStringOffset++;
          _dynamicStrings[offset] = resultStr;

          _stack.setLocal(localNumAddTo, T3Value.fromString(offset));
        } else {
          throw T3Exception('ADDTOLCL: operands must be integers, strings, or lists');
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.SUBFROMLCL: // subtract stack value from local (UINT2 index)
        final localNumSubFrom = _codePool!.readUint16(_registers.ip);
        _registers.ip += 2;
        final subFromVal = _stack.pop();
        final localValSubFrom = _stack.getLocal(localNumSubFrom);
        if (localValSubFrom.isInt && subFromVal.isInt) {
          _stack.setLocal(localNumSubFrom, T3Value.fromInt(localValSubFrom.value - subFromVal.value));
        } else {
          throw T3Exception('SUBFROMLCL: operands must be integers');
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.NILLCL1: // set local to nil (1-byte index)
        final localNumNil1 = _codePool!.readByte(_registers.ip++);
        _stack.setLocal(localNumNil1, T3Value.nil());
        return T3ExecutionResult.continue_;

      case T3Opcodes.NILLCL2: // set local to nil (2-byte index)
        final localNumNil2 = _codePool!.readUint16(_registers.ip);
        _registers.ip += 2;
        _stack.setLocal(localNumNil2, T3Value.nil());
        return T3ExecutionResult.continue_;

      case T3Opcodes.ONELCL1: // set local to 1 (1-byte index)
        final localNumOne1 = _codePool!.readByte(_registers.ip++);
        _stack.setLocal(localNumOne1, T3Value.fromInt(1));
        return T3ExecutionResult.continue_;

      case T3Opcodes.ONELCL2: // set local to 1 (2-byte index)
        final localNumOne2 = _codePool!.readUint16(_registers.ip);
        _registers.ip += 2;
        _stack.setLocal(localNumOne2, T3Value.fromInt(1));
        return T3ExecutionResult.continue_;

      // Set argument opcodes
      case T3Opcodes.SETARG1: // set argument (1-byte index)
        final setArg1Idx = _codePool!.readByte(_registers.ip++);
        _stack.setArg(setArg1Idx, _stack.pop());
        return T3ExecutionResult.continue_;

      case T3Opcodes.SETARG2: // set argument (2-byte index)
        final setArg2Idx = _codePool!.readUint16(_registers.ip);
        _registers.ip += 2;
        _stack.setArg(setArg2Idx, _stack.pop());
        return T3ExecutionResult.continue_;

      // Register R0 opcodes
      case T3Opcodes.SETLCL1R0: // set local from R0 (1-byte index)
        final setLcl1R0Idx = _codePool!.readByte(_registers.ip++);
        _stack.setLocal(setLcl1R0Idx, _registers.r0);
        return T3ExecutionResult.continue_;

      // Debugger variable access (treat as regular variables for now)
      case T3Opcodes.GETDBARGC: // get debugger argument count
        // TODO: Track actual argument count
        _stack.push(T3Value.fromInt(0));
        return T3ExecutionResult.continue_;

      case T3Opcodes.GETDBLCL: // get debugger local
        final getDbLclIdx = _codePool!.readUint16(_registers.ip);
        _registers.ip += 2;
        _stack.push(_stack.getLocal(getDbLclIdx));
        return T3ExecutionResult.continue_;

      case T3Opcodes.GETDBARG: // get debugger argument
        final getDbArgIdx = _codePool!.readUint16(_registers.ip);
        _registers.ip += 2;
        _stack.push(_stack.getArg(getDbArgIdx));
        return T3ExecutionResult.continue_;

      // Increment/decrement local variables (UINT2 index)
      case T3Opcodes.INCLCL: // increment local variable
        final localNum = _codePool!.readUint16(_registers.ip);
        _registers.ip += 2;
        final val = _stack.getLocal(localNum);
        if (val.isInt) {
          _stack.setLocal(localNum, T3Value.fromInt(val.value + 1));
        } else {
          throw T3Exception('INCLCL: local $localNum is not an integer');
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.DECLCL: // decrement local variable
        final localNum = _codePool!.readUint16(_registers.ip);
        _registers.ip += 2;
        final val = _stack.getLocal(localNum);
        if (val.isInt) {
          _stack.setLocal(localNum, T3Value.fromInt(val.value - 1));
        } else {
          throw T3Exception('DECLCL: local $localNum is not an integer');
        }
        return T3ExecutionResult.continue_;

      // ==================== Jump/Branch Operations ====================

      case T3Opcodes.SWITCH:
        {
          final controlVal = _stack.pop();
          final numCases = _codePool!.readUint16(_registers.ip);
          _registers.ip += 2;

          bool matched = false;
          for (var i = 0; i < numCases; i++) {
            // Read 5-byte data holder for the case value
            final caseValue = T3Value.fromPortable(_codePool!.readBytes(_registers.ip, 5), 0);
            _registers.ip += 5;

            // Read 2-byte signed offset
            final offset = _codePool!.readInt16(_registers.ip);

            if (controlVal.equals(caseValue)) {
              // Match found: jump relative to current IP (the offset field address)
              _registers.ip += offset;
              matched = true;
              break;
            }
            // No match: skip the 2-byte offset and move to next entry
            _registers.ip += 2;
          }

          if (!matched) {
            // Default case: read 2-byte signed offset and jump relative to its address
            final defaultOffset = _codePool!.readInt16(_registers.ip);
            _registers.ip += defaultOffset;
          }
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.JMP: // Unconditional jump
        {
          final offsetJump = _codePool!.readInt16(_registers.ip);
          _registers.ip += offsetJump;
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.JT: // Jump if true
        {
          final offset = _codePool!.readInt16(_registers.ip);
          _registers.ip += 2;
          final val = _stack.pop();
          if (val.isLogicalTrue) {
            _registers.ip += offset - 2;
          }
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.JF: // Jump if false/nil
        {
          final offset = _codePool!.readInt16(_registers.ip);
          _registers.ip += 2;
          final val = _stack.pop();
          if (!val.isLogicalTrue) {
            _registers.ip += offset - 2;
          }
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.JE: // Jump if equal
        {
          final offset = _codePool!.readInt16(_registers.ip);
          _registers.ip += 2;
          final b = _stack.pop();
          final a = _stack.pop();
          if (a.equals(b)) {
            _registers.ip += offset - 2;
          }
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.JNE: // Jump if not equal
        {
          final offset = _codePool!.readInt16(_registers.ip);
          _registers.ip += 2;
          final b = _stack.pop();
          final a = _stack.pop();
          if (!a.equals(b)) {
            _registers.ip += offset - 2;
          }
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.JGT: // Jump if greater than
        {
          final offset = _codePool!.readInt16(_registers.ip);
          _registers.ip += 2;
          final b = _stack.pop();
          final a = _stack.pop();
          if (a.isInt && b.isInt && a.value > b.value) {
            _registers.ip += offset - 2;
          }
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.JGE: // Jump if greater or equal
        {
          final offset = _codePool!.readInt16(_registers.ip);
          _registers.ip += 2;
          final b = _stack.pop();
          final a = _stack.pop();
          if (a.isInt && b.isInt && a.value >= b.value) {
            _registers.ip += offset - 2;
          }
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.JLT: // Jump if less than
        {
          final offset = _codePool!.readInt16(_registers.ip);
          _registers.ip += 2;
          final b = _stack.pop();
          final a = _stack.pop();
          if (a.isInt && b.isInt && a.value < b.value) {
            _registers.ip += offset - 2;
          }
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.JLE: // Jump if less or equal
        {
          final offset = _codePool!.readInt16(_registers.ip);
          _registers.ip += 2;
          final b = _stack.pop();
          final a = _stack.pop();
          if (a.isInt && b.isInt && a.value <= b.value) {
            _registers.ip += offset - 2;
          }
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.JST: // Jump and save if true
        {
          final offset = _codePool!.readInt16(_registers.ip);
          _registers.ip += 2;
          if (_stack.peek().isLogicalTrue) {
            _registers.ip += offset - 2;
          } else {
            _stack.pop(); // discard if false
          }
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.JSF: // Jump and save if false
        {
          final offset = _codePool!.readInt16(_registers.ip);
          _registers.ip += 2;
          if (!_stack.peek().isLogicalTrue) {
            _registers.ip += offset - 2;
          } else {
            _stack.pop(); // discard if true
          }
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.JNIL: // Jump if nil
        {
          final offset = _codePool!.readInt16(_registers.ip);
          _registers.ip += 2;
          if (_stack.pop().isNil) {
            _registers.ip += offset - 2;
          }
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.JNOTNIL: // Jump if not nil
        {
          final offset = _codePool!.readInt16(_registers.ip);
          _registers.ip += 2;
          if (!_stack.pop().isNil) {
            _registers.ip += offset - 2;
          }
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.JR0T: // Jump if R0 is true
        {
          final offset = _codePool!.readInt16(_registers.ip);
          _registers.ip += 2;
          if (_registers.r0.isLogicalTrue) {
            _registers.ip += offset - 2;
          }
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.JR0F: // Jump if R0 is false
        {
          final offset = _codePool!.readInt16(_registers.ip);
          _registers.ip += 2;
          if (!_registers.r0.isLogicalTrue) {
            _registers.ip += offset - 2;
          }
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.LJSR: // Local jump to subroutine
        {
          final offset = _codePool!.readInt16(_registers.ip);
          _registers.ip += 2;
          final returnOfs = _registers.ip - _registers.ep;
          _stack.push(T3Value.fromInt(returnOfs));
          _registers.ip += offset - 2;
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.LRET: // Local return from subroutine
        {
          final localIdx = _codePool!.readUint16(_registers.ip);
          _registers.ip += 2;
          final returnVal = _stack.getLocal(localIdx);
          if (!returnVal.isInt) {
            throw T3Exception('LRET: return address local $localIdx is not an integer');
          }
          _registers.ip = _registers.ep + returnVal.value;
        }
        return T3ExecutionResult.continue_;

      // ==================== Boolean Operations ====================

      case T3Opcodes.NOT:
        final val = _stack.pop();
        _stack.push(val.isNil ? T3Value.true_() : T3Value.nil());
        return T3ExecutionResult.continue_;

      case T3Opcodes.BOOLIZE:
        final val = _stack.pop();
        _stack.push(val.isNil ? T3Value.nil() : T3Value.true_());
        return T3ExecutionResult.continue_;

      // ==================== Arithmetic Operations ====================

      case T3Opcodes.ADD:
        final b = _stack.pop();
        final a = _stack.pop();

        // Integer addition
        if (a.isInt && b.isInt) {
          _stack.push(T3Value.fromInt(a.value + b.value));
        }
        // List operations
        else if (a.isList || b.isList) {
          final resultElements = <T3Value>[];
          if (a.isList) {
            resultElements.addAll(_getListValues(a));
          } else {
            resultElements.add(a.copy());
          }

          if (b.isList) {
            resultElements.addAll(_getListValues(b));
          } else {
            resultElements.add(b.copy());
          }

          final offset = addDynamicList(resultElements);
          _stack.push(T3Value.fromList(offset));
        }
        // String concatenation
        else if (a.isStringLike || b.isStringLike) {
          // Helper to get string representation
          String getString(T3Value val) {
            if (val.isStringLike) {
              // Check if it's a dynamic string first
              if (_dynamicStrings.containsKey(val.value)) {
                return _dynamicStrings[val.value]!;
              }
              // Otherwise read from constant pool
              try {
                return _constantPool!.readString(val.value);
              } catch (e) {
                throw T3Exception(
                  'Failed to read string at offset 0x${val.value.toRadixString(16)}: $e. '
                  'Value type: ${val.type}, isStringLike: ${val.isStringLike}',
                );
              }
            } else if (val.isInt) {
              return val.value.toString();
            } else if (val.isNil) {
              return '';
            } else {
              return val.toString();
            }
          }

          final aStr = getString(a);
          final bStr = getString(b);
          final result = aStr + bStr;

          // Store the concatenated string
          final offset = _nextDynamicStringOffset++;
          _dynamicStrings[offset] = result;

          // Push a string value with the dynamic offset
          _stack.push(T3Value.fromString(offset));
        } else {
          throw T3Exception('ADD: unsupported operand types ${a.type} and ${b.type}');
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.SUB:
        final b = _stack.pop();
        final a = _stack.pop();
        if (a.isInt && b.isInt) {
          _stack.push(T3Value.fromInt(a.value - b.value));
        } else {
          throw T3Exception('SUB: unsupported operand types ${a.type} and ${b.type}');
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.MUL:
        final b = _stack.pop();
        final a = _stack.pop();
        if (a.isInt && b.isInt) {
          _stack.push(T3Value.fromInt(a.value * b.value));
        } else {
          throw T3Exception('MUL: unsupported operand types ${a.type} and ${b.type}');
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.DIV:
        final b = _stack.pop();
        final a = _stack.pop();
        if (a.isInt && b.isInt) {
          if (b.value == 0) {
            throw T3Exception('Division by zero');
          }
          _stack.push(T3Value.fromInt(a.value ~/ b.value));
        } else {
          throw T3Exception('DIV: unsupported operand types ${a.type} and ${b.type}');
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.MOD:
        final b = _stack.pop();
        final a = _stack.pop();
        if (a.isInt && b.isInt) {
          if (b.value == 0) {
            throw T3Exception('Modulo by zero');
          }
          _stack.push(T3Value.fromInt(a.value % b.value));
        } else {
          throw T3Exception('MOD: unsupported operand types ${a.type} and ${b.type}');
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.NEG:
        final val = _stack.pop();
        if (val.isInt) {
          _stack.push(T3Value.fromInt(-val.value));
        } else {
          throw T3Exception('NEG: unsupported operand type');
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.INC:
        final val = _stack.pop();
        if (val.isInt) {
          _stack.push(T3Value.fromInt(val.value + 1));
        } else {
          throw T3Exception('INC: unsupported operand type');
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.DEC:
        final val = _stack.pop();
        if (val.isInt) {
          _stack.push(T3Value.fromInt(val.value - 1));
        } else {
          throw T3Exception('DEC: unsupported operand type');
        }
        return T3ExecutionResult.continue_;

      // ==================== Bitwise Operations ====================

      case T3Opcodes.BAND:
        final b = _stack.pop();
        final a = _stack.pop();
        _stack.push(T3Value.fromInt(a.value & b.value));
        return T3ExecutionResult.continue_;

      case T3Opcodes.BOR:
        final b = _stack.pop();
        final a = _stack.pop();
        _stack.push(T3Value.fromInt(a.value | b.value));
        return T3ExecutionResult.continue_;

      case T3Opcodes.XOR:
        final b = _stack.pop();
        final a = _stack.pop();
        _stack.push(T3Value.fromInt(a.value ^ b.value));
        return T3ExecutionResult.continue_;

      case T3Opcodes.BNOT:
        final val = _stack.pop();
        _stack.push(T3Value.fromInt(~val.value));
        return T3ExecutionResult.continue_;

      case T3Opcodes.SHL:
        final b = _stack.pop();
        final a = _stack.pop();
        _stack.push(T3Value.fromInt(a.value << (b.value & 0x1F)));
        return T3ExecutionResult.continue_;

      case T3Opcodes.ASHR:
        final b = _stack.pop();
        final a = _stack.pop();
        _stack.push(T3Value.fromInt(a.value >> (b.value & 0x1F)));
        return T3ExecutionResult.continue_;

      case T3Opcodes.LSHR:
        final b = _stack.pop();
        final a = _stack.pop();
        _stack.push(T3Value.fromInt((a.value & 0xFFFFFFFF) >>> (b.value & 0x1F)));
        return T3ExecutionResult.continue_;

      // ==================== Comparison Operations ====================

      case T3Opcodes.EQ:
        final b = _stack.pop();
        final a = _stack.pop();
        _stack.push(a.equals(b) ? T3Value.true_() : T3Value.nil());
        return T3ExecutionResult.continue_;

      case T3Opcodes.NE:
        final b = _stack.pop();
        final a = _stack.pop();
        _stack.push(a.equals(b) ? T3Value.nil() : T3Value.true_());
        return T3ExecutionResult.continue_;

      case T3Opcodes.LT:
        final b = _stack.pop();
        final a = _stack.pop();
        if (a.isInt && b.isInt) {
          _stack.push(a.value < b.value ? T3Value.true_() : T3Value.nil());
        } else {
          throw T3Exception('LT: unsupported operand types');
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.LE:
        final b = _stack.pop();
        final a = _stack.pop();
        if (a.isInt && b.isInt) {
          _stack.push(a.value <= b.value ? T3Value.true_() : T3Value.nil());
        } else {
          throw T3Exception('LE: unsupported operand types');
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.GT:
        final b = _stack.pop();
        final a = _stack.pop();
        if (a.isInt && b.isInt) {
          _stack.push(a.value > b.value ? T3Value.true_() : T3Value.nil());
        } else {
          throw T3Exception('GT: unsupported operand types');
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.GE:
        final b = _stack.pop();
        final a = _stack.pop();
        if (a.isInt && b.isInt) {
          _stack.push(a.value >= b.value ? T3Value.true_() : T3Value.nil());
        } else {
          throw T3Exception('GE: unsupported operand types');
        }
        return T3ExecutionResult.continue_;

      // ==================== Property Access ====================

      case T3Opcodes.GETPROP:
        // Pop target, get property, store in R0
        {
          final propId = _codePool!.readUint16(_registers.ip);
          _registers.ip += 2;
          final target = _stack.pop();
          _getPropertyValue(target, propId);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.GETPROPSELF:
        // Get property of self, store in R0
        {
          final propId = _codePool!.readUint16(_registers.ip);
          _registers.ip += 2;
          final self = _stack.getSelf();
          _getPropertyValue(self, propId);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.GETPROPR0:
        // Get property of R0, store in R0
        {
          final propId = _codePool!.readUint16(_registers.ip);
          _registers.ip += 2;
          _getPropertyValue(_registers.r0, propId);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.OBJGETPROP:
        // Get property of immediate object ID
        {
          final objId = _codePool!.readUint32(_registers.ip);
          _registers.ip += 4;
          final propId = _codePool!.readUint16(_registers.ip);
          _registers.ip += 2;
          final target = T3Value.fromObject(objId);
          _getPropertyValue(target, propId);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.GETPROPLCL1:
        // Get property of local variable
        {
          final lclIdx = _codePool!.readByte(_registers.ip++);
          final propId = _codePool!.readUint16(_registers.ip);
          _registers.ip += 2;
          final target = _stack.getLocal(lclIdx);
          _getPropertyValue(target, propId);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.GETPROPDATA:
        // Get property data only (disallow side effects)
        {
          final propId = _codePool!.readUint16(_registers.ip);
          _registers.ip += 2;
          final target = _stack.pop();
          _getPropertyValue(target, propId);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.PTRGETPROPDATA:
        // Get property data through pointer
        {
          final propPtr = _stack.pop();
          final target = _stack.pop();
          _getPropertyValue(target, propPtr.value);
        }
        return T3ExecutionResult.continue_;

      // ==================== Method/Function Calls ====================

      case T3Opcodes.CALLPROP:
        // Call method: pop target, call property with argc args
        {
          final argc = _codePool!.readByte(_registers.ip++);
          final propId = _codePool!.readUint16(_registers.ip);
          _registers.ip += 2;
          final target = _stack.pop();
          _evalProperty(target, propId, argc: argc);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.CALLPROPSELF:
        // Call method on self
        {
          final argc = _codePool!.readByte(_registers.ip++);
          _handleCallPropSelfOp(argc);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.OBJCALLPROP:
        // Call method on immediate object ID
        {
          final argc = _codePool!.readByte(_registers.ip++);
          _handleObjCallPropOp(argc);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.CALLPROPLCL1:
        // Call method using local variable as target
        {
          final argc = _codePool!.readByte(_registers.ip++);
          _handleCallPropLcl1Op(argc);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.CALLPROPR0:
        // Call method on R0
        {
          final argc = _codePool!.readByte(_registers.ip++);
          _handleCallPropR0Op(argc);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.CALL:
        // Call function at immediate code offset
        {
          final argc = _codePool!.readByte(_registers.ip++);
          _handleCallOp(argc);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.PTRCALL:
        // Call function through pointer on stack
        {
          final argc = _codePool!.readByte(_registers.ip++);
          _handlePtrCallOp(argc);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.SAY:
        {
          final offset = _codePool!.readUint32(_registers.ip);
          _registers.ip += 4;
          _invokeSay(T3Value.fromString(offset));
        }
        return T3ExecutionResult.continue_;

      // ==================== Built-in Function Calls ====================

      case T3Opcodes.BUILTIN_A:
        // Call built-in function from set 0
        {
          final argc = _codePool!.readByte(_registers.ip++);
          _handleBuiltinOp(0, argc);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.BUILTIN_B:
        // Call built-in from set 1
        {
          final argc = _codePool!.readByte(_registers.ip++);
          _handleBuiltinOp(1, argc);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.BUILTIN_C:
        // Call built-in from set 2
        {
          final argc = _codePool!.readByte(_registers.ip++);
          _handleBuiltinOp(2, argc);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.BUILTIN_D:
        // Call built-in from set 3
        {
          final argc = _codePool!.readByte(_registers.ip++);
          _handleBuiltinOp(3, argc);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.BUILTIN1:
        // Call built-in function from any set (8-bit index)
        {
          final argc = _codePool!.readByte(_registers.ip++);
          _handleBuiltin1Op(argc);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.BUILTIN2:
        // Call built-in function from any set (16-bit index)
        {
          final argc = _codePool!.readByte(_registers.ip++);
          _handleBuiltin2Op(argc);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.SAYVAL:
        {
          final val = _stack.pop();
          _invokeSay(val);
        }
        return T3ExecutionResult.continue_;

      // ==================== Property Modification ====================

      case T3Opcodes.SETPROP:
        // Set property: pop target, pop val, set prop
        {
          final propId = _codePool!.readUint16(_registers.ip);
          _registers.ip += 2;
          final target = _stack.pop();
          final val = _stack.pop();
          _setPropertyValue(target, propId, val);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.PTRSETPROP:
        // Set property through pointer: pop val, pop target, pop propPtr
        {
          final propPtr = _stack.pop();
          final target = _stack.pop();
          final val = _stack.pop();
          _setPropertyValue(target, propPtr.value, val);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.SETPROPSELF:
        // Set property on self: pop val, set prop
        {
          final propId = _codePool!.readUint16(_registers.ip);
          _registers.ip += 2;
          final val = _stack.pop();
          _setPropertyValue(_stack.getSelf(), propId, val);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.OBJSETPROP:
        // Set property on immediate object ID: pop val, set prop
        {
          final objId = _codePool!.readUint32(_registers.ip);
          _registers.ip += 4;
          final propId = _codePool!.readUint16(_registers.ip);
          _registers.ip += 2;
          final val = _stack.pop();
          _setPropertyValue(T3Value.fromObject(objId), propId, val);
        }
        return T3ExecutionResult.continue_;

      // ==================== Indexing Operations ====================

      case T3Opcodes.IDXLCL1INT8:
        // Index local variable by 8-bit constant: (UBYTE localNum, UBYTE idx)
        {
          final localNum = _codePool!.readByte(_registers.ip++);
          final idx = _codePool!.readByte(_registers.ip++);
          final listVal = _stack.getLocal(localNum);
          final result = _applyIndex(listVal, idx);
          _stack.push(result);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.IDXINT8:
        // Index top of stack by 8-bit constant: (UBYTE idx)
        {
          final idx = _codePool!.readByte(_registers.ip++);
          final listVal = _stack.pop();
          final result = _applyIndex(listVal, idx);
          _stack.push(result);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.INDEX:
        // Index top of stack by value on stack
        {
          final idxVal = _stack.pop();
          final listVal = _stack.pop();
          if (!idxVal.isInt) {
            throw T3Exception('INDEX: index must be an integer');
          }
          final result = _applyIndex(listVal, idxVal.value);
          _stack.push(result);
        }
        return T3ExecutionResult.continue_;

      // ==================== Default ====================

      default:
        throw T3Exception(
          'Unknown opcode: 0x${opcode.toRadixString(16)} '
          '(${T3Opcodes.getName(opcode)}) at IP=0x${(_registers.ip - 1).toRadixString(16)}',
        );
    }
  }

  /// Calls a function at the given code pool offset.
  /// This parses the function header, sets up the stack frame, and positions
  /// the IP at the first instruction.
  void _callFunction(int codeOffset, int argc, {T3Value? self, T3Value? targetObj, T3Value? definingObj, int? propId}) {
    // Get the method header size from the entrypoint
    final methodHeaderSize = _entrypoint!.methodHeaderSize;

    // Read the header from the code pool (minimum 10 bytes, but may be larger)
    final headerBytes = _codePool!.readBytes(codeOffset, methodHeaderSize);
    final header = T3FunctionHeader.parse(headerBytes);

    // Verify argument count
    final maxArgs = header.minArgs + header.optionalArgc;
    if (!header.isVarargs && (argc < header.minArgs || argc > maxArgs)) {
      throw T3Exception(
        'Argument count mismatch calling function at 0x${codeOffset.toRadixString(16)}: '
        'expected ${header.minArgs}-$maxArgs, got $argc',
      );
    }
    if (header.isVarargs && argc < header.minArgs) {
      throw T3Exception(
        'Argument count mismatch (varargs) at 0x${codeOffset.toRadixString(16)}: '
        'expected at least ${header.minArgs}, got $argc',
      );
    }

    // Push nil for any optional arguments that weren't provided
    // The bytecode may try to access these arguments, so they must exist on the stack
    final actualArgc = argc < maxArgs ? maxArgs : argc;
    for (var i = argc; i < actualArgc; i++) {
      _stack.push(T3Value.nil());
    }

    // Set up the stack frame
    _stack.pushFrame(
      argCount: actualArgc,
      localCount: header.localCount,
      returnAddr: _registers.ip,
      entryPtr: _registers.ep, // Save CALLER's EP
      self: self ?? T3Value.nil(),
      targetObj: targetObj ?? T3Value.nil(),
      definingObj: definingObj ?? T3Value.nil(),
      targetProp: propId ?? 0,
      invokee: targetObj ?? T3Value.nil(),
    );

    // Position IP at the first instruction after the header
    _registers.ip = codeOffset + methodHeaderSize;
    _registers.ep = codeOffset; // Set to CALLEE's EP
  }

  /// Handles function return.
  /// Gets the string representation of a value.
  String getStringValue(T3Value val) {
    if (val.isStringLike) {
      if (val.data is Uint8List) {
        return T3Utf8.decode(val.data as Uint8List);
      }
      final offset = val.value;
      if (offset >= 0x80000000) {
        return _dynamicStrings[offset] ?? '';
      } else {
        return _constantPool!.readString(offset);
      }
    } else if (val.isInt) {
      return val.value.toString();
    } else if (val.isNil) {
      return '';
    } else if (val.isList) {
      final elements = _getListValues(val);
      final buffer = StringBuffer();
      buffer.write('[');
      for (var i = 0; i < elements.length; i++) {
        if (i > 0) buffer.write(' ');
        buffer.write(getStringValue(elements[i]));
      }
      buffer.write(']');
      return buffer.toString();
    }
    return '';
  }

  T3ExecutionResult _doReturn() {
    if (_stack.fp == 0) {
      // Return from entry function - program ends
      return T3ExecutionResult.quit;
    }

    final (returnAddr, oldFp, entryPtr) = _stack.popFrame();
    _registers.ip = returnAddr;

    // Restore the entry pointer from the popped frame
    _registers.ep = entryPtr;

    if (oldFp == 0) {
      // Popped the top-level frame, we are done
      return T3ExecutionResult.quit;
    }

    return T3ExecutionResult.continue_;
  }

  /// Evaluates a property on a target object.
  ///
  /// This handles property lookup based on the target's type:
  /// - Object: Look up property with inheritance, invoke if code
  /// - String constant: TODO - Use string metaclass methods
  /// - List constant: TODO - Use list metaclass methods
  /// - Nil: Throws nil dereference error
  /// - Other: Throws type error
  ///
  /// If [argc] is non-null, this is a method call with that many arguments on
  /// the stack. If it's null, this is a property access (no args allowed for
  /// code properties - they're just stored in R0).
  void _evalProperty(T3Value target, int propId, {int? argc}) {
    switch (target.type) {
      case T3DataType.obj:
        // Look up property with inheritance
        final result = _objectTable.lookupProperty(target.value, propId);
        if (result == null) {
          // Property not found - check for propNotDefined
          final propUndefId = _getSymbolPropertyId('propNotDefined');
          if (propUndefId != null && propUndefId != propId) {
            final undefResult = _objectTable.lookupProperty(target.value, propUndefId);
            if (undefResult != null) {
              // Found propNotDefined - invoke it
              // Arguments: (originalPropId, ...originalArgs)
              final actualArgCount = argc ?? 0;
              _stack.insertAt(actualArgCount, T3Value.fromProp(propId));

              // Evaluate propNotDefined as a method
              _evalProperty(target, propUndefId, argc: actualArgCount + 1);
              return;
            }
          }

          // propNotDefined not found or failed - discard arguments and return nil
          if (argc != null && argc > 0) {
            _stack.discard(argc);
          }
          _registers.r0 = T3Value.nil();
          return;
        }

        // Evaluate the property value based on its type
        final propVal = result.value;

        switch (propVal.type) {
          case T3DataType.codeofs:
          case T3DataType.funcptr:
            // It's a method - invoke it
            if (argc == null) {
              // GETPROP with code property - store in R0 without invoking
              _registers.r0 = propVal;
              return;
            }

            // Read the method header to get local count
            final methodAddr = propVal.value;

            // Set up method invocation
            _callFunction(
              methodAddr,
              argc,
              self: target,
              targetObj: target,
              definingObj: T3Value.fromObject(result.definingObjectId),
              propId: propId,
            );
            return;

          case T3DataType.dstring:
            // Self-printing string - TODO: display via output system
            if (argc != null && argc > 0) {
              throw T3Exception('Arguments not allowed for dstring property');
            }
            _registers.r0 = propVal;
            break;

          default:
            // Data property - arguments not allowed if calling
            if (argc != null && argc > 0) {
              throw T3Exception('Arguments not allowed for data property of type ${propVal.type}');
            }
            _registers.r0 = propVal;
            break;
        }
        break;

      case T3DataType.nil:
        throw T3Exception('Nil dereference: attempted to get property $propId of nil');

      case T3DataType.sstring:
        _handleIntrinsic(_stringMetaclassIdx, target, propId, argc);
        break;

      case T3DataType.list:
        _handleIntrinsic(_listMetaclassIdx, target, propId, argc);
        break;

      default:
        throw T3Exception('Cannot get property of ${target.type}');
    }
  }

  /// Backward compatible wrapper for property get (no args).
  void _getPropertyValue(T3Value target, int propId) {
    _evalProperty(target, propId, argc: null);
  }

  /// Handles property access on intrinsic types (string, list).
  void _handleIntrinsic(int? metaclassIdx, T3Value target, int propId, int? argc) {
    if (metaclassIdx == null || _metaclasses == null) {
      _registers.r0 = T3Value.nil();
      return;
    }

    final dep = _metaclasses?.byIndex(metaclassIdx);
    if (dep != null) {
      final funcIdx = dep.propertyIds.indexOf(propId);
      if (funcIdx >= 0) {
        // Dispatch to internal implementation
        if (dep.name == 'string') {
          _handleStringIntrinsic(funcIdx, target, argc);
          return;
        } else if (dep.name == 'list') {
          _handleListIntrinsic(funcIdx, target, argc);
          return;
        }
      }
    }

    // fallback to placeholder object lookup
    final placeholderName = target.type == T3DataType.sstring ? '*ConstStrObj' : '*ConstLstObj';
    final placeholder = _symbols[placeholderName];
    if (placeholder != null && placeholder.type == T3DataType.obj) {
      // Look up on the placeholder class
      // In TADS3, when a property isn't an intrinsic method, it's looked up on the
      // corresponding class.
      _evalProperty(placeholder, propId, argc: argc);
      return;
    }

    // Not found
    if (argc != null && argc > 0) _stack.discard(argc);
    _registers.r0 = T3Value.nil();
  }

  void _handleStringIntrinsic(int funcIdx, T3Value target, int? argc) {
    // length() is index 0 for strings
    if (funcIdx == 0) {
      if (argc != null && argc > 0) _stack.discard(argc);

      int length;
      if (_dynamicStrings.containsKey(target.value)) {
        length = _dynamicStrings[target.value]!.length;
      } else {
        final text = _constantPool!.readString(target.value);
        length = text.length;
      }
      _registers.r0 = T3Value.fromInt(length);
      return;
    }

    // TODO: Implement other string intrinsics
    if (argc != null && argc > 0) _stack.discard(argc);
    _registers.r0 = T3Value.nil();
  }

  void _handleListIntrinsic(int funcIdx, T3Value target, int? argc) {
    // length() is index 2 for lists (based on dump_mcld)
    if (funcIdx == 2) {
      if (argc != null && argc > 0) _stack.discard(argc);

      int length;
      if (_dynamicLists.containsKey(target.value)) {
        length = _dynamicLists[target.value]!.length;
      } else {
        final list = _constantPool!.readList(target.value);
        length = list.length;
      }
      _registers.r0 = T3Value.fromInt(length);
      return;
    }

    if (argc != null && argc > 0) _stack.discard(argc);
    _registers.r0 = T3Value.nil();
  }

  /// Gets a property ID from the symbol table by name.
  int? _getSymbolPropertyId(String name) {
    final val = _symbols[name];
    if (val != null && val.type == T3DataType.prop) {
      return val.value;
    }
    return null;
  }

  /// Applies an index to a list or string value.
  /// Returns the indexed element. Returns nil if container is nil.
  T3Value _applyIndex(T3Value container, int index) {
    // Nil container returns nil (TADS behavior)
    if (container.isNil) {
      return T3Value.nil();
    }

    if (container.isList) {
      // Check if it's a dynamic list
      if (_dynamicLists.containsKey(container.value)) {
        final list = _dynamicLists[container.value]!;
        // TADS uses 1-based indexing
        if (index < 1 || index > list.length) {
          throw T3Exception('List index out of range: $index (length: ${list.length})');
        }
        return list[index - 1].copy();
      }
      // Otherwise read from constant pool
      final list = _constantPool!.readList(container.value);
      // TADS uses 1-based indexing
      if (index < 1 || index > list.length) {
        throw T3Exception('List index out of range: $index (length: ${list.length})');
      }
      return list[index - 1];
    } else if (container.isStringLike) {
      // String indexing - return a single character string
      String str;
      if (_dynamicStrings.containsKey(container.value)) {
        str = _dynamicStrings[container.value]!;
      } else {
        str = _constantPool!.readString(container.value);
      }
      // TADS uses 1-based indexing
      if (index < 1 || index > str.length) {
        throw T3Exception('String index out of range: $index (length: ${str.length})');
      }
      final char = str[index - 1];
      // Store as dynamic string and return
      final offset = _nextDynamicStringOffset++;
      _dynamicStrings[offset] = char;
      return T3Value.fromString(offset);
    } else {
      throw T3Exception('Cannot index value of type ${container.type}');
    }
  }

  /// Sets a property on a target object.
  void _setPropertyValue(T3Value target, int propId, T3Value value) {
    if (target.type != T3DataType.obj) {
      throw T3Exception('Cannot set property $propId on type ${target.type}');
    }

    final obj = _objectTable.lookup(target.value);
    if (obj == null) {
      throw T3Exception('Attempted to set property $propId on non-existent object ${target.value}');
    }

    obj.setProperty(propId, value);
  }

  /// Calls a built-in function from a function set.
  ///
  /// [setIdx] is the function set index from the FNSD dependency list.
  /// [funcIdx] is the function index within that set.
  /// [argc] is the number of arguments on the stack.
  ///
  /// Results are placed in R0. Arguments are consumed from the stack.
  void _callBuiltin(int setIdx, int funcIdx, int argc) {
    // Get the function set name
    final funcSet = _functionSets?.byIndex(setIdx);
    final setName = funcSet?.name ?? 'unknown-$setIdx';

    final func = T3BuiltinRegistry.getFunction(setName, funcIdx);
    if (func != null) {
      func(this, argc);
      return;
    }

    // For now, just discard args and return nil
    if (argc > 0) {
      _stack.discard(argc);
    }

    // Stub: Set R0 to nil
    _registers.r0 = T3Value.nil();

    // ignore: avoid_print
    print('Warning: Built-in $setName[$funcIdx] not implemented');
  }

  /// Invokes the SAY handler for the given value.
  void _invokeSay(T3Value val) {
    if (val.isString) {
      final text = getStringValue(val);
      _processOutputText(text);
      return;
    }

    // If there's a valid 'self' object and a default display method, use it.
    final self = _stack.getSelf();
    if (_sayMethod != 0 && !self.isNil) {
      // TODO: Implement proper property lookup and call if present
    }

    // If the "say" function is set, call it.
    if (!_sayFunc.isNil) {
      _stack.push(val);
      _callFunctionPointer(_sayFunc, 1);
      return;
    }

    // Default: print to console
    _printValue(val);
  }

  /// Processes output text, handling basic HTML tag filtering.
  void _processOutputText(String text) {
    // Basic tag parsing to handle <aboutbox> and <title>
    var currentIndex = 0;
    while (currentIndex < text.length) {
      final tagStart = text.indexOf('<', currentIndex);
      if (tagStart == -1) {
        // No more tags, print the rest if not ignored
        if (_outputIgnoreDepth == 0) {
          printRaw(text.substring(currentIndex));
        }
        break;
      }

      // Print text before tag if not ignored
      if (tagStart > currentIndex && _outputIgnoreDepth == 0) {
        printRaw(text.substring(currentIndex, tagStart));
      }

      final tagEnd = text.indexOf('>', tagStart);
      if (tagEnd == -1) {
        // Malformed tag, just treat as text
        if (_outputIgnoreDepth == 0) {
          printRaw(text.substring(tagStart));
        }
        break;
      }

      final tagContent = text.substring(tagStart + 1, tagEnd).trim().toLowerCase();
      final isEndTag = tagContent.startsWith('/');
      final tagName = isEndTag ? tagContent.substring(1).trim() : tagContent.split(RegExp(r'\s+'))[0];

      if (tagName == 'aboutbox' || tagName == 'title') {
        if (isEndTag) {
          _outputIgnoreDepth = (_outputIgnoreDepth > 0) ? _outputIgnoreDepth - 1 : 0;
        } else {
          _outputIgnoreDepth++;
        }
      }

      currentIndex = tagEnd + 1;
    }
  }

  /// Prints a T3 value to the console.
  void _printValue(T3Value val) {
    if (_outputIgnoreDepth > 0) return;
    final text = getStringValue(val);
    printRaw(text);
  }

  void printRaw(String text) {
    if (text.isEmpty) return;
    // ignore: avoid_print
    stdout.write(text);
  }

  /// Gets the list of values for a list T3Value (handles dynamic and pool lists).
  List<T3Value> _getListValues(T3Value listVal) {
    if (!listVal.isList) return [];

    if (_dynamicLists.containsKey(listVal.value)) {
      return _dynamicLists[listVal.value]!;
    } else {
      return _constantPool!.readList(listVal.value);
    }
  }

  /// Calls a function pointer or object.
  void _callFunctionPointer(T3Value func, int argc) {
    if (func.type == T3DataType.funcptr || func.type == T3DataType.codeofs) {
      _callFunction(func.value, argc);
    } else if (func.type == T3DataType.obj) {
      // Handle anon-func-ptr and other callable objects
      final codeOfs = _getCallableOffset(func.value);
      if (codeOfs != null) {
        _callFunction(codeOfs, argc);
      } else {
        throw T3Exception('Object ${func.value} is not callable');
      }
    } else {
      throw T3Exception('Value of type ${func.type} is not callable');
    }
  }

  /// Gets the code offset for a callable object (anon-func-ptr, etc.)
  int? _getCallableOffset(int objectId) {
    final obj = _objectTable.lookup(objectId);
    // ignore: avoid_print
    print('DEBUG: _getCallableOffset(${objectId}) -> metaclass=${obj?.metaclass}, runtimeType=${obj.runtimeType}');
    if (obj == null) return null;

    // For anon-func-ptr and vector: element 0 contains the entry point (per reference VM)
    if (obj is T3VectorObject) {
      if (obj.elements.isNotEmpty) {
        final entryVal = obj.elements[0];
        // ignore: avoid_print
        print('DEBUG: anon-func-ptr/vector elements[0]: ${entryVal.type} = ${entryVal.value}');
        if (entryVal.isCodeOffset || entryVal.isFuncPtr) {
          return entryVal.value;
        }
      }
    }

    // For tads-object: try looking up 'ObjectCallProp' property (property 5)
    if (obj is T3TadsObject) {
      final callProp = obj.getProperty(5);
      if (callProp != null && (callProp.isCodeOffset || callProp.isFuncPtr)) {
        return callProp.value;
      }
    }

    return null;
  }

  // ==================== Debug/Utility ====================

  /// Gets the number of instructions executed.
  int get instructionCount => _instructionCount;

  /// Gets the current IP.
  int get ip => _registers.ip;

  /// Gets the current stack depth.
  int get stackDepth => _stack.depth;

  /// Gets info for debugging.
  String debugInfo() {
    return 'T3Interpreter: ip=0x${_registers.ip.toRadixString(16)}, '
        'stack=${_stack.depth}, instructions=$_instructionCount';
  }
  // ==================== Call Opcode Helpers ====================

  void _handleCallOp(int argc) {
    final targetAddr = _codePool!.readUint32(_registers.ip);
    _registers.ip += 4;
    _callFunction(targetAddr, argc);
  }

  void _handlePtrCallOp(int argc) {
    final funcPtr = _stack.pop();
    // ignore: avoid_print
    print('DEBUG: _handlePtrCallOp argc=$argc funcPtr=${funcPtr.type}:${funcPtr.value}');
    if (funcPtr.isCodeOffset || funcPtr.isFuncPtr) {
      _callFunction(funcPtr.value, argc);
    } else if (funcPtr.type == T3DataType.obj) {
      // Handle anon-func-ptr objects
      final codeOfs = _getCallableOffset(funcPtr.value);
      // ignore: avoid_print
      print('DEBUG: PTRCALL object ${funcPtr.value} -> codeOfs=$codeOfs');
      if (codeOfs != null) {
        _callFunction(codeOfs, argc);
      } else {
        throw T3Exception('PTRCALL: object ${funcPtr.value} is not callable');
      }
    } else {
      throw T3Exception('PTRCALL requires function pointer, got ${funcPtr.type}');
    }
  }

  void _handleCallPropOp(int argc) {
    final propId = _codePool!.readUint16(_registers.ip);
    _registers.ip += 2;
    final target = _stack.pop();
    _evalProperty(target, propId, argc: argc);
  }

  void _handleCallPropSelfOp(int argc) {
    final propId = _codePool!.readUint16(_registers.ip);
    _registers.ip += 2;
    final self = _stack.getSelf();
    _evalProperty(self, propId, argc: argc);
  }

  void _handleObjCallPropOp(int argc) {
    final objId = _codePool!.readUint32(_registers.ip);
    _registers.ip += 4;
    final propId = _codePool!.readUint16(_registers.ip);
    _registers.ip += 2;
    final target = T3Value.fromObject(objId);
    _evalProperty(target, propId, argc: argc);
  }

  void _handleCallPropLcl1Op(int argc) {
    final localNum = _codePool!.readByte(_registers.ip++);
    final propId = _codePool!.readUint16(_registers.ip);
    _registers.ip += 2;
    final target = _stack.getLocal(localNum);
    _evalProperty(target, propId, argc: argc);
  }

  void _handleCallPropR0Op(int argc) {
    final propId = _codePool!.readUint16(_registers.ip);
    _registers.ip += 2;
    _evalProperty(_registers.r0, propId, argc: argc);
  }

  void _handleBuiltinOp(int setIdx, int argc) {
    final funcIdx = _codePool!.readByte(_registers.ip++);
    _callBuiltin(setIdx, funcIdx, argc);
  }

  void _handleBuiltin1Op(int argc) {
    final funcIdx = _codePool!.readByte(_registers.ip++);
    final setIdx = _codePool!.readByte(_registers.ip++);
    _callBuiltin(setIdx, funcIdx, argc);
  }

  void _handleBuiltin2Op(int argc) {
    final funcIdx = _codePool!.readUint16(_registers.ip);
    _registers.ip += 2;
    final setIdx = _codePool!.readByte(_registers.ip++);
    _callBuiltin(setIdx, funcIdx, argc);
  }
}
