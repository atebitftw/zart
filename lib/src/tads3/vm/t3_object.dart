// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// TADS3 Object System - Base Object and Metaclass Support
///
/// This module provides the foundation of the TADS3 object system, including:
/// - Base T3Object class with virtual methods for all object operations
/// - Metaclass registration and factory system
/// - Property access and inheritance
/// - Type conversion and arithmetic operations
///
/// Ported from vmobj.cpp/vmobj.h
library;

import 'dart:typed_data';
import 'package:zart/src/tads3/vm/t3_error.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';

// Type aliases for compatibility with C++ code
typedef T3ValueType = T3DataType;
const int invalidObj = invalidObjectId;

/// Base class for all TADS3 objects.
///
/// This is the root of the TADS3 object hierarchy. All TADS3 object types
/// (strings, lists, TadsObjects, etc.) derive from this class and implement
/// its virtual methods.
///
/// Objects are composed of two parts:
/// 1. A fixed-size header (this class) containing the vtable and metadata
/// 2. A variable-size extension containing instance-specific data
abstract class T3Object {
  /// Extension data for this object (variable-size portion).
  /// Subclasses use this to store their instance data.
  Object? ext;

  /// Get the metaclass registration object for this object's type.
  T3Metaclass getMetaclassReg();

  /// Get the image file version string for this metaclass.
  /// This is the version the image file depends on, which may be earlier
  /// than the actual implementation version.
  String getImageFileVersion(T3VM vm) {
    return getMetaclassReg().getMetaName().split('/').last;
  }

  /// Check if the image file version is at least the given version.
  /// Version strings are in format "030001" (major.minor).
  bool imageFileVersionGe(T3VM vm, String ver) {
    return getImageFileVersion(vm).compareTo(ver) >= 0;
  }

  /// Check if this object is of the given metaclass.
  /// Returns true if this object is an instance of [meta] or inherits from it.
  bool isOfMetaclass(T3Metaclass meta) {
    return meta == getMetaclassReg();
  }

  /// Notification that this object is being deleted.
  /// Called by the garbage collector when the object is unreachable.
  void notifyDelete(T3VM vm, bool inRootSet);

  /// Create an instance of this class.
  /// By default, objects cannot be instantiated, so this throws an error.
  /// Subclasses that support dynamic instantiation must override this.
  void createInstance(T3VM vm, int self, Uint8List pc, int pcOffset, int argc) {
    throw T3VmException(vmErrCannotCreateInst);
  }

  /// Determine if the object has a non-trivial finalizer.
  /// Returns true if the object needs finalization, false otherwise.
  bool hasFinalizer(T3VM vm, int self) => false;

  /// Invoke the object's finalizer.
  /// Any exceptions thrown should be caught and discarded.
  void invokeFinalizer(T3VM vm, int self) {}

  /// Determine if this is a class object.
  /// Returns true if this object is a class, false if it's an instance.
  bool isClassObject(T3VM vm, int self) => false;

  /// Determine if this object is an instance of another object.
  /// Returns true if this object derives from [obj], directly or indirectly.
  bool isInstanceOf(T3VM vm, int obj);

  /// Get the number of superclasses of this object.
  /// By default, objects have one superclass (the IntrinsicClass for the metaclass).
  int getSuperclassCount(T3VM vm, int self) => 1;

  /// Get the nth superclass of this object.
  /// By default, returns the IntrinsicClass object for this metaclass.
  int getSuperclass(T3VM vm, int self, int index);

  /// Determine if the object has properties that can be enumerated.
  /// Returns true if the object type provides properties, even if this
  /// instance has zero properties.
  bool providesProps(T3VM vm) => false;

  /// Enumerate properties of the object.
  /// Invokes [callback] for each property. The callback must not modify
  /// the object or invoke garbage collection.
  void enumProps(
    T3VM vm,
    int self,
    void Function(T3VM vm, int self, int prop, T3Value val) callback,
  ) {
    // By default, no properties to enumerate
  }

  /// Set a property value.
  void setProp(T3VM vm, T3Undo? undo, int self, int propId, T3Value val);

