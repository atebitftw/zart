// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// TADS3 String Metaclass
///
/// Implements the String metaclass (vmstr.cpp), which provides string operations
/// for both constant strings (from the constant pool) and dynamic string objects.
///
/// Strings in TADS3 are immutable UTF-8 encoded values with a 2-byte length prefix.
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:zart/src/tads3/vm/t3_error.dart';
import 'package:zart/src/tads3/vm/t3_globals.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';

/// String object - wraps a Dart String for TADS3 VM operations.
class T3ObjString extends T3Object {
  /// The string value
  final String value;

  /// Metaclass registration object
  static final T3MetaclassString metaclassReg = T3MetaclassString();

  /// Create a string object from a Dart string
  T3ObjString(this.value);

  /// Create from constant pool data (length-prefixed UTF-8)
  factory T3ObjString.fromConstPool(Uint8List data, int offset) {
    final len = data[offset] | (data[offset + 1] << 8);
    final bytes = data.sublist(offset + 2, offset + 2 + len);
    return T3ObjString(utf8.decode(bytes, allowMalformed: true));
  }

  @override
  T3Metaclass getMetaclassReg() => metaclassReg;

  @override
  void notifyDelete(T3VM vm, bool inRootSet) {
    // Strings are immutable and have no special cleanup
  }

  @override
  bool isInstanceOf(T3VM vm, int obj) => false;

  @override
  int getSuperclass(T3VM vm, int self, int index) => invalidObj;

  @override
  void setProp(T3VM vm, T3Undo? undo, int self, int propId, T3Value val) {
    // Strings are immutable - cannot set properties
    throw T3VmException(vmErrCannotCreateInst);
  }

  @override
  bool getProp(
    T3VM vm,
    int propId,
    T3Value retval,
    int self,
    List<int> sourceObj,
    int? argc,
  ) {
    // Dispatch to method based on property ID
    // Property IDs are defined in the function table
    sourceObj[0] = self;
    return _evalProp(propId, retval, argc);
  }

  /// Evaluate a property/method call
  bool _evalProp(int propId, T3Value retval, int? argc) {
    switch (propId) {
      case 1: // length
        retval.setInt(value.length);
        return true;
      default:
        return false;
    }
  }

  @override
  void loadFromImage(T3VM vm, int self, Uint8List ptr, int offset, int size) {
    // String data is the extension - already handled in factory
  }

  @override
  void markRefs(T3VM vm, int state) {
    // Strings reference no other objects
  }

  @override
  void applyUndo(T3VM vm, T3UndoRecord rec) {
    // Strings are immutable - no undo needed
  }

  @override
  void markUndoRef(T3VM vm, T3UndoRecord rec) {
    // No references to mark
  }

  @override
  void removeStaleUndoWeakRef(T3VM vm, T3UndoRecord rec) {
    // No weak references
  }

  @override
  void saveToFile(T3VM vm, T3File fp) {
    // TODO: Implement save
  }

  @override
  void restoreFromFile(T3VM vm, int self, T3File fp, T3ObjFixup fixups) {
    // TODO: Implement restore
  }

