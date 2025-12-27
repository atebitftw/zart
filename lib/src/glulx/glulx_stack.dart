import 'dart:typed_data';

import 'package:zart/src/glulx/glulx_exception.dart';
import 'package:zart/src/glulx/glulx_locals_descriptor.dart';

/// The Glulx stack.
///
/// Spec: "The stack consists of a set of call frames, one for each function
/// in the current chain. When a function is called, a new stack frame is
/// pushed, containing the function's local variables. The function can then
/// push or pull 32-bit values on top of that, to store intermediate computations."
///
/// Spec: "The stack pointer starts at zero, and the stack grows upward.
/// The maximum size of the stack is determined by a constant value in the
/// game-file header. For convenience, this must be a multiple of 256."
class GlulxStack {
  final Uint8List _data;
  late final ByteData _view;

  /// The stack pointer.
  /// Spec: "The stack pointer counts in bytes."
  int _sp = 0;

  /// The call-frame pointer.
  /// Spec: "FramePtr is the current value of FramePtr – the stack position
  /// of the call frame of the function."
  int _fp = 0;

  /// The base of the value stack within the current frame.
  int _valstackbase = 0;

  /// The base of locals within the current frame.
  int _localsbase = 0;

  /// Creates a new Glulx stack of the given size.
  ///
  /// Spec: "The maximum size of the stack is determined by a constant value
  /// in the game-file header. For convenience, this must be a multiple of 256."
  GlulxStack(int size) : _data = Uint8List(size) {
    if (size % 256 != 0) {
      throw GlulxException('Stack size must be a multiple of 256');
    }
    _view = ByteData.view(_data.buffer);
  }

  /// The stack pointer.
  int get sp => _sp;

  /// The call-frame pointer.
  int get fp => _fp;

  /// The maximum size of the stack.
  int get maxSize => _data.length;

  /// The base of the value stack within the current frame.
  int get valstackbase => _valstackbase;

  /// The base of locals within the current frame.
  int get localsbase => _localsbase;

  /// Pushes a 32-bit value onto the stack.
  ///
  /// Spec: "If you push a 32-bit value on the stack, the pointer increases by four."
  void push32(int value) {
    if (_sp + 4 > maxSize) {
      throw GlulxException('Stack overflow');
    }
    _view.setUint32(_sp, value & 0xFFFFFFFF, Endian.big);
    _sp += 4;
  }

  /// Internal raw push, bypassing boundary checks.
  void _rawPush32(int value) {
    if (_sp + 4 > maxSize) {
      throw GlulxException('Stack overflow');
    }
    _view.setUint32(_sp, value & 0xFFFFFFFF, Endian.big);
    _sp += 4;
  }

  /// Pops a 32-bit value from the stack.
  ///
  /// Spec: "It is illegal to pop back beyond the original FramePtr+FrameLen boundary."
  int pop32() {
    // Spec: "It is illegal to pop back beyond the original FramePtr+FrameLen boundary."
    if (_sp < _valstackbase + 4) {
      throw GlulxException('Stack underflow in operand');
    }
    return _rawPop32();
  }

  /// Internal raw pop, bypassing boundary checks.
  int _rawPop32() {
    if (_sp < 4) {
      throw GlulxException('Stack underflow');
    }
    _sp -= 4;
    return _view.getUint32(_sp, Endian.big);
  }

  /// Peeks at the 32-bit value at the given index from the top of the stack.
  ///
  /// [index] is the zero-based index from the top (0 = top element).
  /// Spec: "Peek at the Lth value on the stack, without actually popping anything."
  int peek32(int index) {
    final offset = index * 4;
    if (offset < 0 || offset >= (_sp - _valstackbase)) {
      throw GlulxException('Stkpeek outside current stack range');
    }
    final addr = _sp - (offset + 4);
    return _view.getUint32(addr, Endian.big);
  }

  /// Sets the stack pointer.
  set sp(int value) {
    if (value < 0 || value > maxSize) {
      throw GlulxException('Invalid stack pointer');
    }
    _sp = value;
  }

