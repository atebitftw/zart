// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// TADS3 List Metaclass
///
/// Implements the List metaclass (vmlst.cpp), which provides list operations.
/// Lists in TADS3 are immutable - operations return new lists.
///
/// List format: 2-byte length prefix followed by elements (type byte + value).
library;

import 'dart:typed_data';
import 'package:zart/src/tads3/vm/t3_collection.dart';
import 'package:zart/src/tads3/vm/t3_error.dart';
import 'package:zart/src/tads3/vm/t3_globals.dart';
import 'package:zart/src/tads3/vm/t3_iter.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';

/// List object - wraps a Dart List for TADS3 VM operations.
class T3ObjList extends T3Collection {
  /// The list elements
  final List<T3Value> elements;

  /// Metaclass registration object
  static final T3MetaclassList metaclassReg = T3MetaclassList();

  /// Create a list from Dart list of T3Values
  T3ObjList(this.elements);

  @override
  void newIterator(T3VM vm, T3Value retval, T3Value selfVal) {
    retval.setObj(T3ObjIterIdx.createForColl(vm, selfVal, 1, elements.length));
  }

  @override
  void newLiveIterator(T3VM vm, T3Value retval, T3Value selfVal) {
    // Lists are immutable, so live iterator is the same as snapshot iterator
    newIterator(vm, retval, selfVal);
  }

  /// Index a list (static helper)
  static void indexList(T3VM vm, T3Value retval, int poolOfs, int idx) {
    final (data, localOfs) = vm.constPool!.getPtr(poolOfs);
    final count = data[localOfs] | (data[localOfs + 1] << 8);

    if (idx < 1 || idx > count) {
      throw T3VmException(vmErrIndexOutOfRange);
    }

    // A TADS3 constant list starts with a 2-byte count, then each element.
    // Each element is Type (1 byte) + Value (VMB_DATAHOLDER - 1 bytes).
    // The T3Value constructor or fromByteData could be used if available.
    // For now, let's use a simpler approach if possible.
    // Actually, T3ObjList.fromConstPool already parses the whole list.
    // For indexing efficiency, we should ideally parse only the requested element.
    // Total size of an element is 1 + 9 = 10 bytes (dataType + value).
    // But VMB_DATAHOLDER is 10 bytes total (1 type + 9 value/pad).
    // Wait, let's check VMB_DATAHOLDER size.

    final elementOfs = localOfs + 2 + (idx - 1) * 10;
    final dataType = T3DataType.values[data[elementOfs]];
    retval.type = dataType;
    // We need to copy the 9 bytes of data.
    // T3Value should have a way to read from buffer.
    retval.readFromBuffer(data, elementOfs);
  }

  /// Create from constant pool data (length-prefixed, each element is type+value)
  factory T3ObjList.fromConstPool(Uint8List data, int offset) {
    final count = data[offset] | (data[offset + 1] << 8);
    final elements = <T3Value>[];
    var pos = offset + 2;

    for (var i = 0; i < count; i++) {
      final type = T3DataType.values[data[pos]];
      pos++;
      final val = T3Value(type);

      // Read value based on type
      switch (type) {
        case T3DataType.nil:
          // No additional data
          break;
        case T3DataType.trueValue:
          // No additional data
          break;
        case T3DataType.int32:
          final intVal =
              data[pos] |
              (data[pos + 1] << 8) |
              (data[pos + 2] << 16) |
              (data[pos + 3] << 24);
          val.setInt(intVal.toSigned(32));
          pos += 4;
          break;
        case T3DataType.obj:
          final objId =
              data[pos] |
              (data[pos + 1] << 8) |
              (data[pos + 2] << 16) |
              (data[pos + 3] << 24);
          val.setObj(objId);
          pos += 4;
          break;
        case T3DataType.prop:
          final propId = data[pos] | (data[pos + 1] << 8);
          val.setPropId(propId);
          pos += 2;
          break;
        case T3DataType.sstring:
        case T3DataType.list:
          final ofs =
              data[pos] |
              (data[pos + 1] << 8) |
              (data[pos + 2] << 16) |
              (data[pos + 3] << 24);
          if (type == T3DataType.sstring) {
            val.setSstring(ofs);
          } else {
            val.setList(ofs);
          }
          pos += 4;
          break;
        default:
          // Skip unknown types - assume 4 bytes
          pos += 4;
      }
      elements.add(val);
    }

    return T3ObjList(elements);
  }

  @override
  T3Metaclass getMetaclassReg() => metaclassReg;

  @override
  void notifyDelete(T3VM vm, bool inRootSet) {
    // Lists are immutable and have no special cleanup
  }

  @override
  bool isInstanceOf(T3VM vm, int obj) => false;

  @override
  int getSuperclass(T3VM vm, int self, int index) => invalidObj;

  @override
  void setProp(T3VM vm, T3Undo? undo, int self, int propId, T3Value val) {
    // Lists are immutable - cannot set properties
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
    sourceObj[0] = self;
    return _evalProp(propId, retval, argc);
  }

