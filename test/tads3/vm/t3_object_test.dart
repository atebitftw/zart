// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Unit tests for TADS3 Object Base Class
///
/// Tests the base object's default behaviors and utility methods.
library;

import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';

class MockT3Object extends T3Object {
  @override
  T3Metaclass getMetaclassReg() => MockT3Metaclass();

  @override
  void notifyDelete(T3VM vm, bool inRootSet) {}

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
  void loadFromImage(T3VM vm, int self, Uint8List ptr, int offset, int size) {}

  @override
  void saveToFile(T3VM vm, T3File fp) {}

  @override
  void restoreFromFile(T3VM vm, int self, T3File fp, T3ObjFixup fixups) {}

  @override
  String? castToString(T3VM vm, int self, dynamic newStr) => null;
}

class MockT3Metaclass extends T3Metaclass {
  String _name = 'mock-object/030001-test';
  void setName(String name) => _name = name;

  @override
  String getMetaName() => _name;

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
  late MockT3Object obj;
  late T3VM vm;

  setUp(() {
    obj = MockT3Object();
    vm = T3VM();
  });

  group('T3Object - Default Behaviors', () {
    test('getImageFileVersion parsing', () {
      final version = obj.getImageFileVersion(vm);
      expect(version, equals('030001-test'));
    });

    test('isChangedSinceLoad is false by default', () {
      expect(obj.isChangedSinceLoad(), isFalse);
    });

    test('arithmetic methods return false by default', () {
      final res = T3Value();
      final val = T3Value();
      expect(obj.addVal(vm, res, 1, val), isFalse);
      expect(obj.subVal(vm, res, 1, val), isFalse);
      expect(obj.mulVal(vm, res, 1, val), isFalse);
      expect(obj.divVal(vm, res, 1, val), isFalse);
      expect(obj.negVal(vm, res, 1), isFalse);
    });

    test('indexing methods return false by default', () {
      final res = T3Value();
      final val = T3Value();
      expect(obj.indexValQ(vm, res, 1, val), isFalse);
      expect(obj.setIndexValQ(vm, res, 1, val, val), isFalse);
    });
  });
}