  /// Sets the frame pointer.
  set fp(int value) {
    if (value < 0 || value > maxSize) {
      throw GlulxException('Invalid frame pointer');
    }
    _fp = value;
  }

  /// Pushes a call stub onto the stack.
  ///
  /// Spec: "The values are pushed on the stack in the following order
  /// (FramePtr pushed last): DestType, DestAddr, PC, FramePtr"
  void pushCallStub(int destType, int destAddr, int pc, int fp) {
    _rawPush32(destType);
    _rawPush32(destAddr);
    _rawPush32(pc);
    _rawPush32(fp);
  }

  /// Pops a call stub from the stack.
  ///
  /// Returns a list of [destType, destAddr, pc, fp].
  /// Also recomputes valstackbase and localsbase from the restored frame.
  List<int> popCallStub() {
    final oldFp = _rawPop32();
    final oldPc = _rawPop32();
    final oldDestAddr = _rawPop32();
    final oldDestType = _rawPop32();
    return [oldDestType, oldDestAddr, oldPc, oldFp];
  }

  /// Pushes a new call frame onto the stack.
  ///
  /// [format] is the "Format of Locals" descriptor from the function header.
  ///
  /// Spec: "A call frame looks like this: FrameLen (4 bytes), LocalsPos (4 bytes),
  /// Format of Locals (2*n bytes), Padding (0 or 2 bytes), Locals, Padding, Values"
  void pushFrame(Uint8List format) {
    final descriptor = GlulxLocalsDescriptor.parse(format);

    // LocalsPos = 8 (FrameLen, LocalsPos) + format.length
    // Terminated by (0,0) and padded to 4-byte boundary.
    final localsPosValue = (8 + format.length + 3) & ~3;
    final frameLenValue = localsPosValue + descriptor.totalSizeWithPadding;

    if (_sp + frameLenValue > maxSize) {
      throw GlulxException('Stack overflow in function call');
    }

    final newFp = _sp;

    // Write header
    // Spec: "FrameLen: The distance from FramePtr to (FramePtr+FrameLen), in bytes."
    _view.setUint32(newFp, frameLenValue, Endian.big);
    // Spec: "LocalsPos: The distance from FramePtr to the locals segment."
    _view.setUint32(newFp + 4, localsPosValue, Endian.big);

    // Write format descriptor
    for (int i = 0; i < format.length; i++) {
      _data[newFp + 8 + i] = format[i];
    }

    // Fill padding and locals with zero
    // Spec: "The locals are zero when the function starts executing."
    _data.fillRange(newFp + 8 + format.length, newFp + frameLenValue, 0);

    _fp = newFp;
    // Update cached bases
    _localsbase = _fp + localsPosValue;
    _valstackbase = _fp + frameLenValue;
    _sp = _valstackbase;
  }

  /// Pops the current call frame from the stack and restores the previous state.
  ///
  /// Returns the call stub [destType, destAddr, pc, oldFp].
  List<int> popFrame() {
    _sp = _fp;
    final stub = popCallStub();
    _fp = stub[3];
    // Recompute valstackbase and localsbase from restored frame
    _updateCachedBases();
    return stub;
  }

  /// Leaves the current function by setting SP = FP.
  void leaveFunction() {
    _sp = _fp;
  }

  /// Restores the frame pointer and updates cached bases.
  /// Called after popping a call stub during return.
  void restoreFp(int oldFp) {
    _fp = oldFp;
    _updateCachedBases();
  }

  /// Updates the cached _valstackbase and _localsbase from the current frame.
  void _updateCachedBases() {
    if (_fp >= 0 && _fp <= maxSize - 8) {
      final frameLenValue = _view.getUint32(_fp, Endian.big);
      final localsPosValue = _view.getUint32(_fp + 4, Endian.big);
      _valstackbase = _fp + frameLenValue;
      _localsbase = _fp + localsPosValue;
    } else {
      _valstackbase = 0;
      _localsbase = 0;
    }
  }

