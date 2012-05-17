
//first (most significant) byte
int fst(int word) => word >> 8;
//second (least significant) byte
int snd(int word) => word & 0xff;

instructionTests(){  
  
  final callAddr = 0x381d;
  final callToAddr = 0x3826;
  final testRoutineAddr = 0xae80;
  
  final testRoutineRestore = Z.machine.mem.getRange(testRoutineAddr, 0xaede - testRoutineAddr);
  
  void injectRoutine(List<int> locals, List<int> instructionBytes){
    Z.machine.mem.storeb(testRoutineAddr, locals.length);
    
    //write the locals
    var start = testRoutineAddr + 1;    
    for(final l in locals){
      Z.machine.mem.storew(start, l);
      start += 2;
    }
  }
  
  void restoreRoutine(){
    var start = testRoutineAddr;
    
    for (final b in testRoutineRestore){
      Z.machine.mem.storeb(start++, b);
    }
  }
  
  group('instructions>', (){
    
    group('setup>', (){
      
      test('test routine check', (){       
        //first/last byte of testRoutineRestore is correct
        Expect.equals(Z.machine.mem.loadb(testRoutineAddr), testRoutineRestore[0]);
        Expect.equals(Z.machine.mem.loadb(0xaedd), testRoutineRestore.last());
        
      });
      
      test('routine restore check', (){
        var start = testRoutineAddr;
        
        //zero out the routine memory
        for (final b in testRoutineRestore){
          Z.machine.mem.storeb(start++, 0);
        }
        
        start = testRoutineAddr;
        //validate 0's
        for (final b in testRoutineRestore){
          Expect.equals(0, Z.machine.mem.loadb(start++));
        }

        restoreRoutine();
        
        start = testRoutineAddr;
        
        //validate restore
        for (final b in testRoutineRestore){
          Expect.equals(b, Z.machine.mem.loadb(start++));
        }
      });
      
      test('inject routine', (){
        injectRoutine([0xffff, 0xeeee, 0x0000], []);
        var testBytes = [3, 0xff, 0xff, 0xee, 0xee, 0, 0];
        var routine = Z.machine.mem.getRange(testRoutineAddr, testBytes.length);

        int i = 0;
        for(final b in routine){
          Expect.equals(testBytes[i++], b);
        }
        
      });
    });
    
  });
  
}