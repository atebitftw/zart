// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// TADS3 VM Pool Manager
///
/// This library provides the pool management system for the TADS3 VM, used for
/// managing constant and code pools loaded from the image file. It is a Dart
/// port of the C++ vmpool.h, vmpool.cpp, and vmpoolim.cpp files.
///
/// The pool system manages read-only data in pages. The C++ implementation has
/// multiple variants (flat, paged, swapping), but we implement only the
/// in-memory paged pool (CVmPoolInMem) as it's the standard implementation.
///
/// Ported from: packages/tads-runner/tads3/vmpool.h
///              packages/tads-runner/tads3/vmpool.cpp
///              packages/tads-runner/tads3/vmpoolim.cpp
library;

import 'dart:typed_data';
import 'package:zart/src/tads3/vm/t3_error.dart';

/// Pool offset type - represents an offset into the pool
typedef PoolOffset = int;

/// Pool page information
///
/// Tracks memory for one page in the pool.
class T3PoolPage {
  /// Memory containing the data in this page
  Uint8List? mem;

  /// Actual size of the page data
  int size = 0;

  /// Create a new pool page.
  T3PoolPage();
}

/// Constant Pool Backing Store Interface
///
/// This is an abstract interface that pool clients must implement to provide
/// the pool with the means of loading pages.
///
/// The backing store, like the pool itself, is considered read-only by the
/// pool manager. The pool manager never needs to write data to the backing
/// store, and expects the backing store to remain constant throughout the
/// existence of the pool.
abstract class T3PoolBackingStore {
  /// Determine the total number of pages that are available to be loaded
  int getPageCount();

  /// Get the common page size in the underlying store
  ///
  /// Individual pages may not use the entire page size, but no page may be
  /// larger than the common size.
  int getCommonPageSize();

  /// Given a starting offset and a page size, calculate how much space is
  /// actually needed for the page at the offset
  ///
  /// This is provided to allow for partial pages, which don't need the full
  /// page size allocated. Simple implementations can simply always return
  /// the full page size.
  int getPageSize(PoolOffset offset, int pageSize);

  /// Given a starting offset, allocate space for the given page and load it
  /// into memory
  ///
  /// [pageSize] is the normal page size in bytes, and [loadSize] is the
  /// actual number of bytes to be allocated and loaded (this will be the
  /// value previously returned by [getPageSize] for the page).
  ///
  /// This should throw an exception if an error occurs.
  Uint8List allocAndLoadPage(PoolOffset offset, int pageSize, int loadSize);

  /// Delete memory allocated by [allocAndLoadPage]
  ///
  /// The pool will call this for each page previously allocated. [pageSize]
  /// is the normal page size in bytes for the entire pool.
  void freePage(Uint8List mem, PoolOffset offset, int pageSize);

  /// Given a starting offset, load the page into the given memory, which is
  /// allocated and managed by the caller
  ///
  /// [pageSize] is the normal page size in bytes, and [loadSize] is the
  /// actual number of bytes to be loaded (this will be the value previously
  /// returned by [getPageSize] for the page).
  ///
  /// This should throw an exception if an error occurs.
  void loadPage(PoolOffset offset, int pageSize, int loadSize, Uint8List mem);

  /// Determine if pages are writable
  ///
  /// Returns true if so, false if not. If the pool pages are directly mapped
  /// to the underlying data file, this should return false.
  bool isWritable() => false;
}

/// Base constant memory pool class
abstract class T3Pool {
  /// Page size in bytes - each page in the pool has the same number of bytes
  int _pageSize = 0;

  /// Backing store
  T3PoolBackingStore? _backingStore;

  /// Attach to the given backing store to provide the page data
  void attachBackingStore(T3PoolBackingStore backingStore) {
    _backingStore = backingStore;
    _pageSize = backingStore.getCommonPageSize();
  }

  /// Detach from backing store
  ///
  /// This must be called before the backing store object can be deleted.
  void detachBackingStore() {
    _backingStore = null;
  }

