import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/glulx/glulx_header.dart';
import 'package:zart/src/glulx/glulx_exception.dart';
import 'glulx_test_utils.dart';

void main() {
  group('GlulxHeader Spec Conformance', () {
    test('Magic number validation (ASCII "Glul")', () {
      // magic number: 47 6C 75 6C (ASCII 'Glul')
      final validHeader = Uint8List(36)..setRange(0, 4, [0x47, 0x6C, 0x75, 0x6C]);
      // Set a valid version as well
      validHeader.setRange(4, 8, [0x00, 0x03, 0x01, 0x03]);

      final header = GlulxHeader(validHeader);
      expect(
        header.magicNumber,
        equals(0x476C756C),
        reason: 'Spec: Magic number: 47 6C 75 6C, which is to say ASCII "Glul".',
      );
      expect(() => header.validate(), returnsNormally);

      final invalidHeader = Uint8List(36)..setRange(0, 4, [0x42, 0x42, 0x42, 0x42]);
      final header2 = GlulxHeader(invalidHeader);
      expect(
        () => header2.validate(),
        throwsA(isA<GlulxException>()),
        reason: 'Spec: The interpreter should validate the magic number.',
      );
    });

    test('Version validation (3.1.3 accepts 2.0.0 to 3.1.*)', () {
      final base = Uint8List(36)..setRange(0, 4, [0x47, 0x6C, 0x75, 0x6C]);

      // Exactly 3.1.3
      final v313 = Uint8List.fromList(base)..setRange(4, 8, [0x00, 0x03, 0x01, 0x03]);
      expect(() => GlulxHeader(v313).validate(), returnsNormally);

      // 3.1.255 (Highest 3.1.*)
      final v31255 = Uint8List.fromList(base)..setRange(4, 8, [0x00, 0x03, 0x01, 0xFF]);
      expect(() => GlulxHeader(v31255).validate(), returnsNormally);

      // 2.0.0 (Exception: A version 3.* interpreter should accept version 2.0 game files)
      final v200 = Uint8List.fromList(base)..setRange(4, 8, [0x00, 0x02, 0x00, 0x00]);
      expect(() => GlulxHeader(v200).validate(), returnsNormally);

      // 1.0.0 (Too low)
      final v100 = Uint8List.fromList(base)..setRange(4, 8, [0x00, 0x01, 0x00, 0x00]);
      expect(() => GlulxHeader(v100).validate(), throwsA(isA<GlulxException>()));

      // 4.0.0 (Too high)
      final v400 = Uint8List.fromList(base)..setRange(4, 8, [0x00, 0x04, 0x00, 0x00]);
      expect(() => GlulxHeader(v400).validate(), throwsA(isA<GlulxException>()));
    });

    test('Field extraction correctness', () {
      final data = Uint8List(36);
      final view = ByteData.view(data.buffer);

      view.setUint32(0x00, 0x476C756C); // Magic
      view.setUint32(0x04, 0x00030103); // Version
      view.setUint32(0x08, 0x1000); // RAMSTART
      view.setUint32(0x0C, 0x2000); // EXTSTART
      view.setUint32(0x10, 0x3000); // ENDMEM
      view.setUint32(0x14, 0x0400); // Stack Size
      view.setUint32(0x18, 0x1234); // Start Func
      view.setUint32(0x1C, 0x5678); // Decoding Tbl
      view.setUint32(0x20, 0xDEADBEEF); // Checksum

      final header = GlulxHeader(data);

      expect(header.magicNumber, equals(0x476C756C));
      expect(header.version, equals(0x00030103));
      expect(header.ramStart, equals(0x1000));
      expect(header.extStart, equals(0x2000));
      expect(header.endMem, equals(0x3000));
      expect(header.stackSize, equals(0x0400));
      expect(header.startFunc, equals(0x1234));
      expect(header.decodingTbl, equals(0x5678));
      expect(header.checksum, equals(0xDEADBEEF));
    });

    test('Real-world test: monkey.gblorb', () {
      final gameData = GlulxTestUtils.loadTestGame('assets/games/monkey.gblorb');
      final header = GlulxHeader(gameData);

      expect(() => header.validate(), returnsNormally, reason: 'monkey.gblorb should have a valid Glulx header.');

      // Basic sanity checks for monkey.gblorb
      expect(header.magicNumber, equals(0x476C756C));
      expect(header.ramStart, isNonZero);
      expect(
        header.extStart,
        equals(gameData.length),
        reason:
            'Spec: EXTSTART: The end of the game-file\'s stored initial memory (and therefore the length of the game file.)',
      );
    });
  });
}
