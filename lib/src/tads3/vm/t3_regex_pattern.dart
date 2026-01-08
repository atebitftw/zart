import 'dart:typed_data';

import 'package:zart/src/tads3/vm/t3_interpreter.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_undo.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';

/// TADS 3 RegexPattern Metaclass.
///
/// Wraps a compiled regular expression. In TADS 3, this object stores the
/// source string of the pattern. The actual compilation happens on demand
/// (or is cached).
///
/// See: internal docs or vmpat.cpp in TADS 3 source.
class T3RegexPattern extends T3Object {
  /// The source pattern string value.
  /// Usually a reference to a constant string or string object.
  T3Value source;

  /// Cached RegExp object.
  RegExp? _cachedRegex;

  /// Cached pattern string literal.
  String? _cachedPatternString;

  T3RegexPattern(int objectId, this.source) : super(objectId: objectId, metaclass: 'regex-pattern');

  /// Creates a [T3RegexPattern] with a new ID.
  ///
  /// Note: The ID allocation logic is typically handled by the caller or ObjectTable,
  /// but here we accept an ID or use a placeholder if transient (not applicable here).
  factory T3RegexPattern.create(int objectId, T3Value source) {
    return T3RegexPattern(objectId, source);
  }

  /// Creates a [T3RegexPattern] from saved data.
  factory T3RegexPattern.fromData(int objectId, Uint8List data) {
    if (data.length < 5) {
      throw FormatException('Invalid data for RegexPattern: length ${data.length}');
    }
    // Read the source T3Value (5 bytes)
    final val = T3Value.fromPortable(data, 0);
    return T3RegexPattern(objectId, val);
  }

  @override
  Uint8List save() {
    final data = Uint8List(5); // 1 byte type + 4 bytes value
    source.toPortable(data, 0);
    return data;
  }

  @override
  T3Value? getProperty(int propId) {
    // RegexPattern objects don't have standard properties.
    return null;
  }

  @override
  void setProperty(int propId, T3Value value, {T3UndoManager? undoManager}) {
    throw UnsupportedError('RegexPattern objects are immutable.');
  }

  @override
  Map<String, dynamic> get debugInfo => {
    'metaclass': metaclass,
    'source': source.toString(),
    'cachedRegex': _cachedRegex?.pattern ?? 'null',
  };

  /// Gets the Dart [RegExp] object for this pattern.
  /// Compiles it if necessary.
  RegExp getRegExp(T3Interpreter interp) {
    if (_cachedRegex != null) return _cachedRegex!;

    final patternStr = _getPatternString(interp);
    try {
      // TADS 3 regex flavor is somewhat different from JS/Dart,
      // but for now we attempt to assume compatibility or basic patterns.
      // JS RegExp (which Dart uses) is reasonably close for common cases.
      // Flags handling might be needed if they are part of the object state,
      // but normally they are embedded in the pattern compilation or passed.
      // TADS 3 patterns typically don't have inline flags in the structure itself,
      // but usage sites (re_match) might pass flags.
      // However, CVmObjPattern seems to just store the string.
      // So flags are part of the string (e.g. <Case>) or passed externally?
      // Actually vmpat.cpp just stores the source string.
      _cachedRegex = RegExp(patternStr);
      return _cachedRegex!;
    } catch (e) {
      // Fallback or better error handling
      throw Exception('Invalid regex pattern: $patternStr');
    }
  }

  /// Gets the raw pattern string.
  String _getPatternString(T3Interpreter interp) {
    if (_cachedPatternString != null) return _cachedPatternString!;
    _cachedPatternString = interp.getStringValue(source);
    return _cachedPatternString!;
  }

  @override
  String toString() {
    return 'regex-pattern(#$objectId, source=$source)';
  }
}
