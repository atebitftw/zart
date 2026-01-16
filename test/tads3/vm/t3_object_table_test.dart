// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Unit tests for TADS3 Object Table
///
/// Tests the object table's page-based allocation, free list management,
/// and object lifecycle tracking.
library;

import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_error.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_object_table.dart';

/// Mock object for testing
class MockT3Object extends T3Object {
  bool _deleted = false;
  bool get wasDeleted => _deleted;

  @override
  T3Metaclass getMetaclassReg() => MockT3Metaclass();

  @override
  void notifyDelete(T3VM vm, bool inRootSet) {
    _deleted = true;
  }

  @override
  bool isInstanceOf(T3VM vm, int obj) => false;

  @override
  int getSuperclass(T3VM vm, int self, int index) => invalidObj;

  @override
  void setProp(T3VM vm, T3Undo? undo, int self, int propId, dynamic val) {}

  @override
  bool getProp(T3VM vm, int propId, dynamic retval, int self, List<int> sourceObj, int? argc) => false;

  @override
  bool inhProp(
    T3VM vm,
    int propId,
    dynamic retval,
    int self,
    int origTargetObj,
    int definingObj,
    List<int> sourceObj,
    int? argc,
  ) => false;

  @override
  void buildPropList(T3VM vm, int self, dynamic retval) {}

  @override
  void markRefs(T3VM vm, int state) {}

  @override
  void applyUndo(T3VM vm, dynamic rec) {}

  @override
  void markUndoRef(T3VM vm, dynamic rec) {}

  @override
  void removeStaleUndoWeakRef(T3VM vm, dynamic rec) {}

  @override
  void loadFromImage(T3VM vm, int self, dynamic ptr, int offset, int size) {}

  @override
  void saveToFile(T3VM vm, dynamic fp) {}

  @override
  void restoreFromFile(T3VM vm, int self, dynamic fp, dynamic fixups) {}

  @override
  String? castToString(T3VM vm, int self, dynamic newStr) => null;
}

class MockT3Metaclass extends T3Metaclass {
  @override
  String getMetaName() => 'mock-object/030001';

  @override
  int createFromStack(T3VM vm, dynamic pc, int pcOffset, int argc) => invalidObj;

  @override
  void createForImageLoad(T3VM vm, int id) {}

  @override
  void createForRestore(T3VM vm, int id) {}

  @override
  bool callStatProp(T3VM vm, dynamic result, dynamic pc, int pcOffset, int argc, int prop) => false;

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
  late T3ObjectTable table;
  late T3VM vm;

  setUp(() {
    table = T3ObjectTable();
    vm = T3VM();
  });

  group('T3ObjectTable - Basic Allocation', () {
    test('allocates first object with ID 1', () {
      final id = table.allocObj(vm, false);
      expect(id, equals(1));
      expect(table.isObjIdValid(id), isTrue);
    });

    test('allocates sequential object IDs', () {
      final id1 = table.allocObj(vm, false);
      final id2 = table.allocObj(vm, false);
      final id3 = table.allocObj(vm, false);

      expect(id1, equals(1));
      expect(id2, equals(2));
      expect(id3, equals(3));
    });

    test('tracks free count correctly', () {
      final initialFree = table.freeCount;
      expect(initialFree, equals(4095)); // One page minus ID 0

      table.allocObj(vm, false);
      expect(table.freeCount, equals(initialFree - 1));

      table.allocObj(vm, false);
      expect(table.freeCount, equals(initialFree - 2));
    });

    test('allocates new page when first page is full', () {
      // Allocate all objects in first page (4095 objects)
      for (var i = 0; i < 4095; i++) {
        table.allocObj(vm, false);
      }

      // Next allocation should trigger new page
      final id = table.allocObj(vm, false);
      expect(id, equals(4096));
      expect(table.isObjIdValid(id), isTrue);
    });

    test('can allocate object at specific ID', () {
      table.allocObjWithId(100, false);
      expect(table.isObjIdValid(100), isTrue);
    });

    test('throws error when allocating already-used ID', () {
      table.allocObjWithId(50, false);
      expect(() => table.allocObjWithId(50, false), throwsA(isA<T3VmException>()));
    });
  });

