// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Unit tests for TADS3 TadsObject Metaclass
///
/// Tests the T3TadsObject class and its supporting data structures.
library;

import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_error.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_object_table.dart';
import 'package:zart/src/tads3/vm/t3_tads_object.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';

void main() {
  group('T3TadsObjProp - Property Entry', () {
    test('creates with default values', () {
      final prop = T3TadsObjProp(propId: 100);

      expect(prop.propId, equals(100));
      expect(prop.flags, equals(0));
      expect(prop.next, isNull);
      expect(prop.val.type, equals(T3DataType.nil));
    });

    test('creates with value copy', () {
      final srcVal = T3Value();
      srcVal.setInt(42);

      final prop = T3TadsObjProp(propId: 100, value: srcVal);

      expect(prop.val.type, equals(T3DataType.int32));
      expect(prop.val.getAsInt(), equals(42));
    });

    test('isModified flag works', () {
      final prop = T3TadsObjProp(propId: 100);

      expect(prop.isModified, isFalse);
      prop.setModified();
      expect(prop.isModified, isTrue);
    });

    test('hasUndo flag works', () {
      final prop = T3TadsObjProp(propId: 100);

      expect(prop.hasUndo, isFalse);
      prop.setUndo();
      expect(prop.hasUndo, isTrue);
      prop.clearUndo();
      expect(prop.hasUndo, isFalse);
    });
  });

  group('T3TadsObjSc - Superclass Entry', () {
    test('creates with object ID', () {
      final sc = T3TadsObjSc(id: 42);

      expect(sc.id, equals(42));
      expect(sc.objp, isNull);
    });
  });

  group('T3TadsObjHeader - Object Header', () {
    test('creates with default values', () {
      final hdr = T3TadsObjHeader();

      expect(hdr.liObjFlags, equals(0));
      expect(hdr.internObjFlags, equals(0));
      expect(hdr.superclassCount, equals(0));
      expect(hdr.propCount, equals(0));
      expect(hdr.hashSize, equals(16));
    });

    test('creates with superclasses', () {
      final hdr = T3TadsObjHeader(superclassCount: 3);

      expect(hdr.superclassCount, equals(3));
      expect(hdr.superclasses[0].id, equals(invalidObj));
      expect(hdr.superclasses[1].id, equals(invalidObj));
      expect(hdr.superclasses[2].id, equals(invalidObj));
    });

    test('isClass flag works', () {
      final hdr = T3TadsObjHeader();

      expect(hdr.isClass, isFalse);
      hdr.liObjFlags |= vmtobjObjfClass;
      expect(hdr.isClass, isTrue);
    });

    test('isFromImage flag works', () {
      final hdr = T3TadsObjHeader();

      expect(hdr.isFromImage, isFalse);
      hdr.setFromImage();
      expect(hdr.isFromImage, isTrue);
    });

    test('isModified flag works', () {
      final hdr = T3TadsObjHeader();

      expect(hdr.isModified, isFalse);
      hdr.setModified();
      expect(hdr.isModified, isTrue);
    });

    test('calcHash returns valid bucket index', () {
      final hdr = T3TadsObjHeader(hashSize: 16);

      // Hash should be propId & (hashSize - 1)
      expect(hdr.calcHash(0), equals(0));
      expect(hdr.calcHash(15), equals(15));
      expect(hdr.calcHash(16), equals(0));
      expect(hdr.calcHash(17), equals(1));
    });

    test('findPropEntry returns null for missing property', () {
      final hdr = T3TadsObjHeader();

      expect(hdr.findPropEntry(100), isNull);
    });

    test('allocPropEntry adds property', () {
      final hdr = T3TadsObjHeader();
      final val = T3Value();
      val.setInt(42);

      final entry = hdr.allocPropEntry(100, val, 0);

      expect(entry.propId, equals(100));
      expect(entry.val.getAsInt(), equals(42));
      expect(hdr.propCount, equals(1));
    });

    test('findPropEntry finds allocated property', () {
      final hdr = T3TadsObjHeader();
      final val = T3Value();
      val.setInt(42);

      hdr.allocPropEntry(100, val, 0);

      final found = hdr.findPropEntry(100);
      expect(found, isNotNull);
      expect(found!.val.getAsInt(), equals(42));
    });

    test('multiple properties in same bucket form chain', () {
      final hdr = T3TadsObjHeader(hashSize: 16);
      final val1 = T3Value();
      val1.setInt(1);
      final val2 = T3Value();
      val2.setInt(2);

      // Props 0 and 16 both hash to bucket 0
      hdr.allocPropEntry(0, val1, 0);
      hdr.allocPropEntry(16, val2, 0);

      expect(hdr.propCount, equals(2));
      expect(hdr.findPropEntry(0)!.val.getAsInt(), equals(1));
      expect(hdr.findPropEntry(16)!.val.getAsInt(), equals(2));
    });

    test('clearUndoFlags clears all entries', () {
      final hdr = T3TadsObjHeader();
      final val = T3Value();

      final entry1 = hdr.allocPropEntry(100, val, 0);
      final entry2 = hdr.allocPropEntry(200, val, 0);

      entry1.setUndo();
      entry2.setUndo();
      expect(entry1.hasUndo, isTrue);
      expect(entry2.hasUndo, isTrue);

      hdr.clearUndoFlags();

      expect(entry1.hasUndo, isFalse);
      expect(entry2.hasUndo, isFalse);
    });
  });

  group('T3MetaclassTads - Metaclass', () {
    test('has correct metaclass name', () {
      final meta = T3MetaclassTads();
      expect(meta.getMetaName(), equals('tads-object/030005'));
    });

    test('static metaName matches instance method', () {
      expect(T3MetaclassTads.metaName, equals('tads-object/030005'));
    });

    test('createFromStack throws for now', () {
      final meta = T3MetaclassTads();
      final vm = T3VM();

      expect(
        () => meta.createFromStack(vm, null, 0, 0),
        throwsA(isA<T3VmException>()),
      );
    });

    test('callStatProp returns false', () {
      final meta = T3MetaclassTads();
      final vm = T3VM();

      expect(meta.callStatProp(vm, null, null, 0, 0, 1), isFalse);
    });

    test('getSupermeta returns invalidObj', () {
      final meta = T3MetaclassTads();
      final vm = T3VM();

      expect(meta.getSupermeta(vm, 0), equals(invalidObj));
    });

    test('getSupermetaReg returns null', () {
      final meta = T3MetaclassTads();
      expect(meta.getSupermetaReg(), isNull);
    });
  });

  group('T3TadsObject - Basic Operations', () {
    test('getMetaclassReg returns T3MetaclassTads', () {
      final obj = T3TadsObject();
      obj.initHeader();

      expect(obj.getMetaclassReg(), isA<T3MetaclassTads>());
    });

    test('initHeader creates valid header', () {
      final obj = T3TadsObject();
      obj.initHeader(superclassCount: 2, propCount: 32);

      expect(obj.scCount, equals(2));
      expect(obj.header.hashSize, greaterThanOrEqualTo(32));
    });

    test('getSc returns superclass ID', () {
      final obj = T3TadsObject();
      obj.initHeader(superclassCount: 2);
      obj.header.superclasses[0].id = 100;
      obj.header.superclasses[1].id = 200;

      expect(obj.getSc(0), equals(100));
      expect(obj.getSc(1), equals(200));
    });

    test('isClassObject returns correct value', () {
      final obj = T3TadsObject();
      final vm = T3VM();
      obj.initHeader();

      expect(obj.isClassObject(vm, 1), isFalse);

      obj.header.liObjFlags |= vmtobjObjfClass;
      expect(obj.isClassObject(vm, 1), isTrue);
    });

    test('providesProps returns true', () {
      final obj = T3TadsObject();
      final vm = T3VM();
      obj.initHeader();

      expect(obj.providesProps(vm), isTrue);
    });
  });

  group('T3TadsObject - Property Operations', () {
    test('setProp stores new property', () {
      final obj = T3TadsObject();
      final vm = T3VM();
      obj.initHeader();

      final val = T3Value();
      val.setInt(42);

      obj.setProp(vm, null, 1, 100, val);

      final entry = obj.findPropEntry(100);
      expect(entry, isNotNull);
      expect(entry!.val.getAsInt(), equals(42));
    });

    test('setProp updates existing property', () {
      final obj = T3TadsObject();
      final vm = T3VM();
      obj.initHeader();

      final val1 = T3Value();
      val1.setInt(42);
      obj.setProp(vm, null, 1, 100, val1);

      final val2 = T3Value();
      val2.setInt(99);
      obj.setProp(vm, null, 1, 100, val2);

      final entry = obj.findPropEntry(100);
      expect(entry!.val.getAsInt(), equals(99));
    });

    test('setProp marks object as modified', () {
      final obj = T3TadsObject();
      final vm = T3VM();
      obj.initHeader();

      expect(obj.isChangedSinceLoad(), isFalse);

      final val = T3Value();
      val.setInt(42);
      obj.setProp(vm, null, 1, 100, val);

      expect(obj.isChangedSinceLoad(), isTrue);
    });

    test('getProp returns stored property', () {
      final obj = T3TadsObject();
      final vm = T3VM();
      obj.initHeader();

      final val = T3Value();
      val.setInt(42);
      obj.setProp(vm, null, 1, 100, val);

      final retval = T3Value();
      final sourceObj = [0];
      final found = obj.getProp(vm, 100, retval, 1, sourceObj, null);

      expect(found, isTrue);
      expect(retval.type, equals(T3DataType.int32));
      expect(retval.getAsInt(), equals(42));
      expect(sourceObj[0], equals(1));
    });

    test('getProp returns false for missing property', () {
      final obj = T3TadsObject();
      final vm = T3VM();
      obj.initHeader();

      final retval = T3Value();
      final sourceObj = [0];
      final found = obj.getProp(vm, 999, retval, 1, sourceObj, null);

      expect(found, isFalse);
    });
  });

  group('T3TadsObject - Inheritance', () {
    test('isInstanceOf checks direct superclasses', () {
      final obj = T3TadsObject();
      final vm = T3VM();
      obj.initHeader(superclassCount: 2);
      obj.header.superclasses[0].id = 100;
      obj.header.superclasses[1].id = 200;

      expect(obj.isInstanceOf(vm, 100), isTrue);
      expect(obj.isInstanceOf(vm, 200), isTrue);
      expect(obj.isInstanceOf(vm, 300), isFalse);
    });

    test('getSuperclassCount returns correct count', () {
      final obj = T3TadsObject();
      final vm = T3VM();
      obj.initHeader(superclassCount: 3);

      expect(obj.getSuperclassCount(vm, 1), equals(3));
    });

    test('getSuperclass returns superclass ID', () {
      final obj = T3TadsObject();
      final vm = T3VM();
      obj.initHeader(superclassCount: 2);
      obj.header.superclasses[0].id = 100;
      obj.header.superclasses[1].id = 200;

      expect(obj.getSuperclass(vm, 1, 0), equals(100));
      expect(obj.getSuperclass(vm, 1, 1), equals(200));
      expect(obj.getSuperclass(vm, 1, 2), equals(invalidObj));
    });
  });

  group('T3TadsObject - Savepoint', () {
    test('notifyNewSavept clears undo flags', () {
      final obj = T3TadsObject();
      final vm = T3VM();
      obj.initHeader();

      final val = T3Value();
      obj.setProp(vm, null, 1, 100, val);
      obj.setProp(vm, null, 1, 200, val);

      obj.findPropEntry(100)!.setUndo();
      obj.findPropEntry(200)!.setUndo();

      obj.notifyNewSavept();

      expect(obj.findPropEntry(100)!.hasUndo, isFalse);
      expect(obj.findPropEntry(200)!.hasUndo, isFalse);
    });
  });

  group('T3TadsObject - Object Table Integration', () {
    late T3ObjectTable objTable;
    late T3VM vm;

    setUp(() {
      objTable = T3ObjectTable();
      vm = T3VM();
      objTable.init(vm);
    });

    test('isTadsObj returns false for invalid object ID', () {
      expect(T3TadsObject.isTadsObj(objTable, invalidObj), isFalse);
    });

    test('isTadsObj returns false for non-existent object', () {
      expect(T3TadsObject.isTadsObj(objTable, 999), isFalse);
    });

    test('isTadsObj returns true for registered TadsObject', () {
      // Allocate an object slot
      final objId = objTable.allocObj(vm, true);

      // Create a TadsObject and assign it to the slot
      final tadsObj = T3TadsObject();
      tadsObj.initHeader();

      // Get the entry and set the object
      final entry = objTable.getEntry(objId);
      entry!.obj = tadsObj;

      // Now check
      expect(T3TadsObject.isTadsObj(objTable, objId), isTrue);
    });

    test('setSc caches superclass object pointer', () {
      // Allocate IDs for superclass and child
      final superclassId = objTable.allocObj(vm, true);
      final childId = objTable.allocObj(vm, true);

      // Create the superclass TadsObject
      final superclassObj = T3TadsObject();
      superclassObj.initHeader();
      objTable.getEntry(superclassId)!.obj = superclassObj;

      // Create the child TadsObject with 1 superclass
      final childObj = T3TadsObject();
      childObj.initHeader(superclassCount: 1);
      objTable.getEntry(childId)!.obj = childObj;

      // Set superclass with object table - should cache
      childObj.setSc(0, superclassId, objTable);

      expect(childObj.getSc(0), equals(superclassId));
      expect(childObj.getScObjp(0), isNotNull);
      expect(childObj.getScObjp(0), same(superclassObj));
    });

    test('setSc without object table does not cache', () {
      final obj = T3TadsObject();
      obj.initHeader(superclassCount: 1);

      // Set superclass without object table
      obj.setSc(0, 100);

      expect(obj.getSc(0), equals(100));
      expect(obj.getScObjp(0), isNull);
    });

    test('isMetaInstanceOfWithTable uses object table', () {
      final meta = T3MetaclassTads();

      // Allocate and create a TadsObject
      final objId = objTable.allocObj(vm, true);
      final tadsObj = T3TadsObject();
      tadsObj.initHeader();
      objTable.getEntry(objId)!.obj = tadsObj;

      expect(meta.isMetaInstanceOfWithTable(objTable, objId), isTrue);
      expect(meta.isMetaInstanceOfWithTable(objTable, invalidObj), isFalse);
    });
  });
}
