// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// TADS3 TimeZone Metaclass
///
/// The TimeZone intrinsic class represents a time zone. It provides
/// information about historical transitions, rules, and localization.
///
/// Ported from vmtzobj.cpp and vmtzobj.h.
library;

import 'dart:typed_data';
import 'package:zart/src/tads3/vm/t3_error.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';
import 'package:zart/src/tads3/vm/t3_list.dart';
import 'package:zart/src/tads3/vm/t3_string.dart';
import 'package:zart/src/tads3/vm/t3_globals.dart';
import 'package:zart/src/tads3/vm/t3_tz.dart';

// ----------------------------------------------------------------------------
// Constants
// ----------------------------------------------------------------------------

const int _propIdxGetNames = 1;
const int _propIdxGetHistory = 2;
const int _propIdxGetRules = 3;
const int _propIdxGetLocation = 4;

// ----------------------------------------------------------------------------
// TimeZone Object
// ----------------------------------------------------------------------------

/// TimeZone object - represents a specific time zone.
class T3ObjTimeZone extends T3Object {
  /// The underlying time zone data.
  T3TimeZone? tz;

  T3ObjTimeZone();

  T3ObjTimeZone.withZone(this.tz);

  @override
  T3Metaclass getMetaclassReg() => T3MetaclassTimeZone.instance;

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
    if (funcIdx == null || funcIdx < 1 || funcIdx > _propIdxGetLocation) {
      return false;
    }

