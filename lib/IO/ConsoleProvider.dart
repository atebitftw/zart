#library('Console_Provider');
#import('dart:io');
#import('../zmachine.dart');

/** A basic console provider with word-wrap support. */
class ConsoleProvider implements IOProvider
{
  final StringInputStream textStream;
  final Queue<String> lineBuffer;
  final int cols = 80;
  
  ConsoleProvider()
  :
    textStream = new StringInputStream(stdin),
    lineBuffer = new Queue<String>();
  
  void PrimaryOutput(String text) {
    var words = new Queue<String>.from(text.split(' '));

    var s = new StringBuffer();
    
    while(!words.isEmpty()){
      var nextWord = words.removeFirst();

      if (s.length > cols){
        print('$s');
        s = new StringBuffer();
      }

      if (words.isEmpty()){
        s.add(nextWord + ' ');
        print('$s');
        s = new StringBuffer();
      }else{
        s.add(nextWord + ' '); 
      }
    }
    
    if (s.length > 0){
      print('$s');
    }
    
  }
  
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
