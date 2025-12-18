import 'dart:typed_data';

import 'package:zart/src/glulx/glulx_exception.dart';
import 'package:zart/src/glulx/glulx_locals_descriptor.dart';

/// The Glulx stack.
class GlulxStack {
  final Uint8List _data;
  late final ByteData _view;

  /// The stack pointer.
  int _sp = 0;

  /// The call-frame pointer.
  int _fp = 0;

  /// Creates a new Glulx stack of the given size.
  GlulxStack(int size) : _data = Uint8List(size) {
    if (size % 256 != 0) {
      throw GlulxException('Stack size must be a multiple of 256 (Spec Line 64)');
    }
    _view = ByteData.view(_data.buffer);
  }

  /// The stack pointer.
  int get sp => _sp;

  /// The call-frame pointer.
  int get fp => _fp;

  /// The maximum size of the stack.
  int get maxSize => _data.length;

  /// Pushes a 32-bit value onto the stack.
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
  int pop32() {
    final limit = _fp + frameLen;
    if (_sp <= limit) {
      throw GlulxException('Illegal pop beyond frame boundary (Spec Line 89)');
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

  /// Peeks at the 32-bit value at the given offset from the stack pointer.
  int peek32(int offset) {
    final addr = _sp - 4 - offset;
    if (addr < 0 || addr > maxSize - 4) {
      throw GlulxException('Invalid stack access');
    }
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
  void pushCallStub(int destType, int destAddr, int pc, int fp) {
    _rawPush32(destType);
    _rawPush32(destAddr);
    _rawPush32(pc);
    _rawPush32(fp);
  }

  /// Pops a call stub from the stack.
  /// Returns a list of [destType, destAddr, pc, fp].
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
  void pushFrame(Uint8List format) {
    final descriptor = GlulxLocalsDescriptor.parse(format);

    // LocalsPos = 8 (FrameLen, LocalsPos) + format.length
    // Terminated by (0,0) and padded to 4-byte boundary.
    final localsPosValue = (8 + format.length + 3) & ~3;
    final frameLenValue = localsPosValue + descriptor.totalSizeWithPadding;

    if (_sp + frameLenValue > maxSize) {
      throw GlulxException('Stack overflow during frame construction');
    }

    final newFp = _sp;

    // Write header
    _view.setUint32(newFp, frameLenValue, Endian.big);
    _view.setUint32(newFp + 4, localsPosValue, Endian.big);

    // Write format descriptor
    for (int i = 0; i < format.length; i++) {
      _data[newFp + 8 + i] = format[i];
    }

    // Fill padding and locals with zero
    _data.fillRange(newFp + 8 + format.length, newFp + frameLenValue, 0);

    _fp = newFp;
    _sp = _fp + frameLenValue;
  }

  /// Pops the current call frame from the stack and restores the previous state.
  ///
  /// Returns the call stub [destType, destAddr, pc, oldFp].
  List<int> popFrame() {
    _sp = _fp;
    final stub = popCallStub();
    _fp = stub[3];
    return stub;
  }

  /// Stores a result value according to a call stub's destination.
  ///
  /// [type] and [addr] are the DestType and DestAddr from the call stub.
  /// [onMemoryWrite] is called if the result should be stored in main memory (Type 1).
  void storeResult(int value, int type, int addr, {void Function(int addr, int val)? onMemoryWrite}) {
    switch (type) {
      case 0: // Do not store. The result value is discarded. (Spec Line 125)
        break;
      case 1: // Store in main memory. (Spec Line 126)
        onMemoryWrite?.call(addr, value);
        break;
      case 2: // Store in local variable. (Spec Line 127)
        writeLocal32(addr, value);
        break;
      case 3: // Push on stack. (Spec Line 129)
        push32(value);
        break;
      case 10: // Resume printing a compressed string. (Spec Line 133)
      case 11: // Resume executing function code after a string completes. (Spec Line 135)
      case 12: // Resume printing a signed decimal integer. (Spec Line 137)
      case 13: // Resume printing a C-style string. (Spec Line 140)
      case 14: // Resume printing a Unicode string. (Spec Line 141)
        // For all string-decoding types, the function's return value is discarded. (Spec Line 166)
        break;
      default:
        throw GlulxException('Unknown or reserved DestType: $type (Spec Lines 123-145)');
    }
  }

  /// Sets a function argument in the current call frame.
  ///
  /// [index] is the zero-based index of the local variable.
  /// [value] is the 32-bit value to store (truncated to the local's size).
  void setArgument(int index, int value) {
    // Re-parse the format descriptor from the stack to find the local's info.
    final localsPosValue = localsPos;
    if (localsPosValue == 0) return;

    final formatLen = localsPosValue - 8;
    final format = _data.sublist(_fp + 8, _fp + 8 + formatLen);
    final descriptor = GlulxLocalsDescriptor.parse(format);

    if (index < 0 || index >= descriptor.locals.length) {
      throw GlulxException('Local variable index out of range: $index');
    }

    final info = descriptor.locals[index];
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
    final addr = _fp + localsPos + offset;
    return _data[addr];
  }

  /// Write an 8-bit local at the given offset.
  void writeLocal8(int offset, int value) {
    final addr = _fp + localsPos + offset;
    _data[addr] = value & 0xFF;
  }

  /// Read a 16-bit local at the given offset.
  int readLocal16(int offset) {
    final addr = _fp + localsPos + offset;
    return _view.getUint16(addr, Endian.big);
  }

  /// Write a 16-bit local at the given offset.
  void writeLocal16(int offset, int value) {
    final addr = _fp + localsPos + offset;
    _view.setUint16(addr, value & 0xFFFF, Endian.big);
  }

  /// Read a 32-bit local at the given offset.
  int readLocal32(int offset) {
    final addr = _fp + localsPos + offset;
    return _view.getUint32(addr, Endian.big);
  }

  /// Write a 32-bit local at the given offset.
  void writeLocal32(int offset, int value) {
    final addr = _fp + localsPos + offset;
    _view.setUint32(addr, value & 0xFFFFFFFF, Endian.big);
  }

  /// Returns the number of 32-bit values above the current frame.
  int get stkCount {
    return (_sp - (_fp + frameLen)) ~/ 4;
  }

  /// Swaps the top two 32-bit values on the stack.
  void stkSwap() {
    if (stkCount < 2) {
      throw GlulxException('Stack underflow in stkswap');
    }
    final v1 = pop32();
    final v2 = pop32();
    push32(v1);
    push32(v2);
  }

  /// Rolls the top [count] values by [shift] positions.
  void stkRoll(int count, int shift) {
    if (count < 0) return;
    if (stkCount < count) {
      throw GlulxException('Stack underflow in stkroll');
    }
    if (count <= 1) return;

    shift %= count;
    if (shift == 0) return;

    final values = List<int>.generate(count, (_) => pop32()).reversed.toList();
    final shifted = List<int>.filled(count, 0);

    for (var i = 0; i < count; i++) {
      shifted[(i + shift) % count] = values[i];
    }

    for (final v in shifted) {
      push32(v);
    }
  }

  /// Copies the top [count] values and pushes them.
  void stkCopy(int count) {
    if (count < 0) return;
    if (stkCount < count) {
      throw GlulxException('Stack underflow in stkcopy');
    }
    final values = List<int>.generate(count, (i) => peek32(i * 4)).reversed.toList();
    for (final v in values) {
      push32(v);
    }
  }
}
