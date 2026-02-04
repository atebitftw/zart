// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// TADS3 VM TadsObject Metaclass
///
/// This library provides the TadsObject metaclass, which is the core
/// user-defined object type in TADS3. It provides:
/// - Property storage via hash table
/// - Multiple inheritance with C3 linearization
/// - Dynamic object creation (via `new` keyword)
/// - Undo/redo support for property changes
/// - Image file loading/saving
///
/// Ported from: packages/tads-runner/tads3/vmtobj.h
///              packages/tads-runner/tads3/vmtobj.cpp
library;

import 'dart:typed_data';
import 'package:zart/src/tads3/vm/t3_error.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_object_table.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';

// ============================================================================
// Constants and Flags
// ============================================================================

/// Load image object flag: object represents a class, not an instance
const int vmtobjObjfClass = 0x0001;

/// Internal object flag: object came from image file
const int vmtoObjImage = 0x0001;

/// Internal object flag: object has been modified since loading
const int vmtoObjMod = 0x0002;

/// Property flag: property was modified (not from image file)
const int vmtoPropMod = 0x01;

/// Property flag: undo has been stored for this property since last savepoint
const int vmtoPropUndo = 0x02;

/// Initial empty property table size for new objects
const int vmtobjPropInit = 16;

// ============================================================================
// Data Structures
// ============================================================================

/// Property entry in the hash table.
///
/// TadsObject stores properties in a hash table keyed by property ID.
/// Each entry contains the property ID, value, flags, and a link to
/// the next entry in the hash bucket chain.
class T3TadsObjProp {
  /// Property ID
  int propId;

  /// Next entry in the hash chain (same bucket)
  T3TadsObjProp? next;

  /// Property flags (VMTO_PROP_MOD, VMTO_PROP_UNDO)
  int flags;

  /// Property value - stored as a copy of the assigned value
  T3Value val;

  T3TadsObjProp({
    required this.propId,
    T3Value? value,
    this.next,
    this.flags = 0,
  }) : val = value != null ? T3Value.copy(value) : T3Value();

  /// Check if this property was modified (not from image file)
  bool get isModified => (flags & vmtoPropMod) != 0;

  /// Check if undo has been stored for this property
  bool get hasUndo => (flags & vmtoPropUndo) != 0;

  /// Mark as modified
  void setModified() => flags |= vmtoPropMod;

  /// Mark as having undo stored
  void setUndo() => flags |= vmtoPropUndo;

  /// Clear undo flag (for new savepoint)
  void clearUndo() => flags &= ~vmtoPropUndo;
}

/// Superclass reference.
///
/// Stores both the object ID and a direct pointer to the TadsObject
/// for efficient access during inheritance searches.
class T3TadsObjSc {
  /// Object ID of the superclass
  int id;

  /// Direct pointer to the superclass object (cached for efficiency)
  T3TadsObject? objp;

  T3TadsObjSc({required this.id, this.objp});
}

/// TadsObject header (extension data).
///
/// This is the variable-size extension that stores all instance-specific
/// data for a TadsObject. It includes:
/// - List of superclasses
/// - Hash table for properties
/// - Object flags
class T3TadsObjHeader {
  /// Load image object flags (VMTOBJ_OBJF_xxx)
  int liObjFlags;

  /// Internal object flags (VMTO_OBJ_xxx)
  int internObjFlags;

  /// Superclass list
  final List<T3TadsObjSc> superclasses;

  /// Property hash table buckets
  /// Maps hash bucket index to head of property chain
  final List<T3TadsObjProp?> hashBuckets;

  /// All allocated property entries (for enumeration)
  final List<T3TadsObjProp> propEntries;

  /// Cached inheritance path (for multiple inheritance)
  List<T3TadsObjSc>? inhPath;

  T3TadsObjHeader({
    this.liObjFlags = 0,
    this.internObjFlags = 0,
    int superclassCount = 0,
    int hashSize = 16,
  }) : superclasses = List<T3TadsObjSc>.generate(
         superclassCount,
         (_) => T3TadsObjSc(id: invalidObj),
       ),
       hashBuckets = List<T3TadsObjProp?>.filled(hashSize, null),
       propEntries = [];

