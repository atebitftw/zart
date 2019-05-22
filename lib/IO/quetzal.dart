
//TODO added total bytes after FORM chunk


import 'dart:collection';
import 'package:zart/IO/iff.dart';
import 'package:zart/binary_helper.dart';
import 'package:zart/header.dart';
import 'package:zart/machines/machine.dart';
import 'package:zart/memory_map.dart';
import 'package:zart/z_machine.dart';

/**
* Quetzal IFF Standard load/save implementation.
*
* Ref: http://www.inform-fiction.org/zmachine/standards/quetzal/
*
* Note that while the format of the standard is followed, and
* files saved with this class should interchange with other interpreters
* that conform to Quetzal, this implementation does not support all
* standards on file restore (compression, etc), therefore it is not
* guaranteed to successfully load Quetzal save files that are not
* explicitly saved with it.
*
*/
class Quetzal {
  /// Generates a stream of save bytes in the Quetzal format.
  static List<int> save(int pcAddr){
    // bool padByte;

    List<int> saveData = new List<int>();

    IFF.writeChunk(saveData, Chunk.FORM);
    IFF.writeChunk(saveData, Chunk.IFZS);

    //associated story file
    IFF.writeChunk(saveData, Chunk.IFhd);
    IFF.write4Byte(saveData, 13);
    IFF.write2Byte(saveData, Z.machine.mem.loadw(Header.RELEASE));
    IFF.write2Byte(saveData, Z.machine.mem.loadw(Header.SERIAL_NUMBER));
    IFF.write2Byte(saveData, Z.machine.mem.loadw(Header.SERIAL_NUMBER + 2));
    IFF.write2Byte(saveData, Z.machine.mem.loadw(Header.SERIAL_NUMBER + 4));
    IFF.write2Byte(saveData, Z.machine.mem.loadw(Header.CHECKSUMOFFILE));
    //pc
    IFF.write3Byte(saveData, pcAddr); //varies depending on version.
    saveData.add(0); //pad byte

    //uncompressed memory
    IFF.writeChunk(saveData, Chunk.UMem);

    //IFF.write length in bytes
    IFF.write4Byte(saveData, Z.machine.mem.memList.length);

    saveData.addAll(Z.machine.mem.memList);

    if (Z.machine.mem.memList.length % 2 != 0){
      saveData.add(0); //pad byte
    }

    //stacks, oldest first
    IFF.writeChunk(saveData, Chunk.Stks);

    var stackData = new Queue<StackFrame>();

    stackData.addFirst(new StackFrame(0,0));

    while(stackData.first.nextCallStackIndex != null){
      stackData.addFirst(new StackFrame(stackData.first.nextCallStackIndex, stackData.first.nextEvalStackIndex));
    }

    var totalStackBytes = 0;
    for(final sd in stackData){
      totalStackBytes += sd.computedByteSize;
    }

    IFF.write4Byte(saveData, totalStackBytes);

    for(StackFrame sd in stackData){
      IFF.write3Byte(saveData, sd.returnAddr);


      //flags byte
      var flagByte = 0;

      //set the call_xN bit if this stack frame is supposed to discard returns
      if (sd.returnVar == Machine.STACK_MARKER){
        flagByte = BinaryHelper.set(flagByte, 4);
      }

      //using the first 4 bits, we set the number of locals... (not standard, but permissible)
      flagByte |= sd.locals.length;

      saveData.add(flagByte);

      // return variable number
      // (ref 4.6)
      saveData.add(sd.returnVar != Machine.STACK_MARKER ? sd.returnVar : 0);

      //total args passed (4.3.4)
      saveData.add(BinaryHelper.setBottomBits(sd.totalArgsPassed));

      IFF.write2Byte(saveData, sd.evals.length);

      for(int l in sd.locals){
        IFF.write2Byte(saveData, l);
      }

      for(int e in sd.evals){
        IFF.write2Byte(saveData, e);
      }
    }

    if (totalStackBytes % 2 != 0) {
      saveData.add(0);
    } //pad byte

    return saveData;
  }


