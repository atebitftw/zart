// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// TADS3 StringBuffer Metaclass
///
/// StringBuffer provides a mutable string buffer for efficient string building.
/// Unlike regular String objects which are immutable, StringBuffer allows
/// in-place modification of text content.
///
/// The buffer stores text as 16-bit Unicode characters (not UTF-8) for
/// efficient random access and modification.
///
/// Ported from vmstrbuf.cpp/vmstrbuf.h
library;

import 'dart:typed_data';

import 'package:zart/src/tads3/vm/t3_error.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';

/// Maximum buffer length (matching C++ STRBUF_MAX_LEN).
const int _strBufMaxLen = 0x7fffffff;

/// Minimum buffer/increment size.
const int _strBufMinSize = 16;

/// Default allocation size.
const int _strBufDefaultAlo = 256;

/// Default increment size.
const int _strBufDefaultInc = 256;

// ----------------------------------------------------------------------------
// Property function indices (matching C++ function table)
// ----------------------------------------------------------------------------

const int _propIdxUndef = 0;
const int _propIdxLen = 1;
const int _propIdxCharAt = 2;
const int _propIdxAppend = 3;
const int _propIdxInsert = 4;
const int _propIdxCopyChars = 5;
const int _propIdxDelete = 6;
const int _propIdxSplice = 7;
const int _propIdxSubstr = 8;

/// StringBuffer object.
///
/// Provides a mutable string buffer for efficient string building and
/// manipulation. Text is stored internally as 16-bit Unicode characters.
class T3ObjStringBuffer extends T3Object {
  /// Internal buffer of 16-bit Unicode characters.
  List<int> _buf;

  /// Current string length (characters in use).
  int _len;

  /// Allocated buffer size.
  int _alo;

  /// Allocation increment size.
  int _inc;

  /// Metaclass registration object.
  static final T3MetaclassStringBuffer metaclassReg = T3MetaclassStringBuffer();

  /// Create a StringBuffer with given allocation size and increment.
  T3ObjStringBuffer(int alo, int inc)
    : _alo = alo.clamp(_strBufMinSize, _strBufMaxLen),
      _inc = inc.clamp(_strBufMinSize, _strBufMaxLen),
      _len = 0,
      _buf = List<int>.filled(alo.clamp(_strBufMinSize, _strBufMaxLen), 0);

  /// Create a StringBuffer with default sizes.
  T3ObjStringBuffer.withDefaults()
    : _alo = _strBufDefaultAlo,
      _inc = _strBufDefaultInc,
      _len = 0,
      _buf = List<int>.filled(_strBufDefaultAlo, 0);

  /// Create from VM stack arguments.
  ///
  /// Arguments:
  /// - 0 args: default allocation (256, 256)
  /// - 1 arg: initial size, increment calculated heuristically
  /// - 2 args: initial size and increment
  static int createFromStack(T3VM vm, int argc) {
    int alo;
    int inc;

    if (argc == 0) {
      // No arguments - use defaults
      alo = _strBufDefaultAlo;
      inc = _strBufDefaultInc;
    } else if (argc == 1) {
      // One argument - initial size
      alo = _tryGetInt(vm.stack.popVal()) ?? _strBufDefaultAlo;

      // Calculate increment heuristically
      if (alo < 256) {
        inc = alo;
      } else if (alo < 4096) {
        inc = alo ~/ 2;
      } else {
        inc = 2048;
      }
    } else if (argc == 2) {
      // Two arguments - initial size and increment
      // Stack has: (top) inc, alo (bottom) since args pushed in order
      inc = _tryGetInt(vm.stack.popVal()) ?? _strBufDefaultInc;
      alo = _tryGetInt(vm.stack.popVal()) ?? _strBufDefaultAlo;
    } else {
      throw T3VmException(vmErrWrongNumOfArgs);
    }

    // Enforce minimum and maximum sizes
    alo = alo.clamp(_strBufMinSize, _strBufMaxLen);
    inc = inc.clamp(_strBufMinSize, _strBufMaxLen);

    // Create the object
    final obj = T3ObjStringBuffer(alo, inc);

    // Register with object table
    return vm.objTable.registerObj(obj, false);
  }