  @override
  void buildPropList(T3VM vm, int self, T3Value retval) {
    // Strings have no enumerable properties
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

  @override
  String? castToString(T3VM vm, int self, T3Value newStr) {
    newStr.setObj(self);
    return value;
  }

  @override
  bool equals(T3VM vm, int self, T3Value val, int depth) {
    if (val.type == T3DataType.obj) {
      final otherObj = vm as T3Globals;
      final entry = otherObj.objTable?.getEntry(val.getAsObj()!);
      if (entry?.obj is T3ObjString) {
        return value == (entry!.obj as T3ObjString).value;
      }
    }
    return false;
  }

  @override
  int compareTo(T3VM vm, int self, T3Value val) {
    // Get the other string
    String? otherStr;
    if (val.type == T3DataType.sstring) {
      // Constant string - get from pool
      final globals = vm as T3Globals;
      otherStr = globals.constPool?.getString(val.getAsOfs()!);
    } else if (val.type == T3DataType.obj) {
      final globals = vm as T3Globals;
      final entry = globals.objTable?.getEntry(val.getAsObj()!);
      if (entry?.obj is T3ObjString) {
        otherStr = (entry!.obj as T3ObjString).value;
      }
    }
    if (otherStr == null) {
      throw T3VmException(vmErrInvalidComparison);
    }
    return value.compareTo(otherStr);
  }

  @override
  int calcHash(T3VM vm, int self, int depth) {
    // Use the string's hash code
    return value.hashCode & 0xFFFF;
  }

  @override
  bool addVal(T3VM vm, T3Value result, int self, T3Value val) {
    // String concatenation
    String? otherStr;
    if (val.type == T3DataType.sstring) {
      final globals = vm as T3Globals;
      otherStr = globals.constPool?.getString(val.getAsOfs()!);
    } else if (val.type == T3DataType.obj) {
      final globals = vm as T3Globals;
      final entry = globals.objTable?.getEntry(val.getAsObj()!);
      if (entry?.obj is T3ObjString) {
        otherStr = (entry!.obj as T3ObjString).value;
      }
    } else if (val.type == T3DataType.int32) {
      otherStr = val.getAsInt().toString();
    }

    if (otherStr != null) {
      // Create new string object with concatenated value
      final newStr = T3ObjString(value + otherStr);
      // TODO: Register in object table and return object ID
      result.setNil(); // Placeholder
      return true;
    }
    return false;
  }

  @override
  bool indexValQ(T3VM vm, T3Value result, int self, T3Value indexVal) {
    // String indexing - get character at position (1-based)
    if (indexVal.type != T3DataType.int32) return false;
    final idx = indexVal.getAsInt();
    if (idx < 1 || idx > value.length) {
      throw T3VmException(vmErrIndexOutOfRange);
    }
    // Return the character code as an integer
    result.setInt(value.codeUnitAt(idx - 1));
    return true;
  }

  // --- String Methods ---

  /// Get string length in characters
  int get length => value.length;

  /// Extract substring (1-based start index)
  String substr(int start, [int? len]) {
    // Convert from 1-based to 0-based
    final startIdx = start - 1;
    if (startIdx < 0 || startIdx >= value.length) return '';
    final endIdx = len != null
        ? (startIdx + len).clamp(0, value.length)
        : value.length;
    return value.substring(startIdx, endIdx);
  }

  /// Find substring (1-based result, 0 if not found)
  int find(String needle, [int start = 1]) {
    final startIdx = start - 1;
    if (startIdx < 0 || startIdx >= value.length) return 0;
    final pos = value.indexOf(needle, startIdx);
    return pos < 0 ? 0 : pos + 1;
  }

  /// Find last occurrence of substring
  int findLast(String needle, [int? start]) {
    final startIdx = start != null ? start - 1 : value.length;
    final pos = value.lastIndexOf(needle, startIdx);
    return pos < 0 ? 0 : pos + 1;
  }

  /// Convert to uppercase
  String toUpper() => value.toUpperCase();

  /// Convert to lowercase
  String toLower() => value.toLowerCase();

  /// Check if starts with prefix
  bool startsWith(String prefix) => value.startsWith(prefix);

  /// Check if ends with suffix
  bool endsWith(String suffix) => value.endsWith(suffix);
}

/// String metaclass registration
class T3MetaclassString extends T3Metaclass {
  static const String name = 'string/030008';

  @override
  String getMetaName() => name;

  @override
  int createFromStack(T3VM vm, Uint8List pc, int pcOffset, int argc) {
    // Create a string from stack arguments
    // TODO: Implement proper string creation
    throw T3VmException(vmErrBadDynamicNew);
  }

  @override
  void createForImageLoad(T3VM vm, int id) {
    // String objects are created differently - from constant pool
  }

  @override
  void createForRestore(T3VM vm, int id) {
    // TODO: Implement restore
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
    // String has no static properties
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

/// Helper to get string from a T3Value (handles both sstring and string objects)
String? getStringValue(T3Globals globals, T3Value val) {
  if (val.type == T3DataType.sstring) {
    return globals.constPool?.getString(val.getAsOfs()!);
  } else if (val.type == T3DataType.obj) {
    final entry = globals.objTable?.getEntry(val.getAsObj()!);
    if (entry?.obj is T3ObjString) {
      return (entry!.obj as T3ObjString).value;
    }
  }
  return null;
}
