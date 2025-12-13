import 'package:test/test.dart';
import 'package:zart/zart.dart';
import 'package:zart/src/interpreters/interpreter_v5.dart';
import 'dart:typed_data';

class MockIoProvider extends IoProvider {
  final List<Map<String, dynamic>> commands = [];

  @override
  Future<dynamic> command(Map<String, dynamic> ioData) async {
    commands.add(ioData);
    if (ioData['command'] == IoCommands.read) return "quit";
    return null;
  }

  @override
  int getFlags1() => 0x7F;
}

void main() {
  late MockIoProvider provider;

  setUp(() {
    provider = MockIoProvider();
    Z.io = provider;
  });

  test('Verification: Header Cursor Position Update (Beyond Zork Compat)', () async {
    // 1. Setup V5 memory (64KB)
    final List<int> mem = List.filled(65536, 0);
    mem[0] = 5; // V5

    // Set Header Pointers
    mem[8] = 0x02; // Dictionary at 0x0200 = 512
    mem[9] = 0x00;

    mem[10] = 0x02; // Objects at 0x0280 = 640 (dummy)
    mem[11] = 0x80;

    mem[12] = 0x03; // Globals at 0x0300 = 768
    mem[13] = 0x00;

    // Valid Dictionary Header at 512
    mem[512] = 0x00; // 0 Separators
    mem[513] = 0x07; // Entry length (must be >= 6)
    mem[514] = 0x00;
    mem[515] = 0x00; // 0 Entries

    int pc = 256;
    mem[6] = 0x01; // PC packed address

    // Initial Instructions
    // instructions written here will be loaded into Z-Machine memory

    // set_window 1
    mem[pc++] = 0xEB;
    mem[pc++] = 0x7F; // Small, Omitted...
    mem[pc++] = 0x01;

    // set_cursor 15 25
    mem[pc++] = 0xEF;
    mem[pc++] = 0x5F; // Small, Small, Omitted...
    mem[pc++] = 0x0F;
    mem[pc++] = 0x19;

    // quit
    mem[pc++] = 0xBA;

    // Load and Run
    Z.load(mem);

    // Override PC to skip normal startup routine call
    Z.engine.programCounter = 256;

    print("Step 1: set_window 1");
    await Z.engine.visitInstruction();

    expect(Z.engine.mem.loadb(0x24), equals(1), reason: "Header Row should be 1 after set_window 1");
    expect(Z.engine.mem.loadb(0x25), equals(1), reason: "Header Column should be 1 after set_window 1");

    print("Step 2: set_cursor 15 25");
    await Z.engine.visitInstruction();

    expect(Z.engine.mem.loadb(0x24), equals(15), reason: "Header Row should be updated to 15");
    expect(Z.engine.mem.loadb(0x25), equals(25), reason: "Header Column should be updated to 25");

    print("Step 3: quit");
    await Z.engine.visitInstruction();

    print("Step 4: erase_window 1");
    // Dynamic instruction writing using Z.engine.mem directly
    pc = 300;
    Z.engine.programCounter = pc;
    Z.engine.mem.storeb(pc++, 0xED);
    Z.engine.mem.storeb(pc++, 0x7F);
    Z.engine.mem.storeb(pc++, 0x01);

    await Z.engine.visitInstruction();

    expect(Z.engine.mem.loadb(0x24), equals(1), reason: "Header Row should be reset to 1 after erase_window 1");
    expect(Z.engine.mem.loadb(0x25), equals(1), reason: "Header Column should be reset to 1 after erase_window 1");

    print("Step 5: set_window 1 again");
    Z.engine.mem.storeb(0x24, 10);
    Z.engine.mem.storeb(0x25, 10);

    pc = 310;
    Z.engine.programCounter = pc;
    Z.engine.mem.storeb(pc++, 0xEB);
    Z.engine.mem.storeb(pc++, 0x7F);
    Z.engine.mem.storeb(pc++, 0x01);

    if (Z.engine is InterpreterV5) {
      (Z.engine as InterpreterV5).currentWindow = 0;
    }

    await Z.engine.visitInstruction();

    expect(Z.engine.mem.loadb(0x24), equals(1), reason: "Header Row should be reset to 1 after switching to window 1");
    expect(
      Z.engine.mem.loadb(0x25),
      equals(1),
      reason: "Header Column should be reset to 1 after switching to window 1",
    );
  });
}
