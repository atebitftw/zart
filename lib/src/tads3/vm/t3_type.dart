// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// TADS3 VM Type System
///
/// This library provides the core type system for the TADS3 VM, including
/// data type definitions, value containers, and portable binary encoding/decoding.
/// It is a Dart port of the C++ vmtype.h and vmtype.cpp files.
///
/// Ported from: packages/tads-runner/tads3/vmtype.h
///              packages/tads-runner/tads3/vmtype.cpp
library;

import 'dart:typed_data';

// ----------------------------------------------------------------------------
// Type Definitions
// ----------------------------------------------------------------------------

/// Constant pool/code offset. This is an address of an object in the pool.
/// Pool offsets are 32-bit values.
typedef PoolOffset = int;

/// Savepoint ID's are stored in a single byte. This limits us to 256
/// simultaneous savepoints.
typedef SavepointId = int;

/// Maximum savepoint ID value
const int maxSavepointId = 255;

/// Object ID type. VM_INVALID_OBJ is a distinguished value that serves
/// as an invalid object ID (a null pointer, effectively); no object can
/// ever have this ID.
typedef ObjectId = int;

/// Invalid object ID constant
const ObjectId invalidObjectId = 0;

/// Property ID. Property ID's are 16-bit values. VM_INVALID_PROP is a
/// distinguished value that serves as an invalid property ID.
typedef PropertyId = int;

/// Invalid property ID constant
const PropertyId invalidPropertyId = 0;

/// Maximum recursion depth for recursive equality tests and hash calculations.
///
/// When comparing or hashing a tree of references by value, we keep track
/// of the recursion depth. If we reach this depth, we throw an error on the
/// assumption that the tree contains cycles.
const int maxTreeDepthEq = 256;

// ----------------------------------------------------------------------------
// Data Types
// ----------------------------------------------------------------------------

/// TADS3 VM data types
enum T3DataType {
  /// nil - doubles as a null pointer and a boolean false
  nil,

  /// true - boolean true
  trueValue,

  /// Stack pointer (used to store a pointer to the enclosing frame in a stack frame)
  stack,

  /// Code pointer (used to store a pointer to the return address in a stack frame)
  codePtr,

  /// Object reference
  obj,

  /// Property ID
  prop,

  /// 32-bit signed integer
  int32,

  /// String constant value - the value is an offset into the constant pool
  sstring,

  /// Self-printing string value - the value is an offset into the constant pool
  dstring,

  /// List constant - the value is an offset into the constant pool
  list,

  /// Byte-code constant offset - this is an offset into the byte-code pool
  codeOfs,

  /// Function pointer - represented as an offset into the byte-code pool
  funcPtr,

  /// Empty - indicates that a value is not present (different from nil)
  empty,

  /// Native code - evaluating requires executing system code
  nativeCode,

  /// Enumerated constant
  enumValue,

  /// Built-in function pointer
  bifPtr,

  /// Execute-on-evaluation object (internal pseudo-type)
  objX,

  /// Execute-on-evaluation built-in function pointer (internal pseudo-type)
  bifPtrX,

  /// First invalid type ID - tools can use this and higher IDs for internal types
  firstInvalidType,
}

// ----------------------------------------------------------------------------
// T3Value - Value Container
// ----------------------------------------------------------------------------

/// Value container for TADS3 VM values.
///
/// This is the Dart equivalent of the C++ vm_val_t struct. It stores a value
/// and its type. Since Dart doesn't have unions, we use nullable fields with
/// type checking.
class T3Value {
  /// The type of this value
  T3DataType type;

  // Union-like value storage (only one should be non-null based on type)

  /// For stack/code pointers (stored as offsets or references)
  int? _ptrValue;

  /// For object references
  ObjectId? _objValue;

  /// For property IDs
  PropertyId? _propValue;

  /// For 32-bit integers
  int? _intValue;

  /// For enumerated constants
  int? _enumValue;

  /// For string/list/code offsets
  PoolOffset? _ofsValue;

  /// For native code descriptors
  T3NativeCodeDesc? _nativeDesc;

  /// For built-in function pointers (set index)
  int? _bifSetIdx;

  /// For built-in function pointers (function index)
  int? _bifFuncIdx;

