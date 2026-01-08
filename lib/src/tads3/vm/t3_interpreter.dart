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
import 'package:zart/src/tads3/loaders/sini_parser.dart';
import 'package:zart/src/tads3/vm/t3_code_pool.dart';
import 'package:zart/src/tads3/vm/t3_constant_pool.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_object_table.dart';
import 'package:zart/src/tads3/vm/t3_opcodes.dart';
import 'package:zart/src/tads3/vm/t3_undo.dart';
import 'package:zart/src/tads3/vm/t3_registers.dart';
import 'package:zart/src/tads3/vm/t3_stack.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';
import 'package:zart/src/tads3/vm/t3_builtin_registry.dart';
import 'package:zart/src/tads3/vm/t3_value_helpers.dart';
import 'package:zart/src/tads3/vm/t3_call_helpers.dart';
import 'package:zart/src/tads3/vm/t3_execution_helpers.dart';
import 'package:zart/src/tads3/vm/t3_execution_result.dart';

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
class T3Interpreter with T3ValueHelpers, T3CallHelpers, T3ExecutionHelpers implements TUndoContext {
  // ==================== VM State ====================

  int? _pendingNamedArgTableAddr;
  bool _varArgcPending = false;

  // Mixin accessors for T3ValueHelpers
  @override
  T3Stack get helperStack => _stack;
  @override
  T3Registers get helperRegisters => _registers;
  @override
  T3ObjectTable get helperObjectTable => _objectTable;
  @override
  T3ConstantPool? get helperConstantPool => _constantPool;
  @override
  Map<int, List<T3Value>> get helperDynamicLists => _dynamicLists;
  @override
  Map<int, String> get helperDynamicStrings => _dynamicStrings;
  @override
  int get helperNextDynamicStringOffset => _nextDynamicStringOffset;
  @override
  set helperNextDynamicStringOffset(int value) => _nextDynamicStringOffset = value;

  @override
  T3UndoManager get helperUndoManager => undoManager;
  @override
  T3UndoManager get execUndoManager => undoManager;

  // Mixin accessors for T3CallHelpers
  @override
  T3Stack get callStack => _stack;
  @override
  T3Registers get callRegisters => _registers;
  @override
  T3CodePool? get callCodePool => _codePool;
  @override
  T3ObjectTable get callObjectTable => _objectTable;
  @override
  int? get pendingNamedArgTableAddr => _pendingNamedArgTableAddr;
  @override
  void clearPendingNamedArgTable() => _pendingNamedArgTableAddr = null;

  @override
  void callFunction(
    int codeOffset,
    int argc, {
    T3Value? self,
    T3Value? targetObj,
    T3Value? definingObj,
    int? propId,
    T3Value? invokee,
    int? namedArgTableAddr,
    T3Value? context,
  }) => execCallFunction(
    codeOffset,
    argc,
    self: self,
    targetObj: targetObj,
    definingObj: definingObj,
    propId: propId,
    invokee: invokee,
    namedArgTableAddr: namedArgTableAddr,
    context: context,
  );
  @override
  void evalProperty(T3Value target, int propId, {int? argc, int? namedArgTableAddr}) =>
      execEvalProperty(target, propId, argc: argc, namedArgTableAddr: namedArgTableAddr);
  @override
  void callBuiltin(int setIdx, int funcIdx, int argc) => execCallBuiltin(setIdx, funcIdx, argc);

  // Mixin accessors for T3ExecutionHelpers
  @override
  T3Stack get execStack => _stack;
  @override
  T3Registers get execRegisters => _registers;
  @override
  T3CodePool? get execCodePool => _codePool;
  @override
  T3ConstantPool? get execConstantPool => _constantPool;
  @override
  T3ObjectTable get execObjectTable => _objectTable;
  @override
  T3Entrypoint? get execEntrypoint => _entrypoint;
  @override
  T3MetaclassDepList? get execMetaclasses => _metaclasses;
  @override
  T3FunctionSetDepList? get execFunctionSets => _functionSets;
  @override
  Map<String, T3Value> get execSymbols => _symbols;
  @override
  Map<int, String> get execDynamicStrings => _dynamicStrings;
  @override
  Map<int, List<T3Value>> get execDynamicLists => _dynamicLists;
  @override
  int get execNextDynamicStringOffset => _nextDynamicStringOffset;
  @override
  set execNextDynamicStringOffset(int value) => _nextDynamicStringOffset = value;
  @override
  int get execNextDynamicListOffset => _nextDynamicListOffset;
  @override
  set execNextDynamicListOffset(int value) => _nextDynamicListOffset = value;
  @override
  int get execOutputIgnoreDepth => _outputIgnoreDepth;
  @override
  set execOutputIgnoreDepth(int value) => _outputIgnoreDepth = value;
  @override
  int get execSayMethod => _sayMethod;
  @override
  T3Value get execSayFunc => _sayFunc;
  @override
  int? get execStringMetaclassIdx => _stringMetaclassIdx;
  @override
  int? get execListMetaclassIdx => _listMetaclassIdx;
  @override
  T3ValueHelpers get execValueHelpers => this;

  @override
  void Function(int argc)? getBuiltinFunction(String setName, int funcIdx) {
    final func = T3BuiltinRegistry.getFunction(setName, funcIdx);
    if (func == null) return null;
    return (argc) => func(this, argc);
  }

  @override
  void callFunctionPointer(T3Value func, int argc) {
    if (func.type == T3DataType.funcptr || func.type == T3DataType.codeofs) {
      execCallFunction(func.value, argc);
    } else if (func.type == T3DataType.obj) {
      final codeOfs = getCallableOffset(func.value);
      if (codeOfs != null) {
        execCallFunction(codeOfs, argc);
      } else {
        throw T3Exception('Object ${func.value} is not callable');
      }
    } else {
      throw T3Exception('Value of type ${func.type} is not callable');
    }
  }

