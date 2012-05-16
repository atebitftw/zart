
/**
* A runtime debugger for Z-Machine.
*/ 
class Debugger {
  static bool enableVerbose = false;
  static bool enableTrace = false; 
  static bool enableDebug = false;
  
  static int debugStartAddr;
  
  static List<int> _breakPoints;
  
  static void startBreak(timer){
    var locals = Z._machine.callStack[2];
    StringBuffer s = new StringBuffer();
    
    for(int i = 0; i < locals; i++){
      s.add('(L${i}: ${Z._machine._readLocal(i + 1)})  ');
    }

    Z._io.DebugOutput('(break)>>> [0x${debugStartAddr.toRadixString(16)}]'
    ' opCode: ${Z._machine.mem.loadb(debugStartAddr)}'
    ' (${opCodes[Z._machine.mem.loadb(debugStartAddr).toString()]})');
    
    Z._io.DebugOutput('   Locals: $s');
    
    _repl(timer);
  }
  
  static void _repl(timer){

    void parse(String command){
      var cl = command.toLowerCase().trim();
      var args = cl.split(' ');
      
      switch(args[0]){
        case 'enable':
          switch(args[1]){
            case 'trace':
              Debugger.enableTrace = true;
              debug('Trace Enabled.');
              break;
            case 'verbose':
              Debugger.enableVerbose = true;
              debug('Verbose Enabled.');
              break;
          }
          Z._io.callAsync(_repl);
          break;
        case 'disable':
          switch(args[1]){
            case 'trace':
              Debugger.enableTrace = false;
              debug('Trace Disabled.');
              break;
            case 'verbose':
              Debugger.enableVerbose = false;
              debug('Verbose Disabled.');
              break;
          }
          Z._io.callAsync(_repl);
          break;
        case '':
        case 'n':
          debugStartAddr = Z._machine.pc;    
          Z._machine.visitInstruction();
          Z._io.callAsync(startBreak);
          break;
        case 'q':
          Z.inBreak = false;
          Z._io.callAsync(Z._runIt);
          break;
        case 'globals':
          StringBuffer s = new StringBuffer();
          
          var col = args.length == 2 ? Math.parseInt(args[1]) : 10;
          if (col < 1) col = 1;
          
          for(int i = 0x10; i < 0xff; i++){
            
            s.add('g${i - 16 < 10 ? "0" : ""}${i - 16}:'
            ' 0x${Z._machine.mem.readGlobal(i).toRadixString(16)}');
            
            if ((i - 15) % col != 0){
              s.add('\t');
            }else{
              s.add('\n');
            }
          }
          debug('$s');
          Z._io.callAsync(_repl);
          break;
        case 'locals':
          var locals = Z._machine.callStack[2];
          StringBuffer s = new StringBuffer();
          
          for(int i = 0; i < locals; i++){
            s.add('(L${i}: ${Z._machine._readLocal(i + 1)})  ');
          }
          Z._io.callAsync(_repl);
          break;
        case 'object':
          var obj = new GameObjectV3(Math.parseInt(args[1]));
          obj.dump();
          Z._io.callAsync(_repl);
          break;
        default:
          Z.dynamic._io.DebugOutput('Unknown Command.');
          Z.dynamic._io.callAsync(_repl);
          break;
      }
    }

    var line = Z._io.getLine();
    
    if (line.isComplete){
      parse(line.value);
    }else{
      line.then((String l){
        parse(l);
      });
    }
  }
  
  static bool isBreakPoint(int addr){
    if (_breakPoints == null) return false;
    return _breakPoints.indexOf(addr) != -1;
  }
  
  static void setBreaks(List breakPoints) {
    if (_breakPoints == null){
      _breakPoints = new List<int>();
    }else{
      _breakPoints.clear();
    }
    _breakPoints.addAll(breakPoints);
  }
  
  static String dumpHeader(){
    if (!Z.dynamic.isLoaded) return '<<< Machine Not Loaded >>>\n';
    
    var s = new StringBuffer();
    
    s.add('(Story contains ${Z._machine.mem.size} bytes.)\n');
    s.add('\n');
    s.add('------- START HEADER -------\n');
    s.add('Z-Machine Version: ${Z.version}');
    s.add('Flags1(binary): ${Z._machine.mem.loadw(Header.FLAGS1).toRadixString(2)}\n');
    // word after flags1 is used by Inform
    s.add('Abbreviations Location: ${Z._machine.mem.abbrAddress.toRadixString(16)}\n');
    s.add('Object Table Location: ${Z._machine.mem.objectsAddress.toRadixString(16)}');
    s.add('Global Variables Location: ${Z._machine.mem.globalVarsAddress.toRadixString(16)}\n');
    s.add('Static Memory Start: ${Z._machine.mem.staticMemAddress.toRadixString(16)}\n');
    s.add('Dictionary Location: ${Z._machine.mem.dictionaryAddress.toRadixString(16)}\n');
    s.add('High Memory Start: ${Z._machine.mem.highMemAddress.toRadixString(16)}\n');
    s.add('Program Counter Start: ${Z._machine.pc.toRadixString(16)}\n');
    s.add('Flags2(binary): ${Z._machine.mem.loadb(Header.FLAGS2).toRadixString(2)}\n');
    s.add('Length Of File: ${Z._machine.mem.loadw(Header.LENGTHOFFILE) * Z._machine.fileLengthMultiplier()}\n');
    s.add('Checksum Of File: ${Z._machine.mem.loadw(Header.CHECKSUMOFFILE)}\n');
    //TODO v4+ header stuff here
    s.add('Standard Revision: ${Z._machine.mem.loadw(Header.REVISION_NUMBER)}\n');
    s.add('-------- END HEADER ---------\n');

    //s.add('main Routine: ${Z._machine.mem.getRange(Z.pc - 4, 10)}');

    s.add('\n');
    return s.toString();
  }
  
  /// Verbose Channel (via Debug)
  static void verbose(String outString){
    //TODO support redirect to file.
    if (Debugger.enableDebug && Debugger.enableVerbose)
      debug(outString);
  }
  
  /// Debug Channel
  static void debug(String debugString) => Z._io.DebugOutput(debugString);
  
  
  static void todo([String message]){
    Z._io.DebugOutput('Stopped At: 0x${Z._machine.pc.toRadixString(16)}');
    Z._io.PrimaryOutput('Text Buffer:');
    Z._printBuffer();
  
    if (message != null)
      Z._io.DebugOutput(message);
    throw const NotImplementedException();
  }
  
  static void throwAndDump(String message, int dumpOffset, [int howMany=20]){
    Z._printBuffer();
    
    for(final v in Z.dynamic.mem.getRange(Z.dynamic.pc + dumpOffset, howMany)){
      Debugger.verbose("(${v}, 0x${v.toRadixString(16)}, 0b${v.toRadixString(2)})");
    }
    
    //Z.callStack.dump();
    
    throw new Exception('(0x${(Z._machine.pc - 1).toRadixString(16)}) $message');
  }
}
