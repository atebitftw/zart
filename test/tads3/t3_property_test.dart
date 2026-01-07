import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_interpreter.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';

/// T3 Property unit tests with TADS 3 specification validation.
///
/// Spec Reference: packages/tads-sources/t3doc/techman/t3spec/model.htm
/// - "Object Model" section (lines 527-775)
/// - "Generic Objects" interface (lines 556-710)
void main() {
  group('Property get operation', () {
    late T3Interpreter interp;

    setUp(() {
      interp = T3Interpreter();
    });

    /// Spec: model.htm lines 576-578:
    /// "Get a property value. This takes a property ID as the argument,
    /// and returns the value of the given property and whether the property
    /// exists in the object or not."
    test('getProperty returns value for existing property', () {
      final obj = T3TadsObject(
        objectId: 100,
        superclasses: [],
        loadImageProperties: [T3ObjectProperty(10, T3Value.fromInt(42))],
        flags: 0,
      );
      interp.objectTable.register(obj);

      final result = interp.objectTable.lookupProperty(100, 10);
      expect(result, isNotNull);
      expect(result!.value.value, equals(42));
    });

    /// Spec: Properties should report which object defined them.
    test('getProperty returns defining object ID', () {
      final obj = T3TadsObject(
        objectId: 100,
        superclasses: [],
        loadImageProperties: [T3ObjectProperty(10, T3Value.fromInt(42))],
        flags: 0,
      );
      interp.objectTable.register(obj);

      final result = interp.objectTable.lookupProperty(100, 10);
      expect(result!.definingObjectId, equals(100));
    });

    /// Spec: model.htm lines 576-578:
    /// "...and returns... whether the property exists in the object or not."
    test('getProperty returns null for nonexistent property', () {
      final obj = T3TadsObject(objectId: 100, superclasses: [], loadImageProperties: [], flags: 0);
      interp.objectTable.register(obj);

      final result = interp.objectTable.lookupProperty(100, 999);
      expect(result, isNull);
    });

    /// Spec: Properties can hold any T3Value type.
    test('getProperty works for all value types', () {
      final obj = T3TadsObject(
        objectId: 100,
        superclasses: [],
        loadImageProperties: [
          T3ObjectProperty(1, T3Value.nil()),
          T3ObjectProperty(2, T3Value.true_()),
          T3ObjectProperty(3, T3Value.fromInt(123)),
          T3ObjectProperty(4, T3Value.fromObject(200)),
          T3ObjectProperty(5, T3Value.fromString(300)),
          T3ObjectProperty(6, T3Value.fromFuncPtr(0x400)),
        ],
        flags: 0,
      );
      interp.objectTable.register(obj);

      expect(interp.objectTable.lookupProperty(100, 1)!.value.isNil, isTrue);
      expect(interp.objectTable.lookupProperty(100, 2)!.value.isTrue, isTrue);
      expect(interp.objectTable.lookupProperty(100, 3)!.value.value, 123);
      expect(interp.objectTable.lookupProperty(100, 4)!.value.isObject, isTrue);
      expect(interp.objectTable.lookupProperty(100, 5)!.value.isString, isTrue);
      expect(interp.objectTable.lookupProperty(100, 6)!.value.isFuncPtr, isTrue);
    });
  });

  group('Property set operation', () {
    /// Spec: model.htm lines 580-582:
    /// "Set a property value. This takes a property ID and a value (giving
    /// the primitive type and data value), and sets the given property of
    /// the object to the given value."
    test('setProperty adds new property', () {
      final obj = T3TadsObject(objectId: 100, superclasses: [], loadImageProperties: [], flags: 0);

      obj.setProperty(10, T3Value.fromInt(42));

      expect(obj.getProperty(10)?.value, 42);
    });

    /// Spec: Setting an existing property replaces its value.
    test('setProperty updates existing property', () {
      final obj = T3TadsObject(
        objectId: 100,
        superclasses: [],
        loadImageProperties: [T3ObjectProperty(10, T3Value.fromInt(42))],
        flags: 0,
      );

      obj.setProperty(10, T3Value.fromInt(999));

      expect(obj.getProperty(10)?.value, 999);
    });
  });

  group('Property inheritance', () {
    late T3Interpreter interp;

    setUp(() {
      interp = T3Interpreter();
    });

    /// Spec: model.htm lines 571-574:
    /// "Determine if this object is an instance of another object. Some
    /// objects (TADS objects in particular) can be related to other objects
    /// as subclasses and superclasses."
    test('child inherits property from parent', () {
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
    });

    /// Spec: The defining object should be the actual owner.
    test('inherited property reports correct defining object', () {
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
      expect(result!.definingObjectId, equals(50));
    });

    /// Spec: Child's definition overrides parent's.
    test('child property overrides parent property', () {
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

    /// Spec: model.htm lines 584-592:
    /// "Inherit a property value. This is similar to get-property, but
    /// ignores any setting in the object itself, and considers only the
    /// value it inherits from a superclass."
    test('multi-level inheritance chain', () {
      final grandparent = T3TadsObject(
        objectId: 1,
        superclasses: [],
        loadImageProperties: [T3ObjectProperty(10, T3Value.fromInt(111))],
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

      // Child inherits from grandparent through parent
      final result = interp.objectTable.lookupProperty(3, 10);
      expect(result, isNotNull);
      expect(result!.value.value, equals(111));
      expect(result.definingObjectId, equals(1));
    });

    /// Spec: Multiple inheritance - first matching superclass wins.
    test('multiple superclasses - first match wins', () {
      final parent1 = T3TadsObject(
        objectId: 1,
        superclasses: [],
        loadImageProperties: [T3ObjectProperty(10, T3Value.fromInt(111))],
        flags: T3TadsObject.flagIsClass,
      );
      final parent2 = T3TadsObject(
        objectId: 2,
        superclasses: [],
        loadImageProperties: [T3ObjectProperty(10, T3Value.fromInt(222))],
        flags: T3TadsObject.flagIsClass,
      );
      final child = T3TadsObject(
        objectId: 3,
        superclasses: [1, 2], // parent1 comes first
        loadImageProperties: [],
        flags: 0,
      );

      interp.objectTable.register(parent1);
      interp.objectTable.register(parent2);
      interp.objectTable.register(child);

      // Should find in parent1 (first superclass)
      final result = interp.objectTable.lookupProperty(3, 10);
      expect(result!.value.value, equals(111));
    });
  });

  group('Property on different object types', () {
    /// Spec: model.htm lines 587-588:
    /// "This method can be ignored by any objects that can't be subclasses
    /// of other objects (strings and lists, for example, are never
    /// subclasses)."
    test('ListObject has elements property', () {
      final list = T3ListObject(objectId: 100, elements: [T3Value.fromInt(1), T3Value.fromInt(2)]);

      expect(list.elements.length, 2);
      expect(list.elements[0].value, 1);
    });

    /// Spec: VectorObject is similar to List but mutable.
    test('VectorObject has mutable elements', () {
      final vector = T3VectorObject(
        objectId: 100,
        elements: [T3Value.fromInt(1), T3Value.fromInt(2)],
        allocatedSize: 10,
      );

      expect(vector.elements.length, 2);
      // Vectors can be modified
      vector.elements.add(T3Value.fromInt(3));
      expect(vector.elements.length, 3);
    });
  });
}