  /// Create a new value with the given type (defaults to nil)
  T3Value([this.type = T3DataType.nil]);

  /// Create a copy of another value
  T3Value.copy(T3Value other)
    : type = other.type,
      _ptrValue = other._ptrValue,
      _objValue = other._objValue,
      _propValue = other._propValue,
      _intValue = other._intValue,
      _enumValue = other._enumValue,
      _ofsValue = other._ofsValue,
      _nativeDesc = other._nativeDesc,
      _bifSetIdx = other._bifSetIdx,
      _bifFuncIdx = other._bifFuncIdx;

  // ------------------------------------------------------------------------
  // Setters
  // ------------------------------------------------------------------------

  /// Set to empty
  void setEmpty() {
    type = T3DataType.empty;
    _clearValues();
  }

  /// Set to nil
  void setNil() {
    type = T3DataType.nil;
    _clearValues();
  }

  /// Set to true
  void setTrue() {
    type = T3DataType.trueValue;
    _clearValues();
  }

  /// Set to a stack pointer
  void setStack(int ptr) {
    type = T3DataType.stack;
    _clearValues();
    _ptrValue = ptr;
  }

  /// Set to a code pointer
  void setCodePtr(int ptr) {
    type = T3DataType.codePtr;
    _clearValues();
    _ptrValue = ptr;
  }

  /// Set to an object reference
  void setObj(ObjectId obj) {
    type = T3DataType.obj;
    _clearValues();
    _objValue = obj;
  }

  /// Set to a property ID
  void setPropId(PropertyId prop) {
    type = T3DataType.prop;
    _clearValues();
    _propValue = prop;
  }

  /// Set to an integer
  void setInt(int intval) {
    type = T3DataType.int32;
    _clearValues();
    _intValue = intval;
  }

  /// Set to an enumerated constant
  void setEnum(int enumval) {
    type = T3DataType.enumValue;
    _clearValues();
    _enumValue = enumval;
  }

  /// Set to a string constant
  void setSstring(PoolOffset ofs) {
    type = T3DataType.sstring;
    _clearValues();
    _ofsValue = ofs;
  }

  /// Set to a self-printing string constant
  void setDstring(PoolOffset ofs) {
    type = T3DataType.dstring;
    _clearValues();
    _ofsValue = ofs;
  }

  /// Set to a list constant
  void setList(PoolOffset ofs) {
    type = T3DataType.list;
    _clearValues();
    _ofsValue = ofs;
  }

  /// Set to a code offset
  void setCodeOfs(PoolOffset ofs) {
    type = T3DataType.codeOfs;
    _clearValues();
    _ofsValue = ofs;
  }

  /// Set to a function pointer
  void setFnPtr(PoolOffset ofs) {
    type = T3DataType.funcPtr;
    _clearValues();
    _ofsValue = ofs;
  }

  /// Set to a built-in function pointer
  void setBifPtr(int setIdx, int funcIdx) {
    type = T3DataType.bifPtr;
    _clearValues();
    _bifSetIdx = setIdx;
    _bifFuncIdx = funcIdx;
  }

  /// Set to a native code descriptor
  void setNative(T3NativeCodeDesc desc) {
    type = T3DataType.nativeCode;
    _clearValues();
    _nativeDesc = desc;
  }

  /// Set to nil, specifically for a value that might be interpreted as an object ID
  void setNilObj() {
    type = T3DataType.nil;
    _clearValues();
    _objValue = invalidObjectId;
  }

  /// Set to an object or nil value: if the object ID is invalid, set type to nil
  void setObjOrNil(ObjectId obj) {
    type = T3DataType.obj;
    _clearValues();
    _objValue = obj;

    if (obj == invalidObjectId) {
      type = T3DataType.nil;
    }
  }

  /// Set to nil if val is zero, true if val is non-zero
  void setLogical(bool v) {
    type = v ? T3DataType.trueValue : T3DataType.nil;
    _clearValues();
  }

  /// Clear all value fields
  void _clearValues() {
    _ptrValue = null;
    _objValue = null;
    _propValue = null;
    _intValue = null;
    _enumValue = null;
    _ofsValue = null;
    _nativeDesc = null;
    _bifSetIdx = null;
    _bifFuncIdx = null;
  }

  // ------------------------------------------------------------------------
  // Getters
  // ------------------------------------------------------------------------

