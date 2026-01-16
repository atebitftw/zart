// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// TADS3 Metaclass Table - Metaclass Registration and Lookup
///
/// This module provides the metaclass dependency table that manages
/// metaclass registration and dynamic linking:
/// - Metaclass registration by name
/// - Property ID to method index mapping
/// - IntrinsicClass object association
///
/// Ported from vmobj.cpp/vmobj.h and vmmeta.cpp/vmmeta.h
library;

import 'package:zart/src/tads3/vm/t3_error.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';

/// Metaclass dependency table entry.
///
/// Each entry represents one registered metaclass and contains:
/// - The metaclass instance
/// - The metaclass name (for dynamic linking)
/// - The associated IntrinsicClass object ID
class T3MetaEntry {
  /// The metaclass instance.
  final T3Metaclass meta;

  /// The metaclass name (unique identifier).
  final String name;

  /// The IntrinsicClass object ID for this metaclass.
  /// Set when the IntrinsicClass object is created.
  int classObj = invalidObj;

  /// Property ID to function table index mapping.
  /// Maps property IDs to indices in the metaclass's function table.
  final Map<int, int> propToIdx = {};

  T3MetaEntry(this.meta, this.name);
}

/// Metaclass registration table.
///
/// Manages all registered metaclasses and provides lookup by:
/// - Registration index (assigned at startup)
/// - Metaclass name (for dynamic linking from image files)
/// - Property ID (for method dispatch)
class T3MetaclassTable {
  /// List of registered metaclasses (indexed by registration index).
  final List<T3MetaEntry> _entries = [];

  /// Map from metaclass name to registration index.
  final Map<String, int> _nameToIndex = {};

  /// Map from registration index to entry index.
  /// (Registration index is assigned by the metaclass, entry index is our internal index)
  final Map<int, int> _regIdxToIndex = {};

  /// Register a metaclass.
  ///
  /// Assigns a registration index to the metaclass and adds it to the table.
  /// Returns the registration index.
  int registerMetaclass(T3Metaclass meta) {
    final name = meta.getMetaName();

    // Check if already registered
    if (_nameToIndex.containsKey(name)) {
      throw T3VmException(vmErrCircularInit);
    }

    // Assign registration index
    final regIdx = _entries.length;
    meta.setMetaclassRegIndex(regIdx);

    // Create entry
    final entry = T3MetaEntry(meta, name);
    _entries.add(entry);

    // Add to name map
    _nameToIndex[name] = regIdx;

    // Add to registration index map
    _regIdxToIndex[regIdx] = regIdx;

    return regIdx;
  }

  /// Get an entry by registration index.
  T3MetaEntry? getEntryFromReg(int regIdx) {
    final idx = _regIdxToIndex[regIdx];
    if (idx == null || idx >= _entries.length) {
      return null;
    }
    return _entries[idx];
  }

  /// Get an entry by metaclass name.
  T3MetaEntry? getEntryFromName(String name) {
    final idx = _nameToIndex[name];
    if (idx == null) {
      return null;
    }
    return _entries[idx];
  }

  /// Map a property ID to a function table index for a metaclass.
  ///
  /// Returns the index in the metaclass's function table for the given
  /// property ID, or null if the property is not defined for the metaclass.
  int? propToVectorIdx(int regIdx, int propId) {
    final entry = getEntryFromReg(regIdx);
    if (entry == null) {
      return null;
    }
    return entry.propToIdx[propId];
  }

  /// Register a property mapping for a metaclass.
  ///
  /// Associates a property ID with a function table index for the metaclass.
  void registerProp(int regIdx, int propId, int funcIdx) {
    final entry = getEntryFromReg(regIdx);
    if (entry == null) {
      throw T3VmException(vmErrUnknownMetaclass);
    }
    entry.propToIdx[propId] = funcIdx;
  }

  /// Set the IntrinsicClass object for a metaclass.
  void setClassObj(int regIdx, int classObj) {
    final entry = getEntryFromReg(regIdx);
    if (entry != null) {
      entry.classObj = classObj;
    }
  }

  /// Get the IntrinsicClass object for a metaclass.
  int getClassObj(int regIdx) {
    final entry = getEntryFromReg(regIdx);
    return entry?.classObj ?? invalidObj;
  }

  /// Iterate over all registered metaclasses.
  void forEach(void Function(T3MetaEntry entry) func) {
    for (final entry in _entries) {
      func(entry);
    }
  }

  /// Get the number of registered metaclasses.
  int get count => _entries.length;

  /// Clear all registrations.
  void clear() {
    _entries.clear();
    _nameToIndex.clear();
    _regIdxToIndex.clear();
  }
}
