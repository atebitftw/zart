import 'dart:typed_data';

import 'package:zart/src/glulx/glulx_exception.dart';

/// Glulx Interpreter Stack
///
/// The stack is an array of values. It is not a part of main memory; the terp maintains it separately.
/// The stack consists of a set of call frames, one for each function in the current chain.
/// When a function is called, a new stack frame is pushed, containing the function's local variables.
/// The function can then push or pull 32-bit values on top of that, to store intermediate computations.
class GlulxStack {
  /// The stack memory.
  late ByteData _memory;

  /// The raw stack memory.
  late Uint8List _rawMemory;

  /// The stack pointer (byte offset).
  int sp = 0;

  /// Instantiates a [GlulxStack] with a maximum size.
  GlulxStack({int size = 65536}) {
    _rawMemory = Uint8List(size);
    _memory = ByteData.sublistView(_rawMemory);
  }

  /// Pushes a 32-bit value onto the stack.
  void push(int value) {
    if (sp + 4 > _memory.lengthInBytes) {
      throw GlulxException('Stack Overflow');
    }
    _memory.setUint32(sp, value);
    sp += 4;
  }

  /// Pops a 32-bit value from the stack.
  int pop() {
    if (sp < 4) {
      throw GlulxException('Stack Underflow');
    }
    sp -= 4;
    return _memory.getUint32(sp);
  }

  /// Peeks a 32-bit value at the top of the stack.
  int peek() {
    if (sp < 4) {
      throw GlulxException('Stack Underflow');
    }
    return _memory.getUint32(sp - 4);
  }

  // --- Call Stub Operations ---

  /// Pushes a call stub onto the stack.
  void pushCallStub(int destType, int destAddr, int pc, int framePtr) {
    push(destType);
    push(destAddr);
    push(pc);
    push(framePtr);
  }

  /// Pops a call stub from the stack.
  /// Returns a list [destType, destAddr, pc, framePtr].
  List<int> popCallStub() {
    final framePtr = pop();
    final pc = pop();
    final destAddr = pop();
    final destType = pop();
    return [destType, destAddr, pc, framePtr];
  }

  // --- Stack Access Helpers (for Locals, etc.) ---

  /// Reads an 8-bit value from the stack at the given offset.
  int read8(int offset) {
    return _memory.getUint8(offset);
  }

  /// Reads a 16-bit value from the stack at the given offset.
  int read16(int offset) {
    return _memory.getUint16(offset);
  }

  /// Reads a 32-bit value from the stack at the given offset.
  int read32(int offset) {
    return _memory.getUint32(offset);
  }

  /// Writes an 8-bit value to the stack at the given offset.
  void write8(int offset, int value) {
    _memory.setUint8(offset, value);
  }

  /// Writes a 16-bit value to the stack at the given offset.
  void write16(int offset, int value) {
    _memory.setUint16(offset, value);
  }

  /// Writes a 32-bit value to the stack at the given offset.
  void write32(int offset, int value) {
    _memory.setUint32(offset, value);
  }

  /// Resets the stack.
  void clear() {
    sp = 0;
    // Optional: Zero out memory? Glulx spec doesn't strictly require it on reset,
    // but useful for determinism.
    for (int i = 0; i < _rawMemory.length; i++) {
      _rawMemory[i] = 0;
    }
  }
}
