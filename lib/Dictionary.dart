
class Dictionary {
  final List<String> entries;
  final List<String> separators;
  int wordSize;

  int _address;

  Dictionary([int address])
  :
    entries = new List<String>(),
    separators = new List<String>()
  {
    _address = Z.machine.mem.loadw(Header.DICTIONARY_ADDR);

    if (address != null){
      //custom dictionary
      _address = address;
    }

    assert(_address != null);

    _initDictionary();
  }

  void _initDictionary(){
    var iCodes = Z.machine.mem.loadb(_address);

    for(int i = 1; i <= iCodes; i++){
      separators.add(ZSCII.ZCharToChar(Z.machine.mem.loadb(_address + i)));
    }

    wordSize =
        Z.machine.mem.loadb(_address + separators.length + 1);

    var numEntries =
        Z.machine.mem.loadw(_address + separators.length + 2);

    var start = _address + separators.length + 4;


    for(int i = 1; i <= numEntries; i++){
      entries.add(ZSCII.readZStringAndPop(start + ((i - 1) * wordSize)));
    }
  }

  List<int> parse(List<String> tokenizedList, String line){
    var parseTable = new List<int>();

    parseTable.add(tokenizedList.length);

    int wordAddress(int index) {
      var addr = _address + separators.length + 4 + (index * wordSize);
      Debugger.verbose('>>> ${ZSCII.readZStringAndPop(addr)}');
      return addr;
    }
    int lastIndex = 0;

    for(final t in tokenizedList){
      var word = t;
      if (word.length > 6){
        word = word.substring(0, 6);
      }

      var idx = entries.indexOf(word);

      if (idx != -1){
        var addr = wordAddress(idx);
        Debugger.verbose('    (found word: "${t}" in dictionary as "${entries[idx]}" at address 0x${addr.toRadixString(16)})');
        parseTable.add((addr >> 8) & 0xff);
        parseTable.add(addr & 0xff);

        //word length
        parseTable.add(t.length);

      }else{
        Debugger.verbose('    (word: ${t} not found in dictionary)');
        parseTable.add(0);
        parseTable.add(0);
        parseTable.add(t.length);
      }

      //location in text buffer
      lastIndex = line.indexOf(t, lastIndex);
      parseTable.add(lastIndex + 1);
      lastIndex += t.length;
    }

    return parseTable;
  }

  List<String> tokenize(String line){
    var tokens = new List<String>();

    var s = new StringBuffer();

    for(int i = 0; i < line.length; i++){
      var c = line.substring(i, i+1);
//      if (i == line.length - 1){
//        s.add(c);
//        tokens.add(s.toString().trim());
//        s = new StringBuffer();
//      }else
        if (c == ' ' && s.length > 0){
        tokens.add(s.toString().trim());
        s = new StringBuffer();
      }else if (Z.machine.mem.dictionary.separators.indexOf(c) != -1){
        if (s.length > 0){
          tokens.add(s.toString().trim());
          s = new StringBuffer();
        }
        tokens.add(c.trim());
      }
      else{
        s.add(c);
      }
    }

    if (s.length > 0){
      tokens.add(s.toString().trim());
    }

    return tokens;
  }

  String dump(){
    var s = new StringBuffer();

    s.add('entries: ${entries.length}\n');
    s.add('separators: ${separators}\n');
    s.add('word size: $wordSize \n');
    s.add('$entries \n');
    return s.toString();
  }
}
