import 'dart:io';

import 'package:zart/src/engines/engine.dart';
import 'package:zart/src/game_exception.dart';
import 'package:zart/src/math_helper.dart';

/// Z-Machine Stack
class Stack {
  final List<int> stack;
  final int _max;

  int sp = 0;

  Stack() : stack = <int>[], _max = 0;

  Stack.max(this._max) : stack = <int>[];

  int pop() {
    final v = stack[0];
    stack.removeAt(0);

    //no Dart negative values should exist here
    //except the special stack-end flag 0x-10000
    assert(v == Engine.stackMarker || v >= 0);

    return v;
  }

  int operator [](int index) {
    final v = stack[index];

    //no Dart negative values should exist here
    //except the spcecial stack-end flag 0x-10000
    assert(v == Engine.stackMarker || v >= 0);

    return v;
  }

  void operator []=(int index, int value) {
    if (value < 0 && value != Engine.stackMarker) {
      value = MathHelper.dartSignedIntTo16BitSigned(value);
    }

    stack[index] = value;
  }

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

  int peek() {
    final v = stack[0];

    //no Dart negative values should exist here
    //except the spcecial stack-end flag 0x-10000
    assert(v == Engine.stackMarker || v >= 0);

    return v;
  }

  void clear() => stack.clear();

  void dump() {
    int p = 0;
    for (var i in stack) {
      stdout.writeln("${p++}: 0x${i.toRadixString(16)}");
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

  int get length => stack.length;
}
