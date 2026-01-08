import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_interpreter.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_execution_helpers.dart';

/// T3 String Metaclass unit tests with spec validation.
///
/// Spec Reference: packages/tads-runner/tads3/vmstr.cpp (func_table_)
void main() {
  group('String metaclass methods per vmstr.cpp', () {
    late T3Interpreter interp;

    // Helper to create a T3Value string in dynamic memory
    T3Value makeStr(String s) {
      final offset = interp.execNextDynamicStringOffset++;
      interp.execDynamicStrings[offset] = s;
      return T3Value.fromString(offset);
    }

    setUp(() {
      interp = T3Interpreter();
    });

    group('length [1]', () {
      test('returns character count', () {
        final target = makeStr('hello');
        interp.handleStringIntrinsic(0, target, 0);
        expect(interp.registers.r0.value, 5);
      });
    });

    group('substr [2]', () {
      test('extracts substring', () {
        final target = makeStr('hello world');
        interp.stack.push(T3Value.fromInt(5));
        interp.stack.push(T3Value.fromInt(1));
        interp.handleStringIntrinsic(1, target, 2);
        expect(interp.execDynamicStrings[interp.registers.r0.value], 'hello');
      });
    });

    group('toUpper [3]', () {
      test('converts to uppercase', () {
        final target = makeStr('Hello World');
        interp.handleStringIntrinsic(2, target, 0);
        expect(interp.execDynamicStrings[interp.registers.r0.value], 'HELLO WORLD');
      });
    });

    group('toLower [4]', () {
      test('converts to lowercase', () {
        final target = makeStr('Hello World');
        interp.handleStringIntrinsic(3, target, 0);
        expect(interp.execDynamicStrings[interp.registers.r0.value], 'hello world');
      });
    });

    group('find [5]', () {
      test('finds substring position', () {
        final target = makeStr('hello world');
        final sub = makeStr('world');
        interp.stack.push(sub);
        interp.handleStringIntrinsic(4, target, 1);
        expect(interp.registers.r0.value, 7);
      });
    });

    group('toUnicode [6]', () {
      test('converts string to list of code points', () {
        final target = makeStr('ABC');
        interp.handleStringIntrinsic(5, target, 0);
        final listId = interp.registers.r0.value;
        expect(interp.objectTable.lookup(listId), isNotNull);
      });
    });

    group('htmlify [7]', () {
      test('escapes HTML characters', () {
        final target = makeStr('A < B');
        interp.handleStringIntrinsic(6, target, 0);
        expect(interp.execDynamicStrings[interp.registers.r0.value], 'A &lt; B');
      });
    });

    group('startsWith [8]', () {
      test('checks prefix match', () {
        final target = makeStr('hello world');
        final arg = makeStr('hello');
        interp.stack.push(arg);
        interp.handleStringIntrinsic(7, target, 1);
        expect(interp.registers.r0.type, T3DataType.true_);
      });
    });

    group('endsWith [9]', () {
      test('checks suffix match', () {
        final target = makeStr('hello world');
        final arg = makeStr('world');
        interp.stack.push(arg);
        interp.handleStringIntrinsic(8, target, 1);
        expect(interp.registers.r0.type, T3DataType.true_);
      });
    });

    group('toByteArray [10]', () {
      test('returns ByteArray object', () {
        final target = makeStr('hello');
        interp.handleStringIntrinsic(9, target, 0);
        expect(interp.registers.r0.isObject, isTrue);
        final obj = interp.objectTable.lookup(interp.registers.r0.value);
        expect(obj.runtimeType.toString(), contains('T3ByteArray'));
      });
    });

    group('replace [11]', () {
      test('replaces occurrences', () {
        final target = makeStr('foo-bar-foo');
        final oldStr = makeStr('foo');
        final newStr = makeStr('baz');
        interp.stack.push(T3Value.fromInt(0));
        interp.stack.push(newStr);
        interp.stack.push(oldStr);
        interp.handleStringIntrinsic(10, target, 3);
        expect(interp.execDynamicStrings[interp.registers.r0.value], 'baz-bar-baz');
      });
    });

    group('splice [12]', () {
      test('replaces range', () {
        final target = makeStr('123456');
        interp.stack.push(makeStr('foo')); // insert
        interp.stack.push(T3Value.fromInt(3)); // len
        interp.stack.push(T3Value.fromInt(2)); // idx
        interp.handleStringIntrinsic(11, target, 3);
        expect(interp.execDynamicStrings[interp.registers.r0.value], '1foo56');
      });
    });

    group('split [13]', () {
      test('splits by delimiter', () {
        final target = makeStr('a,b,c');
        interp.stack.push(T3Value.nil()); // limit
        interp.stack.push(makeStr(',')); // delim
        interp.handleStringIntrinsic(12, target, 2);
        final listId = interp.registers.r0.value;
        expect(interp.objectTable.lookup(listId), isNotNull);
      });
    });

    group('specialsToHtml [14]', () {
      test('stub returns original', () {
        final target = makeStr('test');
        interp.handleStringIntrinsic(13, target, 0);
        expect(interp.execDynamicStrings[interp.registers.r0.value], 'test');
      });
    });

    group('specialsToText [15]', () {
      test('stub returns original', () {
        final target = makeStr('test');
        interp.handleStringIntrinsic(14, target, 0);
        expect(interp.execDynamicStrings[interp.registers.r0.value], 'test');
      });
    });

    group('urlEncode [16]', () {
      test('encodes URL component', () {
        final target = makeStr('hello world');
        interp.handleStringIntrinsic(15, target, 0);
        expect(interp.execDynamicStrings[interp.registers.r0.value], 'hello%20world');
      });
    });

    group('urlDecode [17]', () {
      test('decodes URL component', () {
        final target = makeStr('hello%20world');
        interp.handleStringIntrinsic(16, target, 0);
        expect(interp.execDynamicStrings[interp.registers.r0.value], 'hello world');
      });
    });

    group('sha256 [18]', () {
      test('computes hash', () {
        final target = makeStr('hello');
        interp.handleStringIntrinsic(17, target, 0);
        expect(
          interp.execDynamicStrings[interp.registers.r0.value],
          '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824',
        );
      });
    });

    group('md5 [19]', () {
      test('computes hash', () {
        final target = makeStr('hello');
        interp.handleStringIntrinsic(18, target, 0);
        expect(interp.execDynamicStrings[interp.registers.r0.value], '5d41402abc4b2a76b9719d911017c592');
      });
    });

    group('packBytes [20]', () {
      test('stub returns nil', () {
        final target = makeStr('hello');
        interp.handleStringIntrinsic(19, target, 0);
        expect(interp.registers.r0.type, T3DataType.nil);
      });
    });

    group('unpackBytes [21]', () {
      test('stub returns nil', () {
        final target = makeStr('hello');
        interp.handleStringIntrinsic(20, target, 0);
        expect(interp.registers.r0.type, T3DataType.nil);
      });
    });

    group('toTitleCase [22]', () {
      test('capitalizes words', () {
        final target = makeStr('hello world');
        interp.handleStringIntrinsic(21, target, 0);
        expect(interp.execDynamicStrings[interp.registers.r0.value], 'Hello World');
      });
    });

    group('toFoldedCase [23]', () {
      test('folds case', () {
        final target = makeStr('HeLLo');
        interp.handleStringIntrinsic(22, target, 0);
        expect(interp.execDynamicStrings[interp.registers.r0.value], 'hello');
      });
    });

    group('compareTo [24]', () {
      test('compares less', () {
        final target = makeStr('a');
        interp.stack.push(makeStr('b'));
        interp.handleStringIntrinsic(23, target, 1);
        expect(interp.registers.r0.value, -1);
      });
    });

    group('compareIgnoreCase [25]', () {
      test('compares ignoring case', () {
        final target = makeStr('A');
        interp.stack.push(makeStr('a'));
        interp.handleStringIntrinsic(24, target, 1);
        expect(interp.registers.r0.value, 0);
      });
    });

    group('findLast [26]', () {
      test('finds last occurrence', () {
        final target = makeStr('hello world hello');
        final sub = makeStr('hello');
        interp.stack.push(T3Value.nil()); // index
        interp.stack.push(sub); // sub
        interp.handleStringIntrinsic(25, target, 2);
        expect(interp.registers.r0.value, 13);
      });
    });

    group('findAll [27]', () {
      test('finds all matches', () {
        final target = makeStr('hello');
        final re = makeStr('l');
        interp.stack.push(re); // regex
        interp.handleStringIntrinsic(26, target, 1);

        final listId = interp.registers.r0.value;
        final listObj = interp.objectTable.lookup(listId)!;
        expect(listObj.metaclass, 'list');
        // We happen to know the stub returns a list of matches strings.
        // 'l', 'l'.
      });
    });

    group('match [28]', () {
      test('finds match', () {
        final target = makeStr('hello');
        final re = makeStr('e');
        interp.stack.push(T3Value.nil()); // index
        interp.stack.push(re); // regex
        interp.handleStringIntrinsic(27, target, 2);
        expect(interp.execDynamicStrings[interp.registers.r0.value], 'e');
      });
    });
  });
}
