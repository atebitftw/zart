import 'dart:collection';
import 'dart:async';
import 'package:zart/IO/io_provider.dart';

/**
* Default provider with word-wrap support.
*
* Cannot take input because it has no IO
* context.  Also cannot provide async facility
* so just runs sync.
*
*/
class DefaultProvider implements IOProvider
{
  final Queue<String> script;
  final int cols = 80;

  DefaultProvider(List<String> script)
  :
    script = Queue<String>.from(script);


  Future<Object> command(Map<String, dynamic> command){
    return Future.value(null);
  }

  Future<bool> saveGame(List<int> saveBytes){
    print('Save not supported with this provider.');
    var c = Completer();
    c.complete(false);
    return c.future;
  }

  Future<List<int>> restore(){
    print('Restore not supported with this provider.');
    var c = Completer();
    c.complete(null);
    return c.future;
  }

  void PrimaryOutput(String text) {
    var lines = text.split('\n');
    for(final l in lines){
      var words = Queue<String>.from(l.split(' '));

      var s = StringBuffer();
      while(!words.isEmpty){
        var nextWord = words.removeFirst();

        if (s.length > cols){
          print('$s');
          s = StringBuffer();
          s.write('$nextWord ');
        }else{
          if (words.isEmpty){
            s.write('$nextWord ');
            print('$s');
            s = StringBuffer();
          }else{
            s.write('$nextWord ');
          }
        }
      }

      if (s.length > 0){
        print('$s');
        s = StringBuffer();
      }
    }
  }

  void DebugOutput(String text) => print(text);

  Future<String> getLine(){
    Completer c = Completer();

    if (!script.isEmpty){
      c.complete(script.removeFirst());
    }

    return c.future;
  }
}