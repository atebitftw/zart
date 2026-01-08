import 'dart:typed_data';

import 'package:zart/src/tads3/loaders/entp_parser.dart';
import 'package:zart/src/tads3/loaders/mcld_parser.dart';
import 'package:zart/src/tads3/vm/t3_interpreter.dart';
import 'package:zart/src/tads3/vm/t3_code_pool.dart';
import 'package:zart/src/tads3/vm/t3_constant_pool.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';
import 'package:zart/src/tads3/vm/t3_opcodes.dart';
import 'package:zart/src/tads3/vm/t3_execution_result.dart';

/// Test harness for executing T3 opcodes in isolation.
///
/// Provides a simple way to build bytecode sequences, execute them,
/// and verify the resulting VM state.
///
/// Example usage:
/// ```dart
/// final harness = OpcodeTestHarness();
/// harness.emit(T3Opcodes.PUSHINT8);
/// harness.emitByte(42);
/// harness.emit(T3Opcodes.PUSHINT8);
/// harness.emitByte(10);
/// harness.emit(T3Opcodes.ADD);
/// harness.run();
/// expect(harness.pop().value, 52);
/// ```
class OpcodeTestHarness {
  late T3Interpreter interpreter;
  final BytesBuilder _bytecode = BytesBuilder();
  final BytesBuilder _constantData = BytesBuilder();
  int _entryPoint = 0;
  int _constantOffset = 0;

  OpcodeTestHarness() {
    interpreter = T3Interpreter();
    interpreter.onPrint = (text) => output.write(text);
  }

  /// Current bytecode length (for calculating offsets).
  int get bytecodeLength => _bytecode.length;

  // ==================== Constant Pool Helpers ====================

  /// Adds a list to the constant pool and returns its offset.
  /// The list can then be referenced via PUSHLST with this offset.
  int addList(List<T3Value> elements) {
    final offset = _constantOffset;

    // List format: UINT2 element count + (type byte + value bytes) per element
    _constantData.addByte(elements.length & 0xFF);
    _constantData.addByte((elements.length >> 8) & 0xFF);

    for (final elem in elements) {
      // Type byte
      _constantData.addByte(elem.type.code);
      // Value bytes (4 bytes, little-endian)
      final val = elem.value;
      _constantData.addByte(val & 0xFF);
      _constantData.addByte((val >> 8) & 0xFF);
      _constantData.addByte((val >> 16) & 0xFF);
      _constantData.addByte((val >> 24) & 0xFF);
    }

    _constantOffset = _constantData.length;
    return offset;
  }

  /// Adds a string to the constant pool and returns its offset.
  int addString(String str) {
    final offset = _constantOffset;
    final bytes = str.codeUnits;

    // String format: UINT2 length + UTF-8 bytes
    _constantData.addByte(bytes.length & 0xFF);
    _constantData.addByte((bytes.length >> 8) & 0xFF);
    _constantData.add(bytes);

    _constantOffset = _constantData.length;
    return offset;
  }

  /// Emits a single opcode byte.
  void emit(int opcode) {
    _bytecode.addByte(opcode);
  }

  /// Emits a single data byte.
  void emitByte(int value) {
    _bytecode.addByte(value & 0xFF);
  }

  /// Emits a signed 8-bit value.
  void emitInt8(int value) {
    _bytecode.addByte(value & 0xFF);
  }

  final List<T3ExceptionRecord> _exceptions = [];

  /// Adds an exception handler to the current method.
  void addExceptionHandler(int startAddr, int endAddr, int handlerAddr, int exceptionClass) {
    _exceptions.add(
      T3ExceptionRecord(
        startAddr: startAddr,
        endAddr: endAddr,
        handlerAddr: handlerAddr,
        exceptionClass: exceptionClass,
      ),
    );
  }

  /// Emits an unsigned 16-bit value (little-endian).
  void emitUint16(int value) {
    _bytecode.addByte(value & 0xFF);
    _bytecode.addByte((value >> 8) & 0xFF);
  }

  /// Emits a signed 16-bit value (little-endian).
  void emitInt16(int value) {
    emitUint16(value);
  }

  /// Emits an unsigned 32-bit value (little-endian).
  void emitUint32(int value) {
    _bytecode.addByte(value & 0xFF);
    _bytecode.addByte((value >> 8) & 0xFF);
    _bytecode.addByte((value >> 16) & 0xFF);
    _bytecode.addByte((value >> 24) & 0xFF);
  }

  /// Emits a signed 32-bit value (little-endian).
  void emitInt32(int value) {
    emitUint32(value);
  }

  /// Sets entry point to current bytecode position.
  void markEntryPoint() {
    _entryPoint = _bytecode.length;
  }

  /// Gets current bytecode offset (for calculating jumps).
  int get currentOffset => _bytecode.length;