  /// Get an object, or null if it's not an object
  ObjectId? getAsObj() => type == T3DataType.obj ? _objValue : null;

  /// Get the value as an offset
  PoolOffset? getAsOfs() =>
      (type == T3DataType.sstring ||
          type == T3DataType.dstring ||
          type == T3DataType.list ||
          type == T3DataType.codeOfs ||
          type == T3DataType.funcPtr)
      ? _ofsValue
      : null;

  /// Get the value as a stack pointer
  int? getAsStack() => type == T3DataType.stack ? _ptrValue : null;

  /// Get the value as a code pointer
  int? getAsCodePtr() => type == T3DataType.codePtr ? _ptrValue : null;

  /// Get the value as a property ID
  int? getAsProp() => type == T3DataType.prop ? _propValue : null;

  /// Get the value as a native descriptor.
  /// Get the value as an integer, throwing an error if it's any other type
  int getAsInt() {
    if (type == T3DataType.int32) {
      return _intValue!;
    } else {
      throw T3TypeError('Numeric value required');
    }
  }

  /// Get as logical, checking type
  bool getLogicalOnly() {
    if (type == T3DataType.trueValue) {
      return true;
    } else if (type == T3DataType.nil) {
      return false;
    } else {
      throw T3TypeError('Bad type for built-in function');
    }
  }

  /// Get a logical as numeric TRUE or FALSE.
  /// Caller must ensure the value is either true or nil.
  bool getLogical() => type == T3DataType.trueValue;

  /// Determine if the value is logically true (exactly trueValue)
  bool get isLogicalTrue => type == T3DataType.trueValue;

  /// Determine if the value is "truthy" in TADS3 sense.
  /// In TADS3, everything is true EXCEPT nil, empty, and integer 0.
  bool get isTrue {
    if (type == T3DataType.nil || type == T3DataType.empty) return false;
    if (type == T3DataType.int32) return _intValue != 0;
    return true;
  }

  // ------------------------------------------------------------------------
  // Type Checking
  // ------------------------------------------------------------------------

  /// Determine if the value is logical (nil or true)
  bool isLogical() => type == T3DataType.nil || type == T3DataType.trueValue;

  /// Determine if the value is an integer
  bool isInt() => type == T3DataType.int32;

  /// Determine if the type is numeric (for now, just integers; BigNumber will be added later)
  bool isNumeric() => type == T3DataType.int32;

  // ------------------------------------------------------------------------
  // Conversion Methods
  // ------------------------------------------------------------------------

  /// Convert a numeric value to a logical value
  void numToLogical() {
    if (type == T3DataType.int32) {
      // Treat 0 as nil, all else as true
      type = (_intValue == 0) ? T3DataType.nil : T3DataType.trueValue;
      _clearValues();
    } else {
      throw T3TypeError('No logical conversion');
    }
  }

  /// Convert a numeric value to an integer
  int numToInt() {
    if (type == T3DataType.int32) {
      return _intValue!;
    } else {
      throw T3TypeError('Numeric value required');
    }
  }

  /// Convert a numeric value to a double
  double numToDouble() {
    if (type == T3DataType.int32) {
      return _intValue!.toDouble();
    } else {
      throw T3TypeError('Numeric value required');
    }
  }

  /// Cast to an integer (more aggressive than numToInt)
  int castToInt() {
    switch (type) {
      case T3DataType.trueValue:
        return 1;
      case T3DataType.nil:
        return 0;
      case T3DataType.int32:
        return _intValue!;
      default:
        throw T3TypeError('No integer conversion');
    }
  }

  /// Determine if the numeric value is zero
  bool numIsZero() {
    if (type == T3DataType.int32) {
      return _intValue == 0;
    } else {
      throw T3TypeError('Numeric value required');
    }
  }

  // ------------------------------------------------------------------------
  // Comparison Methods
  // ------------------------------------------------------------------------

