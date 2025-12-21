import 'package:zart/src/glulx/glulx_exception.dart';

/// A block of memory in the Glulx heap.
class GlulxHeapBlock {
  int addr;
  int len;
  bool isFree;
  GlulxHeapBlock? next;
  GlulxHeapBlock? prev;

  GlulxHeapBlock({
    required this.addr,
    required this.len,
    required this.isFree,
    this.next,
    this.prev,
  });
}

/// The Glulx dynamic allocation heap.
///
/// Spec Section 2.13.2: "The heap is a collection of memory blocks that can be
/// allocated and freed by the program."
///
/// Reference: heap.c
class GlulxHeap {
  int _heapStart = 0;
  GlulxHeapBlock? _head;
  GlulxHeapBlock? _tail;
  int _allocCount = 0;

  int get heapStart => _heapStart;
  bool get isActive => _heapStart != 0;
  int get allocCount => _allocCount;

  /// Deactivates the heap and clears all blocks.
  void clear() {
    _head = null;
    _tail = null;
    _heapStart = 0;
    _allocCount = 0;
  }

  /// Manually activates the heap at the given address.
  void activate(int address) {
    if (_heapStart == 0) {
      _heapStart = address;
    }
  }

  /// Allocates a block of the given length.
  ///
  /// Returns the address of the block, or 0 if allocation failed.
  /// Note: The caller (MemoryMap) is responsible for resizing memory if needed
  /// and setting _heapStart if this is the first allocation.
  int allocate(
    int len,
    int currentEndMem,
    int Function(int newSize) resizeMemory,
  ) {
    if (len <= 0) {
      throw GlulxException('Heap allocation length must be positive.');
    }

    GlulxHeapBlock? curr = _head;
    while (curr != null) {
      if (curr.isFree && curr.len >= len) {
        break;
      }

      if (!curr.isFree) {
        curr = curr.next;
        continue;
      }

      if (curr.next == null || !curr.next!.isFree) {
        curr = curr.next;
        continue;
      }

      // Merge adjacent free blocks
      final nextBlo = curr.next!;
      curr.len += nextBlo.len;
      final nextNext = nextBlo.next;
      curr.next = nextNext;
      if (nextNext != null) {
        nextNext.prev = curr;
      } else {
        _tail = curr;
      }
      continue; // Check again if the merged block is big enough
    }

    if (curr == null) {
      // No free area found, extend memory
      int extension = 0;
      if (_heapStart != 0) {
        extension = currentEndMem - _heapStart;
      }
      if (extension < len) {
        extension = len;
      }
      if (extension < 256) {
        extension = 256;
      }
      // Round up to 256
      extension = (extension + 0xFF) & ~0xFF;

      final res = resizeMemory(currentEndMem + extension);
      if (res != 0) {
        return 0; // Allocation failed
      }

      if (_heapStart == 0) {
        _heapStart = currentEndMem;
      }

      if (_tail != null && _tail!.isFree) {
        // Append to last free block
        curr = _tail;
        curr!.len += extension;
      } else {
        // Append new free block
        final newBlo = GlulxHeapBlock(
          addr: currentEndMem,
          len: extension,
          isFree: true,
          prev: _tail,
        );
        if (_tail == null) {
          _head = newBlo;
          _tail = newBlo;
        } else {
          _tail!.next = newBlo;
          _tail = newBlo;
        }
        curr = newBlo;
      }
    }

    // Now we have a free block 'curr' of at least 'len'
    if (curr.len == len) {
      curr.isFree = false;
    } else {
      // Split block
      final remaining = GlulxHeapBlock(
        addr: curr.addr + len,
        len: curr.len - len,
        isFree: true,
        next: curr.next,
        prev: curr,
      );
      curr.len = len;
      curr.isFree = false;
      if (curr.next != null) {
        curr.next!.prev = remaining;
      }
      curr.next = remaining;
      if (_tail == curr) {
        _tail = remaining;
      }
    }

    _allocCount++;
    return curr.addr;
  }

  /// Frees a block at the given address.
  void free(int addr) {
    GlulxHeapBlock? curr = _head;
    while (curr != null) {
      if (curr.addr == addr) {
        break;
      }
      curr = curr.next;
    }

    if (curr == null || curr.isFree) {
      throw GlulxException(
        'Attempt to free unallocated address 0x${addr.toRadixString(16).toUpperCase()} from heap.',
      );
    }

    curr.isFree = true;
    _allocCount--;

    if (_allocCount <= 0) {
      // Deactivate heap handled by caller (MemoryMap) via clear()
    }
  }

  /// Returns a summary of allocated heap blocks for save/restore.
  ///
  /// Format: [heapStart, allocCount, addr1, len1, addr2, len2, ...]
  List<int> getSummary() {
    if (_heapStart == 0) return [];

    final summary = <int>[_heapStart, _allocCount];
    GlulxHeapBlock? curr = _head;
    while (curr != null) {
      if (!curr.isFree) {
        summary.add(curr.addr);
        summary.add(curr.len);
      }
      curr = curr.next;
    }
    return summary;
  }

  /// Restores heap state from a summary.
  void applySummary(List<int> summary, int currentEndMem) {
    clear();
    if (summary.isEmpty) return;

    _heapStart = summary[0];
    _allocCount = summary[1];

    int lastEnd = _heapStart;
    int idx = 2;

    while (idx < summary.length || lastEnd < currentEndMem) {
      final GlulxHeapBlock blo;
      if (idx >= summary.length) {
        // Trailing free block
        blo = GlulxHeapBlock(
          addr: lastEnd,
          len: currentEndMem - lastEnd,
          isFree: true,
        );
      } else {
        if (lastEnd < summary[idx]) {
          // Inner free block
          blo = GlulxHeapBlock(
            addr: lastEnd,
            len: summary[idx] - lastEnd,
            isFree: true,
          );
        } else {
          // Allocated block
          blo = GlulxHeapBlock(
            addr: summary[idx++],
            len: summary[idx++],
            isFree: false,
          );
        }
      }

      if (_head == null) {
        _head = blo;
        _tail = blo;
      } else {
        _tail!.next = blo;
        blo.prev = _tail;
        _tail = blo;
      }

      lastEnd = blo.addr + blo.len;
    }
  }
}
