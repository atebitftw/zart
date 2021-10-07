import 'package:zart/game_exception.dart';
import 'package:zart/header.dart';
import 'package:zart/z_char.dart';
import 'package:zart/z_machine.dart';
import 'package:zart/zart.dart';
import 'package:zart/mixins/loggable.dart';

typedef ZStringReader = String Function(int fromAddress, [bool abbreviationLookup]);

//ref 3.2.2
const char2AlphabetShift = <int, int>{
  ZSCII.a0: ZSCII.a1,
  ZSCII.a1: ZSCII.a2,
  ZSCII.a2: ZSCII.a0,
};

//ref 3.2.2
const char3AlphabetShift = <int, int>{
  ZSCII.a0: ZSCII.a2,
  ZSCII.a1: ZSCII.a0,
  ZSCII.a2: ZSCII.a1,
};

/// ZSCII Handler */
class ZSCII with Loggable {
  ZSCII() {
    logName = "ZSCII";
  }

  static const int a0 = 0;
  static const int a1 = 1;
  static const int a2 = 2;

  static const List<String> defaultTable = [
    'abcdefghijklmnopqrstuvwxyz',
    'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
    // The first space in A2 (below): Z-character 6 from A2 means that the two subsequent Z-characters specify a ten-bit
    // ZSCII character code: the next Z-character gives the top 5 bits and the one after the bottom 5.
    //
    // The second space represents a newline character and is handled in .readZString() below.
    // ignore: unnecessary_string_escapes
    '  0123456789.,!?_#\'\"/\\-:()',
  ];

  static const List<String> v1Table = [
    'abcdefghijklmnopqrstuvwxyz',
    'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
    // In V1 of engine, the newline is not used and instead "<" is available in A2 (below)
    // ignore: unnecessary_string_escapes
    ' 0123456789.,!?_#\'\"/\\<-:()',
  ];

  /// Represents the padding value for ZString encoding/decoding.
  static const int padding = 5;

  static const Map<zMachineVersions, String Function(int, [bool])> _stringReaderMap = <zMachineVersions, ZStringReader>{
    zMachineVersions.v1: _readZStringVersion1And2,
    zMachineVersions.v2: _readZStringVersion1And2,
    zMachineVersions.v3: _readZStringVersion3and4,
    zMachineVersions.v4: _readZStringVersion3and4,
    zMachineVersions.v5: _readZStringVersion5AndUp,
    zMachineVersions.v6: _readZStringVersion5AndUp,
    zMachineVersions.v7: _readZStringVersion5AndUp,
    zMachineVersions.v8: _readZStringVersion5AndUp,
  };

