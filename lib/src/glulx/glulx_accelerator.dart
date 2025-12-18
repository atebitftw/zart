import 'dart:typed_data';

import 'interpreter.dart';

/// Function signature for accelerated routines.
/// Returns the result of the function, or null if the function declined to handle it (unlikely).
/// Throws GlulxException on error.
typedef AcceleratedFunction = int Function(List<int> args);

/// Handles Glulx function acceleration (opcodes 0x164 accelfunc / 0x165 accelparam).
class GlulxAccelerator {
  final GlulxInterpreter interpreter;

  /// The parameter table (9 values, indexed 0-8).
  final List<int> params = List.filled(9, 0);

  /// Map of Address -> Function ID.
  final Map<int, int> _addressToFuncId = {};

  GlulxAccelerator(this.interpreter);

  /// Stores a parameter value.
  void setParam(int index, int value) {
    if (index >= 0 && index < params.length) {
      params[index] = value;
    }
  }

  /// Registers an accelerated function at a given address.
  /// If [funcId] is 0, removes acceleration for [address].
  void setFunction(int funcId, int address) {
    if (funcId == 0) {
      _addressToFuncId.remove(address);
    } else {
      _addressToFuncId[address] = funcId;
    }
  }

  /// Checks if an address is accelerated. returns funcId or 0.
  int getFunctionId(int address) {
    return _addressToFuncId[address] ?? 0;
  }

  /// Executes the accelerated function [funcId].
  /// [args] are the arguments passed to the function.
  /// Executes the accelerated function [funcId].
  /// [args] are the arguments passed to the function.
  /// Returns result or null if not handled (fallback to VM).
  int? execute(int funcId, List<int> args) {
    switch (funcId) {
      case 1:
        return _zRegion(args);
      case 2:
      case 8:
        return _cpTab(args);
      case 3:
      case 9:
        return _raPr(args);
      case 4:
      case 10:
        return _rlPr(args);
      case 5:
      case 11:
        return _ocCl(args);
      case 7:
      case 13:
        return _opPr(args);
      // Complex functions fallback to VM for now
      case 6: // RV__Pr
      case 12:
        return _rvPr(args);
      default:
        return null;
    }
  }

  // --- Parameter Constants ---
  int get _classesTable => params[0];
  int get _indivPropStart => params[1];
  int get _classMetaclass => params[2];
  int get _objectMetaclass => params[3];
  int get _routineMetaclass => params[4];
  int get _stringMetaclass => params[5];
  int get _self => params[6];
  int get _numAttrBytes => params[7];
  int get _cpvStart => params[8];

  // --- Implementation Stubs ---

  int _zRegion(List<int> args) {
    // Func 1: Z__Region(addr)
    if (args.isEmpty) return 0;
    final addr = args[0];
    if (addr < 36) return 0;

    // Check against memory size
    if (addr >= interpreter.memory.lengthInBytes) return 0;

    final tb = interpreter.memRead8(addr);
    if (tb >= 0xE0) return 3; // Routine
    if (tb >= 0xC0) return 2; // String

    if (tb >= 0x70 && tb <= 0x7F) {
      // Object check: Valid if type byte is 70-7F.
      return 1;
    }
    return 0;
  }

  int _cpTab(List<int> args) {
    // Func 2/8: CP__Tab(obj, id)
    if (args.length < 2) return 0;
    final obj = args[0];
    final id = args[1];

    if (_zRegion([obj]) != 1) {
      // Not an object or invalid address
      return 0;
    }

    // otab = obj-->(3+(PARAM_7_num_attr_bytes/4));
    final offset = 3 + (_numAttrBytes ~/ 4);
    final otabAddr = obj + offset * 4;
    int otab = interpreter.memRead32(otabAddr);

    if (otab == 0) return 0;

    final max = interpreter.memRead32(otab);
    otab += 4;

    // binarysearch id 2 otab 10 max 0 0 res
    return interpreter.binarySearch(id, 2, otab, 10, max, 0, 0);
  }

  int? _raPr(List<int> args) {
    // Func 3/9: RA__Pr(obj, id)
    final prop = _cpTab(args);
    if (prop == 0) return 0;
    return interpreter.memRead32(prop + 4);
  }

  int? _rlPr(List<int> args) {
    // Func 4/10: RL__Pr(obj, id)
    final prop = _cpTab(args);
    if (prop == 0) return 0;
    // I6: if (prop-->2 & 1) return (prop-->2) & $FFFF; return 4;
    final val = interpreter.memRead32(prop + 8);
    if ((val & 1) != 0) return val & 0xFFFF;
    return 4;
  }

  int? _ocCl(List<int> args) {
    // Func 5/11: OC__Cl(obj)
    if (args.isEmpty) return 0;
    final obj = args[0];
    // return obj-->3;
    return interpreter.memRead32(obj + 12);
  }

  int? _opPr(List<int> args) {
    // Func 7/13: OP__Pr(obj, id)
    final ra = _raPr(args);
    return (ra != 0 && ra != null) ? 1 : 0;
  }

  int? _rvPr(List<int> args) {
    // Func 6/12: RV__Pr(obj, id)
    if (args.length < 2) return 0;
    // obj is used in _cpTab(args), but looking at args[0] here for readability
    // final obj = args[0];
    final id = args[1];

    final addr = _cpTab(args);
    if (addr != 0) {
      return interpreter.memRead32(addr + 4);
    }

    // Default property value
    // return CPV__Start-->id;
    if (_cpvStart == 0) return 0; // Should not happen in valid game
    return interpreter.memRead32(_cpvStart + id * 4);
  }
}
