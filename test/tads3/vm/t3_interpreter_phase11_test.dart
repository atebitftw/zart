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
  group('T3Interpreter Phase 11 - Index & Misc Opcodes', () {
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

    void setupFrame() {
      stack.init();
      globals.framePtr = 20;
      stack.setAt(20, T3Value(T3DataType.stack)..setStack(0));
      stack.setAt(19, T3Value(T3DataType.int32)..setInt(0));
      stack.setAt(18, T3Value(T3DataType.codeOfs)..setCodeOfs(0));
      stack.setAt(
        17,
        T3Value(T3DataType.codeOfs)..setCodeOfs(vmrunRetRecursive),
      );
      stack.setAt(21, T3Value(T3DataType.nil)); // local 0
    }

    // --- Arithmetic Tests ---
    test('opcMul - Multiply', () {
      setupFrame();
      final writer = BytesBuilder();
      writer.addByte(opcPushInt8);
      writer.addByte(6);
      writer.addByte(opcPushInt8);
      writer.addByte(7);
      writer.addByte(opcMul);
      writer.addByte(opcRetval);
      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();
      expect(globals.r0.getAsInt(), equals(42));
    });

    test('opcDiv - Divide', () {
      setupFrame();
      final writer = BytesBuilder();
      writer.addByte(opcPushInt8);
      writer.addByte(20);
      writer.addByte(opcPushInt8);
      writer.addByte(4);
      writer.addByte(opcDiv);
      writer.addByte(opcRetval);
      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();
      expect(globals.r0.getAsInt(), equals(5));
    });

    test('opcMod - Modulo', () {
      setupFrame();
      final writer = BytesBuilder();
      writer.addByte(opcPushInt8);
      writer.addByte(17);
      writer.addByte(opcPushInt8);
      writer.addByte(5);
      writer.addByte(opcMod);
      writer.addByte(opcRetval);
      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();
      expect(globals.r0.getAsInt(), equals(2));
    });

    // --- Bitwise Tests ---
    test('opcBand - Bitwise AND', () {
      setupFrame();
      final writer = BytesBuilder();
      writer.addByte(opcPushInt8);
      writer.addByte(0x0F);
      writer.addByte(opcPushInt8);
      writer.addByte(0x3C);
      writer.addByte(opcBand);
      writer.addByte(opcRetval);
      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();
      expect(globals.r0.getAsInt(), equals(0x0C));
    });

    test('opcBor - Bitwise OR', () {
      setupFrame();
      final writer = BytesBuilder();
      writer.addByte(opcPushInt8);
      writer.addByte(0x05); // 0101
      writer.addByte(opcPushInt8);
      writer.addByte(0x0A); // 1010
      writer.addByte(opcBor);
      writer.addByte(opcRetval);
      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();
      expect(globals.r0.getAsInt(), equals(0x0F)); // 1111
    });

    test('opcBnot - Bitwise NOT', () {
      setupFrame();
      final writer = BytesBuilder();
      writer.addByte(opcPushInt8);
      writer.addByte(0);
      writer.addByte(opcBnot);
      writer.addByte(opcRetval);
      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();
      expect(globals.r0.getAsInt(), equals(-1)); // ~0 = -1 in two's complement
    });

    // --- Logic Tests ---
    test('opcNot - Logical NOT (true becomes nil)', () {
      setupFrame();
      final writer = BytesBuilder();
      writer.addByte(opcPushTrue);
      writer.addByte(opcNot);
      writer.addByte(opcRetval);
      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();
      expect(globals.r0.type, equals(T3DataType.nil));
    });

    test('opcNot - Logical NOT (nil becomes true)', () {
      setupFrame();
      final writer = BytesBuilder();
      writer.addByte(opcPushNil);
      writer.addByte(opcNot);
      writer.addByte(opcRetval);
      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();
      expect(globals.r0.type, equals(T3DataType.trueValue));
    });

    test('opcInc - Increment', () {
      setupFrame();
      final writer = BytesBuilder();
      writer.addByte(opcPushInt8);
      writer.addByte(10);
      writer.addByte(opcInc);
      writer.addByte(opcRetval);
      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();
      expect(globals.r0.getAsInt(), equals(11));
    });

    test('opcDec - Decrement', () {
      setupFrame();
      final writer = BytesBuilder();
      writer.addByte(opcPushInt8);
      writer.addByte(10);
      writer.addByte(opcDec);
      writer.addByte(opcRetval);
      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();
      expect(globals.r0.getAsInt(), equals(9));
    });

    // --- Push Tests ---
    test('opcPushPropId - Push Property ID', () {
      setupFrame();
      final writer = BytesBuilder();
      writer.addByte(opcPushPropId);
      writer.add([0x34, 0x12]); // Property ID 0x1234
      writer.addByte(opcRetval);
      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();
      expect(globals.r0.type, equals(T3DataType.prop));
      expect(globals.r0.getAsProp(), equals(0x1234));
    });

    test('opcPushLst - Push List Constant', () {
      setupFrame();
      final writer = BytesBuilder();
      writer.addByte(opcPushLst);
      writer.add([0x00, 0x01, 0x00, 0x00]); // List at offset 0x100
      writer.addByte(opcRetval);
      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();
      expect(globals.r0.type, equals(T3DataType.list));
    });

    test('opcPushEnum - Push Enum Value', () {
      setupFrame();
      final writer = BytesBuilder();
      writer.addByte(opcPushEnum);
      writer.add([0x42, 0x00, 0x00, 0x00]); // Enum value 66
      writer.addByte(opcRetval);
      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();
      expect(globals.r0.type, equals(T3DataType.enumValue));
    });

    // --- Stack Tests ---
    test('opcDisc1 - Discard N items', () {
      setupFrame();
      final writer = BytesBuilder();
      writer.addByte(opcPushInt8);
      writer.addByte(1);
      writer.addByte(opcPushInt8);
      writer.addByte(2);
      writer.addByte(opcPushInt8);
      writer.addByte(3);
      writer.addByte(opcDisc1);
      writer.addByte(2); // Discard 2 items
      writer.addByte(opcRetval); // Return remaining (1)
      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();
      expect(globals.r0.getAsInt(), equals(1));
    });

    // --- Index Tests ---
    test('opcIndex - Returns nil for list placeholder', () {
      setupFrame();
      final writer = BytesBuilder();
      writer.addByte(opcPushLst);
      writer.add([0x00, 0x01, 0x00, 0x00]);
      writer.addByte(opcPushInt8);
      writer.addByte(1);
      writer.addByte(opcIndex);
      writer.addByte(opcRetval);
      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();
      // Returns nil because list indexing is placeholder
      expect(globals.r0.type, equals(T3DataType.nil));
    });

    test('opcIdxInt8 - Index by immediate int8', () {
      setupFrame();
      final writer = BytesBuilder();
      writer.addByte(opcPushLst);
      writer.add([0x00, 0x01, 0x00, 0x00]);
      writer.addByte(opcIdxInt8);
      writer.addByte(2); // index 2
      writer.addByte(opcRetval);
      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();
      expect(globals.r0.type, equals(T3DataType.nil));
    });
  });
}