  /// Determine if this value equals another value
  bool equals(T3Value other, [int depth = 0]) {
    // Check recursion depth
    if (depth > maxTreeDepthEq) {
      throw T3TypeError('Maximum tree depth exceeded in equality test');
    }

    // Handle different type combinations
    switch (type) {
      case T3DataType.nil:
      case T3DataType.trueValue:
        return other.type == type;

      case T3DataType.stack:
      case T3DataType.codePtr:
        return other.type == type && other._ptrValue == _ptrValue;

      case T3DataType.obj:
        // For now, just compare object IDs directly
        // TODO: Use object's polymorphic equality test when object system is ported
        return other.type == T3DataType.obj && other._objValue == _objValue;

      case T3DataType.prop:
        return other.type == T3DataType.prop && other._propValue == _propValue;

      case T3DataType.int32:
        return other.type == T3DataType.int32 && other._intValue == _intValue;

      case T3DataType.bifPtr:
      case T3DataType.bifPtrX:
        return other.type == T3DataType.bifPtr && other._bifSetIdx == _bifSetIdx && other._bifFuncIdx == _bifFuncIdx;

      case T3DataType.enumValue:
        return other.type == T3DataType.enumValue && other._enumValue == _enumValue;

      case T3DataType.sstring:
        // TODO: Use string comparison when string metaclass is ported
        return other.type == T3DataType.sstring && other._ofsValue == _ofsValue;

      case T3DataType.list:
        // TODO: Use list comparison when list metaclass is ported
        return other.type == T3DataType.list && other._ofsValue == _ofsValue;

      case T3DataType.objX:
        return other.type == type && other._objValue == _objValue;

      case T3DataType.codeOfs:
      case T3DataType.funcPtr:
        return other.type == type && other._ofsValue == _ofsValue;

      case T3DataType.empty:
        return false; // empty never matches anything

      case T3DataType.dstring:
        return false; // dstrings have no value, never equal

      default:
        return false; // other types not recognized
    }
  }

  /// Calculate a hash value for this value
  int calcHash([int depth = 0]) {
    // Check recursion depth
    if (depth > maxTreeDepthEq) {
      throw T3TypeError('Maximum tree depth exceeded in hash calculation');
    }

    switch (type) {
      case T3DataType.nil:
        return 0;

      case T3DataType.trueValue:
        return 1;

      case T3DataType.empty:
        return 2;

      case T3DataType.codeOfs:
      case T3DataType.funcPtr:
        // Use a 16-bit hash of the code address
        final ofs = _ofsValue!;
        return (ofs & 0xffff) ^ ((ofs & 0xffff0000) >> 16);

      case T3DataType.objX:
        // Use a 16-bit hash of the object ID
        final obj = _objValue!;
        return (obj & 0xffff) ^ ((obj & 0xffff0000) >> 16);

      case T3DataType.prop:
        return _propValue!;

      case T3DataType.int32:
        // Use the integer value directly
        final val = _intValue!;
        return (val & 0xffff) ^ ((val & 0xffff0000) >> 16);

      case T3DataType.bifPtr:
      case T3DataType.bifPtrX:
        // Multiply set index and function index, keep low 16 bits
        return (_bifSetIdx! * _bifFuncIdx!) & 0xffff;

      case T3DataType.enumValue:
        // Use a 16-bit hash of the enum value
        final val = _enumValue!;
        return (val & 0xffff) ^ ((val & 0xffff0000) >> 16);

      case T3DataType.obj:
        // TODO: Ask object to calculate its hash when object system is ported
        final obj = _objValue!;
        return (obj & 0xffff) ^ ((obj & 0xffff0000) >> 16);

      case T3DataType.sstring:
        // TODO: Get hash of constant string when string metaclass is ported
        final ofs = _ofsValue!;
        return (ofs & 0xffff) ^ ((ofs & 0xffff0000) >> 16);

      case T3DataType.list:
        // TODO: Get hash of constant list when list metaclass is ported
        final ofs = _ofsValue!;
        return (ofs & 0xffff) ^ ((ofs & 0xffff0000) >> 16);

      default:
        return 3; // arbitrary value for other types
    }
  }

  /// Compare this value to another value for magnitude ordering.
  /// Returns positive if this > other, negative if this < other, 0 if equal.
  int compareTo(T3Value other) {
    // Fast path for two integers
    if (type == T3DataType.int32 && other.type == T3DataType.int32) {
      final a = _intValue!;
      final b = other._intValue!;
      return a > b ? 1 : (a < b ? -1 : 0);
    }

    // General comparison
    return _genCompareTo(other);
  }

