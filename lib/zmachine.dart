#library('ZMachine');

#import('dart:json');
#import('dart:isolate');

#source('Header.dart');
#source('_Stack.dart');
#source('_MemoryMap.dart');
#source('BinaryHelper.dart');
#source('ZSCII.dart');
#source('Debugger.dart');
#source('Operand.dart');
#source('Dictionary.dart');
#source('DRandom.dart');
#source('GameException.dart');

#source('IO/IFF.dart');
#source('IO/Quetzal.dart');
#source('IO/Blorb.dart');
#source('IO/DefaultProvider.dart');
#source('IO/IOProvider.dart');

#source('machines/Machine.dart');
#source('machines/Version3.dart');
#source('machines/Version5.dart');
#source('machines/Version7.dart');
#source('machines/Version8.dart');
#source('GameObject.dart');

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

  final SendPort _asyncIsolate;

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
                          ],
    _asyncIsolate = spawnFunction(asyncIsolate)
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

  callAsync(func()){
    _asyncIsolate
    .call('foo')
    .then((reply){
      func();
    });
  }


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
    machine.pc--;
    
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

//    if(inBreak){
//      Z.sendIO(IOCommands.PRINT_DEBUG, ["<<< DEBUG MODE >>>"]);
//      callAsync(Debugger.startBreak);
//    }
    
//    if (Debugger.enableDebug){
//      Debugger.debug('<<< Interrupt, ${Debugger.instructionsCounter} instructions. >>>');
//    }
 //   Debugger.instructionsCounter = 0;
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
    machine.pc = 0;
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

void asyncIsolate(){
  port.receive((message, SendPort replyTo){
    replyTo.send('foo');
  });
}


Map<String, String> opCodes =
const {
 '224' : 'callVS',
 '225' : 'storewv',
 '79' : 'loadw',
 '15' : 'loadw',
 '47' : 'loadw',
 '111' : 'loadw',
 '10' : 'test_attr',
 '42' : 'test_attr',
 '74' : 'test_attr',
 '106' : 'test_attr',
 '11' : 'set_attr',
 '43' : 'set_attr',
 '75' : 'set_attr',
 '107' : 'set_attr',
 '13' : 'store',
 '45' : 'store',
 '77' : 'store',
 '109' : 'store',
 '16' : 'loadb',
 '48' : 'loadb',
 '80' : 'loadb',
 '112' : 'loadb',
 '17' : 'get_prop',
 '49' : 'get_prop',
 '81' : 'get_prop',
 '113' : 'get_prop',
 '14' : 'insertObj',
 '46' : 'insertObj',
 '78' : 'insertObj',
 '110' : 'insertObj',
 '20' : 'add',
 '52' : 'add',
 '84' : 'add',
 '116' : 'add',
 '21' : 'sub',
 '53' : 'sub',
 '85' : 'sub',
 '117' : 'sub',
 '22' : 'mul',
 '54' : 'mul',
 '86' : 'mul',
 '118' : 'mul',
 '23' : 'div',
 '55' : 'div',
 '87' : 'div',
 '119' : 'div',
 '24' : 'mod',
 '56' : 'mod',
 '88' : 'mod',
 '120' : 'mod',
 '5' : 'inc_chk',
 '37' : 'inc_chk',
 '69' : 'inc_chk',
 '101' : 'inc_chk',
 '6' : 'jin',
 '38' : 'jin',
 '70' : 'jin',
 '102' : 'jin',
 '1' : 'je',
 '33' : 'je',
 '65' : 'je',
 '97' : 'je',
 '160' : 'jz',
 '140' : 'jump',
 '156' : 'jump',
 '144' : 'jz',
 '128' : 'jz',
 '139' : 'ret',
 '155' : 'ret',
 '171' : 'ret',
 '135' : 'print_addr',
 '151' : 'print_addr',
 '167' : 'print_addr',
 '141' : 'print_paddr',
 '157' : 'print_paddr',
 '173' : 'print_paddr',
 '178' : 'printf',
 '187' : 'newline',
 '201' : 'andV',
 '9' : 'and',
 '230' : 'print_num',
 '229' : 'print_char',
 '176' : 'rtrue',
 '177' : 'rfalse',
 '138' : 'print_obj',
 '154' : 'print_obj',
 '170' : 'print_obj',
 '130' : 'get_child',
 '146' : 'get_child',
 '162' : 'get_child',
 '193' : 'jeV',
 '131' : 'get_parent',
 '147' : 'get_parent',
 '163' : 'get_parent',
 '161' : 'get_sibling',
 '145' : 'get_sibling',
 '129' : 'get_sibling',
 '184' : 'ret_popped',
 '2' : 'jl',
 '35' : 'jl',
 '66' : 'jl',
 '98' : 'jl',
 '3' : 'jg',
 '36' : 'jg',
 '67' : 'jg',
 '99' : 'jg',
 '228' : 'read',
 '133' : 'inc',
 '149' : 'inc',
 '165' : 'inc',
 '134' : 'dec',
 '150' : 'dec',
 '166' : 'dec',
 '186' : 'quit',
 '232' : 'push'
};