  /// Get the page size
  ///
  /// This reflects the size of the pages in the backing store (usually the
  /// image file); this doesn't necessarily indicate anything about the way
  /// we manage the pool memory.
  int getPageSize() => _pageSize;

  /// Get the number of pages in the pool
  int getPageCount() {
    return _backingStore?.getPageCount() ?? 0;
  }

  /// Translate an address from a pool offset to a physical location
  ///
  /// Returns a tuple of (page data, offset within page).
  /// Note: This is abstract and must be implemented by subclasses.
  (Uint8List, int) getPtr(PoolOffset offset);

  /// Validate an offset
  bool validateOffset(PoolOffset offset);

  /// Given a pointer into physical memory, get the pool offset
  ///
  /// Returns the offset if the pointer is valid, null if not.
  PoolOffset? getOffsetFromPtr(Uint8List mem, int offsetInMem);
}

/// Paged constant pool
///
/// This type of pool is divided into pages. A given object must be entirely
/// contained in a single page.
///
/// Each object is referenced by its address in the constant pool. An object
/// address is simply an offset into the pool.
class T3PoolPaged extends T3Pool {
  /// The page list - array of page structures
  ///
  /// Each structure keeps track of one page in the pool. The page identified
  /// by the first page information structure contains pool offsets 0 through
  /// (pageSize - 1); the next contains offsets pageSize through
  /// (2*pageSize - 1); and so on.
  List<T3PoolPage>? _pages;

  /// The number of page slots in the page list
  ///
  /// This starts at the initial page size and can grow dynamically as more
  /// pages are added.
  int _pageSlots = 0;

  /// The maximum of allocated pages array entries
  ///
  /// This might be larger than [_pageSlots], because we sometimes allocate
  /// more slots than we currently need to avoid having to allocate on every
  /// new page addition.
  int _pageSlotsMax = 0;

  /// log2 of the page size
  int _log2PageSize = 0;

  /// Delete the pool
  void terminate() {
    deletePageList();
  }

  /// Delete our page list, if any
  void deletePageList() {
    if (_pages != null) {
      _pages = null;
      _pageSlots = 0;
      _pageSlotsMax = 0;
    }
    _backingStore = null;
  }

  @override
  void attachBackingStore(T3PoolBackingStore backingStore) {
    // Delete any existing page list
    deletePageList();

    // Inherit default handling
    super.attachBackingStore(backingStore);

    // If the page size is zero, there must not be any pages at all -
    // use a dummy default page size
    if (_pageSize == 0) {
      _pageSize = 1024;
    }

    // Compute log2 of the page size. If the page size isn't a power of
    // two, throw an error.
    int cur = _pageSize;
    int log2 = 0;
    while ((cur & 1) == 0) {
      cur >>= 1;
      log2++;
    }
    if (cur != 1) {
      throw T3VmException(vmErrBadPoolPageSize);
    }

    // Store log2(pageSize) in _log2PageSize
    _log2PageSize = log2;

    // Allocate the pages
    allocPageSlots(backingStore.getPageCount());
  }

  /// Allocate or expand the page slot list
  void allocPageSlots(int nslots) {
    // If the new size isn't bigger than the old size, ignore the request
    if (nslots <= _pageSlots) {
      return;
    }

    // If necessary, expand the master page array
    if (nslots > _pageSlotsMax) {
      // Increase the maximum, leaving some room for dynamically added pages
      _pageSlotsMax = nslots + 10;

      // Allocate or reallocate at the new size
      if (_pages == null) {
        _pages = List<T3PoolPage>.generate(_pageSlotsMax, (_) => T3PoolPage(), growable: false);
      } else {
        // Grow the list
        final newPages = List<T3PoolPage>.generate(
          _pageSlotsMax,
          (i) => i < _pages!.length ? _pages![i] : T3PoolPage(),
          growable: false,
        );
        _pages = newPages;
      }
    }

    // Set the new size
    _pageSlots = nslots;

    // Clear the new slots (they're already initialized to null mem)
    // This is implicit in our List.generate above
  }

