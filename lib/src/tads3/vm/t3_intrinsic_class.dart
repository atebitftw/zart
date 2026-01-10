import 'dart:typed_data';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_undo.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';

/// IntrinsicClass - represents a metaclass as a first-class object.
///
/// In TADS3, each intrinsic metaclass (BigNumber, String, List, etc.) has
/// a corresponding IntrinsicClass object that represents the class itself.
/// This allows calling static methods like `BigNumber.getPi()`.
class T3IntrinsicClass extends T3Object {
  final String metaclassName;
  final int metaclassIndex;

  T3IntrinsicClass({
    required super.objectId,
    required this.metaclassName,
    required this.metaclassIndex,
    super.isTransient,
  }) : super(metaclass: 'intrinsic-class');

  @override
  T3Value? getProperty(int propId) {
    // Property access on IntrinsicClass objects is handled through
    // the metaclass's static method dispatch mechanism
    return null;
  }

  @override
  void setProperty(int propId, T3Value value, {T3UndoManager? undoManager}) {
    throw UnsupportedError('IntrinsicClass properties are read-only');
  }

  @override
  Uint8List save() {
    // IntrinsicClass objects are usually not saved - they're recreated on load
    return Uint8List(0);
  }

  @override
  Map<String, dynamic> get debugInfo => {
    'objectId': objectId,
    'metaclass': metaclass,
    'intrinsicMetaclass': metaclassName,
    'metaclassIndex': metaclassIndex,
  };

  @override
  String toString() => 'T3IntrinsicClass(#$objectId, $metaclassName)';
}
