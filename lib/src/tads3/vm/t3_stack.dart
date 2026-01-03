import 't3_value.dart';

/// T3 VM stack implementation.
///
/// The T3 VM is stack-based: most operations are performed through the stack.
/// This class manages the value stack and activation frames per the spec
/// section "Stack Organization".
///
/// Stack frame layout (from FP upward for locals, downward for arguments):
/// ```
/// FP+n    : Local variable n-1
/// FP+1    : Local variable 0
/// FP      : Enclosing frame pointer
/// FP-1    : Argument count
/// FP-2    : Entry pointer (EP)
/// FP-3    : Return address
/// FP-4    : Frame reference slot (nil initially)
/// FP-5    : Invokee (function pointer, AnonFunc, etc.)
/// FP-6    : Self object
/// FP-7    : Defining object
/// FP-8    : Target object
/// FP-9    : Target property
/// FP-10   : Arg 0 (first argument)
/// FP-11   : Arg 1 (second argument)
/// ...
/// ```
class T3Stack {
  /// The stack storage.
  final List<T3Value> _stack;

  /// Maximum stack depth.
  final int _maxDepth;

  /// Reserved stack depth (extra space for overflow handling).
  final int _reserveDepth;

  /// Stack pointer - index of next free slot.
  int _sp = 0;

  /// Frame pointer - index of current activation frame base.
  int _fp = 0;

  /// Creates a new T3 stack with the specified max depth.
  T3Stack({int maxDepth = 65536, int reserveDepth = 256})
    : _maxDepth = maxDepth,
      _reserveDepth = reserveDepth,
      _stack = List<T3Value>.filled(maxDepth + reserveDepth, T3Value.nil());

  // ==================== Stack Pointer Access ====================

  /// Gets the current stack pointer.
  int get sp => _sp;

  /// Sets the stack pointer (for restore operations).
  set sp(int value) => _sp = value;

  /// Gets the current frame pointer.
  int get fp => _fp;

  /// Sets the frame pointer (for restore operations).
  set fp(int value) => _fp = value;

  /// Gets the current stack depth (number of active elements).
  int get depth => _sp;

  // ==================== Basic Stack Operations ====================

  /// Pushes a value onto the stack.
  void push(T3Value value) {
    assert(_sp < _stack.length, 'Stack overflow');
    _stack[_sp++] = value.copy();
  }

  /// Pops a value from the stack.
  T3Value pop() {
    assert(_sp > 0, 'Stack underflow');
    return _stack[--_sp];
  }

  /// Peeks at the top of the stack without removing.
  T3Value peek() {
    assert(_sp > 0, 'Stack underflow');
    return _stack[_sp - 1];
  }

  /// Gets a value by index from top (0 = top of stack).
  T3Value get(int indexFromTop) {
    assert(indexFromTop >= 0 && indexFromTop < _sp, 'Invalid stack index');
    return _stack[_sp - 1 - indexFromTop];
  }

  /// Sets a value by index from top (0 = top of stack).
  void set(int indexFromTop, T3Value value) {
    assert(indexFromTop >= 0 && indexFromTop < _sp, 'Invalid stack index');
    _stack[_sp - 1 - indexFromTop] = value.copy();
  }

  /// Discards the top n elements from the stack.
  void discard([int count = 1]) {
    assert(_sp >= count, 'Stack underflow');
    _sp -= count;
  }

  /// Checks if there's space for n more elements.
  bool checkSpace(int count) {
    return (_sp + count) <= _maxDepth;
  }

  // ==================== Frame Pointer Operations ====================

  /// Frame header offsets (relative to FP, negative = before FP).
  static const int fpOfsTargetProp = -9;
  static const int fpOfsTargetObj = -8;
  static const int fpOfsDefObj = -7;
  static const int fpOfsSelf = -6;
  static const int fpOfsInvokee = -5;
  static const int fpOfsFrameRef = -4;
  static const int fpOfsReturnAddr = -3;
  static const int fpOfsEntryPtr = -2;
  static const int fpOfsArgCount = -1;
  // FP itself contains the enclosing frame pointer

  /// Gets a value relative to the frame pointer.
  T3Value getFromFrame(int offset) {
    final index = _fp + offset;
    assert(index >= 0 && index < _sp, 'Invalid frame offset');
    return _stack[index];
  }

  /// Sets a value relative to the frame pointer.
  void setAtFrame(int offset, T3Value value) {
    final index = _fp + offset;
    assert(index >= 0 && index < _sp, 'Invalid frame offset');
    _stack[index] = value.copy();
  }

  // ==================== Local Variable Access ====================

  /// Gets a local variable by index.
  /// Locals are at FP+1, FP+2, etc.
  T3Value getLocal(int index) {
    return _stack[_fp + 1 + index];
  }

  /// Sets a local variable by index.
  void setLocal(int index, T3Value value) {
    _stack[_fp + 1 + index] = value.copy();
  }

  // ==================== Argument Access ====================

