// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_run.dart';
import 'package:zart/src/tads3/vm/t3_globals.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_object_table.dart';
import 'package:zart/src/tads3/vm/t3_stack.dart';
import 'package:zart/src/tads3/vm/t3_pool.dart';
import 'dart:typed_data';

void main() {
  group('Special Return Addresses', () {
    test('vmrunRetRecursive is 0', () {
      expect(vmrunRetRecursive, equals(0));
    });

    test('vmrunRetOp is 1', () {
      expect(vmrunRetOp, equals(1));
    });

    test('vmrunRetOpAsilcl is 2', () {
      expect(vmrunRetOpAsilcl, equals(2));
    });
  });

  group('vmrunIsSpecialReturn', () {
    test('returns true for offsets 0-9', () {
      for (int i = 0; i < 10; i++) {
        expect(vmrunIsSpecialReturn(i), isTrue, reason: 'offset $i');
      }
    });

    test('returns false for offsets >= 10', () {
      expect(vmrunIsSpecialReturn(10), isFalse);
      expect(vmrunIsSpecialReturn(100), isFalse);
      expect(vmrunIsSpecialReturn(1000), isFalse);
    });

    test('returns true for negative offsets (edge case)', () {
      // Negative offsets are < 10 so technically return true
      expect(vmrunIsSpecialReturn(-1), isTrue);
    });
  });

  group('Frame Pointer Offsets', () {
    test('first argument offset is -11', () {
      expect(vmrunFpOfsArg1, equals(-11));
    });

    test('target property offset is -10', () {
      expect(vmrunFpOfsProp, equals(-10));
    });
    // ... we can trust the constants are correct based on previous tests ...
  });

  group('T3Arithmetic', () {
    test('computeIntSum adds numbers', () {
      expect(T3Arithmetic.computeIntSum(10, 20), equals(30));
    });

    test('computeIntDiff subtracts numbers', () {
      expect(T3Arithmetic.computeIntDiff(20, 7), equals(13));
    });

    test('logicalXor computes XOR', () {
      expect(T3Arithmetic.logicalXor(true, false), isTrue);
      expect(T3Arithmetic.logicalXor(true, true), isFalse);
    });
  });

  group('T3PropertyResult', () {
    test('initial state is correct', () {
      final res = T3PropertyResult();
      expect(res.value.type, equals(T3DataType.empty));
      expect(res.definingObj, equals(invalidObjectId));
      expect(res.argc, equals(0));
    });

    test('reset clears everything', () {
      final res = T3PropertyResult();
      res.value.setInt(42);
      res.definingObj = 100;
      res.argc = 5;

      res.reset();
      expect(res.value.type, equals(T3DataType.empty));
      expect(res.definingObj, equals(invalidObjectId));
      expect(res.argc, equals(0));
    });
  });

  group('T3PropertyEvaluator', () {
    late T3Globals globals;
    late T3PropertyEvaluator evaluator;
    late T3ObjectTable objTable;
    late T3VM vm;

    late MockCodePool codePool;
    late T3Stack stack;

    setUp(() {
      globals = T3Globals();
      objTable = T3ObjectTable();
      globals.objTable = objTable;
      codePool = MockCodePool();
      globals.codePool = codePool;
      stack = T3Stack(100, 10);
      globals.stack = stack;
      globals.funchdrSize = 10;
      globals.interpreter = T3Interpreter(globals);
      evaluator = T3PropertyEvaluator(globals);
      vm = T3VM();
    });

    test('getPropNoEval finds property on object', () {
      final obj = MockObject();
      final propId = 1234;
      final val = T3Value();
      val.setInt(42);
      obj.props[propId] = val;

      final objId = objTable.allocObj(vm, false);
      objTable.getEntry(objId)!.obj = obj;

      final selfValue = T3Value();
      selfValue.setObj(objId);

      final found = evaluator.getPropNoEval(selfValue, propId);

      expect(found, isTrue);
      expect(evaluator.result.value.type, equals(T3DataType.int32));
      expect(evaluator.result.value.getAsInt(), equals(42));
      expect(evaluator.result.definingObj, equals(objId));
    });

    test('getPropNoEval returns false if property not found', () {
      final obj = MockObject();
      final objId = objTable.allocObj(vm, false);
      objTable.getEntry(objId)!.obj = obj;

      final selfValue = T3Value();
      selfValue.setObj(objId);

      final found = evaluator.getPropNoEval(selfValue, 1234);
      expect(found, isFalse);
    });

    test('evalPropVal handles codeOfs and dstring as calls', () {
      evaluator.result.value.setCodeOfs(100);
      expect(evaluator.evalPropVal(1000, 0), isNotNull);

      globals.framePtr = -1; // Reset for next call
      evaluator.result.value.setDstring(200);
      expect(evaluator.evalPropVal(1000, 0), isNotNull);
    });

    test('evalPropVal handles simple values as non-calls', () {
      evaluator.result.value.setInt(42);
      expect(evaluator.evalPropVal(1000, 0), equals(1000));
    });
  });

  group('T3FunctionCaller', () {
    late T3Globals globals;
    late T3FunctionCaller caller;
    late T3Stack stack;
    late MockCodePool codePool;

    setUp(() {
      globals = T3Globals();
      stack = T3Stack(100, 10);
      codePool = MockCodePool();
      globals.stack = stack;
      globals.codePool = codePool;
      globals.funchdrSize = 10;
      caller = T3FunctionCaller(globals);
    });

    test('doCall sets up stack frame correctly', () {
      // Setup a fake function header (10 bytes)
      // argc=2, optional_argc=0, locals=3, total_stack=10, exc=0, dbg=0
      final hdr = Uint8List.fromList([
        2, 0, // argc, opt
        3, 0, // locals
        10, 0, // stack
        0, 0, // exc
        0, 0, // dbg
      ]);
      codePool.memory[0] = hdr;

      // Simulate 2 arguments already on stack (self, invokee etc are NOT pushed yet in this simple test)
      // wait, doCall assumes the CALLER pushed 5 meta items.
      for (int i = 0; i < 5; i++) {
        stack.push(T3Value(T3DataType.nil));
      }

      final startFp = globals.framePtr;
      final targetPtr = 0;
      final argc = 2;
      final callerOfs = 1000;

      final nextPc = caller.doCall(callerOfs, targetPtr, argc);

      // Verify PC
      expect(nextPc, equals(globals.funchdrSize));

      // Verify frame pointer updated
      expect(
        globals.framePtr,
        equals(stack.getTopPointer() - 4),
      ); // -4 because of 3 locals + FP slot

      // Verify metadata pushed on stack
      // FP points to the OLD FP
      final fp = globals.framePtr;
      expect(stack.getRef(fp).type, equals(T3DataType.stack));
      expect(stack.getRef(fp).getAsStack(), equals(startFp));

      expect(stack.getRef(fp - 1).type, equals(T3DataType.int32));
      expect(stack.getRef(fp - 1).getAsInt(), equals(argc));

      expect(stack.getRef(fp - 2).type, equals(T3DataType.codeOfs));
      expect(
        stack.getRef(fp - 2).getAsOfs(),
        equals(0),
      ); // globals.entryPtr starts at 0

      expect(stack.getRef(fp - 3).type, equals(T3DataType.codeOfs));
      expect(stack.getRef(fp - 3).getAsOfs(), equals(callerOfs));

      expect(stack.getRef(fp - 4).type, equals(T3DataType.codeOfs));
      expect(stack.getRef(fp - 4).getAsOfs(), equals(0));

      expect(stack.getRef(fp - 5).type, equals(T3DataType.nil));

      // Verify locals (3 locals)
      expect(
        stack.getRef(fp + 1).type,
        equals(T3DataType.nil),
      ); // Wait, locals should be nil?
      // In my implementation: stack.push(T3Value(T3DataType.nil));
      // T3Value(T3DataType.nil) is what it is.
      expect(stack.getRef(fp + 1).type, equals(T3DataType.nil));
      expect(stack.getRef(fp + 2).type, equals(T3DataType.nil));
      expect(stack.getRef(fp + 3).type, equals(T3DataType.nil));

      // New entry pointer
      expect(globals.entryPtr, equals(targetPtr));
    });

    test('callFuncPtr dispatches to doCall for function pointers', () {
      // Setup hdr
      final hdr = Uint8List.fromList([0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
      codePool.memory[100] = hdr;

      final funcPtr = T3Value(T3DataType.funcPtr)..setFnPtr(100);

      final nextPc = caller.callFuncPtr(funcPtr, 0, 500);

      expect(nextPc, equals(100 + globals.funchdrSize));
      expect(globals.entryPtr, equals(100));
    });

    test('doCall returns null for recursive calls (callerOfs == 0)', () {
      codePool.memory[0] = Uint8List(10); // dummy hdr
      for (int i = 0; i < 5; i++) stack.push(T3Value(T3DataType.nil));

      final nextPc = caller.doCall(0, 0, 0);
      expect(nextPc, isNull);
    });

    test('callFuncPtr handles bifPtr by discarding frame', () {
      final funcPtr = T3Value(T3DataType.bifPtr)..setBifPtr(1, 2);
      final spBefore = stack.getTopPointer();

      final nextPc = caller.callFuncPtr(funcPtr, 0, 500);

      expect(nextPc, isNull);
      expect(stack.getTopPointer(), equals(spBefore)); // Pushed 5, discarded 5
    });

    test('callFuncPtr handles obj by pushing as self', () {
      final objId = 1234;
      final funcPtr = T3Value(T3DataType.obj)..setObj(objId);

      final nextPc = caller.callFuncPtr(funcPtr, 0, 500);

      expect(nextPc, isNull);
      // Verify self in invocation frame (4th slot of 5)
      expect(stack.get(1).type, equals(T3DataType.obj));
      expect(stack.get(1).getAsObj(), equals(objId));
    });

    test('callFuncPtr returns null for invalid Types', () {
      final funcPtr = T3Value(T3DataType.int32)..setInt(42);
      final nextPc = caller.callFuncPtr(funcPtr, 0, 500);
      expect(nextPc, isNull);
    });
  });
}

class MockCodePool extends T3Pool {
  final Map<int, Uint8List> memory = {};

  @override
  (Uint8List, int) getPtr(int offset) {
    if (memory.containsKey(offset)) {
      return (memory[offset]!, 0);
    }
    return (Uint8List(10), 0);
  }

  @override
  bool validateOffset(int offset) => true;

  @override
  int? getOffsetFromPtr(Uint8List mem, int offsetInMem) => null;
}

/// Mock object for testing property evaluation
class MockObject extends T3Object {
  final Map<int, T3Value> props = {};

  @override
  bool getProp(
    T3VM vm,
    int propId,
    T3Value retval,
    int self,
    List<int> sourceObj,
    int? argc,
  ) {
    if (props.containsKey(propId)) {
      retval.copyFrom(props[propId]!);
      sourceObj[0] = self;
      if (argc != null) {
        // Simple mock: don't consume arguments
      }
      return true;
    }
    return false;
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
  void buildPropList(T3VM vm, int self, T3Value retval) {
    retval.setNil();
  }

  @override
  T3Metaclass getMetaclassReg() => throw UnimplementedError();
  @override
  void notifyDelete(T3VM vm, bool inRootSet) {}
  @override
  void setProp(T3VM vm, T3Undo? undo, int self, int propId, T3Value val) {
    props[propId] = T3Value.copy(val);
  }

  @override
  bool isInstanceOf(T3VM vm, int obj) => false;
  @override
  int getSuperclass(T3VM vm, int self, int index) => 0;
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
}
