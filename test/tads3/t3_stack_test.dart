import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_stack.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';

/// T3 Stack unit tests with TADS 3 specification validation.
///
/// Spec Reference: packages/tads-sources/t3doc/techman/t3spec/model.htm
/// - "Stack Organization" section (lines 1157-1363)
/// - "Machine Registers" section (lines 1112-1155)
void main() {
  group('T3Stack basic operations', () {
    late T3Stack stack;

    setUp(() {
      stack = T3Stack();
    });

    /// Spec: model.htm lines 1168-1174:
    /// "The stack is organized as an array of value holders. Each value
    /// holder contains a type code and a value. A stack pointer register
    /// (SP) points to the next available element of the stack at any
    /// given time."
    test('empty stack has zero depth', () {
      expect(stack.depth, 0);
      expect(stack.sp, 0);
      expect(stack.fp, 0);
    });

    /// Spec: model.htm lines 1191-1192:
    /// "A 'push' operation stores a value at the stack location to which
    /// SP points, and then increments SP."
    test('push increases depth', () {
      stack.push(T3Value.fromInt(42));
      expect(stack.depth, 1);
      expect(stack.sp, 1);
    });

    /// Spec: model.htm lines 1195-1196:
    /// "A 'pop' operation decrements SP, then retrieves the value at the
    /// stack location to which SP points."
    test('pop decreases depth', () {
      stack.push(T3Value.fromInt(42));
      stack.push(T3Value.fromInt(43));
      expect(stack.depth, 2);

      final val = stack.pop();
      expect(val.value, 43);
      expect(stack.depth, 1);
    });

    /// Spec: This is a convenience operation not explicitly defined but
    /// follows from the stack-based machine model.
    test('peek returns top without removing', () {
      stack.push(T3Value.fromInt(42));
      stack.push(T3Value.fromInt(43));

      final val = stack.peek();
      expect(val.value, 43);
      expect(stack.depth, 2); // Unchanged
    });

    /// Spec: model.htm lines 1179-1180:
    /// "Local variables are at locations above the frame pointer, and
    /// actual parameters are at locations below the frame pointer"
    /// This requires indexed access to stack elements.
    test('get returns element by index from top', () {
      stack.push(T3Value.fromInt(10));
      stack.push(T3Value.fromInt(20));
      stack.push(T3Value.fromInt(30));

      expect(stack.get(0).value, 30); // Top
      expect(stack.get(1).value, 20);
      expect(stack.get(2).value, 10); // Bottom
    });

    /// Spec: Implied by property setting and local variable assignment
    /// operations throughout the bytecode spec.
    test('set modifies element by index from top', () {
      stack.push(T3Value.fromInt(10));
      stack.push(T3Value.fromInt(20));
      stack.push(T3Value.fromInt(30));

      stack.set(1, T3Value.fromInt(999));
      expect(stack.get(1).value, 999);
    });

    /// Spec: model.htm lines 1330-1332:
    /// "Load SP with the value in FP. This effectively discards all
    /// local variables and any intermediate calculation results still
    /// on the stack."
    test('discard removes top element', () {
      stack.push(T3Value.fromInt(10));
      stack.push(T3Value.fromInt(20));

      stack.discard();
      expect(stack.depth, 1);
      expect(stack.peek().value, 10);
    });

    /// Spec: model.htm lines 1353-1355:
    /// "Discard the number of items at the top of the stack given by the
    /// actual parameter count that we noted earlier. This discards the
    /// arguments to the function."
    test('discard with count removes multiple elements', () {
      stack.push(T3Value.fromInt(10));
      stack.push(T3Value.fromInt(20));
      stack.push(T3Value.fromInt(30));
      stack.push(T3Value.fromInt(40));

      stack.discard(2);
      expect(stack.depth, 2);
      expect(stack.peek().value, 20);
    });

    /// Spec: Implied by the need to prevent stack overflow during execution.
    test('checkSpace returns true when space available', () {
      expect(stack.checkSpace(100), isTrue);
    });

    /// Spec: model.htm describes restarting behavior, which requires
    /// resetting the machine state including the stack.
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
    /// Spec: model.htm lines 1168-1170:
    /// "The stack is organized as an array of value holders."
    /// Each value holder is independent, so pushing should copy.
    test('push creates copy of value', () {
      final original = T3Value.fromInt(42);
      final stack = T3Stack();

      stack.push(original);
      original.value = 100;

      expect(stack.peek().value, 42); // Stack has copy
    });

    /// Spec: Pop returns the value from the stack location.
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
      for (var i = 0; i < 6; i++) {
        stack.push(T3Value.fromInt(i));
      }
      stack.fp = 5;

      // Locals at FP+1, FP+2, FP+3
      stack.push(T3Value.fromInt(100)); // Local 0
      stack.push(T3Value.fromInt(200)); // Local 1
      stack.push(T3Value.fromInt(300)); // Local 2
    });

    /// Spec: model.htm lines 1178-1180:
    /// "Local variables are at locations above the frame pointer"
    /// This means FP+1, FP+2, etc.
    test('getLocal returns correct local', () {
      expect(stack.getLocal(0).value, 100);
      expect(stack.getLocal(1).value, 200);
      expect(stack.getLocal(2).value, 300);
    });

    /// Spec: model.htm lines 1298-1300:
    /// "Read the number of local variables from the method header...
    /// Push nil for each local variable."
    /// Locals must be modifiable during execution.
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

    /// Spec: model.htm lines 1276-1282:
    /// "Push the frame pointer (FP) register... Store the current stack
    /// pointer (SP) register value in the frame pointer (FP) register.
    /// This establishes the new function activation frame."
    test('pushFrame creates activation frame', () {
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
      expect(stack.getArgCount(), 2);
      expect(stack.getReturnAddress(), 0x1234);
      expect(stack.getEntryPointer(), 0x5678);
      expect(stack.getSelf().value, 42);
    });

    /// Spec: model.htm lines 1298-1300:
    /// "Read the number of local variables from the method header at the
    /// EP register. Push nil for each local variable."
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

    /// Spec: model.htm lines 1182-1188:
    /// "The frame pointer always points to a stack location that contains
    /// the frame pointer of the enclosing frame"
    /// Nested frames must be able to chain back to their callers.
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

      expect(stack.getLocal(0).value, 222);
      expect(stack.getLocal(1).value, 333);
      expect(stack.getReturnAddress(), 0x2000);

      // Pop second frame
      final (retAddr, _, _, _, _) = stack.popFrame();
      expect(retAddr, 0x2000);
      expect(stack.fp, fp1);
      expect(stack.getLocal(0).value, 111);
      expect(stack.getReturnAddress(), 0x1000);
    });
  });

  group('T3Stack walkFrames', () {
    /// Spec: Implied by debugger/introspection needs - t3GetStackTrace().
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

    /// Spec: model.htm lines 1182-1184:
    /// "The frame pointer always points to a stack location that contains
    /// the frame pointer of the enclosing frame"
    test('walks nested frames', () {
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
      final fp1 = stack.fp;

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

    /// Spec: Implied by the need to limit stack trace depth.
    test('walkFrames can stop early', () {
      final stack = T3Stack();

      for (var i = 0; i < 3; i++) {
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
      }

      var count = 0;
      stack.walkFrames((fp, depth) {
        count++;
        return depth < 1;
      });

      expect(count, 2);
    });
  });

  group('T3Stack dumpTop', () {
    /// Spec: Debugging/diagnostic utility.
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

  // ==================== SPEC-VALIDATED FRAME STRUCTURE TESTS ====================

  group('T3Stack frame header layout', () {
    /// Spec: model.htm lines 1217-1248 describes the frame setup sequence.
    /// The frame header contains, in order pushed:
    /// - target property (line 1217)
    /// - target object (lines 1219-1223)
    /// - defining object (lines 1225-1229)
    /// - self (lines 1231-1234)
    /// - invokee (lines 1236-1243)
    /// - frame reference slot - nil (lines 1245-1248)
    /// - return address (lines 1263-1271)
    /// - entry pointer (line 1273)
    /// - argument count (line 1275)
    /// - enclosing FP (lines 1277-1278)
    test('frame header contains all required slots per spec', () {
      final stack = T3Stack();

      stack.push(T3Value.fromInt(111)); // Arg 0
      stack.push(T3Value.fromInt(222)); // Arg 1

      stack.pushFrame(
        argCount: 2,
        localCount: 2,
        returnAddr: 0xABCD,
        entryPtr: 0x1234,
        self: T3Value.fromObject(99),
        targetObj: T3Value.fromObject(88),
        definingObj: T3Value.fromObject(77),
        targetProp: 0x55,
        invokee: T3Value.fromFuncPtr(0x6666),
      );

      // Verify frame header slots per spec order
      expect(stack.getFromFrame(0).isInt, isTrue); // Enclosing FP
      expect(stack.getArgCount(), 2); // FP-1
      expect(stack.getEntryPointer(), 0x1234); // FP-2
      expect(stack.getReturnAddress(), 0xABCD); // FP-3

      /// Spec: model.htm lines 1245-1248:
      /// "Push nil. This slot is reserved for use for StackFrameRef
      /// objects; initially, a frame has no frame reference"
      expect(stack.getFromFrame(T3Stack.fpOfsFrameRef).isNil, isTrue);

      expect(stack.getInvokee().value, 0x6666); // FP-6
      expect(stack.getSelf().value, 99); // FP-7
      expect(stack.getDefiningObject().value, 77); // FP-8
      expect(stack.getTargetObject().value, 88); // FP-9
      expect(stack.getTargetProp().value, 0x55); // FP-10
    });

    /// Spec: model.htm lines 1298-1300:
    /// "Read the number of local variables from the method header at the
    /// EP register. Push nil for each local variable."
    test('locals are initialized to nil', () {
      final stack = T3Stack();

      stack.pushFrame(
        argCount: 0,
        localCount: 5,
        returnAddr: 0,
        entryPtr: 0,
        self: T3Value.nil(),
        targetObj: T3Value.nil(),
        definingObj: T3Value.nil(),
        targetProp: 0,
        invokee: T3Value.nil(),
      );

      for (var i = 0; i < 5; i++) {
        expect(stack.getLocal(i).isNil, isTrue, reason: 'Local $i should be nil per spec');
      }
    });
  });

  group('T3Stack argument handling', () {
    /// Spec: model.htm lines 1180-1182:
    /// "actual parameters are at locations below the frame pointer
    /// (because they are pushed onto the stack by the caller, before
    /// the current function's frame was activated)"
    test('arguments are accessible after frame creation', () {
      final stack = T3Stack();

      // Caller pushes args (right to left per TADS convention)
      stack.push(T3Value.fromInt(333)); // Arg 2
      stack.push(T3Value.fromInt(222)); // Arg 1
      stack.push(T3Value.fromInt(111)); // Arg 0

      stack.pushFrame(
        argCount: 3,
        localCount: 5,
        returnAddr: 0,
        entryPtr: 0,
        self: T3Value.nil(),
        targetObj: T3Value.nil(),
        definingObj: T3Value.nil(),
        targetProp: 0,
        invokee: T3Value.nil(),
      );

      // Reference implementation copies first N args to locals
      expect(stack.getLocal(0).value, 111, reason: 'Arg 0 -> Local 0');
      expect(stack.getLocal(1).value, 222, reason: 'Arg 1 -> Local 1');
      expect(stack.getLocal(2).value, 333, reason: 'Arg 2 -> Local 2');
      expect(stack.getLocal(3).isNil, isTrue);
      expect(stack.getLocal(4).isNil, isTrue);
    });

    /// Spec: model.htm lines 1290-1297:
    /// Varargs functions can take more arguments than local slots.
    /// "Compare the argument count... If the value in the method header
    /// has its high bit set, it indicates that the function is a
    /// 'varargs' function... the actual parameter count must be greater
    /// than or equal to the header value"
    test('excess arguments remain accessible via getArg', () {
      final stack = T3Stack();

      stack.push(T3Value.fromInt(444));
      stack.push(T3Value.fromInt(333));
      stack.push(T3Value.fromInt(222));
      stack.push(T3Value.fromInt(111));

      stack.pushFrame(
        argCount: 4,
        localCount: 2,
        returnAddr: 0,
        entryPtr: 0,
        self: T3Value.nil(),
        targetObj: T3Value.nil(),
        definingObj: T3Value.nil(),
        targetProp: 0,
        invokee: T3Value.nil(),
      );

      expect(stack.getLocal(0).value, 111);
      expect(stack.getLocal(1).value, 222);

      // All args still accessible via getArg
      expect(stack.getArg(0).value, 111);
      expect(stack.getArg(1).value, 222);
      expect(stack.getArg(2).value, 333);
      expect(stack.getArg(3).value, 444);
    });
  });

  group('T3Stack return sequence', () {
    /// Spec: model.htm lines 1314-1362 describes the return sequence:
    /// "Load SP with the value in FP... Pop the item at the top of the
    /// stack and store it in FP... Get the argument count... Pop the
    /// enclosing frame's entrypoint code offset..."
    test('popFrame restores caller state and discards frame', () {
      final stack = T3Stack();

      // Caller frame
      stack.pushFrame(
        argCount: 0,
        localCount: 2,
        returnAddr: 0x1000,
        entryPtr: 0x100,
        self: T3Value.fromObject(1),
        targetObj: T3Value.nil(),
        definingObj: T3Value.nil(),
        targetProp: 0,
        invokee: T3Value.nil(),
      );
      final callerFp = stack.fp;
      stack.setLocal(0, T3Value.fromInt(42));
      stack.setLocal(1, T3Value.fromInt(43));

      stack.push(T3Value.fromInt(500));
      stack.push(T3Value.fromInt(600));

      // Nested call
      stack.pushFrame(
        argCount: 2,
        localCount: 3,
        returnAddr: 0x2000,
        entryPtr: 0x200,
        self: T3Value.fromObject(2),
        targetObj: T3Value.nil(),
        definingObj: T3Value.nil(),
        targetProp: 0,
        invokee: T3Value.nil(),
      );

      stack.setLocal(0, T3Value.fromInt(999));
      stack.push(T3Value.fromInt(123));

      // Return
      final (returnAddr, _, entryPtr, _, _) = stack.popFrame();

      /// Spec: model.htm lines 1344-1348:
      /// "Pop the item at the top of the stack; this is the return
      /// address's code offset. Add this offset to the result of
      /// translating the EP register..."
      expect(returnAddr, 0x2000);
      expect(entryPtr, 0x200);
      expect(stack.fp, callerFp);
      expect(stack.getLocal(0).value, 42);
      expect(stack.getLocal(1).value, 43);
      expect(stack.getSelf().value, 1);
    });
  });

  group('T3Stack method context', () {
    /// Spec: model.htm lines 1217-1244 describes pushing method context:
    /// - line 1217: "Push the property ID of the property being invoked."
    /// - lines 1219-1223: "Push a reference to the object whose method
    ///   is to be invoked; this is the 'target object' value."
    /// - lines 1225-1229: "Push a reference to the object which defines
    ///   the property containing the method to be invoked."
    /// - lines 1231-1234: "Push a reference to the object whose method
    ///   is to be invoked; the 'self' object"
    test('setMethodContext updates all context values', () {
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

      stack.setMethodContext(
        self: T3Value.fromObject(100),
        targetProp: 0x55,
        targetObj: T3Value.fromObject(200),
        definingObj: T3Value.fromObject(300),
      );

      expect(stack.getSelf().value, 100);
      expect(stack.getTargetProp().value, 0x55);
      expect(stack.getTargetObject().value, 200);
      expect(stack.getDefiningObject().value, 300);
    });
  });

  group('T3Stack frame offset constants', () {
    /// Spec: Reference implementation vmrun.h VMRUN_FPOFS_* constants.
    /// These offsets are implementation-defined but must be consistent
    /// with the frame layout described in model.htm lines 1217-1282.
    test('frame offset constants are correct', () {
      expect(T3Stack.fpOfsArgCount, -1);
      expect(T3Stack.fpOfsEntryPtr, -2);
      expect(T3Stack.fpOfsReturnAddr, -3);
      expect(T3Stack.fpOfsFrameRef, -5);
      expect(T3Stack.fpOfsInvokee, -6);
      expect(T3Stack.fpOfsSelf, -7);
      expect(T3Stack.fpOfsDefObj, -8);
      expect(T3Stack.fpOfsTargetObj, -9);
      expect(T3Stack.fpOfsTargetProp, -10);
      expect(T3Stack.fpOfsArg1, -12);
    });
  });
}
