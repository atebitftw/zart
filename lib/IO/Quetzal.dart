
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
        throw new GameException('Chunk not recognzied.');
    }
  }
}

/**
* Quetzal IFF Standard load/save implementation.
*
* Ref: http://www.inform-fiction.org/zmachine/standards/quetzal/
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
    var s = new StringBuffer();

    for(int i = 0; i < 4; i++){
      s.addCharCode(nextByte(stream));
    }

    return Chunk.toChunk(s.toString());
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
     return (nextByte(stream) << 24) | (nextByte(stream) << 16) | (nextByte(stream) << 8) | nextByte(stream);
  }

  /// Generates a stream of save bytes in the Quetzal format.
  static List<int> save(int pcAddr){
    bool padByte;

    List<int> saveData = new List<int>();

    writeChunk(saveData, Chunk.FORM);
    writeChunk(saveData, Chunk.IFZS);

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

      var nargs = sd.locals.length > 7 ? 7 : sd.locals.length;
      saveData.add(setBottomBits(nargs));

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

    return saveData;
  }

//  -------------------
//  Routine Stack frame
//  -------------------
//  0x0: returnTo Addr
//  0x1: returnValue Addr
//  0x2: # locals
//  0x3: local 1
//  0x...
//  0xn: local n

  // Restores current machine state with the given stream of file bytes.
  static void load(List<int> fileBytes){

  }

}

class StackFrame
{
  int returnAddr;
  int returnVar;
  final List<int> locals;
  final List<int> evals;
  int nextCallStackIndex;
  int nextEvalStackIndex;

  StackFrame(int callIndex, evalIndex)
  :
    locals = new List<int>(),
    evals = new List<int>()
  {
    returnAddr = Z.machine.callStack[callIndex];
    returnVar = Z.machine.callStack[++callIndex];

    var totalLocals = Z.machine.callStack[++callIndex];

    for(int i = 0; i < totalLocals; i++){
      locals.add(Z.machine.callStack[++callIndex]);
    }

    nextCallStackIndex = callIndex + 1;

    if (nextCallStackIndex >= Z.machine.callStack.length)
      nextCallStackIndex = null;

    var eStack = Z.machine.stack[evalIndex];

    while(eStack != Machine.STACK_MARKER){
        evals.add(eStack);
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
