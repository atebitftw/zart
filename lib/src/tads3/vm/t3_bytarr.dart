// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// TADS3 ByteArray Metaclass
///
/// ByteArray is a simple array of byte values, providing a fast mechanism to
/// store blocks of binary data. Unlike Vector/List, it is not a Collection.
///
/// Ported from vmbytarr.cpp/vmbytarr.h
library;

import 'dart:typed_data';
import 'package:crypto/crypto.dart' show sha256, md5;
import 'package:zart/src/tads3/vm/t3_error.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';
import 'package:zart/src/tads3/vm/t3_string.dart';

// ----------------------------------------------------------------------------
// Integer Format Codes (matching C++ definitions)
// ----------------------------------------------------------------------------

/// Integer size mask
const int fmtSizeMask = 0x000F;

/// 8-bit integer
const int fmtInt8 = 0x0000;

/// 16-bit integer
const int fmtInt16 = 0x0001;

/// 32-bit integer
const int fmtInt32 = 0x0002;

/// Byte order mask
const int fmtOrderMask = 0x00F0;

/// Little-endian byte order
const int fmtLittleEndian = 0x0000;

/// Big-endian byte order
const int fmtBigEndian = 0x0010;

/// Signedness mask
const int fmtSignedMask = 0x0F00;

/// Signed integer
const int fmtSigned = 0x0000;

/// Unsigned integer
const int fmtUnsigned = 0x0100;

// ----------------------------------------------------------------------------
// Property indices (matching C++ function table order)
// ----------------------------------------------------------------------------

const int _propIdxUndef = 0;
const int _propIdxLength = 1;
const int _propIdxSubarray = 2;
const int _propIdxCopyFrom = 3;
const int _propIdxFillVal = 4;
const int _propIdxToString = 5;
const int _propIdxReadInt = 6;
const int _propIdxWriteInt = 7;
const int _propIdxPackBytes = 8;
const int _propIdxUnpackBytes = 9;
const int _propIdxSha256 = 10;
const int _propIdxDigestMD5 = 11;

/// ByteArray object - stores raw binary data as a sequence of bytes.
class T3ObjByteArray extends T3Object {
  /// The raw byte storage
  Uint8List _data;

  /// Create a ByteArray with the specified number of elements.
  T3ObjByteArray(int elementCount) : _data = Uint8List(elementCount);

  /// Create a ByteArray from existing bytes.
  T3ObjByteArray.fromBytes(Uint8List bytes) : _data = Uint8List.fromList(bytes);

  /// Get the number of bytes in the array.
  int get length => _data.length;

  /// Get a byte at the given 1-based index.
  int getElement(int index) {
    if (index < 1 || index > _data.length) {
      throw T3VmException(vmErrIndexOutOfRange);
    }
    return _data[index - 1];
  }

  /// Set a byte at the given 1-based index.
  void setElement(int index, int value) {
    if (index < 1 || index > _data.length) {
      throw T3VmException(vmErrIndexOutOfRange);
    }
    if (value < 0 || value > 255) {
      throw T3VmException(vmErrNumOverflow);
    }
    _data[index - 1] = value;
  }

  @override
  T3Metaclass getMetaclassReg() => T3MetaclassByteArray.instance;

  @override
  void notifyDelete(T3VM vm, bool inRootSet) {
    // Nothing special needed - Dart handles GC
  }

  @override
  bool isInstanceOf(T3VM vm, int obj) {
    // Check if obj is the ByteArray intrinsic class
    return false; // TODO: Implement when intrinsic class system is integrated
  }

  @override
  int getSuperclass(T3VM vm, int self, int index) {
    return invalidObjectId; // TODO: Return intrinsic class when available
  }

  @override
  void setProp(T3VM vm, T3Undo? undo, int self, int propId, T3Value val) {
    throw T3VmException(vmErrInvalidSetprop);
  }

  @override
  bool getProp(T3VM vm, int propId, T3Value retval, int self, List<int> sourceObj, int? argc) {
    // Get the function table index from the property ID
    final funcIdx = vm.metaTable?.propToVectorIdx(getMetaclassReg().getRegIdx(), propId);
    if (funcIdx == null || funcIdx < 0 || funcIdx > _propIdxDigestMD5) {
      return false;
    }

    if (evalProp(vm, funcIdx, retval, self, argc)) {
      sourceObj[0] = getMetaclassReg().getClassObj(vm);
      return true;
    }
    return false;
  }

