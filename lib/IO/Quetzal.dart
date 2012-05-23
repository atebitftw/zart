

//TODO account for the argument count value that is now on the stack!

/**
* Enumerates IFF chunks used in the Quetzal format.
*
*/
class Chunk{
  final String _str;

  const Chunk(this._str);

  static final IFZS = const Chunk('IFZS');
  static final IFhd = const Chunk('IFhd');
  static final CMem = const Chunk('CMem');
  static final UMem = const Chunk('UMem');
  static final Stks = const Chunk('Stks');
  static final IntD = const Chunk('IntD');

  static final FORM = const Chunk('FORM');
  static final AUTH = const Chunk('AUTH');
  static final CPYR = const Chunk('(c) ');
  static final ANNO = const Chunk('ANNO');

  String toString() => _str;

  List<int> charCodes() => _str.charCodes();

  static Chunk toChunk(String chunk){
    switch(chunk){
      case "IFZS": return Chunk.IFZS;
      case "IFhd": return Chunk.IFhd;
      case "CMem": return Chunk.CMem;
      case "UMem": return Chunk.UMem;
      case "Stks": return Chunk.Stks;
      case "IntD": return Chunk.IntD;
      case "FORM": return Chunk.FORM;
      case "AUTH": return Chunk.AUTH;
      case "(c) ": return Chunk.CPYR;
      case "ANNO": return Chunk.ANNO;
      default:
        return null;
    }
  }
}

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
* Currently only V3 compatible.
*/
class Quetzal {

  static int nextByte(List stream){
    if (stream.isEmpty()) return null;

    var nb = stream[0];
    stream.removeRange(0, 1);
    return nb;
  }

  static void writeChunk(List stream, Chunk chunk){
    var bytes = chunk.charCodes();

    for(final byte in bytes){
      stream.add(byte);
    }
  }

  static Chunk readChunk(List stream){
    if (stream.length < 4) return null;

    var s = new StringBuffer();

    for(int i = 0; i < 4; i++){
      s.addCharCode(nextByte(stream));
    }

    return Chunk.toChunk(s.toString());
  }

  static int read4Byte(List stream){
    var bl = new List();

    for(int i = 0; i < 4; i++){
      bl.add(nextByte(stream));
    }

    return (bl[0] << 24) | (bl[1] << 16) | (bl[2] << 8) | bl[3];
  }

  static int read3Byte(List stream){
    var bl = new List();

    for(int i = 0; i < 3; i++){
      bl.add(nextByte(stream));
    }

    return (bl[0] << 16) | (bl[1] << 8) | bl[2];
  }

  static int read2Byte(List stream){
    var bl = new List();

    for(int i = 0; i < 2; i++){
      bl.add(nextByte(stream));
    }

    return (bl[0] << 8) | bl[1];
  }

  static void write4Byte(List stream, int value){
    stream.add((value >> 24) & 0xFF);
    stream.add((value >> 16) & 0xFF);
    stream.add((value >> 8) & 0xFF);
    stream.add(value & 0xFF);
   }

  static void write3Byte(List stream, int value){
    stream.add((value >> 16) & 0xFF);
    stream.add((value >> 8) & 0xFF);
    stream.add(value & 0xFF);
   }

  static void write2Byte(List stream, int value){
    stream.add((value >> 8) & 0xFF);
    stream.add(value & 0xFF);
  }

  static int setBottomBits(int numBits){
    if (numBits == 0) return 0;

    var i = 1;

    for(int x = 1; x < numBits; x++){
      i = (i << 1) | 1;
    }

    return i;
  }


  static int read16BitValue(List stream){
     return (nextByte(stream) << 24)
         | (nextByte(stream) << 16)
         | (nextByte(stream) << 8)
         | nextByte(stream);
  }

