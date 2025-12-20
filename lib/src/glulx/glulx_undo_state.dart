import 'dart:typed_data';

/// Represents a saved undo state for the Glulx interpreter.
/// Spec Section 2.4.10: "saveundo S1" / "restoreundo S1"
/// Reference: serial.c perform_saveundo/perform_restoreundo
///
/// The undo state captures:
/// - RAM memory (from ramStart to current memorySize, XOR'd with original for compression)
/// - Stack data (complete call frames and value stack)
/// - Program counter
class GlulxUndoState {
  /// The RAM state (XOR'd with original game file for compression).
  /// Reference: serial.c write_memstate
  final Uint8List ramState;

  /// The current memory size at time of save.
  final int memorySize;

  /// The stack data at time of save.
  final Uint8List stackData;

  /// The stack pointer at time of save.
  final int stackPointer;

  /// The program counter at time of save (points to instruction after saveundo).
  final int pc;

  /// The destination where the result should be stored on restore.
  /// This is needed because restoreundo must store -1 at the original
  /// saveundo's destination operand.
  final int destType;
  final int destAddr;

  GlulxUndoState({
    required this.ramState,
    required this.memorySize,
    required this.stackData,
    required this.stackPointer,
    required this.pc,
    required this.destType,
    required this.destAddr,
  });
}
