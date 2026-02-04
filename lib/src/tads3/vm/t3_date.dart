// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// TADS3 Date Metaclass
///
/// The Date intrinsic class represents a point in time, with millisecond
/// precision. It supports calendar arithmetic, formatting, and parsing.
///
/// Internal representation:
/// - dayno: Number of days since March 1, year 0 (TADS Epoch).
/// - daytime: Milliseconds past midnight UTC.
///
/// Ported from vmdate.cpp/vmdate.h
library;

import 'dart:typed_data';
import 'package:zart/src/tads3/vm/t3_error.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';
import 'package:zart/src/tads3/vm/t3_list.dart';
import 'package:zart/src/tads3/vm/t3_globals.dart';

// ----------------------------------------------------------------------------
// Date Constants
// ----------------------------------------------------------------------------

const int _propIdxCompareTo = 3;
const int _propIdxGetDate = 6;
const int _propIdxGetTime = 7;
const int _propIdxDayOfWeek = 8;
const int _propIdxDayOfYear = 9;
const int _propIdxIsLeapYear = 10;
const int _propIdxAddDays = 11;
const int _propIdxSubtractDays = 12;
const int _propIdxNow = 13;

/// Date object - represents a specific point in time.
class T3ObjDate extends T3Object {
  /// Days since March 1, 0000 UTC
  int dayno = 0;

  /// Milliseconds past midnight UTC
  int daytime = 0;

  T3ObjDate();

  T3ObjDate.fromValues(this.dayno, this.daytime);

  T3ObjDate.fromDateTime(DateTime dt) {
    // DateTime is since 1970-01-01.
    // TADS epoch is 0000-03-01.
    dayno = T3DateCalendar.toDayno(dt.year, dt.month, dt.day);
    daytime = ((dt.hour * 60 + dt.minute) * 60 + dt.second) * 1000 + dt.millisecond;
  }

  @override
  T3Metaclass getMetaclassReg() => T3MetaclassDate.instance;

  @override
  void notifyDelete(T3VM vm, bool inRootSet) {}

  @override
  bool isInstanceOf(T3VM vm, int obj) {
    return obj == getMetaclassReg().getClassObj(vm);
  }

  @override
  int getSuperclass(T3VM vm, int self, int index) {
    if (index == 0) return getMetaclassReg().getClassObj(vm);
    return invalidObjectId;
  }

  @override
  void setProp(T3VM vm, T3Undo? undo, int self, int propId, T3Value val) {
    throw T3VmException(vmErrInvalidSetprop);
  }

  @override
  bool getProp(T3VM vm, int propId, T3Value retval, int self, List<int> sourceObj, int? argc) {
    final funcIdx = vm.metaTable?.propToVectorIdx(getMetaclassReg().getRegIdx(), propId);
    if (funcIdx == null || funcIdx < 1 || funcIdx > _propIdxNow) {
      return false;
    }

    if (evalProp(vm, funcIdx, retval, self, argc)) {
      sourceObj[0] = getMetaclassReg().getClassObj(vm);
      return true;
    }
    return false;
  }

  bool evalProp(T3VM vm, int funcIdx, T3Value retval, int self, int? argc) {
    switch (funcIdx) {
      case _propIdxGetDate:
        return _getpGetDate(vm, retval, argc);
      case _propIdxGetTime:
        return _getpGetTime(vm, retval, argc);
      case _propIdxDayOfWeek:
        return _getpDayOfWeek(vm, retval, argc);
      case _propIdxDayOfYear:
        return _getpDayOfYear(vm, retval, argc);
      case _propIdxIsLeapYear:
        return _getpIsLeapYear(vm, retval, argc);
      case _propIdxCompareTo:
        return _getpCompareTo(vm, retval, argc);
      case _propIdxAddDays:
        return _getpAddDays(vm, retval, self, argc);
      case _propIdxSubtractDays:
        return _getpSubtractDays(vm, retval, self, argc);
      default:
        // TODO: Implement other properties (parseDate, formatDate, etc.)
        throw T3VmException(vmErrBadTypeBif);
    }
  }

