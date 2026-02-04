// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// TADS3 Vector Metaclass
///
/// Implements the Vector metaclass (vmvec.cpp), which provides mutable lists.
/// Unlike lists, vectors can be modified in place and resized.
library;

import 'dart:typed_data';
import 'package:zart/src/tads3/vm/t3_collection.dart';
import 'package:zart/src/tads3/vm/t3_error.dart';
import 'package:zart/src/tads3/vm/t3_list.dart';
import 'package:zart/src/tads3/vm/t3_iter.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';

/// Vector object - mutable collection of T3Values.
class T3ObjVector extends T3Collection {
  /// The current element count
  int _elementCount = 0;

  /// The allocated slots
  final List<T3Value> _elements;

  /// Metaclass registration object
  static final T3MetaclassVector metaclassReg = T3MetaclassVector();

  /// Create a vector with initial allocated capacity
  T3ObjVector([int capacity = 0])
    : _elements = List<T3Value>.generate(
        capacity,
        (_) => T3Value(T3DataType.nil),
      );

  /// Initialize the extension with allocation size
  void initHeader({int allocSize = 0}) {
    while (_elements.length < allocSize) {
      _elements.add(T3Value(T3DataType.nil));
    }
  }

  /// Set the number of elements in use
  void setElementCount(int count) {
    if (count > _elements.length) {
      _expandBy(count - _elements.length);
    }
    _elementCount = count;
  }

  /// Get the current number of elements
  int get length => _elementCount;

  /// Get an element at the given 1-based index
  T3Value getElement(int index) {
    if (index < 1 || index > _elementCount) {
      throw T3VmException(vmErrIndexOutOfRange);
    }
    return _elements[index - 1];
  }

  /// Set an element at the given 1-based index
  void setElement(int index, T3Value val) {
    if (index < 1 || index > _elementCount) {
      throw T3VmException(vmErrIndexOutOfRange);
    }
    _elements[index - 1].copyFrom(val);
  }

  @override
  T3Metaclass getMetaclassReg() => metaclassReg;

  @override
  void notifyDelete(T3VM vm, bool inRootSet) {
    // No special cleanup needed for Dart implementation
  }

  @override
  void newIterator(T3VM vm, T3Value retval, T3Value selfVal) {
    // For a snapshot iterator on a mutable collection, we create a copy
    // as an immutable list.
    final snapshot = T3ObjList(
      List<T3Value>.from(
        _elements.sublist(0, _elementCount).map((v) => T3Value.copy(v)),
      ),
    );

    // We need to allocate an ID for the snapshot list if we want to pass it
    // in a T3Value.
    final id = vm.objTable!.allocObj(vm, true);
    vm.objTable!.getEntry(id)!.obj = snapshot;

    retval.setObj(
      T3ObjIterIdx.createForColl(vm, T3Value()..setObj(id), 1, _elementCount),
    );
  }

  @override
  void newLiveIterator(T3VM vm, T3Value retval, T3Value selfVal) {
    // For a live iterator, we use the vector itself.
    retval.setObj(T3ObjIterIdx.createForColl(vm, selfVal, 1, _elementCount));
  }

  @override
  bool isInstanceOf(T3VM vm, int obj) => false;

  @override
  int getSuperclass(T3VM vm, int self, int index) => invalidObj;

  @override
  void setProp(T3VM vm, T3Undo? undo, int self, int propId, T3Value val) {
    // Vectors don't have standard properties
    throw T3VmException(vmErrInvalidSetprop);
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
    final selfVal = T3Value()..setObj(self);
    if (constGetCollProp(vm, propId, retval, selfVal, sourceObj, argc)) {
      return true;
    }

    sourceObj[0] = self;
    return _evalProp(vm, propId, retval, self, argc);
  }

  bool _evalProp(T3VM vm, int propId, T3Value retval, int self, int? argc) {
    switch (propId) {
      case 1: // toList
        return _getpToList(vm, retval, argc);
      case 2: // getSize
        return _getpGetSize(vm, retval, argc);
      case 3: // copyFrom
        return _getpCopyFrom(vm, retval, self, argc);
      case 4: // fillVal
        return _getpFillVal(vm, retval, self, argc);
      case 5: // subset
        return _getpSubset(vm, retval, self, argc);
      case 11: // indexOf
        return _getpIndexOf(vm, retval, argc);
      case 13: // lastIndexOf
        return _getpLastIndexOf(vm, retval, argc);
      case 21: // setLength
        return _getpSetLength(vm, retval, self, argc);
      case 22: // insertAt
        return _getpInsertAt(vm, retval, self, argc);
      case 23: // removeElementAt
        return _getpRemoveElementAt(vm, retval, self, argc);
      case 25: // append
        return _getpAppend(vm, retval, self, argc);
      case 26: // prepend
        return _getpPrepend(vm, retval, self, argc);
      case 27: // appendAll
        return _getpAppendAll(vm, retval, self, argc);
      default:
        return false;
    }
  }

