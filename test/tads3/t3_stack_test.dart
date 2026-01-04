import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_stack.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';

void main() {
  group('T3Stack basic operations', () {
    late T3Stack stack;

    setUp(() {
      stack = T3Stack();
    });

    test('empty stack has zero depth', () {
      expect(stack.depth, 0);
      expect(stack.sp, 0);
      expect(stack.fp, 0);
    });

    test('push increases depth', () {
      stack.push(T3Value.fromInt(42));
      expect(stack.depth, 1);
      expect(stack.sp, 1);
    });

    test('pop decreases depth', () {
      stack.push(T3Value.fromInt(42));
      stack.push(T3Value.fromInt(43));
      expect(stack.depth, 2);

      final val = stack.pop();
      expect(val.value, 43);
      expect(stack.depth, 1);
    });

    test('peek returns top without removing', () {
      stack.push(T3Value.fromInt(42));
      stack.push(T3Value.fromInt(43));

      final val = stack.peek();
      expect(val.value, 43);
      expect(stack.depth, 2); // Unchanged
    });

    test('get returns element by index from top', () {
      stack.push(T3Value.fromInt(10));
      stack.push(T3Value.fromInt(20));
      stack.push(T3Value.fromInt(30));

      expect(stack.get(0).value, 30); // Top
      expect(stack.get(1).value, 20);
      expect(stack.get(2).value, 10); // Bottom
    });

    test('set modifies element by index from top', () {
      stack.push(T3Value.fromInt(10));
      stack.push(T3Value.fromInt(20));
      stack.push(T3Value.fromInt(30));

      stack.set(1, T3Value.fromInt(999));
      expect(stack.get(1).value, 999);
    });

    test('discard removes top element', () {
      stack.push(T3Value.fromInt(10));
      stack.push(T3Value.fromInt(20));

      stack.discard();
      expect(stack.depth, 1);
      expect(stack.peek().value, 10);
    });

    test('discard with count removes multiple elements', () {
      stack.push(T3Value.fromInt(10));
      stack.push(T3Value.fromInt(20));
      stack.push(T3Value.fromInt(30));
      stack.push(T3Value.fromInt(40));

      stack.discard(2);
      expect(stack.depth, 2);
      expect(stack.peek().value, 20);
    });

    test('checkSpace returns true when space available', () {
      expect(stack.checkSpace(100), isTrue);
    });

    test('clear resets stack', () {
      stack.push(T3Value.fromInt(10));
      stack.push(T3Value.fromInt(20));

      stack.clear();
      expect(stack.depth, 0);
      expect(stack.sp, 0);
      expect(stack.fp, 0);
    });
  });

  group('T3Stack value copying', () {
    test('push creates copy of value', () {
      final original = T3Value.fromInt(42);
      final stack = T3Stack();

      stack.push(original);
      original.value = 100;

      expect(stack.peek().value, 42); // Stack has copy
    });

    test('pop returns value (not necessarily copy)', () {
      final stack = T3Stack();
      stack.push(T3Value.fromInt(42));

      final popped = stack.pop();
      expect(popped.value, 42);
    });
  });

  group('T3Stack local variable access', () {
    late T3Stack stack;

    setUp(() {
      stack = T3Stack();
      // Simulate a simple frame: FP at position 5, with 3 locals
      // In reality, frame setup is more complex, but for testing locals:
      for (var i = 0; i < 6; i++) {
        stack.push(T3Value.fromInt(i)); // Positions 0-5
      }
      stack.fp = 5; // FP points to position 5

      // Locals at FP+1, FP+2, FP+3
      stack.push(T3Value.fromInt(100)); // Local 0
      stack.push(T3Value.fromInt(200)); // Local 1
      stack.push(T3Value.fromInt(300)); // Local 2
    });

    test('getLocal returns correct local', () {
      expect(stack.getLocal(0).value, 100);
      expect(stack.getLocal(1).value, 200);
      expect(stack.getLocal(2).value, 300);
    });

    test('setLocal modifies correct local', () {
      stack.setLocal(1, T3Value.fromInt(999));
      expect(stack.getLocal(1).value, 999);
    });
  });

  group('T3Stack frame management', () {
    late T3Stack stack;

    setUp(() {
      stack = T3Stack();
    });

    test('pushFrame creates activation frame', () {
      // Push some arguments first
      stack.push(T3Value.fromInt(100)); // Arg 0
      stack.push(T3Value.fromInt(200)); // Arg 1

      final newFp = stack.pushFrame(
        argCount: 2,
        localCount: 3,
        returnAddr: 0x1234,
        entryPtr: 0x5678,
        self: T3Value.fromObject(42),
        targetObj: T3Value.nil(),
        definingObj: T3Value.nil(),
        targetProp: 0,
        invokee: T3Value.nil(),
      );

      expect(newFp, greaterThan(0));
      expect(stack.fp, newFp);

      // Check frame info
      expect(stack.getArgCount(), 2);
      expect(stack.getReturnAddress(), 0x1234);
      expect(stack.getEntryPointer(), 0x5678);
      expect(stack.getSelf().value, 42);
    });

    test('pushFrame allocates locals initialized to nil', () {
      stack.pushFrame(
        argCount: 0,
        localCount: 3,
        returnAddr: 0,
        entryPtr: 0,
        self: T3Value.nil(),
        targetObj: T3Value.nil(),
        definingObj: T3Value.nil(),
        targetProp: 0,
        invokee: T3Value.nil(),
      );

      expect(stack.getLocal(0).isNil, isTrue);
      expect(stack.getLocal(1).isNil, isTrue);
      expect(stack.getLocal(2).isNil, isTrue);
    });

    test('nested frames work correctly', () {
      // First frame
      stack.pushFrame(
        argCount: 0,
        localCount: 1,
        returnAddr: 0x1000,
        entryPtr: 0,
        self: T3Value.nil(),
        targetObj: T3Value.nil(),
        definingObj: T3Value.nil(),
        targetProp: 0,
        invokee: T3Value.nil(),
      );
      stack.setLocal(0, T3Value.fromInt(111));
      final fp1 = stack.fp;

      // Push args for second frame
      stack.push(T3Value.fromInt(999));

      // Second frame
      stack.pushFrame(
        argCount: 1,
        localCount: 2,
        returnAddr: 0x2000,
        entryPtr: 0,
        self: T3Value.nil(),
        targetObj: T3Value.nil(),
        definingObj: T3Value.nil(),
        targetProp: 0,
        invokee: T3Value.nil(),
      );
      stack.setLocal(0, T3Value.fromInt(222));
      stack.setLocal(1, T3Value.fromInt(333));

      // Verify second frame
      expect(stack.getLocal(0).value, 222);
      expect(stack.getLocal(1).value, 333);
      expect(stack.getReturnAddress(), 0x2000);

      // Pop second frame
      final (retAddr, _, _) = stack.popFrame();
      expect(retAddr, 0x2000);
      expect(stack.fp, fp1);

      // First frame preserved
      expect(stack.getLocal(0).value, 111);
      expect(stack.getReturnAddress(), 0x1000);
    });
  });

  group('T3Stack walkFrames', () {
    test('walks single frame', () {
      final stack = T3Stack();
      stack.pushFrame(
        argCount: 0,
        localCount: 0,
        returnAddr: 0,
        entryPtr: 0,
        self: T3Value.nil(),
        targetObj: T3Value.nil(),
        definingObj: T3Value.nil(),
        targetProp: 0,
        invokee: T3Value.nil(),
      );

      final frames = <int>[];
      stack.walkFrames((fp, depth) {
        frames.add(fp);
        return true;
      });

      expect(frames.length, 1);
    });

    test('walks nested frames', () {
      final stack = T3Stack();

      // First frame
      stack.pushFrame(
        argCount: 0,
        localCount: 0,
        returnAddr: 0,
        entryPtr: 0,
        self: T3Value.nil(),
        targetObj: T3Value.nil(),
        definingObj: T3Value.nil(),
        targetProp: 0,
        invokee: T3Value.nil(),
      );
      final fp1 = stack.fp;

      // Second frame
      stack.pushFrame(
        argCount: 0,
        localCount: 0,
        returnAddr: 0,
        entryPtr: 0,
        self: T3Value.nil(),
        targetObj: T3Value.nil(),
        definingObj: T3Value.nil(),
        targetProp: 0,
        invokee: T3Value.nil(),
      );
      final fp2 = stack.fp;

      final frames = <int>[];
      stack.walkFrames((fp, depth) {
        frames.add(fp);
        return true;
      });

      expect(frames.length, 2);
      expect(frames[0], fp2);
      expect(frames[1], fp1);
    });

    test('walkFrames can stop early', () {
      final stack = T3Stack();

      stack.pushFrame(
        argCount: 0,
        localCount: 0,
        returnAddr: 0,
        entryPtr: 0,
        self: T3Value.nil(),
        targetObj: T3Value.nil(),
        definingObj: T3Value.nil(),
        targetProp: 0,
        invokee: T3Value.nil(),
      );
      stack.pushFrame(
        argCount: 0,
        localCount: 0,
        returnAddr: 0,
        entryPtr: 0,
        self: T3Value.nil(),
        targetObj: T3Value.nil(),
        definingObj: T3Value.nil(),
        targetProp: 0,
        invokee: T3Value.nil(),
      );
      stack.pushFrame(
        argCount: 0,
        localCount: 0,
        returnAddr: 0,
        entryPtr: 0,
        self: T3Value.nil(),
        targetObj: T3Value.nil(),
        definingObj: T3Value.nil(),
        targetProp: 0,
        invokee: T3Value.nil(),
      );

      var count = 0;
      stack.walkFrames((fp, depth) {
        count++;
        return depth < 1; // Stop after first iteration
      });

      expect(count, 2);
    });
  });

  group('T3Stack dumpTop', () {
    test('dumpTop returns readable string', () {
      final stack = T3Stack();
      stack.push(T3Value.fromInt(10));
      stack.push(T3Value.fromInt(20));
      stack.push(T3Value.fromInt(30));

      final dump = stack.dumpTop(5);
      expect(dump, contains('int(30)'));
      expect(dump, contains('int(20)'));
      expect(dump, contains('int(10)'));
    });
  });
}
