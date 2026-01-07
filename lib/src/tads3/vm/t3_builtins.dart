import 'dart:io';
import 'package:zart/src/loaders/tads/t3_exception.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';
import 'package:zart/src/tads3/vm/t3_interpreter.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_object_table.dart';

/// Prototype for a T3 built-in function.
typedef T3BuiltinFunc = void Function(T3Interpreter interpreter, int argc);

/// Registry for T3 built-in function sets.
class T3BuiltinRegistry {
  static final Map<String, List<T3BuiltinFunc?>> _functionSets = {
    'tads-gen': _tadsGenFunctions,
    't3vm': _t3vmFunctions,
    'tads-io': _tadsIoFunctions,
  };

  /// Gets a function implementation from a set by index.
  static T3BuiltinFunc? getFunction(String setName, int funcIdx) {
    // Handle versioned names like "tads-gen/030005"
    final baseName = setName.contains('/') ? setName.split('/')[0] : setName;
    final set = _functionSets[baseName];
    if (set == null || funcIdx < 0 || funcIdx >= set.length) return null;
    return set[funcIdx];
  }

  // ==================== tads-gen ====================
  static final List<T3BuiltinFunc?> _tadsGenFunctions = [
    _datatype, // 0
    _getarg, // 1
    _firstObj, // 2
    _nextObj, // 3
    null, // 4: randomize
    null, // 5: rand
    null, // 6: toString
    null, // 7: toInteger
    null, // 8: gettime
    null, // 9: re_match
    null, // 10: re_search
    null, // 11: re_group
    null, // 12: re_replace
    null, // 13: savepoint
    null, // 14: undo
    _saveGame, // 15: save
    _restoreGame, // 16: restore
    null, // 17: restart
    null, // 18: get_max
    null, // 19: get_min
    null, // 20: make_string
    _getFuncParams, // 21
    null, // 22: (unused?)
    null, // 23: toNumber
  ];

  static void _datatype(T3Interpreter interp, int argc) {
    if (argc < 1) throw T3Exception('datatype() requires 1 argument');
    final val = interp.stack.pop();
    // Discard any extra args
    if (argc > 1) interp.stack.discard(argc - 1);

    interp.registers.r0 = T3Value.fromInt(val.type.code);
  }

  static void _getarg(T3Interpreter interp, int argc) {
    if (argc < 1) throw T3Exception('getarg() requires 1 argument');
    final idxVal = interp.stack.pop();
    if (argc > 1) interp.stack.discard(argc - 1);

    final idx = idxVal.numToInt();
    final actualArgCount = interp.stack.getArgCount();

    if (idx < 1 || idx > actualArgCount) {
      throw T3Exception('getarg($idx) out of range (argc=$actualArgCount)');
    }

    // TADS indices are 1-based
    interp.registers.r0 = interp.stack.getArg(idx - 1);
  }

  static void _getFuncParams(T3Interpreter interp, int argc) {
    if (argc < 1) throw T3Exception('get_func_params() requires 1 argument');
    final funcVal = interp.stack.pop();
    if (argc > 1) interp.stack.discard(argc - 1);

    if (funcVal.type != T3DataType.funcptr && funcVal.type != T3DataType.codeofs) {
      throw T3Exception('get_func_params: function pointer required');
    }

    // Read header from code pool
    final header = interp.codePool!.readMethodHeader(funcVal.value, interp.methodHeaderSize);

    // Create return list: [minArgs, optionalArgs, isVarargs]
    final list = [
      T3Value.fromInt(header.minArgs),
      T3Value.fromInt(header.optionalArgs),
      header.isVarargs ? T3Value.true_() : T3Value.nil(),
    ];

    final offset = interp.addDynamicList(list);
    interp.registers.r0 = T3Value.fromList(offset);
  }

  /// saveGame(filename) - Save game state to file.
  /// Currently a stub that just returns nil (save not implemented).
  static void _saveGame(T3Interpreter interp, int argc) {
    // Discard all arguments
    if (argc > 0) interp.stack.discard(argc);
    // Return nil to indicate success (actual save not implemented)
    interp.registers.r0 = T3Value.nil();
  }

  /// restoreGame(filename) - Restore game state from file.
  /// Currently a stub that just returns nil (restore not implemented).
  static void _restoreGame(T3Interpreter interp, int argc) {
    // Discard all arguments
    if (argc > 0) interp.stack.discard(argc);
    // Return nil to indicate failure (actual restore not implemented)
    interp.registers.r0 = T3Value.nil();
  }

  /// firstObj(cls?, flags?) - Get first object in memory.
  static void _firstObj(T3Interpreter interp, int argc) {
    // Parse optional arguments
    int? cls;
    int flags = 0x0003; // ObjAll = ObjInstances | ObjClasses

    if (argc >= 1) {
      final clsVal = interp.stack.pop();
      if (!clsVal.isNil) {
        cls = clsVal.value;
      }
    }
    if (argc >= 2) {
      final flagsVal = interp.stack.pop();
      if (flagsVal.isInt) {
        flags = flagsVal.value;
      }
    }
    if (argc > 2) interp.stack.discard(argc - 2);

    // ignore: avoid_print

    // Iterate through objects to find first matching one
    final table = interp.objectTable;
    // ignore: avoid_print

    for (final obj in table.all) {
      if (_matchesObjFilter(obj, cls, flags, table)) {
        // ignore: avoid_print

        interp.registers.r0 = T3Value.fromObject(obj.objectId);
        return;
      }
    }

    // ignore: avoid_print

    // No matching object found
    interp.registers.r0 = T3Value.nil();
  }