  /// Get hash table size
  int get hashSize => hashBuckets.length;

  /// Get property count
  int get propCount => propEntries.length;

  /// Get superclass count
  int get superclassCount => superclasses.length;

  /// Check if object is from image file
  bool get isFromImage => (internObjFlags & vmtoObjImage) != 0;

  /// Check if object has been modified
  bool get isModified => (internObjFlags & vmtoObjMod) != 0;

  /// Check if object represents a class
  bool get isClass => (liObjFlags & vmtobjObjfClass) != 0;

  /// Mark as from image file
  void setFromImage() => internObjFlags |= vmtoObjImage;

  /// Mark as modified
  void setModified() => internObjFlags |= vmtoObjMod;

  /// Invalidate cached inheritance path
  void invalInhPath() {
    inhPath = null;
  }

  /// Calculate hash bucket index for a property ID
  int calcHash(int propId) => propId & (hashSize - 1);

  /// Find a property entry by ID
  T3TadsObjProp? findPropEntry(int propId) {
    final hash = calcHash(propId);
    var entry = hashBuckets[hash];
    while (entry != null) {
      if (entry.propId == propId) {
        return entry;
      }
      entry = entry.next;
    }
    return null;
  }

  /// Allocate a new property entry
  ///
  /// Creates a new property entry and adds it to the hash table.
  /// Does not check for existing entries - caller must verify first.
  T3TadsObjProp allocPropEntry(int propId, T3Value val, int flags) {
    final entry = T3TadsObjProp(propId: propId, value: val, flags: flags);

    // Add to hash table
    final hash = calcHash(propId);
    entry.next = hashBuckets[hash];
    hashBuckets[hash] = entry;

    // Track in master list
    propEntries.add(entry);

    return entry;
  }

  /// Clear all undo flags (for new savepoint)
  void clearUndoFlags() {
    for (final entry in propEntries) {
      entry.clearUndo();
    }
  }

  /// Expand hash table if needed
  ///
  /// Call this when adding many properties to maintain good hash performance.
  void expandIfNeeded() {
    // If we have more entries than buckets, expand
    if (propCount > hashSize) {
      _rehash(hashSize * 2);
    }
  }

  /// Rehash all entries into a new bucket array
  void _rehash(int newSize) {
    // Ensure power of 2 for efficient modulo
    var size = 1;
    while (size < newSize) {
      size *= 2;
    }

    // Create new bucket array
    final newBuckets = List<T3TadsObjProp?>.filled(size, null);

    // Re-insert all entries
    for (final entry in propEntries) {
      final hash = entry.propId & (size - 1);
      entry.next = newBuckets[hash];
      newBuckets[hash] = entry;
    }

    // Replace buckets (can't reassign final, so clear and refill)
    hashBuckets.clear();
    hashBuckets.addAll(newBuckets);
  }
}

// ============================================================================
// TadsObject Class
// ============================================================================

/// TadsObject metaclass - user-defined objects.
///
/// This is the core object type for TADS3 game objects. It supports:
/// - Dynamic property storage
/// - Multiple inheritance
/// - Runtime object creation
/// - Undo/redo tracking
class T3TadsObject extends T3Object {
  // ========================================================================
  // Metaclass Registration
  // ========================================================================

  /// Metaclass registration object
  static T3MetaclassTads? metaclassReg;

  @override
  T3Metaclass getMetaclassReg() {
    metaclassReg ??= T3MetaclassTads();
    return metaclassReg!;
  }

  @override
  bool isOfMetaclass(T3Metaclass meta) {
    return meta == metaclassReg || super.isOfMetaclass(meta);
  }

  /// Check if a given object is a TadsObject.
  ///
  /// Looks up the object in the provided object table and checks if its
  /// metaclass is T3MetaclassTads.
  static bool isTadsObj(T3ObjectTable objTable, int objId) {
    if (objId == invalidObj) {
      return false;
    }
    final obj = objTable.getObj(objId);
    if (obj == null) {
      return false;
    }
    // Check if the object is an instance of our metaclass
    metaclassReg ??= T3MetaclassTads();
    return obj.isOfMetaclass(metaclassReg!);
  }

