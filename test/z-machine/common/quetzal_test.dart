import 'package:test/test.dart';
import 'package:zart/src/z_machine/interpreters/interpreter_v3.dart';
import 'package:zart/zart.dart';
import 'package:zart/src/io/quetzal.dart';
import '../test_utils.dart';

void main() {
  setupZMachine();

  group('Quetzal >', () {
    test('Save and Restore using CMem', () async {
      // 1. Setup initial state
      expect(Z.isLoaded, isTrue);

      // 2. Setup Dummy Call Stack Frame
      // Quetzal expects at least one frame.
      // Push order (bottom to top) to achieve [ReturnAddr, ReturnVar, TotalLocals, ArgsPassed] at indices 0, 1, 2, 3
      Z.engine.callStack.clear();
      Z.engine.callStack.push(0); // Args passed (index 3)
      Z.engine.callStack.push(0); // Local count (index 2) -> implies no locals pushed
      Z.engine.callStack.push(0); // Return Var (index 1)
      Z.engine.callStack.push(0x1234); // Return Addr (index 0)

      // Setup Evaluation Stack (Engine.stack)
      // QuetzalStackFrame reads from Z.engine.stack[0] onwards until StackMarker.
      Z.engine.stack.clear();
      Z.engine.stack.push(InterpreterV3.stackMarker);

      // 3. Modify dynamic memory
      var originalByte0 = Z.engine.mem.loadb(0);
      var originalByte1 = Z.engine.mem.loadb(1);

      var newByte0 = (originalByte0 + 1) & 0xFF;
      var newByte1 = (originalByte1 + 1) & 0xFF;

      Z.engine.mem.storeb(0, newByte0);
      Z.engine.mem.storeb(1, newByte1);

      // Verify modification
      expect(Z.engine.mem.loadb(0), equals(newByte0));
      expect(Z.engine.mem.loadb(1), equals(newByte1));

      // 4. Save
      var pc = 0x1234;
      var saveBytes = Quetzal.save(pc);

      // 5. Verify CMem chunk is present
      // Convert to string to check for "CMem" tag (rough check)
      var saveString = String.fromCharCodes(saveBytes.where((b) => b != null).map((b) => b!));
      expect(saveString, contains('CMem'));

      // 6. Reset Memory (Simulate restart or new game)
      Z.engine.mem.storeb(0, originalByte0);
      Z.engine.mem.storeb(1, originalByte1);
      expect(Z.engine.mem.loadb(0), equals(originalByte0));

      // Reset stack for restore (Restore will rebuild it)
      Z.engine.callStack.clear();

      // 7. Restore
      var result = Quetzal.restore(saveBytes as List<int>);
      expect(result, isTrue);

      // 8. Verify memory is restored
      expect(Z.engine.mem.loadb(0), equals(newByte0));
      expect(Z.engine.mem.loadb(1), equals(newByte1));
    });

    test('CMem Compression Logic (Indirect)', () {
      // This tests that we can compress and decompress effectively via the public API

      // Zero out a block of memory to force RLE
      var start = 0x10;
      for (var i = 0; i < 300; i++) {
        Z.engine.mem.storeb(start + i, 0);
      }

      // Setup stack
      Z.engine.callStack.clear();
      Z.engine.callStack.push(0); // Args passed
      Z.engine.callStack.push(0); // Local count
      Z.engine.callStack.push(0); // Return Var
      Z.engine.callStack.push(0x1234); // Return Addr

      var pc = 0x1234;
      var saveBytes = Quetzal.save(pc);

      // Verify size is smaller than raw memory due to compression
      var memSize = Z.engine.mem.memList.length;
      var saveSize = saveBytes.length;

      // Memory is usually large (10s of KB), save file with mostly 0 diffs should be small.
      expect(saveSize, lessThan(memSize));

      print('Mem Size: $memSize, Save Size: $saveSize');
    });

    test('IFF Header Compliance', () {
      var pc = 0;
      var saveBytes = Quetzal.save(pc);

      // Check FORM chunk (0-3)
      expect(saveBytes[0], equals(0x46)); // F
      expect(saveBytes[1], equals(0x4F)); // O
      expect(saveBytes[2], equals(0x52)); // R
      expect(saveBytes[3], equals(0x4D)); // M

      // Check Size (Bytes 4-7)
      // Total size - 8
      var expectedSize = saveBytes.length - 8;
      // saveBytes is List<int?>, but we know it contains ints.
      var actualSize = (saveBytes[4]! << 24) | (saveBytes[5]! << 16) | (saveBytes[6]! << 8) | saveBytes[7]!;
      expect(actualSize, equals(expectedSize));

      // Check IFZS (Bytes 8-11)
      expect(saveBytes[8], equals(0x49)); // I
      expect(saveBytes[9], equals(0x46)); // F
      expect(saveBytes[10], equals(0x5A)); // Z
      expect(saveBytes[11], equals(0x53)); // S
    });
  });
}