  /// Stores a result value according to a call stub's destination.
  ///
  /// [type] and [addr] are the DestType and DestAddr from the call stub.
  /// [onMemoryWrite] is called if the result should be stored in main memory (Type 1).
  ///
  /// Spec: "DestType and DestAddr describe a location in which to store a result."
  void storeResult(
    int value,
    int type,
    int addr, {
    void Function(int addr, int val)? onMemoryWrite,
    void Function(int addr, int type)? onResumeString,
    void Function(int val, int charnum)? onResumeNum,
  }) {
    switch (type) {
      case 0:
        // Spec: "Do not store. The result value is discarded. DestAddr should be zero."
        break;
      case 1:
        // Spec: "Store in main memory. The result value is stored in the
        // main-memory address given by DestAddr."
        onMemoryWrite?.call(addr, value);
        break;
      case 2:
        // Spec: "Store in a call-frame local. The result value is stored in the
        // call-frame local whose address is given by DestAddr."
        writeLocal32(addr, value);
        break;
      case 3:
        // Spec: "Push on stack. The result value is pushed on the stack.
        // DestAddr should be zero."
        push32(value);
        break;
      case 0x10:
        // Spec: "Resume printing a compressed (E1) string."
        onResumeString?.call(addr, 0xE1);
        break;
      case 0x11:
        // Spec: "Resume executing function code after a string completes."
        throw GlulxException('String-terminator call stub at end of function call');
      case 0x12:
        // Spec: "Resume printing a signed decimal integer."
        onResumeNum?.call(addr, value);
        break;
      case 0x13:
        // Spec: "Resume printing a C-style (E0) string."
        onResumeString?.call(addr, 0xE0);
        break;
      case 0x14:
        // Spec: "Resume printing a Unicode (E2) string."
        onResumeString?.call(addr, 0xE2);
        break;
      default:
        throw GlulxException('Unknown or reserved DestType: $type');
    }
  }

  /// Sets function arguments in the current call frame.
  ///
  /// [args] is the list of argument values.
  /// [locals] is the list of local variable descriptors for the function.
  ///
  /// Spec Section 2.4.2: "If there are more arguments than locals, the extras are silently dropped."
  void setArguments(List<int> args, List<LocalInfo> locals) {
    final count = args.length < locals.length ? args.length : locals.length;
    for (var i = 0; i < count; i++) {
      final info = locals[i];
      final value = args[i];
      switch (info.type) {
        case 1:
          writeLocal8(info.offset, value);
          break;
        case 2:
          writeLocal16(info.offset, value);
          break;
        case 4:
          writeLocal32(info.offset, value);
          break;
      }
    }
  }

  /// Reads the 4-byte locals position for the current frame.
  int get localsPos {
    if (_fp < 0 || _fp > maxSize - 8) return 0;
    return _view.getUint32(_fp + 4, Endian.big);
  }

  /// Reads the 4-byte frame length for the current frame.
  int get frameLen {
    if (_fp < 0 || _fp > maxSize - 4) return 0;
    return _view.getUint32(_fp, Endian.big);
  }

  /// Read an 8-bit local at the given offset.
  int readLocal8(int offset) {
    final addr = _localsbase + offset;
    return _data[addr];
  }

  /// Write an 8-bit local at the given offset.
  void writeLocal8(int offset, int value) {
    final addr = _localsbase + offset;
    _data[addr] = value & 0xFF;
  }

  /// Read a 16-bit local at the given offset.
  int readLocal16(int offset) {
    final addr = _localsbase + offset;
    return _view.getUint16(addr, Endian.big);
  }

  /// Write a 16-bit local at the given offset.
  void writeLocal16(int offset, int value) {
    final addr = _localsbase + offset;
    _view.setUint16(addr, value & 0xFFFF, Endian.big);
  }

