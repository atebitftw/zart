import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_globals.dart';
import 'package:zart/src/tads3/vm/t3_run.dart';
import 'package:zart/src/tads3/vm/t3_opcode.dart';
import 'package:zart/src/tads3/vm/t3_stack.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';
import 'package:zart/src/tads3/vm/t3_object_table.dart';
import 'package:zart/src/tads3/vm/t3_pool.dart' hide PoolOffset;
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_metaclass_table.dart';

// Mock Code Pool
class MockCodePool extends T3Pool {
  final Map<int, Uint8List> _pages = {};

  MockCodePool();

  void setCode(int offset, Uint8List code) {
    _pages[offset] = code;
  }

  void setCodeAt0(Uint8List code) => setCode(0, code);

  @override
  (Uint8List, int) getPtr(int offset) {
    for (final key in _pages.keys) {
      final page = _pages[key]!;
      if (offset >= key && offset < key + page.length) {
        return (page, offset - key);
      }
    }
    if (_pages.containsKey(offset)) {
      return (_pages[offset]!, 0);
    }
    throw RangeError('Invalid code offset: $offset');
  }

  @override
  void terminate() {}
  @override
  bool validateOffset(PoolOffset offset) => true;
  @override
  PoolOffset? getOffsetFromPtr(Uint8List mem, int offsetInMem) => null;
}

// Mock T3Object for recording interactions
class MockT3Object extends T3Object {
  bool inhPropCalled = false;
  bool getPropCalled = false;
  bool createInstanceCalled = false;
  int? lastPropId;
  int? lastDefiningObj;

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
    inhPropCalled = true;
    lastPropId = propId;
    lastDefiningObj = definingObj;
    retval.setInt(1234); // Return dummy value
    return true;
  }

  @override
  bool getProp(
    T3VM vm,
    int propId,
    T3Value retval,
    int self,
    List<int> sourceObj,
    int? argc,
  ) {
    getPropCalled = true;
    lastPropId = propId;
    retval.setInt(5678); // Return dummy value
    return true;
  }

  @override
  void createInstance(T3VM vm, int self, Uint8List pc, int pcOffset, int argc) {
    createInstanceCalled = true;
    (vm as T3Globals).stack!.push(T3Value(T3DataType.obj)..setObj(9999));
  }

  // Implement other abstracts as stubs
  @override
  bool getInvoker(T3VM vm, T3Value? val) => false;
  @override
  void setProp(T3VM vm, dynamic undo, int self, int propId, T3Value val) {}
  @override
  void enumProps(
    T3VM vm,
    int self,
    void Function(T3VM vm, int self, int prop, T3Value val) callback,
  ) {}
  @override
  void buildPropList(T3VM vm, int self, T3Value retval) {}

  // Stubs for missing methods
  @override
  void applyUndo(T3VM vm, dynamic rec) {}
  @override
  String? castToString(T3VM vm, int self, T3Value newStr) => null;
  @override
  T3Metaclass getMetaclassReg() => throw UnimplementedError();
  @override
  int getSuperclass(T3VM vm, int self, int index) => invalidObj;
  @override
  bool isInstanceOf(T3VM vm, int obj) => false;
  @override
  void loadFromImage(T3VM vm, int self, Uint8List ptr, int offset, int size) {}
  @override
  void markRefs(T3VM vm, int self) {}
  @override
  void markUndoRef(T3VM vm, dynamic rec) {}
  @override
  void notifyDelete(T3VM vm, bool inRootSet) {}
  @override
  void removeStaleUndoWeakRef(T3VM vm, dynamic rec) {}
  @override
  void restoreFromFile(T3VM vm, int self, dynamic fp, dynamic fixups) {}
  @override
  void saveToFile(T3VM vm, dynamic fp) {}
}

class MockMetaclass extends T3Metaclass {
  bool createCalled = false;

  @override
  String getMetaName() => 'mock-meta';