  /// Get a property value.
  ///
  /// Does not evaluate the property, but merely gets the raw value.
  /// If the property value is code, returns the code offset pointer.
  ///
  /// Returns true if the property was found, false if not.
  /// Sets [sourceObj] to the object that actually supplied the value.
  ///
  /// If [argc] is not null, this function can consume arguments from the
  /// stack and set [argc] to zero to indicate consumption.
  bool getProp(
    T3VM vm,
    int propId,
    T3Value retval,
    int self,
    List<int> sourceObj,
    int? argc,
  );

  /// Get the invocation routine for this object.
  /// If the object has a function interface, sets up a FUNCPTR or CODEPTR
  /// value to point to the code to invoke.
  ///
  /// Returns true if this is an invokable object, false if not.
  bool getInvoker(T3VM vm, T3Value? val) => false;

  /// Inherit a property value.
  ///
  /// Works like getProp(), but finds an inherited definition of the property,
  /// as though [origTargetObj].prop were undefined.
  ///
  /// [definingObj] is the object containing the currently running method.
  /// [origTargetObj] is the original target of the get_prop() operation.
  bool inhProp(
    T3VM vm,
    int propId,
    T3Value retval,
    int self,
    int origTargetObj,
    int definingObj,
    List<int> sourceObj,
    int? argc,
  );

  /// Build a list of properties directly defined on this object instance.
  /// Most object types don't define properties in instances, so the default
  /// returns an empty list.
  void buildPropList(T3VM vm, int self, T3Value retval);

  /// Mark all strongly-referenced objects for garbage collection.
  /// Calls objTable.markRefs() for each referenced object.
  void markRefs(T3VM vm, int state);

  /// Remove stale weak references.
  /// For each weakly-referenced object, check if it's marked as reachable;
  /// if not, forget the weak reference.
  void removeStaleWeakRefs(T3VM vm) {}

  /// Receive notification that the undo manager is creating a new savepoint.
  void notifyNewSavept() {}

  /// Apply an undo record created by this object.
  void applyUndo(T3VM vm, T3UndoRecord rec);

  /// Discard extra information associated with an undo record.
  void discardUndo(T3VM vm, T3UndoRecord rec) {}

  /// Mark object references in an undo record.
  void markUndoRef(T3VM vm, T3UndoRecord rec);

  /// Remove stale weak references in an undo record.
  void removeStaleUndoWeakRef(T3VM vm, T3UndoRecord rec);

  /// Post-load initialization.
  /// Called after ALL objects are loaded, allowing initialization that
  /// depends on other objects.
  void postLoadInit(T3VM vm, int self) {}

  /// Load the object from an image file.
  void loadFromImage(T3VM vm, int self, Uint8List ptr, int offset, int size);

  /// Reload the object from an image file.
  /// Discards changes and restores to the image file state.
  void reloadFromImage(
    T3VM vm,
    int self,
    Uint8List ptr,
    int offset,
    int size,
  ) {}

  /// Reset to the image file state.
  /// Discards changes made since loading.
  void resetToImage(T3VM vm, int self) {}

  /// Determine if the object has been changed since loading from the image file.
  /// Returns true if modified, false if in original state.
  bool isChangedSinceLoad() => false;

  /// Save this object to a file.
  void saveToFile(T3VM vm, T3File fp);

  /// Restore the object state from a file.
  void restoreFromFile(T3VM vm, int self, T3File fp, T3ObjFixup fixups);

  /// Compare to another value for equality.
  /// By default, returns true only if [val] is a reference to this same object.
  bool equals(T3VM vm, int self, T3Value val, int depth) {
    return val.type == T3DataType.obj && val.getAsObj() == self;
  }

  /// Compare magnitude of this object and another object.
  /// Returns positive if this > val, negative if this < val, zero if equal.
  /// By default, magnitude comparisons are not meaningful, so throws an error.
  int compareTo(T3VM vm, int self, T3Value val) {
    throw T3VmException(vmErrInvalidComparison);
  }

  /// Calculate a hash value for the object.
  /// By default, uses a 16-bit hash of the object ID.
  int calcHash(T3VM vm, int self, int depth) {
    return ((self & 0xffff) ^ ((self & 0xffff0000) >> 16));
  }

  /// Add a value to this object, returning the result.
  /// Returns true if implemented, false if not.
  bool addVal(T3VM vm, T3Value result, int self, T3Value val) => false;

