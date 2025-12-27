import 'dart:async';
import 'dart:typed_data';

/// IO provider for Glulx/Glk operations.
///
/// This interface defines the contract between the GlulxInterpreter and
/// the presentation layer for Glk-based I/O operations.
///
/// Reference: packages/ifarchive-if-specs/glk-spec.md
abstract class GlkProvider {
  /// Dispatch a Glk function call.
  ///
  /// [selector] - Glk function selector (e.g., glk_put_char = 0x80).
  /// [args] - The function arguments.
  ///
  /// Returns the operation result.
  FutureOr<int> dispatch(int selector, List<int> args);

  /// Handles Glulx VM-level gestalt queries (the @gestalt opcode).
  ///
  /// This is separate from Glk gestalt - it queries the VM capabilities.
  int vmGestalt(int selector, int arg);

  /// Write a value to game memory.
  void writeMemory(int addr, int value, {int size = 1});

  /// Read a value from game memory.
  int readMemory(int addr, {int size = 1});

  /// Configure memory access callbacks.
  void setMemoryAccess({
    required void Function(int addr, int value, {int size}) write,
    required int Function(int addr, {int size}) read,
    void Function(int addr, Uint8List block)? writeBlock,
    Uint8List Function(int addr, int len)? readBlock,
  });

  /// Write a block of memory.
  void writeMemoryBlock(int addr, Uint8List block);

  /// Read a block of memory.
  Uint8List readMemoryBlock(int addr, int len);

  /// Configure VM state callbacks.
  void setVMState({int Function()? getHeapStart});

  /// Push a 32-bit value onto the VM stack.
  void pushToStack(int value);

  /// Pop a 32-bit value from the VM stack.
  int popFromStack();

  /// Configure stack access callbacks.
  void setStackAccess({
    required void Function(int value) push,
    required int Function() pop,
  });

  /// Render the Glk screen immediately.
  void renderScreen();

  /// Show an exit message and wait for user input.
  Future<void> showExitAndWait(String message);
}
