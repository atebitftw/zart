import 'package:zart/src/tads3/vm/t3_interpreter.dart';
import 'package:zart/src/tads3/vm/t3_builtin_core.dart';
import 'package:zart/src/tads3/vm/t3_builtin_obj.dart';
import 'package:zart/src/tads3/vm/t3_builtin_vm.dart';
import 'package:zart/src/tads3/vm/t3_builtin_time.dart';
import 'package:zart/src/tads3/vm/t3_builtin_state.dart';
import 'package:zart/src/tads3/vm/t3_builtin_io.dart';
import 'package:zart/src/tads3/vm/t3_builtin_regex.dart';

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
  // Reference: packages/tads-runner/tads3/vmbiftad.h (30 functions)
  static final List<T3BuiltinFunc?> _tadsGenFunctions = [
    T3BuiltinObj.datatype, // 0
    T3BuiltinObj.getarg, // 1
    T3BuiltinObj.firstObj, // 2
    T3BuiltinObj.nextObj, // 3
    T3BuiltinCore.randomize, // 4
    T3BuiltinCore.rand, // 5
    T3BuiltinCore.toString_, // 6
    T3BuiltinCore.toInteger, // 7
    T3BuiltinTime.gettime, // 8
    T3BuiltinRegex.reMatch, // 9
    T3BuiltinRegex.reSearch, // 10
    T3BuiltinRegex.reGroup, // 11
    T3BuiltinRegex.reReplace, // 12
    T3BuiltinState.savepoint, // 13
    T3BuiltinState.undo, // 14
    T3BuiltinState.saveGame, // 15
    T3BuiltinState.restoreGame, // 16
    T3BuiltinState.restart, // 17
    T3BuiltinCore.max, // 18
    T3BuiltinCore.min, // 19
    T3BuiltinCore.makeString, // 20
    T3BuiltinObj.getFuncParams, // 21
    null, // 22: (reserved)
    T3BuiltinCore.toNumber, // 23
    T3BuiltinCore.sprintf, // 24
    T3BuiltinCore.makeList, // 25
    T3BuiltinCore.abs, // 26
    T3BuiltinCore.sgn, // 27
    T3BuiltinCore.concat, // 28
    T3BuiltinRegex.reSearchBack, // 29
  ];

  // ==================== t3vm ====================
  // Reference: packages/tads-runner/tads3/vmbift3.h (12 functions)
  static final List<T3BuiltinFunc?> _t3vmFunctions = [
    T3BuiltinVm.runGC, // 0
    T3BuiltinVm.setSay, // 1
    T3BuiltinVm.getVmVsn, // 2
    T3BuiltinVm.getVmId, // 3
    T3BuiltinVm.getVmBanner, // 4
    T3BuiltinVm.getVmPreinitMode, // 5
    T3BuiltinVm.debugTrace, // 6
    T3BuiltinVm.getGlobalSymbols, // 7
    T3BuiltinVm.allocProp, // 8
    T3BuiltinVm.getStackTrace, // 9
    T3BuiltinVm.getNamedArg, // 10
    T3BuiltinVm.getNamedArgList, // 11
  ];

  // ==================== tads-io ====================
  static final List<T3BuiltinFunc?> _tadsIoFunctions = [
    T3BuiltinIO.inputLine, // 0
    T3BuiltinIO.inputKey, // 1
    T3BuiltinIO.inputEvent, // 2
    T3BuiltinIO.inputTimeout, // 3
    T3BuiltinIO.tadsSay, // 4
    T3BuiltinIO.flushOutput, // 5
    T3BuiltinIO.morePrompt, // 6
    T3BuiltinIO.statusMode, // 7
    T3BuiltinIO.statusRight, // 8
    T3BuiltinIO.bannerCreate, // 9
    T3BuiltinIO.bannerDelete, // 10
    T3BuiltinIO.bannerSay, // 11
    T3BuiltinIO.bannerSizeTo, // 12
    T3BuiltinIO.bannerSetSize, // 13
    T3BuiltinIO.setLogFile, // 14
    T3BuiltinIO.setScriptFile, // 15
    T3BuiltinIO.systemInfo, // 16
    T3BuiltinIO.getLocalCharSet, // 17
  ];
}
