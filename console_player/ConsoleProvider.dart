
/** A basic console provider with word-wrap support. */
class ConsoleProvider implements IOProvider
{
  final StringInputStream textStream;
  final Queue<String> lineBuffer;
  final Queue<String> outputBuffer;
  final int cols = 80;

  ConsoleProvider()
  :
    textStream = new StringInputStream(stdin),
    lineBuffer = new Queue<String>(),
    outputBuffer = new Queue<String>();

  Future<bool> saveGame(List<int> saveBytes){
    var c = new Completer();
    print('(Caution: will overwrite existing file!)');
    print('Enter file name to save to (no extension):');

    textStream.onLine = (){
      var fn = textStream.readLine();
      if (fn == null || fn.isEmpty())
      {
        print('Invalid file name given.');
        c.complete(false);
      }else{
        try{
          print('Saving game "${fn}.sav".  Use "restore" to restore it.');
          File f2 = new File('games${Platform.pathSeparator}${fn}.sav');
          OutputStream s = f2.openOutputStream();
          s.writeFrom(saveBytes);
          s.close();
          c.complete(true);
        }catch(FileIOException e){
          print('File IO error.');
          c.complete(false);
        }
      }
    };

    return c.future;
  }

  Future<List<int>> restore(){
    var c = new Completer();
    print('Enter game file name to load (no extension):');

    textStream.onLine = (){
      var fn = textStream.readLine();
      if (fn == null || fn.isEmpty())
      {
        print('Invalid file name given.');
        c.complete(null);
      }else{
        try{
          print('Restoring game "${fn}.sav"...');
          File f2 = new File('games${Platform.pathSeparator}${fn}.sav');
          c.complete(f2.readAsBytesSync());
        }catch(FileIOException e){
          print('File IO error.');
          c.complete(null);
        }
      }
    };

    return c.future;
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
          print('$s');
          s = new StringBuffer();
          s.add(nextWord + ' ');
        }else{
          if (words.isEmpty()){
            s.add(nextWord + ' ');
            outputBuffer.addFirst('$s');
            print('$s');
            s = new StringBuffer();
          }else{
            s.add(nextWord + ' ');
          }
        }
      }

      if (s.length > 0){
        outputBuffer.addFirst('$s');
        print('$s');
        s = new StringBuffer();
      }
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
