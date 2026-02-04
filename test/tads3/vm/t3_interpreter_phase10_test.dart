import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_globals.dart';
import 'package:zart/src/tads3/vm/t3_run.dart';
import 'package:zart/src/tads3/vm/t3_opcode.dart';
import 'package:zart/src/tads3/vm/t3_stack.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';
import 'package:zart/src/tads3/vm/t3_object_table.dart';
import 'package:zart/src/tads3/vm/t3_pool.dart' hide PoolOffset;
import 'package:zart/src/tads3/vm/t3_bif.dart';

// Mock Code Pool (reused from previous phases)
class MockCodePool extends T3Pool {
  final Map<int, Uint8List> _pages = {};

  MockCodePool();

  void setCode(int offset, Uint8List code) => _pages[offset] = code;
  void setCodeAt0(Uint8List code) => setCode(0, code);

  @override
  (Uint8List, int) getPtr(int offset) {
    for (final key in _pages.keys) {
      final page = _pages[key]!;
      if (offset >= key && offset < key + page.length) {
        return (page, offset - key);
      }
    }
    if (_pages.containsKey(offset)) return (_pages[offset]!, 0);
    throw RangeError('Invalid code offset: $offset');
  }

  @override
  void terminate() {}
  @override
  bool validateOffset(int offset) => true;
  @override
  int? getOffsetFromPtr(Uint8List mem, int offsetInMem) => null;
}

class MockConstPool extends T3PoolInMem {
  MockConstPool() : super();
  @override
  String getString(int offset) => '';
}

void main() {
  group('T3Interpreter Phase 10 - Local Modifiers & Context', () {
    late T3Globals globals;
    late T3Interpreter interpreter;
    late MockCodePool codePool;
    late T3Stack stack;

    setUp(() {
      globals = T3Globals();
      codePool = MockCodePool();
      globals.codePool = codePool;
      globals.constPool = MockConstPool();
      stack = T3Stack(100, 10);
      globals.stack = stack;
      globals.objTable = T3ObjectTable();
      globals.bifTable = T3BifTable();
      interpreter = T3Interpreter(globals);
      globals.interpreter = interpreter;
      globals.funchdrSize = 10;
    });

    tearDown(() => globals.dispose());

    void setupFrame({int localVal = 0}) {
      stack.init();
      globals.framePtr = 20;
      stack.setAt(20, T3Value(T3DataType.stack)..setStack(0));
      stack.setAt(19, T3Value(T3DataType.int32)..setInt(0)); // argc
      stack.setAt(18, T3Value(T3DataType.codeOfs)..setCodeOfs(0));
      stack.setAt(
        17,
        T3Value(T3DataType.codeOfs)..setCodeOfs(vmrunRetRecursive),
      );
      // Local 0 at FP+1 = slot 21
      stack.setAt(21, T3Value(T3DataType.int32)..setInt(localVal));
    }

    test('opcIncLcl - Increment Local', () {
      setupFrame(localVal: 10);
      final writer = BytesBuilder();
      writer.addByte(opcIncLcl);
      writer.add([0, 0]); // lclIdx = 0 (2-byte)
      writer.addByte(opcRetnil);
      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();
      expect(stack.getRef(21).getAsInt(), equals(11));
    });

    test('opcDecLcl - Decrement Local', () {
      setupFrame(localVal: 10);
      final writer = BytesBuilder();
      writer.addByte(opcDecLcl);
      writer.add([0, 0]);
      writer.addByte(opcRetnil);
      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();
      expect(stack.getRef(21).getAsInt(), equals(9));
    });

    test('opcAddILcl1 - Add Int8 to Local', () {
      setupFrame(localVal: 5);
      final writer = BytesBuilder();
      writer.addByte(opcAddILcl1);
      writer.add([0, 0]); // lclIdx = 0
      writer.addByte(7); // Add 7
      writer.addByte(opcRetnil);
      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();
      expect(stack.getRef(21).getAsInt(), equals(12));
    });

    test('opcZeroLcl1 - Set Local to Zero', () {
      setupFrame(localVal: 99);
      final writer = BytesBuilder();
      writer.addByte(opcZeroLcl1);
      writer.addByte(0); // lclIdx = 0 (1-byte)
      writer.addByte(opcRetnil);
      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();
      expect(stack.getRef(21).getAsInt(), equals(0));
    });

    test('opcNilLcl1 - Set Local to Nil', () {
      setupFrame(localVal: 42);
      final writer = BytesBuilder();
      writer.addByte(opcNilLcl1);
      writer.addByte(0);
      writer.addByte(opcRetnil);
      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();
      expect(stack.getRef(21).type, equals(T3DataType.nil));
    });

    test('opcOneLcl1 - Set Local to One', () {
      setupFrame(localVal: 0);
      final writer = BytesBuilder();
      writer.addByte(opcOneLcl1);
      writer.addByte(0);
      writer.addByte(opcRetnil);
      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();
      expect(stack.getRef(21).getAsInt(), equals(1));
    });

    test('opcAddToLcl - Add TOS to Local', () {
      setupFrame(localVal: 10);
      final writer = BytesBuilder();
      writer.addByte(opcPushInt8); // Push 5
      writer.addByte(5);
      writer.addByte(opcAddToLcl);
      writer.add([0, 0]);
      writer.addByte(opcRetnil);
      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();
      expect(stack.getRef(21).getAsInt(), equals(15));
    });

    test('opcSubFromLcl - Subtract TOS from Local', () {
      setupFrame(localVal: 20);
      final writer = BytesBuilder();
      writer.addByte(opcPushInt8);
      writer.addByte(7);
      writer.addByte(opcSubFromLcl);
      writer.add([0, 0]);
      writer.addByte(opcRetnil);
      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();
      expect(stack.getRef(21).getAsInt(), equals(13));
    });

    test('opcSetSelf - Set Self in Frame', () {
      setupFrame();
      // Set self slot (FP-7 = slot 13)
      stack.setAt(13, T3Value(T3DataType.nil));
      final writer = BytesBuilder();
      writer.addByte(opcPushObj);
      writer.add([100, 0, 0, 0]); // Object ID 100
      writer.addByte(opcSetSelf);
      writer.addByte(opcRetnil);
      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();
      expect(stack.getRef(13).type, equals(T3DataType.obj));
      expect(stack.getRef(13).getAsObj(), equals(100));
    });

    test('opcStoreCtx - Store Context to Stack', () {
      setupFrame();
      // Set self to object 42
      stack.setAt(13, T3Value(T3DataType.obj)..setObj(42));
      final writer = BytesBuilder();
      writer.addByte(opcStoreCtx);
      writer.addByte(opcRetval);
      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();
      // R0 should contain self value
      expect(globals.r0.type, equals(T3DataType.obj));
      expect(globals.r0.getAsObj(), equals(42));
    });
  });
}