  // ========================================================================
  // Header Access
  // ========================================================================

  /// Get the object header
  T3TadsObjHeader get header => ext as T3TadsObjHeader;

  /// Initialize with a new header
  void initHeader({int superclassCount = 0, int propCount = vmtobjPropInit}) {
    ext = T3TadsObjHeader(
      superclassCount: superclassCount,
      hashSize: _calcHashSize(propCount),
    );
  }

  /// Calculate appropriate hash size for expected property count
  static int _calcHashSize(int propCount) {
    // Use power of 2 >= propCount, minimum 16
    var size = 16;
    while (size < propCount) {
      size *= 2;
    }
    return size;
  }

  // ========================================================================
  // Superclass Access
  // ========================================================================

  /// Get superclass count
  int get scCount => header.superclassCount;

  /// Get superclass ID at index
  int getSc(int n) => header.superclasses[n].id;

  /// Get superclass object pointer at index
  T3TadsObject? getScObjp(int n) => header.superclasses[n].objp;

  /// Set superclass at index.
  ///
  /// If [objTable] is provided, also caches the object pointer for fast access.
  void setSc(int n, int objId, [T3ObjectTable? objTable]) {
    header.superclasses[n].id = objId;

    // Cache the object pointer if we have access to the object table
    if (objTable != null && objId != invalidObj) {
      final obj = objTable.getObj(objId);
      if (obj is T3TadsObject) {
        header.superclasses[n].objp = obj;
      } else {
        header.superclasses[n].objp = null;
      }
    } else {
      header.superclasses[n].objp = null;
    }

    // Invalidate inheritance path cache
    header.invalInhPath();
  }

  @override
  int getSuperclassCount(T3VM vm, int self) {
    // If no superclasses, inherit from system TadsObject class
    if (scCount == 0) {
      return super.getSuperclassCount(vm, self);
    }
    return scCount;
  }

  @override
  int getSuperclass(T3VM vm, int self, int index) {
    // If no superclasses, return the IntrinsicClass for TadsObject metaclass
    if (scCount == 0) {
      // TODO: Return proper IntrinsicClass when metaclass table is integrated
      return invalidObj;
    }
    if (index >= scCount) {
      return invalidObj;
    }
    return getSc(index);
  }

  // ========================================================================
  // Flag Access
  // ========================================================================

  /// Get load image object flags
  int get liObjFlags => header.liObjFlags;

  /// Set load image object flags
  set liObjFlags(int flags) => header.liObjFlags = flags;

  /// Check if this is a class object
  bool isClassObjectFlag(T3VM vm, int self) => header.isClass;

  @override
  bool isClassObject(T3VM vm, int self) => header.isClass;

  /// Check if object has been modified since loading
  @override
  bool isChangedSinceLoad() => header.isModified;

  // ========================================================================
  // Property Access
  // ========================================================================

  /// This object type provides properties
  @override
  bool providesProps(T3VM vm) => true;

  /// Find a property entry
  T3TadsObjProp? findPropEntry(int propId) => header.findPropEntry(propId);

  // ========================================================================
  // Abstract Method Implementations
  // ========================================================================

  @override
  void notifyDelete(T3VM vm, bool inRootSet) {
    // Free any allocated resources
    // In Dart, garbage collection handles this
  }

  @override
  bool isInstanceOf(T3VM vm, int obj) {
    // TODO: Implement full inheritance check
    // For now, just check direct superclasses
    for (var i = 0; i < scCount; i++) {
      if (getSc(i) == obj) {
        return true;
      }
    }
    return false;
  }