    if (evalProp(vm, funcIdx, retval, self, argc)) {
      sourceObj[0] = getMetaclassReg().getClassObj(vm);
      return true;
    }
    return false;
  }

  bool evalProp(T3VM vm, int funcIdx, T3Value retval, int self, int? argc) {
    if (tz == null) throw T3VmException(vmErrBadTypeBif);

    switch (funcIdx) {
      case _propIdxGetNames:
        return _getpGetNames(vm, retval, argc);
      case _propIdxGetHistory:
        return _getpGetHistory(vm, retval, argc);
      case _propIdxGetRules:
        return _getpGetRules(vm, retval, argc);
      case _propIdxGetLocation:
        return _getpGetLocation(vm, retval, argc);
      default:
        return false;
    }
  }

  bool _getpGetNames(T3VM vm, T3Value retval, int? argc) {
    _checkArgc(argc, 0);

    final globals = vm as T3Globals;
    final primaryName = tz!.name;
    final aliases = globals.tzCache.getAliases(primaryName);

    final names = <T3Value>[];

    // Add primary name first
    final primaryVal = T3Value();
    final primaryId = globals.objTable!.allocObj(vm, false);
    globals.objTable!.getEntry(primaryId)!.obj = T3ObjString(primaryName);
    primaryVal.setObj(primaryId);
    names.add(primaryVal);

    // Add aliases
    for (final alias in aliases) {
      final aliasVal = T3Value();
      final aliasId = globals.objTable!.allocObj(vm, false);
      globals.objTable!.getEntry(aliasId)!.obj = T3ObjString(alias);
      aliasVal.setObj(aliasId);
      names.add(aliasVal);
    }

    retval.setObj(_createList(vm, names));
    return true;
  }

  bool _getpGetHistory(T3VM vm, T3Value retval, int? argc) {
    _checkArgc(argc, 0);
    final history = <T3Value>[];

    // First item is the pre-history state (first type)
    if (tz!.types.isNotEmpty) {
      history.add(_createHistoryItem(vm, -2147483648, -2147483648, tz!.types[0]));
    }

    for (var t in tz!.trans) {
      history.add(_createHistoryItem(vm, t.dayno, t.daytime, t.type));
    }

    retval.setObj(_createList(vm, history));
    return true;
  }

  T3Value _createHistoryItem(T3VM vm, int dayno, int daytime, T3TimeZoneType type) {
    final list = <T3Value>[];
    list.add(T3Value()..setInt(dayno));
    list.add(T3Value()..setInt(daytime));
    list.add(T3Value()..setInt(type.gmtOffset));
    list.add(T3Value()..setInt(type.save));

    final abbrVal = T3Value();
    final stringObj = T3ObjString(type.abbr ?? "");
    final stringId = vm.objTable.allocObj(vm, false);
    vm.objTable.getEntry(stringId)!.obj = stringObj;
    abbrVal.setObj(stringId);
    list.add(abbrVal);

    final val = T3Value();
    val.setObj(_createList(vm, list));
    return val;
  }

  bool _getpGetRules(T3VM vm, T3Value retval, int? argc) {
    _checkArgc(argc, 0);
    final list = <T3Value>[];
    for (var r in tz!.rules) {
      final item = <T3Value>[];

      final fmtVal = T3Value();
      final stringId = (vm as T3Globals).objTable!.allocObj(vm, false);
      vm.objTable!.getEntry(stringId)!.obj = T3ObjString(r.fmt ?? "");
      fmtVal.setObj(stringId);
      item.add(fmtVal);

      item.add(T3Value()..setInt(r.mm));
      item.add(T3Value()..setInt(r.when));
      item.add(T3Value()..setInt(r.dd));
      item.add(T3Value()..setInt(r.weekday));
      item.add(T3Value()..setInt(r.at | (r.atZone << 24)));
      item.add(T3Value()..setInt(r.gmtOffset));
      item.add(T3Value()..setInt(r.save));

      final val = T3Value();
      val.setObj(_createList(vm, item));
      list.add(val);
    }
    retval.setObj(_createList(vm, list));
    return true;
  }

  bool _getpGetLocation(T3VM vm, T3Value retval, int? argc) {
    _checkArgc(argc, 0);
    final list = <T3Value>[];
    final item = (String s) {
      final val = T3Value();
      final id = (vm as T3Globals).objTable!.allocObj(vm, false);
      vm.objTable!.getEntry(id)!.obj = T3ObjString(s);
      val.setObj(id);
      return val;
    };

    list.add(item(tz!.country ?? ""));
    list.add(item(tz!.coords ?? ""));
    list.add(item(tz!.desc ?? ""));
    retval.setObj(_createList(vm, list));
    return true;
  }

  void _checkArgc(int? argc, int expected) {
    if (argc != null && argc != expected) throw T3VmException(vmErrWrongNumOfArgs);
  }

  int _createList(T3VM vm, List<T3Value> elements) {
    final listObj = T3ObjList(elements);
    final id = vm.objTable.allocObj(vm, false);
    vm.objTable.getEntry(id)!.obj = listObj;
    return id;
  }

  @override
  void loadFromImage(T3VM vm, int self, Uint8List ptr, int offset, int size) {
    if (size < 9) return; // Minimum size check (adjust based on format)

    final view = ByteData.sublistView(ptr, offset, offset + size);
    int p = 0;

    // Read stored offsets (ms) - conversion handling might be needed if they are signed?
    // ByteData.getInt32 is signed.
    final stdOfs = view.getInt32(p, Endian.little);
    p += 4;
    final dstSave = view.getInt32(p, Endian.little);
    p += 4;

    // Read abbreviation (Pascal-style string: len byte + chars)
    // Actually VMTZOBJ.CPP says it reads "std_abbr" then "dst_abbr"?
    // No, logic was:
    // "read the default abbreviation"
    // "const char *abbr = ptr + 8 + osrp1(ptr+8) + 1;" -> this offset matches start of abbr
    // "lib_strcpy(desc.std_abbr, ..., abbr+1, osrp1(abbr));" -> reads content

    // Let's verify order:
    // C++ logic accesses offsets around `ptr+8` (name len).
    // The C++ `save_to_file` writes: gmtofs, save, abbr, name.
    // [0-3] gmtofs
    // [4-7] save
    // [8...] abbr (len + chars)
    // [After abbr] name (len + chars)

    // BUT `load_image_data` uses `ptr+9` and `osrp1(ptr+8)` to PARSE ZONE.
    // If format is [gmtofs][save][abbr][name], then name is AFTER abbr.
    // If name is at 9, then abbr must be length 0? Or I misread C++.

    // Let's look at `RESTORE_FROM_FILE` in C++:
    // fp->read_int4() (std_ofs)
    // fp->read_int4() (dst_ofs/save?)
    // fp->read_str_byte_prefix() (abbr)
    // fp->read_str_byte_prefix() (name)
    // This MATCHES `save_to_file`.

    // BUT `load_from_image` (IMAGE FILE) format might be DIFFERENT from SAVE FILE format.
    // `load_image_data` does:
    //   CVmTimeZone *tz = G_tzcache->parse_zone(vmg_ ptr+9, osrp1(ptr+8));
    //   desc.std_ofs = osrp4s(ptr) / 1000;
    //   desc.dst_ofs = desc.std_ofs + osrp4s(ptr+4) / 1000;
    //   const char *abbr = ptr + 8 + osrp1(ptr+8) + 1;

    // This implies layout:
    // [0-3] std_ofs
    // [4-7] dst_ofs (or save?)
    // [8]   name_len
    // [9...9+name_len-1] name
    // [9+name_len] abbr_len
    // [9+name_len+1...] abbr

    // OK, let's implement that.

    final nameLen = view.getUint8(p);
    p++;
    final nameBytes = ptr.sublist(offset + p, offset + p + nameLen);
    final name = String.fromCharCodes(nameBytes);
    p += nameLen;

    final abbrLen = view.getUint8(p);
    p++;
    final abbrBytes = ptr.sublist(offset + p, offset + p + abbrLen);
    final abbr = String.fromCharCodes(abbrBytes);
    // p += abbrLen; // Not strictly needed unless checking size

    final globals = vm as T3Globals;
    // Try to find in cache
    var tz = globals.tzCache.getZone(name);

    if (tz == null) {
      // Create missing zone
      // Note: C++ uses stdOfs/1000 (seconds) for OS desc.
      // But T3TimeZoneType stores offsets in ms.
      // stdOfs read from file is likely MS?
      // C++: "desc.std_ofs = osrp4s(ptr) / 1000;" -> so file has MS.

      // Calculate true offsets.
      // T3TimeZoneType takes gmtofs and save.
      // stdOfs is gmtofs.
      // dstSave is "dst_ofs - std_ofs" or simple "save"?
      // C++: "desc.dst_ofs = desc.std_ofs + osrp4s(ptr+4) / 1000;"
      // If ptr+4 is just the "save" (e.g. 3600000), then dst_ofs = std_ofs + 3600.
      // Yes, usually ptr+4 is "save".

      tz = globals.tzCache.createMissingZone(name, stdOfs, dstSave, abbr);
    }
    this.tz = tz;
  }

  @override
  void saveToFile(T3VM vm, T3File fp) {}

  @override
  void restoreFromFile(T3VM vm, int self, T3File fp, T3ObjFixup fixups) {}

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
    return tz?.name;
  }
}