  /// Builds the interpreter state and loads the bytecode.
  void build({int localCount = 16, int argCount = 0}) {
    final bytecodeBytes = _bytecode.toBytes();

    // Create code pool and load bytecode
    final pool = T3CodePool(poolId: 1, pageCount: 1, pageSize: bytecodeBytes.length + 1024);
    pool.loadPage(0, Uint8List.fromList([...bytecodeBytes, ...List.filled(1024, 0)]));
    interpreter.codePool = pool;

    // Create constant pool if we have constant data
    final constBytes = _constantData.toBytes();
    if (constBytes.isNotEmpty) {
      final constantPool = T3ConstantPool(poolId: 2, pageCount: 1, pageSize: constBytes.length + 1024);
      constantPool.loadPage(0, Uint8List.fromList([...constBytes, ...List.filled(1024, 0)]));
      interpreter.constantPool = constantPool;
    }

    // Set IP to entry point
    interpreter.registers.ip = _entryPoint;
    interpreter.registers.ep = _entryPoint;

    // Ensure we have an entrypoint with standard header sizes
    if (interpreter.execEntrypoint == null) {
      interpreter.entrypoint = T3Entrypoint(
        codeOffset: _entryPoint,
        methodHeaderSize: 10,
        exceptionEntrySize: 6,
        debugLineEntrySize: 0,
        debugTableHeaderSize: 0,
        debugLocalHeaderSize: 0,
        debugRecordsVersion: 1,
        debugFrameHeaderSize: 10,
      );
    }

    // Push arguments before the frame (T3 calling convention)
    final actualArgs = _args.isNotEmpty ? _args : [];
    final actualArgCount = argCount > 0 ? argCount : actualArgs.length;

    for (final arg in actualArgs.reversed) {
      interpreter.stack.push(arg);
    }

    // Set up a base frame for execution
    interpreter.stack.pushFrame(
      argCount: actualArgCount,
      localCount: localCount,
      returnAddr: 0,
      entryPtr: _entryPoint,
      self: _self,
      targetObj: _targetObj,
      definingObj: _definingObj,
      targetProp: _targetProp,
      invokee: T3Value.nil(),
    );
  }

  // Frame configuration
  T3Value _self = T3Value.nil();
  T3Value _targetObj = T3Value.nil();
  T3Value _definingObj = T3Value.nil();
  int _targetProp = 0;
  List<T3Value> _args = [];

  /// Sets up arguments for the frame.
  void addArgs(List<T3Value> args) {
    _args = args;
  }

  /// Sets self for the frame.
  void setSelf(T3Value self) {
    _self = self;
  }

  /// Sets target property for the frame.
  void setTargetProp(int prop) {
    _targetProp = prop;
  }

  /// Sets defining object for the frame.
  void setDefiningObject(T3Value obj) {
    _definingObj = obj;
  }

  /// Executes a single instruction.
  T3ExecutionResult step() {
    return interpreter.executeInstruction();
  }

  /// Executes instructions until the current frame returns.
  void runUntilReturn() {
    final originalFp = interpreter.stack.fp;
    for (var i = 0; i < 1000; i++) {
      step();
      if (interpreter.stack.fp < originalFp) return;
    }
    throw StateError('Exceeded max instructions (1000) in runUntilReturn');
  }

  /// Executes instructions until quit or error.
  void run({int maxInstructions = 1000}) {
    for (var i = 0; i < maxInstructions; i++) {
      final result = step();
      if (result == T3ExecutionResult.quit || result == T3ExecutionResult.error) {
        return;
      }
    }
    throw StateError('Exceeded max instructions ($maxInstructions)');
  }

  /// Runs exactly N instructions.
  void runSteps(int n) {
    for (var i = 0; i < n; i++) {
      step();
    }
  }

  // ==================== Stack Helpers ====================

  /// Pushes a value onto the stack.
  void push(T3Value value) {
    interpreter.stack.push(value);
  }

  /// Pushes an integer onto the stack.
  void pushInt(int value) {
    interpreter.stack.push(T3Value.fromInt(value));
  }

  /// Pops a value from the stack.
  T3Value pop() {
    return interpreter.stack.pop();
  }

  /// Peeks at the top of the stack.
  T3Value peek() {
    return interpreter.stack.peek();
  }

  /// Gets the current stack depth.
  int get stackDepth => interpreter.stack.depth;

  // ==================== Register Helpers ====================

  /// Gets the R0 register value.
  T3Value get r0 => interpreter.registers.r0;

  /// Sets the R0 register value.
  set r0(T3Value value) => interpreter.registers.r0 = value;

  /// Gets the current IP.
  int get ip => interpreter.registers.ip;

  /// Sets the current IP.
  set ip(int value) => interpreter.registers.ip = value;

  // ==================== Local Variable Helpers ====================

  /// Sets a local variable.
  void setLocal(int index, T3Value value) {
    interpreter.stack.setLocal(index, value);
  }

  /// Gets a local variable.
  T3Value getLocal(int index) {
    return interpreter.stack.getLocal(index);
  }

  // ==================== Convenience Builders ====================

  /// Builds bytecode that pushes an int8 and returns result in R0.
  static OpcodeTestHarness withPushInt8(int value) {
    final h = OpcodeTestHarness();
    h.emit(T3Opcodes.PUSHINT8);
    h.emitInt8(value);
    h.build();
    return h;
  }