  @override
  T3Metaclass getMetaclassReg() => metaclassReg;

  @override
  bool isOfMetaclass(T3Metaclass meta) {
    return meta == metaclassReg || super.isOfMetaclass(meta);
  }

  @override
  void notifyDelete(T3VM vm, bool inRootSet) {
    // No special cleanup needed - Dart handles memory
  }

  /// Get the current character length.
  int get length => _len;

  /// Get the allocated buffer size.
  int get allocatedSize => _alo;

  /// Get the allocation increment.
  int get increment => _inc;

  /// Get a character at the given 0-based index.
  int getCharAt(int idx) {
    if (idx < 0 || idx >= _len) {
      throw T3VmException(vmErrIndexOutOfRange);
    }
    return _buf[idx];
  }

  /// Set a character at the given 0-based index.
  void setCharAt(int idx, int ch) {
    if (idx < 0 || idx >= _len) {
      throw T3VmException(vmErrIndexOutOfRange);
    }
    _buf[idx] = ch & 0xFFFF; // Clamp to 16-bit
  }

  /// Ensure the buffer has enough space for the given length.
  void ensureSpace(int len) {
    if (len > _strBufMaxLen) {
      throw T3VmException(vmErrStrTooLong);
    }

    if (len > _alo) {
      // Calculate new allocation size in increments of _inc
      final newAlo = ((len + _inc - 1) ~/ _inc) * _inc;
      _expandBuffer(newAlo);
    }
  }

  /// Expand the buffer to the new allocation size.
  void _expandBuffer(int newAlo) {
    final newBuf = List<int>.filled(newAlo, 0);
    for (var i = 0; i < _len; i++) {
      newBuf[i] = _buf[i];
    }
    _buf = newBuf;
    _alo = newAlo;
  }

  /// Adjust index arguments to valid range.
  ///
  /// [idx] is the 0-based starting index (in-out).
  /// [len] is the length of characters to operate on (in-out, nullable).
  /// [ins] is the length of characters to insert (in-out, nullable).
  void _adjustArgs(List<int> idx, List<int>? len, List<int>? ins) {
    // Clamp index to 0..len
    if (idx[0] < 0) {
      idx[0] = 0;
    } else if (idx[0] > _len) {
      idx[0] = _len;
    }

    // Clamp length to available range
    if (len != null) {
      if (len[0] < 0) {
        len[0] = 0;
      } else if (idx[0] + len[0] > _len) {
        len[0] = _len - idx[0];
      }
    }

    // Check insertion limit
    if (ins != null) {
      final del = len != null ? len[0] : 0;
      if (ins[0] < 0) {
        ins[0] = 0;
      } else if (idx[0] + ins[0] + _len - del > _strBufMaxLen) {
        throw T3VmException(vmErrStrTooLong);
      }
    }
  }

  /// Move buffer contents for a splice operation.
  void _spliceMove(int idx, int del, int ins) {
    // Expand buffer if needed
    if (ins > del) {
      ensureSpace(_len + ins - del);
    }

    // Move tail if net insertion/deletion
    if (ins != del && idx + del < _len) {
      final tailLen = _len - (idx + del);
      if (ins > del) {
        // Moving right - copy from end to avoid overlap
        for (var i = tailLen - 1; i >= 0; i--) {
          _buf[idx + ins + i] = _buf[idx + del + i];
        }
      } else {
        // Moving left
        for (var i = 0; i < tailLen; i++) {
          _buf[idx + ins + i] = _buf[idx + del + i];
        }
      }
    }

    // Adjust length
    _len += ins - del;
  }

