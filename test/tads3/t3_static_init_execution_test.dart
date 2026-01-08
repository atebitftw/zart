import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_interpreter.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';
import 'package:zart/src/tads3/vm/t3_opcodes.dart';
import 'opcode_test_harness.dart';

void main() {
  group('T3 SINI Execution', () {
    test('runSynchronousTask executes property evaluation to completion', () {
      final h = OpcodeTestHarness();

      // Create an object with a property that performs a side effect
      final objId = h.interpreter.objectTable.createDynamicObject('tads-object', [], isTransient: false);

      // Create a marker object to store the result
      final markerObjId = h.interpreter.objectTable.createDynamicObject('tads-object', [], isTransient: false);
      h.interpreter.setPropertyValue(T3Value.fromObject(markerObjId), 200, T3Value.fromInt(0));

      // Add a function for prop 100 on objId
      final funcOfs = h.currentOffset;
      // Header: 0 args, 0 locals, no varargs
      h.addFunction([0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);

      // Implementation: markerObjId.prop200 = 123
      h.emit(T3Opcodes.PUSHINT8, offset: funcOfs + 10);
      h.emitByte(123);
      h.emit(T3Opcodes.OBJSETPROP);
      h.emitUint32(markerObjId);
      h.emitUint16(200);
      h.emit(T3Opcodes.RETNIL);

      h.interpreter.setPropertyValue(T3Value.fromObject(objId), 100, T3Value.fromCodeOffset(funcOfs));

      h.build();

      // Trigger the execution manually (like SINI would)
      h.interpreter.runSynchronousTask(() {
        h.interpreter.evalProperty(T3Value.fromObject(objId), 100);
      });

      final val = h.interpreter.objectTable.lookupProperty(markerObjId, 200)?.value;
      expect(val?.value, 123);
    });
  });
}
