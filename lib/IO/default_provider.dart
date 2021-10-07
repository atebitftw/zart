import 'dart:collection';
import 'dart:async';
import 'dart:io';
import 'package:zart/IO/io_provider.dart';


/// Default provider with word-wrap support.
///
/// Cannot take input because it has no IO
/// context.  Also cannot provide async facility
/// so just runs sync.
class DefaultProvider implements IOProvider
{
  final Queue<String> script;
  final int cols = 80;

  DefaultProvider(List<String> script)
  :
    script = Queue<String>.from(script);


  @override
  Future<void> command(Map<String, dynamic> command) {
    return Future.value();
  }

  Future<bool> saveGame(List<int> saveBytes){
    stdout.writeln('Save not supported with this provider.');
    var c = Completer();
    c.complete(false);
    return c.future.then((value) => value as bool);
  }

  Future<List<int>> restore(){
    stdout.writeln('Restore not supported with this provider.');
    var c = Completer();
    c.complete(null);
    return c.future.then((value) => value as List<int>);
  }

  void primaryOutput(String text) {
    var lines = text.split('\n');
    for(final l in lines){
      var words = Queue<String>.from(l.split(' '));

      var s = StringBuffer();
      while(words.isNotEmpty){
        var nextWord = words.removeFirst();

        if (s.length > cols){
          stdout.writeln('$s');
          s = StringBuffer();
          s.write('$nextWord ');
        }else{
          if (words.isEmpty){
            s.write('$nextWord ');
            stdout.writeln('$s');
            s = StringBuffer();
          }else{
            s.write('$nextWord ');
          }
        }
      }

      if (s.length > 0){
        stdout.writeln('$s');
        s = StringBuffer();
      }
    }
  }

  void debugOutput(String text) => stdout.writeln(text);

  Future<String> getLine(){
    Completer c = Completer();

    if (script.isNotEmpty){
      c.complete(script.removeFirst());
    }

    return c.future.then((value) => value as String);
  }
}