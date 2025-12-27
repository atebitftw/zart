/// Defines the Gestalt selectors for the Glulx VM capabilities.
/// These match the values defined in the Glulx specification.
class GlulxGestaltSelectors {
  /// Glulx spec version (e.g. 0x00030103).
  static const int glulxVersion = 0;

  /// Interpreter version (e.g. 0x00000100).
  static const int terpVersion = 1;

  /// Support for memory resizing opcodes (setmemsize).
  static const int resizeMem = 2;

  /// Support for undo/redo opcodes (saveundo, restoreundo).
  static const int undo = 3;

  /// Support for specific I/O systems (null, filter, glk).
  static const int ioSystem = 4;

  /// Support for Unicode characters and strings.
  static const int unicode = 5;

  /// Support for memory copy/zero opcodes (mcopy, mzero).
  static const int memCopy = 6;

  /// Support for dynamic memory allocation opcodes (malloc, mfree).
  static const int mAlloc = 7;

  /// Address of the start of the heap (if active).
  static const int mAllocHeap = 8;

  /// Support for accelerated function calls (accelfunc, accelparam).
  static const int acceleration = 9;

  /// Support for specific accelerated functions.
  static const int accelFunc = 10;

  /// Support for floating-point opcodes.
  static const int float = 11;

  /// Support for extended undo opcodes (hasundo, discardundo).
  static const int extUndo = 12;

  /// Support for double-precision floating-point opcodes.
  static const int doubleValue = 13;
}
