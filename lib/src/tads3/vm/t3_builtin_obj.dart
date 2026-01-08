import 'package:zart/src/loaders/tads/t3_exception.dart';
import 'package:zart/src/tads3/vm/t3_interpreter.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_object_table.dart';

/// Object utility built-in functions for TADS 3.
/// Includes: datatype, getarg, firstobj, nextobj, getFuncParams
class T3BuiltinObj {
  /// datatype(val) - Get the datatype code of a value.
  /// Ref: vmbiftad.cpp line 129
  static void datatype(T3Interpreter interp, int argc) {
    if (argc < 1) throw T3Exception('datatype() requires 1 argument');
    final val = interp.stack.pop();
    if (argc > 1) interp.stack.discard(argc - 1);

    interp.registers.r0 = T3Value.fromInt(val.type.code);
  }

  /// getarg(n) - Get nth argument to current function (1-based).
  /// Ref: vmbiftad.cpp line 149
  static void getarg(T3Interpreter interp, int argc) {
    if (argc < 1) throw T3Exception('getarg() requires 1 argument');
    final idxVal = interp.stack.pop();
    if (argc > 1) interp.stack.discard(argc - 1);

    final idx = idxVal.numToInt();
    final actualArgCount = interp.stack.getArgCount();

    if (idx < 1 || idx > actualArgCount) {
      interp.registers.r0 = T3Value.nil();
      return;
    }

    // TADS indices are 1-based
    interp.registers.r0 = interp.stack.getArg(idx - 1);
  }

  /// getFuncParams(func) - Get function parameter info.
  /// Returns [minArgs, optionalArgs, isVarargs]
  static void getFuncParams(T3Interpreter interp, int argc) {
    if (argc < 1) throw T3Exception('get_func_params() requires 1 argument');
    final funcVal = interp.stack.pop();
    if (argc > 1) interp.stack.discard(argc - 1);

    if (funcVal.type != T3DataType.funcptr &&
        funcVal.type != T3DataType.codeofs) {
      throw T3Exception('get_func_params: function pointer required');
    }

    // Read header from code pool
    final pool = interp.codePool;
    final header = pool != null
        ? pool.readMethodHeader(funcVal.value, interp.methodHeaderSize)
        : null;

    // Create return list: [minArgs, optionalArgs, isVarargs]
    final list = [
      T3Value.fromInt(header?.minArgs ?? 0),
      T3Value.fromInt(header?.optionalArgs ?? 0),
      (header?.isVarargs ?? false) ? T3Value.true_() : T3Value.nil(),
    ];

    final offset = interp.addDynamicList(list);
    interp.registers.r0 = T3Value.fromList(offset);
  }

  /// firstobj(cls?, flags?) - Get first object in memory.
  static void firstObj(T3Interpreter interp, int argc) {
    T3Value clsVal = T3Value.nil();
    int flags = 0x0003; // ObjAll

    if (argc >= 1) clsVal = interp.stack.pop();
    if (argc >= 2) {
      final fv = interp.stack.pop();
      if (fv.isInt) flags = fv.value;
    }
    if (argc > 2) interp.stack.discard(argc - 2);

    final table = interp.objectTable;
    for (final obj in table.all) {
      if (_matchesObjFilter(obj, clsVal, flags, table, interp)) {
        interp.registers.r0 = T3Value.fromObject(obj.objectId);
        return;
      }
    }
    interp.registers.r0 = T3Value.nil();
  }

  /// nextobj(obj, cls?, flags?) - Get next object after given one.
  static void nextObj(T3Interpreter interp, int argc) {
    if (argc < 1) throw T3Exception('nextObj() requires at least 1 argument');
    final objVal = interp.stack.pop();
    T3Value clsVal = T3Value.nil();
    int flags = 0x0003;

    if (argc >= 2) clsVal = interp.stack.pop();
    if (argc >= 3) {
      final fv = interp.stack.pop();
      if (fv.isInt) flags = fv.value;
    }
    if (argc > 3) interp.stack.discard(argc - 3);

    final currentId = objVal.value;
    final table = interp.objectTable;
    bool foundCurrent = false;

    for (final obj in table.all) {
      if (foundCurrent &&
          _matchesObjFilter(obj, clsVal, flags, table, interp)) {
        interp.registers.r0 = T3Value.fromObject(obj.objectId);
        return;
      }
      if (obj.objectId == currentId) foundCurrent = true;
    }
    interp.registers.r0 = T3Value.nil();
  }

  static bool _matchesObjFilter(
    T3Object obj,
    T3Value cls,
    int flags,
    T3ObjectTable table,
    T3Interpreter interp,
  ) {
    if (obj is! T3TadsObject) return false;
    final isClass = obj.isClass;
    if (isClass && (flags & 0x0002) == 0) return false;
    if (!isClass && (flags & 0x0001) == 0) return false;

    if (!cls.isNil) {
      if (cls.isStringLike) {
        final meta = interp.getStringValue(cls);
        if (obj.metaclass != meta) return false;
      } else if (cls.isObject) {
        if (!_isInstanceOf(obj, cls.value, table)) return false;
      }
    }
    return true;
  }

  /// Check if object is an instance of (or inherits from) the given class.
  static bool _isInstanceOf(T3TadsObject obj, int cls, T3ObjectTable table) {
    final visited = <int>{};
    final queue = <int>[...obj.superclasses];

    while (queue.isNotEmpty) {
      final scId = queue.removeAt(0);
      if (visited.contains(scId)) continue;
      visited.add(scId);

      if (scId == cls) return true;

      final scObj = table.lookup(scId);
      if (scObj is T3TadsObject) {
        queue.addAll(scObj.superclasses.where((id) => !visited.contains(id)));
      }
    }

    return false;
  }
}
