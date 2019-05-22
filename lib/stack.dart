import 'package:zart/machines/machine.dart';
import 'package:zart/game_exception.dart';

/// Z-Machine Stack
class Stack {
  final List<int> stack;
  final int _max;

  int sp = 0;

  Stack()
  :
    stack = new List<int>(),
    _max = 0;

  Stack.max(this._max)
  :
    stack = new List<int>();

  int pop() {
    var v = stack[0];
    stack.removeRange(0, 1);

    //no Dart negative values should exist here
    //except the spcecial stack-end flag 0x-10000
    assert(v == Machine.STACK_MARKER || v >= 0);

    return v;
  }

  int operator [](int index){
    var v = stack[index];

    //no Dart negative values should exist here
    //except the spcecial stack-end flag 0x-10000
    assert(v == Machine.STACK_MARKER || v >= 0);

    return v;
  }

  void operator []=(int index, int value){

    if (value < 0 && value != Machine.STACK_MARKER){
      value = Machine.dartSignedIntTo16BitSigned(value);
    }

    stack[index] = value;
  }

  void push(int value) {
    //ref 6.3.3
    if (_max > 0 && length == (_max - 1)) {
      throw new GameException('Stack Overflow. $_max');
    }
//
//    if (length % 1024 == 0){
//      Debugger.debug('stack at $length');
//      Debugger.debug('text buffer: ${Z.sbuff}');
//    }

    //excluding the stack boundary flag
    if (value < 0 && value != Machine.STACK_MARKER){
      value = Machine.dartSignedIntTo16BitSigned(value);
    }

    stack.fillRange(0, 1, value);
  }

  int peek(){
    var v = stack[0];

    //no Dart negative values should exist here
    //except the spcecial stack-end flag 0x-10000
    assert(v == Machine.STACK_MARKER || v >= 0);

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
    var mapped = stack.map((s) => '0x${s.toRadixString(16)}');
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
