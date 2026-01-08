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
      test('creates new instance with superclass', () {
        // Create a parent object
        final parent = T3TadsObject(
          objectId: 50,
          superclasses: [],
          loadImageProperties: [],
          flags: T3TadsObject.flagIsClass,
        );
        interp.objectTable.register(parent);

        final target = T3Value.fromObject(50);
        // Call createInstance on parent
        interp.handleTadsObjectIntrinsic(1, target, 0);

        final result = interp.registers.r0;
        expect(result.isObject, isTrue);
        expect(result.value, isNot(50)); // Should be new ID

        final newObj = interp.objectTable.lookup(result.value) as T3TadsObject;
        expect(newObj.superclasses, contains(50));
      });
    });

    /// vmtobj.cpp:310 - PROPIDX_CREATE_CLONE = 2
    group('createClone [2]', () {
      test('creates shallow copy and calls constructClone', () {
        // Setup original
        final original = T3TadsObject(objectId: 50, superclasses: [10], loadImageProperties: [], flags: 0);
        interp.objectTable.register(original);

        final target = T3Value.fromObject(50);
        interp.handleTadsObjectIntrinsic(2, target, 0);

        final result = interp.registers.r0;
        expect(result.isObject, isTrue);
        expect(result.value, isNot(50));

        final clone = interp.objectTable.lookup(result.value) as T3TadsObject;
        expect(clone.superclasses, contains(10));
      });
    });

    /// vmtobj.cpp:311 - PROPIDX_CREATE_TRANS_INSTANCE = 3
    group('createTransientInstance [3]', () {
      test('creates transient instance', () {
        final parent = T3TadsObject(
          objectId: 50,
          superclasses: [],
          loadImageProperties: [],
          flags: T3TadsObject.flagIsClass,
        );
        interp.objectTable.register(parent);

        final target = T3Value.fromObject(50);
        interp.handleTadsObjectIntrinsic(3, target, 0);

        final result = interp.registers.r0;
        expect(result.isObject, isTrue);

        final newObj = interp.objectTable.lookup(result.value) as T3TadsObject;
        expect(newObj.isTransient, isTrue);
        expect(newObj.superclasses, contains(50));
      });
    });

    /// vmtobj.cpp:312 - PROPIDX_CREATE_INSTANCE_OF = 4
    group('createInstanceOf [4]', () {
      test('creates instance of specified class', () {
        final parent = T3TadsObject(
          objectId: 60,
          superclasses: [],
          loadImageProperties: [],
          flags: T3TadsObject.flagIsClass,
        );
        interp.objectTable.register(parent);

        // Target can be anything (e.g., TadsObject meta object), here just dummy
        final target = T3Value.fromObject(100);

        // Arg1: Class to instantiate
        interp.stack.push(T3Value.fromObject(60));

        interp.handleTadsObjectIntrinsic(4, target, 1);

        final result = interp.registers.r0;
        expect(result.isObject, isTrue);

        final newObj = interp.objectTable.lookup(result.value) as T3TadsObject;
        expect(newObj.superclasses, contains(60));
      });
    });

    /// vmtobj.cpp:313 - PROPIDX_CREATE_TRANS_INSTANCE_OF = 5
    group('createTransientInstanceOf [5]', () {
      test('creates transient instance of specified class', () {
        final parent = T3TadsObject(
          objectId: 70,
          superclasses: [],
          loadImageProperties: [],
          flags: T3TadsObject.flagIsClass,
        );
        interp.objectTable.register(parent);

        final target = T3Value.fromObject(100);
        interp.stack.push(T3Value.fromObject(70));

        interp.handleTadsObjectIntrinsic(5, target, 1);

        final result = interp.registers.r0;
        expect(result.isObject, isTrue);

        final newObj = interp.objectTable.lookup(result.value) as T3TadsObject;
        expect(newObj.isTransient, isTrue);
        expect(newObj.superclasses, contains(70));
      });
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