  // ---------------------------------------------------------------------------
  // Property Implementations
  // ---------------------------------------------------------------------------

  bool _getpGetDate(T3VM vm, T3Value retval, int? argc) {
    _checkArgc(argc, 0);
    final cal = T3DateCalendar.fromDayno(dayno);
    retval.setObj(_createIntList(vm, [cal.year, cal.month, cal.day]));
    return true;
  }

  bool _getpGetTime(T3VM vm, T3Value retval, int? argc) {
    _checkArgc(argc, 0);
    final h = daytime ~/ (60 * 60 * 1000);
    final m = (daytime ~/ (60 * 1000)) % 60;
    final s = (daytime ~/ 1000) % 60;
    final ms = daytime % 1000;
    retval.setObj(_createIntList(vm, [h, m, s, ms]));
    return true;
  }

  bool _getpDayOfWeek(T3VM vm, T3Value retval, int? argc) {
    _checkArgc(argc, 0);
    retval.setInt(T3DateCalendar.weekday(dayno) + 1);
    return true;
  }

  bool _getpDayOfYear(T3VM vm, T3Value retval, int? argc) {
    _checkArgc(argc, 0);
    final cal = T3DateCalendar.fromDayno(dayno);
    retval.setInt(cal.dayOfYear);
    return true;
  }

  bool _getpIsLeapYear(T3VM vm, T3Value retval, int? argc) {
    _checkArgc(argc, 0);
    final cal = T3DateCalendar.fromDayno(dayno);
    retval.setLogical(T3DateCalendar.isLeap(cal.year));
    return true;
  }

  bool _getpCompareTo(T3VM vm, T3Value retval, int? argc) {
    _checkArgc(argc, 1);
    final otherVal = vm.stack.popVal();
    if (otherVal.type != T3DataType.obj) throw T3VmException(vmErrBadTypeBif);
    final other = vm.objTable.getObj(otherVal.getAsObj()!);
    if (other is! T3ObjDate) throw T3VmException(vmErrBadTypeBif);

    if (dayno != other.dayno) {
      retval.setInt(dayno > other.dayno ? 1 : -1);
    } else if (daytime != other.daytime) {
      retval.setInt(daytime > other.daytime ? 1 : -1);
    } else {
      retval.setInt(0);
    }
    return true;
  }

  bool _getpAddDays(T3VM vm, T3Value retval, int self, int? argc) {
    _checkArgc(argc, 1);
    final days = vm.stack.popVal().getAsInt();
    final newDate = T3ObjDate.fromValues((dayno + days).truncate(), daytime);
    final id = vm.objTable.allocObj(vm, false);
    vm.objTable.getEntry(id)!.obj = newDate;
    retval.setObj(id);
    return true;
  }

  bool _getpSubtractDays(T3VM vm, T3Value retval, int self, int? argc) {
    _checkArgc(argc, 1);
    final days = vm.stack.popVal().getAsInt();
    final newDate = T3ObjDate.fromValues((dayno - days).truncate(), daytime);
    final id = vm.objTable.allocObj(vm, false);
    vm.objTable.getEntry(id)!.obj = newDate;
    retval.setObj(id);
    return true;
  }

  // ---------------------------------------------------------------------------
  // Internal Helpers
  // ---------------------------------------------------------------------------

  void _checkArgc(int? argc, int expected) {
    if (argc != null && argc != expected) throw T3VmException(vmErrWrongNumOfArgs);
  }

  int _createIntList(T3VM vm, List<int> values) {
    final elements = values.map((v) {
      final val = T3Value();
      val.setInt(v);
      return val;
    }).toList();
    final listObj = T3ObjList(elements);
    final id = vm.objTable.allocObj(vm, false);
    vm.objTable.getEntry(id)!.obj = listObj;
    return id;
  }

  // ---------------------------------------------------------------------------
  // T3Object Overrides
  // ---------------------------------------------------------------------------

  @override
  void loadFromImage(T3VM vm, int self, Uint8List ptr, int offset, int size) {
    final view = ByteData.view(ptr.buffer, ptr.offsetInBytes + offset);
    dayno = view.getInt32(0, Endian.little);
    daytime = view.getUint32(4, Endian.little);
  }