  /// Builds bytecode that pushes an int32.
  static OpcodeTestHarness withPushInt(int value) {
    final h = OpcodeTestHarness();
    h.emit(T3Opcodes.PUSHINT);
    h.emitInt32(value);
    h.build();
    return h;
  }

  /// Builds bytecode for a binary operation (a op b).
  static OpcodeTestHarness withBinaryOp(int opcode, int a, int b) {
    final h = OpcodeTestHarness();
    h.emit(T3Opcodes.PUSHINT);
    h.emitInt32(a);
    h.emit(T3Opcodes.PUSHINT);
    h.emitInt32(b);
    h.emit(opcode);
    h.build();
    return h;
  }

  /// Builds bytecode for a unary operation.
  static OpcodeTestHarness withUnaryOp(int opcode, int value) {
    final h = OpcodeTestHarness();
    h.emit(T3Opcodes.PUSHINT);
    h.emitInt32(value);
    h.emit(opcode);
    h.build();
    return h;
  }

  // ==================== Object/Metaclass Infrastructure ====================

  /// Captured output buffer.
  final StringBuffer output = StringBuffer();

  /// Creates a new test harness.
  int allocateObjectId() => interpreter.objectTable.allocateObjectId();

  /// Creates a TadsObject with the given properties using the real object table.
  /// Returns the object ID.
  int createObject({
    int? id,
    List<T3ObjectProperty>? properties,
    List<int>? superclasses,
    int? superclass,
    int flags = 0,
  }) {
    final objectId = id ?? interpreter.objectTable.allocateObjectId();
    final obj = T3TadsObject(
      objectId: objectId,
      superclasses: superclasses ?? (superclass != null ? [superclass] : []),
      loadImageProperties: properties ?? [],
      flags: flags,
    );
    interpreter.objectTable.register(obj);
    return objectId;
  }

  /// Creates a dynamic list object using the interpreter's object table.
  /// Returns the object ID.
  int createListObject(List<T3Value> elements) {
    return interpreter.objectTable.createDynamicObject('list', elements);
  }

  /// Creates a dynamic vector object.
  int createVectorObject(List<T3Value> elements) {
    return interpreter.objectTable.createDynamicObject('vector', elements);
  }

  /// Creates a dynamic iterator object.
  int createIteratorObject(int objectId, List<T3Value> elements) {
    final obj = T3IteratorObject(objectId: objectId, collection: T3Value.nil(), elements: elements);
    interpreter.objectTable.register(obj);
    return objectId;
  }

  /// Gets list values for a T3Value.
  List<T3Value> getListValues(T3Value listVal) {
    return interpreter.getListValues(listVal);
  }

  /// Looks up an object by ID.
  T3Object? lookupObject(int objectId) {
    return interpreter.objectTable.lookup(objectId);
  }

  /// Gets a property from an object.
  T3Value? getObjectProperty(int objectId, int propId) {
    final result = interpreter.objectTable.lookupProperty(objectId, propId);
    return result?.value;
  }

  /// Sets a property on an object.
  void setObjectProperty(int objectId, int propId, T3Value value) {
    final obj = interpreter.objectTable.lookup(objectId);
    if (obj is T3TadsObject) {
      obj.setProperty(propId, value);
    }
  }

  // ==================== Metaclass Infrastructure ====================

  /// Registers metaclasses for object creation tests.
  /// Call before build() to set up metaclass dependencies.
  void registerMetaclasses(List<String> names) {
    final deps = <T3MetaclassDep>[];
    for (var i = 0; i < names.length; i++) {
      deps.add(T3MetaclassDep(identifier: names[i], index: i, name: names[i], propertyCount: 0, propertyIds: []));
    }
    interpreter.metaclasses = T3MetaclassDepList(deps);
  }

  // ==================== Function Code Setup ====================

  /// Adds a function to the code pool at a specific offset.
  /// Returns the offset where the function starts.
  /// The function should be complete bytecode including method header.
  int addFunction(List<int> bytecode) {
    final offset = _bytecode.length;
    for (final b in bytecode) {
      _bytecode.addByte(b);
    }
    return offset;
  }

  /// Creates a simple method header for a function.
  /// Returns the header bytes.
  static List<int> createMethodHeader({
    required int argCount,
    required int localCount,
    int isVarargs = 0,
    int exceptionTableOffset = 0,
  }) {
    // 10-byte standard header
    return [
      argCount & 0xFF | (isVarargs != 0 ? 0x80 : 0), // argc (minArgs + varargs flag)
      0x00, // optionalArgc
      localCount & 0xFF, // stack_size (locals)
      localCount >> 8,
      0x00, // method_flags
      0x00,
      exceptionTableOffset & 0xFF,
      (exceptionTableOffset >> 8) & 0xFF,
      0x00, // debug_records_offset
      0x00,
    ];
  }
}

/// Helper class to track exception handlers in the test harness.
class T3ExceptionRecord {
  final int startAddr;
  final int endAddr;
  final int handlerAddr;
  final int exceptionClass;

  T3ExceptionRecord({
    required this.startAddr,
    required this.endAddr,
    required this.handlerAddr,
    required this.exceptionClass,
  });
}
