import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_interpreter.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';

void main() {
  group('T3 Property Access', () {
    late T3Interpreter interp;

    setUp(() {
      interp = T3Interpreter();
    });

    test('simple property retrieval', () {
      final obj = T3TadsObject(
        objectId: 100,
        superclasses: [],
        loadImageProperties: [T3ObjectProperty(10, T3Value.fromInt(42))],
        flags: 0,
      );
      interp.objectTable.register(obj);

      // Testing _evalProperty through the interpreter's logic
      // Since it's private, we'll verify it via opcode execution
      // or by making a test-only subclass that exposes it.
      // For simplicity, we'll just test the object and object table directly.

      final result = interp.objectTable.lookupProperty(100, 10);
      expect(result, isNotNull);
      expect(result!.value.value, equals(42));
      expect(result.definingObjectId, equals(100));
    });

    test('property inheritance', () {
      final parent = T3TadsObject(
        objectId: 50,
        superclasses: [],
        loadImageProperties: [T3ObjectProperty(10, T3Value.fromInt(42))],
        flags: T3TadsObject.flagIsClass,
      );
      final child = T3TadsObject(objectId: 100, superclasses: [50], loadImageProperties: [], flags: 0);

      interp.objectTable.register(parent);
      interp.objectTable.register(child);

      final result = interp.objectTable.lookupProperty(100, 10);
      expect(result, isNotNull);
      expect(result!.value.value, equals(42));
      expect(result.definingObjectId, equals(50));
    });

    test('property override', () {
      final parent = T3TadsObject(
        objectId: 50,
        superclasses: [],
        loadImageProperties: [T3ObjectProperty(10, T3Value.fromInt(42))],
        flags: T3TadsObject.flagIsClass,
      );
      final child = T3TadsObject(
        objectId: 100,
        superclasses: [50],
        loadImageProperties: [T3ObjectProperty(10, T3Value.fromInt(99))],
        flags: 0,
      );

      interp.objectTable.register(parent);
      interp.objectTable.register(child);

      final result = interp.objectTable.lookupProperty(100, 10);
      expect(result, isNotNull);
      expect(result!.value.value, equals(99));
      expect(result.definingObjectId, equals(100));
    });
  });
}
