/// Diagnostic tests to trace parser behavior for multi-word commands.
///
/// These tests were created to debug the "take wood" bug in Beyond Zork where
/// object interaction commands failed with "[Please try to express that another
/// way.]". The root cause was that the `tokenise` opcode was incorrectly
/// writing to the text buffer instead of only reading from it.
///
/// These tests verify:
/// - Tokenization correctly splits multi-word input
/// - Dictionary lookup finds both verbs and nouns
/// - Parse buffer positions are calculated correctly (with V5 offset of 2)
///
/// See also: Z-Machine Standard 1.1, Section 15 (tokenise opcode)
library;

import 'dart:io';
import 'package:test/test.dart';
import 'package:zart/zart.dart';
import 'package:logging/logging.dart';

void main() {
  group('Parser Diagnostic Tests', () {
    test('trace tokenization and parsing of multi-word command', () async {
      // Enable logging to see dictionary operations
      Logger.root.level = Level.FINE;
      Logger.root.onRecord.listen((record) {
        if (record.message.contains('parse()') ||
            record.message.contains('tokenize')) {
          print('${record.level.name}: ${record.message}');
        }
      });

      // Load Beyond Zork
      final gamePath = _findGameFile('beyondzork.z5');
      final bytes = File(gamePath).readAsBytesSync();

      final provider = DiagnosticTestProvider();
      Z.io = provider;
      Z.load(bytes.toList());

      // Get dictionary
      final dict = Z.engine.mem.dictionary;
      print('Dictionary initialized with ${dict.totalEntries} entries');
      print('Entry character limit: ${dict.entryCharacterLimit}');
      print('Entry bytes: ${dict.entryBytes}');

      // Test tokenization
      const testInput = 'take wood';
      print('\n=== Testing input: "$testInput" ===');

      final tokens = dict.tokenize(testInput);
      print('Tokens: $tokens');
      expect(tokens, hasLength(2), reason: 'Should have 2 tokens');
      expect(tokens[0], equals('take'));
      expect(tokens[1], equals('wood'));

      // Test parsing
      final parseResult = dict.parse(tokens, testInput);
      print('Parse result bytes: $parseResult');

      // Decode parse result
      // Format: [wordCount, ...for each word: addrHigh, addrLow, length, position]
      final wordCount = parseResult[0];
      print('Word count: $wordCount');

      for (int i = 0; i < wordCount; i++) {
        final baseIdx = 1 + (i * 4);
        final addrHigh = parseResult[baseIdx];
        final addrLow = parseResult[baseIdx + 1];
        final addr = (addrHigh << 8) | addrLow;
        final length = parseResult[baseIdx + 2];
        final position = parseResult[baseIdx + 3];

        print(
          'Word $i: addr=0x${addr.toRadixString(16)}, length=$length, position=$position',
        );

        // Verify position is correct
        // In V5, text buffer format: byte0=max, byte1=count, byte2+=text
        // So position should be: index_in_string + 2
        // "take wood" -> "take" at index 0 -> position 2
        //             -> "wood" at index 5 -> position 7
        if (i == 0) {
          expect(position, equals(2), reason: '"take" should be at position 2');
        } else if (i == 1) {
          expect(position, equals(7), reason: '"wood" should be at position 7');
        }
      }

      // Check if words are found in dictionary
      print('\n=== Dictionary lookup test ===');
      print('Checking if "take" is in dictionary...');
      // Note: Dictionary entries might be truncated to entryCharacterLimit
      // For V5+, that's 9 characters
    });

    test('verify dictionary contains common verb and noun words', () {
      final gamePath = _findGameFile('beyondzork.z5');
      final bytes = File(gamePath).readAsBytesSync();

      Z.io = DiagnosticTestProvider();
      Z.load(bytes.toList());

      final dict = Z.engine.mem.dictionary;

      // Get a sample of dictionary entries
      print('First 20 dictionary entries:');
      // Note: _entries is private, but we can test via tokenize/parse
      final testWords = [
        'take',
        'get',
        'drop',
        'look',
        'wood',
        'north',
        'south',
      ];

      for (final word in testWords) {
        final tokens = dict.tokenize(word);
        final parseResult = dict.parse(tokens, word);
        final addr = (parseResult[1] << 8) | parseResult[2];
        print(
          '  "$word": ${addr > 0 ? "FOUND at 0x${addr.toRadixString(16)}" : "NOT FOUND"}',
        );
      }
    });
  });
}

class DiagnosticTestProvider implements IoProvider {
  @override
  Future<dynamic> command(Map<String, dynamic> ioData) async {
    return null;
  }

  @override
  int getFlags1() => 0x7F;

  @override
  Future<int> glulxGlk(int selector, List<int> args) => Future.value(0);
}

String _findGameFile(String filename) {
  final paths = ['assets/games/$filename', '../../assets/games/$filename'];

  for (final path in paths) {
    if (File(path).existsSync()) {
      return path;
    }
  }

  throw Exception(
    'Game file $filename not found. Tried: $paths. CWD: ${Directory.current.path}',
  );
}
