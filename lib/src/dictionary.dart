import 'package:zart/src/logging.dart';
import 'package:zart/src/z_machine.dart';
import 'package:zart/zart.dart';
import 'package:zart/src/zscii.dart';

/// Represents a dictionary of words used by the game.
class Dictionary {
  /// Initializes a new instance of the [Dictionary] class.
  Dictionary({int? address}) {
    _initDictionary(address);
  }

  bool _isIntialized = false;
  List<String> _entries = <String>[];

  // List of input codes (or separators) found at
  // the header of the dictionary.
  List<String?> _separators = <String>[];

  // Contains the byte length of entries in the dictionary
  late int _entryLength;

  // Starting address of this Dictionary in z memory.
  late int _address;

  // Starting address of the actual dictionary entries, after the header portion.
  late int _entriesStartAddress;

  /// Gets a boolean indicated whether this Dictionary instance is initialized.
  /// Dictionary objects should never be initialized more than once.
  bool get isInitialized => _isIntialized;

  /// Gets the total number of Dictionary entries.
  int get totalEntries => _entries.length;

  /// Gets the number of entry bytes (length) that should be used to scan for entries.
  ///
  /// Versions 1-3 = 4 bytes (6 z characters max)
  /// Versions 4+ = 6 bytes (9 z characters max)
  ///
  /// Word in dictionary may be less than max, in which case it's padded with 5s.
  ///
  /// ### Specification Reference
  /// 13.3
  int get entryBytes {
    if (Z.engine.version == ZMachineVersions.v1 ||
        Z.engine.version == ZMachineVersions.v2 ||
        Z.engine.version == ZMachineVersions.v3) {
      return 4;
    } else {
      return 6;
    }
  }

  // Ref op-code 228 (read)
  // in V1-4 the first byte of the text buffer is reserved
  // in V5+ the first two bytes of the text buffer are reserved
  // the actual text comes after the reserved bytes
  /// Gets the offset of the text buffer.
  int get textBufferOffset {
    if (Z.engine.version == ZMachineVersions.v1 ||
        Z.engine.version == ZMachineVersions.v2 ||
        Z.engine.version == ZMachineVersions.v3 ||
        Z.engine.version == ZMachineVersions.v4) {
      return 1;
    } else {
      return 2;
    }
  }

  /// Gets the character limit (length) that should be used to scan for entries.
  ///
  /// Versions 1-3 = 6 z characters max
  /// Versions 4+ = 9 z characters max
  ///
  /// Word in dictionary may be less than max, in which case it's padded with 5s.
  ///
  /// ### Specification Reference
  /// 13.3
  int get entryCharacterLimit {
    if (Z.engine.version == ZMachineVersions.v1 ||
        Z.engine.version == ZMachineVersions.v2 ||
        Z.engine.version == ZMachineVersions.v3) {
      return 6;
    } else {
      return 9;
    }
  }

  // Loading the input codes "aka separators" into array.
  void _initSeparators() {
    // Ref 13.1 & 13.2
    final totalInputCodeBytes = Z.engine.mem.loadb(_address);
    _separators = List<String?>.filled(
      totalInputCodeBytes,
      null,
      growable: false,
    );

    for (int i = 1; i <= totalInputCodeBytes; i++) {
      _separators[i - 1] = ZSCII.zCharToChar(Z.engine.mem.loadb(_address + i));
    }
  }

  // Initializes the offset address of the dictionary in z memory.
  void _initDictionaryAddress(int? address) {
    if (address != null) {
      //custom dictionary
      _address = address;
    } else {
      _address = Z.engine.mem.loadw(Header.dictionaryAddr);
    }
  }

  // Initializes the dictionary entries
  void _initEntries() {
    _entryLength = Z.engine.mem.loadb(_address + _separators.length + 1);

    if (_entryLength < entryBytes) {
      throw GameException(
        "Entry length found is less than minimum entry bytes required for this game version.  Minimum bytes for this version: $entryBytes.  Found: $_entryLength",
      );
    }

    // Read the 2-byte count of entries
    final entryCount = Z.engine.mem.loadw(_address + _separators.length + 2);

    // Initialize the list with the correct size
    _entries = List<String>.filled(entryCount, "");

    //_entries = ["${Z.engine.mem.loadw(_address + _separators.length + 2)}"];

    _entriesStartAddress = _address + _separators.length + 4;

    for (int i = 0; i < entryCount; i++) {
      _entries[i] = (ZSCII.readZStringAndPop(
        _entriesStartAddress + (i * _entryLength),
      ));
    }
  }

