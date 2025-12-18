import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/glulx/glulx_exception.dart';
import 'package:zart/src/glulx/glulx_stack.dart';

void main() {
  group('GlulxStack', () {
    late GlulxStack stack;

    setUp(() {
      stack = GlulxStack(1024);
    });

    void setupDummyFrame({int len = 8, int locals = 8}) {
      // Pushes a dummy frame: [len, locals]
      // sp should be at least fp + len
      stack.push32(len);
      stack.push32(locals);
      stack.fp = stack.sp - 8;
      stack.sp = stack.fp + len;
    }

    test('basic push and pop', () {
      setupDummyFrame();
      // Spec: "The stack pointer counts in bytes. If you push a 32-bit value on the stack, the pointer increases by four." (L66)
      stack.push32(0x12345678);
      expect(stack.sp, 12);
      stack.push32(0xABCDEF01);
      expect(stack.sp, 16);
      expect(stack.pop32(), 0xABCDEF01);
      expect(stack.sp, 12);
      expect(stack.pop32(), 0x12345678);
      expect(stack.sp, 8);
    });

    test('peek', () {
      // Spec: "stkpeek L1 S1: Peek at the L1'th value on the stack, without actually popping anything. If L1 is zero, this is the top value; if one, it's the value below that; etc." (L1063-1066)
      setupDummyFrame();
      stack.push32(0x11111111);
      stack.push32(0x22222222);
      expect(stack.peek32(0), 0x22222222);
      expect(stack.peek32(4), 0x11111111);
    });

    test('call stubs', () {
      // Spec: "The values are pushed on the stack in the following order (FramePtr pushed last): DestType (4 bytes), DestAddr (4 bytes), PC (4 bytes), FramePtr (4 bytes)" (L116-123)
      stack.pushCallStub(1, 0x1000, 0x2000, 0x3000);
      final stub = stack.popCallStub();
      expect(stub[0], 1); // destType
      expect(stub[1], 0x1000); // destAddr
      expect(stub[2], 0x2000); // pc
      expect(stub[3], 0x3000); // fp
    });

    test('locals access', () {
      // Spec: "Locals can be 8, 16, or 32-bit values. They are not necessarily contiguous; padding is inserted wherever necessary to bring a value to its natural alignment (16-bit values at even addresses, 32-bit values at multiples of four)." (L91)
      // Mock a frame header: [Length=64, LocalsPos=16]
      stack.push32(64);
      stack.push32(16);
      stack.fp = stack.sp - 8;
      stack.sp = stack.fp + 64;

      stack.writeLocal8(0, 0x42);
      stack.writeLocal16(2, 0x1234);
      stack.writeLocal32(4, 0xDEADBEEF);

      expect(stack.readLocal8(0), 0x42);
      expect(stack.readLocal16(2), 0x1234);
      expect(stack.readLocal32(4), 0xDEADBEEF);
    });

    test('stack manipulation - count', () {
      // Spec: "stkcount S1: Store a count of the number of values on the stack. This counts only values above the current call-frame... it is always the number of values that can be popped legally." (L1057-1060)
      // Mock a frame [Length=8, LocalsPos=8]
      stack.push32(8);
      stack.push32(8);
      stack.fp = 0;
      stack.sp = 8;

      stack.push32(1);
      stack.push32(2);
      expect(stack.stkCount, 2);
    });

    test('stack manipulation - swap', () {
      // Spec: "stkswap: Swap the top two values on the stack. The current stack-count must be at least two." (L1069-1072)
      // Mock frame
      stack.push32(8);
      stack.push32(8);
      stack.fp = 0;
      stack.sp = 8;

      stack.push32(10);
      stack.push32(20);
      stack.stkSwap();
      expect(stack.pop32(), 10);
      expect(stack.pop32(), 20);
    });

    test('stack manipulation - roll', () {
      // Spec: "stkroll L1 L2: Rotate the top L1 values on the stack. They are rotated up or down L2 places, with positive values meaning up and negative meaning down." (L1087-1090)
      // Mock frame
      stack.push32(8);
      stack.push32(8);
      stack.fp = 0;
      stack.sp = 8;

      stack.push32(1);
      stack.push32(2);
      stack.push32(3);
      stack.push32(4);

      // Roll top 3 by 1: [1, 2, 3, 4] -> [1, 4, 2, 3]
      stack.stkRoll(3, 1);
      expect(stack.pop32(), 3);
      expect(stack.pop32(), 2);
      expect(stack.pop32(), 4);
      expect(stack.pop32(), 1);

      stack.push32(1);
      stack.push32(2);
      stack.push32(3);
      stack.push32(4);
      // Roll top 3 by -1: [1, 2, 3, 4] -> [1, 3, 4, 2]
      stack.stkRoll(3, -1);
      expect(stack.pop32(), 2);
      expect(stack.pop32(), 4);
      expect(stack.pop32(), 3);
      expect(stack.pop32(), 1);
    });

    test('stack manipulation - copy', () {
      // Spec: "stkcopy L1: Peek at the top L1 values in the stack, and push duplicates onto the stack in the same order." (L1075-1078)
      // Mock frame
      stack.push32(8);
      stack.push32(8);
      stack.fp = 0;
      stack.sp = 8;

      stack.push32(100);
      stack.push32(200);
      stack.stkCopy(2);
      expect(stack.pop32(), 200);
      expect(stack.pop32(), 100);
      expect(stack.pop32(), 200);
      expect(stack.pop32(), 100);
    });

    group('integer behavior (Spec Line 15)', () {
      test('32-bit truncation', () {
        setupDummyFrame();
        // Spec: "All values are treated as unsigned integers, unless otherwise noted... Arithmetic overflows and underflows are truncated, also as usual." (L15)
        // Pushing a 64-bit value should result in 32-bit truncation.
        stack.push32(0x123456789ABCDEF0);
        expect(stack.pop32(), 0x9ABCDEF0);
      });

      test('two\'s complement signed integers', () {
        setupDummyFrame();
        // Spec: "Signed integers are handled with the usual two's-complement notation." (L15)
        stack.push32(-1);
        expect(stack.pop32(), 0xFFFFFFFF);

        // 0xFFFFFFFF interpreted as signed should be -1
        stack.push32(0xFFFFFFFF);
        final val = stack.pop32();
        expect(val.toSigned(32), -1);
      });

      test('local variable truncation', () {
        // Mock a frame
        stack.push32(64);
        stack.push32(16);
        stack.fp = 0;
        stack.sp = 64;

        // 8-bit truncation
        stack.writeLocal8(0, 0x1234);
        expect(stack.readLocal8(0), 0x34);

        // 16-bit truncation
        stack.writeLocal16(2, 0x12345678);
        expect(stack.readLocal16(2), 0x5678);
      });
    });

    group('stack size and alignment (Spec Line 64)', () {
      test('stack pointer starts at zero', () {
        // Spec: "The stack pointer starts at zero, and the stack grows upward." (L64)
        expect(stack.sp, 0);
      });

      test('maximum size and overflow', () {
        // Spec: "The maximum size of the stack is determined by a constant value in the game-file header... If a push operation would cause the stack pointer to exceed this value, the terp must signal a fatal error." (L64)
        final smallStack = GlulxStack(256);
        // Fill the stack
        for (var i = 0; i < 256; i += 4) {
          smallStack.push32(i);
        }
        expect(smallStack.sp, 256);
        expect(() => smallStack.push32(1), throwsA(isA<GlulxException>()));
      });

      test('size must be multiple of 256', () {
        // Spec: "For convenience, this [stack size] must be a multiple of 256." (L64)
        expect(() => GlulxStack(255), throwsA(isA<GlulxException>()));
        expect(() => GlulxStack(512), returnsNormally);
      });
    });

    group('frame boundary protection (Spec Line 89)', () {
      test('popping beyond frame boundary is illegal', () {
        // Spec: "Computation can push and pull 32-bit values on the stack. It is illegal to pop back beyond the original FramePtr+FrameLen boundary." (L89)

        // Mock a frame: Len=8, LocalsPos=8
        stack.push32(8);
        stack.push32(8);
        stack.fp = 0;
        stack.sp = 8; // sp == fp + frameLen

        // Pushing values is fine
        stack.push32(42);
        expect(stack.pop32(), 42);

        // Popping at the boundary should throw
        expect(stack.sp, 8);
        expect(() => stack.pop32(), throwsA(isA<GlulxException>()));
      });
    });

    group('full frame lifecycle (Spec Lines 93-108)', () {
      test('pushFrame and popFrame with complex locals', () {
        // Spec Example: "if a function has three 8-bit locals followed by six 16-bit locals, the format segment would contain eight bytes: (1, 3, 2, 6, 0, 0, 0, 0). The locals segment would then be 16 bytes long, with a padding byte after the third local." (L102)
        final format = Uint8List.fromList([1, 3, 2, 6, 0, 0]);

        // Push call stub first
        stack.pushCallStub(1, 0x1000, 0x2000, 0);
        final stubSp = stack.sp;

        stack.pushFrame(format);

        // Expected layout:
        // header (8) + format (6) + padding (2) = LocalsPos (16)
        // LocalsPos (16) + locals segment (16) = FrameLen (32)
        expect(stack.frameLen, 32);
        expect(stack.localsPos, 16);
        expect(stack.fp, stubSp);
        expect(stack.sp, stubSp + 32);

        // Verify write/read in the new frame
        stack.writeLocal8(0, 0xAA);
        stack.writeLocal16(4, 0xBBBB); // 16-bit local at offset 4 relative to LocalsPos

        expect(stack.readLocal8(0), 0xAA);
        expect(stack.readLocal16(4), 0xBBBB);

        // Pop frame
        final stub = stack.popFrame();
        expect(stub[0], 1);
        expect(stub[1], 0x1000);
        expect(stub[2], 0x2000);
        expect(stub[3], 0);

        expect(stack.fp, 0);
        expect(stack.sp, stubSp - 16); // stub (16 bytes) also popped
      });
    });

    group('call stub result storage (Spec Lines 112-145)', () {
      test('type 0: discard result', () {
        // Spec: "0: Do not store. The result value is discarded. DestAddr should be zero." (L125)
        setupDummyFrame();
        final spBefore = stack.sp;
        stack.storeResult(0x1234, 0, 0);
        expect(stack.sp, spBefore);
      });

      test('type 1: store in memory', () {
        // Spec: "1: Store in main memory. The result value is stored in the main-memory address given by DestAddr." (L126)
        setupDummyFrame();
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
        // Spec: "2: Store in local variable. The result value is stored in the call frame at position ((FramePtr+LocalsPos) + DestAddr)." (L127)
        // writeLocal32 already handles FramePtr+LocalsPos offset.
        setupDummyFrame();
        stack.storeResult(0xDEADBEEF, 2, 4);
        expect(stack.readLocal32(4), 0xDEADBEEF);
      });

      test('type 3: push on stack', () {
        // Spec: "3: Push on stack. The result value is pushed on the stack. DestAddr should be zero." (L129)
        setupDummyFrame();
        final spBefore = stack.sp;
        stack.storeResult(0xCAFEBABE, 3, 0);
        expect(stack.sp, spBefore + 4);
        expect(stack.pop32(), 0xCAFEBABE);
      });
    });

    group('call/return coordination (Spec Lines 148-154)', () {
      test('full call and return lifecycle', () {
        // 1. "When a function is called, the terp pushes a four-value call stub." (L148)
        stack.pushCallStub(2, 0, 0x5000, 0); // DestType 2 (local), DestAddr 0
        final stubSp = stack.sp;

        // 2. "The terp then sets the FramePtr to the StackPtr, and builds a new call frame." (L149)
        final format = Uint8List.fromList([4, 1, 0, 0]); // one 32-bit local
        stack.pushFrame(format);
        expect(stack.fp, stubSp);
        expect(stack.localsPos, 12); // 8 header + 4 format (padded)

        // 3. "Function arguments can be stored in the locals of the new call frame..." (L151)
        stack.setArgument(0, 0x12345678);
        expect(stack.readLocal32(0), 0x12345678);

        // 4. "When a function returns, the process is reversed. First StackPtr is set back to FramePtr, throwing away the current call frame..." (L153)
        // Simulate some stack usage inside function
        stack.push32(999);

        final stub = stack.popFrame();
        expect(stack.sp, stubSp - 16); // Stub popped too
        expect(stack.fp, 0);

        // 5. "The function's return value is stored where the destination says it should be." (L154)
        // The destination was Local 0 of the OLD frame (which is our only frame here).
        // Since we popped, we need to be in a frame to store in a local.
        // Let's setup a "caller" frame first.

        stack.sp = 0;
        stack.fp = 0;
        stack.pushFrame(Uint8List.fromList([4, 1, 0, 0])); // Caller frame

        stack.pushCallStub(2, 4, 0x100, stack.fp); // Return to local 4
        stack.pushFrame(Uint8List.fromList([1, 1, 0, 0])); // Callee frame

        final calleeStub = stack.popFrame();
        stack.storeResult(0xABCDEF01, calleeStub[0], calleeStub[1]);

        expect(stack.readLocal32(4), 0xABCDEF01);
      });
    });

    group('string-decoding call stubs (Spec Lines 156-170)', () {
      test('type 10 and 11 result storage', () {
        // Spec: "When a function returns... it must check to see if it was called from within a string... (The function's return value is discarded.)" (L165-166)
        setupDummyFrame();
        final spBefore = stack.sp;

        // Type 10 (Compressed string)
        stack.storeResult(0x1234, 10, 0);
        expect(stack.sp, spBefore);

        // Type 11 (Function code after string)
        stack.storeResult(0x1234, 11, 0);
        expect(stack.sp, spBefore);

        // Types 12 (Decimal), 13 (E0), 14 (E2)
        stack.storeResult(0x1234, 12, 0);
        stack.storeResult(0x1234, 13, 0);
        stack.storeResult(0x1234, 14, 0);
        expect(stack.sp, spBefore);
      });

      test('push/pop string stubs with bit offsets', () {
        // Spec: "If, during string decoding, the terp encounters an indirect reference... it pushes a type-10 call stub. This includes the string-decoding PC, and the bit number within that address." (L160-161)
        stack.pushCallStub(10, 7, 0x9000, 0x3000); // Type 10, Bit 7, PC 0x9000
        final stub = stack.popCallStub();

        expect(stub[0], 10); // Type 10
        expect(stub[1], 7); // Bit offset stored in DestAddr field
        expect(stub[2], 0x9000);
        expect(stub[3], 0x3000);
      });
    });

    group('output filtering coordination (Spec Lines 172-186)', () {
      test('nested stubs for streamnum flow', () {
        // 1. "When the terp executes streamnum, it pushes a type-11 call stub." (L176)
        stack.pushCallStub(11, 0, 0x1000, 0); // Type 11, PC 0x1000
        final stub11Sp = stack.sp;

        // 2. "The terp then pushes a type-12 call stub, which contains the integer being printed..." (L177)
        stack.pushCallStub(12, 1, 0x1000, 0); // Type 12, PC 0x1000, Position 1
        final stub12Sp = stack.sp;

        // 3. "It then executes the output function." -> Build framing
        stack.pushFrame(Uint8List.fromList([0, 0]));

        // 4. "When the output function returns, the terp pops the type-12 stub..." (L179)
        final calleeStub = stack.popFrame();
        expect(calleeStub[0], 12);
        expect(stack.sp, stub12Sp - 16);

        // 5. "It pushes another type-12 stub back on the stack, indicating that the next position to print is 2..." (L180)
        stack.pushCallStub(12, 2, 0x1000, 0);

        // Repeat for a few "characters"...
        stack.pushFrame(Uint8List.fromList([0, 0]));
        final finalStub = stack.popFrame();
        expect(finalStub[0], 12);
        expect(finalStub[1], 2);

        // 6. "The terp then pops the type-11 stub... and resumes execution..." (L182)
        // If no more Type 12 stubs are pushed, the interpreter eventually pops the Type 11.
        final originalStub = stack.popCallStub();
        expect(originalStub[0], 11);
        expect(stack.sp, stub11Sp - 16);
      });

      test('storeResult throws on unknown types', () {
        setupDummyFrame();
        expect(
          () => stack.storeResult(0, 4, 0),
          throwsA(isA<GlulxException>().having((e) => e.message, 'message', contains('Unknown or reserved DestType'))),
        );
      });
    });
  });
}
