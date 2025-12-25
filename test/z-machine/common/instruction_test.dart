//first (most significant) byte
import 'dart:async';

import 'package:test/test.dart';
import 'package:zart/src/z_machine/interpreters/interpreter_v3.dart';
import 'package:zart/src/z_machine/math_helper.dart';
import 'package:zart/src/z_machine/operand.dart';
import 'package:zart/src/zart_internal.dart'; // Added for Z
import '../test_utils.dart';

int fst(int word) => word >> 8;
//second (least significant) byte
int snd(int word) => word & 0xff;

//this is a testing facility to run simulated instructions against the machine
void main() {
  setupZMachine();

  const callAddr = 0x4f04;
  const testRoutineAddr = 0xae60;
  const testRoutineEndAddr = 0xafa5;
  const maxTestRoutineLength = (testRoutineEndAddr + 1) - testRoutineAddr;
  const stackPointer = 0;

  final testRoutineRestoreBytes = Z.engine.mem.getRange(
    testRoutineAddr,
    maxTestRoutineLength,
  );

  void injectRoutine(List<int> locals, List<int> instructionBytes) {
    Z.engine.mem.storeb(testRoutineAddr, locals.length);

    //write the locals
    var start = testRoutineAddr + 1;

    for (final l in locals) {
      Z.engine.mem.storew(start, l);
      start += 2;
    }

    //write the instructions
    for (final b in instructionBytes) {
      Z.engine.mem.storeb(start, b);
      start++;
    }
  }

  List<Operand> createVarParamList(item1, [item2, item3, item4]) {
    List<int> kindList = [];
    List<Operand> paramList = [];

    int getKind(item) {
      if (item == null) {
        return OperandType.omitted;
      }

      if (item is String) {
        return OperandType.variable;
      } else {
        if (item <= 0xFF) {
          return OperandType.small;
        }
        return OperandType.large;
      }
    }

    int convertToVariableLiteral(String item) {
      //convert to variable literal
      if (item.toLowerCase() == 'sp') {
        return 0;
      }

      var varType = item.substring(0, 1);
      switch (varType.toLowerCase()) {
        case 'g':
          // G0 = 16, G1 = 17, etc
          return int.parse(item.substring(1, item.length - 1)) + 0x10;
        case 'l':
          // L0 = 1, L1 = 2, etc
          return int.parse(item.substring(1, item.length - 1)) + 0x01;
        default:
          throw Exception('variable type not recognized: $varType');
      }
    }

    //load the kinds and create the kind byte
    kindList.add(getKind(item1));
    kindList.add(getKind(item2));
    kindList.add(getKind(item3));
    kindList.add(getKind(item4));

    var operandByte = Operand(OperandType.omitted);
    operandByte.rawValue = Operand.createVarOperandByte(kindList);
    paramList.add(operandByte);

    //convert any variable types to literals
    paramList.add(Operand(kindList[0]));
    paramList.add(Operand(kindList[1]));
    paramList.add(Operand(kindList[2]));
    paramList.add(Operand(kindList[3]));

    paramList[1].rawValue = (kindList[0] == OperandType.variable)
        ? convertToVariableLiteral(item1)
        : item1;
    paramList[2].rawValue = (kindList[1] == OperandType.variable)
        ? convertToVariableLiteral(item2)
        : item2;
    paramList[3].rawValue = (kindList[2] == OperandType.variable)
        ? convertToVariableLiteral(item3)
        : item3;
    paramList[4].rawValue = (kindList[3] == OperandType.variable)
        ? convertToVariableLiteral(item4)
        : item4;

    return paramList;
  }

  runRoutine([param1, param2, param3]) {
    var operandList = createVarParamList(
      Z.engine.pack(testRoutineAddr),
      param1,
      param2,
      param3,
    );
    Z.quit = false;

    var callInstruction = [224];

    // var operand types byte
    callInstruction.add((operandList[0]).rawValue!);

    // write the operands
    for (final operand in operandList.getRange(1, 4)) {
      if (operand.oType == OperandType.omitted) {
        break;
      }
      if (operand.oType == OperandType.large) {
        callInstruction.add(fst(operand.rawValue!));
        callInstruction.add(snd(operand.rawValue!));
      } else {
        callInstruction.add(operand.rawValue!);
      }
    }

    //Debugger.debug(callInstruction);

    // return value to the stack
    callInstruction.add(stackPointer);
    //QUIT opcode
    callInstruction.add(186);

    //write out the routine
    var addr = callAddr + 1;

    for (final inst in callInstruction) {
      Z.engine.mem.storeb(addr, inst);
      addr++;
    }

    //clear stacks and reset program counter
    Z.engine.stack.clear();
    Z.engine.callStack.clear();

    // Set up a dummy routine header with 0 locals at callAddr
    Z.engine.mem.storeb(callAddr, 0);
    Z.engine.programCounter = callAddr;

    // visit the main 'routine'
    Z.engine.visitRoutine([]);

    //push dummy result store onto the call stack
    Z.engine.callStack.push(0);

    //push dummy return address onto the call stack
    Z.engine.callStack.push(0);

    //    Debugger.debug('${Z.machine.mem.dump(callAddr, 20)}');

    Z.callAsync(Z.runUntilInput);
  }

  void restoreRoutine() {
    var start = testRoutineAddr;

    for (final b in testRoutineRestoreBytes) {
      Z.engine.mem.storeb(start++, b);
    }
  }

  group('instructions>', () {
    group('setup>', () {
      test('test routine check', () {
        //first/last byte of testRoutineRestore is correct
        expect(
          Z.engine.mem.loadb(testRoutineAddr),
          equals(testRoutineRestoreBytes[0]),
        );
        expect(
          Z.engine.mem.loadb(testRoutineEndAddr),
          equals(testRoutineRestoreBytes.last),
        );
      });

      test('routine restore check', () {
        var start = testRoutineAddr;

        //zero out the routine memory
        for (final _ in testRoutineRestoreBytes) {
          Z.engine.mem.storeb(start++, 0);
        }

        start = testRoutineAddr;
        //validate 0's
        for (final _ in testRoutineRestoreBytes) {
          expect(0, equals(Z.engine.mem.loadb(start++)));
        }

        restoreRoutine();

        start = testRoutineAddr;

        //validate restore
        for (final b in testRoutineRestoreBytes) {
          expect(b, equals(Z.engine.mem.loadb(start++)));
        }
      });

      test('inject routine', () {
        injectRoutine([0xffff, 0xeeee, 0x0, 0x0, 0x0, 0x0], []);
        var testBytes = [0x6, 0xff, 0xff, 0xee, 0xee, 0, 0, 0, 0];
        var routine = Z.engine.mem.getRange(testRoutineAddr, testBytes.length);

        int i = 0;
        for (final b in routine) {
          expect(testBytes[i++], equals(b));
        }

        restoreRoutine();
      });
    });

    Future<int> pollUntilQuit() {
      Completer c = Completer();

      doIt() {
        if (Z.quit) {
          c.complete(Z.engine.stack.pop());
        } else {
          Timer(const Duration(seconds: 0), doIt);
        }
      }

      Timer(const Duration(seconds: 0), doIt);

      return c.future.then((value) => value as int);
    }

    group("tests>", () {
      /*
* Tests in this group generally follow the following pattern:
* 1.  inject a routine (with locals defined if needed):
*    //injects a routine with 2 locals and opcode 0xb0 (rtrue)
*    injectRoutine([0x0, 0x0],[0xb0]);
*
* 2. Call the routine with 1 to 3 optional parameters:
*    // runs the routine with no parameters passed
*    runRoutine();
*
*    // passes a few values in
*    runRoutine(0xFFFF, 0x42);
*
* 3.  Call future pollUntilQuit which returns the value return by the
*     injected function:
*
*    pollUntilQuit().then((v){
*        Expect.equals(42, v);
*        callbackDone(); //important!
*    });
*
*/

      test('simple return true', () async {
        injectRoutine([], [0xb0]); //RTRUE
        //Debugger.enableAll();

        runRoutine();

        var v = await pollUntilQuit();
        expect(InterpreterV3.gameTrue, equals(v));
      });

      test('simple return false', () async {
        injectRoutine([], [0xb1]); //RFALSE
        runRoutine();

        var v = await pollUntilQuit();
        expect(InterpreterV3.gameFalse, equals(v));
      });

      test('push non-negative small', () async {
        /*
        * PUSH L00 (25)
        * RET SP
        */
        injectRoutine([0x0], [0xe8, 0xbf, 0x01, 0xab, 0x00]);
        runRoutine(25);

        final v = await pollUntilQuit();
        expect(25, equals(v));
      });

      test('push non-negative big', () async {
        /*
        * PUSH L00 (0xFFFF)
        * RET SP
        */
        injectRoutine([0x0], [0xe8, 0xbf, 0x01, 0xab, 0x00]);
        runRoutine(0xffff);

        final v = await pollUntilQuit();
        expect(0xffff, equals(v));
      });

      test('push negative small', () async {
        /*
        * PUSH L00
        * RET SP
        */
        injectRoutine([0x0], [0xe8, 0xbf, 0x01, 0xab, 0x00]);
        runRoutine(MathHelper.dartSignedIntTo16BitSigned(-42));

        final v = await pollUntilQuit();
        expect(MathHelper.dartSignedIntTo16BitSigned(-42), equals(v));
      });

      test('push negative big', () async {
        /*
        * PUSH L00
        * RET SP
        */
        injectRoutine([0x0], [0xe8, 0xbf, 0x01, 0xab, 0x00]);

        runRoutine(MathHelper.dartSignedIntTo16BitSigned(-30000));

        final v = await pollUntilQuit();
        expect(MathHelper.dartSignedIntTo16BitSigned(-30000), equals(v));
      });
    });
  });
}
