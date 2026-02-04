// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Unit tests for TADS3 Metaclass Table
///
/// Tests the metaclass registration system and property-to-method mapping.
library;

import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_error.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_metaclass_table.dart';

/// Mock metaclass for testing
class MockMetaclass1 extends T3Metaclass {
  String _name = 'test-meta-1/030001';
  void setName(String name) => _name = name;

  @override
  String getMetaName() => _name;

  @override
  int createFromStack(T3VM vm, dynamic pc, int pcOffset, int argc) =>
      invalidObj;

  @override
  void createForImageLoad(T3VM vm, int id) {}

  @override
  void createForRestore(T3VM vm, int id) {}

  @override
  bool callStatProp(
    T3VM vm,
    dynamic result,
    dynamic pc,
    int pcOffset,
    int argc,
    int prop,
  ) => false;

  @override
  int getSupermeta(T3VM vm, int idx) => invalidObj;

  @override
  bool isMetaInstanceOf(T3VM vm, int obj) => false;

  @override
  T3Metaclass? getSupermetaReg() => null;

  @override
  int getClassObj(T3VM vm) => invalidObj;
}

class MockMetaclass2 extends T3Metaclass {
  @override
  String getMetaName() => 'test-meta-2/030001';

  @override
  int createFromStack(T3VM vm, dynamic pc, int pcOffset, int argc) =>
      invalidObj;

  @override
  void createForImageLoad(T3VM vm, int id) {}

  @override
  void createForRestore(T3VM vm, int id) {}

  @override
  bool callStatProp(
    T3VM vm,
    dynamic result,
    dynamic pc,
    int pcOffset,
    int argc,
    int prop,
  ) => false;

  @override
  int getSupermeta(T3VM vm, int idx) => invalidObj;

  @override
  bool isMetaInstanceOf(T3VM vm, int obj) => false;

  @override
  T3Metaclass? getSupermetaReg() => null;

  @override
  int getClassObj(T3VM vm) => invalidObj;
}

