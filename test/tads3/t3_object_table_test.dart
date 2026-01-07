import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_object_table.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';

/// T3 Object Table unit tests with TADS 3 specification validation.
///
/// Spec Reference: packages/tads-sources/t3doc/techman/t3spec/model.htm
/// - "Object Model" section (lines 527-775)
/// - "Object References" section (lines 712-732)
void main() {
  group('T3ObjectTable registration', () {
    late T3ObjectTable table;

    setUp(() {
      table = T3ObjectTable();
    });

    /// Spec: model.htm lines 715-716:
    /// "An object is referenced by its ID, which is a 32-bit value."
    test('objects are registered by ID', () {
      final obj = T3TadsObject(objectId: 100, superclasses: [], loadImageProperties: [], flags: 0);

      table.register(obj);

      expect(table.contains(100), isTrue);
      expect(table.lookup(100), equals(obj));
    });

    /// Spec: model.htm lines 718-725:
    /// "The object ID is an index into the object header table. The object
    /// table is conceptually an array of object descriptors."
    test('lookup returns null for nonexistent object', () {
      expect(table.lookup(999), isNull);
      expect(table.contains(999), isFalse);
    });

    /// Spec: Each object ID must be unique per the object table structure.
    test('duplicate registration throws error', () {
      final obj1 = T3TadsObject(objectId: 100, superclasses: [], loadImageProperties: [], flags: 0);
      final obj2 = T3TadsObject(objectId: 100, superclasses: [], loadImageProperties: [], flags: 0);

      table.register(obj1);
      expect(() => table.register(obj2), throwsA(isA<StateError>()));
    });

    /// Spec: Object table must support efficient enumeration.
    test('count and enumeration work correctly', () {
      for (var i = 0; i < 5; i++) {
        table.register(T3TadsObject(objectId: i, superclasses: [], loadImageProperties: [], flags: 0));
      }

      expect(table.count, 5);
      expect(table.all.length, 5);
      expect(table.allIds.toList(), containsAll([0, 1, 2, 3, 4]));
    });
  });

  group('T3ObjectTable property lookup', () {
    late T3ObjectTable table;

    setUp(() {
      table = T3ObjectTable();
    });

    /// Spec: model.htm lines 576-578:
    /// "Get a property value. This takes a property ID as the argument,
    /// and returns the value of the given property and whether the
    /// property exists in the object or not."
    test('property lookup returns value and defining object', () {
      final obj = T3TadsObject(
        objectId: 100,
        superclasses: [],
        loadImageProperties: [T3ObjectProperty(10, T3Value.fromInt(42))],
        flags: 0,
      );
      table.register(obj);

      final result = table.lookupProperty(100, 10);

      expect(result, isNotNull);
      expect(result!.value.value, 42);
      expect(result.definingObjectId, 100);
    });

    /// Spec: model.htm lines 584-592:
    /// "Inherit a property value. This is similar to get-property, but
    /// ignores any setting in the object itself, and considers only the
    /// value it inherits from a superclass."
    test('property lookup searches superclass chain', () {
      // Create a class hierarchy: child -> parent -> grandparent
      final grandparent = T3TadsObject(
        objectId: 1,
        superclasses: [],
        loadImageProperties: [T3ObjectProperty(10, T3Value.fromInt(111))],
        flags: T3TadsObject.flagIsClass,
      );
      final parent = T3TadsObject(
        objectId: 2,
        superclasses: [1],
        loadImageProperties: [T3ObjectProperty(20, T3Value.fromInt(222))],
        flags: T3TadsObject.flagIsClass,
      );
      final child = T3TadsObject(objectId: 3, superclasses: [2], loadImageProperties: [], flags: 0);

      table.register(grandparent);
      table.register(parent);
      table.register(child);

      // Property 10 defined only in grandparent
      final result10 = table.lookupProperty(3, 10);
      expect(result10, isNotNull);
      expect(result10!.value.value, 111);
      expect(result10.definingObjectId, 1);

      // Property 20 defined only in parent
      final result20 = table.lookupProperty(3, 20);
      expect(result20, isNotNull);
      expect(result20!.value.value, 222);
      expect(result20.definingObjectId, 2);
    });

    /// Spec: model.htm lines 571-574:
    /// "Determine if this object is an instance of another object. Some
    /// objects (TADS objects in particular) can be related to other objects
    /// as subclasses and superclasses."
    test('child property overrides parent property', () {
      final parent = T3TadsObject(
        objectId: 1,
        superclasses: [],
        loadImageProperties: [T3ObjectProperty(10, T3Value.fromInt(100))],
        flags: T3TadsObject.flagIsClass,
      );
      final child = T3TadsObject(
        objectId: 2,
        superclasses: [1],
        loadImageProperties: [T3ObjectProperty(10, T3Value.fromInt(200))],
        flags: 0,
      );

      table.register(parent);
      table.register(child);

      // Child's definition should override parent's
      final result = table.lookupProperty(2, 10);
      expect(result, isNotNull);
      expect(result!.value.value, 200);
      expect(result.definingObjectId, 2);
    });

    /// Spec: Undefined properties should return null.
    test('property lookup returns null for undefined property', () {
      final obj = T3TadsObject(objectId: 100, superclasses: [], loadImageProperties: [], flags: 0);
      table.register(obj);

      final result = table.lookupProperty(100, 999);
      expect(result, isNull);
    });
  });

  group('T3ObjectTable dynamic object creation', () {
    late T3ObjectTable table;

    setUp(() {
      table = T3ObjectTable();
    });

    /// Spec: model.htm lines 777+ (Metaclass Construction):
    /// "new" keyword triggers object construction via metaclass.
    test('createDynamicObject allocates new object ID', () {
      final id1 = table.createDynamicObject('tads-object', []);
      final id2 = table.createDynamicObject('tads-object', []);

      expect(id1, isNot(equals(id2)));
      expect(table.contains(id1), isTrue);
      expect(table.contains(id2), isTrue);
    });

    /// Spec: model.htm lines 534-538:
    /// "Generic objects are used for all types that are allocated
    /// dynamically at run-time; this allows a single memory manager
    /// to handle all allocation and garbage collection."
    test('createDynamicObject creates tads-object with superclass', () {
      // Create parent class
      final parentId = table.createDynamicObject('tads-object', []);

      // Create child with parent as superclass
      final childId = table.createDynamicObject('tads-object', [T3Value.fromObject(parentId)]);

      final child = table.lookup(childId);
      expect(child, isA<T3TadsObject>());
      expect((child as T3TadsObject).superclasses, contains(parentId));
    });

    /// Spec: model.htm lines 653-657 (Add operation for lists):
    /// "Strings and lists implement this method to support
    /// concatenation operations."
    test('createDynamicObject creates list with elements', () {
      final elements = [T3Value.fromInt(1), T3Value.fromInt(2)];
      final id = table.createDynamicObject('list', elements);

      final obj = table.lookup(id);
      expect(obj, isA<T3ListObject>());
      expect((obj as T3ListObject).elements.length, 2);
    });

    /// Spec: Vector is a mutable list (per metacl.htm).
    test('createDynamicObject creates vector with capacity', () {
      final id = table.createDynamicObject(
        'vector',
        [T3Value.fromInt(10)], // capacity
      );

      final obj = table.lookup(id);
      expect(obj, isA<T3VectorObject>());
      expect((obj as T3VectorObject).allocatedSize, 10);
    });

    /// Spec: Dynamic IDs use high range to avoid conflicts.
    test('dynamic object IDs start at 0x80000000', () {
      final id = table.createDynamicObject('tads-object', []);
      expect(id, greaterThanOrEqualTo(0x80000000));
    });
  });

  group('T3ObjectTable object removal', () {
    late T3ObjectTable table;

    setUp(() {
      table = T3ObjectTable();
    });

    /// Spec: model.htm lines 560-562:
    /// "Notify of deletion. This notifies the object that it's being
    /// deleted by the garbage collector; the object must release any
    /// resources, such as its extension memory."
    test('remove returns removed object', () {
      final obj = T3TadsObject(objectId: 100, superclasses: [], loadImageProperties: [], flags: 0);
      table.register(obj);

      final removed = table.remove(100);
      expect(removed, equals(obj));
      expect(table.contains(100), isFalse);
    });

    /// Spec: Removing nonexistent object should return null.
    test('remove returns null for nonexistent object', () {
      expect(table.remove(999), isNull);
    });

    /// Spec: clear removes all objects for restart scenarios.
    test('clear removes all objects', () {
      for (var i = 0; i < 5; i++) {
        table.register(T3TadsObject(objectId: i, superclasses: [], loadImageProperties: [], flags: 0));
      }

      table.clear();
      expect(table.isEmpty, isTrue);
      expect(table.count, 0);
    });
  });

  group('T3ObjectTable metaclass filtering', () {
    late T3ObjectTable table;

    setUp(() {
      table = T3ObjectTable();
    });

    /// Spec: model.htm lines 540-544:
    /// "A specific implementation of the generic object interface is
    /// called a 'metaclass.' Each generic object has a metaclass."
    test('byMetaclass returns objects of specific type', () {
      table.register(T3TadsObject(objectId: 1, superclasses: [], loadImageProperties: [], flags: 0));
      table.register(T3ListObject(objectId: 2, elements: []));
      table.register(T3TadsObject(objectId: 3, superclasses: [], loadImageProperties: [], flags: 0));

      final tadsObjects = table.byMetaclass('tads-object').toList();
      expect(tadsObjects.length, 2);

      final listObjects = table.byMetaclass('list').toList();
      expect(listObjects.length, 1);
    });

    /// Spec: countByMetaclass provides object distribution summary.
    test('countByMetaclass returns accurate counts', () {
      table.register(T3TadsObject(objectId: 1, superclasses: [], loadImageProperties: [], flags: 0));
      table.register(T3TadsObject(objectId: 2, superclasses: [], loadImageProperties: [], flags: 0));
      table.register(T3ListObject(objectId: 3, elements: []));

      final counts = table.countByMetaclass;
      expect(counts['tads-object'], 2);
      expect(counts['list'], 1);
    });
  });

  group('T3TadsObject properties', () {
    /// Spec: model.htm lines 580-582:
    /// "Set a property value. This takes a property ID and a value
    /// (giving the primitive type and data value), and sets the given
    /// property of the object to the given value."
    test('setProperty adds or updates property', () {
      final obj = T3TadsObject(objectId: 100, superclasses: [], loadImageProperties: [], flags: 0);

      obj.setProperty(10, T3Value.fromInt(42));
      expect(obj.getProperty(10)?.value, 42);

      obj.setProperty(10, T3Value.fromInt(99));
      expect(obj.getProperty(10)?.value, 99);
    });

    /// Spec: model.htm lines 576-578:
    /// "Get a property value... returns the value of the given property
    /// and whether the property exists in the object or not."
    test('getProperty returns null for undefined property', () {
      final obj = T3TadsObject(objectId: 100, superclasses: [], loadImageProperties: [], flags: 0);

      expect(obj.getProperty(999), isNull);
    });
  });
}