  /// General comparison implementation
  int _genCompareTo(T3Value other) {
    switch (type) {
      case T3DataType.obj:
        // TODO: Let object perform comparison when object system is ported
        throw T3TypeError('Invalid comparison');

      case T3DataType.sstring:
        // TODO: Compare string when string metaclass is ported
        throw T3TypeError('Invalid comparison');

      case T3DataType.int32:
        if (other.type == T3DataType.int32) {
          final a = _intValue!;
          final b = other._intValue!;
          return a - b;
        } else if (other.type == T3DataType.obj) {
          // TODO: Let object do comparison when object system is ported
          throw T3TypeError('Invalid comparison');
        } else {
          throw T3TypeError('Invalid comparison');
        }

      default:
        if (other.type == T3DataType.obj) {
          // TODO: Let object do comparison when object system is ported
          throw T3TypeError('Invalid comparison');
        } else {
          throw T3TypeError('Invalid comparison');
        }
    }
  }

  /// self > other
  bool isGt(T3Value other) {
    if (type == T3DataType.int32 && other.type == T3DataType.int32) {
      return _intValue! > other._intValue!;
    } else {
      return _genCompareTo(other) > 0;
    }
  }

  /// self >= other
  bool isGe(T3Value other) {
    if (type == T3DataType.int32 && other.type == T3DataType.int32) {
      return _intValue! >= other._intValue!;
    } else {
      return _genCompareTo(other) >= 0;
    }
  }

  /// self < other
  bool isLt(T3Value other) {
    if (type == T3DataType.int32 && other.type == T3DataType.int32) {
      return _intValue! < other._intValue!;
    } else {
      return _genCompareTo(other) < 0;
    }
  }

  /// self <= other
  bool isLe(T3Value other) {
    if (type == T3DataType.int32 && other.type == T3DataType.int32) {
      return _intValue! <= other._intValue!;
    } else {
      return _genCompareTo(other) <= 0;
    }
  }

  @override
  String toString() {
    switch (type) {
      case T3DataType.nil:
        return 'nil';
      case T3DataType.trueValue:
        return 'true';
      case T3DataType.int32:
        return _intValue.toString();
      case T3DataType.obj:
        return 'obj($_objValue)';
      case T3DataType.prop:
        return 'prop($_propValue)';
      case T3DataType.sstring:
        return 'sstring($_ofsValue)';
      case T3DataType.list:
        return 'list($_ofsValue)';
      case T3DataType.empty:
        return 'empty';
      default:
        return 'T3Value($type)';
    }
  }
}

// ----------------------------------------------------------------------------
// T3NativeCodeDesc - Native Code Descriptor
// ----------------------------------------------------------------------------

/// Describes a native method call of an intrinsic class object.
class T3NativeCodeDesc {
  /// Minimum argument count
  final int minArgc;

  /// Number of optional named arguments beyond the minimum
  final int optArgc;

  /// True if varargs: any number of arguments >= minArgc are valid
  final bool varargs;

  /// Create a descriptor with an exact number of arguments
  T3NativeCodeDesc(this.minArgc) : optArgc = 0, varargs = false;

  /// Create a descriptor with optional arguments (but not varargs)
  T3NativeCodeDesc.withOptional(this.minArgc, this.optArgc) : varargs = false;

  /// Create a descriptor with optional arguments and/or varargs
  T3NativeCodeDesc.withVarargs(this.minArgc, this.optArgc, this.varargs);

  /// Check if the given number of arguments is valid
  bool argsOk(int argc) {
    return argc >= minArgc && (varargs || argc <= minArgc + optArgc);
  }
}

// ----------------------------------------------------------------------------
// Portable Binary Helpers
// ----------------------------------------------------------------------------

/// Portable binary LENGTH indicator size (16-bit unsigned integer)
const int vmbLen = 2;

/// Portable binary unsigned 2-byte integer size
const int vmbUint2 = 2;

/// Portable binary unsigned 4-byte integer size
const int vmbUint4 = 4;

/// Portable binary signed 4-byte integer size
const int vmbInt4 = 4;

/// Portable binary object ID size
const int vmbObjectId = 4;

/// Portable binary property ID size
const int vmbPropId = 2;

/// Portable data holder size (1 byte type + 4 bytes value)
const int vmbDataholder = 5;