  /// Splice 16-bit characters into the buffer.
  void spliceChars(int idx, int delChars, List<int> src, int insChars) {
    final idxList = [idx];
    final delList = [delChars];
    final insList = [insChars];
    _adjustArgs(idxList, delList, insList);
    idx = idxList[0];
    delChars = delList[0];
    insChars = insList[0];

    // Move buffer contents
    _spliceMove(idx, delChars, insChars);

    // Copy in new characters
    for (var i = 0; i < insChars; i++) {
      _buf[idx + i] = src[i] & 0xFFFF;
    }
  }

  /// Splice UTF-8 text into the buffer.
  void spliceUtf8(int idx, int delChars, String src) {
    // Convert UTF-8 string to 16-bit characters
    final chars = src.runes.toList();
    spliceChars(idx, delChars, chars, chars.length);
  }

  /// Insert text at the given index.
  void insertText(int idx, String src) {
    spliceUtf8(idx, 0, src);
  }

  /// Append text to the end.
  void appendText(String src) {
    insertText(_len, src);
  }

  /// Delete characters starting at index.
  void deleteText(int idx, int len) {
    spliceChars(idx, len, [], 0);
  }

  /// Get a substring as a Dart string.
  String substring(int idx, int len) {
    final idxList = [idx];
    final lenList = [len];
    _adjustArgs(idxList, lenList, null);
    idx = idxList[0];
    len = lenList[0];

    // Convert 16-bit chars to string
    final buffer = StringBuffer();
    for (var i = 0; i < len; i++) {
      buffer.writeCharCode(_buf[idx + i]);
    }
    return buffer.toString();
  }

  /// Convert the entire buffer to a string.
  @override
  String? castToString(T3VM vm, int self, T3Value newStr) {
    return substring(0, _len);
  }

  @override
  bool equals(T3VM vm, int self, T3Value val, int depth) {
    // Compare to another StringBuffer
    if (val.type == T3DataType.obj) {
      final other = vm.objTable.getObj(val.getAsObj()!);
      if (other is T3ObjStringBuffer) {
        if (_len != other._len) return false;
        for (var i = 0; i < _len; i++) {
          if (_buf[i] != other._buf[i]) return false;
        }
        return true;
      }
    }

    // Compare to a string
    // For constant strings (sstring type), we'd need to look up in const pool
    // For now, we can only equal another StringBuffer
    if (val.type == T3DataType.sstring) {
      // Would need const pool lookup - simplified for now
      return false;
    }

    throw T3VmException(vmErrInvalidComparison);
  }

  /// Helper to try getting an int from a T3Value (returns null instead of throwing).
  static int? _tryGetInt(T3Value val) {
    try {
      return val.getAsInt();
    } catch (_) {
      return null;
    }
  }

  /// Helper to get a Dart string from a T3Value.
  /// For StringBuffer, returns the buffer content. For other objects, returns empty.
  static String _getStringFromValue(T3VM vm, T3Value val) {
    if (val.type == T3DataType.obj) {
      final obj = vm.objTable.getObj(val.getAsObj()!);
      if (obj is T3ObjStringBuffer) {
        return obj.substring(0, obj._len);
      }
    }
    // For constant strings, we'd need const pool lookup
    // For now, return empty string
    return '';
  }

  // Note: _equalsString and _compareString would be used if we could
  // look up constant strings from the const pool. For now, they are
  // placeholders for future implementation.

  @override
  int compareTo(T3VM vm, int self, T3Value val) {
    // Compare to another StringBuffer
    if (val.type == T3DataType.obj) {
      final other = vm.objTable.getObj(val.getAsObj()!);
      if (other is T3ObjStringBuffer) {
        for (var i = 0; i < _len && i < other._len; i++) {
          if (_buf[i] < other._buf[i]) return -1;
          if (_buf[i] > other._buf[i]) return 1;
        }
        return _len - other._len;
      }
    }

    // Compare to a string
    // For constant strings, we'd need const pool lookup
    if (val.type == T3DataType.sstring) {
      // Would need const pool lookup - simplified for now
      return 1; // StringBuffer > constant string by convention
    }

    throw T3VmException(vmErrInvalidComparison);
  }

