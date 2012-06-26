
//TODO error handling

class _Stack {
  /// Z-Machine Stack
  final List<int> _stack;
  final int max;

  int sp = 0;

  _Stack()
  :
    _stack = new List<int>(),
    max = 0;

  _Stack.max(this.max)
  :
    _stack = new List<int>();

  int pop() {
    var v = _stack[0];
    _stack.removeRange(0, 1);

    //no Dart negative values should exist here
    //except the spcecial stack-end flag 0x-10000
    assert(v == Machine.STACK_MARKER || v >= 0);

    return v;
  }

  int operator [](int index){
    var v = _stack[index];

    //no Dart negative values should exist here
    //except the spcecial stack-end flag 0x-10000
    assert(v == Machine.STACK_MARKER || v >= 0);

    return v;
  }

  void operator []=(int index, int value){

    if (value < 0 && value != Machine.STACK_MARKER){
      value = Machine.dartSignedIntTo16BitSigned(value);
    }

    _stack[index] = value;
  }

  void push(int value) {
    //ref 6.3.3
    if (max > 0 && length == (max - 1))
      throw new GameException('Stack Overflow. $max');
//
//    if (length % 1024 == 0){
//      Debugger.debug('stack at $length');
//      Debugger.debug('text buffer: ${Z.sbuff}');
//    }

    //excluding the stack boundary flag
    if (value < 0 && value != Machine.STACK_MARKER){
      value = Machine.dartSignedIntTo16BitSigned(value);
    }

    _stack.insertRange(0, 1, value);
  }

  int peek(){
    var v = _stack[0];

    //no Dart negative values should exist here
    //except the spcecial stack-end flag 0x-10000
    assert(v == Machine.STACK_MARKER || v >= 0);

    return v;
  }

  void clear() => _stack.clear();

  void dump(){
    int p = 0;
    _stack.forEach((i){
      print("${p++}: 0x${i.toRadixString(16)}");
    });
  }

  String toString(){
    var mapped = _stack.map((s) => '0x${s.toRadixString(16)}');
    return '$mapped';
  }

//  void inc(int amount){
//    sp += amount;
//  }
//
//  void dec(int amount){
//    sp -= amount;
//  }

  int get length() => _stack.length;
}