  /// Machine registers.
  final T3Registers _registers = T3Registers();

  /// Manager for undo history.
  final T3UndoManager undoManager = T3UndoManager();

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
  int _nextDynamicStringOffset = 0x80000001;

  /// Last regex match state
  Match? lastRegexMatch;
  String? lastRegexString;

  /// Undo manager for the VM.at high offset to avoid conflicts

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

  /// Depth of nested tags being ignored (e.g., `<ABOUTBOX>`, `<TITLE>`).
  int _outputIgnoreDepth = 0;

  /// Whether the interpreter has been loaded.
  bool get isLoaded => _image != null;

  /// Dynamic strings created at runtime (concatenation, etc.)
  Map<int, String> get dynamicStrings => _dynamicStrings;

  /// Method Header Size from Entrypoint
  int get methodHeaderSize => _entrypoint?.methodHeaderSize ?? 0;

  /// Executes a callback function with the given arguments and returns the result.
  /// Uses a nested execution loop, running until the stack frame returns.
  @override
  T3Value execCallback(T3Value callback, List<T3Value> args) {
    // Save current frame pointer to detect return
    final originalFp = _stack.fp;

    // Push arguments in reverse order (right to left per VM convention)
    for (var i = args.length - 1; i >= 0; i--) {
      _stack.push(args[i]);
    }

    // Get the callable offset
    int? codeOffset;
    T3Value? context;
    if (callback.type == T3DataType.funcptr || callback.type == T3DataType.codeofs) {
      codeOffset = callback.value;
    } else if (callback.type == T3DataType.obj) {
      codeOffset = getCallableOffset(callback.value);
      context = callback;
    }

    if (codeOffset == null) {
      throw T3Exception('execCallback: callback is not callable: $callback');
    }

    // Call the function
    execCallFunction(codeOffset, args.length, self: callback, invokee: callback, context: context);

    // Run nested execution loop until we return to original frame
    while (_stack.fp != originalFp) {
      final result = executeInstruction();
      if (result == T3ExecutionResult.quit) break;
    }

    // Return R0 which contains the callback result
    return _registers.r0;
  }

  /// Set the property ID used for specialized SAY handling.
  set sayMethod(int propId) => _sayMethod = propId;

  /// Get the property ID used for specialized SAY handling.
  int get sayMethod => _sayMethod;

  /// Set the function or object used for specialized SAY handling.
  set sayFunc(T3Value val) => _sayFunc = val;

  /// Get the function or object used for specialized SAY handling.
  T3Value get sayFunc => _sayFunc;

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
    _runStaticInitializers();
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
    for (final dep in _metaclasses!.dependencies) {
      // print('DEBUG: Metaclass ${dep.name} index=${dep.index} props=${dep.propertyIds}');
    }

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

  /// Loads all global symbols from SYMD and GSYM blocks.
  void _loadSymbols() {
    _symbols.clear();

    // Load SYMD (Symbolic names for debugging)
    final symdBlocks = _image!.findBlocks(T3Block.typeSymbolicNames);
    for (final block in symdBlocks) {
      final data = _image!.getBlockData(block);
      final parsed = T3SymdBlock.parse(data);
      _symbols.addAll(parsed.symbols);
    }

    // Load GSYM (Global symbols)
    final gsymBlocks = _image!.findBlocks(T3Block.typeGlobalSymbols);
    for (final block in gsymBlocks) {
      final data = _image!.getBlockData(block);
      final parsed = T3SymdBlock.parse(data); // Same format as SYMD
      _symbols.addAll(parsed.symbols);
    }
  }

  /// Gets the object table for debugging/testing.
  T3ObjectTable get objectTable => _objectTable;

  /// Gets the global symbol table.
  Map<String, T3Value> get symbols => Map.unmodifiable(_symbols);

  /// Adds a global symbol (for testing).
  void addGlobalSymbol(String name, T3Value value) {
    _symbols[name] = value;
  }

  /// Gets the VM stack.
  T3Stack get stack => _stack;

  /// Gets the VM registers.
  T3Registers get registers => _registers;

  /// Gets the entrypoint information.
  T3Entrypoint? get entrypoint => _entrypoint;

  /// Gets the constant pool.
  T3ConstantPool? get constantPool => _constantPool;
  set constantPool(T3ConstantPool? value) => _constantPool = value;

  /// Gets the code pool.
  T3CodePool? get codePool => _codePool;
  set codePool(T3CodePool? value) => _codePool = value;

  /// Counter for allocating new property IDs.
  int _nextPropertyId = 0x10000; // Start above typical static property range

  /// Runs all static initializers from SINI blocks.
  void _runStaticInitializers() {
    final blocks = _image!.findBlocks(T3Block.typeStaticInit);
    for (final block in blocks) {
      final data = _image!.getBlockData(block);
      final parsed = T3SiniBlock.parse(data);
      for (final init in parsed.initializers) {
        final objId = init.$1;
        final propId = init.$2;
        runSynchronousTask(() {
          evalProperty(T3Value.fromObject(objId), propId);
        });
      }
    }
  }

  /// Runs a single task (e.g., an initializer) to completion synchronously.
  void runSynchronousTask(void Function() setup) {
    final initialFp = _stack.fp;
    setup();

    // If setup pushed a frame, run until that frame is popped.
    while (_stack.fp > initialFp) {
      final result = executeInstruction();
      if (result == T3ExecutionResult.error) {
        throw T3Exception('Error during static initialization');
      }
      if (result == T3ExecutionResult.quit) {
        throw T3Exception('Unexpected quit during static initialization');
      }
    }
  }