  /// Read a 32-bit local at the given offset.
  int readLocal32(int offset) {
    final addr = _localsbase + offset;
    return _view.getUint32(addr, Endian.big);
  }

  /// Write a 32-bit local at the given offset.
  void writeLocal32(int offset, int value) {
    final addr = _localsbase + offset;
    _view.setUint32(addr, value & 0xFFFFFFFF, Endian.big);
  }

  /// Returns the number of 32-bit values above the current frame.
  ///
  /// Spec: "Store a count of the number of values on the stack.
  /// This counts only values above the current call-frame."
  int get stkCount {
    return (_sp - _valstackbase) ~/ 4;
  }

  /// Swaps the top two 32-bit values on the stack.
  ///
  /// Spec: "Swap the top two values on the stack.
  /// The current stack-count must be at least two."
  void stkSwap() {
    if (_sp < _valstackbase + 8) {
      throw GlulxException('Stack underflow in stkswap');
    }
    final v1 = pop32();
    final v2 = pop32();
    push32(v1);
    push32(v2);
  }

  /// Rolls the top [count] values by [shift] positions.
  ///
  /// Spec: "Rotate the top L1 values on the stack. They are rotated up or down
  /// L2 places, with positive values meaning up and negative meaning down."
  void stkRoll(int count, int shift) {
    if (count < 0) {
      throw GlulxException('Negative operand in stkroll');
    }
    if (count == 0) return;

    // Bounds check
    if (stkCount < count) {
      throw GlulxException('Stack underflow in stkroll');
    }
    if (count <= 1) return;

    // Normalize shift
    // Convert positive shift to equivalent negative for easier implementation
    if (shift > 0) {
      shift = shift % count;
      shift = count - shift;
    } else {
      shift = (-shift) % count;
    }
    if (shift == 0) return;

    // "Since the values are being moved into space above the current stack,
    // we must check for overflow."
    if (_sp + shift * 4 > maxSize) {
      throw GlulxException('Stack overflow in stkroll');
    }

    final baseAddr = _sp - count * 4;

    // Copy the first 'shift' values to temp space above current stack
    for (var i = 0; i < shift; i++) {
      final value = _view.getUint32(baseAddr + i * 4, Endian.big);
      _view.setUint32(_sp + i * 4, value, Endian.big);
    }

    // Shift remaining values down
    for (var i = 0; i < count; i++) {
      final value = _view.getUint32(baseAddr + (shift + i) * 4, Endian.big);
      _view.setUint32(baseAddr + i * 4, value, Endian.big);
    }
  }

  /// Copies the top [count] values and pushes them.
  ///
  /// Spec: "Peek at the top L1 values in the stack, and push duplicates onto
  /// the stack in the same order."
  void stkCopy(int count) {
    if (count < 0) {
      throw GlulxException('Negative operand in stkcopy');
    }
    if (count == 0) return;

    // Bounds check
    if (stkCount < count) {
      throw GlulxException('Stack underflow in stkcopy');
    }
    // Overflow check
    if (_sp + count * 4 > maxSize) {
      throw GlulxException('Stack overflow in stkcopy');
    }

    final baseAddr = _sp - count * 4;
    for (var i = 0; i < count; i++) {
      final value = _view.getUint32(baseAddr + i * 4, Endian.big);
      _view.setUint32(_sp + i * 4, value, Endian.big);
    }
    _sp += count * 4;
  }

  /// Provides read access to the raw stack data for serialization.
  Uint8List get rawData => _data;

  /// Resets the stack to initial state.
  void reset() {
    _sp = 0;
    _fp = 0;
    _valstackbase = 0;
    _localsbase = 0;
  }

  /// Alias for sp, used by undo save/restore.
  int get pointer => _sp;

  /// Restores the stack from saved data.
  void restoreFrom(Uint8List data, int stackPointer, int framePointer) {
    // Copy the saved data into the stack
    _data.setRange(0, data.length, data);
    _sp = stackPointer;
    _fp = framePointer;
    _updateCachedBases();
  }
}
