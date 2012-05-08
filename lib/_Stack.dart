
//TODO error handling

class _Stack {
  /// Z-Machine Stack
  final Queue<int> _stack;

  int sp = 0;
  
  _Stack()
  : _stack = new Queue<int>();

  int pop() => _stack.removeFirst();

  void push(int value) => _stack.addFirst(value);

  int peek() => _stack.first();

  void clear() => _stack.clear();
  
  void inc(int amount){
    sp += amount;
  }
  
  void dec(int amount){
    sp -= amount;
  }
}
