import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_globals.dart';
import 'package:zart/src/tads3/vm/t3_run.dart';
import 'package:zart/src/tads3/vm/t3_opcode.dart';
import 'package:zart/src/tads3/vm/t3_stack.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';
import 'package:zart/src/tads3/vm/t3_object_table.dart';
import 'package:zart/src/tads3/vm/t3_pool.dart' hide PoolOffset;

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

void main() {
  group('T3Interpreter Phase 7', () {
    late T3Globals globals;
    late T3Interpreter interpreter;
    late MockCodePool codePool;
    late T3Stack stack;

    setUp(() {
      globals = T3Globals();
      codePool = MockCodePool();
      globals.codePool = codePool;
      stack = T3Stack(100, 10);
      globals.stack = stack;
      globals.objTable = T3ObjectTable();

      interpreter = T3Interpreter(globals);
      globals.interpreter = interpreter;
      globals.funchdrSize = 10;
    });

    tearDown(() {
      globals.dispose();
    });

    test('opcCall - Simple Function Call', () {
      // 1. Define Function at offset 100
      final funcWriter = BytesBuilder();
      // Header (10 bytes)
      funcWriter.addByte(0); // argc
      funcWriter.addByte(0); // opt
      funcWriter.add([1, 0]); // locals=1
      funcWriter.add([10, 0]); // stack=10
      funcWriter.add([0, 0]); // exc
      funcWriter.add([0, 0]); // dbg

      // Code: Push 42, Retval
      funcWriter.addByte(opcPushInt8);
      funcWriter.addByte(42);
      funcWriter.addByte(opcRetval);

      final funcCode = funcWriter.toBytes();

      // 2. Define Caller at offset 0
      final writer = BytesBuilder();
      writer.addByte(opcCall);
      writer.addByte(0); // Argc
      writer.add([100, 0, 0, 0]); // FuncAddr = 100

      writer.addByte(opcGetR0); // Push result to stack
      writer.addByte(opcRetval); // Return result from stack

      final opcodes = writer.toBytes();

      // Combine into one data page
      final data = Uint8List(200);
      for (var i = 0; i < opcodes.length; i++) data[10 + i] = opcodes[i];
      for (var i = 0; i < funcCode.length; i++) data[100 + i] = funcCode[i];

      codePool.setCodeAt0(data);

      globals.framePtr = 20;
      stack.init();
      // Pad stack up to 30
      for (var i = 0; i < 30; i++) stack.push(T3Value(T3DataType.int32)..setInt(0));

      // Setup initial frame
      stack.setAt(20, T3Value(T3DataType.stack)..setStack(0)); // EncFP
      stack.setAt(18, T3Value(T3DataType.codeOfs)..setCodeOfs(0)); // EncEP
      stack.setAt(17, T3Value(T3DataType.codeOfs)..setCodeOfs(vmrunRetRecursive));

      globals.pc = 10;
      interpreter.run();

      expect(globals.pc, equals(vmrunRetRecursive));
    });

    test('opcCall - With Arguments', () {
      // Function at 200: GetArg1(1), Retval
      final funcWriter = BytesBuilder();
      funcWriter.addByte(0); // argc
      funcWriter.addByte(0); // opt
      funcWriter.add([1, 0]); // locals
      funcWriter.add([10, 0]); // stack
      funcWriter.add([0, 0]); // exc
      funcWriter.add([0, 0]); // dbg

      funcWriter.addByte(opcGetArg1);
      funcWriter.addByte(0); // Index 0
      funcWriter.addByte(opcRetval);

      final funcCode = funcWriter.toBytes();

      // Caller at 0
      final writer = BytesBuilder();
      writer.addByte(opcPushInt8);
      writer.addByte(123); // Arg 1

      writer.addByte(opcCall);
      writer.addByte(1); // Argc=1
      writer.add([200, 0, 0, 0]);

      writer.addByte(opcGetR0);
      writer.addByte(opcRetval);

      final opcodes = writer.toBytes();

      final data = Uint8List(300);
      for (var i = 0; i < opcodes.length; i++) data[10 + i] = opcodes[i];
      for (var i = 0; i < funcCode.length; i++) data[200 + i] = funcCode[i];

      codePool.setCodeAt0(data);

      globals.framePtr = 20;
      stack.init();
      for (var i = 0; i < 30; i++) stack.push(T3Value(T3DataType.int32)..setInt(0));

      // Setup initial frame
      stack.setAt(20, T3Value(T3DataType.stack)..setStack(0));
      stack.setAt(18, T3Value(T3DataType.codeOfs)..setCodeOfs(0));
      stack.setAt(17, T3Value(T3DataType.codeOfs)..setCodeOfs(vmrunRetRecursive));

      globals.pc = 10;
      interpreter.run();

      expect(globals.r0.getAsInt(), equals(123));
    });

    test('opcPtrCall - Function Pointer', () {
      // Function at 300: Push 99, Retval
      final funcWriter = BytesBuilder();
      funcWriter.addByte(0); // argc
      funcWriter.addByte(0); // opt
      funcWriter.add([1, 0]); // locals
      funcWriter.add([10, 0]); // stack
      funcWriter.add([0, 0]); // exc
      funcWriter.add([0, 0]); // dbg

      funcWriter.addByte(opcPushInt8);
      funcWriter.addByte(99);
      funcWriter.addByte(opcRetval);

      final funcCode = funcWriter.toBytes();

      // Caller
      final writer = BytesBuilder();
      writer.addByte(opcPushFnPtr);
      writer.add([0x2C, 0x01, 0x00, 0x00]); // 300 = 0x12C

      writer.addByte(opcPtrCall);
      writer.addByte(0); // Argc

      writer.addByte(opcGetR0);
      writer.addByte(opcRetval);

      final opcodes = writer.toBytes();

      final data = Uint8List(400);
      for (var i = 0; i < opcodes.length; i++) data[10 + i] = opcodes[i];
      for (var i = 0; i < funcCode.length; i++) data[300 + i] = funcCode[i];

      codePool.setCodeAt0(data);

      globals.framePtr = 20;
      stack.init();
      for (var i = 0; i < 30; i++) stack.push(T3Value(T3DataType.int32)..setInt(0));
      stack.setAt(20, T3Value(T3DataType.stack)..setStack(0));
      stack.setAt(18, T3Value(T3DataType.codeOfs)..setCodeOfs(0));
      stack.setAt(17, T3Value(T3DataType.codeOfs)..setCodeOfs(vmrunRetRecursive));

      globals.pc = 10;
      interpreter.run();

      expect(globals.r0.getAsInt(), equals(99));
    });
  });
}
