import 'dart:typed_data';

/// T3 VM primitive datatypes as defined in the T3 specification.
///
/// These match the vm_datatype_t enum in the reference implementation.
/// See spec section "Datatypes" for details.
enum T3DataType {
  /// Nil - doubles as null pointer and boolean false.
  nil(1),

  /// True - boolean true.
  true_(2),

  /// Stack pointer (internal use).
  stack(3),

  /// Code pointer (internal use, native pointer).
  codeptr(4),

  /// Object reference - 32-bit object ID.
  obj(5),

  /// Property ID - 16-bit property identifier.
  prop(6),

  /// Integer - 32-bit signed value.
  int_(7),

  /// Constant string - offset into constant pool.
  sstring(8),

  /// Self-printing string - offset into constant pool.
  dstring(9),

  /// Constant list - offset into constant pool.
  list(10),

  /// Code offset - offset into code pool.
  codeofs(11),

  /// Function pointer - offset into code pool.
  funcptr(12),

  /// Empty/no value (internal use).
  empty(13),

  /// Native code descriptor (internal use).
  nativeCode(14),

  /// Enumerated constant - 32-bit value.
  enum_(15),

  /// Built-in function pointer - (setIndex:16 | funcIndex:16).
  bifptr(16),

  /// Built-in function pointer (extended format).
  bifptrx(17);

  final int code;
  const T3DataType(this.code);

  /// Returns the T3DataType for a given type code.
  static T3DataType? fromCode(int code) {
    for (final type in T3DataType.values) {
      if (type.code == code) return type;
    }
    return null;
  }
}

/// A typed value container for the T3 VM.
///
/// This is the fundamental unit of storage in the T3 VM. Stack locations,
/// local variables, machine registers, and object properties all use this
/// structure to store values.
///
/// Corresponds to `vm_val_t` in the reference implementation.
class T3Value {
  /// The datatype of this value.
  T3DataType type;

  /// The raw value, interpretation depends on [type].
  ///
  /// - For [T3DataType.nil]: always 0
  /// - For [T3DataType.true_]: always 1
  /// - For [T3DataType.int_]: 32-bit signed integer
  /// - For [T3DataType.obj]: object ID (0 = invalid)
  /// - For [T3DataType.prop]: property ID
  /// - For [T3DataType.sstring], [T3DataType.dstring]: constant pool offset
  /// - For [T3DataType.list]: constant pool offset
  /// - For [T3DataType.codeofs], [T3DataType.funcptr]: code pool offset
  /// - For [T3DataType.enum_]: enumeration constant value
  /// - For [T3DataType.bifptr]: (set_idx << 16) | func_idx
  int value;

  T3Value(this.type, this.value);

  // ==================== Factory Constructors ====================

  /// Creates a nil value.
  factory T3Value.nil() => T3Value(T3DataType.nil, 0);

  /// Creates a boolean true value.
  factory T3Value.true_() => T3Value(T3DataType.true_, 1);

  /// Creates an empty/no-value marker.
  factory T3Value.empty() => T3Value(T3DataType.empty, 0);

  /// Creates an integer value.
  factory T3Value.fromInt(int val) => T3Value(T3DataType.int_, val);

  /// Creates an object reference value.
  factory T3Value.fromObject(int objId) => T3Value(T3DataType.obj, objId);

  /// Creates a property ID value.
  factory T3Value.fromProp(int propId) => T3Value(T3DataType.prop, propId);

  /// Creates a constant string value.
  factory T3Value.fromString(int poolOffset) => T3Value(T3DataType.sstring, poolOffset);

  /// Creates a self-printing string value.
  factory T3Value.fromDString(int poolOffset) => T3Value(T3DataType.dstring, poolOffset);

  /// Creates a constant list value.
  factory T3Value.fromList(int poolOffset) => T3Value(T3DataType.list, poolOffset);

  /// Creates a code offset value.
  factory T3Value.fromCodeOffset(int offset) => T3Value(T3DataType.codeofs, offset);

  /// Creates a function pointer value.
  factory T3Value.fromFuncPtr(int offset) => T3Value(T3DataType.funcptr, offset);

  /// Creates an enumeration constant value.
  factory T3Value.fromEnum(int enumVal) => T3Value(T3DataType.enum_, enumVal);

  /// Creates a built-in function pointer.
  factory T3Value.fromBifPtr(int setIndex, int funcIndex) {
    return T3Value(T3DataType.bifptr, (setIndex << 16) | (funcIndex & 0xFFFF));
  }

  /// Creates an object reference or nil if objId is 0 (invalid).
  factory T3Value.fromObjectOrNil(int objId) {
    if (objId == 0) return T3Value.nil();
    return T3Value.fromObject(objId);
  }

  // ==================== Type Checking ====================

