import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/glulx/glulx_header.dart';
import 'package:zart/src/glulx/glulx_exception.dart';
import 'glulx_test_utils.dart';

void main() {
  group('GlulxHeader Spec Conformance', () {
    group('Header Structure', () {
      test('header size is 36 bytes', () {
        // Spec: "The header is the first 36 bytes of memory."
        expect(GlulxHeader.size, equals(36));
      });

      test('throws if data is too short', () {
        final shortData = Uint8List(35);
        expect(
          () => GlulxHeader(shortData),
          throwsA(isA<GlulxException>()),
          reason: 'Header requires 36 bytes minimum',
        );
      });

      test('field offsets match spec', () {
        // Spec: Header layout is nine 32-bit values starting at address 0
        expect(GlulxHeader.magicNumberOffset, equals(0x00));
        expect(GlulxHeader.versionOffset, equals(0x04));
        expect(GlulxHeader.ramStartOffset, equals(0x08));
        expect(GlulxHeader.extStartOffset, equals(0x0C));
        expect(GlulxHeader.endMemOffset, equals(0x10));
        expect(GlulxHeader.stackSizeOffset, equals(0x14));
        expect(GlulxHeader.startFuncOffset, equals(0x18));
        expect(GlulxHeader.decodingTblOffset, equals(0x1C));
        expect(GlulxHeader.checksumOffset, equals(0x20));
      });
    });

    group('Magic Number Validation', () {
      test('valid magic number (ASCII "Glul")', () {
        // Spec: "Magic number: 47 6C 75 6C, which is to say ASCII 'Glul'."
        final validHeader = Uint8List(36)..setRange(0, 4, [0x47, 0x6C, 0x75, 0x6C]);
        // Set a valid version as well
        validHeader.setRange(4, 8, [0x00, 0x03, 0x01, 0x03]);

        final header = GlulxHeader(validHeader);
        expect(header.magicNumber, equals(0x476C756C));
        expect(header.magicNumber, equals(GlulxHeader.expectedMagicNumber));
        expect(() => header.validate(), returnsNormally);
      });

      test('invalid magic number throws', () {
        // Spec: "The interpreter should validate the magic number"
        final invalidHeader = Uint8List(36)..setRange(0, 4, [0x42, 0x42, 0x42, 0x42]);
        final header = GlulxHeader(invalidHeader);
        expect(() => header.validate(), throwsA(isA<GlulxException>()));
      });
    });

    group('Version Validation', () {
      test('version 3.1.3 is accepted', () {
        // Spec: "This specification is version 3.1.3"
        final base = _createValidHeader();
        base.setRange(4, 8, [0x00, 0x03, 0x01, 0x03]);
        expect(() => GlulxHeader(base).validate(), returnsNormally);
      });

      test('version 3.1.255 (highest 3.1.*) is accepted', () {
        // Spec: "version between X.0.0 and X.Y.*"
        final base = _createValidHeader();
        base.setRange(4, 8, [0x00, 0x03, 0x01, 0xFF]);
        expect(() => GlulxHeader(base).validate(), returnsNormally);
      });

      test('version 2.0.0 is accepted (exception rule)', () {
        // Spec: "EXCEPTION: A version 3.* interpreter should accept version 2.0 game files."
        final base = _createValidHeader();
        base.setRange(4, 8, [0x00, 0x02, 0x00, 0x00]);
        expect(() => GlulxHeader(base).validate(), returnsNormally);
      });

      test('version 3.0.0 is accepted', () {
        final base = _createValidHeader();
        base.setRange(4, 8, [0x00, 0x03, 0x00, 0x00]);
        expect(() => GlulxHeader(base).validate(), returnsNormally);
      });

      test('version 1.0.0 is rejected (too low)', () {
        final base = _createValidHeader();
        base.setRange(4, 8, [0x00, 0x01, 0x00, 0x00]);
        expect(() => GlulxHeader(base).validate(), throwsA(isA<GlulxException>()));
      });

      test('version 4.0.0 is rejected (too high)', () {
        final base = _createValidHeader();
        base.setRange(4, 8, [0x00, 0x04, 0x00, 0x00]);
        expect(() => GlulxHeader(base).validate(), throwsA(isA<GlulxException>()));
      });

      test('version 3.2.0 is rejected (minor too high)', () {
        // Spec: "minor version number should be less than or equal to Y"
        final base = _createValidHeader();
        base.setRange(4, 8, [0x00, 0x03, 0x02, 0x00]);
        expect(() => GlulxHeader(base).validate(), throwsA(isA<GlulxException>()));
      });
    });

    group('Version Component Getters', () {
      test('extracts major, minor, subminor correctly', () {
        // Spec: "The upper 16 bits stores the major version number;
        // the next 8 bits stores the minor version number;
        // the low 8 bits stores an even more minor version number"
        final data = _createValidHeader();
        data.setRange(4, 8, [0x00, 0x03, 0x01, 0x03]); // 3.1.3

        final header = GlulxHeader(data);
        expect(header.majorVersion, equals(3));
        expect(header.minorVersion, equals(1));
        expect(header.subminorVersion, equals(3));
        expect(header.versionString, equals('3.1.3'));
      });

      test('handles version 2.0.0', () {
        final data = _createValidHeader();
        data.setRange(4, 8, [0x00, 0x02, 0x00, 0x00]);

        final header = GlulxHeader(data);
        expect(header.majorVersion, equals(2));
        expect(header.minorVersion, equals(0));
        expect(header.subminorVersion, equals(0));
        expect(header.versionString, equals('2.0.0'));
      });
    });

    group('Field Extraction', () {
      test('all fields extracted correctly', () {
        final data = Uint8List(36);
        final view = ByteData.view(data.buffer);

        view.setUint32(0x00, 0x476C756C, Endian.big); // Magic
        view.setUint32(0x04, 0x00030103, Endian.big); // Version 3.1.3
        view.setUint32(0x08, 0x1000, Endian.big); // RAMSTART
        view.setUint32(0x0C, 0x2000, Endian.big); // EXTSTART
        view.setUint32(0x10, 0x3000, Endian.big); // ENDMEM
        view.setUint32(0x14, 0x0400, Endian.big); // Stack Size
        view.setUint32(0x18, 0x1234, Endian.big); // Start Func
        view.setUint32(0x1C, 0x5678, Endian.big); // Decoding Tbl
        view.setUint32(0x20, 0xDEADBEEF, Endian.big); // Checksum

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

      test('decoding table can be zero', () {
        // Spec: "This may be zero, indicating that no compressed strings are to be decoded."
        final data = _createValidHeader();
        ByteData.view(data.buffer).setUint32(0x1C, 0, Endian.big);

        final header = GlulxHeader(data);
        expect(header.decodingTbl, equals(0));
        expect(() => header.validate(), returnsNormally);
      });
    });

    group('Checksum Computation', () {
      test('computes checksum correctly', () {
        // Spec: "A simple sum of the entire initial contents of memory,
        // considered as an array of big-endian 32-bit integers.
        // The checksum should be computed with this field set to zero."
        final memory = Uint8List(64);
        final view = ByteData.view(memory.buffer);

        // Add some test values
        view.setUint32(0, 0x00000001, Endian.big);
        view.setUint32(4, 0x00000002, Endian.big);
        view.setUint32(8, 0x00000003, Endian.big);
        // Skip checksum at offset 0x20
        view.setUint32(36, 0x00000010, Endian.big);

        // Expected: 1 + 2 + 3 + ... + 10 (skipping checksum offset)
        final computed = GlulxHeader.computeChecksum(memory);
        expect(computed, isNonZero);
      });

      test('verifyChecksum returns true for matching checksum', () {
        // Create a small memory with known values
        final memory = Uint8List(64);
        final view = ByteData.view(memory.buffer);

        // Set magic and version for a valid header
        view.setUint32(0x00, 0x476C756C, Endian.big);
        view.setUint32(0x04, 0x00030103, Endian.big);

        // Compute and store the correct checksum
        final computed = GlulxHeader.computeChecksum(memory);
        view.setUint32(GlulxHeader.checksumOffset, computed, Endian.big);

        expect(GlulxHeader.verifyChecksum(memory), isTrue);
      });

      test('verifyChecksum returns false for wrong checksum', () {
        final memory = Uint8List(64);
        final view = ByteData.view(memory.buffer);

        // Set magic and version
        view.setUint32(0x00, 0x476C756C, Endian.big);
        view.setUint32(0x04, 0x00030103, Endian.big);

        // Set a wrong checksum
        view.setUint32(GlulxHeader.checksumOffset, 0x12345678, Endian.big);

        expect(GlulxHeader.verifyChecksum(memory), isFalse);
      });

      test('verifyChecksum returns false for short memory', () {
        final memory = Uint8List(10);
        expect(GlulxHeader.verifyChecksum(memory), isFalse);
      });
    });

    group('rawData accessor', () {
      test('returns copy of header bytes', () {
        final data = _createValidHeader();
        final header = GlulxHeader(data);

        expect(header.rawData.length, equals(36));
        expect(header.rawData[0], equals(0x47)); // 'G'
        expect(header.rawData[1], equals(0x6C)); // 'l'
        expect(header.rawData[2], equals(0x75)); // 'u'
        expect(header.rawData[3], equals(0x6C)); // 'l'
      });
    });

    group('Real-world test', () {
      test('monkey.gblorb has valid header', () {
        final gameData = GlulxTestUtils.loadTestGame('assets/games/glulx/monkey.gblorb');
        final header = GlulxHeader(gameData);

        expect(() => header.validate(), returnsNormally, reason: 'monkey.gblorb should have a valid Glulx header.');

        // Basic sanity checks for monkey.gblorb
        expect(header.magicNumber, equals(0x476C756C));
        expect(header.ramStart, isNonZero);
        expect(header.extStart, equals(gameData.length), reason: 'Spec: EXTSTART is the length of the game file.');

        // Version should be in valid range
        expect(header.majorVersion, anyOf(equals(2), equals(3)));
      });

      test('monkey.gblorb checksum is valid', () {
        final gameData = GlulxTestUtils.loadTestGame('assets/games/glulx/monkey.gblorb');

        // Real game files should have valid checksums
        expect(GlulxHeader.verifyChecksum(gameData), isTrue, reason: 'monkey.gblorb should have a valid checksum');
      });
    });
  });
}

/// Creates a valid header with magic number and version set.
Uint8List _createValidHeader() {
  final data = Uint8List(36);
  data.setRange(0, 4, [0x47, 0x6C, 0x75, 0x6C]); // 'Glul'
  data.setRange(4, 8, [0x00, 0x03, 0x01, 0x03]); // Version 3.1.3
  return data;
}
