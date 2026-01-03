import 't3_value.dart';

/// T3 VM machine registers.
///
/// The T3 VM has several "registers" which control the state of the machine.
/// See spec section "Machine Registers" for details.
class T3Registers {
  /// Data Register 0 (R0).
  ///
  /// Used for temporary storage of data values. The RETVAL instruction
  /// stores the return value of a function in this register.
  T3Value r0 = T3Value.nil();

  /// Instruction Pointer (IP).
  ///
  /// Points to the next byte of byte-code to be interpreted.
  /// This is an offset into the code pool.
  int ip = 0;

  /// Entry Pointer (EP).
  ///
  /// Points to the entry point of the current function.
  /// Used to calculate offsets for exception tables and debug tables.
  int ep = 0;

  /// Current Savepoint.
  ///
  /// Used for undo operations. Identifies the current undo savepoint.
  int currentSavepoint = 0;

  /// Savepoint Count.
  ///
  /// Used for undo operations. Tracks the number of savepoints.
  int savepointCount = 0;

  /// Resets all registers to initial state.
  void reset() {
    r0 = T3Value.nil();
    ip = 0;
    ep = 0;
    currentSavepoint = 0;
    savepointCount = 0;
  }

  /// Saves the current register state.
  T3RegisterSnapshot save() {
    return T3RegisterSnapshot(
      r0: r0.copy(),
      ip: ip,
      ep: ep,
      currentSavepoint: currentSavepoint,
      savepointCount: savepointCount,
    );
  }

  /// Restores register state from a snapshot.
  void restore(T3RegisterSnapshot snapshot) {
    r0 = snapshot.r0.copy();
    ip = snapshot.ip;
    ep = snapshot.ep;
    currentSavepoint = snapshot.currentSavepoint;
    savepointCount = snapshot.savepointCount;
  }

  @override
  String toString() {
    return 'T3Registers(r0: $r0, ip: 0x${ip.toRadixString(16)}, '
        'ep: 0x${ep.toRadixString(16)}, savepoint: $currentSavepoint/$savepointCount)';
  }
}

/// Immutable snapshot of register state for save/restore.
class T3RegisterSnapshot {
  final T3Value r0;
  final int ip;
  final int ep;
  final int currentSavepoint;
  final int savepointCount;

  const T3RegisterSnapshot({
    required this.r0,
    required this.ip,
    required this.ep,
    required this.currentSavepoint,
    required this.savepointCount,
  });
}