  /// Allocates a new unique property ID.
  int allocatePropertyId() => _nextPropertyId++;

  /// Adds a dynamic string at runtime and returns its offset.
  int addDynamicString(String str) {
    final offset = _nextDynamicStringOffset++;
    _dynamicStrings[offset] = str;
    return offset;
  }

  /// Gets the elements of a list value.
  List<T3Value> getListElements(T3Value listVal) {
    if (!listVal.isList) {
      throw T3Exception('getListElements: expected list, got ${listVal.type}');
    }
    if (_dynamicLists.containsKey(listVal.value)) {
      return _dynamicLists[listVal.value]!;
    }
    return _constantPool!.readList(listVal.value);
  }

  /// Adds a dynamic list at runtime and returns its ID.
  int addDynamicList(List<T3Value> elements) {
    final id = _nextDynamicListOffset++;
    _dynamicLists[id] = elements;
    return id;
  }

  // ==================== Execution ====================

  /// Runs the interpreter until completion.
  Future<void> run() async {
    if (!isLoaded) {
      throw StateError('No image loaded');
    }

    // Set up initial state by "calling" the entrypoint.
    // The entrypoint expects 1 argument: a List of command-line arguments.
    // Create an empty dynamic list for the args.
    final argsListOffset = _nextDynamicListOffset++;
    _dynamicLists[argsListOffset] = <T3Value>[];
    _stack.push(T3Value.fromList(argsListOffset));
    execCallFunction(_entrypoint!.codeOffset, 1);

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
    // Uncomment for full trace:
    // print('TRACE: 0x${opcode.toRadixString(16).toUpperCase()} at 0x${(_registers.ip - 1).toRadixString(16)} stack=${_stack.depth}');
    // if (_stack.depth > 0) print(_stack.dumpTop(5));

    return _executeOpcode(opcode);
  }

