import 'dart:io';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/loaders/tads/t3_header.dart';
import 'package:zart/src/loaders/tads/t3_block.dart';
import 'package:zart/src/loaders/tads/t3_image.dart';
import 'package:zart/src/loaders/tads/t3_exception.dart';

void main() {
  group('T3Header', () {
    test('signature constants are correct', () {
      expect(T3Header.expectedSignature.length, equals(11));
      expect(String.fromCharCodes(T3Header.expectedSignature.sublist(0, 8)), equals('T3-image'));
      expect(T3Header.expectedSignature[8], equals(0x0D)); // \r
      expect(T3Header.expectedSignature[9], equals(0x0A)); // \n
      expect(T3Header.expectedSignature[10], equals(0x1A)); // ^Z
    });

    test('throws on too-short data', () {
      expect(() => T3Header(Uint8List(68)), throwsA(isA<T3Exception>()));
    });

    test('detects invalid signature', () {
      final data = Uint8List(69)..fillRange(0, 69, 0);
      final header = T3Header(data);
      expect(header.hasValidSignature, isFalse);
      expect(() => header.validate(), throwsA(isA<T3Exception>()));
    });

    test('parses valid header from mock data', () {
      final data = Uint8List(69);
      // Set signature
      for (var i = 0; i < T3Header.expectedSignature.length; i++) {
        data[i] = T3Header.expectedSignature[i];
      }
      // Set version = 1 (little-endian)
      data[11] = 0x01;
      data[12] = 0x00;
      // Set timestamp
      final timestamp = 'Mon Jan 01 00:00:00 2024';
      for (var i = 0; i < timestamp.length; i++) {
        data[45 + i] = timestamp.codeUnitAt(i);
      }

      final header = T3Header(data);
      expect(header.hasValidSignature, isTrue);
      expect(header.version, equals(1));
      expect(header.timestamp, equals(timestamp));
      expect(() => header.validate(), returnsNormally);
    });
  });

  group('T3Block', () {
    test('parses block header correctly', () {
      final data = Uint8List(20);
      // Type = "ENTP"
      data[0] = 0x45; // E
      data[1] = 0x4E; // N
      data[2] = 0x54; // T
      data[3] = 0x50; // P
      // Size = 16 (little-endian)
      data[4] = 0x10;
      data[5] = 0x00;
      data[6] = 0x00;
      data[7] = 0x00;
      // Flags = 1 (mandatory)
      data[8] = 0x01;
      data[9] = 0x00;

      final block = T3Block.parseHeader(data, 0, 100);
      expect(block.type, equals('ENTP'));
      expect(block.dataSize, equals(16));
      expect(block.flags, equals(1));
      expect(block.isMandatory, isTrue);
      expect(block.dataOffset, equals(110)); // 100 + headerSize(10)
    });

    test('EOF block detection', () {
      final data = Uint8List(10);
      data[0] = 0x45; // E
      data[1] = 0x4F; // O
      data[2] = 0x46; // F
      data[3] = 0x20; // (space)
      // Size = 0
      // Flags = 0

      final block = T3Block.parseHeader(data, 0, 0);
      expect(block.type, equals('EOF '));
      expect(block.isEof, isTrue);
    });
  });

  group('T3Image with AllHope.t3', () {
    late Uint8List gameData;

    setUpAll(() {
      final paths = ['assets/games/tads/AllHope.t3', '../../assets/games/tads/AllHope.t3'];
      for (final path in paths) {
        if (File(path).existsSync()) {
          gameData = File(path).readAsBytesSync();
          return;
        }
      }
      throw Exception('AllHope.t3 not found');
    });

    test('loads and validates header', () {
      final image = T3Image(gameData);
      expect(image.header.hasValidSignature, isTrue);
      expect(image.header.version, equals(1));
      expect(image.header.timestamp.isNotEmpty, isTrue);
      expect(() => image.validate(), returnsNormally);

      print('T3 Header:');
      print('  Version: ${image.header.version}');
      print('  Timestamp: ${image.header.timestamp}');
    });

    test('enumerates blocks', () {
      final image = T3Image(gameData);
      expect(image.blocks.isNotEmpty, isTrue);

      print('T3 Blocks (${image.blockCount} total):');
      for (final block in image.blocks.take(20)) {
        print('  ${block.type}: size=${block.dataSize}, mandatory=${block.isMandatory}');
      }
      if (image.blockCount > 20) {
        print('  ... (${image.blockCount - 20} more blocks)');
      }
    });

    test('first block is ENTP (entrypoint)', () {
      final image = T3Image(gameData);
      // First meaningful block should be ENTP
      final firstBlock = image.blocks.first;
      expect(firstBlock.type, equals('ENTP'));
    });

    test('has EOF block', () {
      final image = T3Image(gameData);
      final eofBlock = image.blocks.last;
      expect(eofBlock.isEof, isTrue);
    });

    test('can find specific block types', () {
      final image = T3Image(gameData);

      // Should have entrypoint block
      expect(image.entrypointBlock, isNotNull);
      expect(image.entrypointBlock!.type, equals('ENTP'));

      // Should have constant pool blocks
      final cpdfBlocks = image.findBlocks(T3Block.typeConstPoolDef);
      print('Found ${cpdfBlocks.length} CPDF blocks');

      final cppgBlocks = image.findBlocks(T3Block.typeConstPoolPage);
      print('Found ${cppgBlocks.length} CPPG blocks');
    });

    test('can read block data', () {
      final image = T3Image(gameData);
      final entryBlock = image.entrypointBlock!;
      final data = image.getBlockData(entryBlock);

      expect(data.length, equals(entryBlock.dataSize));
      print('ENTP block data: ${data.take(20).toList()}...');
    });
  });
}
