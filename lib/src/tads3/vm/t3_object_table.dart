// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// TADS3 Object Table - Object Allocation and Management
///
/// This module provides the object table that manages all TADS3 objects:
/// - Page-based object storage for efficient allocation
/// - Free list management for object reuse
/// - Root set tracking for objects loaded from image files
/// - Transient object support
///
/// Ported from vmobj.cpp/vmobj.h
library;

import 'package:zart/src/tads3/vm/t3_error.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';

/// Object table page entry with metadata.
///
/// Each entry represents one object slot in the object table.
/// Entries are either free (available for allocation) or contain a valid object.
class T3ObjPageEntry {
  /// The VM object stored in this entry (null if free).
  T3Object? obj;

  /// Next object in list (either free list or GC work queue).
  int nextObj = invalidObj;

  /// Previous object in free list (for doubly-linked free list).
  int prevFree = invalidObj;

  /// Flag: the object is in the free list.
  bool free = true;

  /// Flag: the object is part of the root set.
  /// Root set objects were loaded from the image file and are always reachable.
  bool inRootSet = false;

  /// Flag: the object is transient.
  /// Transient objects don't participate in undo, save/restore, or restart.
  bool transient = false;

  /// Flag: the object has requested post-load initialization.
  bool requestedPostLoadInit = false;

  /// Flag: the object is part of an undo savepoint.
  /// Set for all existing objects when a savepoint is created.
  bool inUndo = false;

  /// GC hint: the object can contain references to other objects.
  bool canHaveRefs = true;

  /// GC hint: the object can contain weak references to other objects.
  bool canHaveWeakRefs = true;

  /// Check if this entry contains a valid object.
  bool get isValid => !free && obj != null;

  /// Check if the object should participate in undo.
  bool get isInUndo => inUndo && !transient;

  /// Check if the object is saveable (should be written to saved state).
  /// An object is saveable if it's not free, not transient, and either
  /// not in the root set or has been modified since loading.
  bool get isSaveable {
    return !free && !transient && (!inRootSet || (obj?.isChangedSinceLoad() ?? false));
  }

  /// Check if the object is persistent (survives save/restore).
  /// An object is persistent if it's not transient and either in the
  /// root set or saveable.
  bool get isPersistent => !transient && (inRootSet || isSaveable);
}

/// Object table managing all TADS3 objects.
///
/// The object table uses a page-based allocation scheme:
/// - Objects are allocated in pages of fixed size (4096 objects per page)
/// - Object IDs are indices into the page table
/// - Free objects are tracked in a linked list for efficient reuse
class T3ObjectTable {
  /// Number of objects per page (power of 2 for fast division).
  static const int pageCountLog2 = 12;

  /// Number of objects per page (4096).
  static const int pageCount = 1 << pageCountLog2;

  /// Page table (array of pages, each containing object entries).
  final List<List<T3ObjPageEntry>> _pages = [];

  /// Number of pages currently allocated.
  int _pagesUsed = 0;

  /// Head of the free list (linked list of available object slots).
  int _freeListHead = invalidObj;

  /// Tail of the free list (for efficient append).
  int _freeListTail = invalidObj;

  /// Number of free entries in the free list.
  int _freeCount = 0;

  /// List of global object pages (objects always reachable but not from image).
  final List<int> _globalObjs = [];

  /// Get the number of free entries in the free list.
  int get freeCount => _freeCount;

  /// Create the object table.
  T3ObjectTable() {
    // Allocate the first page
    _allocNewPage();
  }

  /// Initialize the object table.
  void init(T3VM vm) {
    // Nothing to do for now
  }

  /// Clear the object table.
  /// Deletes all garbage collected objects but leaves the table intact.
  void clear(T3VM vm) {
    // Delete all non-root-set objects
    for (var pageIdx = 0; pageIdx < _pagesUsed; pageIdx++) {
      final page = _pages[pageIdx];
      for (var entryIdx = 0; entryIdx < pageCount; entryIdx++) {
        final entry = page[entryIdx];
        if (!entry.free && !entry.inRootSet) {
          final objId = (pageIdx << pageCountLog2) | entryIdx;
          _deleteEntry(vm, objId, entry);
        }
      }
    }
  }

  /// Destroy the object table.
  /// Call this before deleting the table.
  void deleteTable(T3VM vm) {
    // Delete all objects
    for (var pageIdx = 0; pageIdx < _pagesUsed; pageIdx++) {
      final page = _pages[pageIdx];
      for (var entryIdx = 0; entryIdx < pageCount; entryIdx++) {
        final entry = page[entryIdx];
        if (!entry.free) {
          final objId = (pageIdx << pageCountLog2) | entryIdx;
          _deleteEntry(vm, objId, entry);
        }
      }
    }

    // Clear the page table
    _pages.clear();
    _pagesUsed = 0;
    _freeListHead = invalidObj;
    _freeListTail = invalidObj;
    _freeCount = 0;
  }