  /// Executes the given opcode.
  T3ExecutionResult _executeOpcode(int opcode) {
    // Debug tracing
    printRaw('IP:${(_registers.ip - 1).toRadixString(16)} Op:${opcode.toRadixString(16)}\n');

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
          final actualArgc = _stack.getArgCount();

          if (actualArgc <= fixedCount) {
            _stack.push(T3Value.nil());
          } else {
            final varArgc = actualArgc - fixedCount;
            final elements = <T3Value>[];
            for (var i = 0; i < varArgc; i++) {
              // Arguments are relative to the current frame's base pointer
              elements.add(_stack.getArg(fixedCount + i).copy());
            }

            final offset = _nextDynamicListOffset++;
            _dynamicLists[offset] = elements;
            _stack.push(T3Value.fromList(offset));
          }
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.MAKELSTPAR:
        // Push varargs parameters from a list
        // Pop list, pop arg count, push list elements, push updated count
        {
          final listVal = _stack.pop();
          final countVal = _stack.pop();
          if (!countVal.isInt) {
            throw T3Exception(
              'MAKELSTPAR: expected integer argument count on stack at IP=${(_registers.ip - 2).toRadixString(16)}',
            );
          }

          var currentCount = countVal.value;
          final obj = listVal.isObject ? _objectTable!.lookup(listVal.value) : null;
          final isListLike = listVal.isList || obj is T3VectorObject || obj is T3ListObject;

          if (isListLike) {
            List<T3Value> elements;
            if (listVal.isList) {
              if (_dynamicLists.containsKey(listVal.value)) {
                elements = _dynamicLists[listVal.value]!;
              } else {
                elements = _constantPool!.readList(listVal.value);
              }
            } else if (obj is T3VectorObject) {
              elements = obj.elements;
            } else if (obj is T3ListObject) {
              elements = obj.elements;
            } else {
              elements = [];
            }

            // Push elements in reverse order so first is at top (as Arg0)
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

      case T3Opcodes.SWAP2:
        // Swap top two elements with next two
        // Stack: [A, B, C, D] -> [C, D, A, B] (A is top)
        {
          final a = _stack.pop();
          final b = _stack.pop();
          final c = _stack.pop();
          final d = _stack.pop();
          _stack.push(b);
          _stack.push(a);
          _stack.push(d);
          _stack.push(c);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.SWAPN:
        // Swap elements at given indices (UBYTE idx1, UBYTE idx2)
        {
          final idx1 = _codePool!.readByte(_registers.ip++);
          final idx2 = _codePool!.readByte(_registers.ip++);
          final val1 = _stack.get(idx1);
          final val2 = _stack.get(idx2);
          _stack.set(idx1, val2);
          _stack.set(idx2, val1);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.DUP2:
        // Duplicate top two elements
        {
          final a = _stack.get(0);
          final b = _stack.get(1);
          _stack.push(b.copy());
          _stack.push(a.copy());
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.DUPR0:
        // Push R0 twice
        _stack.push(_registers.r0.copy());
        _stack.push(_registers.r0.copy());
        return T3ExecutionResult.continue_;

      case T3Opcodes.GETSPN:
        // Get stack element at given index (UBYTE idx)
        {
          final idx = _codePool!.readByte(_registers.ip++);
          _stack.push(_stack.get(idx).copy());
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.GETARGC:
        // Push current argument count
        _stack.push(T3Value.fromInt(_stack.getArgCount()));
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
        return doReturn();

      case T3Opcodes.RETNIL: // return nil
        _registers.r0 = T3Value.nil();
        return doReturn();

      case T3Opcodes.RET: // return (keeps R0)
        return doReturn();

      case T3Opcodes.RETTRUE: // return true
        _registers.r0 = T3Value.true_();
        return doReturn();

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

      case T3Opcodes.PUSHCTXELE:
        // Push method context element (UBYTE which)
        {
          final which = _codePool!.readByte(_registers.ip++);
          switch (which) {
            case T3Opcodes.PUSHCTXELE_THIS:
              _stack.pushFrameReference();
              break;
            case T3Opcodes.PUSHCTXELE_TARGPROP:
              _stack.push(_stack.getTargetProp());
              break;
            case T3Opcodes.PUSHCTXELE_TARGOBJ:
              _stack.push(_stack.getTargetObject());
              break;
            case T3Opcodes.PUSHCTXELE_DEFOBJ:
              _stack.push(_stack.getDefiningObject());
              break;
            case T3Opcodes.PUSHCTXELE_INVOKEE:
              _stack.push(_stack.getInvokee());
              break;
            default:
              throw T3Exception('PUSHCTXELE: unknown element $which');
          }
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.GETSETLCL1:
        // Set local from stack and leave value on stack (UBYTE localNum)
        {
          final localNum = _codePool!.readByte(_registers.ip++);
          final val = _stack.peek();
          _stack.setLocal(localNum, val.copy());
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.GETSETLCL1R0:
        // Set local from R0 and push R0 (UBYTE localNum)
        {
          final localNum = _codePool!.readByte(_registers.ip++);
          _stack.setLocal(localNum, _registers.r0.copy());
          _stack.push(_registers.r0.copy());
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.VARARGC:
        // Modifier: next call uses argument count from stack
        _varArgcPending = true;
        return T3ExecutionResult.continue_;

      case T3Opcodes.NAMEDARGPTR:
        // Named argument pointer (UINT4 offset)
        _pendingNamedArgTableAddr = _codePool!.readUint32(_registers.ip);
        _registers.ip += 4;
        return T3ExecutionResult.continue_;

      // Local variable modification opcodes
      case T3Opcodes.ADDILCL1: // add immediate 1-byte int to local (UBYTE index)
        {
          final localNum = _codePool!.readByte(_registers.ip++);
          final addVal = _codePool!.readInt8(_registers.ip++);
          final localVal = _stack.getLocal(localNum);
          if (localVal.isInt) {
            _stack.setLocal(localNum, T3Value.fromInt(localVal.value + addVal));
          } else {
            // Fallback to generic arithmetic for objects (Vector, List, etc.)
            t3Add(localVal, T3Value.fromInt(addVal));
            _stack.setLocal(localNum, _stack.pop());
          }
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.ADDILCL4: // add immediate 4-byte int to local (UINT2 index)
        {
          final localNum = _codePool!.readUint16(_registers.ip);
          _registers.ip += 2;
          final addVal = _codePool!.readInt32(_registers.ip);
          _registers.ip += 4;
          final localVal = _stack.getLocal(localNum);
          if (localVal.isInt) {
            _stack.setLocal(localNum, T3Value.fromInt(localVal.value + addVal));
          } else {
            throwRuntimeError(2004); // VMERR_NUM_VAL_REQD
          }
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.ADDTOLCL: // add stack value to local (UINT2 index)
        // Reference VM: handles integers inline, otherwise uses compute_sum (our t3Add)
        {
          final localNum = _codePool!.readUint16(_registers.ip);
          _registers.ip += 2;
          final addVal = _stack.pop();
          final localVal = _stack.getLocal(localNum);

          if (localVal.isInt && addVal.isInt) {
            // Fast path for integers
            _stack.setLocal(localNum, T3Value.fromInt(localVal.value + addVal.value));
          } else {
            // Use t3Add for objects (Vectors, lists, strings, etc.)
            // t3Add pushes result to stack
            t3Add(localVal, addVal);
            final result = _stack.pop();
            _stack.setLocal(localNum, result);
          }
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.SUBFROMLCL: // subtract stack value from local (UINT2 index)
        // Reference VM vmrun.cpp:3117-3153 - handles integers inline,
        // otherwise tries compute_diff (our t3Sub) or operator overload
        {
          final localNum = _codePool!.readUint16(_registers.ip);
          _registers.ip += 2;
          final subVal = _stack.pop();
          final localVal = _stack.getLocal(localNum);

          if (localVal.isInt && subVal.isInt) {
            // Fast path for integers
            _stack.setLocal(localNum, T3Value.fromInt(localVal.value - subVal.value));
          } else {
            // Use t3Sub for objects (Vectors, etc.) or mixed types
            // t3Sub pushes result to stack
            t3Sub(localVal, subVal);
            final result = _stack.pop();
            _stack.setLocal(localNum, result);
          }
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

      // Increment/decrement local variables (UBYTE index)
      case T3Opcodes.INCLCL: // increment local variable
        final localNum = _codePool!.readByte(_registers.ip);
        _registers.ip++;
        final val = _stack.getLocal(localNum);
        // Optimize for integer common case
        if (val.isInt) {
          _stack.setLocal(localNum, T3Value.fromInt(val.value + 1));
        } else {
          // Fallback to generic arithmetic (pushes result to stack)
          t3Add(val, T3Value.fromInt(1));
          _stack.setLocal(localNum, _stack.pop());
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.DECLCL: // decrement local variable
        final localNum = _codePool!.readByte(_registers.ip);
        _registers.ip++;
        final val = _stack.getLocal(localNum);
        // Optimize for integer common case
        if (val.isInt) {
          _stack.setLocal(localNum, T3Value.fromInt(val.value - 1));
        } else {
          // Fallback to generic arithmetic
          t3Sub(val, T3Value.fromInt(1));
          _stack.setLocal(localNum, _stack.pop());
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
          // Offset is relative to the operand address, not the byte after
          final offset = _codePool!.readInt16(_registers.ip);
          _registers.ip += 2;
          // Push return address (byte after operand)
          final returnOfs = _registers.ip - _registers.ep;
          _stack.push(T3Value.fromInt(returnOfs));
          // Jump: IP is now past operand, so subtract 2 to get offset relative to operand
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

      case T3Opcodes.ITERNEXT:
        // Iterator next: (UINT2 localNum, INT2 jumpOffset)
        // Get iterator from local, get next value. If available, push and skip 2.
        // If exhausted, jump by offset.
        {
          final localNum = _codePool!.readUint16(_registers.ip);
          _registers.ip += 2;
          final jumpOffset = _codePool!.readInt16(_registers.ip);

          final iteratorVal = _stack.getLocal(localNum);
          final nextVal = getIteratorNext(iteratorVal);

          if (nextVal != null) {
            // More values available - push and skip offset bytes
            _stack.push(nextVal);
            _registers.ip += 2;
          } else {
            // No more values - jump by offset
            _registers.ip += jumpOffset;
          }
        }
        return T3ExecutionResult.continue_;

      // ==================== Boolean Operations ====================

      case T3Opcodes.NOT:
        final val = _stack.pop();
        _stack.push(val.isNil ? T3Value.true_() : T3Value.nil());
        return T3ExecutionResult.continue_;

      case T3Opcodes.BOOLIZE:
        final val = _stack.pop();
        _stack.push(val.isLogicalTrue ? T3Value.true_() : T3Value.nil());
        return T3ExecutionResult.continue_;

      // ==================== Arithmetic Operations ====================

      case T3Opcodes.ADD:
        {
          final b = _stack.pop();
          final a = _stack.pop();
          t3Add(a, b);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.SUB:
        {
          final b = _stack.pop();
          final a = _stack.pop();
          t3Sub(a, b);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.MUL:
        {
          final b = _stack.pop();
          final a = _stack.pop();
          t3Mul(a, b);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.DIV:
        {
          final b = _stack.pop();
          final a = _stack.pop();
          t3Div(a, b);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.MOD:
        {
          final b = _stack.pop();
          final a = _stack.pop();
          t3Mod(a, b);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.NEG:
        {
          final val = _stack.pop();
          t3Neg(val);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.INC:
        {
          // INC opcode pops, increments, pushes back.
          // Spec: increments the value on the stack.
          final val = _stack.pop();
          t3Add(val, T3Value.fromInt(1));
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.DEC:
        {
          final val = _stack.pop();
          t3Sub(val, T3Value.fromInt(1));
        }
        return T3ExecutionResult.continue_;

      // ==================== Bitwise Operations ====================

      case T3Opcodes.BAND:
        {
          final b = _stack.pop();
          final a = _stack.pop();
          t3BitAnd(a, b);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.BOR:
        {
          final b = _stack.pop();
          final a = _stack.pop();
          t3BitOr(a, b);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.XOR:
        {
          final b = _stack.pop();
          final a = _stack.pop();
          t3BitXor(a, b);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.BNOT:
        {
          final val = _stack.pop();
          t3BitNot(val);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.SHL:
        {
          final b = _stack.pop();
          final a = _stack.pop();
          t3Shl(a, b);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.ASHR:
        {
          final b = _stack.pop();
          final a = _stack.pop();
          t3Ashr(a, b);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.LSHR:
        {
          final b = _stack.pop();
          final a = _stack.pop();
          t3Lshr(a, b);
        }
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
          // print('DEBUG: GETPROP propId=0x${propId.toRadixString(16)} target=$target');
          execEvalProperty(target, propId, argc: null);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.GETPROPSELF:
        // Get property of self, store in R0
        {
          final propId = _codePool!.readUint16(_registers.ip);
          _registers.ip += 2;
          final self = _stack.getSelf();
          // print('DEBUG: GETPROPSELF propId=0x${propId.toRadixString(16)} target=$self');
          execEvalProperty(self, propId, argc: null);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.GETPROPR0:
        // Get property of R0, store in R0
        {
          final propId = _codePool!.readUint16(_registers.ip);
          _registers.ip += 2;
          execEvalProperty(_registers.r0, propId, argc: null);
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
          execEvalProperty(target, propId, argc: null);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.GETPROPLCL1:
        // Get property of local variable
        {
          final lclIdx = _codePool!.readByte(_registers.ip++);
          final propId = _codePool!.readUint16(_registers.ip);
          _registers.ip += 2;
          final target = _stack.getLocal(lclIdx);
          execEvalProperty(target, propId, argc: null);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.GETPROPDATA:
        // Get property data only (disallow side effects)
        {
          final propId = _codePool!.readUint16(_registers.ip);
          _registers.ip += 2;
          final target = _stack.pop();
          execEvalProperty(target, propId, argc: null);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.PTRGETPROPDATA:
        // Get property data through pointer
        {
          final propPtr = _stack.pop();
          final target = _stack.pop();
          execEvalProperty(target, propPtr.value, argc: null);
        }
        return T3ExecutionResult.continue_;

      // ==================== Method/Function Calls ====================

      case T3Opcodes.CALLPROP:
        // Call method: pop target, call property with argc args
        {
          final argc = _resolveArgc();
          final propId = _codePool!.readUint16(_registers.ip);
          _registers.ip += 2;
          final target = _stack.pop();
          evalProperty(target, propId, argc: argc);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.CALLPROPSELF:
        // Call method on self
        {
          final argc = _resolveArgc();
          handleCallPropSelfOp(argc);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.OBJCALLPROP:
        // Call method on immediate object ID
        {
          final argc = _resolveArgc();
          handleObjCallPropOp(argc);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.CALLPROPLCL1:
        // Call method using local variable as target
        {
          final argc = _resolveArgc();
          handleCallPropLcl1Op(argc);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.CALLPROPR0:
        // Call method on R0
        {
          final argc = _resolveArgc();
          handleCallPropR0Op(argc);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.PTRCALLPROP:
        // Call property via pointer from stack
        {
          final argc = _resolveArgc();
          final propVal = _stack.pop();
          final target = _stack.pop();
          if (!propVal.isProp) {
            throw T3Exception('PTRCALLPROP: expected property value');
          }
          evalProperty(target, propVal.value, argc: argc);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.PTRCALLPROPSELF:
        // Call property on self via pointer from stack
        {
          final argc = _resolveArgc();
          final propVal = _stack.pop();
          if (!propVal.isProp) {
            throw T3Exception('PTRCALLPROPSELF: expected property value');
          }
          evalProperty(_stack.getSelf(), propVal.value, argc: argc);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.INHERIT:
        // Inherit property from superclass (UBYTE argc, UINT2 propId)
        {
          final argc = _resolveArgc();
          final propId = _codePool!.readUint16(_registers.ip);
          _registers.ip += 2;
          inheritProperty(propId, argc);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.PTRINHERIT:
        // Inherit property via pointer (UBYTE argc)
        {
          final argc = _resolveArgc();
          final propVal = _stack.pop();
          if (!propVal.isProp) {
            throw T3Exception('PTRINHERIT: expected property value');
          }
          inheritProperty(propVal.value, argc);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.EXPINHERIT:
        // Inherit from explicit superclass (UBYTE argc, UINT2 propId, UINT4 objId)
        {
          final argc = _resolveArgc();
          final propId = _codePool!.readUint16(_registers.ip);
          _registers.ip += 2;
          final superclassId = _codePool!.readUint32(_registers.ip);
          _registers.ip += 4;
          final superclass = T3Value.fromObject(superclassId);
          evalProperty(superclass, propId, argc: argc);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.PTREXPINHERIT:
        // Inherit from explicit superclass via pointer (UBYTE argc, UINT4 objId)
        {
          final argc = _resolveArgc();
          final propVal = _stack.pop();
          final superclassId = _codePool!.readUint32(_registers.ip);
          _registers.ip += 4;
          if (!propVal.isProp) {
            throw T3Exception('PTREXPINHERIT: expected property value');
          }
          final superclass = T3Value.fromObject(superclassId);
          evalProperty(superclass, propVal.value, argc: argc);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.DELEGATE:
        // Delegate to object on stack (UBYTE argc, UINT2 propId)
        {
          final argc = _resolveArgc();
          final propId = _codePool!.readUint16(_registers.ip);
          _registers.ip += 2;
          final target = _stack.pop();
          evalProperty(target, propId, argc: argc);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.PTRDELEGATE:
        // Delegate via property pointer (UBYTE argc)
        {
          final argc = _resolveArgc();
          final propVal = _stack.pop();
          final target = _stack.pop();
          if (!propVal.isProp) {
            throw T3Exception('PTRDELEGATE: expected property value');
          }
          evalProperty(target, propVal.value, argc: argc);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.CALL:
        // Call function at immediate code offset
        {
          final argc = _resolveArgc();
          handleCallOp(argc);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.PTRCALL:
        // Call function through pointer on stack
        {
          final argc = _resolveArgc();
          handlePtrCallOp(argc);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.SAY:
        {
          final offset = codePool!.readUint32(_registers.ip);
          _registers.ip += 4;
          invokeSay(T3Value.fromString(offset));
        }
        return T3ExecutionResult.continue_;

      // ==================== Built-in Function Calls ====================

      case T3Opcodes.BUILTIN_A:
        // Call built-in function from set 0
        {
          final argc = _resolveArgc();
          handleBuiltinOp(0, argc);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.BUILTIN_B:
        // Call built-in from set 1
        {
          final argc = _resolveArgc();
          handleBuiltinOp(1, argc);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.BUILTIN_C:
        // Call built-in from set 2
        {
          final argc = _resolveArgc();
          handleBuiltinOp(2, argc);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.BUILTIN_D:
        // Call built-in from set 3
        {
          final argc = _resolveArgc();
          handleBuiltinOp(3, argc);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.BUILTIN1:
        // Call built-in function from any set (8-bit index)
        {
          final argc = _resolveArgc();
          handleBuiltin1Op(argc);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.BUILTIN2:
        // Call built-in function from any set (16-bit index)
        {
          final argc = _resolveArgc();
          handleBuiltin2Op(argc);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.SAYVAL:
        {
          final val = _stack.pop();
          invokeSay(val);
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
          setPropertyValue(target, propId, val);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.PTRSETPROP:
        // Set property through pointer: pop val, pop target, pop propPtr
        {
          final propPtr = _stack.pop();
          final target = _stack.pop();
          final val = _stack.pop();
          setPropertyValue(target, propPtr.value, val);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.SETPROPSELF:
        // Set property on self: pop val, set prop
        {
          final propId = _codePool!.readUint16(_registers.ip);
          _registers.ip += 2;
          final val = _stack.pop();
          setPropertyValue(_stack.getSelf(), propId, val);
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
          setPropertyValue(T3Value.fromObject(objId), propId, val);
        }
        return T3ExecutionResult.continue_;

      // ==================== Indexing Operations ====================

      case T3Opcodes.IDXLCL1INT8:
        // Index local variable by 8-bit constant: (UBYTE localNum, UBYTE idx)
        {
          final localNum = _codePool!.readByte(_registers.ip++);
          final idx = _codePool!.readByte(_registers.ip++);
          final listVal = _stack.getLocal(localNum);
          final result = applyIndex(listVal, idx);
          _stack.push(result);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.IDXINT8:
        // Index top of stack by 8-bit constant: (UBYTE idx)
        {
          final idx = _codePool!.readByte(_registers.ip++);
          final listVal = _stack.pop();
          final result = applyIndex(listVal, idx);
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
          final result = applyIndex(listVal, idxVal.value);
          _stack.push(result);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.LOADCTX:
        // LOADCTX: Restore method context
        // Pop the context object (list or anon-fn) and set current frame context
        {
          final ctxVal = _stack.pop();
          if (ctxVal.type == T3DataType.obj) {
            final obj = _objectTable!.lookup(ctxVal.value);
            if (obj is T3ListObject || obj is T3AnonFnObject) {
              // Extract elements: [self, prop, targetObj, definingObj]
              // Note: T3AnonFnObject element 0 is funcPtr, so context starts at 1
              // T3ListObject context starts at 0
              final isAnon = obj is T3AnonFnObject;
              final listElements = (isAnon) ? (obj as T3VectorObject).elements : (obj as T3ListObject).elements;
              final offset = isAnon ? 1 : 0;

              if (listElements.length >= offset + 4) {
                _stack.setMethodContext(
                  self: listElements[offset + 0],
                  targetProp: listElements[offset + 1].value, // Prop is stored as value
                  targetObj: listElements[offset + 2],
                  definingObj: listElements[offset + 3],
                );
              } else {
                throw T3Exception('LOADCTX: Invalid context object size');
              }
            } else {
              throw T3Exception('LOADCTX: Invalid object type for context');
            }
          } else if (ctxVal.type == T3DataType.nil) {
            // Nil context - clear everything? Reference VM typically expects a list.
            // We'll leave it as is or clear if needed.
          } else {
            throw T3Exception('LOADCTX: Invalid type');
          }
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.STORECTX:
        // STORECTX: Capture method context
        // Create a list [self, prop, targetObj, definingObj], store in FP-5, and push list
        {
          final self = _stack.getSelf();
          final targetProp = _stack.getTargetProp();
          final targetObj = _stack.getTargetObject();
          final definingObj = _stack.getDefiningObject();

          final elements = [self, targetProp, targetObj, definingObj];
          final newObjId = _objectTable!.createDynamicObject('list', elements, isTransient: false);
          final ctxVal = T3Value.fromObject(newObjId);

          _stack.setFrameReference(ctxVal);
          _stack.push(ctxVal);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.PUSHCTXELE:
        // PUSHCTXELE: Push specific context element from current frame
        {
          final eleType = _codePool!.readByte(_registers.ip++);
          switch (eleType) {
            case 1: // PUSHCTXELE_TARGPROP
              _stack.push(_stack.getTargetProp());
              break;
            case 2: // PUSHCTXELE_TARGOBJ
              _stack.push(_stack.getTargetObject());
              break;
            case 3: // PUSHCTXELE_DEFOBJ
              _stack.push(_stack.getDefiningObject());
              break;
            case 4: // PUSHCTXELE_INVOKEE
              _stack.push(_stack.getInvokee());
              break;
            default:
              throw T3Exception('PUSHCTXELE: Invalid element type $eleType');
          }
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.SETIND:
        // Set indexed value: Stack order per reference VM (vmrun.cpp:3209-3220):
        // Pop order: index, container, value. Then set container[index] = value.
        // Per reference VM (vmrun.cpp:3223), push the new container value afterward.
        {
          // printRaw('DEBUG: SETIND stack depth=${_stack.depth}\n');
          // Reference VM: popval(&val2) = index, popval(&val) = container, popval(&val3) = value
          final idxVal = _stack.pop(); // First pop: index
          final containerVal = _stack.pop(); // Second pop: container
          final newVal = _stack.pop(); // Third pop: value to assign
          // printRaw(
          //   'DEBUG: SETIND container=${containerVal.type}:${containerVal.value} idx=${idxVal.type}:${idxVal.value} val=${newVal.type}:${newVal.value}\n',
          // );

          if (!idxVal.isInt) {
            throw T3Exception('SETIND: index must be an integer');
          }
          setIndexedValue(containerVal, idxVal.value, newVal);

          // Push the new container value (reference VM vmrun.cpp:3223)
          _stack.push(containerVal);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.SETINDLCL1I8:
        // Set indexed local: (UBYTE localNum, SBYTE idx) - set local[idx] to TOS
        {
          final localNum = _codePool!.readByte(_registers.ip++);
          final idx = _codePool!.readInt8(_registers.ip++);
          final newVal = _stack.pop();
          final listVal = _stack.getLocal(localNum);
          setIndexedValue(listVal, idx, newVal);
        }
        return T3ExecutionResult.continue_;

      // ==================== Object Creation ====================

      case T3Opcodes.NEW1:
        // Create new object (1-byte operands)
        // Format: [0xC0] [metaclass_idx UBYTE] [argc UBYTE]
        {
          final metaclassIdx = _codePool!.readByte(_registers.ip++);
          final argc = _resolveArgc();
          createNewObject(metaclassIdx, argc, isTransient: false);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.NEW2:
        // Create new object (2-byte operands)
        // Format: [0xC1] [metaclass_idx UINT2] [argc UBYTE]
        {
          final metaclassIdx = _codePool!.readUint16(_registers.ip);
          _registers.ip += 2;
          final argc = _resolveArgc();
          createNewObject(metaclassIdx, argc, isTransient: false);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.TRNEW1:
        // Create transient object (1-byte operands)
        {
          final metaclassIdx = _codePool!.readByte(_registers.ip++);
          final argc = _resolveArgc();
          createNewObject(metaclassIdx, argc, isTransient: true);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.TRNEW2:
        // Create transient object (2-byte operands)
        {
          final metaclassIdx = _codePool!.readUint16(_registers.ip);
          _registers.ip += 2;
          final argc = _resolveArgc();
          createNewObject(metaclassIdx, argc, isTransient: true);
        }
        return T3ExecutionResult.continue_;

      // ==================== Exception Handling ====================

      case T3Opcodes.THROW:
        // Throw exception
        // Pop exception object from stack and find handler
        {
          final exceptionObj = _stack.pop();
          if (!exceptionObj.isObject && !exceptionObj.isNil) {
            throw T3Exception('THROW: expected object on stack or nil, got ${exceptionObj.type}');
          }

          final exceptionId = exceptionObj.isObject ? exceptionObj.value : null;

          // Try to find an exception handler
          final handlerAddr = findExceptionHandler(exceptionId);
          if (handlerAddr != null) {
            // Handler found - push exception and jump to handler
            _stack.push(exceptionObj);
            _registers.ip = handlerAddr;
          } else {
            // No handler found - terminate with unhandled exception
            final msg = exceptionId != null ? 'object #$exceptionId' : 'unknown (nil)';

            // Debugging: Dump info about the exception object
            if (exceptionObj.isObject) {
              final obj = execObjectTable.lookup(exceptionObj.value);
              printRaw('\n[Exception Object Dump (THROW)]\n');
              printRaw('Type: ${obj.runtimeType}\n');

              // Use helper methods from T3ExecutionHelpers mixin
              final errnoProp = getSymbolPropertyId('errno');
              if (errnoProp != null) {
                final errnoVal = execObjectTable.lookupProperty(exceptionObj.value, errnoProp);
                if (errnoVal != null && errnoVal.value.isInt) {
                  printRaw('errno: ${errnoVal.value.value}\n');
                }
              }

              final msgProp = getSymbolPropertyId('exceptionMessage');
              if (msgProp != null) {
                final msgVal = execObjectTable.lookupProperty(exceptionObj.value, msgProp);
                if (msgVal != null && msgVal.value.isStringLike) {
                  printRaw('message: ${getStringValue(msgVal.value)}\n');
                }
              }
            }

            throw T3Exception('Unhandled exception: $msg');
          }
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.SETSELF:
        // Set self object: pop from stack and set as current self
        {
          final newVal = _stack.pop();
          _stack.setSelf(newVal);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.NAMEDARGTAB:
        // Named argument table (UINT2 element_count) - skip it, it's just data
        {
          final count = _codePool!.readUint16(_registers.ip);
          _registers.ip += 2 + (count * 6);
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.CALLEXT:
        // Call external function (UBYTE idx, UBYTE argc) - placeholder
        {
          _registers.ip += 2;
          // External functions are host-level, return nil for now
          _registers.r0 = T3Value.nil();
        }
        return T3ExecutionResult.continue_;

      case T3Opcodes.BP:
        // Breakpoint - no-op for us
        return T3ExecutionResult.continue_;

      case T3Opcodes.SETDBLCL:
        _registers.ip += 2;
        return T3ExecutionResult.continue_;

      case T3Opcodes.SETDBARG:
        // Debug opcodes - no-op for us
        {
          _registers.ip += 2;
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

  /// Raw print to console - bridge for mixins.
  void printRaw(String text) {
    if (text.isEmpty) return;
    // ignore: avoid_print
    stdout.write(text);
  }

  /// Gets info for debugging.
  /// Resolves the argument count for a call, handling the VARARGC modifier.
  int _resolveArgc({bool argcIsSecondOperand = false}) {
    if (_varArgcPending) {
      _varArgcPending = false;
      // Skip the 1-byte argc operand in the code stream
      _registers.ip++;
      final countVal = _stack.pop();
      if (!countVal.isInt) {
        throw T3Exception('VARARGC: expected integer argument count on stack');
      }
      return countVal.value;
    } else {
      if (argcIsSecondOperand) {
        // For NEW1/TRNEW1, argc is the second operand.
        // We need to read the first operand (metaclassIdx), then argc.
        // But wait, the main loop already handles this by calling _resolveArgc
        // specifically for the argc operand.
        return _codePool!.readByte(_registers.ip++);
      }
      return _codePool!.readByte(_registers.ip++);
    }
  }

  String debugInfo() {
    return 'T3Interpreter: ip=0x${_registers.ip.toRadixString(16)}, '
        'stack=${_stack.depth}, instructions=$_instructionCount';
  }

  // --- Undo Context Implementation ---

  @override
  void undoSetProperty(int objectId, int propId, T3Value? oldValue) {
    final obj = _objectTable.lookup(objectId);
    if (obj is T3TadsObject) {
      if (oldValue == null) {
        obj.modifiedProperties.remove(propId);
      } else {
        obj.modifiedProperties[propId] = oldValue;
      }
    }
  }

  @override
  void undoCreateObject(int objectId) {
    _objectTable.remove(objectId);
  }

  @override
  void undoVectorSet(int objectId, int index, T3Value oldValue) {
    final obj = _objectTable.lookup(objectId);
    if (obj is T3VectorObject) {
      if (index >= 0 && index < obj.elements.length) {
        obj.elements[index] = oldValue;
      }
    }
  }
}