  /// Evaluate a property method by function index.
  /// Public for testing purposes.
  bool evalProp(T3VM vm, int funcIdx, T3Value retval, int self, int? argc) {
    switch (funcIdx) {
      case _propIdxUndef:
        return false;
      case _propIdxLength:
        return _getpLength(vm, retval, argc);
      case _propIdxSubarray:
        return _getpSubarray(vm, retval, self, argc);
      case _propIdxCopyFrom:
        return _getpCopyFrom(vm, retval, self, argc);
      case _propIdxFillVal:
        return _getpFillVal(vm, retval, self, argc);
      case _propIdxToString:
        return _getpToString(vm, retval, self, argc);
      case _propIdxReadInt:
        return _getpReadInt(vm, retval, argc);
      case _propIdxWriteInt:
        return _getpWriteInt(vm, retval, self, argc);
      case _propIdxPackBytes:
        return _getpPackBytes(vm, retval, self, argc);
      case _propIdxUnpackBytes:
        return _getpUnpackBytes(vm, retval, self, argc);
      case _propIdxSha256:
        return _getpSha256(vm, retval, argc);
      case _propIdxDigestMD5:
        return _getpDigestMD5(vm, retval, argc);
      default:
        return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Property method implementations
  // ---------------------------------------------------------------------------

  /// length() - return the number of bytes
  bool _getpLength(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 0, 0);
    retval.setInt(_data.length);
    return true;
  }

  /// subarray(startIdx, len?) - extract a portion into a new ByteArray
  bool _getpSubarray(T3VM vm, T3Value retval, int self, int? argc) {
    _checkArgs(argc, 1, 2);

    var startIdx = vm.stack.pop().getAsInt();
    var cnt = (argc! >= 2) ? vm.stack.pop().getAsInt() : _data.length;

    // Force startIdx to be in range
    if (startIdx < 1) startIdx = 1;
    if (startIdx > _data.length + 1) startIdx = _data.length + 1;

    // Limit count to available size
    if (startIdx > _data.length) {
      cnt = 0;
    } else if (startIdx + cnt - 1 > _data.length) {
      cnt = _data.length + 1 - startIdx;
    }

    // Create new ByteArray with the subarray
    final newArr = T3ObjByteArray(cnt);
    if (cnt > 0) {
      newArr._data.setRange(0, cnt, _data, startIdx - 1);
    }

    final newId = vm.objTable.allocObj(vm, false);
    vm.objTable.getEntry(newId)!.obj = newArr;
    retval.setObj(newId);
    return true;
  }

  /// copyFrom(src, srcIdx, dstIdx, cnt) - copy from another ByteArray
  bool _getpCopyFrom(T3VM vm, T3Value retval, int self, int? argc) {
    _checkArgs(argc, 4, 4);

    final srcArrId = vm.stack.pop().getAsObj();
    var srcIdx = vm.stack.pop().getAsInt();
    var dstIdx = vm.stack.pop().getAsInt();
    var cnt = vm.stack.pop().getAsInt();

    // Get the source array
    final srcObj = vm.objTable.getObj(srcArrId!);
    if (srcObj is! T3ObjByteArray) {
      throw T3VmException(vmErrBadTypeBif);
    }
    final srcArr = srcObj;

    // Force indices to be in range
    if (srcIdx < 1) srcIdx = 1;
    if (srcIdx > srcArr._data.length + 1) srcIdx = srcArr._data.length + 1;
    if (dstIdx < 1) dstIdx = 1;
    if (dstIdx > _data.length + 1) dstIdx = _data.length + 1;

    // Limit copy to available destination space
    if (dstIdx > _data.length) {
      cnt = 0;
    } else if (dstIdx + cnt - 1 > _data.length) {
      cnt = _data.length + 1 - dstIdx;
    }

    // Copy the bytes
    _copyFrom(dstIdx, srcArr, srcIdx, cnt);

    retval.setObj(self);
    return true;
  }

  /// fillWith(val, startIdx?, cnt?) - fill a range with a byte value
  bool _getpFillVal(T3VM vm, T3Value retval, int self, int? argc) {
    _checkArgs(argc, 1, 3);

    final fillVal = vm.stack.pop().getAsInt();
    if (fillVal < 0 || fillVal > 255) {
      throw T3VmException(vmErrNumOverflow);
    }

    var startIdx = (argc! >= 2) ? vm.stack.pop().getAsInt() : 1;
    var cnt = (argc >= 3) ? vm.stack.pop().getAsInt() : _data.length;

    // Force startIdx to be in range
    if (startIdx < 1) startIdx = 1;
    if (startIdx > _data.length + 1) startIdx = _data.length + 1;

    // Force count to be in range
    if (startIdx > _data.length) {
      cnt = 0;
    } else if (startIdx + cnt - 1 > _data.length) {
      cnt = _data.length + 1 - startIdx;
    }

    // Fill with the value
    _data.fillRange(startIdx - 1, startIdx - 1 + cnt, fillVal);

    retval.setObj(self);
    return true;
  }

  /// mapToString(charset?, startIdx?, len?) - convert to string
  bool _getpToString(T3VM vm, T3Value retval, int self, int? argc) {
    _checkArgs(argc, 0, 3);

    // Skip charset arg if present (not yet supported)
    if (argc! >= 1) vm.stack.pop();

    var startIdx = (argc >= 2) ? vm.stack.pop().getAsInt() : 1;
    var cnt = (argc >= 3) ? vm.stack.pop().getAsInt() : _data.length;

    // Force to be in range
    if (startIdx < 1) startIdx = 1;
    if (startIdx > _data.length + 1) startIdx = _data.length + 1;
    if (startIdx > _data.length) {
      cnt = 0;
    } else if (startIdx + cnt - 1 > _data.length) {
      cnt = _data.length + 1 - startIdx;
    }

    // Convert bytes to string (treating as Latin-1)
    final bytes = _data.sublist(startIdx - 1, startIdx - 1 + cnt);
    final str = String.fromCharCodes(bytes);

    // Create a string object
    final strObj = T3ObjString(str);
    final strId = vm.objTable.allocObj(vm, false);
    vm.objTable.getEntry(strId)!.obj = strObj;
    retval.setObj(strId);
    return true;
  }

  /// readInt(idx, fmt) - read an integer with the specified format
  bool _getpReadInt(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 2, 2);

    final idx = vm.stack.pop().getAsInt();
    final fmt = vm.stack.pop().getAsInt();

    // Determine size from format
    int size;
    switch (fmt & fmtSizeMask) {
      case fmtInt8:
        size = 1;
        break;
      case fmtInt16:
        size = 2;
        break;
      case fmtInt32:
        size = 4;
        break;
      default:
        size = 1;
    }

    // Check range
    if (idx < 1 || idx + size - 1 > _data.length) {
      throw T3VmException(vmErrIndexOutOfRange);
    }

    // Read bytes
    final bytes = _data.sublist(idx - 1, idx - 1 + size);

    // Swap if big-endian
    if ((fmt & fmtOrderMask) == fmtBigEndian) {
      _swapBytes(bytes);
    }

    // Interpret value
    int result;
    switch (size) {
      case 1:
        if ((fmt & fmtSignedMask) == fmtSigned) {
          result = bytes[0] < 128 ? bytes[0] : bytes[0] - 256;
        } else {
          result = bytes[0];
        }
        break;
      case 2:
        final val = bytes[0] | (bytes[1] << 8);
        if ((fmt & fmtSignedMask) == fmtSigned) {
          result = val < 0x8000 ? val : val - 0x10000;
        } else {
          result = val;
        }
        break;
      case 4:
        final val = bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24);
        if ((fmt & fmtSignedMask) == fmtSigned) {
          // Dart int is 64-bit, so handle 32-bit signed explicitly
          result = val < 0x80000000 ? val : val - 0x100000000;
        } else {
          result = val & 0xFFFFFFFF;
        }
        break;
      default:
        result = 0;
    }

