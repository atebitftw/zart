part of 'main_test.dart';

void memoryTests(int version, int programCounterAddress){
  test('Read first byte returns correct Z-Machine version (3).', () {
      expect(Z.engine.mem.loadb(0x00), equals(3));
    });

    test(
        "Read word located at address Header.PC_INITIAL_VALUE_ADDR which should be the program counter starting address.",
        () {
      expect(Z.engine.mem.loadw(Header.programCounterInitialValueAddr),
          equals(programCounterAddress));
    });

    test('Z.machine.mem.storeb(0x00, 42) correctly reads back as 42.', () {
      // First make sure the initial state is correct.
      expect(Z.engine.mem.loadb(0x00), equals(version));

      Z.engine.mem.storeb(0x00, 42);

      expect(Z.engine.mem.loadb(0x00), equals(42));

      Z.engine.mem.storeb(0x00, version);

      // Make sure address is back to original state.
      expect(Z.engine.mem.loadb(0x00), equals(version));
    });

    test('Z.machine.mem.storew() correctly writes and reads an expected value.',
        () {
      Z.engine.mem.storew(Header.programCounterInitialValueAddr, 42420);

      expect(Z.engine.mem.loadw(Header.programCounterInitialValueAddr), equals(42420));

      Z.engine.mem.storew(Header.programCounterInitialValueAddr, programCounterAddress);

      // Restore address back to original state.
      expect(Z.engine.mem.loadw(Header.programCounterInitialValueAddr),
          equals(programCounterAddress));
    });

    test(
        "Z.machine.mem.loadw() correct reads a value from the global variables memory area with offset.",
        () {
      expect(Z.engine.mem.loadw(Z.engine.mem.globalVarsAddress + 8),
          equals(8101));
    });

    test(
        "Z.machine.mem.readGlobal() correctly reads a value from the global variables memory area.",
        () {
      expect(Z.engine.mem.readGlobal(0x14), equals(8101));
    });

    test(
        "Z.machine.mem.writeGlobal() correctly writes a value to the global variables memory area.",
        () {
      Z.engine.mem.writeGlobal(0x14, 41410);

      expect(Z.engine.mem.readGlobal(0x14), equals(41410));

      // Restore and test state again.
      Z.engine.mem.writeGlobal(0x14, 8101);

      expect(Z.engine.mem.readGlobal(0x14), equals(8101));
    });
}