  /// Get an object given an object ID.
  T3Object? getObj(int id) {
    if (id == invalidObj || id >= getMaxUsedObjId()) {
      return null;
    }
    return getEntry(id)?.obj;
  }

  /// Get the page entry for a given object ID.
  T3ObjPageEntry? getEntry(int id) {
    if (id == invalidObj || id >= getMaxUsedObjId()) {
      return null;
    }
    final pageIdx = id >> pageCountLog2;
    final entryIdx = id & (pageCount - 1);
    return _pages[pageIdx][entryIdx];
  }

  /// Allocate a new object ID.
  ///
  /// [inRootSet] - true if the object is part of the root set
  /// [canHaveRefs] - true if the object can contain references to other objects
  /// [canHaveWeakRefs] - true if the object can contain weak references
  int allocObj(T3VM vm, bool inRootSet, [bool canHaveRefs = true, bool canHaveWeakRefs = true]) {
    // If the free list is empty, allocate a new page
    if (_freeListHead == invalidObj) {
      _allocNewPage();
    }

    // Get the first free entry
    final id = _freeListHead;
    final entry = getEntry(id)!;

    // Remove from free list
    _freeListHead = entry.nextObj;
    if (_freeListHead == invalidObj) {
      _freeListTail = invalidObj;
    } else {
      getEntry(_freeListHead)!.prevFree = invalidObj;
    }
    _freeCount--;

    // Initialize the entry for allocation
    _initEntryForAlloc(id, entry, inRootSet, canHaveRefs, canHaveWeakRefs);

    return id;
  }

  /// Register an existing object instance in the object table.
  /// Returns the newly allocated object ID.
  int registerObj(T3Object obj, [bool inRootSet = false]) {
    final id = allocObj(T3VM(), inRootSet);
    getEntry(id)!.obj = obj;
    return id;
  }

  /// Set the object for an already-allocated entry.
  void setObj(int id, T3Object obj) {
    final entry = getEntry(id);
    if (entry != null) {
      entry.obj = obj;
    }
  }

  /// Allocate an object at a specific ID.
  ///
  /// Used when loading objects from an image file or restoring from saved state,
  /// since objects must be loaded with their original IDs.
  void allocObjWithId(int id, bool inRootSet, [bool canHaveRefs = true, bool canHaveWeakRefs = true]) {
    // Ensure we have enough pages
    while (id >= getMaxUsedObjId()) {
      _allocNewPage();
    }

    final entry = getEntry(id)!;

    // The object must not already be allocated
    if (!entry.free) {
      throw T3VmException(vmErrObjInUse);
    }

    // Remove from free list
    if (entry.prevFree != invalidObj) {
      getEntry(entry.prevFree)!.nextObj = entry.nextObj;
    } else {
      _freeListHead = entry.nextObj;
    }

    if (entry.nextObj != invalidObj) {
      getEntry(entry.nextObj)!.prevFree = entry.prevFree;
    } else {
      _freeListTail = entry.prevFree;
    }
    _freeCount--;

    // Initialize the entry for allocation
    _initEntryForAlloc(id, entry, inRootSet, canHaveRefs, canHaveWeakRefs);
  }

  /// Get the maximum object ID that has ever been allocated.
  /// This establishes an upper bound on object IDs among active objects.
  int getMaxUsedObjId() => _pagesUsed * pageCount;

  /// Determine if an object ID refers to a valid object.
  bool isObjIdValid(int id) {
    return id != invalidObj && id < getMaxUsedObjId() && !(getEntry(id)?.free ?? true);
  }

  /// Determine if the given object is transient.
  bool isObjTransient(int id) {
    return id != invalidObj && (getEntry(id)?.transient ?? false);
  }

  /// Mark an object as transient.
  void setObjTransient(int id) {
    getEntry(id)?.transient = true;
  }

  /// Determine if the given object is in the root set.
  bool isObjInRootSet(int id) {
    return id != invalidObj && (getEntry(id)?.inRootSet ?? false);
  }

  /// Determine if the object is part of the latest undo savepoint.
  bool isObjInUndo(int id) {
    return id != invalidObj && (getEntry(id)?.isInUndo ?? false);
  }

  /// Determine if the object is saveable.
  bool isObjSaveable(int id) {
    return id != invalidObj && (getEntry(id)?.isSaveable ?? false);
  }

  /// Determine if the object is persistent.
  bool isObjPersistent(int id) {
    return id != invalidObj && (getEntry(id)?.isPersistent ?? false);
  }