void main() {
  late T3MetaclassTable table;

  setUp(() {
    table = T3MetaclassTable();
  });

  group('T3MetaclassTable - Registration', () {
    test('registers metaclass and assigns index', () {
      final meta = MockMetaclass1();
      final idx = table.registerMetaclass(meta);

      expect(idx, equals(0));
      expect(meta.getRegIdx(), equals(0));
    });

    test('assigns sequential indices', () {
      final meta1 = MockMetaclass1();
      final meta2 = MockMetaclass2();

      final idx1 = table.registerMetaclass(meta1);
      final idx2 = table.registerMetaclass(meta2);

      expect(idx1, equals(0));
      expect(idx2, equals(1));
    });

    test('throws error when registering duplicate name', () {
      final meta1 = MockMetaclass1();
      final meta2 = MockMetaclass1(); // Same name

      table.registerMetaclass(meta1);
      expect(
        () => table.registerMetaclass(meta2),
        throwsA(isA<T3VmException>()),
      );
    });

    test('tracks metaclass count', () {
      expect(table.count, equals(0));

      table.registerMetaclass(MockMetaclass1());
      expect(table.count, equals(1));

      table.registerMetaclass(MockMetaclass2());
      expect(table.count, equals(2));
    });
  });

  group('T3MetaclassTable - Lookup', () {
    test('can lookup by registration index', () {
      final meta = MockMetaclass1();
      final idx = table.registerMetaclass(meta);

      final entry = table.getEntryFromReg(idx);
      expect(entry, isNotNull);
      expect(entry!.meta, equals(meta));
      expect(entry.name, equals('test-meta-1/030001'));
    });

    test('can lookup by name', () {
      final meta = MockMetaclass1();
      table.registerMetaclass(meta);

      final entry = table.getEntryFromName('test-meta-1/030001');
      expect(entry, isNotNull);
      expect(entry!.meta, equals(meta));
    });

    test('returns null for invalid registration index', () {
      expect(table.getEntryFromReg(999), isNull);
    });

    test('returns null for unknown name', () {
      expect(table.getEntryFromName('unknown-meta/030001'), isNull);
    });
  });

  group('T3MetaclassTable - Property Mapping', () {
    test('can register property mapping', () {
      final meta = MockMetaclass1();
      final idx = table.registerMetaclass(meta);

      table.registerProp(idx, 100, 5); // propId 100 -> funcIdx 5

      final funcIdx = table.propToVectorIdx(idx, 100);
      expect(funcIdx, equals(5));
    });

    test('can register multiple properties', () {
      final meta = MockMetaclass1();
      final idx = table.registerMetaclass(meta);

      table.registerProp(idx, 100, 5);
      table.registerProp(idx, 101, 6);
      table.registerProp(idx, 102, 7);

      expect(table.propToVectorIdx(idx, 100), equals(5));
      expect(table.propToVectorIdx(idx, 101), equals(6));
      expect(table.propToVectorIdx(idx, 102), equals(7));
    });

    test('returns null for unmapped property', () {
      final meta = MockMetaclass1();
      final idx = table.registerMetaclass(meta);

      expect(table.propToVectorIdx(idx, 999), isNull);
    });

    test('throws error when registering prop for invalid metaclass', () {
      expect(
        () => table.registerProp(999, 100, 5),
        throwsA(isA<T3VmException>()),
      );
    });

    test('property mappings are per-metaclass', () {
      final meta1 = MockMetaclass1();
      final meta2 = MockMetaclass2();
      final idx1 = table.registerMetaclass(meta1);
      final idx2 = table.registerMetaclass(meta2);

      table.registerProp(idx1, 100, 5);
      table.registerProp(idx2, 100, 10);

      expect(table.propToVectorIdx(idx1, 100), equals(5));
      expect(table.propToVectorIdx(idx2, 100), equals(10));
    });
  });

  group('T3MetaclassTable - Class Objects', () {
    test('class object is invalidObj by default', () {
      final meta = MockMetaclass1();
      final idx = table.registerMetaclass(meta);

      expect(table.getClassObj(idx), equals(invalidObj));
    });

    test('can set and get class object', () {
      final meta = MockMetaclass1();
      final idx = table.registerMetaclass(meta);

      table.setClassObj(idx, 42);
      expect(table.getClassObj(idx), equals(42));
    });

    test('returns invalidObj for invalid registration index', () {
      expect(table.getClassObj(999), equals(invalidObj));
    });
  });

  group('T3MetaclassTable - Iteration', () {
    test('forEach visits all registered metaclasses', () {
      final meta1 = MockMetaclass1();
      final meta2 = MockMetaclass2();
      table.registerMetaclass(meta1);
      table.registerMetaclass(meta2);

      final visited = <String>[];
      table.forEach((entry) {
        visited.add(entry.name);
      });

      expect(visited.length, equals(2));
      expect(visited, contains('test-meta-1/030001'));
      expect(visited, contains('test-meta-2/030001'));
    });

    test('forEach on empty table does nothing', () {
      var count = 0;
      table.forEach((entry) {
        count++;
      });
      expect(count, equals(0));
    });
  });

  group('T3MetaclassTable - Clear', () {
    test('clear removes all registrations', () {
      table.registerMetaclass(MockMetaclass1());
      table.registerMetaclass(MockMetaclass2());

      expect(table.count, equals(2));

      table.clear();

      expect(table.count, equals(0));
      expect(table.getEntryFromName('test-meta-1/030001'), isNull);
      expect(table.getEntryFromName('test-meta-2/030001'), isNull);
    });
  });

  group('T3MetaclassTable - Edge Cases', () {
    test('handles many metaclasses', () {
      final metas = <MockMetaclass1>[];
      for (var i = 0; i < 100; i++) {
        final meta = MockMetaclass1();
        meta.setName('test-meta-$i/030001');
        metas.add(meta);
        table.registerMetaclass(meta);
      }

      expect(table.count, equals(100));

      // Verify all are accessible
      for (var i = 0; i < 100; i++) {
        final entry = table.getEntryFromReg(i);
        expect(entry, isNotNull);
        expect(entry!.meta, equals(metas[i]));
      }
    });

    test('handles many property mappings per metaclass', () {
      final meta = MockMetaclass1();
      final idx = table.registerMetaclass(meta);

      // Register 100 properties
      for (var i = 0; i < 100; i++) {
        table.registerProp(idx, i, i * 10);
      }

      // Verify all mappings
      for (var i = 0; i < 100; i++) {
        expect(table.propToVectorIdx(idx, i), equals(i * 10));
      }
    });
  });
}
