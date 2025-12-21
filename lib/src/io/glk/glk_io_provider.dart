import 'dart:async';

// Reference: packages/ifarchive-if-specs/glk-spec.md
// The reference is written assuming C-style code.  It is also written to the
// perspective of the interpreter developer.  Since we are building our own
// glulx interpreter, and we are using the Dart language, we will implement
// the Glk spec as an interface class that various platform-specific implementations
// can then implement to suit their presentation layer needs.

/// IO provider to dispatch all Glk IO operations.
/// All methods implemented in this interface should be async to support
/// asynchronous operations if needed.
abstract class GlkIoProvider {
  /// Gestalt returns 0 for everything right now, and will expand as we implement more features.
  FutureOr<int> glkDispatch(int selector, List<int> args);

  /// Handles Glulx VM-level gestalt queries (the @gestalt opcode).
  int vmGestalt(int selector, int arg) => 0;

  /// Write a value to game memory. Override to provide memory access.
  void writeMemory(int addr, int value, {int size = 1}) {}

  /// Read a value from game memory. Override to provide memory access.
  int readMemory(int addr, {int size = 1}) => 0;

  /// Configure memory access callbacks.
  void setMemoryAccess({
    required void Function(int addr, int value, {int size}) write,
    required int Function(int addr, {int size}) read,
  }) {}

  /// Configure VM state callbacks.
  void setVMState({int Function()? getHeapStart}) {}

  /// Push a 32-bit value onto the VM stack.
  /// Used when Glk struct addresses are 0xFFFFFFFF (-1).
  void pushToStack(int value) {}

  /// Pop a 32-bit value from the VM stack.
  /// Used when Glk struct addresses are 0xFFFFFFFF (-1).
  int popFromStack() => 0;

  /// Configure stack access callbacks.
  void setStackAccess({required void Function(int value) push, required int Function() pop}) {}
}
