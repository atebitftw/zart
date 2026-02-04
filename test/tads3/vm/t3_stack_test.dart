// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_stack.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';
import 'package:zart/src/tads3/vm/t3_error.dart';

void main() {
  group('Construction', () {
    test('creates stack with specified depth', () {
      final stack = T3Stack(100, 20);
      expect(stack.getDepth(), equals(0));
    });

    test('initializes with empty stack', () {
      final stack = T3Stack(50, 10);
      expect(stack.getSp(), equals(0));
      expect(stack.getDepth(), equals(0));
    });

    test('init resets stack pointer', () {
      final stack = T3Stack(100, 20);
      stack.push(T3Value()..setInt(42));
      expect(stack.getDepth(), equals(1));

      stack.init();
      expect(stack.getDepth(), equals(0));
      expect(stack.getSp(), equals(0));
    });
  });

  group('Push Operations', () {
    test('push adds element to stack', () {
      final stack = T3Stack(100, 20);
      final val = T3Value()..setInt(42);

      stack.push(val);
      expect(stack.getDepth(), equals(1));
      expect(stack.get(0).getAsInt(), equals(42));
    });

    test('push multiple elements', () {
      final stack = T3Stack(100, 20);

      stack.push(T3Value()..setInt(1));
      stack.push(T3Value()..setInt(2));
      stack.push(T3Value()..setInt(3));

      expect(stack.getDepth(), equals(3));
      expect(stack.get(0).getAsInt(), equals(3)); // Top
      expect(stack.get(1).getAsInt(), equals(2)); // Middle
      expect(stack.get(2).getAsInt(), equals(1)); // Bottom
    });

    test('pushSlot returns index and increments sp', () {
      final stack = T3Stack(100, 20);

      final idx = stack.pushSlot();
      expect(idx, equals(0));
      expect(stack.getDepth(), equals(1));

      stack.setAt(idx, T3Value()..setInt(99));
      expect(stack.get(0).getAsInt(), equals(99));
    });

    test('pushMultiple allocates n slots', () {
      final stack = T3Stack(100, 20);

      final idx = stack.pushMultiple(5);
      expect(idx, equals(0));
      expect(stack.getDepth(), equals(5));

      // Fill the slots
      for (int i = 0; i < 5; i++) {
        stack.setAt(idx + i, T3Value()..setInt(i * 10));
      }

      expect(stack.get(4).getAsInt(), equals(0)); // First pushed
      expect(stack.get(0).getAsInt(), equals(40)); // Last pushed
    });

    test('pushCheck throws on overflow', () {
      final stack = T3Stack(5, 0);

      // Fill the stack
      for (int i = 0; i < 5; i++) {
        stack.push(T3Value()..setInt(i));
      }

      // Next push should overflow
      expect(
        () => stack.pushCheck(T3Value()..setInt(99)),
        throwsA(
          isA<T3VmException>().having(
            (e) => e.errorCode,
            'errorCode',
            vmErrStackOverflow,
          ),
        ),
      );
    });

    test('pushSlotCheck throws on overflow', () {
      final stack = T3Stack(3, 0);
      stack.pushMultiple(3);

      expect(
        () => stack.pushSlotCheck(),
        throwsA(
          isA<T3VmException>().having(
            (e) => e.errorCode,
            'errorCode',
            vmErrStackOverflow,
          ),
        ),
      );
    });

    test('pushMultipleCheck throws on overflow', () {
      final stack = T3Stack(10, 0);

      expect(
        () => stack.pushMultipleCheck(11),
        throwsA(
          isA<T3VmException>().having(
            (e) => e.errorCode,
            'errorCode',
            vmErrStackOverflow,
          ),
        ),
      );
    });
  });

  group('Pop and Discard Operations', () {
    test('pop removes and returns top element', () {
      final stack = T3Stack(100, 20);
      stack.push(T3Value()..setInt(10));
      stack.push(T3Value()..setInt(20));

      final val = T3Value();
      stack.pop(val);

      expect(val.getAsInt(), equals(20));
      expect(stack.getDepth(), equals(1));
      expect(stack.get(0).getAsInt(), equals(10));
    });

    test('discard removes top element', () {
      final stack = T3Stack(100, 20);
      stack.push(T3Value()..setInt(1));
      stack.push(T3Value()..setInt(2));

      stack.discard();

      expect(stack.getDepth(), equals(1));
      expect(stack.get(0).getAsInt(), equals(1));
    });

    test('discard removes n elements', () {
      final stack = T3Stack(100, 20);
      for (int i = 0; i < 5; i++) {
        stack.push(T3Value()..setInt(i));
      }

      stack.discard(3);

      expect(stack.getDepth(), equals(2));
      expect(stack.get(0).getAsInt(), equals(1));
    });
  });

  group('Access Operations', () {
    test('get returns element at index from top', () {
      final stack = T3Stack(100, 20);
      stack.push(T3Value()..setInt(10));
      stack.push(T3Value()..setInt(20));
      stack.push(T3Value()..setInt(30));

      expect(stack.get(0).getAsInt(), equals(30)); // Top
      expect(stack.get(1).getAsInt(), equals(20)); // Middle
      expect(stack.get(2).getAsInt(), equals(10)); // Bottom
    });

    test('getSp and setSp work correctly', () {
      final stack = T3Stack(100, 20);
      stack.push(T3Value()..setInt(1));
      stack.push(T3Value()..setInt(2));

      final sp = stack.getSp();
      expect(sp, equals(2));

      stack.push(T3Value()..setInt(3));
      expect(stack.getSp(), equals(3));

      stack.setSp(sp);
      expect(stack.getDepth(), equals(2));
    });

    test('getDepth returns current depth', () {
      final stack = T3Stack(100, 20);
      expect(stack.getDepth(), equals(0));

      stack.push(T3Value()..setInt(1));
      expect(stack.getDepth(), equals(1));

      stack.pushMultiple(5);
      expect(stack.getDepth(), equals(6));

      stack.discard(2);
      expect(stack.getDepth(), equals(4));
    });

    test('getDepthRel returns depth relative to frame pointer', () {
      final stack = T3Stack(100, 20);
      stack.push(T3Value()..setInt(1));
      stack.push(T3Value()..setInt(2));

      final fp = stack.getSp();

      stack.push(T3Value()..setInt(3));
      stack.push(T3Value()..setInt(4));

      expect(stack.getDepthRel(fp), equals(2));

      stack.discard(3);
      expect(stack.getDepthRel(fp), equals(-1)); // Popped past frame
    });
  });

  group('Frame Pointer Operations', () {
    test('getFromFrame accesses elements relative to frame', () {
      final stack = T3Stack(100, 20);
      stack.push(T3Value()..setInt(10));
      stack.push(T3Value()..setInt(20));

      final fp = stack.getSp();

      stack.push(T3Value()..setInt(30));
      stack.push(T3Value()..setInt(40));

      // Access relative to frame pointer
      expect(stack.getFromFrame(fp, 0).getAsInt(), equals(20)); // At frame
      expect(stack.getFromFrame(fp, -1).getAsInt(), equals(10)); // Before frame
      expect(stack.getFromFrame(fp, 1).getAsInt(), equals(30)); // After frame
      expect(stack.getFromFrame(fp, 2).getAsInt(), equals(40)); // After frame
    });
  });

  group('Pointer/Index Conversion', () {
    test('ptrToIndex converts null to 0', () {
      final stack = T3Stack(100, 20);
      expect(stack.ptrToIndex(null), equals(0));
    });

    test('ptrToIndex converts pointer to non-zero index', () {
      final stack = T3Stack(100, 20);
      expect(stack.ptrToIndex(0), equals(1));
      expect(stack.ptrToIndex(5), equals(6));
      expect(stack.ptrToIndex(99), equals(100));
    });

    test('indexToPtr converts 0 to null', () {
      final stack = T3Stack(100, 20);
      expect(stack.indexToPtr(0), isNull);
    });

    test('indexToPtr converts index to pointer', () {
      final stack = T3Stack(100, 20);
      expect(stack.indexToPtr(1), equals(0));
      expect(stack.indexToPtr(6), equals(5));
      expect(stack.indexToPtr(100), equals(99));
    });

    test('round-trip conversion preserves values', () {
      final stack = T3Stack(100, 20);

      final ptr = 42;
      final idx = stack.ptrToIndex(ptr);
      final backToPtr = stack.indexToPtr(idx);

      expect(backToPtr, equals(ptr));
    });

    test('round-trip conversion preserves null', () {
      final stack = T3Stack(100, 20);

      final idx = stack.ptrToIndex(null);
      final ptr = stack.indexToPtr(idx);

      expect(ptr, isNull);
    });
  });

  group('Space Management', () {
    test('checkSpace returns true when space available', () {
      final stack = T3Stack(10, 5);
      expect(stack.checkSpace(5), isTrue);
      expect(stack.checkSpace(10), isTrue);
    });

    test('checkSpace returns false when space unavailable', () {
      final stack = T3Stack(10, 5);
      expect(stack.checkSpace(11), isFalse);
      expect(stack.checkSpace(100), isFalse);
    });

    test('checkSpace accounts for current depth', () {
      final stack = T3Stack(10, 5);
      stack.pushMultiple(5);

      expect(stack.checkSpace(5), isTrue);
      expect(stack.checkSpace(6), isFalse);
    });

    test('checkThrow does not throw when space available', () {
      final stack = T3Stack(10, 5);
      expect(() => stack.checkThrow(5), returnsNormally);
    });

    test('checkThrow throws when space unavailable', () {
      final stack = T3Stack(10, 5);
      expect(
        () => stack.checkThrow(11),
        throwsA(
          isA<T3VmException>().having(
            (e) => e.errorCode,
            'errorCode',
            vmErrStackOverflow,
          ),
        ),
      );
    });

    test('handles negative slot requests gracefully', () {
      final stack = T3Stack(10, 5);
      // Negative requests should always succeed (compatibility with buggy .t3 files)
      expect(stack.checkSpace(-5), isTrue);
    });
  });

  group('Reserve Management', () {
    test('releaseReserve increases available space', () {
      final stack = T3Stack(10, 5);

      // Initially can't use reserve
      expect(stack.checkSpace(11), isFalse);

      // Release reserve
      expect(stack.releaseReserve(), isTrue);

      // Now can use reserve space
      expect(stack.checkSpace(11), isTrue);
      expect(stack.checkSpace(15), isTrue);
    });

    test('releaseReserve returns false if already released', () {
      final stack = T3Stack(10, 5);

      expect(stack.releaseReserve(), isTrue);
      expect(stack.releaseReserve(), isFalse); // Already released
    });

    test('recoverReserve restores original limit', () {
      final stack = T3Stack(10, 5);

      stack.releaseReserve();
      expect(stack.checkSpace(15), isTrue);

      stack.recoverReserve();
      expect(stack.checkSpace(11), isFalse);
      expect(stack.checkSpace(10), isTrue);
    });

    test('recoverReserve is safe to call when not released', () {
      final stack = T3Stack(10, 5);

      // Should not throw
      expect(() => stack.recoverReserve(), returnsNormally);
      expect(stack.checkSpace(10), isTrue);
    });

    test('reserve can be released and recovered multiple times', () {
      final stack = T3Stack(10, 5);

      for (int i = 0; i < 3; i++) {
        expect(stack.releaseReserve(), isTrue);
        expect(stack.checkSpace(15), isTrue);

        stack.recoverReserve();
        expect(stack.checkSpace(11), isFalse);
      }
    });
  });

  group('Insert Operation', () {
    test('insert at index 0 is same as push', () {
      final stack = T3Stack(100, 20);
      stack.push(T3Value()..setInt(1));
      stack.push(T3Value()..setInt(2));

      final idx = stack.insert(0, 3);

      expect(stack.getDepth(), equals(5));
      expect(idx, equals(2)); // Start of inserted block
    });

    test('insert moves existing elements', () {
      final stack = T3Stack(100, 20);
      stack.push(T3Value()..setInt(1));
      stack.push(T3Value()..setInt(2));
      stack.push(T3Value()..setInt(3));

      // Insert 2 slots before the top element
      final idx = stack.insert(1, 2);

      expect(stack.getDepth(), equals(5));

      // Fill inserted slots
      stack.setAt(idx, T3Value()..setInt(99));
      stack.setAt(idx + 1, T3Value()..setInt(98));

      // Check order: bottom to top should be 1, 2, 99, 98, 3
      expect(stack.get(4).getAsInt(), equals(1));
      expect(stack.get(3).getAsInt(), equals(2));
      expect(stack.get(2).getAsInt(), equals(99));
      expect(stack.get(1).getAsInt(), equals(98));
      expect(stack.get(0).getAsInt(), equals(3));
    });

    test('insert throws on overflow', () {
      final stack = T3Stack(5, 0);
      stack.pushMultiple(3);

      expect(
        () => stack.insert(1, 3), // Would need 6 total slots
        throwsA(
          isA<T3VmException>().having(
            (e) => e.errorCode,
            'errorCode',
            vmErrStackOverflow,
          ),
        ),
      );
    });
  });

  group('Edge Cases', () {
    test('empty stack operations', () {
      final stack = T3Stack(100, 20);

      expect(stack.getDepth(), equals(0));
      expect(stack.getSp(), equals(0));
      expect(stack.checkSpace(100), isTrue);
    });

    test('full stack without reserve', () {
      final stack = T3Stack(3, 0);

      stack.push(T3Value()..setInt(1));
      stack.push(T3Value()..setInt(2));
      stack.push(T3Value()..setInt(3));

      expect(stack.checkSpace(0), isTrue);
      expect(stack.checkSpace(1), isFalse);
    });

    test('stack with different value types', () {
      final stack = T3Stack(100, 20);

      stack.push(T3Value()..setInt(42));
      stack.push(T3Value()..setObj(100));
      stack.push(T3Value()..setNil());
      stack.push(T3Value()..setTrue());

      expect(stack.get(3).type, equals(T3DataType.int32));
      expect(stack.get(2).type, equals(T3DataType.obj));
      expect(stack.get(1).type, equals(T3DataType.nil));
      expect(stack.get(0).type, equals(T3DataType.trueValue));
    });

    test('large stack allocation', () {
      final stack = T3Stack(10000, 1000);
      expect(stack.getDepth(), equals(0));
      expect(stack.checkSpace(10000), isTrue);
    });

    test('zero reserve depth', () {
      final stack = T3Stack(10, 0);

      expect(stack.checkSpace(10), isTrue);
      expect(stack.checkSpace(11), isFalse);

      // Release should still work but add nothing
      expect(stack.releaseReserve(), isTrue);
      expect(stack.checkSpace(11), isFalse); // Still can't use more
    });
  });

  group('Real-World Scenarios', () {
    test('function call frame simulation', () {
      final stack = T3Stack(100, 20);

      // Push some arguments
      stack.push(T3Value()..setInt(10));
      stack.push(T3Value()..setInt(20));

      // Save frame pointer
      final fp = stack.getSp();

      // Allocate locals
      stack.pushMultiple(3);
      stack.setAt(fp, T3Value()..setInt(100));
      stack.setAt(fp + 1, T3Value()..setInt(200));
      stack.setAt(fp + 2, T3Value()..setInt(300));

      // Access arguments relative to frame
      // fp points to next free slot after arguments
      // offset 0 gets the last argument (at fp-1)
      // offset -1 gets the second-to-last argument (at fp-2)
      expect(stack.getFromFrame(fp, 0).getAsInt(), equals(20));
      expect(stack.getFromFrame(fp, -1).getAsInt(), equals(10));

      // Access locals
      // Locals are at fp, fp+1, fp+2, so we use offsets 1, 2, 3
      expect(stack.getFromFrame(fp, 1).getAsInt(), equals(100));
      expect(stack.getFromFrame(fp, 2).getAsInt(), equals(200));
      expect(stack.getFromFrame(fp, 3).getAsInt(), equals(300));

      // Clean up frame
      stack.setSp(fp);
      expect(stack.getDepth(), equals(2));
    });

    test('nested function calls', () {
      final stack = T3Stack(100, 20);

      // First function
      stack.push(T3Value()..setInt(1));
      final fp1 = stack.getSp();
      stack.pushMultiple(2);

      // Second function (nested)
      stack.push(T3Value()..setInt(2));
      final fp2 = stack.getSp();
      stack.pushMultiple(2);

      // Third function (nested)
      stack.push(T3Value()..setInt(3));
      final fp3 = stack.getSp();
      stack.pushMultiple(2);

      expect(stack.getDepth(), equals(9));

      // Unwind
      stack.setSp(fp3);
      stack.setSp(fp2);
      stack.setSp(fp1);

      expect(stack.getDepth(), equals(1));
    });

    test('stack overflow with reserve recovery', () {
      final stack = T3Stack(5, 3);

      // Fill to capacity
      for (int i = 0; i < 5; i++) {
        stack.push(T3Value()..setInt(i));
      }

      // Can't push more
      expect(stack.checkSpace(1), isFalse);

      // Release reserve for error handling
      expect(stack.releaseReserve(), isTrue);
      expect(stack.checkSpace(3), isTrue);

      // Use some reserve
      stack.push(T3Value()..setInt(99));

      // Clean up and recover
      stack.discard(6); // Remove everything
      stack.recoverReserve();

      expect(stack.checkSpace(5), isTrue);
      expect(stack.checkSpace(6), isFalse);
    });
  });
}
