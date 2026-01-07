import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_interpreter.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';
import 'dart:typed_data';
import 'package:zart/src/tads3/vm/t3_code_pool.dart';
import 'package:zart/src/tads3/vm/t3_constant_pool.dart';

void main() {
  group('Advanced VM Features', () {
    late T3Interpreter interpreter;

    setUp(() {
      interpreter = T3Interpreter();
    });

    test('t3GetStackTrace returns frame info', () {
      // Push arguments for the frame
      interpreter.stack.push(T3Value.fromInt(10));
      interpreter.stack.push(T3Value.fromInt(20));

      interpreter.stack.pushFrame(
        argCount: 2,
        localCount: 1,
        returnAddr: 0x100,
        entryPtr: 0x50,
        self: T3Value.fromObject(1000),
        targetObj: T3Value.fromObject(1001),
        definingObj: T3Value.fromObject(1002),
        targetProp: 500,
        invokee: T3Value.fromObject(2000),
      );

      interpreter.callBuiltin(1, 9, 0); // t3GetStackTrace

      final result = interpreter.registers.r0;
      expect(result.type, equals(T3DataType.list));

      final list = interpreter.getListElements(result);
      expect(list.length, greaterThan(0));

      final topFrameWrap = list[0];
      final topFrame = interpreter.getListElements(topFrameWrap);

      // [invokee, self, definingObj, propId, targetObj, argCount]
      expect(topFrame[0].value, equals(2000)); // invokee
      expect(topFrame[1].value, equals(1000)); // self
      expect(topFrame[2].value, equals(1002)); // definingObj
      expect(topFrame[3].value, equals(500)); // propId
      expect(topFrame[4].value, equals(1001)); // targetObj
      expect(topFrame[5].value, equals(2)); // argCount
    });

    test('t3GetNamedArg resolves arguments from table', () {
      final codePool = T3CodePool(poolId: 1, pageCount: 1, pageSize: 1024);
      final codeData = Uint8List(1024);
      // Table at 0x100
      codeData[0x100] = 0x01; // count = 1
      codeData[0x101] = 0x00;
      codeData[0x102] = 0x10; // name offset = 0x10
      codeData[0x103] = 0x00;
      codeData[0x104] = 0x00;
      codeData[0x105] = 0x00;
      codeData[0x106] = 0x01; // arg index = 1
      codeData[0x107] = 0x00;
      codePool.loadPage(0, codeData);

      final constPool = T3ConstantPool(poolId: 2, pageCount: 1, pageSize: 1024);
      final constData = Uint8List(1024);
      constData[0x10] = 3; // length
      constData[0x11] = 0;
      constData[0x12] = 102; // 'f'
      constData[0x13] = 111; // 'o'
      constData[0x14] = 111; // 'o'
      constPool.loadPage(0, constData);

      interpreter.codePool = codePool;
      interpreter.constantPool = constPool;

      interpreter.stack.push(T3Value.fromInt(42)); // Arg 1

      interpreter.stack.pushFrame(
        argCount: 1,
        localCount: 0,
        returnAddr: 0,
        entryPtr: 0,
        self: T3Value.nil(),
        targetObj: T3Value.nil(),
        definingObj: T3Value.nil(),
        targetProp: 0,
        invokee: T3Value.nil(),
        namedArgTableAddr: 0x100,
      );

      final strOffset = interpreter.addDynamicString('foo');
      interpreter.stack.push(T3Value.fromString(strOffset));

      interpreter.callBuiltin(1, 10, 1); // t3GetNamedArg('foo')

      expect(interpreter.registers.r0.value, equals(42));
    });

    test('t3GetNamedArgList returns list of names', () {
      final codePool = T3CodePool(poolId: 1, pageCount: 1, pageSize: 1024);
      final codeData = Uint8List(1024);
      // Table at 0x100
      codeData[0x100] = 0x01; // count = 1
      codeData[0x101] = 0x00;
      codeData[0x102] = 0x10; // name offset = 0x10
      codeData[0x103] = 0x00;
      codeData[0x104] = 0x00;
      codeData[0x105] = 0x00;
      codeData[0x106] = 0x01; // arg index = 1
      codeData[0x107] = 0x00;
      codePool.loadPage(0, codeData);

      final constPool = T3ConstantPool(poolId: 2, pageCount: 1, pageSize: 1024);
      final constData = Uint8List(1024);
      constData[0x10] = 3; // length
      constData[0x11] = 0;
      constData[0x12] = 102; // 'f'
      constData[0x13] = 111; // 'o'
      constData[0x14] = 111; // 'o'
      constPool.loadPage(0, constData);

      interpreter.codePool = codePool;
      interpreter.constantPool = constPool;

      interpreter.stack.pushFrame(
        argCount: 1,
        localCount: 0,
        returnAddr: 0,
        entryPtr: 0,
        self: T3Value.nil(),
        targetObj: T3Value.nil(),
        definingObj: T3Value.nil(),
        targetProp: 0,
        invokee: T3Value.nil(),
        namedArgTableAddr: 0x100,
      );

      interpreter.callBuiltin(1, 11, 0); // t3GetNamedArgList()

      final result = interpreter.registers.r0;
      expect(result.type, equals(T3DataType.list));

      final list = interpreter.getListElements(result);
      expect(list.length, equals(1));

      final nameVal = list[0];
      expect(interpreter.getStringValue(nameVal), equals('foo'));
    });
  });
}