  @override
  int createFromStack(T3VM vm, Uint8List pc, int pcOffset, int argc) {
    createCalled = true;
    (vm as T3Globals).stack!.push(T3Value(T3DataType.obj)..setObj(8888));
    return 8888;
  }

  // Abstracts
  @override
  bool callStatProp(
    T3VM vm,
    T3Value result,
    Uint8List pc,
    int pcOffset,
    int argc,
    int prop,
  ) => false;
  @override
  void createForImageLoad(T3VM vm, int id) {}
  @override
  void createForRestore(T3VM vm, int id) {}
  @override
  int getClassObj(T3VM vm) => invalidObj;
  @override
  int getSupermeta(T3VM vm, int idx) => invalidObj;
  @override
  bool isMetaInstanceOf(T3VM vm, int obj) => false;
  @override
  T3Metaclass? getSupermetaReg() => null;
}

void main() {
  group('T3Interpreter Phase 6', () {
    late T3Globals globals;
    late T3Interpreter interpreter;
    late MockCodePool codePool;
    late T3Stack stack;

    // Test data
    final mockSelfObj = MockT3Object();
    final mockTargetObj = MockT3Object();
    final mockClassObj = MockT3Object();
    final mockMeta = MockMetaclass();

    setUp(() {
      globals = T3Globals();
      codePool = MockCodePool();
      globals.codePool = codePool;
      stack = T3Stack(100, 10);
      globals.stack = stack;
      globals.objTable = T3ObjectTable();
      globals.metaTable = T3MetaclassTable();

      interpreter = T3Interpreter(globals);
      globals.interpreter = interpreter;

      // Register mock objects manually
      globals.objTable!.allocObjWithId(1, true);
      globals.objTable!.getEntry(1)!.obj = mockSelfObj;

      globals.objTable!.allocObjWithId(2, true);
      globals.objTable!.getEntry(2)!.obj = mockTargetObj;

      globals.objTable!.allocObjWithId(3, true);
      globals.objTable!.getEntry(3)!.obj = mockClassObj;

      // Register metaclass
      globals.metaTable!.registerMetaclass(mockMeta); // Index 0
    });

    tearDown(() {
      globals.dispose();
    });

    test('opcInherit', () {
      final writer = BytesBuilder();
      writer.addByte(opcInherit);
      writer.addByte(0); // Argc
      writer.add([10, 0]); // PropId = 10
      writer.addByte(opcRetval); // Return with value

      final opcodes = writer.toBytes();
      final data = Uint8List(60);
      for (var i = 0; i < opcodes.length; i++) data[10 + i] = opcodes[i];
      codePool.setCodeAt0(data);

      globals.framePtr = 20;
      stack.init();
      // Setup stack frame

      // Pad stack up to 30
      for (var i = 0; i < 30; i++)
        stack.push(T3Value(T3DataType.int32)..setInt(0));

      stack.setAt(20, T3Value(T3DataType.stack)..setStack(0)); // EncFP
      stack.setAt(18, T3Value(T3DataType.codeOfs)..setCodeOfs(0)); // EncEP

      // Set Self (Obj 1) and DefObj (Obj 2 - pretend super/definer)
      stack.setAt(13, T3Value(T3DataType.obj)..setObj(1)); // Self
      stack.setAt(12, T3Value(T3DataType.obj)..setObj(2)); // DefObj

      // RetAddr
      stack.setAt(
        17,
        T3Value(T3DataType.codeOfs)..setCodeOfs(vmrunRetRecursive),
      );

      globals.pc = 10;
      interpreter.run();

      expect(mockSelfObj.inhPropCalled, isTrue);
      expect(mockSelfObj.lastPropId, equals(10));
      expect(mockSelfObj.lastDefiningObj, equals(2));
      // Should have returned value in R0
      expect(globals.r0.getAsInt(), equals(1234));
    });

    test('opcDelegate', () {
      final writer = BytesBuilder();
      writer.addByte(opcPushObj); // opcPushObject -> opcPushObj
      writer.add([2, 0, 0, 0]); // Push Obj 2
      writer.addByte(opcDelegate);
      writer.addByte(0); // Argc
      writer.add([20, 0]); // PropId = 20
      writer.addByte(opcRetval);

      final opcodes = writer.toBytes();
      final data = Uint8List(60);
      for (var i = 0; i < opcodes.length; i++) data[10 + i] = opcodes[i];
      codePool.setCodeAt0(data);

      globals.framePtr = 20;
      stack.init();
      // Pad stack up to 30
      for (var i = 0; i < 30; i++)
        stack.push(T3Value(T3DataType.int32)..setInt(0));

      // RetAddr, EncFP, EncEP
      stack.setAt(20, T3Value(T3DataType.stack)..setStack(0)); // EncFP
      stack.setAt(18, T3Value(T3DataType.codeOfs)..setCodeOfs(0)); // EncEP
      stack.setAt(
        17,
        T3Value(T3DataType.codeOfs)..setCodeOfs(vmrunRetRecursive),
      );

      globals.pc = 10;
      interpreter.run();

      expect(mockTargetObj.getPropCalled, isTrue);
      expect(mockTargetObj.lastPropId, equals(20));
      // Should have returned 5678 in R0
      expect(globals.r0.getAsInt(), equals(5678));
    });

    test('opcNew1', () {
      final writer = BytesBuilder();
      writer.addByte(opcPushObj); // opcPushObject -> opcPushObj
      writer.add([3, 0, 0, 0]); // Push Obj 3 (Class)
      writer.addByte(opcNew1);
      writer.addByte(0); // Argc
      writer.addByte(opcRetval);

      final opcodes = writer.toBytes();
      final data = Uint8List(60);
      for (var i = 0; i < opcodes.length; i++) data[10 + i] = opcodes[i];
      codePool.setCodeAt0(data);

      globals.framePtr = 20;
      stack.init();
      for (var i = 0; i < 30; i++)
        stack.push(T3Value(T3DataType.int32)..setInt(0));

      stack.setAt(20, T3Value(T3DataType.stack)..setStack(0)); // EncFP
      stack.setAt(18, T3Value(T3DataType.codeOfs)..setCodeOfs(0)); // EncEP
      stack.setAt(
        17,
        T3Value(T3DataType.codeOfs)..setCodeOfs(vmrunRetRecursive),
      );

      globals.pc = 10;
      interpreter.run();

      expect(mockClassObj.createInstanceCalled, isTrue);
      // createInstance pushes 9999, returned in R0
      expect(globals.r0.getAsObj(), equals(9999));
    });

    test('opcNew2', () {
      final writer = BytesBuilder();
      writer.addByte(opcNew2);
      writer.addByte(0); // Argc
      writer.add([0, 0]); // MetaIdx = 0
      writer.addByte(opcRetval);

      final opcodes = writer.toBytes();
      final data = Uint8List(60);
      for (var i = 0; i < opcodes.length; i++) data[10 + i] = opcodes[i];
      codePool.setCodeAt0(data);

      globals.framePtr = 20;
      stack.init();
      for (var i = 0; i < 30; i++)
        stack.push(T3Value(T3DataType.int32)..setInt(0));

      stack.setAt(20, T3Value(T3DataType.stack)..setStack(0)); // EncFP
      stack.setAt(18, T3Value(T3DataType.codeOfs)..setCodeOfs(0)); // EncEP
      stack.setAt(
        17,
        T3Value(T3DataType.codeOfs)..setCodeOfs(vmrunRetRecursive),
      );

      globals.pc = 10;
      interpreter.run();

      expect(mockMeta.createCalled, isTrue);
      // createFromStack pushes 8888, returned in R0
      expect(globals.r0.getAsObj(), equals(8888));
    });
  });
}
