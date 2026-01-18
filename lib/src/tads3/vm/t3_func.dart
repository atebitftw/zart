// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// T3 VM Function Header and Exception Table Definitions.
///
/// This file contains classes for parsing function headers, exception tables,
/// and debug record tables from T3 VM bytecode. Ported from vmfunc.h/vmfunc.cpp.
library;

import 'dart:typed_data';

// ----------------------------------------------------------------------------
// Constants
// ----------------------------------------------------------------------------

/// Minimum function header size supported by the VM.
const int vmFuncHdrMinSize = 10;

/// Size of an exception table entry (start, end, exception class, handler).
/// 2 + 2 + 4 + 2 = 10 bytes.
const int vmExcEntrySize = 10;

// ----------------------------------------------------------------------------
// Function Header
// ----------------------------------------------------------------------------

/// T3 VM Function Header.
///
/// Parses the function header block that precedes every function's bytecode.
/// The header is stored in binary portable format (little-endian).
///
/// Header layout (10 bytes minimum):
/// - UBYTE argc: Parameter count (bit 7 = varargs, bits 0-6 = count)
/// - UBYTE optional_argc: Additional optional parameter count
/// - UINT2 locals: Number of local variables
/// - UINT2 total_stack: Total stack slots required
/// - UINT2 exception_table_ofs: Offset to exception table (0 = none)
/// - UINT2 debug_ofs: Offset to debug records (0 = none)
class T3FuncHeader {
  /// The raw data buffer containing the function header.
  final Uint8List _data;

  /// The offset into [_data] where the function header starts.
  final int _offset;

  /// Create a function header parser from a data buffer and offset.
  T3FuncHeader(this._data, this._offset);

  /// Create a function header parser from a data buffer at offset 0.
  T3FuncHeader.fromData(Uint8List data) : this(data, 0);

  /// Get the raw argc byte (includes varargs bit).
  int get _argc => _data[_offset];

  /// Get the additional optional argument count.
  int get optArgc => _data[_offset + 1];

  /// Get the number of local variables.
  int get localCnt => _readUint16(_offset + 2);

  /// Get the total stack slots required by the function.
  int get stackDepth => _readUint16(_offset + 4);

  /// Get the exception table offset (0 = no exception table).
  int get excOfs => _readUint16(_offset + 6);

  /// Get the debug records offset (0 = no debug records).
  int get debugOfs => _readUint16(_offset + 8);

  /// Get the minimum argument count.
  ///
  /// This masks out the varargs bit from the argc byte.
  int get minArgc => _argc & 0x7F;

  /// Get the maximum argument count (not counting varargs).
  ///
  /// This is the minimum argc plus the optional argc.
  int get maxArgc => minArgc + optArgc;

  /// Check if this is a varargs function.
  ///
  /// The high bit of the argc byte indicates varargs.
  bool get isVarargs => (_argc & 0x80) != 0;

  /// Check if the given argument count is valid for this function.
  ///
  /// Returns true if [argc] is within the valid range for this function.
  bool argcOk(int argc) {
    // Check for match to the min-max range
    if (argc >= minArgc && argc <= maxArgc) {
      return true;
    } else if (isVarargs && argc >= minArgc) {
      // Varargs functions accept any count >= minimum
      return true;
    }
    return false;
  }

  /// Check if this function has an exception table.
  bool get hasExcTable => excOfs != 0;

  /// Check if this function has debug records.
  bool get hasDebugRecords => debugOfs != 0;

  /// Get the offset to the first bytecode instruction.
  ///
  /// The bytecode starts immediately after the function header.
  int get codeOffset => _offset + vmFuncHdrMinSize;

  /// Read a little-endian UINT16 from the data buffer.
  int _readUint16(int offset) {
    return _data[offset] | (_data[offset + 1] << 8);
  }
}

// ----------------------------------------------------------------------------
// Exception Table
// ----------------------------------------------------------------------------

/// T3 VM Exception Table Entry.
///
/// Each entry specifies a handler for a protected range of code.
class T3ExcEntry {
  /// The raw data buffer containing the exception entry.
  final Uint8List _data;

  /// The offset into [_data] where this entry starts.
  final int _offset;

