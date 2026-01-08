import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_opcodes.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';

import 'opcode_test_harness.dart';

void main() {
  group('T3 List Expansion and Parameter Collection', () {
    test('PUSHPARLST creates empty list when no excess args (fixedCount == actualArgc)', () {
      final h = OpcodeTestHarness();
      // Setup frame with 0 arguments
      h.addArgs([]);

      h.emit(T3Opcodes.PUSHPARLST);
      h.emitByte(0); // fixed parameters count

      h.build(argCount: 0);
      h.step();

      // Should satisfy: proper list object, empty elements
      final result = h.peek();
      expect(result.isList, isTrue);

      final elements = h.getListValues(result);
      expect(elements, isEmpty);
    });

    test('PUSHPARLST creates empty list when fixedCount == actualArgc (non-zero args)', () {
      final h = OpcodeTestHarness();
      // Setup frame with 2 arguments
      h.addArgs([T3Value.fromInt(1), T3Value.fromInt(2)]);

      h.emit(T3Opcodes.PUSHPARLST);
      h.emitByte(2); // fixed parameters count = 2

      h.build(argCount: 2);
      h.step();

      final result = h.peek();
      expect(result.isList, isTrue);
      final elements = h.getListValues(result);
      expect(elements, isEmpty);
    });

    test('PUSHPARLST collects excess args into list', () {
      final h = OpcodeTestHarness();
      // Setup frame with 3 arguments: [1, 2, 3]
      h.addArgs([T3Value.fromInt(1), T3Value.fromInt(2), T3Value.fromInt(3)]);

      h.emit(T3Opcodes.PUSHPARLST);
      h.emitByte(1); // fixed parameters count = 1

      h.build(argCount: 3);
      h.step();

      final result = h.peek();
      expect(result.isList, isTrue);
      final elements = h.getListValues(result);
      expect(elements.length, equals(2));
      expect(elements[0].value, equals(2));
      expect(elements[1].value, equals(3));
    });

    test('MAKELSTPAR expansions of nil results in zero arguments', () {
      final h = OpcodeTestHarness();

      h.emit(T3Opcodes.PUSHINT);
      h.emitInt32(5); // initial arg count
      h.emit(T3Opcodes.PUSHNIL); // list to expand (nil)

      h.emit(T3Opcodes.MAKELSTPAR);

      h.build();
      h.runSteps(3);

      // Stack should have updated count (still 5)
      final newCount = h.pop();
      expect(newCount.isInt, isTrue);
      expect(newCount.value, equals(5));

      // Nil should have been popped
      // Stack should just have the initial count 5 below (which we pushed first? No wait)
      // Usage: stack is [..., count, list] -> [..., arg1, arg2, ..., newCount]
      // We start with [count=5, list=nil]
      // Result: [args..., newCount=5] (no new args pushed)
    });

    test('MAKELSTPAR expansions of empty list results in zero arguments', () {
      final h = OpcodeTestHarness();

      // Add empty list to constant pool
      final listOffset = h.addList([]);

      h.emit(T3Opcodes.PUSHINT);
      h.emitInt32(5); // initial arg count

      h.emit(T3Opcodes.PUSHLST);
      h.emitUint32(listOffset);

      h.emit(T3Opcodes.MAKELSTPAR);

      h.build();
      h.runSteps(4);

      final newCount = h.pop();
      expect(newCount.value, equals(5));
    });

    test('MAKELSTPAR expansions of non-empty list works correctly', () {
      final h = OpcodeTestHarness();

      // Add list [10, 20] to constant pool
      final listOffset = h.addList([T3Value.fromInt(10), T3Value.fromInt(20)]);

      h.emit(T3Opcodes.PUSHINT);
      h.emitInt32(5); // initial arg count

      h.emit(T3Opcodes.PUSHLST);
      h.emitUint32(listOffset);

      h.emit(T3Opcodes.MAKELSTPAR);

      h.build();
      h.runSteps(4);

      final newCount = h.pop();
      expect(newCount.value, equals(7)); // 5 + 2

      // Args pushed in reverse order so top is last arg?
      // Wait, TADS3 calling convention:
      // arguments are pushed left-to-right?
      // Opcode spec: "Push elements in reverse order so first is at top (as Arg0)"
      // Actually code says:
      // for (var i = elements.length - 1; i >= 0; i--) { _stack.push(elements[i]); }
      // So last element is pushed first, first element is pushed last (top of stack).

      final val1 = h.pop(); // First element (10)
      final val2 = h.pop(); // Second element (20)

      expect(val1.value, equals(10));
      expect(val2.value, equals(20));
    });
  });
}
