import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_interpreter.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';

void main() {
  group('T3 ADD operator concatenation tests', () {
    late T3Interpreter interp;

    setUp(() {
      interp = T3Interpreter();
      // Setup a minimal frame
      interp.stack.pushFrame(
        argCount: 0,
        localCount: 0,
        returnAddr: 0,
        entryPtr: 0,
        self: T3Value.nil(),
        targetObj: T3Value.nil(),
        definingObj: T3Value.nil(),
        targetProp: 0,
        invokee: T3Value.nil(),
      );
    });

    test('string + int concatenation', () {
      final s1 = interp.addDynamicString('count: ');
      final v1 = T3Value.fromString(s1);
      final v2 = T3Value.fromInt(42);

      interp.t3Add(v1, v2);
      final result = interp.stack.pop();

      expect(result.isStringLike, isTrue);
      expect(interp.getStringValue(result), 'count: 42');
    });

    test('int + string concatenation', () {
      final v1 = T3Value.fromInt(123);
      final s2 = interp.addDynamicString(' is the way');
      final v2 = T3Value.fromString(s2);

      interp.t3Add(v1, v2);
      final result = interp.stack.pop();

      expect(result.isStringLike, isTrue);
      expect(interp.getStringValue(result), '123 is the way');
    });

    test('string + nil concatenation', () {
      final s1 = interp.addDynamicString('value: ');
      final v1 = T3Value.fromString(s1);
      final v2 = T3Value.nil();

      interp.t3Add(v1, v2);
      final result = interp.stack.pop();

      expect(result.isStringLike, isTrue);
      expect(interp.getStringValue(result), 'value: ');
    });

    test('string + list concatenation', () {
      final s1 = interp.addDynamicString('list: ');
      final v1 = T3Value.fromString(s1);
      final listId = interp.addDynamicList([T3Value.fromInt(1), T3Value.fromInt(2)]);
      final v2 = T3Value.fromList(listId);

      interp.t3Add(v1, v2);
      final result = interp.stack.pop();

      expect(result.isStringLike, isTrue);
      expect(interp.getStringValue(result), 'list: [1 2]');
    });

    test('complex string concatenation (basic.t pattern)', () {
      // 'iter[' + iter + ']: ' + i + '! = ' + j + '\n'
      // Simulated: 'iter[' + 0 + ']: '

      final s1 = interp.addDynamicString('iter[');
      final v1 = T3Value.fromString(s1);
      final v2 = T3Value.fromInt(0);

      interp.t3Add(v1, v2);
      final r1 = interp.stack.pop();

      final s3 = interp.addDynamicString(']: ');
      final v3 = T3Value.fromString(s3);

      interp.t3Add(r1, v3);
      final r2 = interp.stack.pop();

      expect(interp.getStringValue(r2), 'iter[0]: ');
    });
  });
}
