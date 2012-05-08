#library('ZMachine');

#source('Operation.dart');
#source('IVisitor.dart');
#source('Header.dart');
#source('_Stack.dart');
#source('_MemoryMap.dart');
#source('OperandType.dart');

#source('machines/IMachine.dart');
#source('machines/Tester.dart');

/// Dart Implementation of Infocom Z-Machine

/// Z-Machine Spec Used: http://www.gnelson.demon.co.uk/zspec/

/**
* Global Z-Machine object.
*/
ZMachine get Z() => new ZMachine();

/// Kilobytes -> Bytes
KBtoB(int kb) => kb * 1024;

void out(String outString){
  //TODO support redirect to file.
  if (Z.verbose)
    print(outString);
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
  final _Stack _stack;

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
    _stack = new _Stack(),
    _supportedMachines = [];

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

    if (_machine == null){
      if (machineOverride != null){
        _machine = machineOverride;
      }else{
        var result = _supportedMachines
            .filter(((IMachine m) => m.version == _ver));

        if (result.length != 1){
          throw new Exception('Z-Machine version ${_ver} not supported.');
        }else{
          _machine = result[0];
        }
      }
      _machine.visitHeader();
    }
    _runInternal();
  }
  
  // push a value onto the stack
  void push(int value){
    _stack.push(value);
  }
  
  int pop(){
    return _stack.pop();
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
  
  void _runInternal(){
    while(pc < mem.size - 1){
      if (checkInterrupt()){

      }
      _machine.visitInstruction(readb());
    }

    throw const Exception('Program Counter out of bounds.');
  }

  bool checkInterrupt(){
    return false;
  }

  /** Reset Z-Machine to state at first load */
  softReset(){
    _assertLoaded();
    pc = 0;
    _stack.clear();
    mem = new _MemoryMap(_rawBytes);
  }

  /** Reset Z-Machine to state at first load */
  hardReset(){
    pc = 0;
    _stack.clear();
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

