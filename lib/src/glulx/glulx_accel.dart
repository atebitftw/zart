import 'package:zart/src/glulx/glulx_exception.dart';
import 'package:zart/src/glulx/glulx_memory_map.dart';

/// Glulx function acceleration system.
///
/// Spec: "To improve performance, Glulx incorporates some complex functions
/// which replicate code in the Inform library."
///
/// The acceleration system allows the interpreter to replace calls to
/// specific function addresses with native implementations of the same
/// functionality, providing significant performance improvements.
class GlulxAccel {
  /// The memory map.
  final GlulxMemoryMap memoryMap;

  /// The 9 acceleration parameters (indices 0-8).
  final List<int> _params = List.filled(9, 0);

  /// Hash map of address -> (index, function).
  final Map<int, _AccelEntry> _accelFuncs = {};

  /// Current I/O system mode for error output.
  int Function() getIosysMode;

  /// Stream character output for error messages.
  void Function(int char) streamChar;

  /// Constructor.
  GlulxAccel({
    required this.memoryMap,
    required this.getIosysMode,
    required this.streamChar,
  });

  /// Set a parameter value.
  ///
  /// Spec: "accelparam L1 L2: Store the value L2 in the parameter table
  /// at position L1. If the terp does not know about parameter L1,
  /// this does nothing."
  void setParam(int index, int value) {
    if (index >= 0 && index < 9) {
      _params[index] = value;
    }
  }

  /// Get a parameter value (used by accelerated functions).
  int getParam(int index) {
    if (index >= 0 && index < 9) {
      return _params[index];
    }
    return 0;
  }

  /// Register/unregister an accelerated function at an address.
  ///
  /// Spec: "accelfunc L1 L2: Request that the VM function with address L2
  /// be replaced by the accelerated function whose number is L1.
  /// If L1 is zero, the acceleration for address L2 is cancelled."
  void setFunc(int index, int address) {
    // Check the Glulx type identifier byte.
    final funcType = memoryMap.readByte(address);
    if (funcType != 0xC0 && funcType != 0xC1) {
      throw GlulxException(
        'Attempt to accelerate non-function at address 0x${address.toRadixString(16)}',
      );
    }

    if (index == 0) {
      // Cancel acceleration at this address
      _accelFuncs.remove(address);
      return;
    }

    final func = _findFunc(index);
    if (func == null) {
      // We don't support this function index - silently ignore
      return;
    }

    _accelFuncs[address] = _AccelEntry(index: index, func: func);
  }

  /// Get the accelerated function for an address, or null.
  int Function(List<int> args)? getFunc(int address) {
    return _accelFuncs[address]?.func;
  }

  /// Check if we support a given function index.
  /// Used by gestalt selector 10 (AccelFunc).
  bool supportsFunc(int index) {
    return _findFunc(index) != null;
  }

  /// Find the native implementation for a function index.
  int Function(List<int> args)? _findFunc(int index) {
    switch (index) {
      case 0:
        return null; // 0 always means no acceleration
      case 1:
        return _func1ZRegion;
      case 2:
        return _func2CPTab;
      case 3:
        return _func3RAPr;
      case 4:
        return _func4RLPr;
      case 5:
        return _func5OCCl;
      case 6:
        return _func6RVPr;
      case 7:
        return _func7OPPr;
      case 8:
        return _func8CPTab;
      case 9:
        return _func9RAPr;
      case 10:
        return _func10RLPr;
      case 11:
        return _func11OCCl;
      case 12:
        return _func12RVPr;
      case 13:
        return _func13OPPr;
      default:
        return null;
    }
  }

  /// Output an error message.
  ///
  /// Spec: "Errors encountered during an accelerated function will be
  /// displayed to the user by some convenient means."
  void _accelError(String msg) {
    // Only output if iosys mode is 2 (Glk)
    if (getIosysMode() == 2) {
      streamChar(0x0A); // newline
      for (final c in msg.codeUnits) {
        streamChar(c);
      }
      streamChar(0x0A); // newline
    }
    // In other modes, error is silently discarded per spec
  }

  /// Utility: Check if an object is "in Class" (contained in the Class metaclass).
  bool _objInClass(int obj) {
    // return (Mem4(obj + 13 + num_attr_bytes) == class_metaclass);
    return memoryMap.readWord(obj + 13 + _params[7]) == _params[2];
  }

