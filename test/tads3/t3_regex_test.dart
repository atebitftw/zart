import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_constant_pool.dart'; // Needed for T3ConstantPool interface
import 'package:zart/src/tads3/vm/t3_interpreter.dart';
import 'package:zart/src/tads3/vm/t3_object_table.dart';
import 'package:zart/src/tads3/vm/t3_regex_pattern.dart';
import 'package:zart/src/tads3/vm/t3_builtin_regex.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';
import 'package:zart/src/tads3/vm/t3_stack.dart';
import 'package:zart/src/tads3/vm/t3_registers.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';

// Simple Mock classes

// MockConstantPool implements T3ConstantPool via noSuchMethod for missing members
class MockConstantPool implements T3ConstantPool {
  final Map<int, String> strings = {};

  // Implement readString to match T3ConstantPool
  @override
  String readString(int offset) => strings[offset] ?? '';

  // Return noSuchMethod for other members like pageCount, etc. if accessed (test shouldn't access them)
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockInterpreter implements T3Interpreter {
  @override
  final T3Stack stack = T3Stack(maxDepth: 1024); // Fix: use named arg

  @override
  final T3ObjectTable objectTable = T3ObjectTable();

  @override
  final T3Registers registers = T3Registers();

  // Override constantPool to be compatible with T3Interpreter signature (T3ConstantPool?)
  @override
  final MockConstantPool constantPool = MockConstantPool();

  @override
  Match? lastRegexMatch; // Fix: use Match?

  @override
  String? lastRegexString;

  // T3Interpreter doesn't strictly require objects map, but if we need to access objects by ID for testing:
  T3Object? getObject(int id) => objectTable.lookup(id);

  @override
  int addDynamicString(String s) {
    // Just mock it: stash string in constant pool for retrieval
    int id = constantPool.strings.length + 1000;
    constantPool.strings[id] = s;
    return id;
  }

  @override
  int addDynamicList(List<T3Value> list) {
    // Mock: return a dummy ID.
    return 2000;
  }

  @override
  String getStringValue(T3Value val) {
    if (val.isString) return constantPool.readString(val.value); // Fix: use readString
    if (val.isObject) {
      // If tests use string objects, we'd need to mock looking them up.
      // For now tests assume constant pool strings.
    }
    return '';
  }

  // Missing members for T3Interpreter interface implementation...
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Extension to help with registers access
extension MockInterpRegs on MockInterpreter {
  T3Value get r0 => registers.r0;
}

void main() {
  group('T3RegexPattern Metaclass', () {
    test('Creation and Serialization', () {
      final sourceVal = T3Value.fromString(123); // Mock string offset
      final regex = T3RegexPattern.create(1, sourceVal);

      expect(regex.metaclass, 'regex-pattern');
      expect(regex.source.value, 123);

      final data = regex.save();
      expect(data.length, 5); // 1 byte type, 4 byte value

      final restored = T3RegexPattern.fromData(1, data);
      expect(restored.source.value, 123);
      expect(restored.source.type, T3DataType.sstring);
    });

    test('getRegExp caching', () {
      // Setup mock interpreter and constant pool
      final mockInterp = MockInterpreter();
      mockInterp.constantPool.strings[123] = 'abc+';

      final sourceVal = T3Value.fromString(123);
      final regex = T3RegexPattern.create(2, sourceVal);

      // First call compiles
      final re1 = regex.getRegExp(mockInterp);
      expect(re1.hasMatch('abccc'), isTrue);

      // Second call returns cached
      final re2 = regex.getRegExp(mockInterp);
      expect(identical(re1, re2), isTrue);
    });
  });

  group('T3BuiltinRegex Functions', () {
    late MockInterpreter interp;

    setUp(() {
      interp = MockInterpreter();
    });

    test('reMatch string pattern', () {
      interp.constantPool.strings[1] = r'hel+o';
      interp.constantPool.strings[2] = 'helllo world';

      // Push args: pattern, str
      interp.stack.push(T3Value.fromString(2)); // str
      interp.stack.push(T3Value.fromString(1)); // pattern

      T3BuiltinRegex.reMatch(interp, 2);

      // Match length should be 6 ("helllo")
      expect(interp.r0.value, 6);
      expect(interp.lastRegexMatch, isNotNull);
    });

    test('reMatch RegexPattern object', () {
      interp.constantPool.strings[10] = r'\d+';
      interp.constantPool.strings[20] = 'a123b';

      // Create RegexPattern object
      final regexObj = T3RegexPattern.create(5, T3Value.fromString(10));
      interp.objectTable.register(regexObj);

      // Push args: index (Arg3), str (Arg2), pattern object (Arg1)
      interp.stack.push(T3Value.fromInt(2)); // index 2 (start at '1')
      interp.stack.push(T3Value.fromString(20)); // str
      interp.stack.push(T3Value.fromObject(5)); // pattern object

      T3BuiltinRegex.reMatch(interp, 3);

      expect(interp.r0.value, 3); // "123" length
    });

    test('reSearch forward', () {
      interp.constantPool.strings[1] = 'bar';
      interp.constantPool.strings[2] = 'foo bar baz';

      interp.stack.push(T3Value.fromString(2));
      interp.stack.push(T3Value.fromString(1));

      T3BuiltinRegex.reSearch(interp, 2);

      // Implementation returns a list. Our mock addDynamicList returns dummy 2000.
      expect(interp.r0.value, 2000); // List ID
      expect(interp.lastRegexMatch!.group(0), 'bar'); // lastRegexMatch is Match?
      // Match doesn't have 'start' property directly exposed if strict type Match? but RegExpMatch does.
      // We can cast or use noSuchMethod dynamic dispatch for test... or explicit cast.
      // But lastRegexMatch is Match? which has 'start'. Yes it does.
      expect(interp.lastRegexMatch!.start, 4);
    });

    test('reSearchBack', () {
      interp.constantPool.strings[1] = 'a';
      interp.constantPool.strings[2] = 'banana';

      interp.stack.push(T3Value.fromString(2));
      interp.stack.push(T3Value.fromString(1));

      T3BuiltinRegex.reSearchBack(interp, 2);

      expect(interp.lastRegexMatch!.start, 5); // last 'a' at index 5
    });

    test('reReplace', () {
      interp.constantPool.strings[1] = 'foo';
      interp.constantPool.strings[2] = 'foo bar foo';
      interp.constantPool.strings[3] = 'BAZ'; // replacement

      // Push: flags, replacement, str, pattern (Arg4, Arg3, Arg2, Arg1)
      interp.stack.push(T3Value.fromInt(1)); // Flags: 1 = ReplaceAll
      interp.stack.push(T3Value.fromString(3)); // replacement
      interp.stack.push(T3Value.fromString(2)); // str
      interp.stack.push(T3Value.fromString(1)); // pattern

      T3BuiltinRegex.reReplace(interp, 4);

      // Result should be stored in dynamic string pool
      // Verification implicitly checks via r0 being set to string
      expect(interp.r0.isString, isTrue);

      // Access the last added string to verify content?
      // Our mock addDynamicString uses 1000+ IDs.
      final resultId = interp.r0.value;
      final resultStr = interp.constantPool.strings[resultId];
      expect(resultStr, 'BAZ bar BAZ');
    });

    test('reGroup', () {
      interp.constantPool.strings[1] = r'(\w+) (\d+)';
      interp.constantPool.strings[2] = 'Item 42';

      interp.stack.push(T3Value.fromString(2));
      interp.stack.push(T3Value.fromString(1));
      T3BuiltinRegex.reMatch(interp, 2);

      // Get group 2
      interp.stack.push(T3Value.fromInt(2));
      T3BuiltinRegex.reGroup(interp, 1);

      // Should return list (mock 2000)
      expect(interp.r0.isList, isTrue);
      expect(interp.lastRegexMatch!.group(2), '42');
    });
  });
}