  @override
  void setProp(T3VM vm, T3Undo? undo, int self, int propId, T3Value val) {
    // Find existing entry
    final existing = header.findPropEntry(propId);

    if (existing != null) {
      // TODO: Save undo if needed
      // Update existing value by replacing with copy
      existing.val = T3Value.copy(val);
      existing.setModified();
    } else {
      // Create new entry
      header.allocPropEntry(propId, val, vmtoPropMod);
      header.expandIfNeeded();
    }

    // Mark object as modified
    header.setModified();
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
    // Look for property in our own table first
    final propEntry = header.findPropEntry(propId);
    if (propEntry != null) {
      // Copy value to retval using the extension method
      retval.copyFrom(propEntry.val);
      sourceObj[0] = self;
      return true;
    }

    // Search superclasses
    for (var i = 0; i < scCount; i++) {
      final scObjp = getScObjp(i);
      if (scObjp != null) {
        if (scObjp.getProp(vm, propId, retval, self, sourceObj, argc)) {
          return true;
        }
      }
    }

    // Not found
    return false;
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
    // TODO: Implement proper inheritance search from defining object
    // For now, just search superclasses
    for (var i = 0; i < scCount; i++) {
      final scObjp = getScObjp(i);
      if (scObjp != null) {
        if (scObjp.getProp(vm, propId, retval, self, sourceObj, argc)) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  void buildPropList(T3VM vm, int self, T3Value retval) {
    // TODO: Build list of all properties
  }

  @override
  void markRefs(T3VM vm, int state) {
    // Mark superclass references
    for (var i = 0; i < scCount; i++) {
      // TODO: Mark superclass object
    }

    // Mark property value references
    for (final _ in header.propEntries) {
      // TODO: Mark object references in property values
    }
  }

  @override
  void applyUndo(T3VM vm, T3UndoRecord rec) {
    // TODO: Implement undo application
  }

  @override
  void markUndoRef(T3VM vm, T3UndoRecord rec) {
    // TODO: Implement undo reference marking
  }

  @override
  void removeStaleUndoWeakRef(T3VM vm, T3UndoRecord rec) {
    // TadsObject uses strong references only
  }

  @override
  void loadFromImage(T3VM vm, int self, Uint8List ptr, int offset, int size) {
    // TODO: Implement image file loading
  }

  @override
  void saveToFile(T3VM vm, T3File fp) {
    // TODO: Implement save to file
  }

  @override
  void restoreFromFile(T3VM vm, int self, T3File fp, T3ObjFixup fixups) {
    // TODO: Implement restore from file
  }

  @override
  String? castToString(T3VM vm, int self, T3Value newStr) {
    // TadsObject has no default string representation
    return null;
  }

  // ========================================================================
  // Savepoint Notification
  // ========================================================================

  @override
  void notifyNewSavept() {
    header.clearUndoFlags();
  }
}

// ============================================================================
// Metaclass Registration
// ============================================================================

/// Metaclass registration for TadsObject.
class T3MetaclassTads extends T3Metaclass {
  /// The metaclass identifier string
  static const String metaName = 'tads-object/030005';

  @override
  String getMetaName() => metaName;

  @override
  int createFromStack(T3VM vm, dynamic pc, int pcOffset, int argc) {
    // TODO: Implement dynamic creation from stack arguments
    throw T3VmException(vmErrBadDynamicNew);
  }

  @override
  void createForImageLoad(T3VM vm, int id) {
    // TODO: Implement image file object creation
  }

  @override
  void createForRestore(T3VM vm, int id) {
    // TODO: Implement restore object creation
  }

  @override
  bool callStatProp(
    T3VM vm,
    dynamic result,
    dynamic pc,
    int pcOffset,
    int argc,
    int prop,
  ) {
    // TadsObject has no static properties
    return false;
  }

  @override
  int getSupermeta(T3VM vm, int idx) {
    // TadsObject inherits from root object
    return invalidObj;
  }

  @override
  bool isMetaInstanceOf(T3VM vm, int obj) {
    // When T3VM is fully implemented, it should have an objTable property.
    // For now, return false as we can't check without the object table.
    // Use isMetaInstanceOfWithTable for tests and when object table is available.
    return false;
  }

  /// Check if an object is an instance of this metaclass using the object table.
  ///
  /// This is the preferred method when the object table is available.
  bool isMetaInstanceOfWithTable(T3ObjectTable objTable, int obj) {
    return T3TadsObject.isTadsObj(objTable, obj);
  }

  @override
  T3Metaclass? getSupermetaReg() {
    // TadsObject inherits from Object metaclass
    return null;
  }

  @override
  int getClassObj(T3VM vm) {
    // TODO: Return IntrinsicClass object when available
    return invalidObj;
  }
}
