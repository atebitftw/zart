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
    null, // 21: get_func_params
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

  // ==================== t3vm ====================
  static final List<T3BuiltinFunc?> _t3vmFunctions = [
    null, // 0: run_gc
    null, // 1: set_say
    _getVmVsn, // 2
    null, // 3: get_vm_id
    null, // 4: get_vm_banner
    null, // 5: get_vm_preinit_mode
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

  // ==================== tads-io ====================
  static final List<T3BuiltinFunc?> _tadsIoFunctions = [
    _say, // 0
  ];

  static void _say(T3Interpreter interp, int argc) {
    if (argc < 1) return;
    final val = interp.stack.pop();
    if (argc > 1) interp.stack.discard(argc - 1);

    // TODO: Connect to actual I/O system
    if (val.type == T3DataType.sstring) {
      // Check if it's a dynamic string first (from concatenation)
      String text;
      if (interp.dynamicStrings.containsKey(val.value)) {
        text = interp.dynamicStrings[val.value]!;
      } else {
        text = interp.constantPool!.readString(val.value);
      }
      print('TADS-SAY: $text');
    } else if (val.type == T3DataType.dstring) {
      // dstring is already handled by opcodes usually, but if called as bif...
      final text = interp.codePool!.readString(val.value);
      print('TADS-SAY (d): $text');
    } else {
      print('TADS-SAY: $val');
    }

    interp.registers.r0 = T3Value.nil();
  }
}
