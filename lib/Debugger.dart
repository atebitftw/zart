
/**
* A runtime debugger for Z-Machine.
*/ 
class Debugger {
  static int debugStartAddr;
  
  static void startBreak(timer){
    var locals = Z.callStack[2];
    StringBuffer s = new StringBuffer();
    
    for(int i = 0; i < locals; i++){
      s.add('(L${i}: ${Z._readLocal(i + 1)})  ');
    }

    Z._io.DebugOutput('(break)>>> [0x${debugStartAddr.toRadixString(16)}] opCode: ${Z.mem.loadb(debugStartAddr)} (${opCodes[Z.mem.loadb(debugStartAddr).toString()]})');
    Z._io.DebugOutput('   Locals: $s');
    
    _repl(timer);
  }
  
  static void _repl(timer){

    void repl(String command){
      var cl = command.toLowerCase().trim();
      var args = cl.split(' ');
      
      switch(args[0]){
        case '':
        case 'n':
          debugStartAddr = Z.pc;    
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
            
            s.add('g${i - 16 < 10 ? "0" : ""}${i - 16}: 0x${Z.mem.readGlobal(i).toRadixString(16)}');
            
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
          var locals = Z.callStack[2];
          StringBuffer s = new StringBuffer();
          
          for(int i = 0; i < locals; i++){
            s.add('(L${i}: ${Z._readLocal(i + 1)})  ');
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
    //repl
    
    var line = Z._io.getLine();
    
    if (line.isComplete){
      repl(line.value);
    }else{
      line.then((String l){
        repl(l);
      });
    }
  }
}
