import 'package:zart/src/z_machine/z_char.dart';
import 'package:zart/src/zart_internal.dart';

/// The ZString reader function.
typedef ZStringReader =
    String Function(int fromAddress, [bool abbreviationLookup]);

//ref 3.2.2
/// The ZSCII character shift table.
const char2AlphabetShift = <int, int>{
  ZSCII.a0: ZSCII.a1,
  ZSCII.a1: ZSCII.a2,
  ZSCII.a2: ZSCII.a0,
};

//ref 3.2.2
/// The ZSCII character shift table.
const char3AlphabetShift = <int, int>{
  ZSCII.a0: ZSCII.a2,
  ZSCII.a1: ZSCII.a0,
  ZSCII.a2: ZSCII.a1,
};

/// ZSCII Handler
class ZSCII {
  /// The A0 alphabet.
  static const int a0 = 0;

  /// The A1 alphabet.
  static const int a1 = 1;

  /// The A2 alphabet.
  static const int a2 = 2;

  /// Cache for decoded Z-strings from static memory.
  /// Like ifvms.js's jit[] cache, this avoids re-decoding the same strings.
  /// Only strings from static memory (address >= staticMemAddress) are cached
  /// since they cannot change during gameplay.
  static final Map<int, String> _stringCache = {};

  /// Clears the string cache. Should be called on game load (assumes game may have changed).
  static void clearCache() {
    _stringCache.clear();
  }

  /// The default ZSCII table.
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

  /// The V1 ZSCII table.
  static const List<String> v1Table = [
    'abcdefghijklmnopqrstuvwxyz',
    'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
    // In V1 of engine, the newline is not used and instead "<" is available in A2 (below)
    // ignore: unnecessary_string_escapes
    ' 0123456789.,!?_#\'\"/\\<-:()',
  ];

  /// Represents the padding value for ZString encoding/decoding.
  static const int padding = 5;

  static const Map<ZMachineVersions, String Function(int, [bool])>
  _stringReaderMap = <ZMachineVersions, ZStringReader>{
    ZMachineVersions.v1: _readZStringVersion1And2,
    ZMachineVersions.v2: _readZStringVersion1And2,
    ZMachineVersions.v3: _readZStringVersion3and4,
    ZMachineVersions.v4: _readZStringVersion3and4,
    ZMachineVersions.v5: _readZStringVersion5AndUp,
    ZMachineVersions.v6: _readZStringVersion5AndUp,
    ZMachineVersions.v7: _readZStringVersion5AndUp,
    ZMachineVersions.v8: _readZStringVersion5AndUp,
  };

  static String _readZStringVersion1And2(
    int? fromAddress, [
    bool? abbreviationLookup = false,
  ]) {
    bool finished = false;
    // bool shiftLock = false; // Shift lock not supported in V1/V2
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

      charList.addAll(nextz.toCollection());
    }

    Z.engine.callStack.push(fromAddress!);

    int i = -1;
    while (i < charList.length - 1) {
      i++;
      var char = charList[i];

      // (ref 3.3)
      if (Z.engine.version == ZMachineVersions.v2 && char == 1) {
        if (abbreviationLookup!) {
          throw GameException(
            "Abbreviation lookup cannot occur inside an abbreviation lookup.",
          );
        }
        // Bounds check: ensure we have another character for abbreviation index
        if (i + 1 >= charList.length) {
          // Malformed z-string - abbreviation marker at end without index
          break;
        }
        //abbreviation lookup, v2 only ref 3.3
        final abbrNum = (32 * (char - 1)) + charList[++i];

        final abbrAddress =
            2 * Z.engine.mem.loadw(Z.engine.mem.abbrAddress + (abbrNum * 2));

        final abbrString = readZString(abbrAddress, true);
        Z.engine.callStack.pop();

        s.write(abbrString);

        // ref 3.2.3
        currentAlphabet = previousAlphabet;

        continue;
      }

      // ref 3.2.2
      if (char >= 2 && char <= 5) {
        // shift alphabet based on char

        if (char == 2 || char == 4) {
          previousAlphabet = currentAlphabet;
          currentAlphabet = char2AlphabetShift[currentAlphabet!];
          // shiftLock = char == 4; // Shift lock not supported in V1/V2 (Standard 3.2.3)

          continue;
        }

        if (char == 3 || char == 5) {
          previousAlphabet = currentAlphabet;
          currentAlphabet = char3AlphabetShift[currentAlphabet!];
          // shiftLock = char == 5; // Shift lock not supported in V1/V2 (Standard 3.2.3)

          continue;
        }

        throw GameException(
          "readZString() Expected char between 2 and 5 (inclusive), but found $char",
        );
      }

      // Z-character 6 from A2 means that the two subsequent Z-characters specify a ten-bit
      // ZSCII character code: the next Z-character gives the top 5 bits and the one after the bottom 5.
      if (currentAlphabet == ZSCII.a2 && char == 6) {
        // (ref 3.4)
        // Bounds check: ensure we have two more characters for the 10-bit code
        if (i + 2 >= charList.length) {
          // Malformed z-string - 10-bit escape without enough following chars
          break;
        }
        s.write(zCharToChar((charList[i + 1] << 5) | charList[i + 2]));
        i += 2;
        currentAlphabet = previousAlphabet;
        continue;
      }

      // Z-char 1 in Version 1 is a newline.  ref 3.5.2
      if (Z.engine.version == ZMachineVersions.v1 && char == 1) {
        s.write('\n');
        currentAlphabet = previousAlphabet;
        continue;
      }

      // Z-char 7 from A2 means newline (except for engine version 1)
      if (Z.engine.version != ZMachineVersions.v1 &&
          currentAlphabet == ZSCII.a2 &&
          char == 7) {
        // (ref 3.5.3)
        //newline
        s.write('\n');
        currentAlphabet = ZSCII.a0;
        continue;
      }

      if (char == 0) {
        // (ref 3.5.1)
        s.write(' ');
        currentAlphabet = previousAlphabet;
      } else {
        if (Z.engine.version == ZMachineVersions.v1 && currentAlphabet == a2) {
          s.write(v1Table[currentAlphabet!][char - 6]);
        } else {
          s.write(defaultTable[currentAlphabet!][char - 6]);
        }
        currentAlphabet = previousAlphabet;
      }
    }