  bool get isNil => type == T3DataType.nil;
  bool get isTrue => type == T3DataType.true_;
  bool get isEmpty => type == T3DataType.empty;
  bool get isInt => type == T3DataType.int_;
  bool get isObject => type == T3DataType.obj;
  bool get isProp => type == T3DataType.prop;
  bool get isString => type == T3DataType.sstring;
  bool get isDString => type == T3DataType.dstring;
  bool get isList => type == T3DataType.list;
  bool get isCodeOffset => type == T3DataType.codeofs;
  bool get isFuncPtr => type == T3DataType.funcptr;
  bool get isEnum => type == T3DataType.enum_;
  bool get isBifPtr => type == T3DataType.bifptr || type == T3DataType.bifptrx;

  /// Returns true if this value represents a logical true.
  /// In T3, nil is false, everything else is true.
  bool get isLogicalTrue => type != T3DataType.nil;

  /// Returns true if this value is numeric (currently just integer).
  bool get isNumeric => type == T3DataType.int_;

  /// Returns true if this value can be used as a string.
  bool get isStringLike => type == T3DataType.sstring || type == T3DataType.dstring;

  // ==================== Value Extraction ====================

  /// Returns the integer value, or null if not an integer.
  int? asInt() => isInt ? value : null;

  /// Returns the object ID, or null if not an object.
  int? asObject() => isObject ? value : null;

  /// Returns the property ID, or null if not a property.
  int? asProp() => isProp ? value : null;

  /// Returns the pool offset for strings, or null if not a string.
  int? asStringOffset() => isStringLike ? value : null;

  /// Returns the pool offset for lists, or null if not a list.
  int? asListOffset() => isList ? value : null;

  /// Returns the code offset for code offsets or function pointers.
  int? asCodeOffset() => (isCodeOffset || isFuncPtr) ? value : null;

  /// For bifptr, returns (setIndex, funcIndex).
  (int, int)? asBifPtr() {
    if (!isBifPtr) return null;
    return ((value >> 16) & 0xFFFF, value & 0xFFFF);
  }

  // ==================== Comparison ====================

  /// Compares two values for equality per the T3 spec.
  ///
  /// Two values are generally not equal unless they have the same type.
  /// Exceptions:
  /// - Object types may implement custom equality (via metaclass)
  /// - String constants and string objects can be equal if text matches
  /// - List constants and list objects can be equal if elements match
  bool equals(T3Value other) {
    // Same type check (simple cases)
    if (type != other.type) {
      // TODO: Handle cross-type comparisons for strings/lists/objects
      return false;
    }

    // For most types, equality is value equality
    return value == other.value;
  }

  // ==================== Portable Binary Format ====================

  /// Size of a portable value in bytes (1 type + 4 value).
  static const int portableSize = 5;

  /// Reads a T3Value from portable binary format.
  ///
  /// Format: 1-byte type code + 4-byte little-endian value.
  factory T3Value.fromPortable(Uint8List data, int offset) {
    final typeCode = data[offset];
    final type = T3DataType.fromCode(typeCode) ?? T3DataType.empty;

    final view = ByteData.view(data.buffer, data.offsetInBytes + offset + 1);
    final value = view.getInt32(0, Endian.little);

    return T3Value(type, value);
  }

  /// Writes this value to portable binary format.
  void toPortable(Uint8List data, int offset) {
    data[offset] = type.code;
    final view = ByteData.view(data.buffer, data.offsetInBytes + offset + 1);
    view.setInt32(0, value, Endian.little);
  }

  // ==================== Utility ====================

  /// Creates a copy of this value.
  T3Value copy() => T3Value(type, value);

  @override
  String toString() {
    switch (type) {
      case T3DataType.nil:
        return 'nil';
      case T3DataType.true_:
        return 'true';
      case T3DataType.int_:
        return 'int($value)';
      case T3DataType.obj:
        return 'obj(#$value)';
      case T3DataType.prop:
        return 'prop(&$value)';
      case T3DataType.sstring:
        return 'sstring(@$value)';
      case T3DataType.dstring:
        return 'dstring(@$value)';
      case T3DataType.list:
        return 'list(@$value)';
      case T3DataType.codeofs:
        return 'codeofs(@$value)';
      case T3DataType.funcptr:
        return 'funcptr(@$value)';
      case T3DataType.enum_:
        return 'enum($value)';
      case T3DataType.bifptr:
      case T3DataType.bifptrx:
        final (set, func) = asBifPtr()!;
        return 'bifptr($set:$func)';
      case T3DataType.empty:
        return 'empty';
      default:
        return '${type.name}($value)';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! T3Value) return false;
    return type == other.type && value == other.value;
  }

  @override
  int get hashCode => Object.hash(type, value);
}
