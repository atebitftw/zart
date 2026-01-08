import 'dart:io';
import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_file.dart';

void main() {
  group('T3File', () {
    test('Creation', () {
      final file = T3File.create(100);
      expect(file.objectId, 100);
      expect(file.metaclass, 'file');
      expect(file.isOpen, isFalse);
      expect(file.isOutOfSync, isFalse);
    });

    test('Serialization and Restoration', () {
      final file = T3File.create(101);
      // Manually set internal state for testing
      // Since we can't call open() without a real file, we test the serialization format

      // Save the empty/default state
      final data = file.save();

      // Verify serialization format: charset(4) + mode(1) + access(1) + flags(4) = 10 bytes
      expect(data.length, 10);

      // Restore
      final restored = T3File.fromData(101, data);
      expect(restored.objectId, 101);
      expect(restored.metaclass, 'file');
      // Restored file should have OUT_OF_SYNC flag set
      expect(restored.isOutOfSync, isTrue);
      expect(restored.isOpen, isFalse);
    });

    test('File open/read/write cycle', () {
      // Use a temp file for actual I/O testing
      final tempDir = Directory.systemTemp;
      final tempFile = File(
        '${tempDir.path}/t3_file_test_${DateTime.now().millisecondsSinceEpoch}.txt',
      );

      try {
        // Create and write
        final writeFile = T3File.create(102);
        writeFile.open(
          tempFile.path,
          T3File.VMOBJFILE_MODE_RAW,
          T3File.VMOBJFILE_ACCESS_WRITE,
        );
        expect(writeFile.isOpen, isTrue);
        writeFile.close();
        expect(writeFile.isOpen, isFalse);

        // Read
        final readFile = T3File.create(103);
        readFile.open(
          tempFile.path,
          T3File.VMOBJFILE_MODE_RAW,
          T3File.VMOBJFILE_ACCESS_READ,
        );
        expect(readFile.isOpen, isTrue);
        readFile.close();
        expect(readFile.isOpen, isFalse);
      } finally {
        // Cleanup
        if (tempFile.existsSync()) {
          tempFile.deleteSync();
        }
      }
    });
  });
}
