#library('ZMachine');

#source('Header.dart');
#source('_Stack.dart');
#source('_MemoryMap.dart');
#source('BinaryHelper.dart');
#source('ZSCII.dart');

#source('Operand.dart');
#source('machines/IMachine.dart');
#source('machines/Version3.dart');

/// Dart Implementation of Infocom Z-Machine

/// Z-Machine Spec Used: http://www.gnelson.demon.co.uk/zspec/

/**
* Global Z-Machine object, capable of running any [IMachine] variant.
*/
ZMachine get Z() => new ZMachine();

/// Kilobytes -> Bytes
KBtoB(int kb) => kb * 1024;

void out(String outString){
  //TODO support redirect to file.
  if (Z.verbose)
    print(outString);
}

void todo([String message]){
  if (message != null)
    print(message);
  throw const NotImplementedException();
}

/**
* Routine Stack frame
*
* # locals
* local 1
* ...
* local n
* routine base address  (Z._readLocal(-1))
*/

void _throwAndDump(String message, int dumpOffset, [int howMany=20]){
  Z.printBuffer();
  
  for(final v in Z.mem.getRange(Z.pc + dumpOffset, howMany)){
    out("(${v}, 0x${v.toRadixString(16)}, 0b${v.toRadixString(2)})");
  }
  throw new Exception('(0x${(Z.pc - 1).toRadixString(16)}) $message');
}

/**
* Version agnostic Z-Machine.
*/
class ZMachine{
  /// Z-Machine False = 0
  final int FALSE = 0;
  /// Z-Machine True = 1
  final int TRUE = 1;

  bool isLoaded = false;

  bool verbose = false;

  static ZMachine _ref;
  ZVersion _ver;
  List<int> _rawBytes;
  final _Stack stack;
  final _Stack callStack;

  //contains machine version which are supported by z-machine.
  final List<IMachine> _supportedMachines;

  IMachine _machine;

  /// Z-Machine Program Counter
  int pc = 0;

  int currentValue;

  _MemoryMap mem;

  factory ZMachine(){
   if (_ref != null) return _ref;

   _ref = new ZMachine._internal();
   return _ref;
  }

  ZMachine._internal()
  :
    stack = new _Stack(),
    callStack = new _Stack.max(1024),
    _supportedMachines = [new Version3()]
  {
    sbuff = new StringBuffer();
  }

  int get version() => _ver != null ? _ver.toInt() : null;

  /**
  * Loads the given Z-Machine story file [storyBytes] into VM memory.
  */
  void load(List<int> storyBytes){
    mem = new _MemoryMap(storyBytes);
    _rawBytes = storyBytes;

    _ver = ZVersion.intToVer(mem.loadb(Header.VERSION));
    isLoaded = true;
  }

  /**
  * Runs the Z-Machine using the detected machine version from the story
  * file.  This can be overridden by passing [machineOverride] to the function.
  * Doing so will cause given IMachine to be used for execution.  This is handy
  * for using the [Disassembler] machine, or any other custome machine.
  */
  void run([IMachine machineOverride = null]){
    _assertLoaded();

    if (machineOverride != null){
      _machine = machineOverride;
      _machine.visitHeader();
    }

    if (_machine == null){
      var result = _supportedMachines
                      .filter(((IMachine m) => m.version == _ver));

      if (result.length != 1){
        throw new Exception('Z-Machine version ${_ver} not supported.');
      }else{
        _machine = result[0];
      }

      _machine.visitHeader();
    }



    _machine.visitMainRoutine();
  }
  
  StringBuffer sbuff;
  
  void printBuffer(){
    //TODO(hook in configuration)
    print(sbuff.toString());
    sbuff.clear();
  }
  
  /** Reads 1 byte from the current program counter
  * address and advances the program counter to the next
  * unread address.
  */
  int readb(){
    pc++;
    currentValue = mem.loadb(pc - 1);
    return currentValue;
  }

  /** Reads 1 word from the current program counter
  * address and advances the program counter to the next
  * unread address.
  */
  int readw(){
    pc += 2;
    currentValue = mem.loadw(pc - 2);
    return currentValue;
  }

