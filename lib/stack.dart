import 'package:zart/engines/engine.dart';
import 'package:zart/game_exception.dart';
import 'package:zart/math_helper.dart';

/// Z-Machine Stack
class Stack {
  final List<int> stack;
  final int _max;

  int sp = 0;

  Stack()
  :
    stack = List<int>(),
    _max = 0;

  Stack.max(this._max)
  :
    stack = List<int>();

  int pop() {
    final v = stack[0];
    stack.removeAt(0);

    //no Dart negative values should exist here
    //except the special stack-end flag 0x-10000
    assert(v == Engine.STACK_MARKER || v >= 0);

    return v;
  }

  int operator [](int index){
    final v = stack[index];

    //no Dart negative values should exist here
    //except the spcecial stack-end flag 0x-10000
    assert(v == Engine.STACK_MARKER || v >= 0);

    return v;
  }

  void operator []=(int index, int value){

    if (value < 0 && value != Engine.STACK_MARKER){
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
    if (value < 0 && value != Engine.STACK_MARKER){
      value = MathHelper.dartSignedIntTo16BitSigned(value);
    }

    stack.insert(0, value);
  }

  int peek(){
    final v = stack[0];

    //no Dart negative values should exist here
    //except the spcecial stack-end flag 0x-10000
    assert(v == Engine.STACK_MARKER || v >= 0);

    return v;
  }

  void clear() => stack.clear();

  void dump(){
    int p = 0;
    stack.forEach((i){
      print("${p++}: 0x${i.toRadixString(16)}");
    });
  }

  String toString(){
    final mapped = stack.map((s) => '0x${s.toRadixString(16)}');
    return '$mapped';
  }

//  void inc(int amount){
//    sp += amount;
//  }
//
//  void dec(int amount){
//    sp -= amount;
//  }

  int get length => stack.length;
}
