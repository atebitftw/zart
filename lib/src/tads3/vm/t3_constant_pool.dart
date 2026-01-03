import 'dart:typed_data';
import 'package:zart/src/tads3/vm/t3_utf8.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';

/// T3 VM constant pool.
///
/// The constant pool stores static strings and lists that are referenced
/// by code at runtime. It is organized as a set of fixed-size pages
/// accessed through a page table.
///
/// Pool addressing: Given a 32-bit offset, divide by page size to get
/// the page index, and use the remainder as the offset within that page.
///
/// See spec sections "Memory Model" and "Constant Pool Definition Block".
class T3ConstantPool {
  /// Pool identifier (1 = code pool, 2 = constant pool).
  final int poolId;

  /// Number of pages in this pool.
  final int pageCount;

  /// Size of each page in bytes.
  final int pageSize;

  /// The pages of this pool.
  final List<Uint8List?> _pages;

  /// Creates a constant pool with the specified structure.
  T3ConstantPool({required this.poolId, required this.pageCount, required this.pageSize})
    : _pages = List<Uint8List?>.filled(pageCount, null);

  /// Loads a page from CPPG block data.
  void loadPage(int pageIndex, Uint8List data) {
    assert(pageIndex >= 0 && pageIndex < pageCount, 'Invalid page index');
    _pages[pageIndex] = Uint8List.fromList(data);
  }

  /// Checks if a page is loaded.
  bool isPageLoaded(int pageIndex) {
    return pageIndex >= 0 && pageIndex < pageCount && _pages[pageIndex] != null;
  }

  /// Gets the physical address (page, offset) for a pool offset.
  (int pageIndex, int pageOffset) _resolveOffset(int offset) {
    final pageIndex = offset ~/ pageSize;
    final pageOffset = offset % pageSize;
    return (pageIndex, pageOffset);
  }

  /// Gets the raw bytes for a page.
  Uint8List? getPage(int pageIndex) {
    if (pageIndex < 0 || pageIndex >= pageCount) return null;
    return _pages[pageIndex];
  }

  // ==================== Byte-Level Access ====================

  /// Reads a single byte at the given pool offset.
  int readByte(int offset) {
    final (pageIndex, pageOffset) = _resolveOffset(offset);
    final page = _pages[pageIndex];
    if (page == null) {
      throw StateError('Page $pageIndex not loaded');
    }
    return page[pageOffset];
  }

  /// Reads a 16-bit unsigned integer (little-endian) at the given offset.
  int readUint16(int offset) {
    final (pageIndex, pageOffset) = _resolveOffset(offset);
    final page = _pages[pageIndex];
    if (page == null) {
      throw StateError('Page $pageIndex not loaded');
    }
    return page[pageOffset] | (page[pageOffset + 1] << 8);
  }

  /// Reads a 16-bit signed integer (little-endian) at the given offset.
  int readInt16(int offset) {
    final val = readUint16(offset);
    return val >= 0x8000 ? val - 0x10000 : val;
  }

  /// Reads a 32-bit unsigned integer (little-endian) at the given offset.
  int readUint32(int offset) {
    final (pageIndex, pageOffset) = _resolveOffset(offset);
    final page = _pages[pageIndex];
    if (page == null) {
      throw StateError('Page $pageIndex not loaded');
    }
    return page[pageOffset] | (page[pageOffset + 1] << 8) | (page[pageOffset + 2] << 16) | (page[pageOffset + 3] << 24);
  }

  /// Reads a 32-bit signed integer (little-endian) at the given offset.
  int readInt32(int offset) {
    final val = readUint32(offset);
    return val >= 0x80000000 ? val - 0x100000000 : val;
  }

  /// Reads a block of bytes at the given offset.
  Uint8List readBytes(int offset, int length) {
    final (pageIndex, pageOffset) = _resolveOffset(offset);
    final page = _pages[pageIndex];
    if (page == null) {
      throw StateError('Page $pageIndex not loaded');
    }

    // Ensure the entire read is within one page
    assert(pageOffset + length <= pageSize, 'Cross-page read not supported');

    return Uint8List.sublistView(page, pageOffset, pageOffset + length);
  }

  /// Reads a constant string at the given pool offset.
  ///
  /// String format: UINT2 length + UTF-8 bytes
  /// The length does not include the 2-byte length prefix.
  String readString(int offset) {
    final length = readUint16(offset);
    final bytes = readBytes(offset + 2, length);

    return T3Utf8.decode(bytes);
  }

  // ==================== Constant List Access ====================

  /// Reads a constant list at the given pool offset.
  ///
  /// List format: UINT2 length (bytes) + element data
  /// Each element: 1-byte type + 4-byte value
  List<T3Value> readList(int offset) {
    final length = readUint16(offset);
    final elements = <T3Value>[];

    var pos = offset + 2;
    final endPos = pos + length;

    while (pos < endPos) {
      final value = readValue(pos);
      elements.add(value);
      pos += T3Value.portableSize;
    }

    return elements;
  }

  /// Reads a T3Value at the given pool offset.
  T3Value readValue(int offset) {
    final bytes = readBytes(offset, T3Value.portableSize);
    return T3Value.fromPortable(bytes, 0);
  }

  // ==================== Utility ====================

  @override
  String toString() => 'T3ConstantPool(id: $poolId, pages: $pageCount, pageSize: $pageSize)';
}
