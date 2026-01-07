import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_interpreter.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';
import 'package:zart/src/tads3/vm/t3_lookup_table.dart';

void main() {
  group('Global Symbols', () {
    late T3Interpreter interpreter;

    setUp(() {
      interpreter = T3Interpreter();
    });

    test('t3GetGlobalSymbols returns populated LookupTable', () {
      // Add symbols
      interpreter.addGlobalSymbol('foo', T3Value.fromInt(123));
      interpreter.addGlobalSymbol('bar', T3Value.fromString(10));

      // Call t3GetGlobalSymbols
      interpreter.stack.pushFrame(
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

      interpreter.callBuiltin(1, 7, 0); // t3vm/7 = t3GetGlobalSymbols

      final result = interpreter.registers.r0;
      expect(result.type, equals(T3DataType.obj));
      final tableObj = interpreter.objectTable.lookup(result.value);
      expect(tableObj, isA<T3LookupTable>());

      final table = tableObj as T3LookupTable;

      // Note: entryCount check depends on whether 'bar' and 'foo' collide or not?
      // No, they are distinct.
      expect(table.entryCount, equals(2));

      bool foundFoo = false;
      bool foundBar = false;

      table.forEach((key, value) {
        final keyStr = interpreter.getStringValue(key);
        if (keyStr == 'foo') {
          expect(value.value, equals(123));
          foundFoo = true;
        } else if (keyStr == 'bar') {
          expect(value.value, equals(10)); // pool offset
          foundBar = true;
        }
      });

      expect(foundFoo, isTrue);
      expect(foundBar, isTrue);
    });
  });
}