    retval.setInt(result);
    return true;
  }

  /// writeInt(idx, fmt, val) - write an integer with the specified format
  bool _getpWriteInt(T3VM vm, T3Value retval, int self, int? argc) {
    _checkArgs(argc, 3, 3);

    final idx = vm.stack.pop().getAsInt();
    final fmt = vm.stack.pop().getAsInt();
    final val = vm.stack.pop().getAsInt();

    // Determine size from format
    int size;
    switch (fmt & fmtSizeMask) {
      case fmtInt8:
        size = 1;
        break;
      case fmtInt16:
        size = 2;
        break;
      case fmtInt32:
        size = 4;
        break;
      default:
        size = 1;
    }

    // Check range
    if (idx < 1 || idx + size - 1 > _data.length) {
      throw T3VmException(vmErrIndexOutOfRange);
    }

    // Write value in little-endian format
    final bytes = Uint8List(size);
    switch (size) {
      case 1:
        bytes[0] = val & 0xFF;
        break;
      case 2:
        bytes[0] = val & 0xFF;
        bytes[1] = (val >> 8) & 0xFF;
        break;
      case 4:
        bytes[0] = val & 0xFF;
        bytes[1] = (val >> 8) & 0xFF;
        bytes[2] = (val >> 16) & 0xFF;
        bytes[3] = (val >> 24) & 0xFF;
        break;
    }

    // Swap if big-endian
    if ((fmt & fmtOrderMask) == fmtBigEndian) {
      _swapBytes(bytes);
    }

    // Copy to data
    for (var i = 0; i < size; i++) {
      _data[idx - 1 + i] = bytes[i];
    }

    retval.setNil();
    return true;
  }

  /// packBytes(idx, fmt, args...) - pack binary data
  /// TODO: Stub implementation - full pack/unpack is complex
  bool _getpPackBytes(T3VM vm, T3Value retval, int self, int? argc) {
    throw T3VmException(vmErrBadTypeBif);
  }

  /// unpackBytes(idx, fmt) - unpack binary data
  /// TODO: Stub implementation - full pack/unpack is complex
  bool _getpUnpackBytes(T3VM vm, T3Value retval, int self, int? argc) {
    throw T3VmException(vmErrBadTypeBif);
  }

  /// sha256(startIdx?, len?) - compute SHA-256 hash
  bool _getpSha256(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 0, 2);

    var startIdx = (argc! >= 1) ? vm.stack.pop().getAsInt() : 1;
    var cnt = (argc >= 2) ? vm.stack.pop().getAsInt() : _data.length;

    // Force to be in range
    if (startIdx < 1) startIdx = 1;
    if (startIdx > _data.length + 1) startIdx = _data.length + 1;
    if (startIdx > _data.length) {
      cnt = 0;
    } else if (startIdx + cnt - 1 > _data.length) {
      cnt = _data.length + 1 - startIdx;
    }

    // Compute hash
    final bytes = _data.sublist(startIdx - 1, startIdx - 1 + cnt);
    final digest = sha256.convert(bytes);
    final hexStr = digest.toString();

    // Create string object
    final strObj = T3ObjString(hexStr);
    final strId = vm.objTable.allocObj(vm, false);
    vm.objTable.getEntry(strId)!.obj = strObj;
    retval.setObj(strId);
    return true;
  }

  /// digestMD5(startIdx?, len?) - compute MD5 hash
  bool _getpDigestMD5(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 0, 2);

    var startIdx = (argc! >= 1) ? vm.stack.pop().getAsInt() : 1;
    var cnt = (argc >= 2) ? vm.stack.pop().getAsInt() : _data.length;

    // Force to be in range
    if (startIdx < 1) startIdx = 1;
    if (startIdx > _data.length + 1) startIdx = _data.length + 1;
    if (startIdx > _data.length) {
      cnt = 0;
    } else if (startIdx + cnt - 1 > _data.length) {
      cnt = _data.length + 1 - startIdx;
    }

    // Compute hash
    final bytes = _data.sublist(startIdx - 1, startIdx - 1 + cnt);
    final digest = md5.convert(bytes);
    final hexStr = digest.toString();

    // Create string object
    final strObj = T3ObjString(hexStr);
    final strId = vm.objTable.allocObj(vm, false);
    vm.objTable.getEntry(strId)!.obj = strObj;
    retval.setObj(strId);
    return true;
  }

  // ---------------------------------------------------------------------------
  // Helper methods
  // ---------------------------------------------------------------------------

  void _checkArgs(int? argc, int min, int max) {
    if (argc == null) return;
    if (argc < min || argc > max) {
      throw T3VmException(vmErrWrongNumOfArgs);
    }
  }

  /// Copy bytes from another ByteArray
  void _copyFrom(int dstIdx, T3ObjByteArray srcArr, int srcIdx, int cnt) {
    if (cnt == 0) return;

    // Limit source to available
    if (srcIdx > srcArr._data.length) return;
    if (srcIdx + cnt - 1 > srcArr._data.length) {
      cnt = srcArr._data.length + 1 - srcIdx;
    }

    // Handle overlapping regions if same array
    if (identical(srcArr, this) && srcIdx != dstIdx) {
      // Need memmove semantics - Dart's setRange handles this
      final temp = srcArr._data.sublist(srcIdx - 1, srcIdx - 1 + cnt);
      _data.setRange(dstIdx - 1, dstIdx - 1 + cnt, temp);
    } else {
      _data.setRange(dstIdx - 1, dstIdx - 1 + cnt, srcArr._data, srcIdx - 1);
    }
  }

  /// Swap byte order in place
  static void _swapBytes(Uint8List bytes) {
    for (var i = 0, j = bytes.length - 1; i < j; i++, j--) {
      final tmp = bytes[i];
      bytes[i] = bytes[j];
      bytes[j] = tmp;
    }
  }

  // ---------------------------------------------------------------------------
  // T3Object overrides
  // ---------------------------------------------------------------------------

  @override
  bool indexValQ(T3VM vm, T3Value result, int self, T3Value indexVal) {
    final idx = indexVal.getAsInt();
    if (idx < 1 || idx > _data.length) {
      throw T3VmException(vmErrIndexOutOfRange);
    }
    result.setInt(_data[idx - 1]);
    return true;
  }

  @override
  bool setIndexValQ(T3VM vm, T3Value newContainer, int self, T3Value indexVal, T3Value newVal) {
    final idx = indexVal.getAsInt();
    if (idx < 1 || idx > _data.length) {
      throw T3VmException(vmErrIndexOutOfRange);
    }
    final val = newVal.getAsInt();
    if (val < 0 || val > 255) {
      throw T3VmException(vmErrNumOverflow);
    }
    _data[idx - 1] = val;
    newContainer.setObj(self);
    return true;
  }

  @override
  bool equals(T3VM vm, int self, T3Value val, int depth) {
    // Self-reference
    if (val.type == T3DataType.obj && val.getAsObj() == self) {
      return true;
    }

    // Must be another ByteArray
    if (val.type != T3DataType.obj) return false;
    final other = vm.objTable.getObj(val.getAsObj()!);
    if (other is! T3ObjByteArray) return false;

    // Must have same length
    if (other._data.length != _data.length) return false;

    // Compare bytes
    for (var i = 0; i < _data.length; i++) {
      if (_data[i] != other._data[i]) return false;
    }
    return true;
  }

  @override
  int calcHash(T3VM vm, int self, int depth) {
    var hash = 0;
    for (var i = 0; i < _data.length; i++) {
      hash += _data[i];
    }
    return hash & 0xFFFF;
  }

  @override
  String? castToString(T3VM vm, int self, T3Value newStr) {
    // Convert bytes to string treating as Latin-1
    final str = String.fromCharCodes(_data);
    final strObj = T3ObjString(str);
    final strId = vm.objTable.allocObj(vm, false);
    vm.objTable.getEntry(strId)!.obj = strObj;
    newStr.setObj(strId);
    return str;
  }

  @override
  void loadFromImage(T3VM vm, int self, Uint8List ptr, int offset, int size) {
    // Format: UINT4(count) + BYTES[count]
    if (size < 4) {
      _data = Uint8List(0);
      return;
    }

    final cnt = ptr[offset] | (ptr[offset + 1] << 8) | (ptr[offset + 2] << 16) | (ptr[offset + 3] << 24);

    // Limit to actual available bytes
    final bytesAvail = size - 4;
    final bytesToCopy = cnt < bytesAvail ? cnt : bytesAvail;

    _data = Uint8List(cnt);
    if (bytesToCopy > 0) {
      _data.setRange(0, bytesToCopy, ptr, offset + 4);
    }
  }

  @override
  void markRefs(T3VM vm, int state) {
    // ByteArray contains only bytes, no object references
  }

  @override
  bool inhProp(
    T3VM vm,
    int propId,
    T3Value retval,
    int self,
    int origTargetObj,
    int definingObj,
    List<int> sourceObj,
    int? argc,
  ) {
    // ByteArray has no inheritance chain beyond intrinsic class
    return false;
  }

  @override
  void buildPropList(T3VM vm, int self, T3Value retval) {
    // ByteArray has no instance properties
    retval.setNil();
  }

  @override
  void applyUndo(T3VM vm, T3UndoRecord rec) {
    // TODO: Implement undo when undo system is integrated
  }

  @override
  void markUndoRef(T3VM vm, T3UndoRecord rec) {
    // ByteArray contains no object references
  }

  @override
  void removeStaleUndoWeakRef(T3VM vm, T3UndoRecord rec) {
    // ByteArray contains no weak references
  }

  @override
  void saveToFile(T3VM vm, T3File fp) {
    // TODO: Implement file save when file I/O is integrated
  }

  @override
  void restoreFromFile(T3VM vm, int self, T3File fp, T3ObjFixup fixups) {
    // TODO: Implement file restore when file I/O is integrated
  }
}

