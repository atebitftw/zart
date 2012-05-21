
/** Debug provider for scripting... */
class DebugProvider implements IOProvider
{
  final StringInputStream textStream;
  final Queue<String> lineBuffer;
  final Queue<String> outputBuffer;
  final int cols = 80;

  DebugProvider.with(String script)
    :
    textStream = new StringInputStream(stdin),
    lineBuffer = new Queue<String>(),
    outputBuffer = new Queue<String>()
  {
    if (script.isEmpty()) return;
    var commands = script.split('.');

    for(final command in commands){
      lineBuffer.addFirst(command.trim());
    }
  }

  Future<bool> saveGame(List<int> saveBytes){
    throw const NotImplementedException();
  }

  Future<List<int>> restore(){
    throw const NotImplementedException();
  }

  void PrimaryOutput(String text) {
    if (text.startsWith('["STATUS",') && text.endsWith(']')){
      //ignore status line for simple console games
      return;
    }
    var lines = text.split('\n');
    for(final l in lines){
      var words = new Queue<String>.from(l.split(' '));

      var s = new StringBuffer();
      while(!words.isEmpty()){
        var nextWord = words.removeFirst();

        if (s.length > cols){
          outputBuffer.addFirst('$s');
          if (Debugger.enableDebug) print('$s');
          s = new StringBuffer();
          s.add(nextWord + ' ');
        }else{
          if (words.isEmpty()){
            s.add(nextWord + ' ');
            outputBuffer.addFirst('$s');
            if (Debugger.enableDebug) print('$s');
            s = new StringBuffer();
          }else{
            s.add(nextWord + ' ');
          }
        }
      }

      if (s.length > 0){
        outputBuffer.addFirst('$s');
        if (Debugger.enableDebug) print('$s');
        s = new StringBuffer();
      }
    }
  }

  void DebugOutput(String text) => print(text);

  void doPrint(){
    while(!outputBuffer.isEmpty()){
      print(outputBuffer.removeLast());
    }
  }

  Future<String> getLine(){
    Completer c = new Completer();

    doPrint();

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