  /// Helper to get argument or 0 if not provided.
  int _argIfGiven(List<int> args, int index) {
    return index < args.length ? args[index] : 0;
  }

  // ========== Accelerated Function Implementations ==========

  /// FUNC_1_Z__Region: Determine object type.
  ///
  /// Returns: 1 for object, 2 for function, 3 for string, 0 otherwise.
  int _func1ZRegion(List<int> args) {
    if (args.isEmpty) return 0;

    final addr = args[0];
    if (addr < 36) return 0;
    if (addr >= memoryMap.endMem) return 0;

    final tb = memoryMap.readByte(addr);
    if (tb >= 0xE0) return 3; // String
    if (tb >= 0xC0) return 2; // Function
    if (tb >= 0x70 && tb <= 0x7F && addr >= memoryMap.ramStart) {
      return 1; // Object
    }
    return 0;
  }

  /// FUNC_2_CP__Tab (old): Look up property table entry.
  ///
  /// Note: This is the OLD version that assumes NUM_ATTR_BYTES = 7.
  int _func2CPTab(List<int> args) {
    final obj = _argIfGiven(args, 0);
    final id = _argIfGiven(args, 1);

    if (_func1ZRegion([obj]) != 1) {
      _accelError(
        '[** Programming error: tried to find the "." of (something) **]',
      );
      return 0;
    }

    // otab = Mem4(obj + 16) - fixed offset for old functions
    final otab = memoryMap.readWord(obj + 16);
    if (otab == 0) return 0;

    final max = memoryMap.readWord(otab);
    // @binarysearch id 2 otab+4 10 max 0 0 res
    return _binarySearch(id, 2, otab + 4, 10, max, 0, 0);
  }

  /// FUNC_3_RA__Pr (old): Get property address.
  int _func3RAPr(List<int> args) {
    final obj = _argIfGiven(args, 0);
    final id = _argIfGiven(args, 1);

    final prop = _getProp(obj, id);
    if (prop == 0) return 0;

    return memoryMap.readWord(prop + 4);
  }

  /// FUNC_4_RL__Pr (old): Get property length.
  int _func4RLPr(List<int> args) {
    final obj = _argIfGiven(args, 0);
    final id = _argIfGiven(args, 1);

    final prop = _getProp(obj, id);
    if (prop == 0) return 0;

    return 4 * memoryMap.readShort(prop + 2);
  }

  /// FUNC_5_OC__Cl (old): Object-of-class test.
  int _func5OCCl(List<int> args) {
    final obj = _argIfGiven(args, 0);
    final cla = _argIfGiven(args, 1);

    final zr = _func1ZRegion([obj]);
    if (zr == 3) return (cla == _params[5]) ? 1 : 0; // string_metaclass
    if (zr == 2) return (cla == _params[4]) ? 1 : 0; // routine_metaclass
    if (zr != 1) return 0;

    if (cla == _params[2]) {
      // class_metaclass
      if (_objInClass(obj)) return 1;
      if (obj == _params[2] ||
          obj == _params[5] ||
          obj == _params[4] ||
          obj == _params[3]) {
        return 1;
      }
      return 0;
    }
    if (cla == _params[3]) {
      // object_metaclass
      if (_objInClass(obj)) return 0;
      if (obj == _params[2] ||
          obj == _params[5] ||
          obj == _params[4] ||
          obj == _params[3]) {
        return 0;
      }
      return 1;
    }
    if (cla == _params[5] || cla == _params[4]) return 0;

    if (!_objInClass(cla)) {
      _accelError(
        "[** Programming error: tried to apply 'ofclass' with non-class **]",
      );
      return 0;
    }

    final prop = _getProp(obj, 2);
    if (prop == 0) return 0;

    final inlist = memoryMap.readWord(prop + 4);
    if (inlist == 0) return 0;

    final inlistlen = memoryMap.readShort(prop + 2);
    for (var jx = 0; jx < inlistlen; jx++) {
      if (memoryMap.readWord(inlist + (4 * jx)) == cla) return 1;
    }
    return 0;
  }

