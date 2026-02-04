// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_tz.dart';
import 'package:zart/src/tads3/vm/t3_tz_obj.dart';
import 'package:zart/src/tads3/vm/t3_globals.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';
import 'package:zart/src/tads3/vm/t3_object_table.dart';
import 'package:zart/src/tads3/vm/t3_pool.dart';
import 'package:zart/src/tads3/vm/t3_stack.dart';
import 'package:zart/src/tads3/vm/t3_list.dart';
import 'package:zart/src/tads3/vm/t3_string.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';

class MockBackingStore extends T3PoolBackingStore {
  @override
  Uint8List allocAndLoadPage(int offset, int pageSize, int loadSize) => Uint8List(loadSize);
  @override
  void freePage(Uint8List mem, int offset, int pageSize) {}
  @override
  int getCommonPageSize() => 1024;
  @override
  int getPageCount() => 0;
  @override
  int getPageSize(int offset, int pageSize) => 0;
  @override
  bool isWritable() => false;
  @override
  void loadPage(int offset, int pageSize, int loadSize, Uint8List mem) {}
}

void main() {
  group('T3TimeZoneCache', () {
    late T3TimeZoneCache cache;
    final tzPath = "packages/tads-sources/tads3/tz/timezones.t3tz";

    setUp(() {
      cache = T3TimeZoneCache();
    });

    test('Initializes from timezones.t3tz', () {
      expect(() => cache.init(tzPath), returnsNormally);
    });

    test('Loads a standard zone (America/Los_Angeles)', () {
      cache.init(tzPath);
      final zone = cache.getZone("America/Los_Angeles");
      expect(zone, isNotNull);
      expect(zone!.name, "America/Los_Angeles");
      expect(zone.trans, isNotEmpty);
      expect(zone.types, isNotEmpty);
      expect(zone.rules, isNotEmpty);
      expect(zone.country, "US");
    });

    test('Loads a synthetic GMT zone', () {
      cache.init(tzPath);
      final zone = cache.getZone("GMT+08:30");
      expect(zone, isNotNull);
      expect(zone!.types[0].gmtOffset, 8.5 * 3600 * 1000);
    });

    test('Loads local zone', () {
      cache.init(tzPath);
      final zone = cache.getZone(":local");
      expect(zone, isNotNull);
      expect(zone!.name, ":local");
    });
  });

  group('T3ObjTimeZone', () {
    late T3Globals vm;
    final tzPath = "packages/tads-sources/tads3/tz/timezones.t3tz";

    setUp(() {
      vm = T3Globals();
      vm.objTable = T3ObjectTable();
      vm.constPool = T3PoolInMem();
      vm.constPool!.attachBackingStore(MockBackingStore());
      vm.stack = T3Stack(1024, 128);
      vm.tzCache.init(tzPath);
    });

    test('getNames returns list of names', () {
      final tz = vm.tzCache.getZone("America/Los_Angeles")!;
      final objId = vm.objTable!.allocObj(vm, false);
      final obj = T3ObjTimeZone.withZone(tz);
      vm.objTable!.getEntry(objId)!.obj = obj;

      final retval = T3Value();
      final sourceObj = [0];
      // getNames is property index 1 in the vector
      final getNamesProp = 1001; // Mock prop ID
      vm.metaTable!.registerProp(T3MetaclassTimeZone.instance.getRegIdx(), getNamesProp, 1);

      final ok = obj.getProp(vm, getNamesProp, retval, objId, sourceObj, 0);
      expect(ok, isTrue);
      expect(retval.type, T3DataType.obj);

      final list = vm.objTable!.getObj(retval.getAsObj()!) as T3ObjList;
      expect(list.elements, isNotEmpty);
      String getStr(T3Value v) => (vm.objTable!.getObj(v.getAsObj()!) as T3ObjString).value;
      expect(getStr(list.elements[0]), "America/Los_Angeles");
      expect(list.elements.length, greaterThanOrEqualTo(1));
    });

    test('getHistory returns history list', () {
      final tz = vm.tzCache.getZone("UTC")!;
      final objId = vm.objTable!.allocObj(vm, false);
      final obj = T3ObjTimeZone.withZone(tz);
      vm.objTable!.getEntry(objId)!.obj = obj;

      final retval = T3Value();
      final getHistoryProp = 1002;
      vm.metaTable!.registerProp(T3MetaclassTimeZone.instance.getRegIdx(), getHistoryProp, 2);

      final ok = obj.getProp(vm, getHistoryProp, retval, objId, [0], 0);
      expect(ok, isTrue);
      final list = vm.objTable!.getObj(retval.getAsObj()!) as T3ObjList;
      expect(list.elements, isNotEmpty);

      // First item is pre-history
      final first = vm.objTable!.getObj(list.elements[0].getAsObj()!) as T3ObjList;
      expect(first.elements[0].getAsInt(), -2147483648);
      expect((vm.objTable!.getObj(first.elements[4].getAsObj()!) as T3ObjString).value, "UTC");
    });
  });
}