/// Offset from a portable data holder pointer to the data value
const int vmbDhDataOfs = 1;

/// Put a length value into a buffer
void vmbPutLen(Uint8List buf, int offset, int len) {
  final view = ByteData.view(buf.buffer, buf.offsetInBytes + offset);
  view.setUint16(0, len, Endian.little);
}

/// Get a length value from a buffer
int vmbGetLen(Uint8List buf, int offset) {
  final view = ByteData.view(buf.buffer, buf.offsetInBytes + offset);
  return view.getUint16(0, Endian.little);
}

/// Put an unsigned 2-byte integer into a buffer
void vmbPutUint2(Uint8List buf, int offset, int value) {
  final view = ByteData.view(buf.buffer, buf.offsetInBytes + offset);
  view.setUint16(0, value, Endian.little);
}

/// Get an unsigned 2-byte integer from a buffer
int vmbGetUint2(Uint8List buf, int offset) {
  final view = ByteData.view(buf.buffer, buf.offsetInBytes + offset);
  return view.getUint16(0, Endian.little);
}

/// Put an unsigned 4-byte integer into a buffer
void vmbPutUint4(Uint8List buf, int offset, int value) {
  final view = ByteData.view(buf.buffer, buf.offsetInBytes + offset);
  view.setUint32(0, value, Endian.little);
}

/// Get an unsigned 4-byte integer from a buffer
int vmbGetUint4(Uint8List buf, int offset) {
  final view = ByteData.view(buf.buffer, buf.offsetInBytes + offset);
  return view.getUint32(0, Endian.little);
}

/// Put a signed 4-byte integer into a buffer
void vmbPutInt4(Uint8List buf, int offset, int value) {
  final view = ByteData.view(buf.buffer, buf.offsetInBytes + offset);
  view.setInt32(0, value, Endian.little);
}

/// Get a signed 4-byte integer from a buffer
int vmbGetInt4(Uint8List buf, int offset) {
  final view = ByteData.view(buf.buffer, buf.offsetInBytes + offset);
  return view.getInt32(0, Endian.little);
}

/// Put an object ID into a buffer
void vmbPutObjId(Uint8List buf, int offset, ObjectId obj) {
  vmbPutUint4(buf, offset, obj);
}

/// Get an object ID from a buffer
ObjectId vmbGetObjId(Uint8List buf, int offset) {
  return vmbGetUint4(buf, offset);
}

/// Put a property ID into a buffer
void vmbPutPropId(Uint8List buf, int offset, PropertyId prop) {
  vmbPutUint2(buf, offset, prop);
}

/// Get a property ID from a buffer
PropertyId vmbGetPropId(Uint8List buf, int offset) {
  return vmbGetUint2(buf, offset);
}

/// Store a portable dataholder from a T3Value
void vmbPutDh(Uint8List buf, int offset, T3Value val) {
  // Store the type byte
  buf[offset] = val.type.index + 1; // +1 to match C++ enum values

  // Store the value based on type
  switch (val.type) {
    case T3DataType.nil:
    case T3DataType.trueValue:
    case T3DataType.empty:
      // No value to store
      break;

    case T3DataType.obj:
    case T3DataType.objX:
      vmbPutObjId(buf, offset + 1, val._objValue!);
      break;

    case T3DataType.prop:
      vmbPutPropId(buf, offset + 1, val._propValue!);
      break;

    case T3DataType.int32:
      vmbPutInt4(buf, offset + 1, val._intValue!);
      break;

    case T3DataType.sstring:
    case T3DataType.dstring:
    case T3DataType.list:
    case T3DataType.codeOfs:
    case T3DataType.funcPtr:
      vmbPutUint4(buf, offset + 1, val._ofsValue!);
      break;

    case T3DataType.enumValue:
      vmbPutUint4(buf, offset + 1, val._enumValue!);
      break;

    case T3DataType.bifPtr:
    case T3DataType.bifPtrX:
      vmbPutUint2(buf, offset + 1, val._bifSetIdx!);
      vmbPutUint2(buf, offset + 3, val._bifFuncIdx!);
      break;

    default:
      throw T3TypeError('Cannot encode type ${val.type} to dataholder');
  }
}