  static String _readZStringVersion1And2(int? fromAddress, [bool? abbreviationLookup = false]) {
    bool finished = false;
    bool shiftLock = false;
    final s = StringBuffer();
    int? previousAlphabet = ZSCII.a0;
    int? currentAlphabet = ZSCII.a0;

    List<int> charList = [];

    //first load all the z chars into an array.
    while (!finished) {
      ZChar nextz = ZChar(Z.engine.mem.loadw(fromAddress!));

      fromAddress += 2;

      // (ref 3.2)
      if (nextz.terminatorSet) finished = true;

      if (nextz.z1 == 0 && nextz.z1 == 0 && nextz.z3 == 1) {
        continue;
      } else {
        charList.addAll(nextz.toCollection());
      }
    }

    Z.engine.callStack.push(fromAddress!);

    int i = -1;
    while (i < charList.length - 1) {
      i++;
      var char = charList[i];

      // (ref 3.3)
      if (Z.engine.version == zMachineVersions.v2 && char == 1) {
        if (abbreviationLookup!) {
          throw GameException("Abbreviation lookup cannot occur inside an abbreviation lookup.");
        }
        //abbreviation lookup, v2 only ref 3.3
        final abbrNum = (32 * (char - 1)) + charList[++i];

        final abbrAddress = 2 * Z.engine.mem.loadw(Z.engine.mem.abbrAddress + (abbrNum * 2));

        final abbrString = readZString(abbrAddress, true);
        Z.engine.callStack.pop();

        s.write(abbrString);

        // ref 3.2.3
        if (!shiftLock) currentAlphabet = currentAlphabet;

        continue;
      }

      // ref 3.2.2
      if (char >= 2 && char <= 5) {
        // shift alphabet based on char

        if (char == 2 || char == 4) {
          previousAlphabet = currentAlphabet;
          currentAlphabet = char2AlphabetShift[currentAlphabet!];
          shiftLock = char == 4;

          if (shiftLock) {
            previousAlphabet = currentAlphabet;
          }

          continue;
        }

        if (char == 3 || char == 5) {
          previousAlphabet = currentAlphabet;
          currentAlphabet = char3AlphabetShift[currentAlphabet!];
          shiftLock = char == 5;

          if (shiftLock) {
            previousAlphabet = currentAlphabet;
          }

          continue;
        }

        throw GameException("readZString() Expected char between 2 and 5 (inclusive), but found $char");
      }

      // Z-character 6 from A2 means that the two subsequent Z-characters specify a ten-bit
      // ZSCII character code: the next Z-character gives the top 5 bits and the one after the bottom 5.
      if (currentAlphabet == ZSCII.a2 && char == 6) {
        // (ref 3.4)
        s.write(zCharToChar((charList[i + 1] << 5) | charList[i + 2]));
        i += 2;
        if (!shiftLock) currentAlphabet = previousAlphabet;
        continue;
      }

      // Z-char 1 in Version 1 is a newline.  ref 3.5.2
      if (Z.engine.version == zMachineVersions.v1 && char == 1) {
        s.write('\n');
        if (!shiftLock) currentAlphabet = previousAlphabet;
        continue;
      }

      // Z-char 7 from A2 means newline (except for engine version 1)
      if (Z.engine.version != zMachineVersions.v1 && currentAlphabet == ZSCII.a2 && char == 7) {
        // (ref 3.5.3)
        //newline
        s.write('\n');
        currentAlphabet = ZSCII.a0;
        continue;
      }

      if (char == 0) {
        // (ref 3.5.1)
        s.write(' ');
        if (!shiftLock) currentAlphabet = previousAlphabet;
      } else {
        if (Z.engine.version == zMachineVersions.v1 && currentAlphabet == a2) {
          s.write(v1Table[currentAlphabet!][char - 6]);
        } else {
          s.write(defaultTable[currentAlphabet!][char - 6]);
        }
        if (!shiftLock) currentAlphabet = previousAlphabet;
      }
    }

    return s.toString();
  }

  static String _readZStringVersion3and4(int? fromAddress, [bool? abbreviationLookup = false]) {
    bool finished = false;
    final s = StringBuffer();
    int currentAlphabet = ZSCII.a0;

    List<int> charList = [];

    //first load all the z chars into an array.
    while (!finished) {
      ZChar nextz = ZChar(Z.engine.mem.loadw(fromAddress!));

      fromAddress += 2;

      // (ref 3.2)
      if (nextz.terminatorSet) finished = true;

      if (nextz.z1 == 0 && nextz.z1 == 0 && nextz.z3 == 1) {
        continue;
      } else {
        charList.addAll(nextz.toCollection());
      }
    }

    Z.engine.callStack.push(fromAddress!);

    int i = -1;
    while (i < charList.length - 1) {
      i++;
      var char = charList[i];

      // (ref 3.3)
      if (char >= 1 && char <= 3) {
        if (abbreviationLookup!) {
          throw GameException("Abbreviation lookup cannot occur inside an abbreviation lookup.");
        }
        //abbreviation lookup
        final abbrNum = (32 * (char - 1)) + charList[++i];

        final abbrAddress = 2 * Z.engine.mem.loadw(Z.engine.mem.abbrAddress + (abbrNum * 2));

        final abbrString = readZString(abbrAddress, true);
        Z.engine.callStack.pop();

        s.write(abbrString);

        // ref 3.2.3
        currentAlphabet = ZSCII.a0;

        continue;
      }

      // Z-character 6 from A2 means that the two subsequent Z-characters specify a ten-bit
      // ZSCII character code: the next Z-character gives the top 5 bits and the one after the bottom 5.
      if (currentAlphabet == ZSCII.a2 && char == 6) {
        // (ref 3.4)
        s.write(zCharToChar((charList[i + 1] << 5) | charList[i + 2]));
        i += 2;
        currentAlphabet = ZSCII.a0;
        continue;
      }

      // Z-char 7 from A2 means newline (except for engine version 1)
      if (currentAlphabet == ZSCII.a2 && char == 7) {
        // (ref 3.5.3)
        //newline
        s.write('\n');
        currentAlphabet = ZSCII.a0;
        continue;
      }

      if (char == 0) {
        // (ref 3.5.1)
        s.write(' ');
        currentAlphabet = ZSCII.a0;
      } else if (char == 4) {
        currentAlphabet = ZSCII.a1;
      } else if (char == 5) {
        currentAlphabet = ZSCII.a2;
      } else {
        s.write(defaultTable[currentAlphabet][char - 6]);
        currentAlphabet = ZSCII.a0;
      }
    }
    return s.toString();
  }

