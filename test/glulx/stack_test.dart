import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/glulx/glulx_exception.dart';
import 'package:zart/src/glulx/glulx_locals_descriptor.dart';
import 'package:zart/src/glulx/glulx_stack.dart';

void main() {
  group('GlulxStack', () {
    late GlulxStack stack;

    setUp(() {
      stack = GlulxStack(1024);
    });

    /// Sets up a minimal frame with proper valstackbase caching.
    void setupMinimalFrame() {
      // Push a minimal frame with format [0, 0] (no locals)
      stack.pushFrame(Uint8List.fromList([0, 0]));
    }

    group('Stack Size and Alignment', () {
      // Spec: "For convenience, this [stack size] must be a multiple of 256."
      test('size must be multiple of 256', () {
        expect(() => GlulxStack(255), throwsA(isA<GlulxException>()));
        expect(() => GlulxStack(257), throwsA(isA<GlulxException>()));
        expect(() => GlulxStack(256), returnsNormally);
        expect(() => GlulxStack(512), returnsNormally);
      });

      // Spec: "The stack pointer starts at zero, and the stack grows upward."
      test('stack pointer starts at zero', () {
        expect(stack.sp, 0);
        expect(stack.fp, 0);
      });

      test('maximum size and overflow', () {
        // Spec: "If a push operation would cause the stack pointer to exceed
        // this value, the terp must signal a fatal error."
        final smallStack = GlulxStack(256);
        for (var i = 0; i < 256; i += 4) {
          smallStack.push32(i);
        }
        expect(smallStack.sp, 256);
        expect(() => smallStack.push32(1), throwsA(isA<GlulxException>()));
      });
    });

    group('Push and Pop Operations', () {
      test('basic push and pop', () {
        setupMinimalFrame();
        // Spec: "If you push a 32-bit value on the stack, the pointer increases by four."
        final spBefore = stack.sp;
        stack.push32(0x12345678);
        expect(stack.sp, spBefore + 4);
        stack.push32(0xABCDEF01);
        expect(stack.sp, spBefore + 8);
        expect(stack.pop32(), 0xABCDEF01);
        expect(stack.sp, spBefore + 4);
        expect(stack.pop32(), 0x12345678);
        expect(stack.sp, spBefore);
      });

      test('32-bit truncation', () {
        setupMinimalFrame();
        // Spec: "Arithmetic overflows and underflows are truncated."
        stack.push32(0x123456789ABCDEF0);
        expect(stack.pop32(), 0x9ABCDEF0);
      });

      test('two\'s complement signed integers', () {
        setupMinimalFrame();
        // Spec: "Signed integers are handled with the usual two's-complement notation."
        stack.push32(-1);
        expect(stack.pop32(), 0xFFFFFFFF);

        stack.push32(0xFFFFFFFF);
        final val = stack.pop32();
        expect(val.toSigned(32), -1);
      });
    });

    group('Frame Boundary Protection', () {
      // Spec: "It is illegal to pop back beyond the original FramePtr+FrameLen boundary."
      test('popping beyond frame boundary throws', () {
        setupMinimalFrame();
        // Push and pop one value - should work
        stack.push32(42);
        expect(stack.pop32(), 42);

        // Popping again should fail - we're at valstackbase
        expect(() => stack.pop32(), throwsA(isA<GlulxException>()));
      });

      test('valstackbase is properly cached after pushFrame', () {
        stack.pushFrame(Uint8List.fromList([4, 1, 0, 0])); // one 32-bit local
        final expectedValstackbase = stack.fp + stack.frameLen;
        expect(stack.valstackbase, expectedValstackbase);
        expect(stack.sp, expectedValstackbase);
      });

      test('valstackbase is updated after popFrame', () {
        // Setup caller frame
        stack.pushFrame(Uint8List.fromList([4, 1, 0, 0]));
        final callerValstackbase = stack.valstackbase;

        // Push call stub and callee frame
        stack.pushCallStub(0, 0, 0x1000, stack.fp);
        stack.pushFrame(Uint8List.fromList([4, 2, 0, 0]));

        // Pop callee frame
        stack.popFrame();

        // Reference: funcs.c lines 240-241 - recompute bases
        expect(stack.valstackbase, callerValstackbase);
      });
    });

    group('stkpeek Operation', () {
      // Spec: "Peek at the L1'th value on the stack, without actually popping anything.
      // If L1 is zero, this is the top value; if one, it's the value below that; etc."
      test('peek returns correct values', () {
        setupMinimalFrame();
        stack.push32(0x11111111);
        stack.push32(0x22222222);
        stack.push32(0x33333333);

        expect(stack.peek32(0), 0x33333333); // top
        expect(stack.peek32(1), 0x22222222); // next
        expect(stack.peek32(2), 0x11111111); // bottom
      });

      // Reference: exec.c lines 479-481 - validates against valstackbase
      test('peek beyond frame boundary throws', () {
        setupMinimalFrame();
        stack.push32(0x11111111);

        expect(stack.peek32(0), 0x11111111);
        // Index 1 would be below valstackbase
        expect(() => stack.peek32(1), throwsA(isA<GlulxException>()));
      });

      test('peek with negative index throws', () {
        setupMinimalFrame();
        stack.push32(0x11111111);

        expect(() => stack.peek32(-1), throwsA(isA<GlulxException>()));
      });
    });

    group('stkcount Operation', () {
      // Spec: "Store a count of the number of values on the stack.
      // This counts only values above the current call-frame."
      test('count returns correct value', () {
        setupMinimalFrame();
        expect(stack.stkCount, 0);

        stack.push32(1);
        expect(stack.stkCount, 1);

        stack.push32(2);
        expect(stack.stkCount, 2);

        stack.pop32();
        expect(stack.stkCount, 1);
      });
    });

    group('stkswap Operation', () {
      // Spec: "Swap the top two values on the stack.
      // The current stack-count must be at least two."
      test('swap exchanges top two values', () {
        setupMinimalFrame();
        stack.push32(10);
        stack.push32(20);
        stack.stkSwap();
        expect(stack.pop32(), 10);
        expect(stack.pop32(), 20);
      });

      // Reference: exec.c lines 486-487
      test('swap with insufficient values throws', () {
        setupMinimalFrame();
        stack.push32(1);
        expect(() => stack.stkSwap(), throwsA(isA<GlulxException>()));
      });
    });

    group('stkroll Operation', () {
      // Spec: "Rotate the top L1 values on the stack. They are rotated up or down
      // L2 places, with positive values meaning up and negative meaning down."
      test('roll with positive shift', () {
        setupMinimalFrame();
        // Spec example: "8 7 6 5 4 3 2 1 0 <top> stkroll 5 1 -> 8 7 6 5 0 4 3 2 1 <top>"
        // Push: 4 3 2 1 0 (so 0 is on top)
        for (var i = 4; i >= 0; i--) {
          stack.push32(i);
        }

        stack.stkRoll(5, 1);

        expect(stack.pop32(), 1); // new top
        expect(stack.pop32(), 2);
        expect(stack.pop32(), 3);
        expect(stack.pop32(), 4);
        expect(stack.pop32(), 0); // rotated down
      });

      test('roll with negative shift', () {
        setupMinimalFrame();
        // Roll 3 by -1: [a, b, c] -> [b, c, a]
        stack.push32(0xAAAA);
        stack.push32(0xBBBB);
        stack.push32(0xCCCC);

        stack.stkRoll(3, -1);

        expect(stack.pop32(), 0xAAAA);
        expect(stack.pop32(), 0xCCCC);
        expect(stack.pop32(), 0xBBBB);
      });

      // Reference: exec.c lines 514-515 - negative count is error, not no-op
      test('negative count throws', () {
        setupMinimalFrame();
        stack.push32(1);
        stack.push32(2);
        expect(() => stack.stkRoll(-1, 1), throwsA(isA<GlulxException>()));
      });

      test('zero count is no-op', () {
        setupMinimalFrame();
        stack.push32(1);
        stack.push32(2);
        stack.stkRoll(0, 5); // Should do nothing
        expect(stack.pop32(), 2);
        expect(stack.pop32(), 1);
      });

      test('underflow throws', () {
        setupMinimalFrame();
        stack.push32(1);
        expect(() => stack.stkRoll(5, 1), throwsA(isA<GlulxException>()));
      });
    });

    group('stkcopy Operation', () {
      // Spec: "Peek at the top L1 values in the stack, and push duplicates onto
      // the stack in the same order."
      test('copy duplicates values', () {
        setupMinimalFrame();
        // Spec example: "5 4 3 2 1 0 <top> stkcopy 3 -> 5 4 3 2 1 0 2 1 0 <top>"
        stack.push32(100);
        stack.push32(200);
        stack.push32(300);

        stack.stkCopy(2);

        expect(stack.pop32(), 300); // copy of top
        expect(stack.pop32(), 200); // copy of second
        expect(stack.pop32(), 300); // original top
        expect(stack.pop32(), 200); // original second
        expect(stack.pop32(), 100); // untouched
      });

      // Reference: exec.c lines 496-497 - negative count is error
      test('negative count throws', () {
        setupMinimalFrame();
        stack.push32(1);
        expect(() => stack.stkCopy(-1), throwsA(isA<GlulxException>()));
      });

      test('zero count is no-op', () {
        setupMinimalFrame();
        stack.push32(1);
        final spBefore = stack.sp;
        stack.stkCopy(0);
        expect(stack.sp, spBefore);
      });

      test('underflow throws', () {
        setupMinimalFrame();
        stack.push32(1);
        expect(() => stack.stkCopy(5), throwsA(isA<GlulxException>()));
      });

      test('overflow throws', () {
        final smallStack = GlulxStack(256);
        smallStack.pushFrame(Uint8List.fromList([0, 0]));
        // Fill most of the stack
        while (smallStack.sp + 8 < smallStack.maxSize) {
          smallStack.push32(42);
        }
        // Try to copy more than space available
        expect(() => smallStack.stkCopy(50), throwsA(isA<GlulxException>()));
      });
    });

    group('Call Stubs', () {
      // Spec: "The values are pushed on the stack in the following order
      // (FramePtr pushed last): DestType, DestAddr, PC, FramePtr"
      test('push and pop call stub', () {
        stack.pushCallStub(1, 0x1000, 0x2000, 0x3000);
        final stub = stack.popCallStub();
        expect(stub[0], 1); // destType
        expect(stub[1], 0x1000); // destAddr
        expect(stub[2], 0x2000); // pc
        expect(stub[3], 0x3000); // fp
      });
    });

    group('storeResult Operation', () {
      test('type 0: discard result', () {
        // Spec: "Do not store. The result value is discarded."
        setupMinimalFrame();
        final spBefore = stack.sp;
        stack.storeResult(0x1234, 0, 0);
        expect(stack.sp, spBefore); // No change
      });

      test('type 1: store in memory', () {
        // Spec: "Store in main memory."
        setupMinimalFrame();
        int? capturedAddr, capturedVal;
        stack.storeResult(
          0x12345678,
          1,
          0x5000,
          onMemoryWrite: (a, v) {
            capturedAddr = a;
            capturedVal = v;
          },
        );
        expect(capturedAddr, 0x5000);
        expect(capturedVal, 0x12345678);
      });

      test('type 2: store in local variable', () {
        // Spec: "Store in local variable."
        stack.pushFrame(Uint8List.fromList([4, 2, 0, 0])); // 2 32-bit locals
        stack.storeResult(0xDEADBEEF, 2, 4);
        expect(stack.readLocal32(4), 0xDEADBEEF);
      });

      test('type 3: push on stack', () {
        // Spec: "Push on stack."
        setupMinimalFrame();
        final spBefore = stack.sp;
        stack.storeResult(0xCAFEBABE, 3, 0);
        expect(stack.sp, spBefore + 4);
        expect(stack.pop32(), 0xCAFEBABE);
      });

      test('types 0x10, 0x12-0x14: string resume (discard)', () {
        // Spec: "The function's return value is discarded." (for string types)
        setupMinimalFrame();
        final spBefore = stack.sp;

        stack.storeResult(0x1234, 0x10, 0); // Compressed string
        stack.storeResult(0x1234, 0x12, 0); // Decimal integer
        stack.storeResult(0x1234, 0x13, 0); // C-style string
        stack.storeResult(0x1234, 0x14, 0); // Unicode string

        expect(stack.sp, spBefore); // No stack changes
      });

      // Reference: funcs.c lines 245-247 - type 0x11 in function return is fatal
      test('type 0x11: string terminator throws in function context', () {
        setupMinimalFrame();
        expect(
          () => stack.storeResult(0, 0x11, 0),
          throwsA(isA<GlulxException>().having((e) => e.message, 'message', contains('String-terminator'))),
        );
      });

      test('unknown type throws', () {
        setupMinimalFrame();
        expect(
          () => stack.storeResult(0, 4, 0),
          throwsA(isA<GlulxException>().having((e) => e.message, 'message', contains('Unknown or reserved DestType'))),
        );
      });
    });

    group('Local Variable Access', () {
      // Spec: "Locals can be 8, 16, or 32-bit values."
      test('read and write locals', () {
        // Setup frame with locals: LocalsPos=16 gives us space
        stack.pushFrame(Uint8List.fromList([4, 4, 0, 0])); // 4 32-bit locals

        stack.writeLocal8(0, 0x42);
        stack.writeLocal16(2, 0x1234);
        stack.writeLocal32(4, 0xDEADBEEF);

        expect(stack.readLocal8(0), 0x42);
        expect(stack.readLocal16(2), 0x1234);
        expect(stack.readLocal32(4), 0xDEADBEEF);
      });

      test('local variable truncation', () {
        stack.pushFrame(Uint8List.fromList([4, 4, 0, 0]));

        // 8-bit truncation
        stack.writeLocal8(0, 0x1234);
        expect(stack.readLocal8(0), 0x34);

        // 16-bit truncation
        stack.writeLocal16(2, 0x12345678);
        expect(stack.readLocal16(2), 0x5678);
      });

      test('localsbase is cached', () {
        stack.pushFrame(Uint8List.fromList([4, 2, 0, 0]));
        expect(stack.localsbase, stack.fp + stack.localsPos);
      });
    });

    group('Frame Lifecycle', () {
      test('pushFrame creates correct structure', () {
        // Spec: frame = [FrameLen, LocalsPos, Format, Padding, Locals, Padding, Values]
        final format = Uint8List.fromList([1, 3, 2, 6, 0, 0]); // 3 bytes + 6 shorts

        stack.pushCallStub(1, 0x1000, 0x2000, 0);
        final stubSp = stack.sp;

        stack.pushFrame(format);

        // Expected layout per spec example:
        // header (8) + format (6) + padding (2) = LocalsPos (16)
        // 3 bytes + 1 padding + 6*2 bytes = 16 bytes of locals
        // LocalsPos (16) + locals (16) = FrameLen (32)
        expect(stack.frameLen, 32);
        expect(stack.localsPos, 16);
        expect(stack.fp, stubSp);
        expect(stack.sp, stubSp + 32);
      });

      test('popFrame restores previous state', () {
        stack.pushFrame(Uint8List.fromList([4, 1, 0, 0])); // caller frame
        final callerFp = stack.fp;

        stack.pushCallStub(0, 0, 0x1000, callerFp);
        stack.pushFrame(Uint8List.fromList([4, 2, 0, 0])); // callee frame

        final stub = stack.popFrame();
        expect(stub[2], 0x1000); // PC
        expect(stub[3], callerFp); // restored FP
        expect(stack.fp, callerFp);
      });
    });

    group('setArguments Operation', () {
      test('sets arguments in locals', () {
        // Spec: "Function arguments can be stored in the locals of the new call frame."
        final format = Uint8List.fromList([4, 3, 0, 0]); // 3 32-bit locals
        final descriptor = GlulxLocalsDescriptor.parse(format);
        stack.pushFrame(format);

        stack.setArguments([0x11111111, 0x22222222, 0x33333333], descriptor.locals);

        expect(stack.readLocal32(0), 0x11111111);
        expect(stack.readLocal32(4), 0x22222222);
        expect(stack.readLocal32(8), 0x33333333);
      });

      test('extra arguments are silently dropped', () {
        // Spec Section 1.4.2: "If there are more arguments than locals, the extras are silently dropped."
        final format = Uint8List.fromList([4, 1, 0, 0]); // 1 32-bit local
        final descriptor = GlulxLocalsDescriptor.parse(format);
        stack.pushFrame(format);

        stack.setArguments([0x11, 0x22, 0x33], descriptor.locals);
        expect(stack.readLocal32(0), 0x11);
      });

      test('fewer arguments leave locals at zero', () {
        // Spec Section 1.4.2: "any locals left unfilled are initialized to zero."
        // pushFrame already zeroes locals, but setArguments should not disturb them if not provided.
        final format = Uint8List.fromList([4, 3, 0, 0]); // 3 32-bit locals
        final descriptor = GlulxLocalsDescriptor.parse(format);
        stack.pushFrame(format);

        stack.setArguments([0x11111111], descriptor.locals);
        expect(stack.readLocal32(0), 0x11111111);
        expect(stack.readLocal32(4), 0);
        expect(stack.readLocal32(8), 0);
      });

      test('arguments are truncated for 8-bit and 16-bit locals', () {
        // Spec Section 1.4.2: "Arguments passed into 8-bit or 16-bit locals are truncated."
        final format = Uint8List.fromList([1, 1, 2, 1, 4, 1, 0, 0]); // 8-bit, 16-bit, 32-bit
        final descriptor = GlulxLocalsDescriptor.parse(format);
        stack.pushFrame(format);

        stack.setArguments([0x112233AA, 0x1122BBCC, 0xDDDDDDDD], descriptor.locals);

        expect(stack.readLocal8(0), 0xAA);
        expect(stack.readLocal16(2), 0xBBCC);
        expect(stack.readLocal32(4), 0xDDDDDDDD);
      });
    });

    group('Utility Methods', () {
      test('reset clears stack state', () {
        stack.pushFrame(Uint8List.fromList([4, 2, 0, 0]));
        stack.push32(1);
        stack.push32(2);

        stack.reset();

        expect(stack.sp, 0);
        expect(stack.fp, 0);
        expect(stack.valstackbase, 0);
        expect(stack.localsbase, 0);
      });

      test('rawData provides access for serialization', () {
        stack.push32(0x12345678);
        expect(stack.rawData.length, 1024);
        // Big-endian: 0x12345678 stored as [12, 34, 56, 78]
        expect(stack.rawData[0], 0x12);
        expect(stack.rawData[1], 0x34);
        expect(stack.rawData[2], 0x56);
        expect(stack.rawData[3], 0x78);
      });
    });
  });
}
