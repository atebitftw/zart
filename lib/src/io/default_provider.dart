import 'dart:collection';
import 'dart:async';
import 'package:zart/zart.dart';

/// Default provider with word-wrap support.
///
/// Cannot take input because it has no IO
/// context.  Also cannot provide async facility
/// so just runs sync.
class DefaultProvider extends ZIoDispatcher {
  /// The script to run.
  final Queue<String> script;

  /// The number of columns.
  final int cols = 80;

  /// Creates a new default provider.
  DefaultProvider(List<String> script) : script = Queue<String>.from(script);

  @override
  Future<void> command(Map<String, dynamic> command) {
    return Future.value();
  }

  /// Saves the game.
  Future<bool> saveGame(List<int> saveBytes) {
    print('Save not supported with this provider.');
    var c = Completer();
    c.complete(false);
    return c.future.then((value) => value as bool);
  }

  /// Restores the game.
  Future<List<int>> restore() {
    print('Restore not supported with this provider.');
    var c = Completer();
    c.complete(null);
    return c.future.then((value) => value as List<int>);
  }

  /// Outputs text to the console.
  void primaryOutput(String text) {
    var lines = text.split('\n');
    for (final l in lines) {
      var words = Queue<String>.from(l.split(' '));

      var s = StringBuffer();
      while (words.isNotEmpty) {
        var nextWord = words.removeFirst();

        if (s.length > cols) {
          print('$s');
          s = StringBuffer();
          s.write('$nextWord ');
        } else {
          if (words.isEmpty) {
            s.write('$nextWord ');
            print('$s');
            s = StringBuffer();
          } else {
            s.write('$nextWord ');
          }
        }
      }

      if (s.length > 0) {
        print('$s');
        s = StringBuffer();
      }
    }
  }

  /// Outputs debug text to the console.
  void debugOutput(String text) => print(text);

  /// Gets a line of input from the console.
  Future<String> getLine() {
    Completer c = Completer();

    if (script.isNotEmpty) {
      c.complete(script.removeFirst());
    }

    return c.future.then((value) => value as String);
  }
}