  static String _readZStringVersion5AndUp(int? fromAddress, [bool? abbreviationLookup = false]) {
    //TODO support custom alphabet table
    //TODO support custom unicode table
    bool finished = false;
    final s = StringBuffer();
    int currentAlphabet = ZSCII.a0;

    List<int> charList = [];

    //first load all the z chars into an array.
    while (!finished) {
      final nextz = ZChar(Z.engine.mem.loadw(fromAddress!));

      fromAddress += 2;

      // (ref 3.2)
      if (nextz.terminatorSet) finished = true;

      if (nextz.z1 == 0 && nextz.z1 == 0 && nextz.z3 == 1) {
        continue;
      } else {
        charList.addAll(nextz.toCollection());
      }
    }

    Z.engine.callStack.push(fromAddress!);

    int i = -1;
    while (i < charList.length - 1) {
      i++;
      var char = charList[i];

      // (ref 3.3)
      if (char >= 1 && char <= 3) {
        if (abbreviationLookup!) {
          throw GameException("Abbreviation lookup cannot occur inside an abbreviation lookup.");
        }
        //abbreviation lookup
        var abbrNum = (32 * (char - 1)) + charList[++i];

        var abbrAddress = 2 * Z.engine.mem.loadw(Z.engine.mem.abbrAddress + (abbrNum * 2));

        String abbrString = readZString(abbrAddress, true);
        Z.engine.callStack.pop();

        s.write(abbrString);

        // ref 3.2.3
        currentAlphabet = ZSCII.a0;

        continue;
      }

      // Z-character 6 from A2 means that the two subsequent Z-characters specify a ten-bit
      // ZSCII character code: the next Z-character gives the top 5 bits and the one after the bottom 5.
      if (currentAlphabet == ZSCII.a2 && char == 6) {
        // (ref 3.4)
        s.write(zCharToChar((charList[i + 1] << 5) | charList[i + 2]));
        i += 2;
        currentAlphabet = ZSCII.a0;
        continue;
      }

      // Z-char 7 from A2 means newline (except for engine version 1)
      if (currentAlphabet == ZSCII.a2 && char == 7) {
        // (ref 3.5.3)
        //newline
        s.write('\n');
        currentAlphabet = ZSCII.a0;
        continue;
      }

      if (char == 0) {
        // (ref 3.5.1)
        s.write(' ');
        currentAlphabet = ZSCII.a0;
      } else if (char == 4) {
        currentAlphabet = ZSCII.a1;
      } else if (char == 5) {
        currentAlphabet = ZSCII.a2;
      } else {
        var alternateTable = Z.engine.mem.loadw(Header.alphabetTable);

        if (alternateTable > 0) {
          throw GameException("oops need to implement alternate ZSCII table lookup here");
        } else {
          if (Z.engine.version == zMachineVersions.v1 && currentAlphabet == a2) {
            s.write(v1Table[currentAlphabet][char - 6]);
            continue;
          }
          s.write(defaultTable[currentAlphabet][char - 6]);
          currentAlphabet = ZSCII.a0;
        }
      }
    }

    return s.toString();
  }