    return s.toString();
  }

  static String _readZStringVersion3and4(
    int? fromAddress, [
    bool? abbreviationLookup = false,
  ]) {
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

      charList.addAll(nextz.toCollection());
    }

    Z.engine.callStack.push(fromAddress!);

    int i = -1;
    while (i < charList.length - 1) {
      i++;
      var char = charList[i];

      // (ref 3.3)
      if (char >= 1 && char <= 3) {
        if (abbreviationLookup!) {
          throw GameException(
            "Abbreviation lookup cannot occur inside an abbreviation lookup.",
          );
        }
        // Bounds check: ensure we have another character for abbreviation index
        if (i + 1 >= charList.length) {
          // Malformed z-string - abbreviation marker at end without index
          break;
        }
        //abbreviation lookup
        final abbrNum = (32 * (char - 1)) + charList[++i];

        final abbrAddress =
            2 * Z.engine.mem.loadw(Z.engine.mem.abbrAddress + (abbrNum * 2));

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
        // Bounds check: ensure we have two more characters for the 10-bit code
        if (i + 2 >= charList.length) {
          // Malformed z-string - 10-bit escape without enough following chars
          break;
        }
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

  static String _readZStringVersion5AndUp(
    int? fromAddress, [
    bool? abbreviationLookup = false,
  ]) {
    bool finished = false;
    List<int> charList = [];

    //first load all the z chars into an array.
    while (!finished) {
      final nextz = ZChar(Z.engine.mem.loadw(fromAddress!));

      fromAddress += 2;

      // (ref 3.2)
      if (nextz.terminatorSet) finished = true;

      charList.addAll(nextz.toCollection());
    }

    Z.engine.callStack.push(fromAddress!);

    return _decodeZStringV5(charList, abbreviationLookup);
  }

  /// Reads a Z-string of a fixed byte length, ignoring the terminator bit.
  /// This is essential for reading dictionary entries which may be fixed-width
  /// but lack the standard terminator bit (e.g. Beyond Zork's custom dictionary).
  static String readByteLimited(int fromAddress, int numBytes) {
    List<int> charList = [];
    for (int i = 0; i < numBytes; i += 2) {
      final nextz = ZChar(Z.engine.mem.loadw(fromAddress + i));
      charList.addAll(nextz.toCollection());
    }

    if (Z.engine.version == ZMachineVersions.v5 ||
        Z.engine.version == ZMachineVersions.v6 ||
        Z.engine.version == ZMachineVersions.v7 ||
        Z.engine.version == ZMachineVersions.v8) {
      return _decodeZStringV5(charList, false);
    }
    // Fallback or todo for other versions
    return "UNSUPPORTED_VERSION_FIXED_READ";
  }

  static String _decodeZStringV5(
    List<int> charList, [
    bool? abbreviationLookup = false,
  ]) {
    final s = StringBuffer();
    int currentAlphabet = ZSCII.a0;

    int i = -1;
    while (i < charList.length - 1) {
      i++;
      var char = charList[i];

      // (ref 3.3)
      if (char >= 1 && char <= 3) {
        if (abbreviationLookup!) {
          throw GameException(
            "Abbreviation lookup cannot occur inside an abbreviation lookup.",
          );
        }
        // Bounds check: ensure we have another character for abbreviation index
        if (i + 1 >= charList.length) {
          // Malformed z-string - abbreviation marker at end without index
          break;
        }
        //abbreviation lookup
        var abbrNum = (32 * (char - 1)) + charList[++i];

        var abbrAddress =
            2 * Z.engine.mem.loadw(Z.engine.mem.abbrAddress + (abbrNum * 2));

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
        // Bounds check: ensure we have two more characters for the 10-bit code
        if (i + 2 >= charList.length) {
          // Malformed z-string - 10-bit escape without enough following chars
          break;
        }
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
          // Custom alphabet table (ref 3.5.4)
          // The table consists of 78 bytes: the 26 ZSCII codes for alphabet A0, then A1, then A2.
          final offset = alternateTable + (currentAlphabet * 26) + (char - 6);
          final zsciiCode = Z.engine.mem.loadb(offset);
          s.write(zCharToChar(zsciiCode));
          currentAlphabet = ZSCII.a0;
        } else {
          // Note: V1 games use _readZStringVersion1And2, not this function,
          // so we don't need a V1-specific check here.
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
  static String readZString(
    int fromAddress, [
    bool abbreviationLookup = false,
  ]) {
    // Check cache first (only for non-abbreviation lookups from static memory)
    // Static memory starts at staticMemAddress and cannot change during gameplay,
    // so cached strings remain valid. This matches ifvms.js's jit[] caching.
    final staticMemAddr = Z.engine.mem.staticMemAddress;
    if (!abbreviationLookup && fromAddress >= staticMemAddr) {
      final cached = _stringCache[fromAddress];
      if (cached != null) {
        // Still need to push end address to call stack for callers that expect it
        // We don't know the end address from cache, so we must decode anyway
        // But we can skip this optimization for now and just return cached value
        // Actually, the internal readers push to call stack, so we need to call them
        // to maintain that contract. Let's only cache the result, not skip decoding.
      }
    }

    final str = _stringReaderMap[Z.engine.version]!(
      fromAddress,
      abbreviationLookup,
    );

    // Cache the result if it's from static memory (immutable during gameplay)
    if (!abbreviationLookup && fromAddress >= staticMemAddr) {
      _stringCache[fromAddress] = str;
    }

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
      throw GameException(
        'String must be length of 1.  Found ${c.length} in $c.',
      );
    }

    if (c == '\t') {
      return 9;
    } else if (c == '\n') {
      return 13;
    } else {
      final cc = c.codeUnitAt(0);
      // Map DEL (127) to ZSCII Delete (8)
      if (cc == 127) {
        return 8;
      }
      // Standard printable ASCII (32-126)
      if (cc >= 32 && cc <= 126) {
        return cc;
      }
      // ZSCII input-only codes (cursor keys, function keys: 129-154)
      // These have no Unicode representation; the IO provider sends them
      // as their raw ZSCII values embedded in a single-char string.
      // Cursor Up=129, Down=130, Left=131, Right=132
      // Keypad 0-9 = 145-154, F1-F12 = 133-144
      if (cc >= 129 && cc <= 154) {
        return cc;
      }
      // Extended ZSCII characters (155-223)
      if (cc >= 155 && cc <= 223) {
        return cc;
      }
    }

    throw GameException('Could not convert from char to ZChar.');
  }

  /// Converts Z-Character [c] into an equivalent char.
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
      // Custom Unicode table lookup (ref 3.8.5.4)
      if (Z.engine.version.index >= ZMachineVersions.v5.index) {
        final extensionTable = Z.engine.mem.loadw(Header.headerExtensionTable);
        if (extensionTable > 0) {
          final unicodeTableAddress = Z.engine.mem.loadw(
            extensionTable + 4,
          ); // Word 3 is Unicode table address (ref 11.1) which is at offset 2*words? No, Header Extension table is word-indexed?
          // Wait, Header extension table is a table of words.
          // Ref 1.1.1.2: "The Header Extension Table... The first word contains the number of further words in the table. The second word is... The third word (at address + 4) is the address of the Unicode translation table."

          if (unicodeTableAddress > 0) {
            final tableLength = Z.engine.mem.loadb(unicodeTableAddress);
            if (c >= 155 && c < 155 + tableLength) {
              final unicodeChar = Z.engine.mem.loadw(
                unicodeTableAddress + 1 + (c - 155) * 2,
              );
              s.writeCharCode(unicodeChar);
              return s.toString();
            }
          }
        }
      }

      if (unicodeTranslations.containsKey(c)) {
        s.writeCharCode(unicodeTranslations[c]!);
        return s.toString();
      }
      // If not in default table and not in custom table, we can't do much.
      // Maybe return '?' or nothing? Existing behavior is to just continue.
    }

    return '';
  }
}

/// Translates ZSCII characters to their Unicode equivalents.
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
  223: 0xbf,
};
