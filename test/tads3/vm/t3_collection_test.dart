// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Unit tests for TADS3 Collection Base Class
///
/// Tests the abstract Collection class and its metaclass registration.
library;

import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_collection.dart';
import 'package:zart/src/tads3/vm/t3_error.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';

/// Mock Collection subclass for testing
class MockCollection extends T3Collection {
  bool newIteratorCalled = false;
  bool newLiveIteratorCalled = false;
  T3Value? lastSelfVal;

  @override
  void newIterator(T3VM vm, T3Value retval, T3Value selfVal) {
    newIteratorCalled = true;
    lastSelfVal = selfVal;
    // Return a mock object ID
    retval.setObj(1000);
  }

  @override
  void newLiveIterator(T3VM vm, T3Value retval, T3Value selfVal) {
    newLiveIteratorCalled = true;
    lastSelfVal = selfVal;
    // Return a mock object ID
    retval.setObj(1001);
  }

  // Required abstract method implementations from T3Object
  @override
  bool getProp(
    T3VM vm,
    int propId,
    T3Value retval,
    int self,
    List<int> sourceObj,
    int? argc,
  ) {
    // Set up self value for collection property lookup
    final selfVal = T3Value();
    selfVal.setObj(self);

    // Try collection-specific properties
    return constGetCollProp(vm, propId, retval, selfVal, sourceObj, argc);
  }

  @override
  void notifyDelete(T3VM vm, bool inRootSet) {}

  @override
  bool isInstanceOf(T3VM vm, int obj) => false;

  @override
  int getSuperclass(T3VM vm, int self, int index) => invalidObj;

  @override
  void setProp(T3VM vm, T3Undo? undo, int self, int propId, T3Value val) {}

  @override
  bool inhProp(
    T3VM vm,
    int propId,
    T3Value retval,
    int self,
    int origTargetObj,
    int definingObj,
    List<int> sourceObj,
    int? argc,
  ) => false;

  @override
  void buildPropList(T3VM vm, int self, T3Value retval) {}

  @override
  void markRefs(T3VM vm, int state) {}

  @override
  void applyUndo(T3VM vm, T3UndoRecord rec) {}

  @override
  void markUndoRef(T3VM vm, T3UndoRecord rec) {}

  @override
  void removeStaleUndoWeakRef(T3VM vm, T3UndoRecord rec) {}

  @override
  void loadFromImage(T3VM vm, int self, dynamic ptr, int offset, int size) {}

  @override
  void saveToFile(T3VM vm, dynamic fp) {}

  @override
  void restoreFromFile(T3VM vm, int self, dynamic fp, dynamic fixups) {}

  @override
  String? castToString(T3VM vm, int self, dynamic newStr) => null;
}