  /// Subtract a value from this object, returning the result.
  /// Returns true if implemented, false if not.
  bool subVal(T3VM vm, T3Value result, int self, T3Value val) => false;

  /// Multiply this object by a value, returning the result.
  /// Returns true if implemented, false if not.
  bool mulVal(T3VM vm, T3Value result, int self, T3Value val) => false;

  /// Divide a value into this object, returning the result.
  /// Returns true if implemented, false if not.
  bool divVal(T3VM vm, T3Value result, int self, T3Value val) => false;

  /// Get the arithmetic negative of this object, returning the result.
  /// Returns true if implemented, false if not.
  bool negVal(T3VM vm, T3Value result, int self) => false;

  /// Index the object (query mode).
  /// Returns true and stores the indexed value in [result] if supported,
  /// or returns false if indexing is not supported.
  bool indexValQ(T3VM vm, T3Value result, int self, T3Value indexVal) => false;

  /// Set an indexed element of the object (query mode).
  /// Returns true and stores the new container in [newContainer] if supported,
  /// or returns false if indexing is not supported.
  bool setIndexValQ(
    T3VM vm,
    T3Value newContainer,
    int self,
    T3Value indexVal,
    T3Value newVal,
  ) => false;

  /// Get the next iterator value.
  /// Returns true and fills in [val] if another value is available,
  /// or returns false if no more values.
  bool iterNext(T3VM vm, int self, T3Value val) => false;

  /// Cast the value to integer.
  /// Throws an error if there's no suitable integer representation.
  int castToInt(T3VM vm) {
    throw T3VmException(vmErrNoIntConv);
  }

  /// Cast the value to a numeric type.
  /// Fills in [val] with the numeric representation.
  void castToNum(T3VM vm, T3Value val, int self) {
    throw T3VmException(vmErrNoNumConv);
  }

  /// Get a string representation of the object.
  /// Returns the string in portable format (length prefix + UTF-8 bytes).
  /// If a new string object is created, [newStr] is set to reference it.
  String? castToString(T3VM vm, int self, T3Value newStr);

  /// Cast to string with explicit radix (for toString() calls).
  /// By default, uses the basic castToString() processing.
  String? explicitToString(
    T3VM vm,
    int self,
    T3Value newStr,
    int radix,
    int flags,
  ) {
    return castToString(vm, self, newStr);
  }

  /// Check if this is a numeric type.
  /// Returns true for types that represent numbers (e.g., BigNumber).
  bool isNumeric() => false;

  /// Get the integer value of the object, if it has one.
  /// Returns true and sets [val] if successful, false otherwise.
  bool getAsInt(List<int> val) => false;

  /// Get the double value of the object, if it has one.
  /// Returns true and sets [val] if successful, false otherwise.
  bool getAsDouble(T3VM vm, List<double> val) => false;

  /// Promote an integer to the type of this object.
  /// For example, if this is a BigNumber, creates a BigNumber from the integer.
  void promoteInt(T3VM vm, T3Value val) {
    throw T3VmException(vmErrNumValReqd);
  }

  /// Get the list contained in the object, if possible.
  /// Returns the list in portable format, or null if not a list.
  Uint8List? getAsList() => null;

  /// Check if this is a list-like object.
  /// Returns true if the object has a length and is indexable with 1..length.
  bool isListlike(T3VM vm, int self) => false;

  /// For a list-like object, get the number of elements.
  /// Returns -1 if not list-like.
  int llLength(T3VM vm, int self) => -1;

  /// Get the string contained in the object, if possible.
  /// Returns the string in portable format, or null if not a string.
  Uint8List? getAsString(T3VM vm) => null;

  /// Rebuild the image data for the object.
  /// Returns the size in bytes of data stored, or 0 if not needed.
  int rebuildImage(T3VM vm, Uint8List buf, int offset, int size) => 0;

  /// Reserve space for conversion to constant data in a rebuilt image file.
  void reserveConstData(T3VM vm, T3ConstMapper mapper, int self) {}

  /// Convert to constant data for a rebuilt image file.
  void convertToConstData(T3VM vm, T3ConstMapper mapper, int self) {}

  /// Get the type this object uses when converted to constant data.
  T3ValueType getConvertToConstDataType() => T3ValueType.nil;
}

