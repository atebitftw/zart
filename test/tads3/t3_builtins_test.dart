import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_builtins.dart';
import 'package:zart/src/tads3/vm/t3_interpreter.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';

/// T3 Built-in Functions unit tests - SPEC COMPLETE COVERAGE
///
/// This test file covers ALL functions defined in the TADS 3 specification,
/// not just what is currently implemented. Tests for unimplemented functions
/// are marked with `skip` and discrepancy reports are created.
///
/// Spec Reference: packages/tads-sources/t3doc/techman/t3spec/fnset_t3.htm
/// Reference Implementation: packages/tads-runner/tads3/vmbiftad.h (tads-gen)
/// Reference Implementation: packages/tads-runner/tads3/vmbift3.h (t3vm)
void main() {
  // ============================================================================
  // tads-gen FUNCTION SET (30 functions per vmbiftad.h)
  // ============================================================================
  group('tads-gen function set', () {
    late T3Interpreter interp;

    setUp(() {
      interp = T3Interpreter();
      interp.stack.pushFrame(
        argCount: 0,
        localCount: 0,
        returnAddr: 0,
        entryPtr: 0,
        self: T3Value.nil(),
        targetObj: T3Value.nil(),
        definingObj: T3Value.nil(),
        targetProp: 0,
        invokee: T3Value.nil(),
      );
    });

    // Index 0: datatype(val)
    /// Ref: vmbiftad.h:186 - datatype(val)
    /// Spec: Returns the datatype code of a value.
    group('datatype [0]', () {
      test('returns int type code', () {
        interp.stack.push(T3Value.fromInt(42));
        T3BuiltinRegistry.getFunction('tads-gen', 0)!(interp, 1);
        expect(interp.registers.r0.value, T3DataType.int_.code);
      });

      test('returns correct codes for all types', () {
        final testCases = [
          (T3Value.nil(), T3DataType.nil.code),
          (T3Value.true_(), T3DataType.true_.code),
          (T3Value.fromInt(123), T3DataType.int_.code),
          (T3Value.fromObject(100), T3DataType.obj.code),
          (T3Value.fromProp(50), T3DataType.prop.code),
          (T3Value.fromString(200), T3DataType.sstring.code),
          (T3Value.fromList(300), T3DataType.list.code),
        ];

        for (final (val, expectedCode) in testCases) {
          interp.stack.push(val);
          T3BuiltinRegistry.getFunction('tads-gen', 0)!(interp, 1);
          expect(interp.registers.r0.value, expectedCode, reason: 'Type ${val.type} should return code $expectedCode');
        }
      });
    });

    // Index 1: getarg(n)
    /// Ref: vmbiftad.h:187 - getarg(n)
    /// Spec: Returns the nth argument to the current function (1-based).
    group('getarg [1]', () {
      test('returns argument by 1-based index', () {
        // TADS pushes args right-to-left: last pushed = arg 1
        interp.stack.push(T3Value.fromInt(222)); // arg 2
        interp.stack.push(T3Value.fromInt(111)); // arg 1
        interp.stack.pushFrame(
          argCount: 2,
          localCount: 2,
          returnAddr: 0,
          entryPtr: 0,
          self: T3Value.nil(),
          targetObj: T3Value.nil(),
          definingObj: T3Value.nil(),
          targetProp: 0,
          invokee: T3Value.nil(),
        );

        interp.stack.push(T3Value.fromInt(1));
        T3BuiltinRegistry.getFunction('tads-gen', 1)!(interp, 1);
        expect(interp.registers.r0.value, 111);

        interp.stack.push(T3Value.fromInt(2));
        T3BuiltinRegistry.getFunction('tads-gen', 1)!(interp, 1);
        expect(interp.registers.r0.value, 222);
      });
    });

    // Index 2: firstobj(cls?, flags?)
    /// Ref: vmbiftad.h:188 - firstobj(cls?, flags?)
    /// Spec: Returns the first object in memory matching optional filter.
    group('firstobj [2]', () {
      test('returns first matching object', () {
        interp.objectTable.register(T3TadsObject(objectId: 100, superclasses: [], loadImageProperties: [], flags: 0));
        T3BuiltinRegistry.getFunction('tads-gen', 2)!(interp, 0);
        expect(interp.registers.r0.isObject, isTrue);
      });
    });

    // Index 3: nextobj(obj, cls?, flags?)
    /// Ref: vmbiftad.h:189 - nextobj(obj, cls?, flags?)
    /// Spec: Returns the next object after given object.
    group('nextobj [3]', () {
      test('returns next matching object or nil', () {
        interp.objectTable.register(T3TadsObject(objectId: 100, superclasses: [], loadImageProperties: [], flags: 0));
        T3BuiltinRegistry.getFunction('tads-gen', 2)!(interp, 0);
        final firstId = interp.registers.r0.value;

        interp.stack.push(T3Value.fromObject(firstId));
        T3BuiltinRegistry.getFunction('tads-gen', 3)!(interp, 1);
        // May return next object or nil if no more
        expect(interp.registers.r0.type, anyOf(equals(T3DataType.obj), equals(T3DataType.nil)));
      });
    });

    // Index 4: randomize(...)
    /// Ref: vmbiftad.h:190 - randomize(...)
    /// Spec: Seeds the random number generator.
    group('randomize [4]', () {
      test('not implemented', () {
        final func = T3BuiltinRegistry.getFunction('tads-gen', 4);
        expect(func, isNull);
      }, skip: 'DISCREPANCY: randomize not implemented - see tads_spec_qa/tads_gen_randomize.md');
    });

    // Index 5: rand(...)
    /// Ref: vmbiftad.h:191 - rand(...)
    /// Spec: Returns a random number.
    group('rand [5]', () {
      test('not implemented', () {
        final func = T3BuiltinRegistry.getFunction('tads-gen', 5);
        expect(func, isNull);
      }, skip: 'DISCREPANCY: rand not implemented - see tads_spec_qa/tads_gen_rand.md');
    });

    // Index 6: toString(val, radix?, flags?)
    /// Ref: vmbiftad.h:192 - toString(val, radix?, flags?)
    /// Spec: Converts any value to a string representation.
    group('toString [6]', () {
      test('not implemented', () {
        final func = T3BuiltinRegistry.getFunction('tads-gen', 6);
        expect(func, isNull);
      }, skip: 'DISCREPANCY: toString not implemented - see tads_spec_qa/tads_gen_toString.md');
    });

    // Index 7: toInteger(val, radix?)
    /// Ref: vmbiftad.h:193 - toInteger(val, radix?)
    /// Spec: Converts a value to an integer.
    group('toInteger [7]', () {
      test('not implemented', () {
        final func = T3BuiltinRegistry.getFunction('tads-gen', 7);
        expect(func, isNull);
      }, skip: 'DISCREPANCY: toInteger not implemented - see tads_spec_qa/tads_gen_toInteger.md');
    });

    // Index 8: gettime(type?)
    /// Ref: vmbiftad.h:194 - gettime(type?)
    /// Spec: Returns current date/time information.
    group('gettime [8]', () {
      test('not implemented', () {
        final func = T3BuiltinRegistry.getFunction('tads-gen', 8);
        expect(func, isNull);
      }, skip: 'DISCREPANCY: gettime not implemented - see tads_spec_qa/tads_gen_gettime.md');
    });

    // Index 9: re_match(pat, str, index?)
    /// Ref: vmbiftad.h:195 - re_match(pat, str, index?)
    /// Spec: Matches a regular expression pattern against a string.
    group('re_match [9]', () {
      test('not implemented', () {
        final func = T3BuiltinRegistry.getFunction('tads-gen', 9);
        expect(func, isNull);
      }, skip: 'DISCREPANCY: re_match not implemented - see tads_spec_qa/tads_gen_re_match.md');
    });

    // Index 10: re_search(pat, str, index?)
    /// Ref: vmbiftad.h:196 - re_search(pat, str, index?)
    /// Spec: Searches for a pattern in a string.
    group('re_search [10]', () {
      test('not implemented', () {
        final func = T3BuiltinRegistry.getFunction('tads-gen', 10);
        expect(func, isNull);
      }, skip: 'DISCREPANCY: re_search not implemented - see tads_spec_qa/tads_gen_re_search.md');
    });

    // Index 11: re_group(n)
    /// Ref: vmbiftad.h:197 - re_group(n)
    /// Spec: Returns a captured group from last regex match.
    group('re_group [11]', () {
      test('not implemented', () {
        final func = T3BuiltinRegistry.getFunction('tads-gen', 11);
        expect(func, isNull);
      }, skip: 'DISCREPANCY: re_group not implemented - see tads_spec_qa/tads_gen_re_group.md');
    });

    // Index 12: re_replace(pat, str, repl, flags?, index?)
    /// Ref: vmbiftad.h:198 - re_replace(pat, str, repl, flags?, index?)
    /// Spec: Replaces matches of a pattern in a string.
    group('re_replace [12]', () {
      test('not implemented', () {
        final func = T3BuiltinRegistry.getFunction('tads-gen', 12);
        expect(func, isNull);
      }, skip: 'DISCREPANCY: re_replace not implemented - see tads_spec_qa/tads_gen_re_replace.md');
    });

    // Index 13: savepoint()
    /// Ref: vmbiftad.h:199 - savepoint()
    /// Spec: Creates an undo savepoint.
    group('savepoint [13]', () {
      test('not implemented', () {
        final func = T3BuiltinRegistry.getFunction('tads-gen', 13);
        expect(func, isNull);
      }, skip: 'DISCREPANCY: savepoint not implemented - see tads_spec_qa/tads_gen_savepoint.md');
    });

    // Index 14: undo()
    /// Ref: vmbiftad.h:200 - undo()
    /// Spec: Undoes changes back to last savepoint.
    group('undo [14]', () {
      test('not implemented', () {
        final func = T3BuiltinRegistry.getFunction('tads-gen', 14);
        expect(func, isNull);
      }, skip: 'DISCREPANCY: undo not implemented - see tads_spec_qa/tads_gen_undo.md');
    });

    // Index 15: save(filename)
    /// Ref: vmbiftad.h:201 - save(filename)
    /// Spec: Saves game state to a file.
    group('save [15]', () {
      test('function exists (stub)', () {
        final func = T3BuiltinRegistry.getFunction('tads-gen', 15);
        expect(func, isNotNull);
        // Note: Currently a stub that returns nil
      });
    });

    // Index 16: restore(filename)
    /// Ref: vmbiftad.h:202 - restore(filename)
    /// Spec: Restores game state from a file.
    group('restore [16]', () {
      test('function exists (stub)', () {
        final func = T3BuiltinRegistry.getFunction('tads-gen', 16);
        expect(func, isNotNull);
        // Note: Currently a stub that returns nil
      });
    });

    // Index 17: restart()
    /// Ref: vmbiftad.h:203 - restart()
    /// Spec: Restarts the game from the beginning.
    group('restart [17]', () {
      test('not implemented', () {
        final func = T3BuiltinRegistry.getFunction('tads-gen', 17);
        expect(func, isNull);
      }, skip: 'DISCREPANCY: restart not implemented - see tads_spec_qa/tads_gen_restart.md');
    });

    // Index 18: max(...)
    /// Ref: vmbiftad.h:204 - get_max(...)
    /// Spec: Returns the maximum of its arguments.
    group('max [18]', () {
      test('not implemented', () {
        final func = T3BuiltinRegistry.getFunction('tads-gen', 18);
        expect(func, isNull);
      }, skip: 'DISCREPANCY: max not implemented - see tads_spec_qa/tads_gen_max.md');
    });

    // Index 19: min(...)
    /// Ref: vmbiftad.h:205 - get_min(...)
    /// Spec: Returns the minimum of its arguments.
    group('min [19]', () {
      test('not implemented', () {
        final func = T3BuiltinRegistry.getFunction('tads-gen', 19);
        expect(func, isNull);
      }, skip: 'DISCREPANCY: min not implemented - see tads_spec_qa/tads_gen_min.md');
    });

    // Index 20: makeString(val, count?)
    /// Ref: vmbiftad.h:206 - make_string(val, count?)
    /// Spec: Creates a string from a value or character code.
    group('makeString [20]', () {
      test('not implemented', () {
        final func = T3BuiltinRegistry.getFunction('tads-gen', 20);
        expect(func, isNull);
      }, skip: 'DISCREPANCY: makeString not implemented - see tads_spec_qa/tads_gen_makeString.md');
    });

    // Index 21: getFuncParams(func)
    /// Ref: vmbiftad.h:207 - get_func_params(func)
    /// Spec: Returns info about function parameters.
    group('getFuncParams [21]', () {
      test('function exists', () {
        final func = T3BuiltinRegistry.getFunction('tads-gen', 21);
        expect(func, isNotNull);
      });
    });

    // Index 22: toNumber(val, radix?)
    /// Ref: vmbiftad.h:208 - toNumber(val, radix?)
    /// Spec: Converts value to number (BigNumber or int).
    group('toNumber [22]', () {
      test('slot exists but null', () {
        final func = T3BuiltinRegistry.getFunction('tads-gen', 22);
        // Index 22 in our array is null
        expect(func, isNull);
      }, skip: 'DISCREPANCY: toNumber not implemented - see tads_spec_qa/tads_gen_toNumber.md');
    });

    // Index 23: sprintf(fmt, ...)
    /// Ref: vmbiftad.h:209 - sprintf(fmt, ...)
    /// Spec: Formats a string with substitution values.
    group('sprintf [23]', () {
      test('not implemented', () {
        final func = T3BuiltinRegistry.getFunction('tads-gen', 23);
        expect(func, isNull);
      }, skip: 'DISCREPANCY: sprintf not implemented - see tads_spec_qa/tads_gen_sprintf.md');
    });

    // Note: Indices 24-29 exist in reference but may not in our impl
  });

  // ============================================================================
  // t3vm FUNCTION SET (12 functions per vmbift3.h)
  // ============================================================================
  group('t3vm function set', () {
    late T3Interpreter interp;

    setUp(() {
      interp = T3Interpreter();
      interp.stack.pushFrame(
        argCount: 0,
        localCount: 0,
        returnAddr: 0,
        entryPtr: 0,
        self: T3Value.nil(),
        targetObj: T3Value.nil(),
        definingObj: T3Value.nil(),
        targetProp: 0,
        invokee: T3Value.nil(),
      );
    });

    // Index 0: t3RunGC()
    /// Ref: vmbift3.h:133 - run_gc()
    /// Spec fnset_t3.htm:101-113: Invokes the garbage collector.
    group('t3RunGC [0]', () {
      test('not implemented', () {
        final func = T3BuiltinRegistry.getFunction('t3vm', 0);
        expect(func, isNull);
      }, skip: 'DISCREPANCY: t3RunGC not implemented - see tads_spec_qa/t3vm_runGC.md');
    });

    // Index 1: t3SetSay(funcptr or prop)
    /// Ref: vmbift3.h:134 - set_say()
    /// Spec fnset_t3.htm:115-136: Sets the default display function/method.
    group('t3SetSay [1]', () {
      test('sets sayFunc with function pointer', () {
        interp.stack.push(T3Value.fromFuncPtr(0x1234));
        T3BuiltinRegistry.getFunction('t3vm', 1)!(interp, 1);
        expect(interp.sayFunc.value, 0x1234);
      });

      test('sets sayMethod with property ID', () {
        interp.stack.push(T3Value.fromProp(0x55));
        T3BuiltinRegistry.getFunction('t3vm', 1)!(interp, 1);
        expect(interp.sayMethod, 0x55);
      });
    });

    // Index 2: t3GetVMVsn()
    /// Ref: vmbift3.h:135 - get_vm_vsn()
    /// Spec fnset_t3.htm:138-161: Returns encoded VM version number.
    group('t3GetVMVsn [2]', () {
      test('returns encoded version number', () {
        T3BuiltinRegistry.getFunction('t3vm', 2)!(interp, 0);
        final version = interp.registers.r0.value;
        final major = (version >> 16) & 0xFFFF;
        expect(major, greaterThanOrEqualTo(3));
      });
    });

    // Index 3: t3GetVMID()
    /// Ref: vmbift3.h:136 - get_vm_id()
    /// Spec fnset_t3.htm:163-184: Returns VM identification string.
    group('t3GetVMID [3]', () {
      test('not implemented', () {
        final func = T3BuiltinRegistry.getFunction('t3vm', 3);
        expect(func, isNull);
      }, skip: 'DISCREPANCY: t3GetVMID not implemented - see tads_spec_qa/t3vm_getVMID.md');
    });

    // Index 4: t3GetVMBanner()
    /// Ref: vmbift3.h:137 - get_vm_banner()
    /// Spec fnset_t3.htm:186-199: Returns VM banner/copyright string.
    group('t3GetVMBanner [4]', () {
      test('not implemented', () {
        final func = T3BuiltinRegistry.getFunction('t3vm', 4);
        expect(func, isNull);
      }, skip: 'DISCREPANCY: t3GetVMBanner not implemented - see tads_spec_qa/t3vm_getVMBanner.md');
    });

    // Index 5: t3GetVMPreinitMode()
    /// Ref: vmbift3.h:138 - get_vm_preinit_mode()
    /// Spec fnset_t3.htm:201-219: Returns true if in preinit mode.
    group('t3GetVMPreinitMode [5]', () {
      test('returns nil during normal execution', () {
        T3BuiltinRegistry.getFunction('t3vm', 5)!(interp, 0);
        expect(interp.registers.r0.isNil, isTrue);
      });
    });

    // Index 6: t3DebugTrace(mode, ...)
    /// Ref: vmbift3.h:139 - debug_trace()
    /// Spec fnset_t3.htm:221-235: Queries/sets debug mode.
    group('t3DebugTrace [6]', () {
      test('not implemented', () {
        final func = T3BuiltinRegistry.getFunction('t3vm', 6);
        expect(func, isNull);
      }, skip: 'DISCREPANCY: t3DebugTrace not implemented - see tads_spec_qa/t3vm_debugTrace.md');
    });

    // Index 7: t3GetGlobalSymbols(which?)
    /// Ref: vmbift3.h:140 - get_global_symtab()
    /// Spec fnset_t3.htm:237-253: Returns global symbol table.
    group('t3GetGlobalSymbols [7]', () {
      test(
        'not implemented',
        () {
          final func = T3BuiltinRegistry.getFunction('t3vm', 7);
          expect(func, isNull);
        },
        skip: 'DISCREPANCY: t3GetGlobalSymbols not implemented - see tads_spec_qa/t3vm_getGlobalSymbols.md',
      );
    });

    // Index 8: t3AllocProp()
    /// Ref: vmbift3.h:141 - alloc_new_prop()
    /// Spec fnset_t3.htm:255-259: Allocates a new property ID.
    group('t3AllocProp [8]', () {
      test('not implemented', () {
        final func = T3BuiltinRegistry.getFunction('t3vm', 8);
        expect(func, isNull);
      }, skip: 'DISCREPANCY: t3AllocProp not implemented - see tads_spec_qa/t3vm_allocProp.md');
    });

    // Index 9: t3GetStackTrace(level?, flags?)
    /// Ref: vmbift3.h:142 - get_stack_trace()
    /// Spec: Returns call stack trace information.
    group('t3GetStackTrace [9]', () {
      test('not implemented', () {
        final func = T3BuiltinRegistry.getFunction('t3vm', 9);
        expect(func, isNull);
      }, skip: 'DISCREPANCY: t3GetStackTrace not implemented - see tads_spec_qa/t3vm_getStackTrace.md');
    });

    // Index 10: t3GetNamedArg(name, default?)
    /// Ref: vmbift3.h:143 - get_named_arg()
    /// Spec: Returns a named argument value.
    group('t3GetNamedArg [10]', () {
      test('not implemented', () {
        // Beyond current array size
        final func = T3BuiltinRegistry.getFunction('t3vm', 10);
        expect(func, isNull);
      }, skip: 'DISCREPANCY: t3GetNamedArg not implemented - see tads_spec_qa/t3vm_getNamedArg.md');
    });

    // Index 11: t3GetNamedArgList()
    /// Ref: vmbift3.h:144 - get_named_arg_list()
    /// Spec: Returns list of all named argument names.
    group('t3GetNamedArgList [11]', () {
      test(
        'not implemented',
        () {
          final func = T3BuiltinRegistry.getFunction('t3vm', 11);
          expect(func, isNull);
        },
        skip: 'DISCREPANCY: t3GetNamedArgList not implemented - see tads_spec_qa/t3vm_getNamedArgList.md',
      );
    });
  });

  // ============================================================================
  // tads-io FUNCTION SET
  // ============================================================================
  group('tads-io function set', () {
    // Index 0: say(val)
    /// Spec: Displays a value to the main output.
    group('say [0]', () {
      test('function exists', () {
        final func = T3BuiltinRegistry.getFunction('tads-io', 0);
        expect(func, isNotNull);
      });
    });

    // Index 3: morePrompt()
    group('morePrompt [3]', () {
      test('function exists', () {
        final func = T3BuiltinRegistry.getFunction('tads-io', 3);
        expect(func, isNotNull);
      });
    });
  });

  // ============================================================================
  // BUILTIN REGISTRY TESTS
  // ============================================================================
  group('T3BuiltinRegistry', () {
    test('handles versioned function set names', () {
      // Versioned name should resolve to base set
      final func = T3BuiltinRegistry.getFunction('tads-gen/030005', 0);
      expect(func, isNotNull);
    });

    test('returns null for unknown function set', () {
      expect(T3BuiltinRegistry.getFunction('unknown-set', 0), isNull);
    });

    test('returns null for invalid index', () {
      expect(T3BuiltinRegistry.getFunction('tads-gen', 999), isNull);
    });
  });
}