  bool _getpSubset(T3VM vm, T3Value retval, int self, int? argc) {
    _checkArgs(argc, 2);
    final start = vm.stack.pop().getAsInt();
    final count = vm.stack.pop().getAsInt();

    // TADS3 subset: start 1-based, count elements
    var startIdx = start;
    if (startIdx < 0) startIdx += _elementCount + 1;
    if (startIdx < 1) startIdx = 1;

    var endIdx = startIdx + count - 1;
    if (endIdx > _elementCount) endIdx = _elementCount;

    final newElements = <T3Value>[];
    if (startIdx <= _elementCount) {
      for (var i = startIdx; i <= endIdx; i++) {
        newElements.add(T3Value.copy(_elements[i - 1]));
      }
    }

    final vec = T3ObjVector(newElements.length);
    vec.setElementCount(newElements.length);
    for (var i = 0; i < newElements.length; i++) {
      vec._elements[i].copyFrom(newElements[i]);
    }

    retval.setObj(vm.objTable.registerObj(vec));
    return true;
  }

  bool _getpIndexOf(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 1);
    final val = vm.stack.pop();
    for (var i = 0; i < _elementCount; i++) {
      if (_elements[i].testEquality(vm, val, 0)) {
        retval.setInt(i + 1);
        return true;
      }
    }
    retval.setNil();
    return true;
  }

  bool _getpLastIndexOf(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 1);
    final val = vm.stack.pop();
    for (var i = _elementCount - 1; i >= 0; i--) {
      if (_elements[i].testEquality(vm, val, 0)) {
        retval.setInt(i + 1);
        return true;
      }
    }
    retval.setNil();
    return true;
  }

  bool _getpSetLength(T3VM vm, T3Value retval, int self, int? argc) {
    _checkArgs(argc, 1);
    final newLen = vm.stack.pop().getAsInt();
    setElementCount(newLen);
    retval.setObj(self);
    return true;
  }

  bool _getpInsertAt(T3VM vm, T3Value retval, int self, int? argc) {
    _checkArgs(argc, 2, 100); // 2 or more args
    if (argc == null) return false;
    final idx = vm.stack.pop().getAsInt();
    var insertIdx = idx;
    if (insertIdx < 0) insertIdx += _elementCount + 1;
    if (insertIdx < 1) insertIdx = 1;
    if (insertIdx > _elementCount + 1) insertIdx = _elementCount + 1;

    final vals = <T3Value>[];
    for (var i = 1; i < argc; i++) {
      vals.add(vm.stack.pop());
    }

    for (var i = 0; i < vals.length; i++) {
      final insertPos = insertIdx - 1 + i;
      if (insertPos < _elementCount) {
        _elements.insert(insertPos, T3Value.copy(vals[i]));
      } else {
        // Appending at the end
        if (insertPos < _elements.length) {
          _elements[insertPos].copyFrom(vals[i]);
        } else {
          _elements.add(T3Value.copy(vals[i]));
        }
      }
    }
    _elementCount += vals.length;

    retval.setObj(self);
    return true;
  }

  bool _getpRemoveElementAt(T3VM vm, T3Value retval, int self, int? argc) {
    _checkArgs(argc, 1);
    final idx = vm.stack.pop().getAsInt();
    var removeIdx = idx;
    if (removeIdx < 0) removeIdx += _elementCount + 1;
    if (removeIdx < 1 || removeIdx > _elementCount) {
      throw T3VmException(vmErrIndexOutOfRange);
    }

    _elements.removeAt(removeIdx - 1);
    // If we want to keep capacity, we should add a nil at the end?
    // Actually, TADS3 vectors just shrink the element count.
    _elementCount--;

    retval.setObj(self);
    return true;
  }

  bool _getpAppend(T3VM vm, T3Value retval, int self, int? argc) {
    if (argc == null) return false;
    for (var i = 0; i < argc; i++) {
      final val = vm.stack.pop();
      if (_elementCount < _elements.length) {
        _elements[_elementCount].copyFrom(val);
      } else {
        _elements.add(T3Value.copy(val));
      }
      _elementCount++;
    }
    retval.setObj(self);
    return true;
  }

  bool _getpPrepend(T3VM vm, T3Value retval, int self, int? argc) {
    if (argc == null) return false;
    for (var i = 0; i < argc; i++) {
      final val = vm.stack.pop();
      _elements.insert(0, T3Value.copy(val));
      _elementCount++;
    }
    retval.setObj(self);
    return true;
  }

  bool _getpAppendAll(T3VM vm, T3Value retval, int self, int? argc) {
    _checkArgs(argc, 1);
    final val = vm.stack.pop();
    if (val.type == T3DataType.list) {
      // TODO: Handle constant list pointers from pool
    } else if (val.type == T3DataType.obj) {
      final obj = vm.objTable.getObj(val.getAsObj());
      if (obj is T3ObjList) {
        for (final e in obj.elements) {
          if (_elementCount < _elements.length) {
            _elements[_elementCount].copyFrom(e);
          } else {
            _elements.add(T3Value.copy(e));
          }
          _elementCount++;
        }
      } else if (obj is T3ObjVector) {
        for (var i = 0; i < obj._elementCount; i++) {
          final e = obj._elements[i];
          if (_elementCount < _elements.length) {
            _elements[_elementCount].copyFrom(e);
          } else {
            _elements.add(T3Value.copy(e));
          }
          _elementCount++;
        }
      }
    }
    retval.setObj(self);
    return true;
  }

  bool _getpToList(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 0);
    // Create new T3Value objects for the list to ensure immutability
    final listElements = List<T3Value>.generate(
      _elementCount,
      (i) => T3Value.copy(_elements[i]),
    );
    final listObj = T3ObjList(listElements);
    final id = vm.objTable.registerObj(listObj);
    retval.setObj(id);
    return true;
  }

  bool _getpGetSize(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 0);
    retval.setInt(_elementCount);
    return true;
  }

  bool _getpCopyFrom(T3VM vm, T3Value retval, int self, int? argc) {
    _checkArgs(argc, 3, 4);
    final srcObjVal = vm.stack.pop();
    final srcStart = vm.stack.pop().getAsInt();
    final dstStart = vm.stack.pop().getAsInt();
    final countArg = (argc == 4) ? vm.stack.pop().getAsInt() : null;

    final srcObj = vm.objTable.getObj(srcObjVal.getAsObj());
    if (srcObj is! T3ObjVector) throw T3VmException(vmErrInvalObjType);

    var srcS = srcStart;
    var dstS = dstStart;
    var srcCnt = srcObj._elementCount;
    var dstCnt = _elementCount;

    if (srcS < 0) srcS += srcCnt + 1;
    if (dstS < 0) dstS += dstCnt + 1;
    if (srcS < 1) srcS = 1;
    if (dstS < 1) dstS = 1;

    var copyCnt = countArg ?? srcCnt;
    if (srcS > srcCnt) {
      copyCnt = 0;
    } else if (srcS + copyCnt - 1 > srcCnt) {
      copyCnt = srcCnt - srcS + 1;
    }

    if (dstS + copyCnt - 1 > dstCnt) {
      setElementCount(dstS + copyCnt - 1);
    }

    for (var i = 0; i < copyCnt; i++) {
      _elements[dstS - 1 + i].copyFrom(srcObj._elements[srcS - 1 + i]);
    }

    retval.setObj(self);
    return true;
  }

  bool _getpFillVal(T3VM vm, T3Value retval, int self, int? argc) {
    _checkArgs(argc, 1, 3);
    final val = vm.stack.pop();
    final startArg = (argc != null && argc >= 2)
        ? vm.stack.pop().getAsInt()
        : 1;
    final countArg = (argc != null && argc >= 3)
        ? vm.stack.pop().getAsInt()
        : null;

    var start = startArg;
    if (start < 0) start += _elementCount + 1;
    if (start < 1) start = 1;

    var count = countArg ?? (_elementCount - start + 1);
    if (count < 0) count = 0;

    if (start + count - 1 > _elementCount) {
      setElementCount(start + count - 1);
    }

    for (var i = 0; i < count; i++) {
      _elements[start - 1 + i].copyFrom(val);
    }

    retval.setObj(self);
    return true;
  }

  void _checkArgs(int? argc, int min, [int? max]) {
    if (argc == null) return;
    if (argc < min || (max != null && argc > max)) {
      throw T3VmException(vmErrWrongNumOfArgs);
    }
  }

  @override
  bool isListlike(T3VM vm, int self) => true;

  @override
  int llLength(T3VM vm, int self) => _elementCount;

  @override
  bool indexValQ(T3VM vm, T3Value result, int self, T3Value indexVal) {
    if (indexVal.type != T3DataType.int32) return false;
    final idx = indexVal.getAsInt();
    if (idx < 1 || idx > _elementCount) {
      throw T3VmException(vmErrIndexOutOfRange);
    }
    result.copyFrom(_elements[idx - 1]);
    return true;
  }

  @override
  bool setIndexValQ(
    T3VM vm,
    T3Value result,
    int self,
    T3Value indexVal,
    T3Value val,
  ) {
    if (indexVal.type != T3DataType.int32) return false;
    final idx = indexVal.getAsInt();
    if (idx < 1 || idx > _elementCount) {
      // If indexing beyond current length, TADS3 vectors often allow resizing depending on context
      if (idx == _elementCount + 1) {
        _expandBy(1);
      } else {
        throw T3VmException(vmErrIndexOutOfRange);
      }
    }

    // Save undo if possible
    // TODO: undo?.saveRes(self, idx, _elements[idx - 1]);

    _elements[idx - 1].copyFrom(val);
    result.copyFrom(val);
    return true;
  }

  void _expandBy(int count) {
    // Simple expansion for now
    for (var i = 0; i < count; i++) {
      _elements.add(T3Value(T3DataType.nil));
    }
    _elementCount += count;
  }

  @override
  void loadFromImage(T3VM vm, int self, Uint8List ptr, int offset, int size) {
    // CVmObjVector::load_image_data(VMG_ const char *ptr, size_t siz)
    // ptr[0-1]: allocation count (UINT2)
    // ptr[2-3]: element count (UINT2)
    // ptr[4...]: element dataholders

    final allocCnt = ptr[offset] | (ptr[offset + 1] << 8);
    final eleCnt = ptr[offset + 2] | (ptr[offset + 3] << 8);

    initHeader(allocSize: allocCnt);
    setElementCount(eleCnt);

    // Each dataholder is 1 byte type + 4 bytes value
    var pos = offset + 4;
    for (var i = 0; i < eleCnt; i++) {
      _elements[i].type = T3DataType.values[ptr[pos]];
      vmbGetDhVal(ptr, pos, _elements[i]);
      pos += 5;
    }
  }

  @override
  void markRefs(T3VM vm, int state) {
    for (var i = 0; i < _elementCount; i++) {
      final val = _elements[i];
      if (val.type == T3DataType.obj && val.getAsObj() != null) {
        // TODO: Mark object
      }
    }
  }

  @override
  void applyUndo(T3VM vm, T3UndoRecord rec) {
    // TODO: Apply element or size change undo
  }

  @override
  void markUndoRef(T3VM vm, T3UndoRecord rec) {
    // TODO: Mark object references in undo record
  }

  @override
  void removeStaleUndoWeakRef(T3VM vm, T3UndoRecord rec) {}

  @override
  void removeStaleWeakRefs(T3VM vm) {}

  @override
  void saveToFile(T3VM vm, T3File fp) {
    // TODO
  }

  @override
  void restoreFromFile(T3VM vm, int self, T3File fp, T3ObjFixup fixups) {
    // TODO
  }

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
    // Match T3ObjList implementation for now
    return _elements.take(_elementCount).map((e) => e.toString()).join(',');
  }
}

