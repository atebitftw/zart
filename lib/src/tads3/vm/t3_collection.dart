// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// TADS3 VM Collection Base Class
///
/// This library provides the Collection base class, which is the abstract base
/// for List, Vector, and other iterable types in TADS3.
///
/// Collection is an abstract class: it cannot be instantiated directly, and
/// thus has no image-file or state-file representation. It provides the common
/// interface for iterator creation that all collection types share.
///
/// Ported from: packages/tads-runner/tads3/vmcoll.h
///              packages/tads-runner/tads3/vmcoll.cpp
library;

import 'package:zart/src/tads3/vm/t3_error.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';

/// Collection property indices
///
/// These correspond to the function table indices in vmcoll.cpp.
enum T3CollectionProp {
  /// Undefined property (index 0)
  undef,

  /// Create a snapshot iterator (index 1)
  createIterator,

  /// Create a live iterator (index 2)
  createLiveIterator,
}

/// Abstract base class for TADS3 Collection types.
///
/// Collection provides the common interface for iterable types. It defines
/// two key properties:
/// - `createIterator()` - creates an iterator over an immutable snapshot
/// - `createLiveIterator()` - creates an iterator over the live collection
///
/// Subclasses must implement [newIterator] and [newLiveIterator] to provide
/// the actual iterator creation logic.
abstract class T3Collection extends T3Object {
  // ========================================================================
  // Metaclass Registration
  // ========================================================================

  /// Metaclass registration object
  static T3MetaclassCollection? metaclassReg;

  @override
  T3Metaclass getMetaclassReg() {
    metaclassReg ??= T3MetaclassCollection();
    return metaclassReg!;
  }

  @override
  bool isOfMetaclass(T3Metaclass meta) {
    // Check our own metaclass first, then inherit from base
    return meta == metaclassReg || super.isOfMetaclass(meta);
  }

  // ========================================================================
  // Abstract Iterator Methods (subclasses must implement)
  // ========================================================================

  /// Create an iterator over an immutable snapshot of this collection.
  ///
  /// The iterator must refer to an immutable copy of the collection's
  /// contents at the time of creation. Changes to the original collection
  /// after iterator creation must not affect the iteration.
  ///
  /// Subclasses must implement this to return an appropriate iterator object.
  void newIterator(T3VM vm, T3Value retval, T3Value selfVal);

  /// Create a "live" iterator over this collection.
  ///
  /// The iterator refers to the original collection, so changes to the
  /// collection during iteration will be visible to the iterator.
  ///
  /// Subclasses must implement this to return an appropriate iterator object.
  void newLiveIterator(T3VM vm, T3Value retval, T3Value selfVal);

  // ========================================================================
  // Property Handling
  // ========================================================================

  // Note: getProp is not overridden here because T3Object.getProp is abstract.
  // Concrete Collection subclasses (List, Vector, etc.) must implement getProp
  // themselves and call constGetCollProp for collection-specific properties.

  /// Get a property of a collection (constant value version).
  ///
  /// This allows evaluating collection properties for both object values
  /// and constant values using the same code.
  bool constGetCollProp(
    T3VM vm,
    int propId,
    T3Value retval,
    T3Value selfVal,
    List<int> sourceObj,
    int? argc,
  ) {
    // Translate property ID to function index via metaclass table
    // For now, we'll use a simple mapping based on known property IDs
    // TODO: Use proper property-to-index translation when metaclass table is ready

    // Get the property index from the metaclass table
    final funcIdx = _propToFuncIndex(vm, propId);

    // Call the appropriate handler
    switch (funcIdx) {
      case T3CollectionProp.createIterator:
        return getpCreateIterator(vm, retval, selfVal, argc);
      case T3CollectionProp.createLiveIterator:
        return getpCreateLiveIterator(vm, retval, selfVal, argc);
      case T3CollectionProp.undef:
        return false;
    }
  }

  /// Translate a property ID to a function table index.
  ///
  /// This would normally use the metaclass table's prop_to_vector_idx method.
  /// For now, we use a placeholder that can be expanded when integrated.
  T3CollectionProp _propToFuncIndex(T3VM vm, int propId) {
    // TODO: Integrate with metaclass table for proper property lookup
    // For now, return undef - actual mapping will come from metaclass table
    return T3CollectionProp.undef;
  }

  // ========================================================================
  // Property Evaluators
  // ========================================================================

  /// Property evaluator: createIterator()
  ///
  /// Creates a snapshot iterator for iteration with the 'foreach' statement.
  bool getpCreateIterator(T3VM vm, T3Value retval, T3Value selfVal, int? argc) {
    // Check arguments - expects 0 arguments
    if (argc != null && argc != 0) {
      throw T3VmException(vmErrWrongNumOfArgs);
    }

    // Create the iterator via the subclass implementation
    newIterator(vm, retval, selfVal);

    return true;
  }

  /// Property evaluator: createLiveIterator()
  ///
  /// Creates a live iterator that tracks changes to the collection.
  bool getpCreateLiveIterator(
    T3VM vm,
    T3Value retval,
    T3Value selfVal,
    int? argc,
  ) {
    // Check arguments - expects 0 arguments
    if (argc != null && argc != 0) {
      throw T3VmException(vmErrWrongNumOfArgs);
    }

    // Create the live iterator via the subclass implementation
    newLiveIterator(vm, retval, selfVal);

    return true;
  }
}

/// Metaclass registration for Collection.
///
/// Collection is an abstract class that cannot be instantiated, so all
/// creation methods throw appropriate errors.
class T3MetaclassCollection extends T3Metaclass {
  /// The metaclass identifier string
  static const String metaName = 'collection/030000';

  @override
  String getMetaName() => metaName;

  @override
  int createFromStack(T3VM vm, dynamic pc, int pcOffset, int argc) {
    // Collection is abstract - cannot be dynamically created
    throw T3VmException(vmErrBadDynamicNew);
  }

  @override
  void createForImageLoad(T3VM vm, int id) {
    // Collection is abstract - cannot appear in image files
    throw T3VmException(vmErrBadStaticNew);
  }

  @override
  void createForRestore(T3VM vm, int id) {
    // Collection is abstract - cannot be restored from saved state
    throw T3VmException(vmErrBadStaticNew);
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
    // Collection has no static properties - inherit base handling
    // This would delegate to CVmObject::call_stat_prop in C++
    return false;
  }

  @override
  int getSupermeta(T3VM vm, int idx) {
    // Collection's only supermetaclass is root object (index 0)
    // Return invalid for any other index
    return invalidObj;
  }

  @override
  bool isMetaInstanceOf(T3VM vm, int obj) {
    // Check if obj is an instance of Collection
    // This would check the object's metaclass hierarchy
    return false;
  }

  @override
  T3Metaclass? getSupermetaReg() {
    // Collection inherits from base Object metaclass
    // Return null to indicate root object metaclass
    return null;
  }

  @override
  int getClassObj(T3VM vm) {
    // Return the IntrinsicClass object for this metaclass
    // This needs to be set up during VM initialization
    return invalidObj;
  }
}