  @override
  int calcHash(T3VM vm, int self, int depth) {
    // Calculate hash matching String hash
    var hash = 0;
    for (var i = 0; i < _len; i++) {
      hash += _buf[i];
    }
    return hash & 0xFFFFFFFF;
  }

  // --------------------------------------------------------------------------
  // Property evaluators
  // --------------------------------------------------------------------------

  @override
  bool getProp(
    T3VM vm,
    int propId,
    T3Value retval,
    int self,
    List<int> sourceObj,
    int? argc,
  ) {
    // Translate property to function index
    final funcIdx = vm.metaTable.propToVectorIdx(
      metaclassReg.getRegIdx(),
      propId,
    );

    switch (funcIdx) {
      case _propIdxLen:
        return getpLen(vm, self, retval, argc ?? 0);
      case _propIdxCharAt:
        return getpCharAt(vm, self, retval, argc ?? 0);
      case _propIdxAppend:
        return getpAppend(vm, self, retval, argc ?? 0);
      case _propIdxInsert:
        return getpInsert(vm, self, retval, argc ?? 0);
      case _propIdxCopyChars:
        return getpCopyChars(vm, self, retval, argc ?? 0);
      case _propIdxDelete:
        return getpDelete(vm, self, retval, argc ?? 0);
      case _propIdxSplice:
        return getpSplice(vm, self, retval, argc ?? 0);
      case _propIdxSubstr:
        return getpSubstr(vm, self, retval, argc ?? 0);
      default:
        return false;
    }
  }

  @override
  void setProp(T3VM vm, T3Undo? undo, int self, int propId, T3Value val) {
    // No settable properties
    throw T3VmException(vmErrInvalidSetprop);
  }

  /// Property: length() - returns character count.
  bool getpLen(T3VM vm, int self, T3Value retval, int argc) {
    if (argc != 0) throw T3VmException(vmErrWrongNumOfArgs);
    retval.setInt(_len);
    return true;
  }

  /// Property: charAt(idx) - returns Unicode code at index.
  bool getpCharAt(T3VM vm, int self, T3Value retval, int argc) {
    if (argc != 1) throw T3VmException(vmErrWrongNumOfArgs);

    var idx = _tryGetInt(vm.stack.popVal()) ?? 0;

    // Adjust to 0-based or end-based
    idx += (idx < 0 ? _len : -1);

    if (idx < 0 || idx >= _len) {
      throw T3VmException(vmErrIndexOutOfRange);
    }

    retval.setInt(_buf[idx]);
    return true;
  }

  /// Property: append(str) - appends text, returns self.
  bool getpAppend(T3VM vm, int self, T3Value retval, int argc) {
    if (argc != 1) throw T3VmException(vmErrWrongNumOfArgs);

    final strVal = vm.stack.popVal();
    final str = _getStringFromValue(vm, strVal);

    appendText(str);

    retval.setObj(self);
    return true;
  }

  /// Property: insert(idx, str) - inserts at position, returns self.
  bool getpInsert(T3VM vm, int self, T3Value retval, int argc) {
    if (argc != 2) throw T3VmException(vmErrWrongNumOfArgs);

    var idx = _tryGetInt(vm.stack.popVal()) ?? 0;
    final strVal = vm.stack.popVal();
    final str = _getStringFromValue(vm, strVal);

    // Adjust to 0-based or end-based
    idx += (idx < 0 ? _len : -1);

    insertText(idx, str);

    retval.setObj(self);
    return true;
  }

  /// Property: copyChars(idx, str) - overwrites at position, returns self.
  bool getpCopyChars(T3VM vm, int self, T3Value retval, int argc) {
    if (argc != 2) throw T3VmException(vmErrWrongNumOfArgs);

    var idx = _tryGetInt(vm.stack.popVal()) ?? 0;
    final strVal = vm.stack.popVal();
    final str = _getStringFromValue(vm, strVal);

    // Adjust to 0-based or end-based
    idx += (idx < 0 ? _len : -1);

    // Get character count to replace
    final chars = str.runes.toList();
    spliceChars(idx, chars.length, chars, chars.length);

    retval.setObj(self);
    return true;
  }