  /// Calculate which page we need for a given pool offset
  ///
  /// The page is the offset divided by the page size; since the page size
  /// is a power of two, this is simply a bit shift by log2(pageSize).
  int getPageForOffset(PoolOffset offset) {
    return offset >> _log2PageSize;
  }

  /// Calculate the offset within the page for a given pool offset
  ///
  /// The page offset is the remainder after dividing the offset by the page
  /// size; again because the page size is a power of two, we can calculate
  /// this remainder simply by AND'ing the offset with the page size minus one.
  int getOffsetInPage(PoolOffset offset) {
    return offset & (_pageSize - 1);
  }

  /// Get the starting offset on the given page
  PoolOffset getPageStartOffset(int page) {
    return page << _log2PageSize;
  }

  @override
  (Uint8List, int) getPtr(PoolOffset offset) {
    throw UnimplementedError('Must be implemented by subclass');
  }

  @override
  bool validateOffset(PoolOffset offset) {
    throw UnimplementedError('Must be implemented by subclass');
  }

  @override
  PoolOffset? getOffsetFromPtr(Uint8List mem, int offsetInMem) {
    throw UnimplementedError('Must be implemented by subclass');
  }
}

/// In-memory pool implementation
///
/// This pool implementation pre-loads all available pages in the pool and
/// keeps the complete pool in memory at all times.
class T3PoolInMem extends T3PoolPaged {
  /// Terminate - free our resources
  void terminateNv() {
    freeBackingPages();
  }

  /// Free pages that we allocated from the backing store
  void freeBackingPages() {
    // If there's no backing store, there's nothing to do
    if (_backingStore == null || _pages == null) {
      return;
    }

    // Run through the page array and delete each allocated page
    PoolOffset offset = 0;
    for (int i = 0; i < _pageSlots; i++, offset += _pageSize) {
      final page = _pages![i];
      // If this slot was allocated, delete it
      if (page.mem != null) {
        _backingStore!.freePage(page.mem!, offset, _pageSize);
        page.mem = null;
      }
    }
  }

  @override
  void attachBackingStore(T3PoolBackingStore backingStore) {
    // Do the normal initialization to allocate the page slots
    super.attachBackingStore(backingStore);

    // Load all of the pages
    PoolOffset offset = 0;
    for (int i = 0; i < _pageSlots; i++, offset += _pageSize) {
      final page = _pages![i];

      // Determine how much memory we really need for this page
      page.size = backingStore.getPageSize(offset, _pageSize);

      // Allocate and load the page
      page.mem = backingStore.allocAndLoadPage(offset, _pageSize, page.size);
    }
  }

  @override
  void detachBackingStore() {
    // Release the backing pages
    freeBackingPages();

    // Inherit default
    super.detachBackingStore();
  }

  @override
  (Uint8List, int) getPtr(PoolOffset offset) {
    // Translate the address through our page array
    final page = getPageForOffset(offset);
    final pageOffset = getOffsetInPage(offset);
    return (_pages![page].mem!, pageOffset);
  }

  @override
  bool validateOffset(PoolOffset offset) {
    // Get the page and the offset in the page
    final page = getPageForOffset(offset);
    final pageOffset = getOffsetInPage(offset);

    // To be valid, it must be within the range of valid pages, the page
    // must be allocated, and the offset in the page must be within the
    // page's actual allocated size
    return page < _pageSlots && _pages![page].mem != null && pageOffset < _pages![page].size;
  }

  @override
  PoolOffset? getOffsetFromPtr(Uint8List mem, int offsetInMem) {
    // Check each page
    PoolOffset pageOffset = 0;
    for (int i = 0; i < _pageSlots; i++, pageOffset += _pageSize) {
      final pageMem = _pages![i].mem;
      // If it's in this page, it's a valid address
      if (pageMem != null && identical(mem, pageMem)) {
        // Check if the offset is within the page
        if (offsetInMem >= 0 && offsetInMem < _pages![i].size) {
          return pageOffset + offsetInMem;
        }
      }
    }

    // Didn't find it
    return null;
  }

  @override
  void terminate() {
    terminateNv();
    super.terminate();
  }
}
