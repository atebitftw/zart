// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// TADS3 LookupTable Metaclass
///
/// LookupTable is a hash table that maps arbitrary keys to values.
/// It uses separate chaining for collision resolution and supports
/// dynamic resizing.
///
/// Ported from: packages/tads-runner/tads3/vmlookup.cpp
///              packages/tads-runner/tads3/vmlookup.h
library;

import 'dart:typed_data';

import 'package:zart/src/tads3/vm/t3_collection.dart';
import 'package:zart/src/tads3/vm/t3_error.dart';
import 'package:zart/src/tads3/vm/t3_iter.dart';
import 'package:zart/src/tads3/vm/t3_list.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';

/// Default bucket count for new LookupTables.
const int _defaultBucketCount = 32;

/// Default initial capacity for new LookupTables.
const int _defaultInitCapacity = 64;

/// Property indices for LookupTable.
const int _propIdxKeyPresent = 1;
const int _propIdxRemoveEntry = 2;
const int _propIdxApplyAll = 3;
const int _propIdxForEach = 4;
const int _propIdxCountBuckets = 5;
const int _propIdxCountEntries = 6;
const int _propIdxForEachAssoc = 7;
const int _propIdxKeysToList = 8;
const int _propIdxValsToList = 9;
const int _propIdxGetDefVal = 10;
const int _propIdxSetDefVal = 11;
const int _propIdxNthKey = 12;
const int _propIdxNthVal = 13;

/// Entry in the lookup table.
class _LookupEntry {
  /// The key.
  final T3Value key = T3Value();

  /// The value.
  final T3Value val = T3Value();

  /// Index of next entry in chain, or -1 if this is the last entry.
  int nextIdx = -1;

  /// Whether this entry is in use (not on the free list).
  bool get inUse => key.type != T3DataType.empty;

  /// Mark this entry as free.
  void markFree() {
    key.setEmpty();
    val.setEmpty();
  }
}

/// LookupTable metaclass.
class T3ObjLookupTable extends T3Collection {
  /// Metaclass registration.
  static final T3MetaclassLookupTable metaclassReg = T3MetaclassLookupTable();

  /// Number of hash buckets.
  int _bucketCount;

  /// Bucket heads - each is an index into _entries, or -1 if empty.
  late List<int> _buckets;

  /// Pool of entries.
  late List<_LookupEntry> _entries;

  /// Index of first free entry, or -1 if none.
  int _firstFreeIdx = -1;

  /// Default value for missing keys.
  final T3Value _defaultValue = T3Value()..setNil();

  /// Create a new LookupTable with specified bucket count and capacity.
  T3ObjLookupTable(int bucketCount, int capacity) : _bucketCount = bucketCount {
    // Allocate buckets
    _buckets = List<int>.filled(bucketCount, -1);

    // Allocate entry pool
    _entries = List<_LookupEntry>.generate(capacity, (_) => _LookupEntry());

    // Initialize free list
    _initFreeList();
  }

  /// Create with default parameters.
  factory T3ObjLookupTable.withDefaults() {
    return T3ObjLookupTable(_defaultBucketCount, _defaultInitCapacity);
  }

  /// Initialize the free list linking all entries.
  void _initFreeList() {
    if (_entries.isEmpty) {
      _firstFreeIdx = -1;
      return;
    }

    _firstFreeIdx = 0;
    for (var i = 0; i < _entries.length; i++) {
      _entries[i].markFree();
      _entries[i].nextIdx = (i + 1 < _entries.length) ? i + 1 : -1;
    }
  }

  /// Create from stack arguments.
  static int createFromStack(T3VM vm, int argc) {
    int bucketCount;
    int initCapacity;
    T3Value? srcList;

    if (argc == 0) {
      bucketCount = _defaultBucketCount;
      initCapacity = _defaultInitCapacity;
    } else if (argc == 1) {
      srcList = vm.stack.popVal();
      bucketCount = _defaultBucketCount;
      initCapacity = _defaultInitCapacity;
    } else if (argc == 2) {
      // Stack has: [bucketCount, initCapacity] (top)
      initCapacity = _tryGetInt(vm.stack.popVal()) ?? _defaultInitCapacity;
      bucketCount = _tryGetInt(vm.stack.popVal()) ?? _defaultBucketCount;
    } else {
      throw T3VmException(vmErrWrongNumOfArgs);
    }

    if (bucketCount <= 0) bucketCount = _defaultBucketCount;
    if (initCapacity <= 0) initCapacity = _defaultInitCapacity;

    final obj = T3ObjLookupTable(bucketCount, initCapacity);

    if (srcList != null && srcList.type != T3DataType.nil) {
      // TODO: Populate from list
    }

    return vm.objTable.registerObj(obj, false);
  }