  group('T3ObjectTable - Root Set', () {
    test('marks objects as in root set', () {
      final id = table.allocObj(vm, true); // inRootSet = true
      expect(table.isObjInRootSet(id), isTrue);
    });

    test('marks objects as not in root set', () {
      final id = table.allocObj(vm, false); // inRootSet = false
      expect(table.isObjInRootSet(id), isFalse);
    });

    test('allocObjWithId respects root set flag', () {
      table.allocObjWithId(42, true);
      expect(table.isObjInRootSet(42), isTrue);

      table.allocObjWithId(43, false);
      expect(table.isObjInRootSet(43), isFalse);
    });
  });

  group('T3ObjectTable - Transient Objects', () {
    test('objects are not transient by default', () {
      final id = table.allocObj(vm, false);
      expect(table.isObjTransient(id), isFalse);
    });

    test('can mark object as transient', () {
      final id = table.allocObj(vm, false);
      table.setObjTransient(id);
      expect(table.isObjTransient(id), isTrue);
    });
  });

  group('T3ObjectTable - GC Characteristics', () {
    test('objects can have refs by default', () {
      final id = table.allocObj(vm, false);
      final entry = table.getEntry(id)!;
      expect(entry.canHaveRefs, isTrue);
    });

    test('can set GC characteristics', () {
      final id = table.allocObj(vm, false);
      table.setObjGcCharacteristics(id, false, false);

      final entry = table.getEntry(id)!;
      expect(entry.canHaveRefs, isFalse);
      expect(entry.canHaveWeakRefs, isFalse);
    });

    test('allocObj respects GC characteristics', () {
      final id = table.allocObj(vm, false, false, false);
      final entry = table.getEntry(id)!;
      expect(entry.canHaveRefs, isFalse);
      expect(entry.canHaveWeakRefs, isFalse);
    });
  });

  group('T3ObjectTable - Object Access', () {
    test('getObj returns null for invalid ID', () {
      expect(table.getObj(invalidObj), isNull);
      expect(table.getObj(99999), isNull);
    });

    test('getObj returns object for valid ID', () {
      final id = table.allocObj(vm, false);
      final mockObj = MockT3Object();
      table.getEntry(id)!.obj = mockObj;

      expect(table.getObj(id), equals(mockObj));
    });

    test('getEntry returns null for invalid ID', () {
      expect(table.getEntry(invalidObj), isNull);
      expect(table.getEntry(99999), isNull);
    });

    test('getEntry returns entry for valid ID', () {
      final id = table.allocObj(vm, false);
      final entry = table.getEntry(id);
      expect(entry, isNotNull);
      expect(entry!.free, isFalse);
    });

    test('isObjIdValid returns false for invalid IDs', () {
      expect(table.isObjIdValid(invalidObj), isFalse);
      expect(table.isObjIdValid(99999), isFalse);
    });

    test('isObjIdValid returns true for allocated IDs', () {
      final id = table.allocObj(vm, false);
      expect(table.isObjIdValid(id), isTrue);
    });
  });

  group('T3ObjectTable - Undo Support', () {
    test('objects not in undo by default', () {
      final id = table.allocObj(vm, false);
      expect(table.isObjInUndo(id), isFalse);
    });

    test('notifyNewSavept marks all objects as in undo', () {
      final id1 = table.allocObj(vm, false);
      final id2 = table.allocObj(vm, false);

      table.notifyNewSavept();

      expect(table.isObjInUndo(id1), isTrue);
      expect(table.isObjInUndo(id2), isTrue);
    });

    test('transient objects not in undo even after savepoint', () {
      final id = table.allocObj(vm, false);
      table.setObjTransient(id);

      table.notifyNewSavept();

      expect(table.isObjInUndo(id), isFalse);
    });
  });