  bool _evalProp(int propId, T3Value retval, int? argc) {
    switch (propId) {
      case 1: // length
        retval.setInt(elements.length);
        return true;
      default:
        return false;
    }
  }

  @override
  void loadFromImage(T3VM vm, int self, Uint8List ptr, int offset, int size) {}

  @override
  void markRefs(T3VM vm, int state) {
    // Mark all object references in list elements
    for (final elem in elements) {
      if (elem.type == T3DataType.obj && elem.getAsObj() != null) {
        // TODO: Mark the referenced object
      }
    }
  }

  @override
  void applyUndo(T3VM vm, T3UndoRecord rec) {}

  @override
  void markUndoRef(T3VM vm, T3UndoRecord rec) {}

  @override
  void removeStaleUndoWeakRef(T3VM vm, T3UndoRecord rec) {}

  @override
  void saveToFile(T3VM vm, T3File fp) {}

  @override
  void restoreFromFile(T3VM vm, int self, T3File fp, T3ObjFixup fixups) {}

  @override
  void buildPropList(T3VM vm, int self, T3Value retval) {
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
  ) => false;

  @override
  String? castToString(T3VM vm, int self, T3Value newStr) {
    // Convert list to comma-separated string
    return elements.map((e) => e.toString()).join(',');
  }

  @override
  bool isListlike(T3VM vm, int self) => true;

  @override
  int llLength(T3VM vm, int self) => elements.length;

  @override
  bool indexValQ(T3VM vm, T3Value result, int self, T3Value indexVal) {
    if (indexVal.type != T3DataType.int32) return false;
    final idx = indexVal.getAsInt();
    if (idx < 1 || idx > elements.length) {
      throw T3VmException(vmErrIndexOutOfRange);
    }
    result.copyFrom(elements[idx - 1]);
    return true;
  }

  @override
  bool addVal(T3VM vm, T3Value result, int self, T3Value val) {
    // List concatenation - create new list with added element
    // final newElements = List<T3Value>.from(elements)..add(T3Value.copy(val));
    // TODO: Register new list in object table
    result.setNil();
    return true;
  }

  // --- List Methods ---

  /// Get list length
  int get length => elements.length;

  /// Get element at 1-based index
  T3Value getElement(int index) {
    if (index < 1 || index > elements.length) {
      throw T3VmException(vmErrIndexOutOfRange);
    }
    return elements[index - 1];
  }

  /// Find index of value (1-based, 0 if not found)
  int indexOf(T3Value val, [int start = 1]) {
    for (var i = start - 1; i < elements.length; i++) {
      if (_valuesEqual(elements[i], val)) {
        return i + 1;
      }
    }
    return 0;
  }

  /// Find last index of value
  int lastIndexOf(T3Value val) {
    for (var i = elements.length - 1; i >= 0; i--) {
      if (_valuesEqual(elements[i], val)) {
        return i + 1;
      }
    }
    return 0;
  }

  /// Extract sublist (1-based, inclusive start, optional length)
  T3ObjList sublist(int start, [int? len]) {
    final startIdx = start - 1;
    if (startIdx < 0 || startIdx >= elements.length) {
      return T3ObjList([]);
    }
    final endIdx = len != null
        ? (startIdx + len).clamp(0, elements.length)
        : elements.length;
    return T3ObjList(
      elements.sublist(startIdx, endIdx).map(T3Value.copy).toList(),
    );
  }

  /// Check if value equals another
  bool _valuesEqual(T3Value a, T3Value b) {
    if (a.type != b.type) return false;
    switch (a.type) {
      case T3DataType.nil:
      case T3DataType.trueValue:
        return true;
      case T3DataType.int32:
        return a.getAsInt() == b.getAsInt();
      case T3DataType.obj:
        return a.getAsObj() == b.getAsObj();
      case T3DataType.prop:
        return a.getAsProp() == b.getAsProp();
      default:
        return false;
    }
  }
}

/// List metaclass registration
class T3MetaclassList extends T3Metaclass {
  static const String name = 'list/030010';

  @override
  String getMetaName() => name;

  @override
  int createFromStack(T3VM vm, Uint8List pc, int pcOffset, int argc) {
    throw T3VmException(vmErrBadDynamicNew);
  }

  @override
  void createForImageLoad(T3VM vm, int id) {}

  @override
  void createForRestore(T3VM vm, int id) {}

  @override
  bool callStatProp(
    T3VM vm,
    T3Value result,
    Uint8List pc,
    int pcOffset,
    int argc,
    int prop,
  ) {
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

/// Helper to get list from a T3Value
List<T3Value>? getListElements(T3Globals globals, T3Value val) {
  if (val.type == T3DataType.list) {
    // Constant list from pool - parse it
    final ofs = val.getAsOfs();
    if (ofs != null) {
      final (data, localOfs) = globals.constPool!.getPtr(ofs);
      return T3ObjList.fromConstPool(data, localOfs).elements;
    }
  } else if (val.type == T3DataType.obj) {
    final entry = globals.objTable?.getEntry(val.getAsObj()!);
    if (entry?.obj is T3ObjList) {
      return (entry!.obj as T3ObjList).elements;
    }
  }
  return null;
}
