import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_interpreter.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';
import 'package:zart/src/tads3/vm/t3_opcodes.dart';

void main() {
  group('Named arguments per opcode.htm', () {
    test('NAMEDARGTAB opcode constant (0x57)', () {
      expect(T3Opcodes.NAMEDARGTAB, 0x57);
    });

    test('NAMEDARGPTR opcode constant (0x56)', () {
      expect(T3Opcodes.NAMEDARGPTR, 0x56);
    });

    test('VARARGC opcode constant (0x76)', () {
      expect(T3Opcodes.VARARGC, 0x76);
    });
  });

  group('Interpreter NAMEDARGPTR support', () {
    test('setting pending named arg table addr', () {
      final interpreter = T3Interpreter();
      expect(interpreter.pendingNamedArgTableAddr, isNull);
      interpreter.clearPendingNamedArgTable();
      expect(interpreter.pendingNamedArgTableAddr, isNull);
    });
  });

  group('T3Stack named argument support', () {
    test('pushFrame and popFrame propagate namedArgTableAddr', () {
      final interpreter = T3Interpreter();
      final stack = interpreter.stack;

      // Push a frame with a named arg table addr
      stack.pushFrame(
        returnAddr: 0x1000,
        argCount: 0,
        localCount: 0,
        entryPtr: 0,
        self: T3Value.nil(),
        targetObj: T3Value.nil(),
        definingObj: T3Value.nil(),
        targetProp: 0,
        invokee: T3Value.nil(),
        namedArgTableAddr: 0x5000,
      );

      // Pop it
      final result = stack.popFrame();
      expect(result.$4, 0x5000);
    });
  });
}