// ----------------------------------------------------------------------------
// TimeZone Metaclass
// ----------------------------------------------------------------------------

class T3MetaclassTimeZone extends T3Metaclass {
  static final T3MetaclassTimeZone instance = T3MetaclassTimeZone._();
  T3MetaclassTimeZone._();

  /// Global TZ cache (singleton for convenience, but could be on T3Globals)
  static final T3TimeZoneCache tzCache = T3TimeZoneCache();

  @override
  String getMetaName() => 'timezone/030000';

  @override
  int createFromStack(T3VM vm, Uint8List pc, int pcOffset, int argc) {
    if (argc < 1) throw T3VmException(vmErrWrongNumOfArgs);

    final arg = vm.stack.popVal();
    T3TimeZone? tz;

    if (arg.type == T3DataType.sstring) {
      final name = (vm as T3Globals).constPool!.getString(arg.getAsSstring()!);
      tz = vm.tzCache.getZone(name);
    } else if (arg.type == T3DataType.int32) {
      tz = T3TimeZone.fromGmtOffset(arg.getAsInt());
    }

    final obj = T3ObjTimeZone.withZone(tz);
    final id = vm.objTable.allocObj(vm, false);
    vm.objTable.getEntry(id)!.obj = obj;
    return id;
  }

  @override
  void createForImageLoad(T3VM vm, int id) {
    vm.objTable.getEntry(id)!.obj = T3ObjTimeZone();
  }

  @override
  void createForRestore(T3VM vm, int id) {
    vm.objTable.getEntry(id)!.obj = T3ObjTimeZone();
  }

  @override
  bool callStatProp(T3VM vm, T3Value result, Uint8List pc, int pcOffset, int argc, int prop) {
    return false;
  }

  @override
  int getSupermeta(T3VM vm, int idx) => invalidObjectId;

  @override
  bool isMetaInstanceOf(T3VM vm, int obj) {
    final o = vm.objTable.getObj(obj);
    return o is T3ObjTimeZone;
  }

  @override
  T3Metaclass? getSupermetaReg() => null;

  @override
  int getClassObj(T3VM vm) {
    return vm.metaTable?.getClassObj(getRegIdx()) ?? invalidObjectId;
  }
}
