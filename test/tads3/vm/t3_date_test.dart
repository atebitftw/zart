import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_date.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';
import 'package:zart/src/tads3/vm/t3_globals.dart';
import 'package:zart/src/tads3/vm/t3_object_table.dart';
import 'package:zart/src/tads3/vm/t3_metaclass_table.dart';
import 'package:zart/src/tads3/vm/t3_stack.dart';
import 'package:zart/src/tads3/vm/t3_pool.dart';
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
  group('T3ObjDate', () {
    late T3Globals globals;
    late T3VM vm;
    const propCompareTo = 1003;
    const propGetDate = 1006;
    const propDayOfWeek = 1008;
    const propAddDays = 1011;
    const propSubtractDays = 1012;

    setUp(() {
      globals = T3Globals();
      globals.objTable = T3ObjectTable();
      globals.metaTable = T3MetaclassTable();
      final regIdx = globals.metaTable!.registerMetaclass(T3MetaclassDate.instance);

      // Register properties used in tests
      globals.metaTable!.registerProp(regIdx, propCompareTo, 3);
      globals.metaTable!.registerProp(regIdx, propGetDate, 6);
      globals.metaTable!.registerProp(regIdx, propDayOfWeek, 8);
      globals.metaTable!.registerProp(regIdx, propAddDays, 11);
      globals.metaTable!.registerProp(regIdx, propSubtractDays, 12);

      globals.stack = T3Stack(100, 10);
      globals.constPool = T3PoolInMem();
      globals.constPool!.attachBackingStore(MockBackingStore());
      vm = globals;
    });

    test('Date calendar conversions (March 1, 0000)', () {
      final cal0 = T3DateCalendar.fromDayno(0);
      expect(cal0.year, equals(0));
      expect(cal0.month, equals(3));
      expect(cal0.day, equals(1));
      expect(T3DateCalendar.toDayno(0, 3, 1), equals(0));
    });

    test('Date calendar conversions (Unix Epoch)', () {
      final dayno = T3DateCalendar.toDayno(1970, 1, 1);
      expect(dayno, equals(719468));
      final cal = T3DateCalendar.fromDayno(dayno);
      expect(cal.year, equals(1970));
      expect(cal.month, equals(1));
      expect(cal.day, equals(1));
    });

    test('Leap year logic', () {
      expect(T3DateCalendar.isLeap(2000), isTrue);
      expect(T3DateCalendar.isLeap(2024), isTrue);
      expect(T3DateCalendar.isLeap(2100), isFalse);
      expect(T3DateCalendar.isLeap(2023), isFalse);
    });

    test('dayOfWeek', () {
      final d0 = T3ObjDate.fromValues(0, 0);
      final retval = T3Value();
      d0.getProp(vm, propDayOfWeek, retval, 0, [0], 0);
      expect(retval.type, equals(T3DataType.int32));
      expect(retval.getAsInt(), equals(4)); // Wednesday
    });

    test('CompareTo', () {
      final d1 = T3ObjDate.fromValues(100, 1000);
      final d2 = T3ObjDate.fromValues(100, 2000);

      final retval = T3Value();
      final otherVal = T3Value();
      final id = vm.objTable!.allocObj(vm, false);
      vm.objTable!.getEntry(id)!.obj = d2;
      otherVal.setObj(id);
      vm.stack.push(otherVal);

      d1.getProp(vm, propCompareTo, retval, 0, [0], 1);
      expect(retval.type, equals(T3DataType.int32));
      expect(retval.getAsInt(), equals(-1));
    });

    test('AddDays / SubtractDays', () {
      final d1 = T3ObjDate.fromValues(100, 5000);
      final retval = T3Value();

      final daysVal = T3Value();
      daysVal.setInt(10);
      vm.stack.push(daysVal);

      d1.getProp(vm, propAddDays, retval, 0, [0], 1); // addDays
      expect(retval.type, equals(T3DataType.obj));
      final d2 = vm.objTable!.getObj(retval.getAsObj()!) as T3ObjDate;
      expect(d2.dayno, equals(110));
      expect(d2.daytime, equals(5000));

      final subVal = T3Value();
      subVal.setInt(5);
      vm.stack.push(subVal);

      d2.getProp(vm, propSubtractDays, retval, 0, [0], 1); // subtractDays
      expect(retval.type, equals(T3DataType.obj));
      final d3 = vm.objTable!.getObj(retval.getAsObj()!) as T3ObjDate;
      expect(d3.dayno, equals(105));
    });
  });
}