  /// Property: delete(idx, [len]) - deletes characters, returns self.
  bool getpDelete(T3VM vm, int self, T3Value retval, int argc) {
    if (argc < 1 || argc > 2) throw T3VmException(vmErrWrongNumOfArgs);

    var idx = _tryGetInt(vm.stack.popVal()) ?? 0;

    // Adjust to 0-based or end-based
    idx += (idx < 0 ? _len : -1);

    // Get length if provided, otherwise delete rest of string
    final len = argc >= 2 ? (_tryGetInt(vm.stack.popVal()) ?? _len) : _len;

    deleteText(idx, len);

    retval.setObj(self);
    return true;
  }

  /// Property: splice(idx, del, str) - replace del chars with str, returns self.
  bool getpSplice(T3VM vm, int self, T3Value retval, int argc) {
    if (argc != 3) throw T3VmException(vmErrWrongNumOfArgs);

    var idx = _tryGetInt(vm.stack.popVal()) ?? 0;
    final del = _tryGetInt(vm.stack.popVal()) ?? 0;
    final strVal = vm.stack.popVal();
    final str = _getStringFromValue(vm, strVal);

    // Adjust to 0-based or end-based
    idx += (idx < 0 ? _len : -1);

    spliceUtf8(idx, del, str);

    retval.setObj(self);
    return true;
  }

  /// Property: substr(idx, [len]) - returns String substring.
  bool getpSubstr(T3VM vm, int self, T3Value retval, int argc) {
    if (argc < 1 || argc > 2) throw T3VmException(vmErrWrongNumOfArgs);

    var idx = _tryGetInt(vm.stack.popVal()) ?? 0;

    // Adjust to 0-based or end-based
    idx += (idx < 0 ? _len : -1);

    // Get length if provided, otherwise return rest of string
    final len = argc >= 2 ? (_tryGetInt(vm.stack.popVal()) ?? _len) : _len;

    // Create a String object - for now, just set as string constant
    // In a full implementation, this would create a T3ObjString
    // For now, return as nil - full implementation would create String object
    // Compute substring for side effects (validation), but discard result
    substring(idx, len);
    retval.setNil(); // Placeholder - caller should use castToString instead
    return true;
  }

  // --------------------------------------------------------------------------
  // Indexing operations
  // --------------------------------------------------------------------------

  @override
  bool indexValQ(T3VM vm, T3Value result, int self, T3Value indexVal) {
    var idx = _tryGetInt(indexVal) ?? 0;

    // Adjust to 0-based or end-based
    idx += (idx < 0 ? _len : -1);

    if (idx < 0 || idx >= _len) {
      throw T3VmException(vmErrIndexOutOfRange);
    }

    // Return one-character string
    // Return the character as an integer (Unicode code point)
    result.setInt(_buf[idx]);
    return true;
  }

  @override
  bool setIndexValQ(
    T3VM vm,
    T3Value newContainer,
    int self,
    T3Value indexVal,
    T3Value newVal,
  ) {
    var idx = _tryGetInt(indexVal) ?? 0;

    // Adjust to 0-based or end-based
    idx += (idx < 0 ? _len : -1);

    if (idx < 0 || idx >= _len) {
      throw T3VmException(vmErrIndexOutOfRange);
    }

    // Get character to set
    int ch;
    if (newVal.type == T3DataType.int32) {
      final intVal = _tryGetInt(newVal) ?? 0;
      if (intVal < 0 || intVal > 65535) {
        throw T3VmException(vmErrBadValBif);
      }
      ch = intVal;
    } else {
      final str = _getStringFromValue(vm, newVal);
      ch = str.isNotEmpty ? str.runes.first : 0;
    }

    // Splice the character
    spliceChars(idx, 1, [ch], 1);

    // Return self as new container
    newContainer.setObj(self);
    return true;
  }

