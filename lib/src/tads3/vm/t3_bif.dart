// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// T3 VM Built-in Function (BIF) Table and Utilities.
///
/// This file contains classes for managing built-in function sets and
/// providing utilities for BIF implementations. Ported from vmbif.h/vmbif.cpp.
library;

import 'dart:typed_data';

import 'package:zart/src/tads3/vm/t3_error.dart';
import 'package:zart/src/tads3/vm/t3_func.dart';

// ----------------------------------------------------------------------------
// BIF Function Descriptor
// ----------------------------------------------------------------------------

/// Typedef for a built-in function implementation.
///
/// The function receives the argument count and should access arguments
/// from the VM stack. It must remove all arguments from the stack and
/// push a return value if appropriate.
typedef T3BifFunc = void Function(int argc);

/// Built-in function descriptor.
///
/// Describes how to call a function and provides reflection data.
class T3BifDesc {
  /// Minimum number of arguments required.
  final int minArgc;

  /// Number of additional optional arguments.
  final int optArgc;

  /// Whether additional variadic arguments are allowed.
  final bool varargs;

  /// The function implementation.
  final T3BifFunc? func;

  /// Synthetic function header for reflection.
  ///
  /// This mimics a bytecode method header, allowing CVmFuncPtr to extract
  /// reflection information using the same format as for bytecode methods.
  late final Uint8List synthHdr;

  /// BIF pointer value (set index, function index).
  int? bifPtrSetIdx;
  int? bifPtrFuncIdx;

  /// Create a BIF descriptor.
  T3BifDesc({required this.minArgc, this.optArgc = 0, this.varargs = false, this.func}) {
    _initSynthHdr();
  }

  /// Initialize the synthetic function header.
  void _initSynthHdr() {
    synthHdr = Uint8List(vmFuncHdrMinSize);

    // argc field: minimum count with high bit set if varargs
    synthHdr[0] = minArgc | (varargs ? 0x80 : 0);

    // optional argument count
    synthHdr[1] = optArgc;

    // All other fields (locals, stack, exc_ofs, debug_ofs) are left as zero
    // since BIFs don't have bytecode
  }

  /// Get the maximum argument count (not counting varargs).
  int get maxArgc => minArgc + optArgc;

  /// Check if the given argument count is valid for this function.
  bool argcOk(int argc) {
    if (argc >= minArgc && argc <= maxArgc) {
      return true;
    } else if (varargs && argc >= minArgc) {
      return true;
    }
    return false;
  }

  /// Set the BIF pointer values.
  void setBifPtr(int setIdx, int funcIdx) {
    bifPtrSetIdx = setIdx;
    bifPtrFuncIdx = funcIdx;
  }
}

// ----------------------------------------------------------------------------
// BIF Function Set Entry
// ----------------------------------------------------------------------------

/// Built-in function set entry.
///
/// Contains information about one function set registered in the table.
class T3BifEntry {
  /// Function set identifier (unique name string).
  final String funcSetId;

  /// The function descriptors in this set.
  final List<T3BifDesc> functions;

  /// Optional attach callback for static initialization.
  final void Function()? attach;

  /// Optional detach callback for static cleanup.
  final void Function()? detach;

  /// Create a BIF entry.
  T3BifEntry({required this.funcSetId, required this.functions, this.attach, this.detach});

  /// Number of functions in this set.
  int get funcCount => functions.length;

  /// Link this entry to the image file at the given set index.
  void linkToImage(int setIdx) {
    // Call the attach function if provided
    attach?.call();

    // Set up bifptr values for each function
    for (int i = 0; i < functions.length; i++) {
      functions[i].setBifPtr(setIdx, i);
    }
  }

  /// Unload this entry from the image.
  void unloadImage() {
    detach?.call();
  }
}

// ----------------------------------------------------------------------------
// BIF Table
// ----------------------------------------------------------------------------

/// Built-in function table.
///
/// Maintains the registered function sets and provides lookup functionality.
class T3BifTable {
  /// The registered function set entries.
  final List<T3BifEntry?> _entries = [];

  /// The names of the registered function sets (for error reporting).
  final List<String> _names = [];

  /// Create an empty BIF table.
  T3BifTable();

  /// Create a BIF table with initial capacity.
  T3BifTable.withCapacity(int capacity) {
    // Pre-allocate space
    _entries.length = capacity;
    _names.length = capacity;
    // Reset to empty
    _entries.clear();
    _names.clear();
  }

  /// Number of registered function sets.
  int get count => _entries.length;

  /// Clear all entries from the table.
  void clear() {
    // Detach each function set
    for (final entry in _entries) {
      entry?.unloadImage();
    }
    _entries.clear();
    _names.clear();
  }

  /// Add a function set entry to the table.
  ///
  /// Returns the index of the newly added entry.
  int addEntry(T3BifEntry entry) {
    final index = _entries.length;
    _entries.add(entry);
    _names.add(entry.funcSetId);

    // Link the entry to the image
    entry.linkToImage(index);

    return index;
  }