  group('T3ObjectTable - Persistence', () {
    test('root set objects are persistent', () {
      final id = table.allocObj(vm, true);
      expect(table.isObjPersistent(id), isTrue);
    });

    test('non-root-set, non-transient objects are persistent', () {
      final id = table.allocObj(vm, false);
      expect(table.isObjPersistent(id), isTrue);
    });

    test('transient objects are not persistent', () {
      final id = table.allocObj(vm, false);
      table.setObjTransient(id);
      expect(table.isObjPersistent(id), isFalse);
    });
  });

  group('T3ObjectTable - Global Objects', () {
    test('can add object to globals', () {
      final id = table.allocObj(vm, false);
      table.addToGlobals(id);
      // No direct way to test, but should not throw
    });

    test('does not add root set objects to globals', () {
      final id = table.allocObj(vm, true);
      table.addToGlobals(id);
      // Should not throw, but won't add to list
    });
  });

  group('T3ObjectTable - Iteration', () {
    test('forEach visits all allocated objects', () {
      final ids = <int>[];
      for (var i = 0; i < 10; i++) {
        ids.add(table.allocObj(vm, false));
      }

      final visited = <int>[];
      table.forEach(vm, (vm, objId, ctx) {
        visited.add(objId);
      }, null);

      expect(visited.length, equals(10));
      for (final id in ids) {
        expect(visited, contains(id));
      }
    });

    test('forEach does not visit free objects', () {
      table.allocObj(vm, false);
      table.allocObj(vm, false);

      var count = 0;
      table.forEach(vm, (vm, objId, ctx) {
        count++;
      }, null);

      expect(count, equals(2));
    });
  });

  group('T3ObjectTable - Post-Load Init', () {
    test('can request post-load init', () {
      final id = table.allocObj(vm, false);
      table.requestPostLoadInit(id);
      expect(table.getEntry(id)!.requestedPostLoadInit, isTrue);
    });

    test('can remove post-load init request', () {
      final id = table.allocObj(vm, false);
      table.requestPostLoadInit(id);
      table.removePostLoadInit(id);
      expect(table.getEntry(id)!.requestedPostLoadInit, isFalse);
    });
  });

  group('T3ObjectTable - Clear and Delete', () {
    test('clear removes non-root-set objects', () {
      final rootId = table.allocObj(vm, true);
      final nonRootId = table.allocObj(vm, false);

      final rootObj = MockT3Object();
      final nonRootObj = MockT3Object();
      table.getEntry(rootId)!.obj = rootObj;
      table.getEntry(nonRootId)!.obj = nonRootObj;

      table.clear(vm);

      expect(rootObj.wasDeleted, isFalse);
      expect(nonRootObj.wasDeleted, isTrue);
    });

    test('deleteTable removes all objects', () {
      final id1 = table.allocObj(vm, true);
      final id2 = table.allocObj(vm, false);

      final obj1 = MockT3Object();
      final obj2 = MockT3Object();
      table.getEntry(id1)!.obj = obj1;
      table.getEntry(id2)!.obj = obj2;

      table.deleteTable(vm);

      expect(obj1.wasDeleted, isTrue);
      expect(obj2.wasDeleted, isTrue);
      expect(table.freeCount, equals(0)); // All pages cleared
    });
  });

  group('T3ObjectTable - Edge Cases', () {
    test('handles maximum object ID correctly', () {
      final maxId = table.getMaxUsedObjId();
      expect(maxId, equals(4096)); // One page allocated
    });

    test('allocates across multiple pages', () {
      // Allocate objects across 3 pages
      for (var i = 0; i < 8200; i++) {
        table.allocObj(vm, false);
      }

      expect(table.getMaxUsedObjId(), greaterThanOrEqualTo(8200));
    });

    test('handles sparse allocation with allocObjWithId', () {
      table.allocObjWithId(1000, false);
      table.allocObjWithId(2000, false);
      table.allocObjWithId(3000, false);

      expect(table.isObjIdValid(1000), isTrue);
      expect(table.isObjIdValid(2000), isTrue);
      expect(table.isObjIdValid(3000), isTrue);
    });
  });
}