  // --------------------------------------------------------------------------
  // Serialization
  // --------------------------------------------------------------------------

  @override
  void loadFromImage(T3VM vm, int self, Uint8List ptr, int offset, int size) {
    if (size < 12) throw T3VmException(vmErrInvalMetaclassData);

    final view = ByteData.sublistView(ptr, offset, offset + size);

    // Read header
    var alo = view.getUint32(0, Endian.little);
    var inc = view.getUint32(4, Endian.little);
    var len = view.getUint32(8, Endian.little);

    // Clamp values
    alo = alo.clamp(_strBufMinSize, _strBufMaxLen);
    inc = inc.clamp(_strBufMinSize, _strBufMaxLen);
    if (len > alo) len = alo;

    // Initialize buffer
    _alo = alo;
    _inc = inc;
    _len = len;
    _buf = List<int>.filled(alo, 0);

    // Read characters (16-bit each)
    var charOffset = 12;
    for (var i = 0; i < len; i++) {
      _buf[i] = view.getUint16(charOffset, Endian.little);
      charOffset += 2;
    }
  }

  @override
  void saveToFile(T3VM vm, T3File fp) {
    // Write header: alo, inc, len
    // Write characters as 16-bit values
    // Implementation would use fp.writeUint32/writeUint16
  }

  @override
  void restoreFromFile(T3VM vm, int self, T3File fp, T3ObjFixup fixups) {
    // Read header: alo, inc, len
    // Read characters as 16-bit values
    // Implementation would use fp.readUint32/readUint16
  }

  @override
  void markRefs(T3VM vm, int state) {
    // StringBuffer doesn't reference other objects
  }

  @override
  void applyUndo(T3VM vm, T3UndoRecord rec) {
    // Undo support would be implemented here
  }

  @override
  void markUndoRef(T3VM vm, T3UndoRecord rec) {
    // No references in undo records
  }

  @override
  void removeStaleUndoWeakRef(T3VM vm, T3UndoRecord rec) {
    // No weak references
  }

  @override
  bool isInstanceOf(T3VM vm, int obj) {
    // Check if obj is our intrinsic class
    return false; // Simplified - full impl would check metaclass hierarchy
  }

  @override
  int getSuperclass(T3VM vm, int self, int index) {
    return invalidObj;
  }

  @override
  void buildPropList(T3VM vm, int self, T3Value retval) {
    // StringBuffer has no user-defined properties
    retval.setNil();
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
    return false;
  }
}

// ----------------------------------------------------------------------------
// Metaclass Registration
// ----------------------------------------------------------------------------

/// Metaclass for StringBuffer.
class T3MetaclassStringBuffer extends T3Metaclass {
  /// Metaclass name.
  static const name = 'stringbuffer/030000';

  @override
  String getMetaName() => name;

  @override
  int createFromStack(T3VM vm, Uint8List pc, int pcOffset, int argc) {
    return T3ObjStringBuffer.createFromStack(vm, argc);
  }

  @override
  void createForImageLoad(T3VM vm, int id) {
    final obj = T3ObjStringBuffer.withDefaults();
    vm.objTable.setObj(id, obj);
  }

  @override
  void createForRestore(T3VM vm, int id) {
    final obj = T3ObjStringBuffer.withDefaults();
    vm.objTable.setObj(id, obj);
  }

  @override
  bool callStatProp(
    T3VM vm,
    T3Value result,
    Uint8List pc,
    int pcOffset,
    int argc,
    int prop,
  ) {
    // StringBuffer has no static properties
    return false;
  }

  @override
  int getSupermeta(T3VM vm, int idx) => invalidObj;

  @override
  bool isMetaInstanceOf(T3VM vm, int obj) => false;

  @override
  T3Metaclass? getSupermetaReg() => null;

  @override
  int getClassObj(T3VM vm) => invalidObj;
}