  /// FUNC_6_RV__Pr (old): Read property value.
  int _func6RVPr(List<int> args) {
    final id = _argIfGiven(args, 1);
    final addr = _func3RAPr(args);

    if (addr == 0) {
      if (id > 0 && id < _params[1]) {
        // indiv_prop_start
        return memoryMap.readWord(_params[8] + (4 * id)); // cpv__start
      }
      _accelError('[** Programming error: tried to read (something) **]');
      return 0;
    }

    return memoryMap.readWord(addr);
  }

  /// FUNC_7_OP__Pr (old): Object provides property test.
  int _func7OPPr(List<int> args) {
    final obj = _argIfGiven(args, 0);
    final id = _argIfGiven(args, 1);

    final zr = _func1ZRegion([obj]);
    if (zr == 3) {
      // print is INDIV_PROP_START+6
      if (id == _params[1] + 6) return 1;
      // print_to_array is INDIV_PROP_START+7
      if (id == _params[1] + 7) return 1;
      return 0;
    }
    if (zr == 2) {
      // call is INDIV_PROP_START+5
      return (id == _params[1] + 5) ? 1 : 0;
    }
    if (zr != 1) return 0;

    if (id >= _params[1] && id < _params[1] + 8) {
      if (_objInClass(obj)) return 1;
    }

    return (_func3RAPr(args) != 0) ? 1 : 0;
  }

  // ========== NEW versions (8-13) with NUM_ATTR_BYTES support ==========

  /// FUNC_8_CP__Tab (new): Look up property table entry.
  int _func8CPTab(List<int> args) {
    final obj = _argIfGiven(args, 0);
    final id = _argIfGiven(args, 1);

    if (_func1ZRegion([obj]) != 1) {
      _accelError(
        '[** Programming error: tried to find the "." of (something) **]',
      );
      return 0;
    }

    // otab = Mem4(obj + 4*(3+(num_attr_bytes/4)))
    // This uses the actual NUM_ATTR_BYTES value
    final otab = memoryMap.readWord(obj + 4 * (3 + (_params[7] ~/ 4)));
    if (otab == 0) return 0;

    final max = memoryMap.readWord(otab);
    return _binarySearch(id, 2, otab + 4, 10, max, 0, 0);
  }

  /// FUNC_9_RA__Pr (new): Get property address.
  int _func9RAPr(List<int> args) {
    final obj = _argIfGiven(args, 0);
    final id = _argIfGiven(args, 1);

    final prop = _getPropNew(obj, id);
    if (prop == 0) return 0;

    return memoryMap.readWord(prop + 4);
  }

  /// FUNC_10_RL__Pr (new): Get property length.
  int _func10RLPr(List<int> args) {
    final obj = _argIfGiven(args, 0);
    final id = _argIfGiven(args, 1);

    final prop = _getPropNew(obj, id);
    if (prop == 0) return 0;

    return 4 * memoryMap.readShort(prop + 2);
  }

  /// FUNC_11_OC__Cl (new): Object-of-class test.
  int _func11OCCl(List<int> args) {
    final obj = _argIfGiven(args, 0);
    final cla = _argIfGiven(args, 1);

    final zr = _func1ZRegion([obj]);
    if (zr == 3) return (cla == _params[5]) ? 1 : 0;
    if (zr == 2) return (cla == _params[4]) ? 1 : 0;
    if (zr != 1) return 0;

    if (cla == _params[2]) {
      if (_objInClass(obj)) return 1;
      if (obj == _params[2] ||
          obj == _params[5] ||
          obj == _params[4] ||
          obj == _params[3]) {
        return 1;
      }
      return 0;
    }
    if (cla == _params[3]) {
      if (_objInClass(obj)) return 0;
      if (obj == _params[2] ||
          obj == _params[5] ||
          obj == _params[4] ||
          obj == _params[3]) {
        return 0;
      }
      return 1;
    }
    if (cla == _params[5] || cla == _params[4]) return 0;

    if (!_objInClass(cla)) {
      _accelError(
        "[** Programming error: tried to apply 'ofclass' with non-class **]",
      );
      return 0;
    }

    final prop = _getPropNew(obj, 2);
    if (prop == 0) return 0;

    final inlist = memoryMap.readWord(prop + 4);
    if (inlist == 0) return 0;

    final inlistlen = memoryMap.readShort(prop + 2);
    for (var jx = 0; jx < inlistlen; jx++) {
      if (memoryMap.readWord(inlist + (4 * jx)) == cla) return 1;
    }
    return 0;
  }

