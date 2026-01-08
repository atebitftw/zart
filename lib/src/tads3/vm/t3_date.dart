import 'dart:typed_data';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_undo.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';

/// Date object.
///
/// Stores date and time information.
/// Exact binary format is internal, for now we treat it as an opaque blob
/// for serialization purposes until we implement the intrinsic methods.
class T3Date extends T3Object {
  final Uint8List _data;

  T3Date({required super.objectId, required Uint8List data, super.isTransient})
    : _data = data,
      super(metaclass: 'date');

  /// Creates a default Date object (placeholder data).
  factory T3Date.create(int objectId, {bool isTransient = false}) {
    // Placeholder 8 bytes or similar.
    // Spec says nothing, but usually a timestamp structure.
    return T3Date(
      objectId: objectId,
      data: Uint8List(8),
      isTransient: isTransient,
    );
  }

  factory T3Date.fromData(
    int objectId,
    Uint8List data, {
    bool isTransient = false,
  }) {
    return T3Date(
      objectId: objectId,
      data: Uint8List.fromList(data),
      isTransient: isTransient,
    );
  }

  @override
  Uint8List save() {
    return _data;
  }

  @override
  T3Value? getProperty(int propId) {
    return null;
  }

  @override
  void setProperty(int propId, T3Value value, {T3UndoManager? undoManager}) {
    throw UnsupportedError('Date properties are read-only');
  }

  @override
  Map<String, dynamic> get debugInfo => {
    'objectId': objectId,
    'metaclass': metaclass,
  };
}

/// TimeZone object.
///
/// Stores timezone information.
class T3TimeZone extends T3Object {
  final Uint8List _data;

  T3TimeZone({
    required super.objectId,
    required Uint8List data,
    super.isTransient,
  }) : _data = data,
       super(metaclass: 'timezone');

  factory T3TimeZone.create(int objectId, {bool isTransient = false}) {
    // Placeholder data
    return T3TimeZone(
      objectId: objectId,
      data: Uint8List(8),
      isTransient: isTransient,
    );
  }

  factory T3TimeZone.fromData(
    int objectId,
    Uint8List data, {
    bool isTransient = false,
  }) {
    return T3TimeZone(
      objectId: objectId,
      data: Uint8List.fromList(data),
      isTransient: isTransient,
    );
  }

  @override
  Uint8List save() {
    return _data;
  }

  @override
  T3Value? getProperty(int propId) {
    return null;
  }

  @override
  void setProperty(int propId, T3Value value, {T3UndoManager? undoManager}) {
    throw UnsupportedError('TimeZone properties are read-only');
  }

  @override
  Map<String, dynamic> get debugInfo => {
    'objectId': objectId,
    'metaclass': metaclass,
  };
}