  int peekVariable(int varNum){
    if (varNum == 0x00){
      //top of stack
      var result = stack.peek();
      //out('    (peeked 0x${result.toRadixString(16)} from stack)');
      return result;
    }else if (varNum <= 0x0f){
      return _readLocal(varNum);
    }else if (varNum <= 0xff){
      return mem.readGlobal(varNum);
    }else{
      out('${mem.getRange(pc - 10, 20)}');
      throw new Exception('Variable referencer byte out of range (0-255): ${varNum}');
    }
  }

  int readVariable(int varNum){
    if (varNum == 0x00){
      //top of stack
      var result = stack.pop();
      out('    (popped 0x${result.toRadixString(16)} from stack)');
      return result;
    }else if (varNum <= 0x0f){
      return _readLocal(varNum);
    }else if (varNum <= 0xff){
      return mem.readGlobal(varNum);
    }else{
      out('${mem.getRange(pc - 10, 20)}');
      throw new Exception('Variable referencer byte out of range (0-255): ${varNum}');
    }
  }

  void writeVariable(int varNum, int value){
    if (varNum == 0x00){
      //top of stack
      out('    (pushed 0x${value.toRadixString(16)} to stack)');
      stack.push(value);
    }else if (varNum <= 0x0f){
      out('    (wrote 0x${value.toRadixString(16)} to local 0x${varNum.toRadixString(16)})');
      _writeLocal(varNum, value);
    }else if (varNum <= 0xff){
      out('    (wrote 0x${value.toRadixString(16)} to global 0x${varNum.toRadixString(16)})');
      mem.writeGlobal(varNum, value);
    }else{
      throw const Exception('Variable referencer byte out of range (0-255)');
    }
 }

  //unwinds one frame from the call stack
  void _unwind1(){
    var frameSize = Z.callStack.peek() + 1;

    out('(unwinding stack 1 frame)');

    while(frameSize >= 0){
      Z.callStack.pop();
      frameSize--;
    }
  }

  void _writeLocal(int local, int value){
    var locals = callStack.peek();

    if (locals < local){
      throw const Exception('Attempted to access unallocated local variable.');
    }

    var index = locals - local;

    if (index == -1){
      out('locals: $locals, local: $local');
      throw const Exception('bad index');
    }

    callStack[index + 1] = value;
  }

  int _readLocal(int local){
    var locals = callStack.peek();

    if (locals < local){
      throw const Exception('Attempted to access unallocated local variable.');
    }

    var index = locals - local;

    return callStack[index + 1];
  }

  bool checkInterrupt(){
    return false;
  }

  /** Reset Z-Machine to state at first load */
  softReset(){
    _assertLoaded();
    pc = 0;
    stack.clear();
    mem = new _MemoryMap(_rawBytes);
  }

  /** Reset Z-Machine to state at first load */
  hardReset(){
    pc = 0;
    stack.clear();
    mem = null;
    _machine = null;
    isLoaded = false;
  }

  void _assertLoaded(){
    if (!isLoaded){
      throw const Exception('Z-Machine state not loaded. Use load() first.');
    }
  }
}


class ZVersion{

  final int _ver;

  const ZVersion(this._ver);

  static final S = const ZVersion(-1); //special (disassembler, etc)
  static final V1 = const ZVersion(1);
  static final V2 = const ZVersion(2);
  static final V3 = const ZVersion(3);
  static final V4 = const ZVersion(4);
  static final V5 = const ZVersion(5);
  static final V6 = const ZVersion(6);
  static final V7 = const ZVersion(7);
  static final V8 = const ZVersion(8);

  String toString() => '$_ver';

  int toInt() => _ver;

  static ZVersion intToVer(int ver){
    switch (ver){
      case -1: return ZVersion.S;
      case 1: return ZVersion.V1;
      case 2: return ZVersion.V2;
      case 3: return ZVersion.V3;
      case 4: return ZVersion.V4;
      case 5: return ZVersion.V5;
      case 6: return ZVersion.V6;
      case 7: return ZVersion.V7;
      case 8: return ZVersion.V8;
      default:
        throw const Exception("Version number not recognized.");
    }
  }
}