  @override
  void saveToFile(T3VM vm, T3File fp) {}

  @override
  void restoreFromFile(T3VM vm, int self, T3File fp, T3ObjFixup fixups) {}

  @override
  bool equals(T3VM vm, int self, T3Value val, int depth) {
    if (val.type != T3DataType.obj) return false;
    final other = vm.objTable.getObj(val.getAsObj()!);
    if (other is! T3ObjDate) return false;
    return dayno == other.dayno && daytime == other.daytime;
  }

  @override
  int compareTo(T3VM vm, int self, T3Value val) {
    if (val.type != T3DataType.obj) throw T3VmException(vmErrInvalidComparison);
    final other = vm.objTable.getObj(val.getAsObj()!);
    if (other is! T3ObjDate) throw T3VmException(vmErrInvalidComparison);

    if (dayno != other.dayno) return dayno - other.dayno;
    return daytime - other.daytime;
  }

  @override
  void markRefs(T3VM vm, int state) {}

  @override
  void applyUndo(T3VM vm, T3UndoRecord rec) {}

  @override
  void markUndoRef(T3VM vm, T3UndoRecord rec) {}

  @override
  void removeStaleUndoWeakRef(T3VM vm, T3UndoRecord rec) {}

  @override
  void buildPropList(T3VM vm, int self, T3Value retval) {
    retval.setNil();
  }

  @override
  int llLength(T3VM vm, int self) => 0;

  @override
  bool isListlike(T3VM vm, int self) => false;

  @override
  bool indexValQ(T3VM vm, T3Value result, int self, T3Value indexVal) => false;

  @override
  bool setIndexValQ(T3VM vm, T3Value newContainer, int self, T3Value indexVal, T3Value newVal) => false;

  @override
  bool addVal(T3VM vm, T3Value result, int self, T3Value val) => false;

  @override
  bool subVal(T3VM vm, T3Value result, int self, T3Value val) => false;

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
  String? castToString(T3VM vm, int self, T3Value newStr) {
    final cal = T3DateCalendar.fromDayno(dayno);
    final h = daytime ~/ (60 * 60 * 1000);
    final m = (daytime ~/ (60 * 1000)) % 60;
    final s = (daytime ~/ 1000) % 60;
    final str =
        "${cal.year}-${cal.month.toString().padLeft(2, '0')}-${cal.day.toString().padLeft(2, '0')} "
        "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
    return str;
  }
}

// ----------------------------------------------------------------------------
// Date Metaclass
// ----------------------------------------------------------------------------

class T3MetaclassDate extends T3Metaclass {
  static final T3MetaclassDate instance = T3MetaclassDate._();
  T3MetaclassDate._();

  @override
  String getMetaName() => 'date/030000';

  @override
  int createFromStack(T3VM vm, Uint8List pc, int pcOffset, int argc) {
    T3ObjDate? date;

    if (argc == 0) {
      final now = DateTime.now().toUtc();
      date = T3ObjDate.fromDateTime(now);
    } else if (argc == 1) {
      final arg = vm.stack.popVal();
      if (arg.type == T3DataType.int32) {
        date = T3ObjDate.fromValues(arg.getAsInt(), 0);
      } else if (arg.type == T3DataType.list) {
        final list = getListElements(vm as T3Globals, arg);
        if (list != null && list.length >= 3) {
          final y = list[0].getAsInt();
          final m = list[1].getAsInt();
          final d = list[2].getAsInt();
          final h = list.length >= 4 ? list[3].getAsInt() : 0;
          final mi = list.length >= 5 ? list[4].getAsInt() : 0;
          final s = list.length >= 6 ? list[5].getAsInt() : 0;
          final ms = list.length >= 7 ? list[6].getAsInt() : 0;
          final dayno = T3DateCalendar.toDayno(y, m, d);
          final daytime = ((h * 60 + mi) * 60 + s) * 1000 + ms;
          date = T3ObjDate.fromValues(dayno, daytime);
        }
      }
    }

    if (date == null) throw T3VmException(vmErrBadTypeBif);

    final id = vm.objTable.allocObj(vm, false);
    vm.objTable.getEntry(id)!.obj = date;
    return id;
  }

