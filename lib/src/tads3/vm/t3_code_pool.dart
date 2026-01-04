import 'dart:typed_data';
import 'package:zart/src/tads3/vm/t3_utf8.dart';

/// T3 VM code pool.
///
/// The code pool stores executable bytecode in a paged structure.
/// Each method must be entirely contained within a single page.
///
/// See spec sections "Memory Model" and "Constant Pool Definition Block".
class T3CodePool {
  /// Pool identifier (1 = code pool, 2 = constant pool).
  final int poolId;

  /// Number of pages in this pool.
  final int pageCount;

  /// Size of each page in bytes.
  final int pageSize;

  /// The pages of this pool.
  final List<Uint8List?> _pages;

  /// Creates a code pool with the specified structure.
  T3CodePool({required this.poolId, required this.pageCount, required this.pageSize})
    : _pages = List<Uint8List?>.filled(pageCount, null);

  /// Total size of the pool in bytes.
  int get totalSize => pageCount * pageSize;

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
      throw StateError('Code page $pageIndex not loaded (offset: 0x${offset.toRadixString(16)})');
    }
    if (pageOffset >= page.length) {
      throw RangeError('Code offset 0x${offset.toRadixString(16)} past end of page');
    }
    return page[pageOffset];
  }

  /// Reads an 8-bit signed integer at the given offset.
  int readInt8(int offset) {
    final val = readByte(offset);
    return val >= 0x80 ? val - 0x100 : val;
  }

  /// Reads a 16-bit unsigned integer (little-endian) at the given offset.
  int readUint16(int offset) {
    final (pageIndex, pageOffset) = _resolveOffset(offset);
    final page = _pages[pageIndex];
    if (page == null) {
      throw StateError('Code page $pageIndex not loaded');
    }
    return (page[pageOffset] & 0xFF) | ((page[pageOffset + 1] & 0xFF) << 8);
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
      throw StateError('Code page $pageIndex not loaded');
    }
    // Mask each byte to prevent sign extension when shifting
    return (page[pageOffset] & 0xFF) |
        ((page[pageOffset + 1] & 0xFF) << 8) |
        ((page[pageOffset + 2] & 0xFF) << 16) |
        ((page[pageOffset + 3] & 0xFF) << 24);
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
      throw StateError('Code page $pageIndex not loaded');
    }

    // Ensure the entire read is within one page (methods cannot span pages)
    assert(pageOffset + length <= pageSize, 'Cross-page read not supported');

    return Uint8List.sublistView(page, pageOffset, pageOffset + length);
  }

  // ==================== Method Header Access ====================

  /// Reads a method header at the given offset.
  ///
  /// The method header structure depends on the header size specified
  /// in the ENTP block. Minimum header contains:
  /// - Byte 0: Argument count (high bit = varargs flag)
  /// - Byte 1: Optional argument count (format v2+)
  /// - Byte 2-3: Local variable count (UINT2)
  /// - Byte 4-5: Total stack slots needed (UINT2)
  /// - Byte 6-7: Exception table offset (UINT2, relative to method start)
  /// - Byte 8-9: Debug record offset (UINT2, relative to method start)
  MethodHeader readMethodHeader(int offset, int headerSize) {
    final bytes = readBytes(offset, headerSize);
    final view = ByteData.view(bytes.buffer, bytes.offsetInBytes);

    final argByte = bytes[0];
    final isVarargs = (argByte & 0x80) != 0;
    final minArgs = argByte & 0x7F;

    // Optional args (v2+), default to 0 if not present
    final optionalArgs = headerSize > 1 ? bytes[1] : 0;

    // Local count at offset 2
    final localCount = view.getUint16(2, Endian.little);

    // Stack slots at offset 4
    final stackSlots = view.getUint16(4, Endian.little);

    // Exception table offset at offset 6
    final exceptionTableOffset = view.getUint16(6, Endian.little);

    // Debug record offset at offset 8
    final debugRecordOffset = headerSize > 8 ? view.getUint16(8, Endian.little) : 0;

    return MethodHeader(
      minArgs: minArgs,
      optionalArgs: optionalArgs,
      isVarargs: isVarargs,
      localCount: localCount,
      stackSlots: stackSlots,
      exceptionTableOffset: exceptionTableOffset,
      debugRecordOffset: debugRecordOffset,
      headerSize: headerSize,
    );
  }

  // ==================== String Access ====================

  /// Reads a string at the given pool offset (e.g. for dstring).
  String readString(int offset) {
    final length = readUint16(offset);
    final bytes = readBytes(offset + 2, length);
    return T3Utf8.decode(bytes);
  }

  // ==================== Utility ====================

  @override
  String toString() => 'T3CodePool(id: $poolId, pages: $pageCount, pageSize: $pageSize)';
}

/// Parsed method header.
class MethodHeader {
  /// Minimum number of arguments required.
  final int minArgs;

  /// Number of optional arguments (beyond minArgs).
  final int optionalArgs;

  /// True if this method accepts variable arguments.
  final bool isVarargs;

  /// Number of local variables.
  final int localCount;

  /// Total stack slots needed (locals + working space).
  final int stackSlots;

  /// Offset to exception table (relative to method start), 0 if none.
  final int exceptionTableOffset;

  /// Offset to debug record (relative to method start), 0 if none.
  final int debugRecordOffset;

  /// Size of this header in bytes.
  final int headerSize;

  const MethodHeader({
    required this.minArgs,
    required this.optionalArgs,
    required this.isVarargs,
    required this.localCount,
    required this.stackSlots,
    required this.exceptionTableOffset,
    required this.debugRecordOffset,
    required this.headerSize,
  });

  /// Maximum number of arguments (for varargs, this is just minArgs).
  int get maxArgs => isVarargs ? 255 : minArgs + optionalArgs;

  /// Offset to first bytecode instruction (immediately after header).
  int get codeOffset => headerSize;

  @override
  String toString() {
    final argsStr = isVarargs ? '$minArgs+' : '$minArgs';
    return 'MethodHeader(args: $argsStr, locals: $localCount, stack: $stackSlots)';
  }
}
