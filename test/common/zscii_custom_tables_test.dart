import 'package:test/test.dart';
import 'package:zart/src/z_machine/z_machine.dart';
import 'package:zart/src/z_machine/zscii.dart';
import 'package:zart/zart.dart';
import '../test_utils.dart';

void main() {
  setupZMachine();

  group('ZSCII Custom Tables Tests>', () {
    setUp(() {
      // Initialize with a dummy V5 game file
      // 64KB of memory, adequate for tests
      final List<int> v5Dummy = List.filled(0xFFFF, 0);
      v5Dummy[Header.version] = 5; // Set version to 5

      // Setup a minimal valid dictionary
      // Dictionary address at 0x0800
      final dictAddress = 0x0800;
      v5Dummy[Header.dictionaryAddr] = (dictAddress >> 8) & 0xFF; // High byte
      v5Dummy[Header.dictionaryAddr + 1] = dictAddress & 0xFF; // Low byte

      // Construct minimal dictionary at dictAddress
      // table header:
      // n = 0 (number of separators)
      v5Dummy[dictAddress] = 0;
      // entry_length = 6 (min for V4+) - located after separators (0 bytes)
      v5Dummy[dictAddress + 1] = 6;
      // entry_count = 0 (2 bytes)
      v5Dummy[dictAddress + 2] = 0;
      v5Dummy[dictAddress + 3] = 0;

      Z.load(v5Dummy);

      // Ensure we are in V5
      expect(Z.engine.version, equals(ZMachineVersions.v5));
    });

    test('Custom Alphabet Table is used when present', () {
      // Setup a custom alphabet table in memory
      // Let's make A0 map 'a' to 'Q', 'b' to 'R', just for the first few chars.
      // 78 bytes total: 26 for A0, 26 for A1, 26 for A2.
      // Address 0x4000 (arbitrary free memory)
      final tableAddr = 0x4000;
      Z.engine.mem.storew(Header.alphabetTable, tableAddr);

      // Fill with '?' by default
      for (int i = 0; i < 78; i++) {
        Z.engine.mem.storeb(tableAddr + i, '?'.codeUnitAt(0));
      }

      // Modify A0 first char (offset 0) to be 'Q' (normally 'a')
      Z.engine.mem.storeb(tableAddr + 0, 'Q'.codeUnitAt(0));
      // Modify A0 second char (offset 1) to be 'R' (normally 'b')
      Z.engine.mem.storeb(tableAddr + 1, 'R'.codeUnitAt(0));

      // Construct a Z-string that uses these characters.
      // Just encoding 'ab' (using default encoding rules but custom lookup)
      // 'a' is Z-char 6, 'b' is Z-char 7 in default A0... Wait.
      // The Z-string reader reads 5-bit codes.
      // Codes 6-31 map to the table at index code-6.
      // So code 6 maps to table index 0.

      // We want to simulate a Z-String at address 0x5000
      final stringAddr = 0x5000;
      // Z-Char for 'a' (index 0) is 6. Z-Char for 'b' (index 1) is 7.
      // Pack into words. 3 chars per word.
      // Word 1: 6, 7, 0(space) -> (6<<10) | (7<<5) | 0 = 0x18E0
      // Set bit 15 on last word? No, let's just do one word with terminator.
      // Terminator bit is 15.
      // Let's do (6, 7, 5(shift A2? no just terminator padding))
      // Terminated word: bit 15 set.
      // Value: (1<<15) | (6<<10) | (7<<5) | 5 (pad)
      // = 0x8000 | 0x1800 | 0x00E0 | 0x5 = 0x98E5

      Z.engine.mem.storew(stringAddr, 0x98E5);

      final result = ZSCII.readZString(stringAddr);

      // Note: ' ' is not from the table, it's hardcoded.
      // 'Q' and 'R' are from our custom table.
      // The 3rd char in our word was 5 (Shift A2).
      // It doesn't print anything.

      expect(result, equals('QR'));
    });

    test('Custom Unicode Table is used when present', () {
      final extTableAddr = 0x4100;
      final unicodeTableAddr = 0x4200;

      // Set Header Extension Table
      Z.engine.mem.storew(Header.headerExtensionTable, extTableAddr);

      // Header Extension Table:
      // Word 0: Number of further words (let's say 3)
      Z.engine.mem.storew(extTableAddr, 3);
      // Word 1: Mouse X
      // Word 2: Mouse Y
      // Word 3 (at addr+4*2? No, words are 2 bytes. Addr+6? No.)
      // Standard 1.1.1.2: "The Header Extension Table... is a table of words."
      // "The first word contains the number of further words... The third word (at address + 4)"
      // So at extTableAddr + 4 bytes.

      Z.engine.mem.storew(extTableAddr + 4, unicodeTableAddr);

      // Unicode Table Setup (ref 3.8.5.4.1)
      // "The table contains n 16-bit words."
      // "The first byte of the table gives the number n."

      Z.engine.mem.storeb(unicodeTableAddr, 2); // n = 2

      // Word 0 (at unicodeTableAddr + 1? No, alignment?)
      // Standard: "The first byte... gives n. Following this are n 16-bit words."
      // So word 0 starts at unicodeTableAddr + 1.

      // Make ZSCII 155 map to '✈' (Plane, 0x2708)
      Z.engine.mem.storew(unicodeTableAddr + 1, 0x2708);
      // Make ZSCII 156 map to '⛄' (Snowman, 0x26C4)
      Z.engine.mem.storew(unicodeTableAddr + 1 + 2, 0x26C4);

      // Verify lookup 155 -> ✈
      expect(ZSCII.zCharToChar(155), equals('✈'));

      // Verify lookup 156 -> ⛄
      expect(ZSCII.zCharToChar(156), equals('⛄'));

      // Verify lookup 157 (out of range of custom table) -> default (e.g., 'ü' 0xfc)
      // 157 is outside our table of length 2 (covers 155, 156).
      // ZSCII default table: 157 -> ü (0xfc)
      final default157 = String.fromCharCode(0xfc);
      expect(ZSCII.zCharToChar(157), equals(default157));
    });
  });
}