  /// Reads a string of Z characters and returns
  /// the decoded version.
  ///
  /// Automatically pops the stack after the read is finished.
  /// this is equivalent to:
  ///
  /// ```
  /// ZSCII.readZString(startingAtSomeAddress);
  /// Z.callStack.pop();
  /// ```
  static String readZStringAndPop(int fromAddress) {
    var result = readZString(fromAddress);
    Z.engine.callStack.pop();
    return result;
  }

  /// Reads a string of Z characters and returns
  /// the decoded version.  Also pushes the address after the
  /// string to the call stack.
  ///
  /// The value MUST be popped off the stack by the caller:
  ///
  /// ### Example
  /// ```
  /// ZSCII.readZString(startingAtSomeAddress);
  /// Z.callStack.pop();
  /// ```
  ///
  /// Call [ZSCII.readZStringAndPop(...)] if you want the pop
  /// to happen automatically after the read.
  static String readZString(int fromAddress, [bool abbreviationLookup = false]) {
    final str = _stringReaderMap[Z.engine.version]!(fromAddress, abbreviationLookup);
    //print("Read string (abbreviation lookup? $abbreviationLookup): $str");
    return str;
  }

  /// Converts [line] to a equivalent array of Z-Characters.
  static List<int> toZCharList(String line) {
    var list = <int>[];

    for (int i = 0; i < line.length; i++) {
      list.add(charToZChar(line[i]));
    }
    return list;
  }

  /// Converts char [c] into an equivalent Z-Character.
  static int charToZChar(String c) {
    if (c.isEmpty || c.length != 1) {
      throw GameException('String must be length of 1.  Found ${c.length} in $c.');
    }

    if (c == '\t') {
      return 9;
    } else if (c == '\n') {
      return 13;
    } else {
      final cc = c.codeUnitAt(0);
      if (cc >= 32 && cc <= 126) {
        return cc;
      } else if (cc >= 155 && cc <= 223) {
        return cc;
      }
    }

    throw GameException('Could not convert from char to ZChar.');
  }

  static String zCharToChar(int c) {
    final s = StringBuffer();
    if (c == 0) {
      return '';
    } else if (c == 9) {
      //version 6 only but it's okay to be relaxed here.
      return '\t';
    } else if (c == 11) {
      //version 6 only but it's okay to be relaxed here.
      return "  ";
    } else if (c == 13) {
      return '\n';
    } else if (c >= 32 && c <= 126) {
      s.writeCharCode(c);
      return s.toString();
    } else if (c >= 155 && c <= 223) {
      s.writeCharCode(unicodeTranslations[c]!);
      return s.toString();
    }

    return '';
  }
}

const Map<int, int> unicodeTranslations = {
  155: 0xe4,
  156: 0xf6,
  157: 0xfc,
  158: 0xc4,
  159: 0xd6,
  160: 0xdc,
  161: 0xdf,
  162: 0xbb,
  163: 0xab,
  164: 0xeb,
  165: 0xef,
  166: 0xff,
  167: 0xcb,
  168: 0xcf,
  169: 0xe1,
  170: 0xe9,
  171: 0xed,
  172: 0xf3,
  173: 0xfa,
  174: 0xfd,
  175: 0xc1,
  176: 0xc9,
  177: 0xcd,
  178: 0xd3,
  179: 0xda,
  180: 0xdd,
  181: 0xe0,
  182: 0xe8,
  183: 0xec,
  184: 0xf2,
  185: 0xf9,
  186: 0xc0,
  187: 0xc8,
  188: 0xcc,
  189: 0xd2,
  190: 0xd9,
  191: 0xe2,
  192: 0xea,
  193: 0xee,
  194: 0xf4,
  195: 0xfb,
  196: 0xc2,
  197: 0xca,
  198: 0xce,
  199: 0xd4,
  200: 0xdb,
  201: 0xe5,
  202: 0xc5,
  203: 0xf8,
  204: 0xd8,
  205: 0xe3,
  206: 0xf1,
  207: 0xf5,
  208: 0xc3,
  209: 0xd1,
  210: 0xd5,
  211: 0xe6,
  212: 0xc6,
  213: 0xe7,
  214: 0xc7,
  215: 0xfe,
  216: 0xf0,
  217: 0xde,
  218: 0xd0,
  219: 0xa3,
  220: 0x153,
  221: 0x152,
  222: 0xa1,
  223: 0xbf
};