  // Restores current machine state with the given stream of file bytes.
  static bool restore(rawBytes){
    var fileBytes = new List.from(rawBytes);
    //List<int> restoreData = new List<int>();

    Chunk nextChunk = IFF.readChunk(fileBytes);
    if (!assertChunk(Chunk.FORM, nextChunk)) return false;

    nextChunk = IFF.readChunk(fileBytes);
    if (!assertChunk(Chunk.IFZS, nextChunk)) return false;

    var gotStacks = false;
    var gotMem = false;
    var gotHeader = false;
    var pc;
    var memBytes = [];
    final stackList = new List<StackFrame>();

    nextChunk = IFF.readChunk(fileBytes);
    if (nextChunk == null) return false;

    while(nextChunk != null){
      switch(nextChunk){
        case Chunk.IFhd:
          // here we are validating that this file is compatible
          // with the game currently loaded into the machine.

          IFF.read4Byte(fileBytes); //size (always 13)
          if (Z.machine.mem.loadw(Header.RELEASE) != IFF.read2Byte(fileBytes)){
            return false;
          }
          if (Z.machine.mem.loadw(Header.SERIAL_NUMBER) != IFF.read2Byte(fileBytes)){
            return false;
          }
          if (Z.machine.mem.loadw(Header.SERIAL_NUMBER + 2) != IFF.read2Byte(fileBytes)){
            return false;
          }
          if (Z.machine.mem.loadw(Header.SERIAL_NUMBER + 4) != IFF.read2Byte(fileBytes)){
            return false;
          }
          if (Z.machine.mem.loadw(Header.CHECKSUMOFFILE) != IFF.read2Byte(fileBytes)){
            return false;
          }
          pc = IFF.read3Byte(fileBytes); //PC
          IFF.nextByte(fileBytes); //pad
          gotHeader = true;
          break;
        case Chunk.Stks:
          var stacksLen = IFF.read4Byte(fileBytes);

          StackFrame getNextStackFrame(){
            var sf = new StackFrame.empty();

            sf.returnAddr = IFF.read3Byte(fileBytes);

            var flagByte = IFF.nextByte(fileBytes);

            var returnVar = IFF.nextByte(fileBytes);

            sf.returnVar = BinaryHelper.isSet(flagByte, 4)
                              ? Machine.STACK_MARKER
                              : returnVar;

            var numLocals = BinaryHelper.bottomBits(flagByte, 4);

            var argsPassed = IFF.nextByte(fileBytes);

            var args = 0;
            while(BinaryHelper.isSet(argsPassed, 0)){
              args++;
              argsPassed = argsPassed >> 1;
            }
            sf.totalArgsPassed = args;

            var numEvals = IFF.read2Byte(fileBytes);

            for(int i = 0; i < numLocals; i++){
              sf.locals.add(IFF.read2Byte(fileBytes));
            }

            for(int i = 0; i < numEvals; i++){
              sf.evals.add(IFF.read2Byte(fileBytes));
            }
            return sf;
          }

          while(stacksLen > 0){
            if (stacksLen == 1){
              //pad byte
              IFF.nextByte(fileBytes);
              continue;
            }

            stackList.add(getNextStackFrame());
            stacksLen -= stackList.last.computedByteSize;
          }

          gotStacks = true;
          break;
        case Chunk.UMem:
          var numBytes = IFF.read4Byte(fileBytes);

          //memory length mismatch
          if (numBytes != Z.machine.mem.memList.length) {
            return false;
          }

          memBytes = fileBytes.getRange(0, numBytes);
          fileBytes.removeRange(0, numBytes);

          //IFF.read pad byte if present
          if (numBytes % 2 != 0) {
            IFF.nextByte(fileBytes);
          }
          gotMem = true;
          break;
        default:
          if (!gotStacks || !gotMem || !gotHeader){
            if (nextChunk == Chunk.FORM || nextChunk == Chunk.IFZS){
              return false; //something went horribly wrong in the file format
            }

            //attempt to skip the chunk
            var sizeOfChunk = IFF.read4Byte(fileBytes);
            fileBytes.removeRange(0, sizeOfChunk);
          }
      }

      if(gotStacks && gotMem && gotHeader) break;
      nextChunk = IFF.readChunk(fileBytes);
    }

    if (!gotStacks || !gotMem || !gotHeader) return false;

    //now that we have all the data structures, do the restore...

    //memory
    Z.machine.mem = MemoryMap(memBytes);
    Z.machine.visitHeader();


    Z.machine.callStack.clear();
    Z.machine.stack.clear();

    //stacks
    for(StackFrame sf in stackList){

      //callstack first
      print(sf);

      //locals
      Z.machine.callStack.push(sf.locals.length);

      for(final local in sf.locals){
        Z.machine.callStack.push(local);
      }

      //total locals
      Z.machine.callStack.push(sf.locals.length);

      //returnTo variable
      Z.machine.callStack.push(sf.returnVar);

      //return addr
      Z.machine.callStack.push(sf.returnAddr);


      //eval stack
      Z.machine.stack.push(Machine.STACK_MARKER);
      for(final eval in sf.evals){
        Z.machine.stack.push(eval);
      }
    }

    Z.machine.PC = pc;

    return true;
  }

  static bool assertChunk(Chunk expect, Chunk value){
    return (expect == value);
  }

}

class StackFrame
{
  int returnAddr;
  int returnVar;
  final Queue<int> locals;
  final Queue<int> evals;
  int nextCallStackIndex;
  int nextEvalStackIndex;
  int totalArgsPassed;

  StackFrame.empty()
  :
    locals = new Queue<int>(),
    evals = new Queue<int>();

  StackFrame(int callIndex, evalIndex)
  :
    locals = new Queue<int>(),
    evals = new Queue<int>()
  {
    returnAddr = Z.machine.callStack[callIndex];
    returnVar = Z.machine.callStack[++callIndex];

    var totalLocals = Z.machine.callStack[++callIndex];

    for(int i = 0; i < totalLocals; i++){
      locals.addFirst(Z.machine.callStack[++callIndex]);
    }

    totalArgsPassed = Z.machine.callStack[++callIndex];

    nextCallStackIndex = callIndex + 1;

    if (nextCallStackIndex >= Z.machine.callStack.length) {
      nextCallStackIndex = null;
    }

    var eStack = Z.machine.stack[evalIndex];

    while(eStack != Machine.STACK_MARKER){
        evals.addFirst(eStack);
        eStack = Z.machine.stack[++evalIndex];
    }

    if (nextCallStackIndex != null) {
      nextEvalStackIndex = evalIndex + 1;
    }
  }

  int get computedByteSize => 8 + (locals.length * 2) + (evals.length * 2);

  String toString(){
    var s = new StringBuffer();
    s.write('return addr: 0x${returnAddr.toRadixString(16)}\n');
    s.write('return var: 0x${returnVar.toRadixString(16)}\n');
    s.write('args passed: $totalArgsPassed');
    s.write('locals: $locals \n');
    s.write('evals: $evals \n');
    s.write('nextCallStackIndex: $nextCallStackIndex \n');
    s.write('nextEvalStackIndex: $nextEvalStackIndex\n\n');
    return s.toString();
  }
}