/// Vector metaclass registration
class T3MetaclassVector extends T3Metaclass {
  static const String name = 'vector/030005';

  @override
  String getMetaName() => name;

  @override
  int createFromStack(T3VM vm, Uint8List pc, int pcOffset, int argc) {
    int initialSize = 0;
    int allocSize = 0;
    List<T3Value>? fromList;

    if (argc >= 1) {
      final arg1 = vm.stack.pop();
      if (arg1.type == T3DataType.int32) {
        initialSize = arg1.getAsInt();
      } else if (arg1.type == T3DataType.list) {
        // Constant list from pool
        // We'd need to parse it or have T3ObjList handle it.
        // For now, let's assume T3ObjList can be created from pool data.
        // TODO: Properly handle constant list pointers.
      } else if (arg1.type == T3DataType.obj) {
        final obj = vm.objTable.getObj(arg1.getAsObj());
        if (obj is T3ObjList) {
          fromList = obj.elements;
          initialSize = fromList.length;
        }
      }
    }

    if (argc >= 2) {
      final arg2 = vm.stack.pop();
      if (arg2.type == T3DataType.int32) {
        allocSize = arg2.getAsInt();
      }
    }

    if (allocSize < initialSize) allocSize = initialSize;

    final vec = T3ObjVector(allocSize);
    if (fromList != null) {
      for (var i = 0; i < fromList.length; i++) {
        vec._elements[i].copyFrom(fromList[i]);
      }
      vec._elementCount = fromList.length;
    } else {
      vec.setElementCount(initialSize);
    }

    return vm.objTable.registerObj(vec);
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
    if (prop == 5) {
      // generate
      return _getpGenerate(vm, result, argc);
    }
    return false;
  }

  bool _getpGenerate(T3VM vm, T3Value result, int argc) {
    // TODO: Implement static generate(func, n)
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
