import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_globals.dart';
import 'package:zart/src/tads3/vm/t3_run.dart';
import 'package:zart/src/tads3/vm/t3_opcode.dart';
import 'package:zart/src/tads3/vm/t3_stack.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';
import 'package:zart/src/tads3/vm/t3_object_table.dart';
import 'package:zart/src/tads3/vm/t3_pool.dart' hide PoolOffset;
import 'package:zart/src/tads3/vm/t3_error.dart';

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
  group('T3Interpreter Phase 5', () {
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
    });

    tearDown(() {
      globals.dispose();
    });

    test('opcSwitch - Taken', () {
      final writer = BytesBuilder();
      writer.addByte(opcPushInt8);
      writer.addByte(20);

      writer.addByte(opcSwitch);
      writer.add([2, 0]); // Count = 2
      writer.add([0x10, 0x00]); // DefOfs = 16

      // Case 1: 10 -> +4
      writer.add([10, 0, 0, 0]); // Val=10
      writer.add([4, 0]); // Ofs=4

      // Case 2: 20 -> +8
      writer.add([20, 0, 0, 0]); // Val=20
      writer.add([8, 0]); // Ofs=8

      // Target for Case 2 calculation:
      // OpStart (relative to code start) = 10 (header) + 2 (push) = 12.
      // globals.pc incremented to 13 before dispatch.
      // logic: pc(13) + 5 + i(1)*6 + ofs(8) = 13 + 5 + 6 + 8 = 32.

      final opcodes = writer.toBytes();

      final data = Uint8List(60);
      final view = ByteData.sublistView(data);
      // Header
      view.setUint16(4, 20, Endian.little); // stack
      view.setUint16(6, 0, Endian.little); // exc

      // Copy opcodes
      for (var i = 0; i < opcodes.length; i++) data[10 + i] = opcodes[i];

      // Inject opcRetnil at 32
      data[32] = opcRetnil;

      codePool.setCode(0, data);

      // Setup frame with sufficient padding
      globals.framePtr = 20;
      stack.init();
      // Push 30 items
      for (var i = 0; i < 30; i++) stack.push(T3Value(T3DataType.int32)..setInt(0));

      // Fixup frame metadata at FP=20
      stack.setAt(20, T3Value(T3DataType.stack)..setStack(0)); // EncFP
      stack.setAt(18, T3Value(T3DataType.codeOfs)..setCodeOfs(0)); // EncEP
      // RetAddr at FP-3 = 17
      stack.setAt(17, T3Value(T3DataType.codeOfs)..setCodeOfs(vmrunRetRecursive));

      globals.entryPtr = 0;
      globals.pc = 10;

      interpreter.run();

      // Expect vmrunRetRecursive
      expect(globals.pc, equals(vmrunRetRecursive));
    });

    test('opcSwitch - Default Case', () {
      final writer = BytesBuilder();
      writer.addByte(opcPushInt8);
      writer.addByte(99); // No match

      writer.addByte(opcSwitch);
      writer.add([1, 0]); // Count = 1
      writer.add([0x10, 0x00]); // DefOfs = 16

      // Case 1: 10 -> +4
      writer.add([10, 0, 0, 0]);
      writer.add([4, 0]);

      // Target for Default:
      // OpStart = 2.
      // Logic: pc(13) + 5 + (count*6) + defOfs
      // 13 + 5 + 6 + 16 = 40.

      final opcodes = writer.toBytes();
      final data = Uint8List(60);
      for (var i = 0; i < opcodes.length; i++) data[10 + i] = opcodes[i];
      data[40] = opcRetnil;

      codePool.setCode(0, data);

      globals.framePtr = 20;
      stack.init();
      for (var i = 0; i < 30; i++) stack.push(T3Value(T3DataType.int32)..setInt(0));

      stack.setAt(20, T3Value(T3DataType.stack)..setStack(0));
      stack.setAt(18, T3Value(T3DataType.codeOfs)..setCodeOfs(0));
      stack.setAt(17, T3Value(T3DataType.codeOfs)..setCodeOfs(vmrunRetRecursive));

      globals.entryPtr = 0;
      globals.pc = 10;

      interpreter.run();
      expect(globals.pc, equals(vmrunRetRecursive));
    });

    test('opcThrow - Simple Catch', () {
      // Handler at offset 40 (relative to EntryPtr).
      // ExcTable defines range covering throw.

      final excTable = BytesBuilder();
      excTable.add([1, 0]); // Count=1
      excTable.add([10, 0]); // Start=10
      excTable.add([30, 0]); // End=30
      excTable.add([0xD2, 0x04, 0x00, 0x00]); // ExcClass=1234
      excTable.add([40, 0]); // Handler=40 (relative to function start)

      final writer = BytesBuilder();
      writer.addByte(opcPushObj);
      writer.add([0xD2, 0x04, 0x00, 0x00]); // 1234
      writer.addByte(opcThrow);

      final opcodes = writer.toBytes();

      final data = Uint8List(100);
      final view = ByteData.sublistView(data);

      // Header
      view.setUint16(6, 10 + opcodes.length, Endian.little); // ExcTable offset

      // Opcodes
      for (var i = 0; i < opcodes.length; i++) data[10 + i] = opcodes[i];

      // ExcTable
      final etData = excTable.toBytes();
      for (var i = 0; i < etData.length; i++) data[10 + opcodes.length + i] = etData[i];

      // Handler at 40
      data[40] = opcRetnil;

      codePool.setCode(0, data);

      // Setup Stack
      globals.framePtr = 20;
      stack.init();
      for (var i = 0; i < 30; i++) stack.push(T3Value(T3DataType.int32)..setInt(0));

      // Fixup frame metadata
      stack.setAt(20, T3Value(T3DataType.stack)..setStack(0)); // EncFP
      stack.setAt(18, T3Value(T3DataType.codeOfs)..setCodeOfs(0)); // EncEP
      stack.setAt(17, T3Value(T3DataType.codeOfs)..setCodeOfs(vmrunRetRecursive));

      globals.entryPtr = 0;
      globals.pc = 10;

      interpreter.run();

      expect(globals.pc, equals(vmrunRetRecursive));
      // Can't check stack easily as frame is popped.
    });

    test('opcThrow - Unhandled', () {
      // No ExcTable setup
      final writer = BytesBuilder();
      writer.addByte(opcPushObj);
      writer.add([123, 0, 0, 0]);
      writer.addByte(opcThrow);

      final opcodes = writer.toBytes();
      final data = Uint8List(50);
      for (var i = 0; i < opcodes.length; i++) data[10 + i] = opcodes[i];

      codePool.setCode(0, data);

      globals.framePtr = 20;
      stack.init();
      for (var i = 0; i < 30; i++) stack.push(T3Value(T3DataType.int32)..setInt(0));
      stack.setAt(20, T3Value(T3DataType.stack)..setStack(0));
      stack.setAt(18, T3Value(T3DataType.codeOfs)..setCodeOfs(0));
      stack.setAt(17, T3Value(T3DataType.codeOfs)..setCodeOfs(vmrunRetRecursive));

      globals.entryPtr = 0;
      globals.pc = 10;

      expect(() => interpreter.run(), throwsA(isA<T3VmException>()));
    });

    test('opcJe - Taken', () {
      final writer = BytesBuilder();
      writer.addByte(opcPush1);
      writer.addByte(opcPush1);
      writer.addByte(opcJe);
      writer.add([10, 0]); // Offset +10

      // PC: 10(Push1), 11(Push1), 12(Je), 13,14(Ofs). NextInstr=15.
      // Target = 15 + 10 = 25.

      final opcodes = writer.toBytes();
      final data = Uint8List(50);

      for (var i = 0; i < opcodes.length; i++) data[10 + i] = opcodes[i];
      data[25] = opcRetnil;

      codePool.setCode(0, data);

      globals.framePtr = 20;
      stack.init();
      for (var i = 0; i < 30; i++) stack.push(T3Value(T3DataType.int32)..setInt(0));

      // Fixup frame metadata
      stack.setAt(20, T3Value(T3DataType.stack)..setStack(0)); // EncFP
      stack.setAt(18, T3Value(T3DataType.codeOfs)..setCodeOfs(0)); // EncEP
      stack.setAt(17, T3Value(T3DataType.codeOfs)..setCodeOfs(vmrunRetRecursive));

      globals.entryPtr = 0;
      globals.pc = 10;

      interpreter.run();

      expect(globals.pc, equals(vmrunRetRecursive));
    });

    test('opcJne - Taken', () {
      // 1 != 2 -> Taken
      final writer = BytesBuilder();
      writer.addByte(opcPush1);
      writer.addByte(opcPushInt8);
      writer.addByte(2);
      writer.addByte(opcJne);
      writer.add([10, 0]); // Offset +10

      // PC: 10(Push1), 11(Push2), 12(Push2), 13(Jne), 14,15(Ofs). Next=16.
      // Target = 16 + 10 = 26.

      final opcodes = writer.toBytes();
      final data = Uint8List(50);
      for (var i = 0; i < opcodes.length; i++) data[10 + i] = opcodes[i];
      data[26] = opcRetnil;

      codePool.setCode(0, data);
      globals.framePtr = 20;
      stack.init();
      for (var i = 0; i < 30; i++) stack.push(T3Value(T3DataType.int32)..setInt(0));
      stack.setAt(20, T3Value(T3DataType.stack)..setStack(0));
      stack.setAt(18, T3Value(T3DataType.codeOfs)..setCodeOfs(0));
      stack.setAt(17, T3Value(T3DataType.codeOfs)..setCodeOfs(vmrunRetRecursive));

      globals.entryPtr = 0;
      globals.pc = 10;
      interpreter.run();
      expect(globals.pc, equals(vmrunRetRecursive));
    });

    test('opcJst - Taken (Short Circuit)', () {
      // Stack: [True]. Jst should jump and KEEP Top.
      final writer = BytesBuilder();
      writer.addByte(opcPushTrue);
      writer.addByte(opcJst);
      writer.add([10, 0]); // Offset +10

      // PC: 10(PushTrue), 11(Jst), 12,13. Next=14.
      // Target = 14 + 10 = 24.

      final opcodes = writer.toBytes();
      final data = Uint8List(50);
      for (var i = 0; i < opcodes.length; i++) data[10 + i] = opcodes[i];
      data[24] = opcRetnil;

      codePool.setCode(0, data);

      globals.framePtr = 20;
      stack.init();
      for (var i = 0; i < 30; i++) stack.push(T3Value(T3DataType.int32)..setInt(0));
      stack.setAt(20, T3Value(T3DataType.stack)..setStack(0));
      stack.setAt(18, T3Value(T3DataType.codeOfs)..setCodeOfs(0));
      stack.setAt(17, T3Value(T3DataType.codeOfs)..setCodeOfs(vmrunRetRecursive));

      globals.entryPtr = 0;
      globals.pc = 10;

      interpreter.run();

      expect(globals.pc, equals(vmrunRetRecursive));
    });

    test('opcJr0t - Taken', () {
      // R0 = True. Jr0t Taken.
      final writer = BytesBuilder();
      writer.addByte(opcJr0t);
      writer.add([10, 0]);

      // PC: 10(Jr0t), 11,12(Ofs). Next=13.
      // Target = 13 + 10 = 23.

      final opcodes = writer.toBytes();
      final data = Uint8List(50);
      for (var i = 0; i < opcodes.length; i++) data[10 + i] = opcodes[i];
      data[23] = opcRetnil;

      codePool.setCode(0, data);

      globals.r0.setTrue();
      globals.framePtr = 20;
      stack.init();
      for (var i = 0; i < 30; i++) stack.push(T3Value(T3DataType.int32)..setInt(0));
      stack.setAt(20, T3Value(T3DataType.stack)..setStack(0));
      stack.setAt(18, T3Value(T3DataType.codeOfs)..setCodeOfs(0));
      stack.setAt(17, T3Value(T3DataType.codeOfs)..setCodeOfs(vmrunRetRecursive));

      globals.entryPtr = 0;
      globals.pc = 10;

      interpreter.run();
      expect(globals.pc, equals(vmrunRetRecursive));
    });
  });
}
