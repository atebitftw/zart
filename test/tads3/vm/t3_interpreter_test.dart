// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_run.dart';
import 'package:zart/src/tads3/vm/t3_globals.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';
import 'package:zart/src/tads3/vm/t3_opcode.dart';
import 'package:zart/src/tads3/vm/t3_stack.dart';
import 'package:zart/src/tads3/vm/t3_pool.dart';
import 'package:zart/src/tads3/vm/t3_object_table.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';

class MockCodePool extends T3Pool {
  Uint8List? data;

  @override
  (Uint8List, int) getPtr(int offset) {
    if (data == null) throw StateError('MockCodePool data not set');
    return (data!, offset);
  }

  @override
  void terminate() {}

  @override
  bool validateOffset(int offset) => true;
  @override
  int? getOffsetFromPtr(Uint8List mem, int offsetInMem) => null;
}

void main() {
  late T3Globals globals;
  late T3Stack stack;
  late T3Interpreter interpreter;
  late MockCodePool codePool;

  setUp(() {
    globals = T3Globals();
    stack = T3Stack(100, 10);
    globals.stack = stack;
    codePool = MockCodePool();
    globals.codePool = codePool;
    globals.objTable = T3ObjectTable();
    globals.funchdrSize = 10;
    globals.r0.setNil();
    interpreter = T3Interpreter(globals);
    globals.interpreter = interpreter;
  });

  /// Helper to set up a standard mock frame for tests.
  void setUpMockFrame({int argc = 0}) {
    stack.init();
    // Push 15 slots for padding and arguments
    for (int i = 0; i < 15; i++) {
      stack.push(T3Value()..setNil());
    }

    // Push metadata (6 slots)
    stack.push(T3Value()..setNil()); // -5 frameref
    stack.push(T3Value()..setCodeOfs(0)); // -4 rcdesc
    stack.push(T3Value()..setCodeOfs(vmrunRetRecursive)); // -3 retpc
    stack.push(T3Value()..setCodeOfs(0)); // -2 encep
    stack.push(T3Value()..setInt(argc)); // -1 argc

    final fp = stack.pushSlot(); // This will be index 20
    stack.getRef(fp).setStack(-1); // 0 encfp

    globals.framePtr = fp;
  }

  void runBytecode(List<int> bytes) {
    codePool.data = Uint8List.fromList(bytes);

    // If frame is not set up, set up a default one
    if (globals.framePtr == -1 || globals.framePtr == 0) {
      setUpMockFrame();
    }

    globals.pc = 0;
    interpreter.run();
  }

  group('Push Opcodes', () {
    test('opcPush0', () {
      runBytecode([opcPush0, opcRetval]);
      expect(globals.r0.getAsInt(), equals(0));
    });

    test('opcPush1', () {
      runBytecode([opcPush1, opcRetval]);
      expect(globals.r0.getAsInt(), equals(1));
    });

    test('opcPushInt8', () {
      runBytecode([opcPushInt8, 0x7F, opcRetval]); // 127
      expect(globals.r0.getAsInt(), equals(127));

      setUpMockFrame();
      runBytecode([opcPushInt8, 0x80, opcRetval]); // -128
      expect(globals.r0.getAsInt(), equals(-128));
    });

    test('opcPushInt', () {
      runBytecode([opcPushInt, 0x00, 0x00, 0x01, 0x00, opcRetval]); // 65536
      expect(globals.r0.getAsInt(), equals(65536));
    });

    test('opcPushStr', () {
      runBytecode([opcPushStr, 0x01, 0x02, 0x03, 0x04, opcRetval]);
      expect(globals.r0.type, equals(T3DataType.sstring));
      expect(globals.r0.getAsOfs(), equals(0x04030201));
    });

    test('opcPushObj', () {
      runBytecode([opcPushObj, 0x01, 0x00, 0x00, 0x00, opcRetval]);
      expect(globals.r0.type, equals(T3DataType.obj));
      expect(globals.r0.getAsObj(), equals(1));
    });

    test('opcPushNil', () {
      runBytecode([opcPushNil, opcRetval]);
      expect(globals.r0.type, equals(T3DataType.nil));
    });

    test('opcPushTrue', () {
      runBytecode([opcPushTrue, opcRetval]);
      expect(globals.r0.type, equals(T3DataType.trueValue));
    });

    test('opcPushFnPtr', () {
      runBytecode([opcPushFnPtr, 0xAA, 0xBB, 0xCC, 0x00, opcRetval]);
      expect(globals.r0.type, equals(T3DataType.funcPtr));
      expect(globals.r0.getAsOfs(), equals(0x00CCBBAA));
    });
  });

  group('Arithmetic & Logic Opcodes', () {
    test('opcNeg', () {
      runBytecode([opcPushInt8, 5, opcNeg, opcRetval]);
      expect(globals.r0.getAsInt(), equals(-5));
    });

    test('opcAdd', () {
      runBytecode([opcPushInt8, 10, opcPushInt8, 20, opcAdd, opcRetval]);
      expect(globals.r0.getAsInt(), equals(30));
    });

    test('opcSub', () {
      runBytecode([opcPushInt8, 30, opcPushInt8, 10, opcSub, opcRetval]);
      expect(globals.r0.getAsInt(), equals(20));
    });

    test('opcEq', () {
      runBytecode([opcPushInt8, 42, opcPushInt8, 42, opcEq, opcRetval]);
      expect(globals.r0.type, equals(T3DataType.trueValue));

      setUpMockFrame();
      runBytecode([opcPushInt8, 42, opcPushInt8, 43, opcEq, opcRetval]);
      expect(globals.r0.type, equals(T3DataType.nil));
    });
  });

  group('Stack Manipulation Opcodes', () {
    test('opcDup', () {
      runBytecode([opcPushInt8, 42, opcDup, opcRetval]);
      expect(globals.r0.getAsInt(), equals(42));
    });

    test('opcDisc', () {
      runBytecode([opcPushInt8, 42, opcDisc, opcRetnil]);
      expect(globals.r0.type, equals(T3DataType.nil));
    });

    test('opcSwap', () {
      runBytecode([opcPushInt8, 1, opcPushInt8, 2, opcSwap, opcRetval]);
      expect(globals.r0.getAsInt(), equals(1));
    });

    test('opcGetR0', () {
      globals.r0.setInt(123);
      runBytecode([opcGetR0, opcRetval]);
      expect(globals.r0.getAsInt(), equals(123));
    });
  });

  group('Control Flow Opcodes', () {
    test('opcJmp', () {
      runBytecode([
        opcJmp, 0x01, 0x00, // Jump +1
        opcPush1, // Skipped
        opcPush0,
        opcRetval,
      ]);
      expect(globals.r0.getAsInt(), equals(0));
    });

    test('opcJt (jump if true)', () {
      runBytecode([
        opcPushTrue,
        opcJt, 0x01, 0x00, // Jump +1
        opcPush1, // Skipped
        opcPush0,
        opcRetval,
      ]);
      expect(globals.r0.getAsInt(), equals(0));

      setUpMockFrame();
      runBytecode([
        opcPushNil,
        opcJt, 0x01, 0x00, // Jump +1 (not taken)
        opcPush1, // Executed
        opcRetval,
      ]);
      expect(globals.r0.getAsInt(), equals(1));
    });

    test('opcJf (jump if false)', () {
      runBytecode([
        opcPushNil,
        opcJf, 0x01, 0x00,
        opcPush1, // Skipped
        opcPush0,
        opcRetval,
      ]);
      expect(globals.r0.getAsInt(), equals(0));
    });

    test('opcJnil (jump if nil and discard)', () {
      runBytecode([opcPushNil, opcJnil, 0x01, 0x00, opcPush1, opcPush0, opcRetval]);
      expect(globals.r0.getAsInt(), equals(0));
    });
  });

  group('Local & Argument Access Opcodes', () {
    setUp(() {
      setUpMockFrame(argc: 2);
      final fp = globals.framePtr;

      // Set Arg 1 (-11) and Arg 2 (-12)
      stack.getRef(fp + vmrunFpOfsArg1).setInt(200);
      stack.getRef(fp + vmrunFpOfsArg1 - 1).setInt(100);

      // Set Self (-7)
      stack.getRef(fp + vmrunFpOfsSelf).setObj(123);

      // Add locals (0, 1)
      stack.push(T3Value()..setInt(10)); // Lcl 1 (1)
      stack.push(T3Value()..setInt(20)); // Lcl 2 (2)
    });

    test('opcGetLclN0', () {
      runBytecode([opcGetLclN0, opcRetval]);
      expect(globals.r0.getAsInt(), equals(10));
    });

    test('opcGetLclN1', () {
      runBytecode([opcGetLclN1, opcRetval]);
      expect(globals.r0.getAsInt(), equals(20));
    });

    test('opcGetLcl1', () {
      runBytecode([opcGetLcl1, 1, opcRetval]); // Get Lcl 2
      expect(globals.r0.getAsInt(), equals(20));
    });

    test('opcSetLcl1', () {
      final fp = globals.framePtr;
      runBytecode([opcPushInt8, 99, opcSetLcl1, 0, opcRet]);
      expect(stack.getRef(fp + 1).getAsInt(), equals(99));
    });

    test('opcGetArgN0', () {
      runBytecode([opcGetArgN0, opcRetval]);
      expect(globals.r0.getAsInt(), equals(200));
    });

    test('opcGetArgN1', () {
      runBytecode([opcGetArgN1, opcRetval]);
      expect(globals.r0.getAsInt(), equals(100));
    });

    test('opcGetArg1', () {
      runBytecode([opcGetArg1, 1, opcRetval]); // Get Arg 2
      expect(globals.r0.getAsInt(), equals(100));
    });

    test('opcPushSelf', () {
      runBytecode([opcPushSelf, opcRetval]);
      expect(globals.r0.getAsObj(), equals(123));
    });
  });

  group('Property & Call Opcodes', () {
    late MockObject obj;
    late int objId;

    setUp(() {
      obj = MockObject();
      objId = globals.objTable!.allocObj(globals, false);
      globals.objTable!.getEntry(objId)!.obj = obj;
    });

    test('opcGetProp', () {
      obj.props[1234] = T3Value()..setInt(42);
      runBytecode([
        opcPushObj, (objId & 0xFF), (objId >> 8) & 0xFF, (objId >> 16) & 0xFF, (objId >> 24) & 0xFF,
        opcGetProp, 0xD2, 0x04, // 1234
        opcRet,
      ]);
      expect(globals.r0.getAsInt(), equals(42));
    });

    test('opcSetProp', () {
      runBytecode([
        opcPushObj, (objId & 0xFF), (objId >> 8) & 0xFF, (objId >> 16) & 0xFF, (objId >> 24) & 0xFF,
        opcPushInt8, 42,
        opcSetProp, 0xD2, 0x04, // 1234
        opcRet,
      ]);
      expect(obj.props[1234]?.getAsInt(), equals(42));
    });

    test('opcCall', () {
      // Mock code: opcPushInt8 55, opcRetval
      final funcCode = [opcPushInt8, 55, opcRetval];

      final mainCode = [
        opcPushInt8, 10, // Arg 1 (offset 0-1)
        opcCall, 1, 20, 0, 0, 0, // argc=1, targetofs=20 (offset 2-7)
        opcRet, // offset 8
      ];

      final data = Uint8List(100);
      data.setRange(0, mainCode.length, mainCode);

      // Function header at 20
      data[20 + 0] = 1; // argc
      data[20 + 1] = 0; // optArgc
      data[20 + 2] = 0; // localCnt
      data[20 + 4] = 8; // stackDepth

      // Bytecode at 30
      data.setRange(30, 30 + funcCode.length, funcCode);

      codePool.data = data;
      setUpMockFrame();
      globals.pc = 0;
      interpreter.run();

      expect(globals.r0.getAsInt(), equals(55));
    });
  });
}

class MockObject extends T3Object {
  final Map<int, T3Value> props = {};

  @override
  bool getProp(T3VM vm, int propId, T3Value retval, int self, List<int> sourceObj, int? argc) {
    if (props.containsKey(propId)) {
      retval.copyFrom(props[propId]!);
      sourceObj[0] = self;
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
  ) => false;
  @override
  void buildPropList(T3VM vm, int self, T3Value retval) => retval.setNil();
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
