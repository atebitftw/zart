import 'package:zart/src/tads3/vm/t3_interpreter.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';

/// State management built-in functions for TADS 3.
/// Includes: savepoint, undo, save, restore, restart
class T3BuiltinState {
  /// savepoint() - Create an undo savepoint.
  /// Ref: vmbiftad.cpp line 2835
  static void savepoint(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    interp.undoManager.savepoint();
    interp.registers.r0 = T3Value.nil();
  }

  /// undo() - Undo changes back to last savepoint.
  /// Ref: vmbiftad.cpp line 2847
  /// Returns nil if no undo available, true if undo successful.
  static void undo(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    final success = interp.undoManager.undo(interp);
    interp.registers.r0 = success ? T3Value.true_() : T3Value.nil();
  }

  /// save(filename) - Save game state to file.
  /// Ref: vmbiftad.cpp line 2872
  /// Currently a stub.
  static void saveGame(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    // TODO: Implement save
    interp.registers.r0 = T3Value.nil();
  }

  /// restore(filename) - Restore game state from file.
  /// Ref: vmbiftad.cpp line 2962
  /// Currently a stub.
  static void restoreGame(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    // TODO: Implement restore
    interp.registers.r0 = T3Value.nil();
  }

  /// restart() - Restart game from beginning.
  /// Ref: vmbiftad.cpp line 3017
  /// Currently a stub.
  static void restart(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    // TODO: Implement restart
    interp.registers.r0 = T3Value.nil();
  }
}
