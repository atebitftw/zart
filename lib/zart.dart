#library('zart.prujohn');

#import('dart:json');
#import('dart:isolate');
#import('dart:math');

#source('src/header.dart');
#source('src/_stack.dart');
#source('src/_memory_map.dart');
#source('src/binary_helper.dart');
#source('src/zscii.dart');
#source('src/debugger.dart');
#source('src/operand.dart');
#source('src/dictionary.dart');
#source('src/d_random.dart');
#source('src/game_exception.dart');

#source('src/IO/iff.dart');
#source('src/IO/quetzal.dart');
#source('src/IO/blorb.dart');
#source('src/IO/default_provider.dart');
#source('src/IO/io_provider.dart');

#source('src/machines/machine.dart');
#source('src/machines/version_3.dart');
#source('src/machines/version_5.dart');
#source('src/machines/version_7.dart');
#source('src/machines/version_8.dart');
#source('src/game_object.dart');

ZMachine get Z() => new ZMachine();

/**
* This is a partial-interpreter for the Z-Machine.  It handles most interpreter
* activites except actual IO, which is deferred to the IOConfig provider.
*
* The IOConfig handles tasks for whatever presentation platform
* is in use by the application.
*/
class ZMachine
{
  bool isLoaded = false;
  bool inBreak = false;
  bool inInterrupt = false;
  bool quit = false;
  ZVersion _ver;
  String _mostRecentInput;

  StringBuffer sbuff;
  final List<int> _memoryStreams;
  final List<int> _rawBytes;

  static ZMachine _context;

  //contains machine version which are supported by z-machine.
  final List<Machine> _supportedMachines;

  Machine machine;

  IOProvider IOConfig;

  factory ZMachine(){
    if (_context != null) return _context;

    _context = new ZMachine._internal();
    return _context;
  }

  ZMachine._internal()
  :
    sbuff = new StringBuffer(),
    _memoryStreams = new List<int>(),
    _rawBytes = new List<int>(),
    _supportedMachines = [
                          new Version3(),
                          new Version5(),
                          new Version7(),
                          new Version8()
                          ]
  {
      IOConfig = new DefaultProvider([]);
  }


  /**
  * Loads the given Z-Machine story file [storyBytes] into VM memory.
  */
  void load(List<int> storyBytes){
    if (storyBytes == null) return;

    _rawBytes.clear();
    _rawBytes.addAll(storyBytes);

    _ver = ZVersion.intToVer(_rawBytes[Header.VERSION]);

    var result = _supportedMachines
                    .filter(((Machine m) => m.version == _ver));

    if (result.length != 1){
      throw new Exception('Z-Machine version ${_ver} not supported.');
    }else{
      machine = result.dynamic[0];
    }

    print('Zart: Using Z-Machine v${machine.version}.');

    machine.mem = new _MemoryMap(_rawBytes);

    machine.visitHeader();

    isLoaded = true;
  }

  callAsync(func()) => new Timer(0, (foo) => func());

  /**
  * Runs the Z-Machine using the detected machine version from the story
  * file.  This can be overridden by passing [machineOverride] to the function.
  * Doing so will cause given IMachine to be used for execution.  This is handy
  * for using the [Disassembler] machine, or any other custome machine.
  */
  void run([Machine machineOverride = null]){
    _assertLoaded();

    if (machineOverride != null){
      machine = machineOverride;
      machine.mem = new _MemoryMap(_rawBytes);
      machine.visitHeader();
    }

    //for main routine only.
    machine.PC--;

    // visit the main 'routine' (call stack required empty)
    machine.visitRoutine([]);

    //push dummy result store onto the call stack
    machine.callStack.push(0);

    //push dummy return address onto the call stack
    machine.callStack.push(0);

    if (inBreak){
      callAsync(Debugger.startBreak);
    }else{
      callAsync(runIt);
    }
  }

  void runIt(){

//    while(!inBreak && !inInterrupt && !quit){
    while(!inInterrupt && !quit){
      machine.visitInstruction();
//      Debugger.instructionsCounter++;
    }

    if(inBreak){
      Z.sendIO(IOCommands.PRINT_DEBUG, ["<<< DEBUG MODE >>>"]);
      callAsync(Debugger.startBreak);
    }
  }

  Future<Object> sendIO(IOCommands command, [List messageData = const []]){
    var msg = [command.toString()];

    msg.addAll(messageData);

    return IOConfig.command(JSON.stringify(msg));
  }

  void _printBuffer(){
    //if output stream 3 is active then we don't print,
    //Just preserve the buffer until the stream is de-selected.
    if (!machine.outputStream3){
     sendIO(IOCommands.PRINT, [machine.currentWindow, sbuff.toString()])
      .then((_){
        sbuff.clear();
      });
    }
  }

  /** Reset Z-Machine to state at first load */
  void softReset(){
    _assertLoaded();
    machine.PC = 0;
    machine.stack.clear();
    machine.callStack.clear();
    _memoryStreams.clear();
    machine.mem = null;

    machine.mem = new _MemoryMap(_rawBytes);
    machine.visitHeader();
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

//String get platform(){
//  final int n=9007199254740992;
//  final int newInt = n + 1;
//  if ('$newInt' == '$n') {
//    return 'js';
//  } else {
//    return 'vm';
//  }
//}