  /// Generates a stream of save bytes in the Quetzal format.
  static List<int> save(int pcAddr){
    bool padByte;

    List<int> saveData = new List<int>();

    writeChunk(saveData, Chunk.FORM);
    writeChunk(saveData, Chunk.IFZS);

    //associated story file
    writeChunk(saveData, Chunk.IFhd);
    write4Byte(saveData, 13);
    write2Byte(saveData, Z.machine.mem.loadw(Header.RELEASE));
    write2Byte(saveData, Z.machine.mem.loadw(Header.SERIAL_NUMBER));
    write2Byte(saveData, Z.machine.mem.loadw(Header.SERIAL_NUMBER + 2));
    write2Byte(saveData, Z.machine.mem.loadw(Header.SERIAL_NUMBER + 4));
    write2Byte(saveData, Z.machine.mem.loadw(Header.CHECKSUMOFFILE));
    //pc
    write3Byte(saveData, pcAddr); //varies depending on version.
    saveData.add(0); //pad byte

    //uncompressed memory
    writeChunk(saveData, Chunk.UMem);

    //write length in bytes
    write4Byte(saveData, Z.machine.mem._mem.length);

    saveData.addAll(Z.machine.mem._mem);

    if (Z.machine.mem._mem.length % 2 != 0){
      saveData.add(0); //pad byte
    }

    //stacks, oldest first
    writeChunk(saveData, Chunk.Stks);

    var stackData = new Queue<StackFrame>();

    stackData.addFirst(new StackFrame(0,0));

    while(stackData.first().nextCallStackIndex != null){
      stackData.addFirst(new StackFrame(stackData.first().nextCallStackIndex, stackData.first().nextEvalStackIndex));
    }

    var totalStackBytes = 0;
    for(final sd in stackData){
      totalStackBytes += sd.computedByteSize;
    }

    write4Byte(saveData, totalStackBytes);

    for(StackFrame sd in stackData){
      write3Byte(saveData, sd.returnAddr);

      saveData.add(0); //flags. > v3...

      saveData.add(sd.returnVar);

      //locals
      //this is incorrect, but whatever
      //the standards wants to keep track of supplied
      //arguements for some reason...
      saveData.add(sd.locals.length);

      write2Byte(saveData, sd.evals.length);

      for(int l in sd.locals){
        write2Byte(saveData, l);
      }

      for(int e in sd.evals){
        write2Byte(saveData, e);
      }
    }

    if (totalStackBytes % 2 != 0)
      saveData.add(0); //pad byte

    return saveData;
  }