  /// Create an exception entry parser.
  T3ExcEntry(this._data, this._offset);

  /// Get the starting offset of the protected range.
  ///
  /// This is a byte offset from the start of the function.
  int get startOfs => _readUint16(_offset);

  /// Get the ending offset of the protected range (inclusive).
  ///
  /// This is a byte offset from the start of the function.
  int get endOfs => _readUint16(_offset + 2);

  /// Get the object ID of the exception class handled by this entry.
  int get exceptionClass => _readUint32(_offset + 4);

  /// Get the handler offset.
  ///
  /// This is a byte offset from the start of the function to the
  /// first instruction of the exception handler code.
  int get handlerOfs => _readUint16(_offset + 8);

  /// Check if the given code offset is within this entry's protected range.
  bool coversOffset(int codeOfs) {
    return codeOfs >= startOfs && codeOfs <= endOfs;
  }

  /// Read a little-endian UINT16.
  int _readUint16(int offset) {
    return _data[offset] | (_data[offset + 1] << 8);
  }

  /// Read a little-endian UINT32.
  int _readUint32(int offset) {
    return _data[offset] | (_data[offset + 1] << 8) | (_data[offset + 2] << 16) | (_data[offset + 3] << 24);
  }
}

/// T3 VM Exception Table.
///
/// The exception table starts with a count, followed by the entries.
/// Entries are searched in forward order, so handlers must be stored
/// in order of precedence.
class T3ExcTable {
  /// The raw data buffer containing the exception table.
  final Uint8List _data;

  /// The offset into [_data] where the exception table starts.
  final int _offset;

  /// Create an exception table parser.
  T3ExcTable(this._data, this._offset);

  /// Create an exception table from a function header.
  ///
  /// Returns null if the function has no exception table.
  static T3ExcTable? fromFuncHeader(T3FuncHeader header, Uint8List data) {
    if (!header.hasExcTable) return null;
    // Exception table offset is relative to function header start
    final tableOffset = header._offset + header.excOfs;
    return T3ExcTable(data, tableOffset);
  }

  /// Get the number of entries in the exception table.
  int get count => _readUint16(_offset);

  /// Get the exception entry at the given index.
  T3ExcEntry getEntry(int index) {
    if (index < 0 || index >= count) {
      throw RangeError.range(index, 0, count - 1, 'index');
    }
    // Entries start after the 2-byte count
    final entryOffset = _offset + 2 + (index * vmExcEntrySize);
    return T3ExcEntry(_data, entryOffset);
  }

  /// Find a handler for the given code offset and exception class.
  ///
  /// Searches entries in forward order. Returns the first matching entry,
  /// or null if no handler is found.
  ///
  /// The [isInstanceOf] callback should return true if the exception object
  /// is an instance of the given exception class ID.
  T3ExcEntry? findHandler(int codeOfs, bool Function(int exceptionClassId) isInstanceOf) {
    for (int i = 0; i < count; i++) {
      final entry = getEntry(i);
      if (entry.coversOffset(codeOfs) && isInstanceOf(entry.exceptionClass)) {
        return entry;
      }
    }
    return null;
  }

  /// Read a little-endian UINT16.
  int _readUint16(int offset) {
    return _data[offset] | (_data[offset + 1] << 8);
  }
}

// ----------------------------------------------------------------------------
// Debug Records (Minimal Support)
// ----------------------------------------------------------------------------

/// T3 VM Debug Table.
///
/// Provides minimal support for checking if debug records exist and
/// accessing basic debug information.
class T3DbgTable {
  /// The raw data buffer containing the debug table.
  final Uint8List _data;

  /// The offset into [_data] where the debug table starts.
  final int _offset;

  /// Create a debug table parser.
  T3DbgTable(this._data, this._offset);

  /// Create a debug table from a function header.
  ///
  /// Returns null if the function has no debug records.
  static T3DbgTable? fromFuncHeader(T3FuncHeader header, Uint8List data) {
    if (!header.hasDebugRecords) return null;
    // Debug table offset is relative to function header start
    final tableOffset = header._offset + header.debugOfs;
    return T3DbgTable(data, tableOffset);
  }

  /// Check if this debug table is valid (has data).
  bool get isValid => _offset < _data.length;
}
