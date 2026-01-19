import 'dart:typed_data';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';
import 'package:zart/src/tads3/vm/t3_error.dart';
import 'package:zart/src/tads3/vm/t3_list.dart';

/// Base Iterator class.
abstract class T3ObjIter extends T3Object {
  /// Registration object.
  static final T3MetaclassIter metaclassReg = T3MetaclassIter();

  @override
  T3Metaclass getMetaclassReg() => metaclassReg;

  @override
  bool isOfMetaclass(T3Metaclass meta) {
    return meta == metaclassReg || super.isOfMetaclass(meta);
  }

  /// Iterator property indices (from vmiter.cpp)
  static const int propGetNext = 1;
  static const int propIsNextAvail = 2;
  static const int propResetIter = 3;
  static const int propGetCurKey = 4;
  static const int propGetCurVal = 5;

  @override
  bool getProp(T3VM vm, int prop, T3Value val, int self, List<int> sourceObj, int? argc) {
    // Translate the property into a function index via metaclass table
    final funcIdx = vm.metaTable.propToVectorIdx(metaclassReg.getRegIdx(), prop);

    bool handled = false;
    switch (funcIdx) {
      case 1:
        handled = getpGetNext(vm, self, val, argc);
        break;
      case 2:
        handled = getpIsNextAvail(vm, self, val, argc);
        break;
      case 3:
        handled = getpResetIter(vm, self, val, argc);
        break;
      case 4:
        handled = getpGetCurKey(vm, self, val, argc);
        break;
      case 5:
        handled = getpGetCurVal(vm, self, val, argc);
        break;
    }

    if (handled) {
      sourceObj[0] = metaclassReg.getClassObj(vm);
      return true;
    }

    // Base object class has no default properties
    return false;
  }

  bool getpGetNext(T3VM vm, int self, T3Value retval, int? argc);
  bool getpIsNextAvail(T3VM vm, int self, T3Value retval, int? argc);
  bool getpResetIter(T3VM vm, int self, T3Value retval, int? argc);
  bool getpGetCurKey(T3VM vm, int self, T3Value retval, int? argc);
  bool getpGetCurVal(T3VM vm, int self, T3Value retval, int? argc);

  @override
  bool getInvoker(T3VM vm, T3Value? val) => false;

  @override
  bool isNumeric() => false;

  @override
  bool providesProps(T3VM vm) => true;

  @override
  void castToNum(T3VM vm, T3Value val, int self) {
    throw T3VmException(vmErrNoNumConv);
  }

  @override
  int getSuperclassCount(T3VM vm, int self) => 1;

  @override
  int getSupermetaCount(T3VM vm) => 1;

  @override
  void notifyDelete(T3VM vm, bool inRootSet) {}

  @override
  bool isInstanceOf(T3VM vm, int obj) => false;

  @override
  int getSuperclass(T3VM vm, int self, int index) {
    if (index == 0) return metaclassReg.getClassObj(vm);
    return invalidObj;
  }

  @override
  void setProp(T3VM vm, T3Undo? undo, int self, int propId, T3Value val) {
    throw T3VmException(vmErrInvalidSetprop);
  }

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
  ) {
    return false;
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
  void loadFromImage(T3VM vm, int self, Uint8List ptr, int offset, int size) {}

  @override
  void saveToFile(T3VM vm, T3File fp) {}

  @override
  void restoreFromFile(T3VM vm, int self, T3File fp, T3ObjFixup fixups) {}

  @override
  String? castToString(T3VM vm, int self, T3Value newStr) => null;

  @override
  void buildPropList(T3VM vm, int self, T3Value retval) {
    // Iterators typically don't expose properties for introspection
    // Return an empty list (TADS3 default for many intrinsic types)
  }
}

/// Indexed Iterator subclass.
class T3ObjIterIdx extends T3ObjIter {
  /// Registration object.
  static final T3MetaclassIterIdx metaclassRegIdx = T3MetaclassIterIdx();

  @override
  T3Metaclass getMetaclassReg() => metaclassRegIdx;

  @override
  bool isOfMetaclass(T3Metaclass meta) {
    if (meta == metaclassRegIdx) {
      return true;
    }
    return super.isOfMetaclass(meta);
  }

  /// Associated collection (object ID or constant list).
  final T3Value collectionValue;

  /// Next item index.
  int curIndex;

  /// First valid index.
  int firstValid;

  /// Last valid index.
  int lastValid;

  /// Flags.
  int flags = 0;

  static const int flagUndo = 0x0001;

  T3ObjIterIdx(T3Value collectionValue, this.firstValid, this.lastValid)
    : collectionValue = T3Value.copy(collectionValue),
      curIndex = firstValid - 1;

  /// Generate an indexed iterator for a collection.
  static int createForColl(T3VM vm, T3Value coll, int first, int last) {
    final iter = T3ObjIterIdx(coll, first, last);
    return vm.objTable.registerObj(iter, true);
  }

  @override
  bool getpGetNext(T3VM vm, int self, T3Value retval, int? argc) {
    if (argc != null && argc != 0) throw T3VmException(vmErrWrongNumOfArgs);

    final idx = curIndex + 1;
    if (idx > lastValid) throw T3VmException(vmErrOutOfRange);

    _getIndexedVal(vm, idx, retval);
    _setCurIndex(vm, self, idx);
    return true;
  }

  @override
  bool getpIsNextAvail(T3VM vm, int self, T3Value retval, int? argc) {
    if (argc != null && argc != 0) throw T3VmException(vmErrWrongNumOfArgs);
    retval.setLogical(curIndex + 1 <= lastValid);
    return true;
  }