  // Restores current machine state with the given stream of file bytes.
  static bool restore(rawBytes){
    var fileBytes = new List.from(rawBytes);
    List<int> restoreData = new List<int>();

    Chunk nextChunk = readChunk(fileBytes);
    if (!assertChunk(Chunk.FORM, nextChunk)) return false;

    nextChunk = readChunk(fileBytes);
    if (!assertChunk(Chunk.IFZS, nextChunk)) return false;

    var gotStacks = false;
    var gotMem = false;
    var gotHeader = false;
    var pc;
    var memBytes = [];
    final stackList = new List<StackFrame>();

    nextChunk = readChunk(fileBytes);
    if (nextChunk == null) return false;

    while(nextChunk != null){
      switch(nextChunk.toString()){
        case Chunk.IFhd.toString():
          // here we are validating that this file is compatible
          // with the game currently loaded into the machine.

          read4Byte(fileBytes); //size (always 13)
          if (Z.machine.mem.loadw(Header.RELEASE) != read2Byte(fileBytes)){
            return false;
          }
          if (Z.machine.mem.loadw(Header.SERIAL_NUMBER) != read2Byte(fileBytes)){
            return false;
          }
          if (Z.machine.mem.loadw(Header.SERIAL_NUMBER + 2) != read2Byte(fileBytes)){
            return false;
          }
          if (Z.machine.mem.loadw(Header.SERIAL_NUMBER + 4) != read2Byte(fileBytes)){
            return false;
          }
          if (Z.machine.mem.loadw(Header.CHECKSUMOFFILE) != read2Byte(fileBytes)){
            return false;
          }
          pc = read3Byte(fileBytes); //PC
          nextByte(fileBytes); //pad
          gotHeader = true;
          break;
        case Chunk.Stks.toString():
          var stacksLen = read4Byte(fileBytes);

          StackFrame getNextStackFrame(){
            var sf = new StackFrame.empty();

            sf.returnAddr = read3Byte(fileBytes);
            nextByte(fileBytes); //we don't care about the flags
            sf.returnVar = nextByte(fileBytes);
            var numLocals = nextByte(fileBytes);
            var numEvals = read2Byte(fileBytes);

            for(int i = 0; i < numLocals; i++){
              sf.locals.add(read2Byte(fileBytes));
            }

            for(int i = 0; i < numEvals; i++){
              sf.evals.add(read2Byte(fileBytes));
            }
            return sf;
          }

          while(stacksLen > 0){
            if (stacksLen == 1){
              //pad byte
              nextByte(fileBytes);
              continue;
            }

            stackList.add(getNextStackFrame());
            stacksLen -= stackList.last().computedByteSize;
          }

          gotStacks = true;
          break;
        case Chunk.UMem.toString():
          var numBytes = read4Byte(fileBytes);

          //memory length mismatch
          if (numBytes != Z.machine.mem._mem.length)
            return false;

          memBytes = fileBytes.getRange(0, numBytes);
          fileBytes.removeRange(0, numBytes);

          //read pad byte if present
          if (numBytes % 2 != 0)
            nextByte(fileBytes);
          gotMem = true;
          break;
        default:
          if (!gotStacks || !gotMem || !gotHeader){
            if (nextChunk == Chunk.FORM || nextChunk == Chunk.IFZS){
              return false; //something went horribly wrong in the file format
            }

            //attempt to skip the chunk
            var sizeOfChunk = read4Byte(fileBytes);
            fileBytes.removeRange(0, sizeOfChunk);
          }
      }

      if(gotStacks && gotMem && gotHeader) break;
      nextChunk = readChunk(fileBytes);
    }

    if (!gotStacks || !gotMem || !gotHeader) return false;

    //now that we have all the data structures, do the restore...

    //memory
    Z.machine.mem = new _MemoryMap(memBytes);
    Z.machine.visitHeader();


    Z.machine.callStack.clear();
    Z.machine.stack.clear();

    //stacks
    for(StackFrame sf in stackList){
      //callstack first
      for(final local in sf.locals){
        Z.machine.callStack.push(local);
      }

      Z.machine.callStack.push(sf.locals.length);
      Z.machine.callStack.push(sf.returnVar);
      Z.machine.callStack.push(sf.returnAddr);


      //eval stack
      Z.machine.stack.push(Machine.STACK_MARKER);
      for(final eval in sf.evals){
        Z.machine.stack.push(eval);
      }
    }

    Z.machine.pc = pc;

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

    nextCallStackIndex = callIndex + 1;

    if (nextCallStackIndex >= Z.machine.callStack.length)
      nextCallStackIndex = null;

    var eStack = Z.machine.stack[evalIndex];

    while(eStack != Machine.STACK_MARKER){
        evals.addFirst(eStack);
        eStack = Z.machine.stack[++evalIndex];
    }

    if (nextCallStackIndex != null)
      nextEvalStackIndex = evalIndex + 1;
  }

  int get computedByteSize() => 8 + (locals.length * 2) + (evals.length * 2);

  String toString(){
    var s = new StringBuffer();
    s.add('return addr: 0x${returnAddr.toRadixString(16)}\n');
    s.add('return var: 0x${returnVar.toRadixString(16)}\n');
    s.add('locals: $locals \n');
    s.add('evals: $evals \n');
    s.add('nextCallStackIndex: $nextCallStackIndex \n');
    s.add('nextEvalStackIndex: $nextEvalStackIndex\n\n');
    return s.toString();
  }
}
