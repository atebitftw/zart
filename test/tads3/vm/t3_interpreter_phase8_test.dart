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

// Mock Code Pool (same as Phase 7)
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

  MockConstPool() : super(); // Initialize super with defaults? T3PoolInMem usually takes no args or calls super

  void setString(int id, String s) => _strings[id] = s;

  @override
  String getString(int offset) {
    if (_strings.containsKey(offset)) return _strings[offset]!;
    throw RangeError('String not found at $offset');
  }
}

void main() {
  group('T3Interpreter Phase 8 - Built-ins & Output', () {
    late T3Globals globals;
    late T3Interpreter interpreter;
    late MockCodePool codePool;
    late MockConstPool constPool;
    late T3Stack stack;
    late T3BifTable bifTable;
    late List<String> outputLog;

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

      outputLog = [];
      globals.printFn = (String s) {
        outputLog.add(s);
      };
    });

    tearDown(() {
      globals.dispose();
    });

    test('opcSay - Print String Constant', () {
      constPool.setString(100, 'Hello World');

      final writer = BytesBuilder();
      writer.addByte(opcSay);
      writer.add([100, 0, 0, 0]); // StrID = 100
      writer.addByte(opcRetnil); // Stop

      codePool.setCodeAt0(writer.toBytes());

      stack.init();
      globals.framePtr = 20;
      stack.setAt(20, T3Value(T3DataType.stack)..setStack(0));
      stack.setAt(18, T3Value(T3DataType.codeOfs)..setCodeOfs(0));
      stack.setAt(17, T3Value(T3DataType.codeOfs)..setCodeOfs(vmrunRetRecursive));

      globals.pc = 0;
      interpreter.run();

      expect(outputLog, contains('Hello World'));
    });

    test('opcSayVal - Print Stack Values', () {
      constPool.setString(200, 'TADS3 String');

      final writer = BytesBuilder();

      // 1. Print SSTRING
      writer.addByte(opcPushStr); // Push string offset
      writer.add([200, 0, 0, 0]);
      writer.addByte(opcSayVal);

      // 2. Print Int
      writer.addByte(opcPushInt8);
      writer.addByte(42);
      writer.addByte(opcSayVal);

      // 3. Print True
      writer.addByte(opcPushTrue);
      writer.addByte(opcSayVal);

      writer.addByte(opcRetnil);

      codePool.setCodeAt0(writer.toBytes());

      stack.init(); // Setup stack
      globals.framePtr = 20; // Dummy frame

      // Initialize stack frame for return
      stack.setAt(20, T3Value(T3DataType.stack)..setStack(0)); // EncFP
      stack.setAt(18, T3Value(T3DataType.codeOfs)..setCodeOfs(0)); // EncEP
      stack.setAt(17, T3Value(T3DataType.codeOfs)..setCodeOfs(vmrunRetRecursive)); // RetAddr

      globals.pc = 0;
      interpreter.run();

      expect(outputLog, equals(['TADS3 String', '42', 'true']));
    });

    test('opcBuiltinA - Call BIF Set 0', () {
      bool bifCalled = false;
      int passedArgc = -1;

      // Register BIF (Set 0, Index 5)
      bifTable.addFunc(0, 5, (argc) {
        bifCalled = true;
        passedArgc = argc;
      });

      final writer = BytesBuilder();
      writer.addByte(opcBuiltinA);
      writer.addByte(5); // FuncIdx
      writer.addByte(2); // Argc
      writer.addByte(opcRetnil);

      codePool.setCodeAt0(writer.toBytes());

      stack.init();
      globals.framePtr = 20;
      stack.setAt(20, T3Value(T3DataType.stack)..setStack(0));
      stack.setAt(18, T3Value(T3DataType.codeOfs)..setCodeOfs(0));
      stack.setAt(17, T3Value(T3DataType.codeOfs)..setCodeOfs(vmrunRetRecursive));

      globals.pc = 0;
      interpreter.run();

      expect(bifCalled, isTrue);
      expect(passedArgc, equals(2));
    });

    test('opcBuiltin1 - Call BIF Arbitrary Set', () {
      bool bifCalled = false;

      // Register BIF (Set 2, Index 10)
      bifTable.addFunc(2, 10, (argc) {
        bifCalled = true;
      });

      final writer = BytesBuilder();
      writer.addByte(opcBuiltin1);
      writer.addByte(2); // SetIdx
      writer.addByte(10); // FuncIdx
      writer.addByte(0); // Argc
      writer.addByte(opcRetnil);

      codePool.setCodeAt0(writer.toBytes());

      stack.init();
      globals.framePtr = 20;
      stack.setAt(20, T3Value(T3DataType.stack)..setStack(0));
      stack.setAt(18, T3Value(T3DataType.codeOfs)..setCodeOfs(0));
      stack.setAt(17, T3Value(T3DataType.codeOfs)..setCodeOfs(vmrunRetRecursive));

      globals.pc = 0;
      interpreter.run();

      expect(bifCalled, isTrue);
    });

    test('opcBuiltin2 - Call BIF 16-bit Func Index', () {
      bool bifCalled = false;

      // Register BIF (Set 1, Index 300)
      bifTable.addFunc(1, 300, (argc) {
        bifCalled = true;
      });

      final writer = BytesBuilder();
      writer.addByte(opcBuiltin2);
      writer.addByte(1); // SetIdx
      writer.add([44, 1]); // FuncIdx=300 (0x012C) -> Little Endian 2C 01
      writer.addByte(0); // Argc
      writer.addByte(opcRetnil); // Add terminating instruction

      codePool.setCodeAt0(writer.toBytes());

      stack.init();
      globals.framePtr = 20;
      stack.setAt(20, T3Value(T3DataType.stack)..setStack(0));
      stack.setAt(18, T3Value(T3DataType.codeOfs)..setCodeOfs(0));
      stack.setAt(17, T3Value(T3DataType.codeOfs)..setCodeOfs(vmrunRetRecursive));

      globals.pc = 0;
      interpreter.run();

      expect(bifCalled, isTrue);
    });
  });
}
