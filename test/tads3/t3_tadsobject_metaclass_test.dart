import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_interpreter.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';

/// T3 TadsObject Metaclass unit tests with spec validation.
///
/// Spec Reference: packages/tads-runner/tads3/vmtobj.cpp
/// TadsObject is the base object metaclass with 6 primary methods.
void main() {
  group('TadsObject metaclass per vmtobj.cpp', () {
    late T3Interpreter interp;

    setUp(() {
      interp = T3Interpreter();
    });

    /// vmtobj.cpp:309 - PROPIDX_CREATE_INSTANCE = 1
    group('createInstance [1]', () {
      test('not implemented via invocation', () {
        expect(true, isTrue);
      }, skip: 'DISCREPANCY: createInstance needs full interpreter invocation');
    });

    /// vmtobj.cpp:310 - PROPIDX_CREATE_CLONE = 2
    group('createClone [2]', () {
      test('not implemented via invocation', () {
        expect(true, isTrue);
      }, skip: 'DISCREPANCY: createClone needs full interpreter invocation');
    });

    /// vmtobj.cpp:311 - PROPIDX_CREATE_TRANS_INSTANCE = 3
    group('createTransientInstance [3]', () {
      test('not implemented via invocation', () {
        expect(true, isTrue);
      }, skip: 'DISCREPANCY: createTransientInstance needs interpreter');
    });

    /// vmtobj.cpp:312 - PROPIDX_CREATE_INSTANCE_OF = 4
    group('createInstanceOf [4]', () {
      test('not implemented via invocation', () {
        expect(true, isTrue);
      }, skip: 'DISCREPANCY: createInstanceOf needs interpreter');
    });

    /// vmtobj.cpp:313 - PROPIDX_CREATE_TRANS_INSTANCE_OF = 5
    group('createTransientInstanceOf [5]', () {
      test('not implemented via invocation', () {
        expect(true, isTrue);
      }, skip: 'DISCREPANCY: createTransientInstanceOf needs interpreter');
    });
  });

  group('T3TadsObject direct tests', () {
    test('object creation with ID and superclasses', () {
      final obj = T3TadsObject(objectId: 100, superclasses: [50, 60], loadImageProperties: [], flags: 0);
      expect(obj.objectId, 100);
      expect(obj.superclasses, [50, 60]);
    });

    test('object with properties', () {
      final obj = T3TadsObject(
        objectId: 100,
        superclasses: [],
        loadImageProperties: [T3ObjectProperty(10, T3Value.fromInt(42)), T3ObjectProperty(20, T3Value.fromString(500))],
        flags: 0,
      );
      expect(obj.getProperty(10)?.value, 42);
      expect(obj.getProperty(20)?.type, T3DataType.sstring);
    });

    test('isClass flag', () {
      final classObj = T3TadsObject(
        objectId: 100,
        superclasses: [],
        loadImageProperties: [],
        flags: T3TadsObject.flagIsClass,
      );
      expect(classObj.isClass, isTrue);
    });

    test('non-class instance', () {
      final instance = T3TadsObject(objectId: 100, superclasses: [], loadImageProperties: [], flags: 0);
      expect(instance.isClass, isFalse);
    });

    test('setProperty adds new property', () {
      final obj = T3TadsObject(objectId: 100, superclasses: [], loadImageProperties: [], flags: 0);
      obj.setProperty(10, T3Value.fromInt(999));
      expect(obj.getProperty(10)?.value, 999);
    });

    test('setProperty updates existing property', () {
      final obj = T3TadsObject(
        objectId: 100,
        superclasses: [],
        loadImageProperties: [T3ObjectProperty(10, T3Value.fromInt(1))],
        flags: 0,
      );
      obj.setProperty(10, T3Value.fromInt(2));
      expect(obj.getProperty(10)?.value, 2);
    });
  });

  group('Object inheritance mechanics', () {
    late T3Interpreter interp;

    setUp(() {
      interp = T3Interpreter();
    });

    /// Spec: model.htm - Property lookup follows superclass chain.
    test('property inherited from superclass', () {
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
      expect(result?.value.value, 42);
      expect(result?.definingObjectId, 50);
    });

    /// Spec: model.htm - Child properties override parent.
    test('property overridden in child', () {
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
      expect(result?.value.value, 99);
      expect(result?.definingObjectId, 100);
    });

    /// Spec: Multi-level inheritance chain.
    test('three-level inheritance', () {
      final grandparent = T3TadsObject(
        objectId: 1,
        superclasses: [],
        loadImageProperties: [T3ObjectProperty(5, T3Value.fromInt(111))],
        flags: T3TadsObject.flagIsClass,
      );
      final parent = T3TadsObject(
        objectId: 2,
        superclasses: [1],
        loadImageProperties: [],
        flags: T3TadsObject.flagIsClass,
      );
      final child = T3TadsObject(objectId: 3, superclasses: [2], loadImageProperties: [], flags: 0);

      interp.objectTable.register(grandparent);
      interp.objectTable.register(parent);
      interp.objectTable.register(child);

      final result = interp.objectTable.lookupProperty(3, 5);
      expect(result?.value.value, 111);
      expect(result?.definingObjectId, 1);
    });

    /// Spec: Property not found returns null.
    test('missing property returns null', () {
      final obj = T3TadsObject(objectId: 100, superclasses: [], loadImageProperties: [], flags: 0);
      interp.objectTable.register(obj);

      expect(interp.objectTable.lookupProperty(100, 999), isNull);
    });
  });
}
