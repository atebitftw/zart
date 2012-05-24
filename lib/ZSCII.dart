
class ZChar{
  final bool terminatorSet;
  final int z1;
  final int z2;
  final int z3;

  ZChar(int word)
  :
    terminatorSet = ((word >> 15) & 1) == 1,
    z3 = BinaryHelper.bottomBits(word, 5),
    z2 = BinaryHelper.bottomBits(word >> 5, 5),
    z1 = BinaryHelper.bottomBits(word >> 10, 5)
    {
     // print('${word.toRadixString(2)}');
    }

  Collection<int> toCollection() => [z1, z2, z3];

}

/** ZSCII Handler */
class ZSCII {

  static final int A0 = 0;
  static final int A1 = 1;
  static final int A2 = 2;

  static final List<String> V1_TABLE = const
      [
       'abcdefghijklmnopqrstuvwxyz',
       'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
       ' 0123456789.,!?_#\'"/\\<-:()'
       ];
//atere
  static final List<String> DEFAULT_TABLE = const
      [
       'abcdefghijklmnopqrstuvwxyz',
       'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
       '  0123456789.,!?_#\'"/\\-:()'
       ];

  static final int PAD = 5;

  static final Map<String, int> UNICODE_TRANSLATIONS = const
      {
       '155':  0xe4, '156':  0xf6, '157':  0xfc, '158':  0xc4,
       '159':  0xd6, '160':  0xdc, '161':  0xdf, '162':  0xbb,
       '163':  0xab, '164':  0xeb, '165':  0xef, '166':  0xff,
       '167':  0xcb, '168':  0xcf, '169':  0xe1, '170':  0xe9,
       '171':  0xed, '172':  0xf3, '173':  0xfa, '174':  0xfd,
       '175':  0xc1, '176':  0xc9, '177':  0xcd, '178':  0xd3,
       '179':  0xda, '180':  0xdd, '181':  0xe0, '182':  0xe8,
       '183':  0xec, '184':  0xf2, '185':  0xf9, '186':  0xc0,
       '187':  0xc8, '188':  0xcc, '189':  0xd2, '190':  0xd9,
       '191':  0xe2, '192':  0xea, '193':  0xee, '194':  0xf4,
       '195':  0xfb, '196':  0xc2, '197':  0xca, '198':  0xce,
       '199':  0xd4, '200':  0xdb, '201':  0xe5, '202':  0xc5,
       '203':  0xf8, '204':  0xd8, '205':  0xe3, '206':  0xf1,
       '207':  0xf5, '208':  0xc3, '209':  0xd1, '210':  0xd5,
       '211':  0xe6, '212':  0xc6, '213':  0xe7, '214':  0xc7,
       '215':  0xfe, '216':  0xf0, '217':  0xde, '218':  0xd0,
       '219':  0xa3, '220': 0x153, '221':  0x152,'222':  0xa1,
       '223':  0xbf
      };


  /// Reads a string of Z characters and returns
  /// the decoded version.
  static String readZStringAndPop(int fromAddress){
   var result = readZString(fromAddress);
   Z.machine.callStack.pop();
   return result;
  }

  /// Reads a string of Z characters and returns
  /// the decoded version.  Also pushes the address after the
  /// string to the call stack.
  ///
  /// The value MUST be popped off the stack by the caller.
  ///
  ///     Z.callStack.pop();
  static String readZString(int fromAddress){
    bool finished = false;
    var s = new StringBuffer();
    int currentAlphabet = ZSCII.A0;

    List<int> charList = [];

    //first load all the z chars into an array.
    while(!finished){
      ZChar nextz = new ZChar(Z.machine.mem.loadw(fromAddress));

      fromAddress += 2;

      // (ref 3.2)
      if (nextz.terminatorSet) finished = true;

      if (nextz.z1 == 0 && nextz.z1 == 0 && nextz.z3 == 1){
        continue;
      }else{
        charList.addAll(nextz.toCollection());
      }
    }

    Z.machine.callStack.push(fromAddress);

    //print(charList);
    //now decode into output string

   // out('charList: $charList');

    int i = -1;
    while (i < charList.length - 1){
      i++;
      var char = charList[i];

      // (ref 3.3)
      if (char >= 1 && char <= 3){
        //abbreviation lookup
        var abbrNum = (32 * (char - 1)) + charList[++i];

        var abbrAddress =
          2 * Z.machine.mem.loadw(Z.machine.mem.abbrAddress + (abbrNum * 2));

        String abbrString = readZString(abbrAddress);
        Z.machine.callStack.pop();

        s.add(abbrString);

        currentAlphabet = ZSCII.A0;
        continue;
      }

      if (currentAlphabet == ZSCII.A2 && char == 6){
        // (ref 3.4)
        s.add(ZCharToChar((charList[i + 1] << 5) | charList[i + 2]));
        i += 2;
        currentAlphabet = ZSCII.A0;
        continue;
      }

      if (currentAlphabet == ZSCII.A2 && char == 7){
        // (ref 3.5.3)
        //newline
        s.add('\n');
        currentAlphabet = ZSCII.A0;
        continue;
      }

      // (ref 3.5.1)
      if (char == 0){
        s.add(' ');
      }else if (char == 4){
        currentAlphabet = ZSCII.A1;
      }
      else if (char == 5){
        currentAlphabet = ZSCII.A2;
      }
      else {
        var alternateTable = Z.machine.mem.loadw(Header.ALPHABET_TABLE);

        if (Z.machine.version.toInt() >= 5 && alternateTable > 0){
          Debugger.todo('alternate ZSCII table lookup');
        }else{
          s.add(DEFAULT_TABLE[currentAlphabet][char - 6]);
          currentAlphabet = ZSCII.A0;
        }
      }
    }

    return s.toString();
  }

  static List<int> toZCharList(String line){
    var list = new List<int>();

    for(int i = 0; i < line.length; i++){
      list.add(CharToZChar(line.substring(i, i + 1)));
    }
    return list;
  }

  static int CharToZChar(String c){
    if (c.isEmpty() || c.length != 1){
      throw new GameException('String must be length of 1');
    }

    if (c == '\t'){
      return 9;
    }else if (c == '\n'){
      return 13;
    }else{
      var cc = c.charCodeAt(0);
      if (cc >= 32 && cc <= 126){
        return cc;
      }else if (cc >= 155 && cc <= 223){
        return cc;
      }
    }

    throw new GameException('Could not convert from char to ZChar.');
  }

  static String ZCharToChar(int c){
    if(c == 0){
      return '';
    }else if(c == 9){
      return '\t';
    }else if (c == 11){
      return ' ';
    }else if (c == 13){
      return '\n';
    }else if (c >= 32 && c <= 126){
      return new StringBuffer().addCharCode(c).toString();
    }else if (c >= 155 && c <= 223){
      return new StringBuffer().addCharCode(UNICODE_TRANSLATIONS['$c']).toString();
    }

    throw new GameException('Could not convert from ZChar to char.');
  }
}
