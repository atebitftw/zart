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

// Mock Code Pool (reused from Phase 8)
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
  bool validateOffset(int offset) => true;
  @override
  int? getOffsetFromPtr(Uint8List mem, int offsetInMem) => null;
}

// Mock Constant Pool for Strings
class MockConstPool extends T3PoolInMem {
  final Map<int, String> _strings = {};

  MockConstPool() : super();

  void setString(int id, String s) => _strings[id] = s;

  @override
  String getString(int offset) {
    if (_strings.containsKey(offset)) return _strings[offset]!;
    throw RangeError('String not found at $offset');
  }
}

void main() {
  group('T3Interpreter Phase 9 - VarArgs Opcodes', () {
    late T3Globals globals;
    late T3Interpreter interpreter;
    late MockCodePool codePool;
    late MockConstPool constPool;
    late T3Stack stack;
    late T3BifTable bifTable;

    setUp(() {
      globals = T3Globals();
      codePool = MockCodePool();
      constPool = MockConstPool();

      globals.codePool = codePool;
      globals.constPool = constPool;

      stack = T3Stack(100, 10);
      globals.stack = stack;
      globals.objTable = T3ObjectTable();

      bifTable = T3BifTable();
      globals.bifTable = bifTable;

      interpreter = T3Interpreter(globals);
      globals.interpreter = interpreter;
      globals.funchdrSize = 10;
    });

    tearDown(() {
      globals.dispose();
    });

    /// Helper to setup a minimal stack frame with argc
    void setupFrame({required int argc}) {
      stack.init();
      // Simulate a call with argc arguments
      // Setup a frame pointer at position 20
      globals.framePtr = 20;

      // Set frame slots:
      // FP+0: enclosing FP (stack type)
      stack.setAt(20, T3Value(T3DataType.stack)..setStack(0));
      // FP-1: argc
      stack.setAt(19, T3Value(T3DataType.int32)..setInt(argc));
      // FP-2: enclosing entry pointer
      stack.setAt(18, T3Value(T3DataType.codeOfs)..setCodeOfs(0));
      // FP-3: return address
      stack.setAt(
        17,
        T3Value(T3DataType.codeOfs)..setCodeOfs(vmrunRetRecursive),
      );
    }

    test('opcGetArgC - Push Argument Count', () {
      setupFrame(argc: 5);

      final writer = BytesBuilder();
      writer.addByte(opcGetArgC);
      writer.addByte(opcRetnil);

      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();

      // After run, return executed. Check R0 is nil (from retnil).
      expect(globals.r0.type, equals(T3DataType.nil));

      // But we need to check the stack had argc pushed before return.
      // Let's modify test to capture pushed value before return.
    });

    test('opcGetArgC - Verify Pushed Value', () {
      setupFrame(argc: 3);

      final writer = BytesBuilder();
      writer.addByte(opcGetArgC);
      writer.addByte(opcSetLcl1); // Store TOS in local 0
      writer.addByte(0); // Local index 0
      writer.addByte(opcRetnil);

      codePool.setCodeAt0(writer.toBytes());

      // Setup local 0 (at FP+1)
      stack.setAt(21, T3Value(T3DataType.nil));

      globals.pc = 0;
      interpreter.run();

      // Check local 0 contains argc value
      final local0 = stack.getRef(21);
      expect(local0.type, equals(T3DataType.int32));
      expect(local0.getAsInt(), equals(3));
    });

    test('opcMakeLstPar - Non-List Value Increments Counter', () {
      setupFrame(argc: 0);

      final writer = BytesBuilder();
      // Push initial counter = 2
      writer.addByte(opcPushInt8);
      writer.addByte(2);
      // Push a non-list value (integer 42)
      writer.addByte(opcPushInt8);
      writer.addByte(42);
      // Execute MAKELSTPAR
      writer.addByte(opcMakeLstPar);
      // Now stack should have: [42, 3] (value, incremented counter)
      // Store counter in local 0
      writer.addByte(opcSetLcl1);
      writer.addByte(0);
      writer.addByte(opcRetnil);

      codePool.setCodeAt0(writer.toBytes());
      stack.setAt(21, T3Value(T3DataType.nil));

      globals.pc = 0;
      interpreter.run();

      // Counter should be incremented to 3
      final local0 = stack.getRef(21);
      expect(local0.getAsInt(), equals(3));
    });

    test('opcVarArgC - Sets Modifier Flag', () {
      setupFrame(argc: 0);

      final writer = BytesBuilder();
      writer.addByte(opcVarArgC);
      writer.addByte(opcRetnil);

      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();

      // Just verify it doesn't throw - the flag is internal
      expect(globals.r0.type, equals(T3DataType.nil));
    });

    test('opcPushParLst - Creates List Placeholder', () {
      // Setup frame with 5 args (2 fixed, 3 varargs)
      stack.init();
      globals.framePtr = 20;

      // Set frame slots
      stack.setAt(20, T3Value(T3DataType.stack)..setStack(0));
      stack.setAt(19, T3Value(T3DataType.int32)..setInt(5)); // argc = 5
      stack.setAt(18, T3Value(T3DataType.codeOfs)..setCodeOfs(0));
      stack.setAt(
        17,
        T3Value(T3DataType.codeOfs)..setCodeOfs(vmrunRetRecursive),
      );

      // Set 5 arguments (at FP-11, FP-12, FP-13, FP-14, FP-15)
      // vmrunFpOfsArg1 = -11
      stack.setAt(9, T3Value(T3DataType.int32)..setInt(100)); // arg 0
      stack.setAt(8, T3Value(T3DataType.int32)..setInt(200)); // arg 1
      stack.setAt(7, T3Value(T3DataType.int32)..setInt(300)); // arg 2 (vararg)
      stack.setAt(6, T3Value(T3DataType.int32)..setInt(400)); // arg 3 (vararg)
      stack.setAt(5, T3Value(T3DataType.int32)..setInt(500)); // arg 4 (vararg)

      final writer = BytesBuilder();
      writer.addByte(opcPushParLst);
      writer.addByte(2); // fixedCnt = 2
      writer.addByte(opcRetval); // Return TOS (the list)

      codePool.setCodeAt0(writer.toBytes());
      globals.pc = 0;
      interpreter.run();

      // R0 should contain a list placeholder with count 3
      expect(globals.r0.type, equals(T3DataType.list));
    });
  });
}
