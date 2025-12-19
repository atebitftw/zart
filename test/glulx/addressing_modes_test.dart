import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/glulx/glulx_interpreter.dart';
import 'mock_glk_io_provider.dart';

class MockGlkIoProvider extends TestGlkIoProvider {
  @override
  Future<int> glkDispatch(int selector, List<int> args) async => 0;

  @override
  int readMemory(int addr, {int size = 1}) => 0;

  @override
  void writeMemory(int addr, int value, {int size = 1}) {}
}

void main() {
  late GlulxInterpreter interpreter;
  late GlulxInterpreterTestingHarness harness;

  Uint8List createDummyGame() {
    final data = Uint8List(4096);
    // Magic: 'Glul' (0x476C756C)
    data[0] = 0x47;
    data[1] = 0x6C;
    data[2] = 0x75;
    data[3] = 0x6C;
    // RAMSTART at offset 8: 0x100
    data[8] = 0;
    data[9] = 0;
    data[10] = 1;
    data[11] = 0;
    // EXTSTART at offset 12: 0x400
    data[12] = 0;
    data[13] = 0;
    data[14] = 4;
    data[15] = 0;
    // ENDMEM at offset 16: 0x1000
    data[16] = 0;
    data[17] = 0;
    data[18] = 0x10;
    data[19] = 0;
    // STACKSIZE at offset 20: 0x1000
    data[20] = 0;
    data[21] = 0;
    data[22] = 0x10;
    data[23] = 0;
    return data;
  }

  setUp(() async {
    final gameData = createDummyGame();
    interpreter = GlulxInterpreter(TestGlkIoProvider());
    await interpreter.load(gameData);
    harness = GlulxInterpreterTestingHarness(interpreter);
  });

  group('Addressing Modes', () {
    test('Mode 0-3: Constants', () {
      final ram = interpreter.memoryMap.ramStart;
      harness.setProgramCounter(ram);

      // Spec: "0: Constant zero. (Zero bytes)"
      expect(interpreter.loadOperand(0), equals(0));

      // Spec: "1: Constant, -80 to 7F. (One byte)"
      // Write operand data 0xFB (-5) at RAM
      interpreter.memoryMap.writeByte(ram, 0xFB);
      harness.setProgramCounter(ram);
      expect(interpreter.loadOperand(1), equals(-5));

      // Spec: "2: Constant, -8000 to 7FFF. (Two bytes)"
      // Write 0xFFF6 (-10)
      interpreter.memoryMap.writeShort(ram, 0xFFF6);
      harness.setProgramCounter(ram);
      expect(interpreter.loadOperand(2), equals(-10));

      // Spec: "3: Constant, any value. (Four bytes)"
      // Write 0x12345678
      interpreter.memoryMap.writeWord(ram, 0x12345678);
      harness.setProgramCounter(ram);
      expect(interpreter.loadOperand(3), equals(0x12345678));
    });

    test('Mode 5-7: Memory addresses', () {
      final ram = interpreter.memoryMap.ramStart;
      final opDataPos = ram;
      final targetRamAddr = ram + 0x200; // 0x300
      final value = 0xDEADBEEF;
      interpreter.memoryMap.writeWord(targetRamAddr, value);

      // Spec: "5: Contents of address 00 to FF. (One byte)"
      // Address 0x08 in ROM contains RAMSTART (0x100)
      harness.setProgramCounter(opDataPos);
      interpreter.memoryMap.writeByte(opDataPos, 0x08);
      expect(interpreter.loadOperand(5), equals(0x100));

      // Spec: "6: Contents of address 0000 to FFFF. (Two bytes)"
      // Point to targetRamAddr (0x300)
      harness.setProgramCounter(opDataPos);
      interpreter.memoryMap.writeShort(opDataPos, targetRamAddr);
      expect(interpreter.loadOperand(6), equals(value));

      // Spec: "7: Contents of any address. (Four bytes)"
      harness.setProgramCounter(opDataPos);
      interpreter.memoryMap.writeWord(opDataPos, targetRamAddr);
      expect(interpreter.loadOperand(7), equals(value));
    });

    test('Mode 8: Stack', () {
      // Spec: "8: Value popped off stack. (Zero bytes)"
      // Spec: "8: The value is pushed into the stack, instead of being popped off."
      final format = Uint8List.fromList([1, 1, 4, 1, 0, 0]);
      interpreter.stack.pushFrame(format);

      interpreter.stack.push32(0x11223344);
      expect(interpreter.loadOperand(8), equals(0x11223344));

      interpreter.storeOperand(8, 0x55667788);
      expect(interpreter.stack.pop32(), equals(0x55667788));
    });

    test('Mode 9-B: Locals', () {
      // Spec: "9: Call frame local at address 00 to FF. (One byte)"
      // Spec: "A: Call frame local at address 0000 to FFFF. (Two bytes)"
      // Spec: "B: Call frame local at any address. (Four bytes)"
      final format = Uint8List.fromList([1, 1, 4, 1, 0, 0]);
      interpreter.stack.pushFrame(format);
      interpreter.stack.writeLocal32(0, 0xABCDEF01);

      final ram = interpreter.memoryMap.ramStart;
      final opDataPos = ram;

      // Mode 9: offset 0
      harness.setProgramCounter(opDataPos);
      interpreter.memoryMap.writeByte(opDataPos, 0x00);
      expect(interpreter.loadOperand(9), equals(0xABCDEF01));

      // Mode A: offset 0
      harness.setProgramCounter(opDataPos);
      interpreter.memoryMap.writeShort(opDataPos, 0x0000);
      expect(interpreter.loadOperand(0xA), equals(0xABCDEF01));

      // Mode B: offset 0
      harness.setProgramCounter(opDataPos);
      interpreter.memoryMap.writeWord(opDataPos, 0x00000000);
      expect(interpreter.loadOperand(0xB), equals(0xABCDEF01));

      interpreter.storeOperand(9, 0x12345678);
      expect(interpreter.stack.readLocal32(0), equals(0x12345678));
    });

    test('Mode D-F: RAM Relative', () {
      // Spec: "D: Contents of RAM address 00 to FF. (One byte)"
      // Spec: "E: Contents of RAM address 0000 to FFFF. (Two bytes)"
      // Spec: "F: Contents of RAM, any address. (Four bytes)"
      final ram = interpreter.memoryMap.ramStart;
      final relativeAddr = 0x10;
      final value = 0x99887766;
      interpreter.memoryMap.writeWord(ram + relativeAddr, value);

      final opDataPos = ram + 0x80;

      // Mode D: offset 0x10
      harness.setProgramCounter(opDataPos);
      interpreter.memoryMap.writeByte(opDataPos, 0x10);
      expect(interpreter.loadOperand(0xD), equals(value));

      // Mode E: offset 0x10
      harness.setProgramCounter(opDataPos);
      interpreter.memoryMap.writeShort(opDataPos, 0x0010);
      expect(interpreter.loadOperand(0xE), equals(value));

      // Mode F: offset 0x10
      harness.setProgramCounter(opDataPos);
      interpreter.memoryMap.writeWord(opDataPos, 0x00000010);
      expect(interpreter.loadOperand(0xF), equals(value));

      harness.setProgramCounter(opDataPos);
      interpreter.memoryMap.writeByte(opDataPos, 0x10);
      interpreter.storeOperand(0xD, 0x11112222);
      expect(interpreter.memoryMap.readWord(ram + 0x10), equals(0x11112222));
    });
    group('Opcode Decoding', () {
      test('Instruction Format - opcode and addressing modes', () {
        // Spec: "An instruction is encoded as follows: Opcode Num (1-4 bytes), Addressing Modes, Operand Data"
        final ram = interpreter.memoryMap.ramStart;

        // Let's encode a simple add opcode (0x10), with mode 1 (1 byte const) and mode 8 (stack push)
        // add L1 L2 S1
        // Opcode: 0x10
        // Addressing modes (4 bits each): mode 1, mode 8, mode 0 (for simplicity/unused)
        // Byte 1: 0x81 (Mode 1 in low 4 bits, Mode 8 in high 4 bits)
        // Byte 2: 0x00 (Mode 0 in low 4 bits, rest zero)
        // Operand data for mode 1: 0x05 (1 byte)

        final program = [
          0x10, // add
          0x81, // Mode 1, Mode 8
          0x00, // Mode 0
          0x05, // 5 (constant)
        ];

        for (var i = 0; i < program.length; i++) {
          interpreter.memoryMap.writeByte(ram + i, program[i]);
        }

        harness.setProgramCounter(ram);

        // This tests the instruction decoding components
        final opcode = harness.readOpCode();
        expect(opcode, equals(0x10));

        final modes = harness.readAddressingModes(3);
        expect(modes, equals([1, 8, 0]));

        final op1 = interpreter.loadOperand(modes[0]);
        expect(op1, equals(5));
      });
    });
  });
}