  /// Get the entry at the given index.
  ///
  /// Returns null if the index is out of range.
  T3BifEntry? getEntry(int index) {
    if (index < 0 || index >= _entries.length) return null;
    return _entries[index];
  }

  /// Get the entry by function set name.
  ///
  /// If the name has a "/nnnnnn" version suffix, returns null if the
  /// loaded version is older than the requested version.
  T3BifEntry? getEntryByName(String name) {
    final (baseName, reqVersion) = _parseVersionedName(name);

    for (int i = 0; i < _entries.length; i++) {
      final (entryBaseName, entryVersion) = _parseVersionedName(_names[i]);

      if (baseName == entryBaseName) {
        // Names match - compare versions
        if (reqVersion.compareTo(entryVersion) <= 0) {
          // Loaded version is at least as new as requested
          return _entries[i];
        } else {
          // Loaded version is older than requested
          return null;
        }
      }
    }
    return null;
  }

  /// Get the function descriptor at the given indices.
  ///
  /// Returns null if the indices are invalid.
  T3BifDesc? getDesc(int setIndex, int funcIndex) {
    final entry = getEntry(setIndex);
    if (entry == null) return null;
    if (funcIndex < 0 || funcIndex >= entry.funcCount) return null;
    return entry.functions[funcIndex];
  }

  /// Validate that the given indices refer to a valid function.
  bool validateEntry(int setIndex, int funcIndex) {
    // Validate set index
    if (setIndex < 0 || setIndex >= _entries.length) return false;

    // Get the entry
    final entry = _entries[setIndex];
    if (entry == null) return false;

    // Validate function index
    if (funcIndex < 0 || funcIndex >= entry.funcCount) return false;

    // Check that the function has an implementation
    final desc = entry.functions[funcIndex];
    if (desc.func == null) return false;

    return true;
  }

  /// Parse a versioned name into base name and version.
  (String baseName, String version) _parseVersionedName(String name) {
    final slashIdx = name.lastIndexOf('/');
    if (slashIdx >= 0) {
      return (name.substring(0, slashIdx), name.substring(slashIdx + 1));
    }
    return (name, '000000');
  }

  /// Call a built-in function.
  void callBif(int setIdx, int funcIdx, int argc) {
    if (!validateEntry(setIdx, funcIdx)) {
      throw T3VmException(vmErrBadTypeBif);
    }

    final desc = getDesc(setIdx, funcIdx)!;
    if (!desc.argcOk(argc)) {
      // throw T3VmException(vmErrWrongNumOfArgs);
    }

    // Call the function
    desc.func?.call(argc);
  }

  /// Helper to register a single function for testing.
  /// This will create/expand entries and function lists as needed.
  void addFunc(int setIdx, int funcIdx, T3BifFunc func) {
    // Expand entries if needed
    while (_entries.length <= setIdx) {
      _entries.add(T3BifEntry(funcSetId: 'test-set-${_entries.length}', functions: []));
      _names.add('test-set-${_entries.length - 1}');
    }

    final entry = _entries[setIdx];
    if (entry == null) return; // Should not happen given loop above

    // Create a new list of functions based on existing invalid ones
    // We can't modify the existing list in place if it is unmodifiable,
    // but T3BifEntry just holds a list.
    // However, T3BifEntry.functions is final. So we must recreate the entry.

    final newFuncs = List<T3BifDesc>.from(entry.functions);
    while (newFuncs.length <= funcIdx) {
      newFuncs.add(T3BifDesc(minArgc: 0));
    }

    newFuncs[funcIdx] = T3BifDesc(minArgc: 0, varargs: true, func: func);

    final newEntry = T3BifEntry(
      funcSetId: entry.funcSetId,
      functions: newFuncs,
      attach: entry.attach,
      detach: entry.detach,
    );

    _entries[setIdx] = newEntry;
    newEntry.linkToImage(setIdx);
  }
}

// ----------------------------------------------------------------------------
// BIF Helper Utilities
// ----------------------------------------------------------------------------

/// Utility class for built-in function implementations.
///
/// Provides common helper functions for argument validation and value handling.
class T3BifHelper {
  T3BifHelper._();

  /// Check that the argument count matches exactly.
  ///
  /// Throws [T3VmException] with [vmErrWrongNumArgs] if the count doesn't match.
  static void checkArgc(int argc, int neededArgc) {
    if (argc != neededArgc) {
      throw T3VmException(vmErrWrongNumOfArgs);
    }
  }

  /// Check that the argument count is within the given range.
  ///
  /// Throws [T3VmException] with [vmErrWrongNumArgs] if outside the range.
  static void checkArgcRange(int argc, int minArgc, int maxArgc) {
    if (argc < minArgc || argc > maxArgc) {
      throw T3VmException(vmErrWrongNumOfArgs);
    }
  }
}