  /// nextObj(obj, cls?, flags?) - Get next object after the given one.
  static void _nextObj(T3Interpreter interp, int argc) {
    if (argc < 1) throw T3Exception('nextObj() requires at least 1 argument');

    final objVal = interp.stack.pop();
    int? cls;
    int flags = 0x0003; // ObjAll

    if (argc >= 2) {
      final clsVal = interp.stack.pop();
      if (!clsVal.isNil) {
        cls = clsVal.value;
      }
    }
    if (argc >= 3) {
      final flagsVal = interp.stack.pop();
      if (flagsVal.isInt) {
        flags = flagsVal.value;
      }
    }
    if (argc > 3) interp.stack.discard(argc - 3);

    final currentId = objVal.value;
    final table = interp.objectTable;

    // Find objects after the current one
    bool foundCurrent = false;
    for (final obj in table.all) {
      if (foundCurrent && _matchesObjFilter(obj, cls, flags, table)) {
        interp.registers.r0 = T3Value.fromObject(obj.objectId);
        return;
      }
      if (obj.objectId == currentId) {
        foundCurrent = true;
      }
    }

    // No more matching objects
    interp.registers.r0 = T3Value.nil();
  }

  /// Helper to check if an object matches the filter criteria.
  static bool _matchesObjFilter(T3Object obj, int? cls, int flags, T3ObjectTable table) {
    // Only consider tads-object metaclass objects for firstObj/nextObj
    if (obj is! T3TadsObject) return false;

    // Check flags: 0x0001 = instances, 0x0002 = classes
    final isClass = obj.isClass;
    final includeInstances = (flags & 0x0001) != 0;
    final includeClasses = (flags & 0x0002) != 0;

    if (isClass && !includeClasses) return false;
    if (!isClass && !includeInstances) return false;

    // Check class filter if specified
    if (cls != null) {
      // Object must be an instance of or inherit from the specified class
      if (!_isInstanceOf(obj, cls, table)) return false;
    }

    return true;
  }

  /// Check if object is an instance of (or inherits from) the given class.
  static bool _isInstanceOf(T3TadsObject obj, int cls, T3ObjectTable table) {
    // Check direct superclasses and their inheritance chain
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

  // ==================== t3vm ====================
  static final List<T3BuiltinFunc?> _t3vmFunctions = [
    null, // 0: run_gc
    _setSay, // 1
    _getVmVsn, // 2
    null, // 3: get_vm_id
    null, // 4: get_vm_banner
    _getVmPreinitMode, // 5
    null, // 6: debug_trace
    null, // 7: get_global_symtab
    null, // 8: alloc_new_prop
    null, // 9: get_stack_trace
  ];

  static void _getVmVsn(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    // Return a dummy version for now (3.1.0)
    interp.registers.r0 = T3Value.fromInt(0x030100);
  }

  static void _setSay(T3Interpreter interp, int argc) {
    if (argc < 1) throw T3Exception('set_say() requires 1 argument');
    final val = interp.stack.pop();
    if (argc > 1) interp.stack.discard(argc - 1);

    const setSayNoFunc = 1;
    const setSayNoMethod = 2;

    if (val.type == T3DataType.prop || (val.type == T3DataType.int_ && val.value == setSayNoMethod)) {
      // Return old prop
      final oldProp = interp.sayMethod;
      interp.registers.r0 = oldProp != 0 ? T3Value.fromProp(oldProp) : T3Value.fromInt(setSayNoMethod);

      // Set new prop
      if (val.type == T3DataType.int_) {
        interp.sayMethod = 0;
      } else {
        interp.sayMethod = val.value;
      }
    } else {
      // Return old func
      final oldFunc = interp.sayFunc;
      interp.registers.r0 = !oldFunc.isNil ? oldFunc : T3Value.fromInt(setSayNoFunc);

      // Set new func
      if (val.type == T3DataType.int_ && val.value == setSayNoFunc) {
        interp.sayFunc = T3Value.nil();
      } else {
        interp.sayFunc = val;
      }
    }
  }

  static void _getVmPreinitMode(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    // We are always in normal mode for now
    interp.registers.r0 = T3Value.nil();
  }

  // ==================== tads-io ====================
  static final List<T3BuiltinFunc?> _tadsIoFunctions = [
    _say, // 0
    null, // 1: setLogFile
    null, // 2: clearScreen
    _morePrompt, // 3
  ];

  static void _say(T3Interpreter interp, int argc) {
    if (argc < 1) return;
    final val = interp.stack.pop();
    if (argc > 1) interp.stack.discard(argc - 1);

    final text = interp.getStringValue(val);
    interp.printRaw(text);

    interp.registers.r0 = T3Value.nil();
  }

  static void _morePrompt(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);

    interp.printRaw('[more]');
    stdin.readLineSync();

    interp.registers.r0 = T3Value.nil();
  }
}
