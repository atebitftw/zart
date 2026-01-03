import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_interpreter.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';
import 'package:zart/src/tads3/vm/t3_builtins.dart';

void main() {
  group('T3 Built-ins Implementation', () {
    late T3Interpreter interp;

    setUp(() {
      interp = T3Interpreter();
    });

    test('datatype() returns correct index', () {
      // Setup stack with 1 argument (an integer)
      interp.stack.push(T3Value.fromInt(123));

      // Call datatype(123)
      final func = T3BuiltinRegistry.getFunction('tads-gen', 0); // 0 = datatype
      expect(func, isNotNull);

      func!(interp, 1);

      // Result should be in R0: index of T3DataType.int (which is 7)
      expect(interp.registers.r0.type, equals(T3DataType.int_));
      expect(interp.registers.r0.value, equals(T3DataType.int_.code));
    });

    test('getarg() retrieves argument', () {
      // TADS3 pushes arguments R-to-L.
      // 1. Push Arg 3
      interp.stack.push(T3Value.fromInt(333));
      // 2. Push Arg 2
      interp.stack.push(T3Value.fromInt(222));
      // 3. Push Arg 1
      interp.stack.push(T3Value.fromInt(111));

      // Now create the frame
      interp.stack.pushFrame(
        argCount: 3,
        localCount: 5, // 3 args + 2 locals
        returnAddr: 0,
        entryPtr: 0,
        self: T3Value.nil(),
        targetObj: T3Value.nil(),
        definingObj: T3Value.nil(),
        targetProp: 0,
        invokee: T3Value.nil(),
      );

      // Call getarg(2) -> gets Argument 2 (222)
      interp.stack.push(T3Value.fromInt(2));
      final func = T3BuiltinRegistry.getFunction('tads-gen', 1); // 1 = getarg
      expect(func, isNotNull);

      func!(interp, 1);

      // Result in R0 should be 222
      expect(interp.registers.r0.value, equals(222));

      // Also verify that it's in the local area
      expect(interp.stack.getLocal(0).value, equals(111)); // Local 1 (Arg 1)
      expect(interp.stack.getLocal(1).value, equals(222)); // Local 2 (Arg 2)
    });

    test('getVmVsn() returns T3 version', () {
      final func = T3BuiltinRegistry.getFunction('t3vm', 2); // 2 = getVmVsn
      expect(func, isNotNull);

      func!(interp, 0);

      expect(interp.registers.r0.type, equals(T3DataType.int_));
      expect(interp.registers.r0.value, equals(0x030100)); // 3.1.0
    });
  });
}
