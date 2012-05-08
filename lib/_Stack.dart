
//TODO error handling

class _Stack {
  /// Z-Machine Stack
  final Queue<int> _stack;
  final int max;
  
  int sp = 0;
  
  _Stack()
  : 
    _stack = new Queue<int>(),
    max = 0;

  _Stack.max(this.max)
  :
    _stack = new Queue<int>();
  
  int pop() => _stack.removeFirst();

  int operator [](int index){
    return new List.from(_stack)[index];
  }
  
  int operator []=(int index, int value){
    this[index] = value;
  }
  
  void push(int value) {
    //ref 6.3.3
    if (max > 0 && length == (max - 1))
      throw const Exception('Stack Overflow.');
    
    _stack.addFirst(value);
  }

  int peek() => _stack.first();

  void clear() => _stack.clear();
  
  void inc(int amount){
    sp += amount;
  }
  
  void dec(int amount){
    sp -= amount;
  }
  
  int get length() => _stack.length;
}
