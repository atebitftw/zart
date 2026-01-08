import 'dart:typed_data';

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
  }

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

  /// Loads the bytecode into the interpreter and prepares for execution.
  void build() {
    final bytes = Uint8List.fromList(_bytecode.toBytes());

    // Create a single-page code pool with the bytecode
    final codePool = T3CodePool(poolId: 1, pageCount: 1, pageSize: bytes.length + 1024);
    codePool.loadPage(0, Uint8List.fromList([...bytes, ...List.filled(1024, 0)]));
    interpreter.codePool = codePool;

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

    // Push arguments onto the stack BEFORE the frame (per T3 calling convention)
    // Arg 0 is the last pushed (closest to frame header), so push in reverse order
    for (var i = _args.length - 1; i >= 0; i--) {
      interpreter.stack.push(_args[i]);
    }

    // Push a base frame so we have locals available
    interpreter.stack.pushFrame(
      argCount: _argCount,
      localCount: 16,
      returnAddr: 0,
      entryPtr: 0,
      self: _self,
      targetObj: _targetObj,
      definingObj: _definingObj,
      targetProp: _targetProp,
      invokee: T3Value.nil(),
    );
  }

  // Frame configuration
  int _argCount = 0;
  T3Value _self = T3Value.nil();
  T3Value _targetObj = T3Value.nil();
  T3Value _definingObj = T3Value.nil();
  int _targetProp = 0;
  List<T3Value> _args = [];

  /// Sets up arguments for the frame.
  void setArgs(List<T3Value> args) {
    _args = args;
    _argCount = args.length;
  }

  /// Sets self for the frame.
  void setSelf(T3Value self) {
    _self = self;
  }

  /// Sets target property for the frame.
  void setTargetProp(int prop) {
    _targetProp = prop;
  }

  /// Executes a single instruction.
  T3ExecutionResult step() {
    return interpreter.executeInstruction();
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

  /// Creates a TadsObject with the given properties using the real object table.
  /// Returns the object ID.
  int createObject({List<T3ObjectProperty>? properties, int? superclass, int flags = 0}) {
    final obj = T3TadsObject(
      objectId: interpreter.objectTable.allocateObjectId(),
      superclasses: superclass != null ? [superclass] : [],
      loadImageProperties: properties ?? [],
      flags: flags,
    );
    interpreter.objectTable.register(obj);
    return obj.objectId;
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
}