  @override
  void createForImageLoad(T3VM vm, int id) {
    vm.objTable.getEntry(id)!.obj = T3ObjDate();
  }

  @override
  void createForRestore(T3VM vm, int id) {
    vm.objTable.getEntry(id)!.obj = T3ObjDate();
  }

  @override
  bool callStatProp(T3VM vm, T3Value result, Uint8List pc, int pcOffset, int argc, int prop) {
    final funcIdx = vm.metaTable?.propToVectorIdx(getRegIdx(), prop);
    if (funcIdx == _propIdxNow) {
      final now = DateTime.now().toUtc();
      final date = T3ObjDate.fromDateTime(now);
      final id = vm.objTable.allocObj(vm, false);
      vm.objTable.getEntry(id)!.obj = date;
      result.setObj(id);
      return true;
    }
    return false;
  }

  @override
  int getSupermeta(T3VM vm, int idx) => invalidObjectId;

  @override
  bool isMetaInstanceOf(T3VM vm, int obj) {
    final o = vm.objTable.getObj(obj);
    return o is T3ObjDate;
  }

  @override
  T3Metaclass? getSupermetaReg() => null;

  @override
  int getClassObj(T3VM vm) {
    return vm.metaTable?.getClassObj(getRegIdx()) ?? invalidObjectId;
  }
}

// ----------------------------------------------------------------------------
// Calendar Helper
// ----------------------------------------------------------------------------

/// Helper for TADS Epoch math (March 1, 0000).
class T3DateCalendar {
  final int year;
  final int month;
  final int day;

  T3DateCalendar(this.year, this.month, this.day);

  static bool isLeap(int y) {
    return (y % 4 == 0 && (y % 100 != 0 || y % 400 == 0));
  }

  static int divfl(int a, int b) {
    return (a < 0 && a % b != 0) ? (a ~/ b) - 1 : (a ~/ b);
  }

  factory T3DateCalendar.fromDayno(int dayno) {
    var y = ((10000 * dayno + 14780) / 3652425).floor();
    var d = dayno - (365 * y + divfl(y, 4) - divfl(y, 100) + divfl(y, 400));
    if (d < 0) {
      y--;
      d = dayno - (365 * y + divfl(y, 4) - divfl(y, 100) + divfl(y, 400));
    }
    final m = (100 * d + 52) ~/ 3060;

    final yy = y + (m + 2) ~/ 12;
    final mm = (m + 2) % 12 + 1;
    final dd = d - (m * 306 + 5) ~/ 10 + 1;
    return T3DateCalendar(yy, mm, dd);
  }

  static int toDayno(int year, int month, int day) {
    var m = month - 3;
    var y = year;
    if (m < 0) {
      m += 12;
      y -= 1;
    }
    return 365 * y + divfl(y, 4) - divfl(y, 100) + divfl(y, 400) + (m * 306 + 5) ~/ 10 + (day - 1);
  }

  static int weekday(int dayno) {
    // March 1, 0000 was Wednesday = 3 (0=Sunday in TADS internal CD code)
    // TADS weekday() logic in vmdate.h:
    // const static int t[] = {0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4};
    // int yy = y - (m < 3 ? 1 : 0);
    // return (yy + yy/4 - yy/100 + yy/400 + t[m-1] + d) % 7;
    // But we have dayno. TADS CD(dayno).weekday() just uses dayno % 7 adjusted?
    // Let's test: dayno 0 -> March 1, 0000.
    // If March 1, 0000 was Wednesday, then (dayno + 3) % 7 gives weekday where 0=Sunday.
    return (dayno + 3) % 7;
  }

  int get dayOfYear {
    final mdays = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (isLeap(year)) mdays[2] = 29;
    var result = 0;
    for (var i = 1; i < month; i++) result += mdays[i];
    return result + day;
  }
}