/// Store a nil value in a portable dataholder
void vmbPutDhNil(Uint8List buf, int offset) {
  buf[offset] = T3DataType.nil.index + 1;
}

/// Store an object value in a portable dataholder
void vmbPutDhObj(Uint8List buf, int offset, ObjectId obj) {
  buf[offset] = T3DataType.obj.index + 1;
  vmbPutObjId(buf, offset + 1, obj);
}

/// Store a property value in a portable dataholder
void vmbPutDhProp(Uint8List buf, int offset, PropertyId prop) {
  buf[offset] = T3DataType.prop.index + 1;
  vmbPutPropId(buf, offset + 1, prop);
}

/// Get the type from a portable dataholder
T3DataType vmbGetDhType(Uint8List buf, int offset) {
  final typeIndex = buf[offset] - 1; // -1 to match C++ enum values
  if (typeIndex < 0 || typeIndex >= T3DataType.values.length) {
    throw T3TypeError('Invalid type index in dataholder: $typeIndex');
  }
  return T3DataType.values[typeIndex];
}

/// Get the value portion of a T3Value from a portable dataholder
void vmbGetDhVal(Uint8List buf, int offset, T3Value val) {
  switch (val.type) {
    case T3DataType.nil:
    case T3DataType.trueValue:
    case T3DataType.empty:
      // No value to retrieve
      break;

    case T3DataType.obj:
    case T3DataType.objX:
      val._objValue = vmbGetObjId(buf, offset + 1);
      break;

    case T3DataType.prop:
      val._propValue = vmbGetPropId(buf, offset + 1);
      break;

    case T3DataType.int32:
      val._intValue = vmbGetInt4(buf, offset + 1);
      break;

    case T3DataType.sstring:
    case T3DataType.dstring:
    case T3DataType.list:
    case T3DataType.codeOfs:
    case T3DataType.funcPtr:
      val._ofsValue = vmbGetUint4(buf, offset + 1);
      break;

    case T3DataType.enumValue:
      val._enumValue = vmbGetUint4(buf, offset + 1);
      break;

    case T3DataType.bifPtr:
    case T3DataType.bifPtrX:
      val._bifSetIdx = vmbGetUint2(buf, offset + 1);
      val._bifFuncIdx = vmbGetUint2(buf, offset + 3);
      break;

    default:
      throw T3TypeError('Cannot decode type ${val.type} from dataholder');
  }
}

/// Get a T3Value from a portable dataholder
T3Value vmbGetDh(Uint8List buf, int offset) {
  final val = T3Value();
  val.type = vmbGetDhType(buf, offset);
  vmbGetDhVal(buf, offset, val);
  return val;
}

/// Get an object value from a portable dataholder
ObjectId vmbGetDhObj(Uint8List buf, int offset) {
  return vmbGetObjId(buf, offset + 1);
}

/// Get an integer value from a portable dataholder
int vmbGetDhInt(Uint8List buf, int offset) {
  return vmbGetInt4(buf, offset + 1);
}

/// Get a property ID value from a portable dataholder
PropertyId vmbGetDhProp(Uint8List buf, int offset) {
  return vmbGetPropId(buf, offset + 1);
}

/// Get a constant offset value from a portable dataholder
PoolOffset vmbGetDhOfs(Uint8List buf, int offset) {
  return vmbGetUint4(buf, offset + 1);
}

// ----------------------------------------------------------------------------
// T3Value Extension
// ----------------------------------------------------------------------------

/// Extension to add copyFrom to T3Value
extension T3ValueCopyExt on T3Value {
  /// Copy value from another T3Value
  ///
  /// This modifies this value in place by copying all fields from [other].
  void copyFrom(T3Value other) {
    type = other.type;
    _ptrValue = other._ptrValue;
    _objValue = other._objValue;
    _propValue = other._propValue;
    _intValue = other._intValue;
    _enumValue = other._enumValue;
    _ofsValue = other._ofsValue;
    _nativeDesc = other._nativeDesc;
    _bifSetIdx = other._bifSetIdx;
    _bifFuncIdx = other._bifFuncIdx;
  }
}

/// Exception thrown for type-related errors
class T3TypeError implements Exception {
  final String message;

  T3TypeError(this.message);

  @override
  String toString() => 'T3TypeError: $message';
}
