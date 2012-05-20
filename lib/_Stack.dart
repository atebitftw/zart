
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
    return v;
  }

  int operator [](int index){
    return _stack[index];
  }

  int operator []=(int index, int value){

    if (value < 0 && value > -0x10000){
      value = Machine.dartSignedIntTo16BitSigned(value);
    }

    _stack[index] = value;
  }

  void push(int value) {
    //ref 6.3.3
    if (max > 0 && length == (max - 1))
      throw new GameException('Stack Overflow.');

    //excluding the stack boundary flag
    if (value < 0 && value > -0x10000){
      value = Machine.dartSignedIntTo16BitSigned(value);
    }

    _stack.insertRange(0, 1, value);
  }

  int peek() => _stack.isEmpty() ? null : _stack[0];

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
