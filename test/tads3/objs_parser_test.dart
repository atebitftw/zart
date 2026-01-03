import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:zart/src/loaders/tads/t3_block.dart';
import 'package:zart/src/loaders/tads/t3_image.dart';
import 'package:zart/src/tads3/loaders/mcld_parser.dart';
import 'package:zart/src/tads3/loaders/objs_parser.dart';
import 'package:zart/src/tads3/vm/t3_interpreter.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_object_table.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';

void main() {
  group('T3ObjsBlock', () {
    test('parses block with small object sizes (UINT2)', () {
      // Construct a test OBJS block:
      // Header: 2 objects, metaclass index 0, flags 0x0000
      // Object 1: ID 1, 6 bytes of data
      // Object 2: ID 2, 6 bytes of data
      final data = <int>[
        // Number of objects (UINT2): 2
        0x02, 0x00,
        // Metaclass index (UINT2): 0
        0x00, 0x00,
        // Flags (UINT2): 0 (small objects, not transient)
        0x00, 0x00,
        // Object 1
        // Object ID (UINT4): 1
        0x01, 0x00, 0x00, 0x00,
        // Data size (UINT2): 6
        0x06, 0x00,
        // Object data: 6 bytes (minimal TADS object: 0 supers, 0 props, 0 flags)
        0x00, 0x00, // superclass count
        0x00, 0x00, // property count
        0x00, 0x00, // flags
        // Object 2
        // Object ID (UINT4): 2
        0x02, 0x00, 0x00, 0x00,
        // Data size (UINT2): 6
        0x06, 0x00,
        // Object data: 6 bytes
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      ];

      final block = T3ObjsBlock.parse(Uint8List.fromList(data));

      expect(block.metaclassIndex, equals(0));
      expect(block.isLargeObjects, isFalse);
      expect(block.isTransient, isFalse);
      expect(block.objectCount, equals(2));
      expect(block.objects[0].objectId, equals(1));
      expect(block.objects[0].data.length, equals(6));
      expect(block.objects[1].objectId, equals(2));
      expect(block.objects[1].data.length, equals(6));
    });

    test('parses block with large object sizes (UINT4)', () {
      final data = <int>[
        // Number of objects (UINT2): 1
        0x01, 0x00,
        // Metaclass index (UINT2): 1
        0x01, 0x00,
        // Flags (UINT2): 0x0001 (large objects)
        0x01, 0x00,
        // Object 1
        // Object ID (UINT4): 100
        0x64, 0x00, 0x00, 0x00,
        // Data size (UINT4): 6 - large format
        0x06, 0x00, 0x00, 0x00,
        // Object data: 6 bytes
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      ];

      final block = T3ObjsBlock.parse(Uint8List.fromList(data));

      expect(block.metaclassIndex, equals(1));
      expect(block.isLargeObjects, isTrue);
      expect(block.isTransient, isFalse);
      expect(block.objectCount, equals(1));
      expect(block.objects[0].objectId, equals(100));
    });

    test('parses block with transient flag', () {
      final data = <int>[
        // Number of objects (UINT2): 1
        0x01, 0x00,
        // Metaclass index (UINT2): 0
        0x00, 0x00,
        // Flags (UINT2): 0x0002 (transient)
        0x02, 0x00,
        // Object 1
        // Object ID (UINT4): 1
        0x01, 0x00, 0x00, 0x00,
        // Data size (UINT2): 6
        0x06, 0x00,
        // Object data
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      ];

      final block = T3ObjsBlock.parse(Uint8List.fromList(data));

      expect(block.isTransient, isTrue);
      expect(block.objects[0].isTransient, isTrue);
    });
  });

  group('T3TadsObject', () {
    test('parses object with no superclasses and no properties', () {
      final data = <int>[
        // Superclass count (UINT2): 0
        0x00, 0x00,
        // Property count (UINT2): 0
        0x00, 0x00,
        // Flags (UINT2): 0
        0x00, 0x00,
      ];

      final obj = T3TadsObject.fromData(42, Uint8List.fromList(data));

      expect(obj.objectId, equals(42));
      expect(obj.superclassCount, equals(0));
      expect(obj.propertyCount, equals(0));
      expect(obj.isClass, isFalse);
    });

    test('parses object with superclasses', () {
      final data = <int>[
        // Superclass count (UINT2): 2
        0x02, 0x00,
        // Property count (UINT2): 0
        0x00, 0x00,
        // Flags (UINT2): 0
        0x00, 0x00,
        // Superclass 1 (UINT4): 10
        0x0A, 0x00, 0x00, 0x00,
        // Superclass 2 (UINT4): 20
        0x14, 0x00, 0x00, 0x00,
      ];

      final obj = T3TadsObject.fromData(1, Uint8List.fromList(data));

      expect(obj.superclassCount, equals(2));
      expect(obj.superclasses, containsAllInOrder([10, 20]));
    });

    test('parses object with properties', () {
      final data = <int>[
        // Superclass count (UINT2): 0
        0x00, 0x00,
        // Property count (UINT2): 2
        0x02, 0x00,
        // Flags (UINT2): 0
        0x00, 0x00,
        // Property 1
        // Property ID (UINT2): 100
        0x64, 0x00,
        // Value: int(42) - type 7, value 42
        0x07, 0x2A, 0x00, 0x00, 0x00,
        // Property 2
        // Property ID (UINT2): 101
        0x65, 0x00,
        // Value: nil - type 1, value 0
        0x01, 0x00, 0x00, 0x00, 0x00,
      ];

      final obj = T3TadsObject.fromData(1, Uint8List.fromList(data));

      expect(obj.propertyCount, equals(2));

      final prop100 = obj.getProperty(100);
      expect(prop100, isNotNull);
      expect(prop100!.type, equals(T3DataType.int_));
      expect(prop100.value, equals(42));

      final prop101 = obj.getProperty(101);
      expect(prop101, isNotNull);
      expect(prop101!.isNil, isTrue);

      final propNotFound = obj.getProperty(999);
      expect(propNotFound, isNull);
    });

    test('parses class object', () {
      final data = <int>[
        // Superclass count (UINT2): 0
        0x00, 0x00,
        // Property count (UINT2): 0
        0x00, 0x00,
        // Flags (UINT2): 0x0001 (isClass)
        0x01, 0x00,
      ];

      final obj = T3TadsObject.fromData(1, Uint8List.fromList(data));

      expect(obj.isClass, isTrue);
    });

    test('modified properties override load image properties', () {
      final data = <int>[
        0x00, 0x00, // 0 superclasses
        0x01, 0x00, // 1 property
        0x00, 0x00, // flags
        // Property 1: ID 100, value int(10)
        0x64, 0x00,
        0x07, 0x0A, 0x00, 0x00, 0x00,
      ];

      final obj = T3TadsObject.fromData(1, Uint8List.fromList(data));

      // Original value
      expect(obj.getProperty(100)!.value, equals(10));

      // Modify the property
      obj.setProperty(100, T3Value.fromInt(20));

      // Modified value takes precedence
      expect(obj.getProperty(100)!.value, equals(20));
    });
  });

  group('T3ObjectTable', () {
    test('registers and lookups objects', () {
      final table = T3ObjectTable();
      final obj = T3TadsObject(objectId: 1, superclasses: [], loadImageProperties: [], flags: 0);

      table.register(obj);

      expect(table.count, equals(1));
      expect(table.contains(1), isTrue);
      expect(table.lookup(1), equals(obj));
      expect(table.lookup(99), isNull);
    });

    test('throws on duplicate object ID', () {
      final table = T3ObjectTable();
      table.register(T3TadsObject(objectId: 1, superclasses: [], loadImageProperties: [], flags: 0));

      expect(
        () => table.register(T3TadsObject(objectId: 1, superclasses: [], loadImageProperties: [], flags: 0)),
        throwsStateError,
      );
    });

    test('groups objects by metaclass', () {
      final table = T3ObjectTable();
      table.register(T3TadsObject(objectId: 1, superclasses: [], loadImageProperties: [], flags: 0));
      table.register(T3TadsObject(objectId: 2, superclasses: [], loadImageProperties: [], flags: 0));
      table.register(T3StringObject(objectId: 3, text: 'hello'));

      final counts = table.countByMetaclass;
      expect(counts['tads-object'], equals(2));
      expect(counts['string'], equals(1));
    });

    test('lookupProperty finds direct property', () {
      final table = T3ObjectTable();
      final obj = T3TadsObject(
        objectId: 1,
        superclasses: [],
        loadImageProperties: [T3ObjectProperty(100, T3Value.fromInt(42))],
        flags: 0,
      );
      table.register(obj);

      final result = table.lookupProperty(1, 100);

      expect(result, isNotNull);
      expect(result!.value.isInt, isTrue);
      expect(result.value.value, equals(42));
      expect(result.definingObjectId, equals(1));
    });

    test('lookupProperty follows single inheritance', () {
      final table = T3ObjectTable();

      // Parent object with property 100
      final parent = T3TadsObject(
        objectId: 1,
        superclasses: [],
        loadImageProperties: [T3ObjectProperty(100, T3Value.fromInt(10))],
        flags: 0,
      );
      table.register(parent);

      // Child object inheriting from parent
      final child = T3TadsObject(objectId: 2, superclasses: [1], loadImageProperties: [], flags: 0);
      table.register(child);

      final result = table.lookupProperty(2, 100);

      expect(result, isNotNull);
      expect(result!.value.value, equals(10));
      expect(result.definingObjectId, equals(1)); // Found in parent
    });

    test('lookupProperty child property overrides parent', () {
      final table = T3ObjectTable();

      final parent = T3TadsObject(
        objectId: 1,
        superclasses: [],
        loadImageProperties: [T3ObjectProperty(100, T3Value.fromInt(10))],
        flags: 0,
      );
      table.register(parent);

      final child = T3TadsObject(
        objectId: 2,
        superclasses: [1],
        loadImageProperties: [T3ObjectProperty(100, T3Value.fromInt(20))],
        flags: 0,
      );
      table.register(child);

      final result = table.lookupProperty(2, 100);

      expect(result, isNotNull);
      expect(result!.value.value, equals(20)); // Child's value
      expect(result.definingObjectId, equals(2)); // Found in child
    });

    test('lookupProperty follows multiple inheritance', () {
      final table = T3ObjectTable();

      final parent1 = T3TadsObject(
        objectId: 1,
        superclasses: [],
        loadImageProperties: [T3ObjectProperty(100, T3Value.fromInt(10))],
        flags: 0,
      );
      table.register(parent1);

      final parent2 = T3TadsObject(
        objectId: 2,
        superclasses: [],
        loadImageProperties: [T3ObjectProperty(200, T3Value.fromInt(20))],
        flags: 0,
      );
      table.register(parent2);

      final child = T3TadsObject(objectId: 3, superclasses: [1, 2], loadImageProperties: [], flags: 0);
      table.register(child);

      // Property from first parent
      final result1 = table.lookupProperty(3, 100);
      expect(result1, isNotNull);
      expect(result1!.value.value, equals(10));
      expect(result1.definingObjectId, equals(1));

      // Property from second parent
      final result2 = table.lookupProperty(3, 200);
      expect(result2, isNotNull);
      expect(result2!.value.value, equals(20));
      expect(result2.definingObjectId, equals(2));
    });

    test('lookupProperty returns null for undefined property', () {
      final table = T3ObjectTable();
      final obj = T3TadsObject(objectId: 1, superclasses: [], loadImageProperties: [], flags: 0);
      table.register(obj);

      final result = table.lookupProperty(1, 999);

      expect(result, isNull);
    });
  });

  group('AllHope.t3 integration', () {
    late T3Interpreter interpreter;

    setUpAll(() {
      final gameFile = File('assets/games/tads/AllHope.t3');
      if (!gameFile.existsSync()) {
        fail('Test file not found: ${gameFile.path}');
      }
      final gameData = gameFile.readAsBytesSync();

      interpreter = T3Interpreter();
      interpreter.load(Uint8List.fromList(gameData));
    });

    test('loads OBJS blocks from AllHope.t3', () {
      final table = interpreter.objectTable;

      // AllHope.t3 should have objects
      expect(table.count, greaterThan(0));

      print('Loaded ${table.count} objects from AllHope.t3');
      print(table.summary);
    });

    test('loads tads-object instances', () {
      final tadsObjects = interpreter.objectTable.byMetaclass('tads-object');
      expect(tadsObjects, isNotEmpty);

      // Print some info about the objects
      var classCount = 0;
      var instanceCount = 0;
      var totalProps = 0;
      for (final obj in tadsObjects) {
        if (obj is T3TadsObject) {
          if (obj.isClass) {
            classCount++;
          } else {
            instanceCount++;
          }
          totalProps += obj.propertyCount;
        }
      }

      print('TADS Objects: $classCount classes, $instanceCount instances');
      print('Total properties: $totalProps');
    });

    test('raw OBJS block parsing from image', () {
      // Direct parsing without going through interpreter
      final gameFile = File('assets/games/tads/AllHope.t3');
      final gameData = gameFile.readAsBytesSync();
      final image = T3Image(Uint8List.fromList(gameData));

      // Get MCLD for metaclass names
      final mcldBlock = image.findBlock(T3Block.typeMetaclassDep);
      expect(mcldBlock, isNotNull);
      final metaclasses = T3MetaclassDepList.parse(image.getBlockData(mcldBlock!));

      print('\nMetaclasses in AllHope.t3:');
      for (final dep in metaclasses.dependencies) {
        print('  $dep');
      }

      // Parse all OBJS blocks
      final objsBlocks = image.findBlocks(T3Block.typeStaticObjects);
      print('\nOBJS blocks: ${objsBlocks.length}');

      var totalObjects = 0;
      final objectsByMetaclass = <String, int>{};

      for (final block in objsBlocks) {
        final data = image.getBlockData(block);
        final parsed = T3ObjsBlock.parse(data);

        final metaclassName = metaclasses.byIndex(parsed.metaclassIndex)?.name ?? 'unknown-${parsed.metaclassIndex}';

        objectsByMetaclass[metaclassName] = (objectsByMetaclass[metaclassName] ?? 0) + parsed.objectCount;
        totalObjects += parsed.objectCount;
      }

      print('\nTotal objects: $totalObjects');
      print('\nObjects by metaclass:');
      for (final entry in objectsByMetaclass.entries) {
        print('  ${entry.key}: ${entry.value}');
      }

      expect(totalObjects, greaterThan(0));
    });
  });
}