  /// Gets the argument count for the current frame.
  int getArgCount() {
    return getFromFrame(fpOfsArgCount).value;
  }

  /// Gets an argument by index.
  /// Arg 0 is at FP-10, Arg 1 at FP-11, etc.
  T3Value getArg(int index) {
    return _stack[_fp + fpOfsTargetProp - 1 - index];
  }

  /// Sets an argument by index.
  void setArg(int index, T3Value value) {
    _stack[_fp + fpOfsTargetProp - 1 - index] = value.copy();
  }

  // ==================== Self and Target Access ====================

  /// Gets the 'self' object for the current frame.
  T3Value getSelf() => getFromFrame(fpOfsSelf);

  /// Gets the target object for the current frame.
  T3Value getTargetObject() => getFromFrame(fpOfsTargetObj);

  /// Gets the defining object for the current frame.
  T3Value getDefiningObject() => getFromFrame(fpOfsDefObj);

  /// Gets the target property for the current frame.
  T3Value getTargetProp() => getFromFrame(fpOfsTargetProp);

  /// Gets the invokee for the current frame.
  T3Value getInvokee() => getFromFrame(fpOfsInvokee);

  // ==================== Frame Management ====================

  /// Pushes a new activation frame.
  ///
  /// This sets up a new stack frame for a function/method call.
  /// Arguments should already be pushed before calling this.
  ///
  /// Returns the new frame pointer.
  int pushFrame({
    required int argCount,
    required int localCount,
    required int returnAddr,
    required int entryPtr,
    required T3Value self,
    required T3Value targetObj,
    required T3Value definingObj,
    required int targetProp,
    required T3Value invokee,
  }) {
    // Push frame header (in order, so first pushed is at lowest address)
    push(T3Value.fromProp(targetProp)); // FP-9
    push(targetObj); // FP-8
    push(definingObj); // FP-7
    push(self); // FP-6
    push(invokee); // FP-5
    push(T3Value.nil()); // FP-4: frame reference (nil initially)
    push(T3Value.fromCodeOffset(returnAddr)); // FP-3
    push(T3Value.fromCodeOffset(entryPtr)); // FP-2
    push(T3Value.fromInt(argCount)); // FP-1

    // Save old FP and set new FP
    final oldFp = _fp;
    push(T3Value.fromInt(oldFp)); // FP: enclosing frame pointer
    _fp = _sp - 1;

    // Allocate space for locals (initialized to nil)
    for (var i = 0; i < localCount; i++) {
      push(T3Value.nil());
    }

    return _fp;
  }

  /// Pops the current activation frame.
  ///
  /// Returns the (returnAddr, oldFp) for continuing execution.
  (int returnAddr, int oldFp) popFrame() {
    // Get return info from frame header
    final returnAddr = getFromFrame(fpOfsReturnAddr).value;
    final oldFp = getFromFrame(0).value; // FP contains old FP
    final argCount = getArgCount();

    // Restore SP to before frame header + args
    // Frame header is 10 slots, args are below that
    _sp = _fp + fpOfsTargetProp - argCount;

    // Restore old FP
    _fp = oldFp;

    return (returnAddr, oldFp);
  }

  /// Gets the return address for the current frame.
  int getReturnAddress() => getFromFrame(fpOfsReturnAddr).value;

  /// Gets the entry pointer for the current frame.
  int getEntryPointer() => getFromFrame(fpOfsEntryPtr).value;

  // ==================== Stack Walking ====================

  /// Walks the stack frames, calling visitor for each.
  /// Visitor receives (framePointer, depth) and returns true to continue.
  void walkFrames(bool Function(int fp, int depth) visitor) {
    var currentFp = _fp;
    var depth = 0;

    while (currentFp > 0) {
      if (!visitor(currentFp, depth)) break;

      // Get enclosing frame pointer
      final enclosingFp = _stack[currentFp].value;
      if (enclosingFp <= 0 || enclosingFp >= currentFp) break;

      currentFp = enclosingFp;
      depth++;
    }
  }

  // ==================== Utility ====================

  /// Converts stack index to/from pointer values for save/restore.
  int ptrToIndex(int ptr) => ptr + 1; // 0 = null, 1 = index 0
  int indexToPtr(int idx) => idx > 0 ? idx - 1 : 0;

  /// Clears the stack (for restart).
  void clear() {
    _sp = 0;
    _fp = 0;
  }

  @override
  String toString() => 'T3Stack(sp: $_sp, fp: $_fp, depth: $depth)';

  /// Debug: dumps the top n elements of the stack.
  String dumpTop([int count = 10]) {
    final buf = StringBuffer('Stack top (sp=$_sp, fp=$_fp):\n');
    final start = _sp - 1;
    final end = (_sp - count).clamp(0, _sp);

    for (var i = start; i >= end; i--) {
      final marker = i == _fp ? ' <-- FP' : '';
      buf.writeln('  [$i] ${_stack[i]}$marker');
    }

    return buf.toString();
  }
}
