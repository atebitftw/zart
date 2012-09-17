
//first (most significant) byte
int fst(int word) => word >> 8;
//second (least significant) byte
int snd(int word) => word & 0xff;

//this is a testing facility to run simulated instructions against the machine
instructionTests(){

  final callAddr = 0x4f04;
  final testRoutineAddr = 0xae60;
  final testRoutineEndAddr = 0xafa5;
  final maxTestRoutineLength = (testRoutineEndAddr + 1) - testRoutineAddr;
  final SP = 0;

  final testRoutineRestoreBytes = Z.machine.mem.getRange(testRoutineAddr, maxTestRoutineLength);

  void injectRoutine(List<int> locals, List<int> instructionBytes){

    Z.machine.mem.storeb(testRoutineAddr, locals.length);

    //write the locals
    var start = testRoutineAddr + 1;

    for(final l in locals){
      Z.machine.mem.storew(start, l);
      start += 2;
    }

    //write the instructions
    for(final b in instructionBytes){
      Z.machine.mem.storeb(start, b);
      start++;
    }
  }

  List<int> createVarParamList(item1, [item2, item3, item4]){
    var kindList = [];
    var paramList = [];

    int getKind(item){
      if (item == null) { return OperandType.OMITTED;
      }

      if (item is String){
        return OperandType.VARIABLE;
      }else{
        if (item <= 0xFF) { return OperandType.SMALL;
        }
        return OperandType.LARGE;
      }
    }

    int convertToVariableLiteral(String item){
      //convert to variable literal
      if (item.toLowerCase() == 'sp') { return 0;
      }

      var varType = item.substring(0, 1);
      switch(varType.toLowerCase()){
        case 'g':
          // G0 = 16, G1 = 17, etc
          return parseInt(item.substring(1, item.length-1)) + 0x10;
        case 'l':
          // L0 = 1, L1 = 2, etc
          return parseInt(item.substring(1, item.length-1)) + 0x01;
        default:
          Expect.fail('variable type not recognized: $varType');
          break;
      }
    }

    //load the kinds and create the kind byte
    kindList.add(getKind(item1));
    kindList.add(getKind(item2));
    kindList.add(getKind(item3));
    kindList.add(getKind(item4));

    var operandByte = new Operand(OperandType.OMITTED);
    operandByte.rawValue = Operand.createVarOperandByte(kindList);
    paramList.add(operandByte);

    //convert any variable types to literals
    paramList.add(new Operand(kindList[0]));
    paramList.add(new Operand(kindList[1]));
    paramList.add(new Operand(kindList[2]));
    paramList.add(new Operand(kindList[3]));

    paramList[1].rawValue = (kindList[0] == OperandType.VARIABLE) ? convertToVariableLiteral(item1) : item1;
    paramList[2].rawValue = (kindList[1] == OperandType.VARIABLE) ? convertToVariableLiteral(item2) : item2;
    paramList[3].rawValue = (kindList[2] == OperandType.VARIABLE) ? convertToVariableLiteral(item3) : item3;
    paramList[4].rawValue = (kindList[3] == OperandType.VARIABLE) ? convertToVariableLiteral(item4) : item4;

    return paramList;
  }

  runRoutine([param1, param2, param3]){

    var operandList = createVarParamList(Z.machine.pack(testRoutineAddr), param1, param2, param3);
    Debugger.isUnitTestRun = true;
    Z.quit = false;

    var callInstruction = [224];

    // var operand types byte
    callInstruction.add(operandList[0].dynamic.rawValue);

    // write the operands
    for(final operand in operandList.getRange(1, 4)){
      if (operand.type == OperandType.OMITTED) { break;
      }
      if (operand.type == OperandType.LARGE){
        callInstruction.add(fst(operand.rawValue));
        callInstruction.add(snd(operand.rawValue));
      }else{
        callInstruction.add(operand.rawValue);
      }
    }

    //Debugger.debug(callInstruction);

    // return value to the stack
    callInstruction.add(SP);
    //QUIT opcode
    callInstruction.add(186);

    //write out the routine
    var addr = callAddr + 1;

    for(final inst in callInstruction){
      Z.machine.mem.storeb(addr, inst);
      addr++;
    }

    //clear stacks and reset program counter
    Z.machine.stack.clear();
    Z.machine.callStack.clear();
    Z.machine.PC = callAddr + 1;

    // visit the main 'routine'
    Z.machine.visitRoutine([]);

    //push dummy result store onto the call stack
    Z.machine.callStack.push(0);

    //push dummy return address onto the call stack
    Z.machine.callStack.push(0);

//    Debugger.debug('${Z.machine.mem.dump(callAddr, 20)}');

    Z.callAsync(Z.runIt);

    callbackDone();
  }

  void restoreRoutine(){
    var start = testRoutineAddr;

    for (final b in testRoutineRestoreBytes){
      Z.machine.mem.storeb(start++, b);
    }
  }

  group('instructions>', (){

    group('setup>', (){

      test('test routine check', (){
        //first/last byte of testRoutineRestore is correct
        Expect.equals(Z.machine.mem.loadb(testRoutineAddr), testRoutineRestoreBytes[0]);
        Expect.equals(Z.machine.mem.loadb(testRoutineEndAddr), testRoutineRestoreBytes.last());
      });

      test('routine restore check', (){
        var start = testRoutineAddr;

        //zero out the routine memory
        for (final b in testRoutineRestoreBytes){
          Z.machine.mem.storeb(start++, 0);
        }

        start = testRoutineAddr;
        //validate 0's
        for (final b in testRoutineRestoreBytes){
          Expect.equals(0, Z.machine.mem.loadb(start++));
        }

        restoreRoutine();

        start = testRoutineAddr;

        //validate restore
        for (final b in testRoutineRestoreBytes){
          Expect.equals(b, Z.machine.mem.loadb(start++));
        }
      });

      test('inject routine', (){
        injectRoutine([0xffff, 0xeeee, 0x0, 0x0, 0x0, 0x0], []);
        var testBytes = [0x6, 0xff, 0xff, 0xee, 0xee, 0, 0, 0, 0];
        var routine = Z.machine.mem.getRange(testRoutineAddr, testBytes.length);

        int i = 0;
        for(final b in routine){
          Expect.equals(testBytes[i++], b);
        }

        restoreRoutine();
      });
    });

    Future<int> pollUntilQuit(){
      Completer c = new Completer();

      doIt(t){
        if (Z.quit){
          c.complete(Z.machine.stack.pop());
        }else{
          new Timer(0, doIt);
        }
      }

      new Timer(0, doIt);

      return c.future;
    }

    group("tests>",(){
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


      asyncTest('simple return true', 2, (){
        injectRoutine([], [0xb0]); //RTRUE
        //Debugger.enableAll();

        runRoutine();

        pollUntilQuit().then((v){
          Expect.equals(Machine.TRUE, v);
          callbackDone();
        });
      });

      asyncTest('simple return false', 2, (){
        injectRoutine([], [0xb1]); //RFALSE
        runRoutine();

        pollUntilQuit().then((v){
          Expect.equals(Machine.FALSE, v);
          callbackDone();
        });
      });

      asyncTest('push non-negative small', 2, (){
        /*
        * PUSH L00 (25)
        * RET SP
        */
        injectRoutine([0x0], [0xe8, 0xbf, 0x01, 0xab, 0x00]);
        runRoutine(25);

        pollUntilQuit().then((v){
          Expect.equals(25, v);
          callbackDone();
        });
      });

      asyncTest('push non-negative big', 2, (){

        /*
        * PUSH L00 (0xFFFF)
        * RET SP
        */
        injectRoutine([0x0], [0xe8, 0xbf, 0x01, 0xab, 0x00]);
        runRoutine(0xffff);

        pollUntilQuit().then((v){
          Expect.equals(0xffff, v);
          callbackDone();
        });
      });

      asyncTest('push negative small', 2, (){

        /*
        * PUSH L00
        * RET SP
        */
        injectRoutine([0x0], [0xe8, 0xbf, 0x01, 0xab, 0x00]);

        runRoutine(Machine.dartSignedIntTo16BitSigned(-42));

        pollUntilQuit().then((v){
          Expect.equals(Machine.dartSignedIntTo16BitSigned(-42), v);
          callbackDone();
        });
      });

      asyncTest('push negative big', 2, (){

        /*
        * PUSH L00
        * RET SP
        */
        injectRoutine([0x0], [0xe8, 0xbf, 0x01, 0xab, 0x00]);

        runRoutine(Machine.dartSignedIntTo16BitSigned(-30000));

        pollUntilQuit().then((v){
          Expect.equals(Machine.dartSignedIntTo16BitSigned(-30000), v);
          callbackDone();
        });
      });
    });
  });

}