void main() {
  group('T3MetaclassCollection - Registration', () {
    test('has correct metaclass name', () {
      final metaclass = T3MetaclassCollection();
      expect(metaclass.getMetaName(), equals('collection/030000'));
    });

    test('static metaName matches instance method', () {
      expect(T3MetaclassCollection.metaName, equals('collection/030000'));
    });
  });

  group('T3MetaclassCollection - Cannot Instantiate', () {
    test('createFromStack throws vmErrBadDynamicNew', () {
      final metaclass = T3MetaclassCollection();
      final vm = T3VM();

      expect(
        () => metaclass.createFromStack(vm, null, 0, 0),
        throwsA(
          isA<T3VmException>().having(
            (e) => e.errorCode,
            'errorCode',
            vmErrBadDynamicNew,
          ),
        ),
      );
    });

    test('createForImageLoad throws vmErrBadStaticNew', () {
      final metaclass = T3MetaclassCollection();
      final vm = T3VM();

      expect(
        () => metaclass.createForImageLoad(vm, 1),
        throwsA(
          isA<T3VmException>().having(
            (e) => e.errorCode,
            'errorCode',
            vmErrBadStaticNew,
          ),
        ),
      );
    });

    test('createForRestore throws vmErrBadStaticNew', () {
      final metaclass = T3MetaclassCollection();
      final vm = T3VM();

      expect(
        () => metaclass.createForRestore(vm, 1),
        throwsA(
          isA<T3VmException>().having(
            (e) => e.errorCode,
            'errorCode',
            vmErrBadStaticNew,
          ),
        ),
      );
    });
  });

  group('T3MetaclassCollection - Static Properties', () {
    test('callStatProp returns false (no static props)', () {
      final metaclass = T3MetaclassCollection();
      final vm = T3VM();

      final result = metaclass.callStatProp(vm, null, null, 0, 0, 1);
      expect(result, isFalse);
    });

    test('getSupermeta returns invalidObj', () {
      final metaclass = T3MetaclassCollection();
      final vm = T3VM();

      expect(metaclass.getSupermeta(vm, 0), equals(invalidObj));
      expect(metaclass.getSupermeta(vm, 1), equals(invalidObj));
    });

    test('getSupermetaReg returns null', () {
      final metaclass = T3MetaclassCollection();
      expect(metaclass.getSupermetaReg(), isNull);
    });

    test('getClassObj returns invalidObj by default', () {
      final metaclass = T3MetaclassCollection();
      final vm = T3VM();
      expect(metaclass.getClassObj(vm), equals(invalidObj));
    });
  });

  group('T3Collection - Metaclass Registration', () {
    test('getMetaclassReg returns T3MetaclassCollection', () {
      final coll = MockCollection();
      expect(coll.getMetaclassReg(), isA<T3MetaclassCollection>());
    });

    test('static metaclassReg is shared', () {
      final coll1 = MockCollection();
      final coll2 = MockCollection();

      final meta1 = coll1.getMetaclassReg();
      final meta2 = coll2.getMetaclassReg();

      expect(meta1, same(meta2));
    });
  });

  group('T3Collection - isOfMetaclass', () {
    test('returns true for Collection metaclass', () {
      final coll = MockCollection();
      final metaclass = coll.getMetaclassReg();

      expect(coll.isOfMetaclass(metaclass), isTrue);
    });

    test('returns false for unrelated metaclass', () {
      final coll = MockCollection();
      final otherMeta = _MockMetaclass();

      expect(coll.isOfMetaclass(otherMeta), isFalse);
    });
  });

  group('T3Collection - Iterator Creation', () {
    test('getpCreateIterator calls newIterator', () {
      final coll = MockCollection();
      final vm = T3VM();
      final retval = T3Value();
      final selfVal = T3Value();
      selfVal.setObj(42);

      final result = coll.getpCreateIterator(vm, retval, selfVal, 0);

      expect(result, isTrue);
      expect(coll.newIteratorCalled, isTrue);
      expect(coll.newLiveIteratorCalled, isFalse);
      expect(retval.getAsObj(), equals(1000));
    });

    test('getpCreateLiveIterator calls newLiveIterator', () {
      final coll = MockCollection();
      final vm = T3VM();
      final retval = T3Value();
      final selfVal = T3Value();
      selfVal.setObj(42);

      final result = coll.getpCreateLiveIterator(vm, retval, selfVal, 0);

      expect(result, isTrue);
      expect(coll.newLiveIteratorCalled, isTrue);
      expect(coll.newIteratorCalled, isFalse);
      expect(retval.getAsObj(), equals(1001));
    });

    test('getpCreateIterator throws on wrong argc', () {
      final coll = MockCollection();
      final vm = T3VM();
      final retval = T3Value();
      final selfVal = T3Value();

      expect(
        () => coll.getpCreateIterator(vm, retval, selfVal, 1),
        throwsA(
          isA<T3VmException>().having(
            (e) => e.errorCode,
            'errorCode',
            vmErrWrongNumOfArgs,
          ),
        ),
      );
    });

    test('getpCreateLiveIterator throws on wrong argc', () {
      final coll = MockCollection();
      final vm = T3VM();
      final retval = T3Value();
      final selfVal = T3Value();

      expect(
        () => coll.getpCreateLiveIterator(vm, retval, selfVal, 2),
        throwsA(
          isA<T3VmException>().having(
            (e) => e.errorCode,
            'errorCode',
            vmErrWrongNumOfArgs,
          ),
        ),
      );
    });

    test('getpCreateIterator accepts null argc', () {
      final coll = MockCollection();
      final vm = T3VM();
      final retval = T3Value();
      final selfVal = T3Value();

      // null argc means "don't check" in TADS semantics
      final result = coll.getpCreateIterator(vm, retval, selfVal, null);
      expect(result, isTrue);
      expect(coll.newIteratorCalled, isTrue);
    });
  });

  group('T3Collection - constGetCollProp', () {
    test('returns false for unknown property', () {
      final coll = MockCollection();
      final vm = T3VM();
      final retval = T3Value();
      final selfVal = T3Value();
      selfVal.setObj(42);
      final sourceObj = [0];

      // Unknown property ID should return false
      final result = coll.constGetCollProp(
        vm,
        99999,
        retval,
        selfVal,
        sourceObj,
        0,
      );
      expect(result, isFalse);
    });
  });
}

/// Mock metaclass for testing isOfMetaclass
class _MockMetaclass extends T3Metaclass {
  @override
  String getMetaName() => 'mock/000000';

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