  static int? _tryGetInt(T3Value val) {
    try {
      return val.getAsInt();
    } catch (_) {
      return null;
    }
  }

  @override
  T3Metaclass getMetaclassReg() => metaclassReg;

  @override
  bool isOfMetaclass(T3Metaclass meta) {
    return meta == metaclassReg || super.isOfMetaclass(meta);
  }

  // -------------------------------------------------------------------------
  // T3Object abstract method implementations
  // -------------------------------------------------------------------------

  @override
  void notifyDelete(T3VM vm, bool inRootSet) {}

  @override
  bool isInstanceOf(T3VM vm, int obj) => false;

  @override
  int getSuperclass(T3VM vm, int self, int index) => invalidObj;

  @override
  void setProp(T3VM vm, T3Undo? undo, int self, int propId, T3Value val) {
    throw T3VmException(vmErrInvalidSetprop);
  }

  @override
  void buildPropList(T3VM vm, int self, T3Value retval) {
    retval.setNil();
  }

  @override
  void markRefs(T3VM vm, int state) {
    if (_defaultValue.type == T3DataType.obj && _defaultValue.getAsObj() != null) {
      // TODO: Mark ref
    }
    for (final entry in _entries) {
      if (entry.inUse) {
        if (entry.key.type == T3DataType.obj && entry.key.getAsObj() != null) {
          // TODO: Mark ref
        }
        if (entry.val.type == T3DataType.obj && entry.val.getAsObj() != null) {
          // TODO: Mark ref
        }
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
  String? castToString(T3VM vm, int self, T3Value newStr) => null;

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
  void newIterator(T3VM vm, T3Value retval, T3Value selfVal) {
    // Create a copy of ourselves for snapshot iteration
    final copy = _createCopy(vm);
    final copyVal = T3Value()..setObj(copy);
    // Create iterator on the copy
    final iterId = T3ObjIterLookupTable.createForColl(vm, copyVal);
    retval.setObj(iterId);
  }

  @override
  void newLiveIterator(T3VM vm, T3Value retval, T3Value selfVal) {
    // Create iterator directly on ourselves
    final iterId = T3ObjIterLookupTable.createForColl(vm, selfVal);
    retval.setObj(iterId);
  }

  /// Create a copy of this lookup table.
  int _createCopy(T3VM vm) {
    final copy = T3ObjLookupTable(_bucketCount, _entries.length);
    // Copy all entries
    for (var i = 0; i < _bucketCount; i++) {
      copy._buckets[i] = _buckets[i];
    }
    for (var i = 0; i < _entries.length; i++) {
      copy._entries[i].key.copyFrom(_entries[i].key);
      copy._entries[i].val.copyFrom(_entries[i].val);
      copy._entries[i].nextIdx = _entries[i].nextIdx;
    }
    copy._firstFreeIdx = _firstFreeIdx;
    copy._defaultValue.copyFrom(_defaultValue);
    return vm.objTable.registerObj(copy, false);
  }

  // -------------------------------------------------------------------------
  // Core Operations
  // -------------------------------------------------------------------------

  int get bucketCount => _bucketCount;
  int get capacity => _entries.length;
  int get entryCount {
    var count = 0;
    for (final entry in _entries) {
      if (entry.inUse) count++;
    }
    return count;
  }

  T3Value get defaultValue => _defaultValue;

  void setDefaultValue(T3Value val) {
    _defaultValue.copyFrom(val);
  }

  int _calcKeyHash(T3Value key) {
    final hash = key.calcHash();
    return hash % _bucketCount;
  }

  int _findEntry(T3Value key, {void Function(int)? onPrevIdx}) {
    final hash = _calcKeyHash(key);
    var prevIdx = -1;
    var idx = _buckets[hash];
    while (idx >= 0) {
      final entry = _entries[idx];
      if (entry.key.equals(key)) {
        onPrevIdx?.call(prevIdx);
        return idx;
      }
      prevIdx = idx;
      idx = entry.nextIdx;
    }
    return -1;
  }

  bool isKeyPresent(T3Value key) => _findEntry(key) >= 0;

  T3Value getValue(T3Value key) {
    final idx = _findEntry(key);
    return idx >= 0 ? _entries[idx].val : _defaultValue;
  }

  void setOrAddEntry(T3Value key, T3Value val) {
    final idx = _findEntry(key);
    if (idx >= 0) {
      _entries[idx].val.copyFrom(val);
    } else {
      _addEntryInternal(key, val);
    }
  }

  void _addEntryInternal(T3Value key, T3Value val) {
    final hash = _calcKeyHash(key);
    final idx = _allocEntry();
    final entry = _entries[idx];
    entry.key.copyFrom(key);
    entry.val.copyFrom(val);
    entry.nextIdx = _buckets[hash];
    _buckets[hash] = idx;
  }

  int _allocEntry() {
    if (_firstFreeIdx < 0) _expandEntries();
    final idx = _firstFreeIdx;
    _firstFreeIdx = _entries[idx].nextIdx;
    _entries[idx].nextIdx = -1;
    return idx;
  }

  void _expandEntries() {
    var newCount = _entries.length + (_entries.length >> 1);
    if (newCount < _entries.length + 16) newCount = _entries.length + 16;
    final oldCount = _entries.length;
    _entries = List<_LookupEntry>.generate(newCount, (i) => i < oldCount ? _entries[i] : _LookupEntry());
    _firstFreeIdx = oldCount;
    for (var i = oldCount; i < newCount; i++) {
      _entries[i].markFree();
      _entries[i].nextIdx = (i + 1 < newCount) ? i + 1 : -1;
    }
  }

  bool removeEntry(T3Value key) {
    final hash = _calcKeyHash(key);
    var prevIdx = -1;
    var idx = _buckets[hash];
    while (idx >= 0) {
      final entry = _entries[idx];
      if (entry.key.equals(key)) {
        if (prevIdx >= 0) {
          _entries[prevIdx].nextIdx = entry.nextIdx;
        } else {
          _buckets[hash] = entry.nextIdx;
        }
        entry.markFree();
        entry.nextIdx = _firstFreeIdx;
        _firstFreeIdx = idx;
        return true;
      }
      prevIdx = idx;
      idx = entry.nextIdx;
    }
    return false;
  }

  void forEach(void Function(T3Value key, T3Value val) callback) {
    for (var i = 0; i < _bucketCount; i++) {
      var idx = _buckets[i];
      while (idx >= 0) {
        final entry = _entries[idx];
        callback(entry.key, entry.val);
        idx = entry.nextIdx;
      }
    }
  }

  T3Value getNthKey(int n) {
    if (n <= 0) return T3Value()..setNil();
    var count = 0;
    for (var i = 0; i < _bucketCount; i++) {
      var idx = _buckets[i];
      while (idx >= 0) {
        if (++count == n) return _entries[idx].key;
        idx = _entries[idx].nextIdx;
      }
    }
    throw T3VmException(vmErrIndexOutOfRange);
  }

  T3Value getNthVal(int n) {
    if (n <= 0) return _defaultValue;
    var count = 0;
    for (var i = 0; i < _bucketCount; i++) {
      var idx = _buckets[i];
      while (idx >= 0) {
        if (++count == n) return _entries[idx].val;
        idx = _entries[idx].nextIdx;
      }
    }
    throw T3VmException(vmErrIndexOutOfRange);
  }

  // -------------------------------------------------------------------------
  // Property Evaluators
  // -------------------------------------------------------------------------

  @override
  bool getProp(T3VM vm, int propId, T3Value retval, int self, List<int> sourceObj, int? argc) {
    final funcIdx = vm.metaTable.propToVectorIdx(metaclassReg.getRegIdx(), propId);
    if (funcIdx != null && funcIdx >= 1 && funcIdx <= _propIdxNthVal) {
      sourceObj[0] = self;
      switch (funcIdx) {
        case _propIdxKeyPresent:
          return getpKeyPresent(vm, retval, argc ?? 0);
        case _propIdxRemoveEntry:
          return getpRemoveEntry(vm, retval, argc ?? 0);
        case _propIdxApplyAll:
          return getpApplyAll(vm, self, retval, argc ?? 0);
        case _propIdxForEach:
          return getpForEach(vm, retval, argc ?? 0);
        case _propIdxCountBuckets:
          return getpCountBuckets(vm, retval, argc ?? 0);
        case _propIdxCountEntries:
          return getpCountEntries(vm, retval, argc ?? 0);
        case _propIdxForEachAssoc:
          return getpForEachAssoc(vm, retval, argc ?? 0);
        case _propIdxKeysToList:
          return getpKeysToList(vm, retval, argc ?? 0);
        case _propIdxValsToList:
          return getpValsToList(vm, retval, argc ?? 0);
        case _propIdxGetDefVal:
          return getpGetDefVal(vm, retval, argc ?? 0);
        case _propIdxSetDefVal:
          return getpSetDefVal(vm, retval, argc ?? 0);
        case _propIdxNthKey:
          return getpNthKey(vm, retval, argc ?? 0);
        case _propIdxNthVal:
          return getpNthVal(vm, retval, argc ?? 0);
      }
    }

    // Check base collection properties
    if (constGetCollProp(vm, propId, retval, T3Value()..setObj(self), sourceObj, argc)) {
      return true;
    }

    return false;
  }

  bool getpKeyPresent(T3VM vm, T3Value retval, int argc) {
    if (argc != 1) throw T3VmException(vmErrWrongNumOfArgs);
    final key = vm.stack.popVal();
    retval.setLogical(isKeyPresent(key));
    return true;
  }

  bool getpRemoveEntry(T3VM vm, T3Value retval, int argc) {
    if (argc != 1) throw T3VmException(vmErrWrongNumOfArgs);
    final key = vm.stack.popVal();
    removeEntry(key);
    retval.setNil();
    return true;
  }

  bool getpApplyAll(T3VM vm, int self, T3Value retval, int argc) {
    if (argc != 1) throw T3VmException(vmErrWrongNumOfArgs);
    vm.stack.popVal(); // callback
    retval.setObj(self);
    return true;
  }

  bool getpForEach(T3VM vm, T3Value retval, int argc) {
    if (argc != 1) throw T3VmException(vmErrWrongNumOfArgs);
    vm.stack.popVal(); // callback
    retval.setNil();
    return true;
  }

  bool getpCountBuckets(T3VM vm, T3Value retval, int argc) {
    if (argc != 0) throw T3VmException(vmErrWrongNumOfArgs);
    retval.setInt(_bucketCount);
    return true;
  }

  bool getpCountEntries(T3VM vm, T3Value retval, int argc) {
    if (argc != 0) throw T3VmException(vmErrWrongNumOfArgs);
    retval.setInt(entryCount);
    return true;
  }

  bool getpForEachAssoc(T3VM vm, T3Value retval, int argc) {
    if (argc != 1) throw T3VmException(vmErrWrongNumOfArgs);
    vm.stack.popVal(); // callback
    retval.setNil();
    return true;
  }

  bool getpKeysToList(T3VM vm, T3Value retval, int argc) {
    if (argc != 0) throw T3VmException(vmErrWrongNumOfArgs);
    _makeList(vm, retval, storeKeys: true);
    return true;
  }

  bool getpValsToList(T3VM vm, T3Value retval, int argc) {
    if (argc != 0) throw T3VmException(vmErrWrongNumOfArgs);
    _makeList(vm, retval, storeKeys: false);
    return true;
  }

  /// Build a list of all keys or values in the table.
  void _makeList(T3VM vm, T3Value retval, {required bool storeKeys}) {
    // Collect all keys or values
    final items = <T3Value>[];
    forEach((key, val) {
      items.add(T3Value.copy(storeKeys ? key : val));
    });

    // Create list and register
    final list = T3ObjList(items);
    final listId = vm.objTable.registerObj(list, false);
    retval.setObj(listId);
  }

  bool getpGetDefVal(T3VM vm, T3Value retval, int argc) {
    if (argc != 0) throw T3VmException(vmErrWrongNumOfArgs);
    retval.copyFrom(_defaultValue);
    return true;
  }

  bool getpSetDefVal(T3VM vm, T3Value retval, int argc) {
    if (argc != 1) throw T3VmException(vmErrWrongNumOfArgs);
    final val = vm.stack.popVal();
    _defaultValue.copyFrom(val);
    retval.setNil();
    return true;
  }

  bool getpNthKey(T3VM vm, T3Value retval, int argc) {
    if (argc != 1) throw T3VmException(vmErrWrongNumOfArgs);
    final n = _tryGetInt(vm.stack.popVal()) ?? 0;
    retval.copyFrom(getNthKey(n));
    return true;
  }

  bool getpNthVal(T3VM vm, T3Value retval, int argc) {
    if (argc != 1) throw T3VmException(vmErrWrongNumOfArgs);
    final n = _tryGetInt(vm.stack.popVal()) ?? 0;
    retval.copyFrom(getNthVal(n));
    return true;
  }

  // -------------------------------------------------------------------------
  // Indexing and Comparison
  // -------------------------------------------------------------------------

  @override
  bool indexValQ(T3VM vm, T3Value result, int self, T3Value indexVal) {
    result.copyFrom(getValue(indexVal));
    return true;
  }

  @override
  bool setIndexValQ(T3VM vm, T3Value newContainer, int self, T3Value indexVal, T3Value newVal) {
    setOrAddEntry(indexVal, newVal);
    newContainer.setObj(self);
    return true;
  }

  @override
  bool equals(T3VM vm, int self, T3Value val, int depth) {
    if (val.type != T3DataType.obj) return false;
    final other = vm.objTable.getObj(val.getAsObj()!);
    if (other is! T3ObjLookupTable) return false;
    if (entryCount != other.entryCount) return false;
    var allEqual = true;
    forEach((k, v) {
      final otherIdx = other._findEntry(k);
      if (otherIdx < 0 || !v.equals(other._entries[otherIdx].val)) allEqual = false;
    });
    return allEqual;
  }

  @override
  int calcHash(T3VM vm, int self, int depth) {
    var hash = 0;
    forEach((k, v) {
      hash ^= k.calcHash(depth + 1);
      hash ^= v.calcHash(depth + 1);
    });
    return hash;
  }

  // -------------------------------------------------------------------------
  // Serialization
  // -------------------------------------------------------------------------

  @override
  void loadFromImage(T3VM vm, int self, Uint8List ptr, int offset, int size) {
    final view = ByteData.sublistView(ptr, offset, offset + size);
    final bucketCnt = view.getUint16(0, Endian.little);
    final valCnt = view.getUint16(2, Endian.little);
    final firstFreeImgIdx = view.getUint16(4, Endian.little);

    _bucketCount = bucketCnt;
    _buckets = List<int>.filled(bucketCnt, -1);
    _entries = List<_LookupEntry>.generate(valCnt, (_) => _LookupEntry());

    var pos = 6;
    for (var i = 0; i < bucketCnt; i++) {
      _buckets[i] = _imgIdxToEntryIdx(view.getUint16(pos, Endian.little));
      pos += 2;
    }

    for (var i = 0; i < valCnt; i++) {
      final entry = _entries[i];
      // Key
      entry.key.type = vmbGetDhType(ptr, offset + pos);
      vmbGetDhVal(ptr, offset + pos, entry.key);
      pos += 5;
      // Value
      entry.val.type = vmbGetDhType(ptr, offset + pos);
      vmbGetDhVal(ptr, offset + pos, entry.val);
      pos += 5;
      // Next
      entry.nextIdx = _imgIdxToEntryIdx(view.getUint16(pos, Endian.little));
      pos += 2;
    }
    _firstFreeIdx = _imgIdxToEntryIdx(firstFreeImgIdx);
    if (pos + 5 <= size) {
      _defaultValue.type = vmbGetDhType(ptr, offset + pos);
      vmbGetDhVal(ptr, offset + pos, _defaultValue);
    } else {
      _defaultValue.setNil();
    }
  }

  int _imgIdxToEntryIdx(int imgIdx) => imgIdx == 0 ? -1 : imgIdx - 1;
}

/// LookupTable metaclass registration.
class T3MetaclassLookupTable extends T3Metaclass {
  static const String name = 'lookuptable/030003';

  @override
  String getMetaName() => name;

  @override
  int createFromStack(T3VM vm, Uint8List pc, int pcOffset, int argc) {
    return T3ObjLookupTable.createFromStack(vm, argc);
  }

  @override
  void createForImageLoad(T3VM vm, int id) {
    vm.objTable.setObj(id, T3ObjLookupTable.withDefaults());
  }

  @override
  void createForRestore(T3VM vm, int id) {
    vm.objTable.setObj(id, T3ObjLookupTable.withDefaults());
  }

  @override
  bool callStatProp(T3VM vm, T3Value result, Uint8List pc, int pcOffset, int argc, int prop) => false;

  @override
  int getSupermeta(T3VM vm, int idx) => invalidObj;

  @override
  bool isMetaInstanceOf(T3VM vm, int obj) => false;

  @override
  T3Metaclass? getSupermetaReg() => null;

  @override
  int getClassObj(T3VM vm) => invalidObj;
}

// -----------------------------------------------------------------------------
// LookupTable Iterator
// -----------------------------------------------------------------------------

/// LookupTable iterator metaclass.
class T3ObjIterLookupTable extends T3ObjIter {
  /// Metaclass registration.
  static final T3MetaclassIterLookupTable metaclassReg = T3MetaclassIterLookupTable();

  @override
  T3Metaclass getMetaclassReg() => metaclassReg;

  @override
  bool isOfMetaclass(T3Metaclass meta) {
    return meta == metaclassReg || super.isOfMetaclass(meta);
  }

  /// Reference to the lookup table collection.
  final T3Value _collectionValue;

  /// Current entry index (1-based into entries pool, 0 = before first).
  int _curIndex = 0;

  /// Flags.
  int _flags = 0;

  static const int _flagUndo = 0x0001;

  /// Create an iterator for a lookup table collection.
  T3ObjIterLookupTable(T3Value collVal) : _collectionValue = T3Value.copy(collVal);

  /// Create iterator for a collection and register it.
  static int createForColl(T3VM vm, T3Value coll) {
    final iter = T3ObjIterLookupTable(coll);
    return vm.objTable.registerObj(iter, false);
  }

  /// Get the lookup table object.
  T3ObjLookupTable? _getLookupTable(T3VM vm) {
    if (_collectionValue.type != T3DataType.obj) return null;
    return vm.objTable.getObj(_collectionValue.getAsObj()!) as T3ObjLookupTable?;
  }

  /// Find the first valid entry index >= the given index.
  /// Returns 0 if no valid entry found.
  int _findFirstValidEntry(T3VM vm, int startIdx) {
    final ltab = _getLookupTable(vm);
    if (ltab == null) return 0;

    // Walk through entries pool starting at startIdx (1-based)
    for (var i = startIdx; i <= ltab._entries.length; i++) {
      final entry = ltab._entries[i - 1];
      if (entry.inUse) return i;
    }
    return 0;
  }

  @override
  bool getpGetNext(T3VM vm, int self, T3Value retval, int? argc) {
    if (argc != null && argc != 0) throw T3VmException(vmErrWrongNumOfArgs);

    final ltab = _getLookupTable(vm);
    if (ltab == null) throw T3VmException(vmErrInvalObjType);

    // Find next valid entry after current
    final nextIdx = _findFirstValidEntry(vm, _curIndex + 1);
    if (nextIdx == 0) throw T3VmException(vmErrOutOfRange);

    // Get the value
    retval.copyFrom(ltab._entries[nextIdx - 1].val);

    // Update index
    _curIndex = nextIdx;
    return true;
  }

  @override
  bool getpIsNextAvail(T3VM vm, int self, T3Value retval, int? argc) {
    if (argc != null && argc != 0) throw T3VmException(vmErrWrongNumOfArgs);

    final nextIdx = _findFirstValidEntry(vm, _curIndex + 1);
    retval.setLogical(nextIdx != 0);
    return true;
  }

  @override
  bool getpResetIter(T3VM vm, int self, T3Value retval, int? argc) {
    if (argc != null && argc != 0) throw T3VmException(vmErrWrongNumOfArgs);
    _curIndex = 0;
    retval.setNil();
    return true;
  }

  @override
  bool getpGetCurKey(T3VM vm, int self, T3Value retval, int? argc) {
    if (argc != null && argc != 0) throw T3VmException(vmErrWrongNumOfArgs);

    final ltab = _getLookupTable(vm);
    if (ltab == null) throw T3VmException(vmErrInvalObjType);

    if (_curIndex < 1 || _curIndex > ltab._entries.length) {
      throw T3VmException(vmErrOutOfRange);
    }

    final entry = ltab._entries[_curIndex - 1];
    if (!entry.inUse) throw T3VmException(vmErrOutOfRange);

    retval.copyFrom(entry.key);
    return true;
  }

  @override
  bool getpGetCurVal(T3VM vm, int self, T3Value retval, int? argc) {
    if (argc != null && argc != 0) throw T3VmException(vmErrWrongNumOfArgs);

    final ltab = _getLookupTable(vm);
    if (ltab == null) throw T3VmException(vmErrInvalObjType);

    if (_curIndex < 1 || _curIndex > ltab._entries.length) {
      throw T3VmException(vmErrOutOfRange);
    }

    final entry = ltab._entries[_curIndex - 1];
    if (!entry.inUse) throw T3VmException(vmErrOutOfRange);

    retval.copyFrom(entry.val);
    return true;
  }

  /// Direct iteration for foreach loops.
  @override
  bool iterNext(T3VM vm, int self, T3Value val) {
    final nextIdx = _findFirstValidEntry(vm, _curIndex + 1);
    if (nextIdx == 0) return false;

    final ltab = _getLookupTable(vm);
    if (ltab == null) return false;

    val.copyFrom(ltab._entries[nextIdx - 1].val);
    _curIndex = nextIdx;
    return true;
  }

  @override
  void markRefs(T3VM vm, int state) {
    if (_collectionValue.type == T3DataType.obj) {
      vm.objTable.markRefs(_collectionValue.getAsObj()!, state);
    }
  }

  @override
  void loadFromImage(T3VM vm, int self, Uint8List ptr, int offset, int size) {
    if (size < 9) throw T3VmException(vmErrInvalMetaclassData);

    // Read collection dataholder
    _collectionValue.readFromBuffer(ptr, offset);

    // Read current index and flags
    final view = ByteData.sublistView(ptr, offset + 5, offset + 9);
    _curIndex = view.getUint16(0, Endian.little);
    _flags = view.getUint16(2, Endian.little);
  }
}

/// LookupTable iterator metaclass registration.
class T3MetaclassIterLookupTable extends T3Metaclass {
  static const String name = 'lookuptable-iterator/030000';

  @override
  String getMetaName() => name;

  @override
  int createFromStack(T3VM vm, Uint8List pc, int pcOffset, int argc) {
    throw T3VmException(vmErrBadDynamicNew);
  }

  @override
  void createForImageLoad(T3VM vm, int id) {
    vm.objTable.setObj(id, T3ObjIterLookupTable(T3Value(T3DataType.nil)));
  }

  @override
  void createForRestore(T3VM vm, int id) {
    vm.objTable.setObj(id, T3ObjIterLookupTable(T3Value(T3DataType.nil)));
  }

  @override
  bool callStatProp(T3VM vm, T3Value result, Uint8List pc, int pcOffset, int argc, int prop) {
    return false;
  }

  @override
  int getSupermeta(T3VM vm, int idx) {
    if (idx == 0) return T3ObjIter.metaclassReg.getClassObj(vm);
    return invalidObj;
  }

  @override
  bool isMetaInstanceOf(T3VM vm, int obj) => false;

  @override
  T3Metaclass? getSupermetaReg() => T3ObjIter.metaclassReg;

  @override
  int getClassObj(T3VM vm) => invalidObj;
}
