import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_anon_fn.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';
import 'package:zart/src/tads3/vm/t3_object_table.dart';
import 'package:zart/src/tads3/vm/t3_stack.dart';

class MockStack extends T3Stack {
  MockStack() : super(100, 10);

  void pushInt(int val) => push(T3Value(T3DataType.int32)..setInt(val));
}

class MockVM extends T3VM {
  @override
  final MockStack stack = MockStack();
  @override
  final T3ObjectTable objTable = T3ObjectTable();
}

void main() {
  group('T3ObjAnonFn', () {
    late MockVM vm;

    setUp(() {
      vm = MockVM();
    });

    test('creation from stack (function pointer only)', () {
      vm.stack.push(T3Value(T3DataType.funcPtr)..setFnPtr(1234));
      final id = T3ObjAnonFn.createFromStack(vm, 1);

      final obj = vm.objTable.getObj(id);
      expect(obj, isA<T3ObjAnonFn>());
      final anonFn = obj as T3ObjAnonFn;

      expect(anonFn.length, equals(1));
      expect(anonFn.getElement(1).type, equals(T3DataType.funcPtr));
      expect(anonFn.getElement(1).getAsOfs(), equals(1234));
    });

    test('creation from stack (with context)', () {
      // Context 1: 42, Context 2: 99, Func: 1234
      // Pushed as: [42, 99, 1234]
      vm.stack.pushInt(42);
      vm.stack.pushInt(99);
      vm.stack.push(T3Value(T3DataType.funcPtr)..setFnPtr(1234));

      final id = T3ObjAnonFn.createFromStack(vm, 3);
      final anonFn = vm.objTable.getObj(id) as T3ObjAnonFn;

      expect(anonFn.length, equals(3));
      expect(anonFn.getElement(1).getAsOfs(), equals(1234));
      expect(anonFn.getElement(2).getAsInt(), equals(99));
      expect(anonFn.getElement(3).getAsInt(), equals(42));
    });

    test('getInvoker returns function pointer', () {
      vm.stack.push(T3Value(T3DataType.funcPtr)..setFnPtr(5555));
      final id = T3ObjAnonFn.createFromStack(vm, 1);
      final anonFn = vm.objTable.getObj(id) as T3ObjAnonFn;

      final invoker = T3Value();
      final ok = anonFn.getInvoker(vm, invoker);
      expect(ok, isTrue);
      expect(invoker.type, equals(T3DataType.funcPtr));
      expect(invoker.getAsOfs(), equals(5555));
    });

    test('getInvoker with nested invokable object', () {
      // Inner anon fn
      vm.stack.push(T3Value(T3DataType.funcPtr)..setFnPtr(8888));
      final innerId = T3ObjAnonFn.createFromStack(vm, 1);

      // Outer anon fn pointing to inner
      vm.stack.push(T3Value(T3DataType.obj)..setObj(innerId));
      final outerId = T3ObjAnonFn.createFromStack(vm, 1);
      final outerFn = vm.objTable.getObj(outerId) as T3ObjAnonFn;

      final invoker = T3Value();
      final ok = outerFn.getInvoker(vm, invoker);
      expect(ok, isTrue);
      expect(invoker.type, equals(T3DataType.funcPtr));
      expect(invoker.getAsOfs(), equals(8888));
    });

    test('isListlike is false', () {
      final anonFn = T3ObjAnonFn(1);
      expect(anonFn.isListlike(vm, 0), isFalse);
    });

    test('equals by reference', () {
      final anon1 = T3ObjAnonFn(1);
      final id1 = 100;
      final id2 = 101;

      expect(
        anon1.equals(vm, id1, T3Value(T3DataType.obj)..setObj(id1), 0),
        isTrue,
      );
      expect(
        anon1.equals(vm, id1, T3Value(T3DataType.obj)..setObj(id2), 0),
        isFalse,
      );
    });
  });
}
