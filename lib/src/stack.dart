import 'package:zart/src/engines/engine.dart';
import 'package:zart/src/game_exception.dart';
import 'package:zart/src/math_helper.dart';

/// Z-Machine Stack
class Stack {
  /// The stack.
  final List<int> stack;

  /// The maximum size of the stack.
  final int _max;

  /// The stack pointer.
  int sp = 0;

  /// Instantiates an empty [Stack].
  Stack() : stack = <int>[], _max = 0;

  /// Instantiates a [Stack] with a maximum size.
  Stack.max(this._max) : stack = <int>[];

  /// Pops the top value from the stack.
  int pop() {
    final v = stack[0];
    stack.removeAt(0);

    //no Dart negative values should exist here
    //except the special stack-end flag 0x-10000
    assert(v == Engine.stackMarker || v >= 0);

    return v;
  }

  /// Gets the value at the specified index.
  int operator [](int index) {
    final v = stack[index];

    //no Dart negative values should exist here
    //except the spcecial stack-end flag 0x-10000
    assert(v == Engine.stackMarker || v >= 0);

    return v;
  }

  /// Sets the value at the specified index.
  void operator []=(int index, int value) {
    if (value < 0 && value != Engine.stackMarker) {
      value = MathHelper.dartSignedIntTo16BitSigned(value);
    }

    stack[index] = value;
  }

  /// Pushes a value onto the stack.
  void push(int value) {
    //ref 6.3.3
    if (_max > 0 && length == (_max - 1)) {
      throw GameException('Stack Overflow. $_max');
    }
    //
    //    if (length % 1024 == 0){
    //      Debugger.debug('stack at $length');
    //      Debugger.debug('text buffer: ${Z.sbuff}');
    //    }

    //excluding the stack boundary flag
    if (value < 0 && value != Engine.stackMarker) {
      value = MathHelper.dartSignedIntTo16BitSigned(value);
    }

    stack.insert(0, value);
  }

  /// Peeks the top value from the stack.
  int peek() {
    final v = stack[0];

    //no Dart negative values should exist here
    //except the spcecial stack-end flag 0x-10000
    assert(v == Engine.stackMarker || v >= 0);

    return v;
  }

  /// Clears the stack.
  void clear() => stack.clear();

  /// Dumps the stack.
  void dump() {
    int p = 0;
    for (var i in stack) {
      print("${p++}: 0x${i.toRadixString(16)}");
    }
  }

  @override
  String toString() => stack.map((s) => '0x${s.toRadixString(16)}').toString();

  //  void inc(int amount){
  //    sp += amount;
  //  }
  //
  //  void dec(int amount){
  //    sp -= amount;
  //  }

  /// Gets the length of the stack.
  int get length => stack.length;
}
