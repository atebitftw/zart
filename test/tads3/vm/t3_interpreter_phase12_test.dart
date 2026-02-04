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

class MockCodePool extends T3Pool {
  final Map<int, Uint8List> _pages = {};
  MockCodePool();
  void setCodeAt0(Uint8List code) => _pages[0] = code;
  @override
  (Uint8List, int) getPtr(int offset) {
    for (final key in _pages.keys) {
      final page = _pages[key]!;
      if (offset >= key && offset < key + page.length)
        return (page, offset - key);
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
  group('T3Interpreter Phase 12 - Debug & Named Args', () {
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

    void setupFrame({int localVal = 42}) {
      stack.init();
      globals.framePtr = 20;
      stack.setAt(20, T3Value(T3DataType.stack)..setStack(0));
      stack.setAt(19, T3Value(T3DataType.int32)..setInt(2)); // argc = 2
      stack.setAt(18, T3Value(T3DataType.codeOfs)..setCodeOfs(0));
      stack.setAt(
        17,
        T3Value(T3DataType.codeOfs)..setCodeOfs(vmrunRetRecursive),
      );
      stack.setAt(21, T3Value(T3DataType.int32)..setInt(localVal)); // local 0
      // Args at FP - vmrunFpOfsArg1 (which is -10)
      stack.setAt(10, T3Value(T3DataType.int32)..setInt(100)); // arg 0
      stack.setAt(9, T3Value(T3DataType.int32)..setInt(200)); // arg 1
    }

    // --- Debug Tests ---
    test('opcNop - No operation', () {
      setupFrame();
      final writer = BytesBuilder();
      writer.addByte(opcNop);
      writer.addByte(opcNop);
      writer.addByte(opcNop);
      writer.addByte(opcRetnil);
      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();
      // Should complete without error
      expect(globals.r0.type, equals(T3DataType.nil));
    });

    test('opcBp - Breakpoint (treated as NOP)', () {
      setupFrame();
      final writer = BytesBuilder();
      writer.addByte(opcBp);
      writer.addByte(opcRetnil);
      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();
      expect(globals.r0.type, equals(T3DataType.nil));
    });

    test('opcGetDbLcl - Get debug local (frame 0)', () {
      setupFrame(localVal: 999);
      final writer = BytesBuilder();
      writer.addByte(opcGetDbLcl);
      writer.add([0, 0]); // frameIdx = 0
      writer.add([0, 0]); // lclIdx = 0
      writer.addByte(opcRetval);
      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();
      expect(globals.r0.getAsInt(), equals(999));
    });

    test('opcGetDbArgC - Get debug argc (frame 0)', () {
      setupFrame();
      final writer = BytesBuilder();
      writer.addByte(opcGetDbArgC);
      writer.add([0, 0]); // frameIdx = 0
      writer.addByte(opcRetval);
      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();
      expect(globals.r0.getAsInt(), equals(2)); // argc was set to 2
    });

    test('opcSetDbLcl - Set debug local (frame 0)', () {
      setupFrame(localVal: 100);
      final writer = BytesBuilder();
      writer.addByte(opcPushInt8);
      writer.addByte(77);
      writer.addByte(opcSetDbLcl);
      writer.add([0, 0]); // frameIdx = 0
      writer.add([0, 0]); // lclIdx = 0
      writer.addByte(opcGetDbLcl);
      writer.add([0, 0]);
      writer.add([0, 0]);
      writer.addByte(opcRetval);
      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();
      expect(globals.r0.getAsInt(), equals(77));
    });

    // --- Named Args Tests ---
    test('opcNamedArgPtr - Skip table offset', () {
      setupFrame();
      final writer = BytesBuilder();
      writer.addByte(opcNamedArgPtr);
      writer.add([0x10, 0x00]); // tableOfs
      writer.addByte(opcRetnil);
      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();
      expect(globals.r0.type, equals(T3DataType.nil));
    });

    test('opcNamedArgTab - Skip table entries', () {
      setupFrame();
      final writer = BytesBuilder();
      writer.addByte(opcNamedArgTab);
      writer.addByte(2); // count = 2 entries
      // Entry 1: nameOfs(2) + localIdx(2)
      writer.add([0, 0, 0, 0]);
      // Entry 2
      writer.add([0, 0, 0, 0]);
      writer.addByte(opcRetnil);
      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();
      expect(globals.r0.type, equals(T3DataType.nil));
    });
  });
}