  /// FUNC_12_RV__Pr (new): Read property value.
  int _func12RVPr(List<int> args) {
    final id = _argIfGiven(args, 1);
    final addr = _func9RAPr(args);

    if (addr == 0) {
      if (id > 0 && id < _params[1]) {
        return memoryMap.readWord(_params[8] + (4 * id));
      }
      _accelError('[** Programming error: tried to read (something) **]');
      return 0;
    }

    return memoryMap.readWord(addr);
  }

  /// FUNC_13_OP__Pr (new): Object provides property test.
  int _func13OPPr(List<int> args) {
    final obj = _argIfGiven(args, 0);
    final id = _argIfGiven(args, 1);

    final zr = _func1ZRegion([obj]);
    if (zr == 3) {
      if (id == _params[1] + 6) return 1;
      if (id == _params[1] + 7) return 1;
      return 0;
    }
    if (zr == 2) {
      return (id == _params[1] + 5) ? 1 : 0;
    }
    if (zr != 1) return 0;

    if (id >= _params[1] && id < _params[1] + 8) {
      if (_objInClass(obj)) return 1;
    }

    return (_func9RAPr(args) != 0) ? 1 : 0;
  }

  // ========== Helper functions ==========

  /// Look up a property entry (OLD version).
  int _getProp(int obj, int id) {
    var cla = 0;
    int prop;

    if ((id & 0xFFFF0000) != 0) {
      cla = memoryMap.readWord(_params[0] + ((id & 0xFFFF) * 4));
      if (_func5OCCl([obj, cla]) == 0) return 0;
      id = id >> 16;
      obj = cla;
    }

    prop = _func2CPTab([obj, id]);
    if (prop == 0) return 0;

    if (_objInClass(obj) && cla == 0) {
      if (id < _params[1] || id >= _params[1] + 8) return 0;
    }

    if (memoryMap.readWord(_params[6]) != obj) {
      if ((memoryMap.readByte(prop + 9) & 1) != 0) return 0;
    }
    return prop;
  }

  /// Look up a property entry (NEW version).
  int _getPropNew(int obj, int id) {
    var cla = 0;
    int prop;

    if ((id & 0xFFFF0000) != 0) {
      cla = memoryMap.readWord(_params[0] + ((id & 0xFFFF) * 4));
      if (_func11OCCl([obj, cla]) == 0) return 0;
      id = id >> 16;
      obj = cla;
    }

    prop = _func8CPTab([obj, id]);
    if (prop == 0) return 0;

    if (_objInClass(obj) && cla == 0) {
      if (id < _params[1] || id >= _params[1] + 8) return 0;
    }

    if (memoryMap.readWord(_params[6]) != obj) {
      if ((memoryMap.readByte(prop + 9) & 1) != 0) return 0;
    }
    return prop;
  }

  /// Binary search implementation.
  ///
  /// This is a simplified version matching the Glulx binarysearch opcode.
  int _binarySearch(
    int key,
    int keySize,
    int start,
    int structSize,
    int numStructs,
    int keyOffset,
    int options,
  ) {
    if (numStructs == 0) return 0;

    var low = 0;
    var high = numStructs;

    while (low < high) {
      final mid = (low + high) ~/ 2;
      final addr = start + (mid * structSize) + keyOffset;

      // Read key from structure (big-endian)
      int structKey;
      if (keySize == 1) {
        structKey = memoryMap.readByte(addr);
      } else if (keySize == 2) {
        structKey = memoryMap.readShort(addr);
      } else {
        structKey = memoryMap.readWord(addr);
      }

      if (key == structKey) {
        // Found - return address of structure (or index if options & 1)
        if ((options & 1) != 0) {
          return mid;
        }
        return start + (mid * structSize);
      } else if (key < structKey) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }

    return 0; // Not found
  }

  /// Clear all acceleration state (for restart).
  void reset() {
    _params.fillRange(0, _params.length, 0);
    _accelFuncs.clear();
  }
}

/// Entry in the acceleration function table.
class _AccelEntry {
  final int index;
  final int Function(List<int> args) func;

  _AccelEntry({required this.index, required this.func});
}
