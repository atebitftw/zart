import 'dart:io';
import 'package:zart/src/loaders/tads/t3_exception.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';
import 'package:zart/src/tads3/vm/t3_interpreter.dart';

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
    null, // 2: firstobj
    null, // 3: nextobj
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
    null, // 15: save
    null, // 16: restore
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

    // ignore: avoid_print
    stdout.write('[more]');
    stdin.readLineSync();

    interp.registers.r0 = T3Value.nil();
  }
}