  @override
  bool getpResetIter(T3VM vm, int self, T3Value retval, int? argc) {
    if (argc != null && argc != 0) throw T3VmException(vmErrWrongNumOfArgs);
    _setCurIndex(vm, self, firstValid - 1);
    retval.setNil();
    return true;
  }

  @override
  bool getpGetCurKey(T3VM vm, int self, T3Value retval, int? argc) {
    if (argc != null && argc != 0) throw T3VmException(vmErrWrongNumOfArgs);
    if (curIndex < firstValid || curIndex > lastValid) throw T3VmException(vmErrOutOfRange);
    retval.setInt(curIndex);
    return true;
  }

  @override
  bool getpGetCurVal(T3VM vm, int self, T3Value retval, int? argc) {
    if (argc != null && argc != 0) throw T3VmException(vmErrWrongNumOfArgs);
    if (curIndex < firstValid || curIndex > lastValid) throw T3VmException(vmErrOutOfRange);
    _getIndexedVal(vm, curIndex, retval);
    return true;
  }

  void _getIndexedVal(T3VM vm, int idx, T3Value retval) {
    switch (collectionValue.type) {
      case T3DataType.list:
        // Index constant list
        T3ObjList.indexList(vm, retval, collectionValue.getAsOfs()!, idx);
        break;
      case T3DataType.obj:
        // Index object
        final objId = collectionValue.getAsObj()!;
        final obj = vm.objTable.getObj(objId);
        if (obj == null) throw T3VmException(vmErrInvalObjType);
        obj.indexValQ(vm, retval, objId, T3Value(T3DataType.int32)..setInt(idx));
        break;
      default:
        throw T3VmException(vmErrCannotIndexType);
    }
  }

  void _setCurIndex(T3VM vm, int self, int idx) {
    // Save undo if necessary (omitted for now as undo is not fully implemented)
    curIndex = idx;
  }

  @override
  void markRefs(T3VM vm, int state) {
    if (collectionValue.type == T3DataType.obj) {
      vm.objTable.markRefs(collectionValue.getAsObj()!, state);
    }
  }

  @override
  void applyUndo(T3VM vm, T3UndoRecord rec) {
    // Integer key in undo record is the saved index
    // Note: rec.id.intval might need to be accessed differently depending on T3UndoRecord implementation
    // For now, assuming it has a way to store the index.
  }

  @override
  void loadFromImage(T3VM vm, int self, Uint8List ptr, int offset, int size) {
    if (size < 26) throw T3VmException(vmErrInvalMetaclassData);

    collectionValue.readFromBuffer(ptr, offset);

    final view = ByteData.sublistView(ptr, offset + 10, offset + 26);
    curIndex = view.getInt32(0, Endian.little);
    firstValid = view.getInt32(4, Endian.little);
    lastValid = view.getInt32(8, Endian.little);
    flags = view.getUint32(12, Endian.little);
  }
}

/// Metaclass registration for Iterator.
class T3MetaclassIter extends T3Metaclass {
  @override
  String getMetaName() => 'iterator/030001';

  @override
  void createForImageLoad(T3VM vm, int id) {
    throw T3VmException(vmErrBadStaticNew);
  }

  @override
  void createForRestore(T3VM vm, int id) {
    throw T3VmException(vmErrBadStaticNew);
  }

  @override
  int createFromStack(T3VM vm, Uint8List pc, int pcOffset, int argc) {
    throw T3VmException(vmErrBadDynamicNew);
  }

  @override
  T3Metaclass? getSupermetaReg() => null;

  @override
  bool callStatProp(T3VM vm, T3Value result, Uint8List pc, int pcOffset, int argc, int prop) {
    return false;
  }

  @override
  int getClassObj(T3VM vm) => invalidObj;

  @override
  int getSupermetaCount(T3VM vm) => 1;

  @override
  int getSupermeta(T3VM vm, int idx) {
    if (idx == 0) return T3MetaclassRoot().getClassObj(vm);
    return invalidObj;
  }

  @override
  bool isMetaInstanceOf(T3VM vm, int obj) => false;
}

/// Metaclass registration for Indexed Iterator.
class T3MetaclassIterIdx extends T3Metaclass {
  @override
  String getMetaName() => 'indexed-iterator/030000';

  @override
  void createForImageLoad(T3VM vm, int id) {
    vm.objTable.registerObj(id, T3ObjIterIdx(T3Value(T3DataType.nil), 0, 0));
  }

  @override
  void createForRestore(T3VM vm, int id) {
    vm.objTable.registerObj(id, T3ObjIterIdx(T3Value(T3DataType.nil), 0, 0));
  }

  @override
  int createFromStack(T3VM vm, Uint8List pc, int pcOffset, int argc) {
    throw T3VmException(vmErrBadDynamicNew);
  }

  @override
  T3Metaclass? getSupermetaReg() => T3ObjIter.metaclassReg;

  @override
  bool callStatProp(T3VM vm, T3Value result, Uint8List pc, int pcOffset, int argc, int prop) {
    return false;
  }

  @override
  int getClassObj(T3VM vm) => invalidObj;

  @override
  int getSupermetaCount(T3VM vm) => 1;

  @override
  int getSupermeta(T3VM vm, int idx) {
    if (idx == 0) return T3ObjIter.metaclassReg.getClassObj(vm);
    return invalidObj;
  }

  @override
  bool isMetaInstanceOf(T3VM vm, int obj) => false;
}
