import 'package:zart/header.dart';
import 'package:zart/mixins/loggable.dart';
import 'package:zart/z_machine.dart';
import 'package:zart/zart.dart';
import 'package:zart/zscii.dart';

class Dictionary with Loggable {
  final List<String> entries;
  final List<String> separators;
  int entryLength;

  int get encodedTextBytes => Z.engine.version == ZVersion.S ||
          Z.engine.version == ZVersion.V1 ||
          Z.engine.version == ZVersion.V2 ||
          Z.engine.version == ZVersion.V3
      ? 4
      : 6;

  int _address;

  Dictionary({int address})
      : entries = List<String>(),
        separators = List<String>() {
    logName = "Dictionary";

    if (address != null) {
      //custom dictionary
      _address = address;
    } else {
      _address = Z.engine.mem.loadw(Header.DICTIONARY_ADDR);
    }

    assert(_address != null);

    _initDictionary();
  }

  void _initDictionary() {
    var iCodes = Z.engine.mem.loadb(_address);

    for (int i = 1; i <= iCodes; i++) {
      separators.add(ZSCII.ZCharToChar(Z.engine.mem.loadb(_address + i)));
    }

    entryLength = Z.engine.mem.loadb(_address + separators.length + 1);

    final numEntries = Z.engine.mem.loadw(_address + separators.length + 2);

    final start = _address + separators.length + 4;

    for (int i = 0; i < numEntries; i++) {
      entries.add(ZSCII.readZStringAndPop(start + (i * entryLength)));
    }
  }

  int _wordAddress(int index) {
    var addr = _address + separators.length + 4 + (index * entryLength);
    return addr;
  }

  List<int> parse(List<String> tokenizedList, String line) {
    log.fine("got line: $line");
    var parseTable = List<int>();

    parseTable.add(tokenizedList.length);

    int lastIndex = 0;

    for (final t in tokenizedList) {
      var word = t;

      if (word.length > entryLength) {
        word = word.substring(0, entryLength);
        log.fine("Truncating word $t to $word.");
      }

      var idx = entries.indexOf(word);

      if (idx != -1) {
        var addr = _wordAddress(idx);
        log.fine(
            '(found word: "${t}" in dictionary as "${entries[idx]}" at address 0x${addr.toRadixString(16)})');
        parseTable.add((addr >> 8) & 0xff);
        parseTable.add(addr & 0xff);

        //word length
        parseTable.add(word.length);
      } else {
        log.warning(
            '(word: ${t} not found in dictionary ${entries.where((e) => e.startsWith(t[0])).toList()})');
        log.warning("entryLength: $entryLength, word length: ${word.length}");
        //log.warning('(word: ${t} not found in dictionary ${entries})');
        parseTable.add(0);
        parseTable.add(0);
        parseTable.add(word.length);
      }

      //location in text buffer
      lastIndex = line.indexOf(t, lastIndex);
      parseTable.add(lastIndex + 2);
      // parseTable.add(lastIndex + 1);
      lastIndex += t.length;
    }

    return parseTable;
  }

  List<String> tokenize(String line) {
    var tokens = List<String>();

    var s = StringBuffer();

    for (int i = 0; i < line.length; i++) {
      var c = line.substring(i, i + 1);
//      if (i == line.length - 1){
//        s.add(c);
//        tokens.add(s.toString().trim());
//        s = StringBuffer();
//      }else
      if (c == ' ' && s.length > 0) {
        tokens.add(s.toString().trim());
        s.clear();
      } else if (Z.engine.mem.dictionary.separators.indexOf(c) != -1) {
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

    log.fine("got tokens: $tokens");

    return tokens;
  }

  String dump() {
    var s = StringBuffer();

    s.write('entries: ${entries.length}\n');
    s.write('separators: ${separators}\n');
    s.write('word size: $entryLength \n');
    s.write('$entries \n');
    return s.toString();
  }
}