/// Metaclass registration and factory.
///
/// Each T3Object subclass must define a singleton instance of T3Metaclass
/// that describes the class and instantiates objects of the class.
abstract class T3Metaclass {
  /// Registration index in the metaclass table.
  /// Set during startup when the registration table is built.
  int _metaRegIdx = -1;

  /// Get the metaclass registration table index.
  int getRegIdx() => _metaRegIdx;

  /// Set the metaclass registration table index.
  /// Can only be called during initialization.
  void setMetaclassRegIndex(int idx) {
    _metaRegIdx = idx;
  }

  /// Get the metaclass name.
  /// This is the universally unique identifier for the metaclass,
  /// used to dynamically link the image file to the metaclass.
  String getMetaName();

  /// Create an instance of the metaclass using arguments from the VM stack.
  /// Returns the ID of the newly-created object.
  /// If the class has a byte-code constructor, invokes it.
  int createFromStack(T3VM vm, Uint8List pc, int pcOffset, int argc);

  /// Create an instance with the given ID for image file loading.
  /// The object table entry is already allocated; this just needs to
  /// invoke the metaclass-specific constructor.
  void createForImageLoad(T3VM vm, int id);

  /// Create an instance with the given ID for restoring from saved state.
  void createForRestore(T3VM vm, int id);

  /// Call a static property of the metaclass.
  bool callStatProp(
    T3VM vm,
    T3Value result,
    Uint8List pc,
    int pcOffset,
    int argc,
    int prop,
  );

  /// Set a static property of the metaclass.
  /// Returns true if successful, false if the property isn't settable.
  bool setStatProp(
    T3VM vm,
    T3Undo? undo,
    int self,
    T3Value classState,
    int prop,
    T3Value val,
  ) => false;

  /// Get the number of super-metaclasses.
  /// All metaclasses have exactly one super-metaclass, except root object.
  int getSupermetaCount(T3VM vm) => 1;

  /// Get the super-metaclass at the given index.
  int getSupermeta(T3VM vm, int idx);

  /// Determine if this metaclass is an instance of the given object.
  bool isMetaInstanceOf(T3VM vm, int obj);

  /// Get the super-metaclass registration object.
  /// Most metaclasses are derived from Object.
  T3Metaclass? getSupermetaReg();

  /// Get the class object for this metaclass.
  /// Looks up the class object in the metaclass registration table.
  int getClassObj(T3VM vm);
}

/// Root object metaclass.
///
/// The root object can never be instantiated; it exists purely to provide
/// a root in the type system.
class T3MetaclassRoot extends T3Metaclass {
  @override
  String getMetaName() => 'root-object/030004';

  @override
  int createFromStack(T3VM vm, Uint8List pc, int pcOffset, int argc) {
    throw T3VmException(vmErrBadDynamicNew);
  }

  @override
  void createForImageLoad(T3VM vm, int id) {
    throw T3VmException(vmErrBadStaticNew);
  }

  @override
  void createForRestore(T3VM vm, int id) {
    throw T3VmException(vmErrBadStaticNew);
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
    // Root object has no static properties
    return false;
  }

  @override
  int getSupermetaCount(T3VM vm) => 0;

  @override
  int getSupermeta(T3VM vm, int idx) => invalidObj;

  @override
  bool isMetaInstanceOf(T3VM vm, int obj) => false;

  @override
  T3Metaclass? getSupermetaReg() => null;

  @override
  int getClassObj(T3VM vm) => invalidObj;
}

/// Placeholder types for features not yet implemented

/// Placeholder for the VM execution environment.
class T3VM {
  /// Placeholder - will be defined elsewhere
  dynamic get stack => null;
  dynamic get objTable => null;
  dynamic get metaTable => null;
  dynamic get constPool => null;
  dynamic get interpreter => null;
}

/// Placeholder for the undo system.
class T3Undo {
  /// Placeholder - will be defined elsewhere
}

/// Placeholder for undo records.
class T3UndoRecord {
  /// Placeholder - will be defined elsewhere
}

/// Placeholder for file handling.
class T3File {
  /// Placeholder - will be defined elsewhere
}

/// Placeholder for object fixups.
class T3ObjFixup {
  /// Placeholder - will be defined elsewhere
}

/// Placeholder for constant mapping.
class T3ConstMapper {
  /// Placeholder - will be defined elsewhere
}
