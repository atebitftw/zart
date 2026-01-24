import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_lookup.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_object_table.dart';
import 'package:zart/src/tads3/vm/t3_stack.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';
import 'package:zart/src/tads3/vm/t3_error.dart';
import 'package:zart/src/tads3/vm/t3_metaclass_table.dart';

class MockStack extends T3Stack {
  MockStack() : super(100, 10);

  void pushInt(int val) => push(T3Value(T3DataType.int32)..setInt(val));
}

class MockVM extends T3VM {
  @override
  final MockStack stack = MockStack();
  @override
  final T3ObjectTable objTable = T3ObjectTable();
  @override
  final T3MetaclassTable metaTable = T3MetaclassTable();
}

void main() {
  group('T3ObjLookupTable', () {
    late MockVM vm;

    setUp(() {
      vm = MockVM();
    });

    group('construction', () {
      test('creates with specified bucket count and capacity', () {
        final table = T3ObjLookupTable(16, 32);
        expect(table.bucketCount, equals(16));
        expect(table.capacity, equals(32));
        expect(table.entryCount, equals(0));
      });

      test('creates with defaults', () {
        final table = T3ObjLookupTable.withDefaults();
        expect(table.bucketCount, equals(32));
        expect(table.capacity, equals(64));
      });

      test('createFromStack with 0 args uses defaults', () {
        final id = T3ObjLookupTable.createFromStack(vm, 0);
        final table = vm.objTable.getObj(id) as T3ObjLookupTable;
        expect(table.bucketCount, equals(32));
        expect(table.capacity, equals(64));
      });

      test('createFromStack with 2 args sets bucket count and capacity', () {
        vm.stack.pushInt(24); // bucket count
        vm.stack.pushInt(50); // capacity
        final id = T3ObjLookupTable.createFromStack(vm, 2);
        final table = vm.objTable.getObj(id) as T3ObjLookupTable;
        expect(table.bucketCount, equals(24));
        expect(table.capacity, equals(50));
      });

      test('createFromStack with 3 args throws', () {
        vm.stack.pushInt(100);
        vm.stack.pushInt(50);
        vm.stack.pushInt(25);
        expect(() => T3ObjLookupTable.createFromStack(vm, 3), throwsA(isA<T3VmException>()));
      });
    });

    group('basic operations', () {
      test('setOrAddEntry adds new entry', () {
        final table = T3ObjLookupTable.withDefaults();
        final key = T3Value()..setInt(42);
        final val = T3Value()..setInt(100);

        table.setOrAddEntry(key, val);
        expect(table.entryCount, equals(1));
        expect(table.isKeyPresent(key), isTrue);
      });

      test('setOrAddEntry updates existing entry', () {
        final table = T3ObjLookupTable.withDefaults();
        final key = T3Value()..setInt(42);
        final val1 = T3Value()..setInt(100);
        final val2 = T3Value()..setInt(200);

        table.setOrAddEntry(key, val1);
        table.setOrAddEntry(key, val2);

        expect(table.entryCount, equals(1));
        final result = table.getValue(key);
        expect(result.getAsInt(), equals(200));
      });

      test('getValue returns value for existing key', () {
        final table = T3ObjLookupTable.withDefaults();
        final key = T3Value()..setInt(42);
        final val = T3Value()..setInt(100);

        table.setOrAddEntry(key, val);
        final result = table.getValue(key);
        expect(result.getAsInt(), equals(100));
      });

      test('getValue returns default for missing key', () {
        final table = T3ObjLookupTable.withDefaults();
        final key = T3Value()..setInt(42);

        final result = table.getValue(key);
        expect(result.type, equals(T3DataType.nil));
      });

      test('isKeyPresent returns false for missing key', () {
        final table = T3ObjLookupTable.withDefaults();
        final key = T3Value()..setInt(42);

        expect(table.isKeyPresent(key), isFalse);
      });

      test('removeEntry removes existing entry', () {
        final table = T3ObjLookupTable.withDefaults();
        final key = T3Value()..setInt(42);
        final val = T3Value()..setInt(100);

        table.setOrAddEntry(key, val);
        expect(table.entryCount, equals(1));

        final removed = table.removeEntry(key);
        expect(removed, isTrue);
        expect(table.entryCount, equals(0));
        expect(table.isKeyPresent(key), isFalse);
      });

      test('removeEntry returns false for missing key', () {
        final table = T3ObjLookupTable.withDefaults();
        final key = T3Value()..setInt(42);

        final removed = table.removeEntry(key);
        expect(removed, isFalse);
      });
    });

    group('default value', () {
      test('default value is nil initially', () {
        final table = T3ObjLookupTable.withDefaults();
        expect(table.defaultValue.type, equals(T3DataType.nil));
      });

      test('setDefaultValue changes default', () {
        final table = T3ObjLookupTable.withDefaults();
        final newDefault = T3Value()..setInt(-1);

        table.setDefaultValue(newDefault);
        expect(table.defaultValue.getAsInt(), equals(-1));
      });

      test('getValue returns custom default for missing key', () {
        final table = T3ObjLookupTable.withDefaults();
        final newDefault = T3Value()..setInt(-1);
        table.setDefaultValue(newDefault);

        final key = T3Value()..setInt(42);
        final result = table.getValue(key);
        expect(result.getAsInt(), equals(-1));
      });
    });

    group('multiple entries', () {
      test('handles multiple entries', () {
        final table = T3ObjLookupTable.withDefaults();

        for (var i = 0; i < 10; i++) {
          final key = T3Value()..setInt(i);
          final val = T3Value()..setInt(i * 10);
          table.setOrAddEntry(key, val);
        }

        expect(table.entryCount, equals(10));

        for (var i = 0; i < 10; i++) {
          final key = T3Value()..setInt(i);
          final result = table.getValue(key);
          expect(result.getAsInt(), equals(i * 10));
        }
      });

      test('handles hash collisions', () {
        // Use a small bucket count to force collisions
        final table = T3ObjLookupTable(4, 16);

        for (var i = 0; i < 16; i++) {
          final key = T3Value()..setInt(i);
          final val = T3Value()..setInt(i * 100);
          table.setOrAddEntry(key, val);
        }

        expect(table.entryCount, equals(16));

        // Verify all entries are retrievable
        for (var i = 0; i < 16; i++) {
          final key = T3Value()..setInt(i);
          final result = table.getValue(key);
          expect(result.getAsInt(), equals(i * 100));
        }
      });
    });

    group('iteration', () {
      test('forEach visits all entries', () {
        final table = T3ObjLookupTable.withDefaults();

        for (var i = 0; i < 5; i++) {
          final key = T3Value()..setInt(i);
          final val = T3Value()..setInt(i * 10);
          table.setOrAddEntry(key, val);
        }

        final visited = <int, int>{};
        table.forEach((key, val) {
          visited[key.getAsInt()] = val.getAsInt();
        });

        expect(visited.length, equals(5));
        for (var i = 0; i < 5; i++) {
          expect(visited[i], equals(i * 10));
        }
      });
    });

    group('nth key/value', () {
      test('getNthKey returns correct key', () {
        final table = T3ObjLookupTable.withDefaults();
        final key1 = T3Value()..setInt(100);
        final key2 = T3Value()..setInt(200);
        final val = T3Value()..setInt(0);

        table.setOrAddEntry(key1, val);
        table.setOrAddEntry(key2, val);

        // Keys might be in any order due to hashing
        final k1 = table.getNthKey(1);
        final k2 = table.getNthKey(2);

        final keys = {k1.getAsInt(), k2.getAsInt()};
        expect(keys, containsAll([100, 200]));
      });

      test('getNthKey with index 0 returns nil', () {
        final table = T3ObjLookupTable.withDefaults();
        final result = table.getNthKey(0);
        expect(result.type, equals(T3DataType.nil));
      });

      test('getNthVal returns correct value', () {
        final table = T3ObjLookupTable.withDefaults();
        final key = T3Value()..setInt(42);
        final val = T3Value()..setInt(100);

        table.setOrAddEntry(key, val);

        final result = table.getNthVal(1);
        expect(result.getAsInt(), equals(100));
      });

      test('getNthVal with index 0 returns default', () {
        final table = T3ObjLookupTable.withDefaults();
        final newDefault = T3Value()..setInt(-1);
        table.setDefaultValue(newDefault);

        final result = table.getNthVal(0);
        expect(result.getAsInt(), equals(-1));
      });

      test('getNthKey throws for out of range', () {
        final table = T3ObjLookupTable.withDefaults();
        expect(() => table.getNthKey(1), throwsA(isA<T3VmException>()));
      });
    });

    group('table expansion', () {
      test('expands when capacity is reached', () {
        final table = T3ObjLookupTable(4, 4);

        // Add more entries than initial capacity
        for (var i = 0; i < 10; i++) {
          final key = T3Value()..setInt(i);
          final val = T3Value()..setInt(i * 10);
          table.setOrAddEntry(key, val);
        }

        expect(table.entryCount, equals(10));
        expect(table.capacity, greaterThan(4));

        // Verify all entries are still retrievable
        for (var i = 0; i < 10; i++) {
          final key = T3Value()..setInt(i);
          expect(table.getValue(key).getAsInt(), equals(i * 10));
        }
      });
    });

    group('indexing operations', () {
      test('indexValQ gets value by key', () {
        final table = T3ObjLookupTable.withDefaults();
        final key = T3Value()..setInt(42);
        final val = T3Value()..setInt(100);
        table.setOrAddEntry(key, val);

        final result = T3Value();
        final id = vm.objTable.registerObj(table, false);
        table.indexValQ(vm, result, id, key);

        expect(result.getAsInt(), equals(100));
      });

      test('setIndexValQ adds new entry', () {
        final table = T3ObjLookupTable.withDefaults();
        final key = T3Value()..setInt(42);
        final val = T3Value()..setInt(100);

        final newContainer = T3Value();
        final id = vm.objTable.registerObj(table, false);
        table.setIndexValQ(vm, newContainer, id, key, val);

        expect(table.entryCount, equals(1));
        expect(table.getValue(key).getAsInt(), equals(100));
      });
    });

    group('equality', () {
      test('equals another LookupTable with same content', () {
        final table1 = T3ObjLookupTable.withDefaults();
        final table2 = T3ObjLookupTable.withDefaults();

        final key = T3Value()..setInt(42);
        final val = T3Value()..setInt(100);

        table1.setOrAddEntry(key, val);
        table2.setOrAddEntry(key, val);

        final id1 = vm.objTable.registerObj(table1, false);
        final id2 = vm.objTable.registerObj(table2, false);

        expect(table1.equals(vm, id1, T3Value(T3DataType.obj)..setObj(id2), 0), isTrue);
      });

      test('not equals LookupTable with different content', () {
        final table1 = T3ObjLookupTable.withDefaults();
        final table2 = T3ObjLookupTable.withDefaults();

        final key = T3Value()..setInt(42);
        final val1 = T3Value()..setInt(100);
        final val2 = T3Value()..setInt(200);

        table1.setOrAddEntry(key, val1);
        table2.setOrAddEntry(key, val2);

        final id1 = vm.objTable.registerObj(table1, false);
        final id2 = vm.objTable.registerObj(table2, false);

        expect(table1.equals(vm, id1, T3Value(T3DataType.obj)..setObj(id2), 0), isFalse);
      });
    });

    group('hash', () {
      test('calcHash returns consistent value', () {
        final table = T3ObjLookupTable.withDefaults();
        final key = T3Value()..setInt(42);
        final val = T3Value()..setInt(100);
        table.setOrAddEntry(key, val);

        final id = vm.objTable.registerObj(table, false);

        final hash1 = table.calcHash(vm, id, 0);
        final hash2 = table.calcHash(vm, id, 0);
        expect(hash1, equals(hash2));
      });

      test('same content produces same hash', () {
        final table1 = T3ObjLookupTable.withDefaults();
        final table2 = T3ObjLookupTable.withDefaults();

        final key = T3Value()..setInt(42);
        final val = T3Value()..setInt(100);

        table1.setOrAddEntry(key, val);
        table2.setOrAddEntry(key, val);

        expect(table1.calcHash(vm, 0, 0), equals(table2.calcHash(vm, 0, 0)));
      });
    });

    group('property methods', () {
      test('getpCountBuckets returns bucket count', () {
        final table = T3ObjLookupTable(24, 32);
        final retval = T3Value();

        table.getpCountBuckets(vm, retval, 0);
        expect(retval.getAsInt(), equals(24));
      });

      test('getpCountEntries returns entry count', () {
        final table = T3ObjLookupTable.withDefaults();
        final key = T3Value()..setInt(42);
        final val = T3Value()..setInt(100);
        table.setOrAddEntry(key, val);

        final retval = T3Value();

        table.getpCountEntries(vm, retval, 0);
        expect(retval.getAsInt(), equals(1));
      });

      test('getpKeyPresent returns true for existing key', () {
        final table = T3ObjLookupTable.withDefaults();
        final key = T3Value()..setInt(42);
        final val = T3Value()..setInt(100);
        table.setOrAddEntry(key, val);

        vm.stack.push(T3Value()..setInt(42));

        final retval = T3Value();
        table.getpKeyPresent(vm, retval, 1);
        expect(retval.type, equals(T3DataType.trueValue));
      });

      test('getpKeyPresent returns false for missing key', () {
        final table = T3ObjLookupTable.withDefaults();
        vm.stack.push(T3Value()..setInt(42));

        final retval = T3Value();
        table.getpKeyPresent(vm, retval, 1);
        expect(retval.type, equals(T3DataType.nil));
      });

      test('getpRemoveEntry removes entry', () {
        final table = T3ObjLookupTable.withDefaults();
        final key = T3Value()..setInt(42);
        final val = T3Value()..setInt(100);
        table.setOrAddEntry(key, val);

        vm.stack.push(T3Value()..setInt(42));

        final retval = T3Value();
        table.getpRemoveEntry(vm, retval, 1);

        expect(table.entryCount, equals(0));
      });

      test('getpGetDefVal returns default value', () {
        final table = T3ObjLookupTable.withDefaults();
        table.setDefaultValue(T3Value()..setInt(-1));

        final retval = T3Value();

        table.getpGetDefVal(vm, retval, 0);
        expect(retval.getAsInt(), equals(-1));
      });

      test('getpSetDefVal sets default value', () {
        final table = T3ObjLookupTable.withDefaults();

        vm.stack.push(T3Value()..setInt(-999));
        final retval = T3Value();
        table.getpSetDefVal(vm, retval, 1);

        expect(table.defaultValue.getAsInt(), equals(-999));
      });
    });

    group('serialization', () {
      test('loadFromImage parses format correctly', () {
        // Create image data for a table with 2 buckets, 1 entry
        // entry: key=42, val=100
        final dataSize = 6 + 2 * 2 + 1 * 12 + 5; // header + buckets + entry + default
        final data = Uint8List(dataSize);
        final view = ByteData.sublistView(data);

        // Header
        view.setUint16(0, 2, Endian.little); // bucket count
        view.setUint16(2, 1, Endian.little); // value count
        view.setUint16(4, 0, Endian.little); // first free = 0 (none)

        // Buckets - key 42 hashes to bucket 0 (42 % 2 = 0)
        view.setUint16(6, 1, Endian.little); // bucket 0 -> entry 1 (1-based)
        view.setUint16(8, 0, Endian.little); // bucket 1 -> empty

        // Entry 0: key=42, val=100, next=0
        final entryPos = 10;
        // Key dataholder: type int32 (index 6), value 42
        data[entryPos] = T3DataType.int32.index + 1;
        view.setInt32(entryPos + 1, 42, Endian.little);
        // Value dataholder: type int32 (index 6), value 100
        data[entryPos + 5] = T3DataType.int32.index + 1;
        view.setInt32(entryPos + 6, 100, Endian.little);
        // Next index
        view.setUint16(entryPos + 10, 0, Endian.little);

        // Default value: nil (index 0)
        data[entryPos + 12] = T3DataType.nil.index + 1;

        final table = T3ObjLookupTable.withDefaults();
        table.loadFromImage(vm, 0, data, 0, data.length);

        expect(table.bucketCount, equals(2));
        expect(table.entryCount, equals(1));

        final key = T3Value()..setInt(42);
        expect(table.getValue(key).getAsInt(), equals(100));
      });
    });
  });

  group('T3MetaclassLookupTable', () {
    test('has correct name', () {
      final meta = T3MetaclassLookupTable();
      expect(meta.getMetaName(), equals('lookuptable/030003'));
    });

    test('static name constant', () {
      expect(T3MetaclassLookupTable.name, equals('lookuptable/030003'));
    });
  });
}