  // Initializes ths Dictionary
  void _initDictionary(int? address) {
    if (_isIntialized) {
      throw GameException("Dictionary already initialized for this game!");
    }

    _initDictionaryAddress(address);

    _initSeparators();

    _initEntries();

    _isIntialized = true;
  }

  // Returns the address of the dictionary entry at [index].
  int _wordAddress(int index) => _entriesStartAddress + (index * _entryLength);

  /// Parses the [tokenizedWords] and looks for matches in this [Dictionary].
  /// [inputTextBuffer] is supplied by op codes that receive
  ///
  /// ### Specification Reference
  /// Section 13.6 - 13.6.3
  ///
  /// The parse table format is specified (buried) in op code 228 definition ("read" op code)
  List<int> parse(List<String> tokenizedWords, String inputTextbuffer) {
    log.fine("parse() Got line: $inputTextbuffer with tokens: $tokenizedWords");

    final parseTable = <int>[];

    // Total tokenized words is byte 1 of the parse table.
    parseTable.add(tokenizedWords.length);

    // Used to index into the inputTextBuffer during parsing
    // and then add to the parseTable
    int textBufferIndex = 0;

    for (final tokenizedWord in tokenizedWords) {
      var searchWord = tokenizedWord;

      if (searchWord.length > entryCharacterLimit) {
        searchWord = searchWord.substring(0, entryCharacterLimit);
        log.fine("parse() is truncating word $tokenizedWord to $searchWord.");
      }

      final wordMatchIndex = _entries.indexOf(searchWord);

      if (wordMatchIndex != -1) {
        final addr = _wordAddress(wordMatchIndex);
        log.fine(
          'parse() (found word: "$tokenizedWord ($searchWord)" in dictionary as "${_entries[wordMatchIndex]}"'
          ' at address 0x${addr.toRadixString(16)}) ${_entries.where((e) => e.startsWith(tokenizedWord[0])).toList()}',
        );

        // byte address of the word in the dictionary
        parseTable.add((addr >> 8) & 0xff);

        parseTable.add(addr & 0xff);

        parseTable.add(tokenizedWord.length);
      } else {
        log.fine(
          'parse() (word: $tokenizedWord ($searchWord) not found in dictionary'
          ' ${_entries.where((e) => e.startsWith(tokenizedWord[0])).toList()})',
        );
        log.fine(
          "parse() entryLength: $_entryLength, word length: ${searchWord.length}",
        );

        // byte address of the word in the dictionary (0 if not found)
        parseTable.add(0);

        parseTable.add(0);

        // number of characters in the word
        parseTable.add(tokenizedWord.length);
      }

      //location in text buffer
      textBufferIndex = inputTextbuffer.indexOf(tokenizedWord, textBufferIndex);

      // Add the location to the parse tabel with the offset
      // base on the engine version (see [textBufferOffset] comments).
      parseTable.add(textBufferIndex + textBufferOffset);

      // Offset the buffer search position for the next go around.
      // Ensures that repeated words in the text buffer are not
      // given the same index.
      textBufferIndex += tokenizedWord.length;
    }

    return parseTable;
  }

  /// Returns a list of words from [line] that is separated by space or game defined separators.
  List<String> tokenize(String line) {
    final tokens = <String>[];
    final s = StringBuffer();

    for (int i = 0; i < line.length; i++) {
      final c = line.substring(i, i + 1);
      //      if (i == line.length - 1){
      //        s.add(c);
      //        tokens.add(s.toString().trim());
      //        s = StringBuffer();
      //      }else
      if (c == ' ' && s.length > 0) {
        tokens.add(s.toString().trim());
        s.clear();
      } else if (Z.engine.mem.dictionary._separators.contains(c)) {
        if (s.length > 0) {
          tokens.add(s.toString().trim());
          s.clear();
        }
        tokens.add(c.trim());
      } else {
        s.write(c);
      }
    }

    if (s.length > 0) {
      tokens.add(s.toString().trim());
    }

    log.fine("Got tokens: $tokens");

    return tokens;
  }

  /// Returns a string representation of the dictionary.
  String dump() {
    var s = StringBuffer();

    s.write('entries: ${_entries.length}\n');
    s.write('separators: $_separators\n');
    s.write('word size: $_entryLength \n');
    s.write('$_entries \n');
    return s.toString();
  }
}
