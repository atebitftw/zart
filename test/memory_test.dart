part of 'main_test.dart';

void memoryTests(int version, int programCounterAddress){
  test('Read first byte returns correct Z-Machine version (3).', () {
      expect(Z.machine.mem.loadb(0x00), equals(3));
    });

    test(
        "Read word located at address Header.PC_INITIAL_VALUE_ADDR which should be the program counter starting address.",
        () {
      expect(Z.machine.mem.loadw(Header.PC_INITIAL_VALUE_ADDR),
          equals(programCounterAddress));
    });

    test('Z.machine.mem.storeb(0x00, 42) correctly reads back as 42.', () {
      // First make sure the initial state is correct.
      expect(Z.machine.mem.loadb(0x00), equals(version));

      Z.machine.mem.storeb(0x00, 42);

      expect(Z.machine.mem.loadb(0x00), equals(42));

      Z.machine.mem.storeb(0x00, version);

      // Make sure address is back to original state.
      expect(Z.machine.mem.loadb(0x00), equals(version));
    });

    test('Z.machine.mem.storew() correctly writes and reads an expected value.',
        () {
      Z.machine.mem.storew(Header.PC_INITIAL_VALUE_ADDR, 42420);

      expect(Z.machine.mem.loadw(Header.PC_INITIAL_VALUE_ADDR), equals(42420));

      Z.machine.mem.storew(Header.PC_INITIAL_VALUE_ADDR, programCounterAddress);

      // Restore address back to original state.
      expect(Z.machine.mem.loadw(Header.PC_INITIAL_VALUE_ADDR),
          equals(programCounterAddress));
    });

    test(
        "Z.machine.mem.loadw() correct reads a value from the global variables memory area with offset.",
        () {
      expect(Z.machine.mem.loadw(Z.machine.mem.globalVarsAddress + 8),
          equals(8101));
    });

    test(
        "Z.machine.mem.readGlobal() correctly reads a value from the global variables memory area.",
        () {
      expect(Z.machine.mem.readGlobal(0x14), equals(8101));
    });

    test(
        "Z.machine.mem.writeGlobal() correctly writes a value to the global variables memory area.",
        () {
      Z.machine.mem.writeGlobal(0x14, 41410);

      expect(Z.machine.mem.readGlobal(0x14), equals(41410));

      // Restore and test state again.
      Z.machine.mem.writeGlobal(0x14, 8101);

      expect(Z.machine.mem.readGlobal(0x14), equals(8101));
    });
}