/// ByteArray metaclass registration.
class T3MetaclassByteArray extends T3Metaclass {
  static final T3MetaclassByteArray instance = T3MetaclassByteArray._();

  T3MetaclassByteArray._();

  @override
  String getMetaName() => 'bytearray/030002';

  @override
  int createFromStack(T3VM vm, Uint8List pc, int pcOffset, int argc) {
    if (argc < 1) {
      throw T3VmException(vmErrWrongNumOfArgs);
    }

    final arg1 = vm.stack.pop();
    T3ObjByteArray arr;

    if (arg1.type == T3DataType.int32) {
      // Integer argument - create empty array of given size
      if (argc != 1) {
        throw T3VmException(vmErrWrongNumOfArgs);
      }
      final cnt = arg1.getAsInt();
      arr = T3ObjByteArray(cnt);
      // Fill with zeros (Uint8List already does this)
    } else if (arg1.type == T3DataType.obj) {
      // Object argument - could be a string or another ByteArray
      final obj = vm.objTable.getObj(arg1.getAsObj()!);
      if (obj is T3ObjByteArray) {
        // Copy from existing ByteArray
        var srcIdx = 1;
        var cnt = obj.length;

        if (argc >= 2) {
          srcIdx = vm.stack.pop().getAsInt();
          if (srcIdx < 1) srcIdx = 1;
        }
        if (argc >= 3) {
          cnt = vm.stack.pop().getAsInt();
        } else {
          cnt = srcIdx <= obj.length ? obj.length + 1 - srcIdx : 0;
        }
        if (argc > 3) {
          throw T3VmException(vmErrWrongNumOfArgs);
        }

        arr = T3ObjByteArray(cnt);
        if (cnt > 0 && srcIdx <= obj.length) {
          final copyLen = srcIdx + cnt - 1 <= obj.length ? cnt : obj.length + 1 - srcIdx;
          arr._data.setRange(0, copyLen, obj._data, srcIdx - 1);
        }
      } else if (obj is T3ObjString) {
        // Map string to bytes
        final str = obj.value;
        arr = T3ObjByteArray(str.length);
        for (var i = 0; i < str.length; i++) {
          final ch = str.codeUnitAt(i);
          if (ch > 255) {
            throw T3VmException(vmErrNumOverflow);
          }
          arr._data[i] = ch;
        }
      } else {
        throw T3VmException(vmErrBadTypeBif);
      }
    } else {
      throw T3VmException(vmErrBadTypeBif);
    }

    // Allocate object ID and store
    final id = vm.objTable.allocObj(vm, false);
    vm.objTable.getEntry(id)!.obj = arr;
    return id;
  }

  @override
  void createForImageLoad(T3VM vm, int id) {
    vm.objTable.getEntry(id)!.obj = T3ObjByteArray(0);
  }

  @override
  void createForRestore(T3VM vm, int id) {
    vm.objTable.getEntry(id)!.obj = T3ObjByteArray(0);
  }

  @override
  bool callStatProp(T3VM vm, T3Value result, Uint8List pc, int pcOffset, int argc, int prop) {
    // Check for static packBytes
    final funcIdx = vm.metaTable?.propToVectorIdx(getRegIdx(), prop);
    if (funcIdx == _propIdxPackBytes) {
      // Static packBytes creates a new ByteArray with packed data
      // TODO: Implement static packBytes
      throw T3VmException(vmErrBadTypeBif);
    }
    return false;
  }

  @override
  int getSupermeta(T3VM vm, int idx) => invalidObjectId;

  @override
  bool isMetaInstanceOf(T3VM vm, int obj) {
    final o = vm.objTable.getObj(obj);
    return o is T3ObjByteArray;
  }

  @override
  T3Metaclass? getSupermetaReg() => null;

  @override
  int getClassObj(T3VM vm) {
    return vm.metaTable?.getMetaclassObj(getRegIdx()) ?? invalidObjectId;
  }
}