  /// Set an object's garbage collection characteristics.
  void setObjGcCharacteristics(int id, bool canHaveRefs, bool canHaveWeakRefs) {
    final entry = getEntry(id);
    if (entry != null) {
      entry.canHaveRefs = canHaveRefs;
      entry.canHaveWeakRefs = canHaveWeakRefs;
    }
  }

  /// Add an object to the list of machine globals.
  /// An object added to this list will never be deleted.
  void addToGlobals(int obj) {
    if (!isObjInRootSet(obj)) {
      _globalObjs.add(obj);
    }
  }

  /// Call a callback for each object in the table.
  void forEach(T3VM vm, void Function(T3VM vm, int objId, dynamic ctx) func, dynamic ctx) {
    for (var pageIdx = 0; pageIdx < _pagesUsed; pageIdx++) {
      final page = _pages[pageIdx];
      for (var entryIdx = 0; entryIdx < pageCount; entryIdx++) {
        final entry = page[entryIdx];
        if (!entry.free) {
          final objId = (pageIdx << pageCountLog2) | entryIdx;
          if (objId != invalidObj) {
            func(vm, objId, ctx);
          }
        }
      }
    }
  }

  /// Request post-load initialization for an object.
  void requestPostLoadInit(int obj) {
    getEntry(obj)?.requestedPostLoadInit = true;
  }

  /// Remove a post-load initialization request.
  void removePostLoadInit(int obj) {
    getEntry(obj)?.requestedPostLoadInit = false;
  }

  /// Receive notification that we're starting a new undo savepoint.
  void notifyNewSavept() {
    // Mark all existing objects as part of the undo savepoint
    for (var pageIdx = 0; pageIdx < _pagesUsed; pageIdx++) {
      final page = _pages[pageIdx];
      for (var entryIdx = 0; entryIdx < pageCount; entryIdx++) {
        final entry = page[entryIdx];
        if (!entry.free) {
          entry.inUndo = true;
          entry.obj?.notifyNewSavept();
        }
      }
    }
  }

  /// Allocate a new page of objects.
  void _allocNewPage() {
    // Create a new page
    final page = List<T3ObjPageEntry>.generate(pageCount, (_) => T3ObjPageEntry(), growable: false);

    // Add to page table
    _pages.add(page);
    final pageIdx = _pagesUsed++;

    // Add all entries in the new page to the free list
    for (var entryIdx = 0; entryIdx < pageCount; entryIdx++) {
      final objId = (pageIdx << pageCountLog2) | entryIdx;

      // Skip ID 0 as it is reserved for invalidObj
      if (objId == invalidObj) {
        page[entryIdx].free = false;
        page[entryIdx].obj = null;
        continue;
      }

      final entry = page[entryIdx];

      // Link into free list
      entry.free = true;
      entry.prevFree = _freeListTail;
      entry.nextObj = invalidObj;

      if (_freeListTail != invalidObj) {
        final prevEntry = getEntry(_freeListTail);
        if (prevEntry != null) {
          prevEntry.nextObj = objId;
        }
      }
      _freeListTail = objId;

      if (_freeListHead == invalidObj) {
        _freeListHead = objId;
      }

      _freeCount++;
    }
  }

  /// Initialize a newly-allocated object table entry.
  ///
  /// Removes the entry from the free list, marks it as allocated,
  /// and initializes its GC status.
  void _initEntryForAlloc(int id, T3ObjPageEntry entry, bool inRootSet, bool canHaveRefs, bool canHaveWeakRefs) {
    // Mark as allocated
    entry.free = false;
    entry.obj = null; // Will be set by the caller

    // Set root set status
    entry.inRootSet = inRootSet;

    // Set GC characteristics
    entry.canHaveRefs = canHaveRefs;
    entry.canHaveWeakRefs = canHaveWeakRefs;

    // Clear other flags
    entry.transient = false;
    entry.requestedPostLoadInit = false;
    entry.inUndo = false;

    // Clear list pointers
    entry.nextObj = invalidObj;
    entry.prevFree = invalidObj;
  }

  /// Delete an entry.
  void _deleteEntry(T3VM vm, int id, T3ObjPageEntry entry) {
    // Notify the object it's being deleted
    entry.obj?.notifyDelete(vm, entry.inRootSet);

    // Clear the object reference
    entry.obj = null;

    // Mark as free
    entry.free = true;

    // Add to free list
    entry.prevFree = _freeListTail;
    entry.nextObj = invalidObj;

    if (_freeListTail != invalidObj) {
      final prevEntry = getEntry(_freeListTail);
      if (prevEntry != null) {
        prevEntry.nextObj = id;
      }
    }
    _freeListTail = id;

    if (_freeListHead == invalidObj) {
      _freeListHead = id;
    }

    _freeCount++;
  }
}
