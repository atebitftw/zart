#library('Console_Provider');
#import('dart:io');
#import('../zmachine.dart');

class ConsoleProvider implements IOProvider
{
  final StringInputStream textStream;
  final Queue<String> lineBuffer;
  
  ConsoleProvider()
  :
    textStream = new StringInputStream(stdin),
    lineBuffer = new Queue<String>();
  
  void PrimaryOutput(String text) => print(text);
  
  void DebugOutput(String text) => print(text);
  
  Future<String> getLine(){
    Completer c = new Completer();
    
    if (!lineBuffer.isEmpty()){
      c.complete(lineBuffer.removeLast());      
    }else{
      textStream.onLine = () => c.complete(textStream.readLine());      
    }
    
    return c.future;
  }
  
  void callAsync(func(timer)){
    new Timer(0, func);
  }
}
