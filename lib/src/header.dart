import 'package:zart/src/binary_helper.dart';
import 'package:zart/src/game_exception.dart';
import 'package:zart/src/z_machine.dart';

/// Header address lookups (all z-machine versions).
class Header {
  //z-machine version
  static const int version = 0x0;

  //byte address of flags
  static const int flags1 = 0x1;

  static const int release = 0x2;

  //byte address of high memory start point (1.1) (word)
  static const int highMemStartAddr = 0x04;

  //byte address of program counter initial value
  static const int programCounterInitialValueAddr = 0x06;

  //byte address of dictionary
  static const int dictionaryAddr = 0x08;

  //byte address of object table
  static const int objectTableAddr = 0x0a;

  //byte address of global variables table
  static const int globalVarsTableAddr = 0x0c;

  //byte address of static memory start (1.1) (word)
  static const int staticMemBaseAddr = 0x0e;

  static const int flags2 = 0x10;

  static const int serialNumber = 0x12;

  static const int abbreviationsTableAddr = 0x18;

  static const int lengthOfFile = 0x1a;

  static const int checkSumOfFile = 0x1c;

  static const int interpreterNumber = 0x1e;

  static const int interpreterVersion = 0x1f;

  // lines of text, 255 means 'infinite'
  static const int screenHeight = 0x20;

  // characters
  static const int screenWidth = 0x21;

  static const int screenWidthUnits = 0x22;

  static const int screenHeightUnits = 0x24;

  static const int fontWidthUnits = 0x26;

  static const int fontHeightUnits = 0x27;

  // byte address of routine offset (ver 6 & 7) (word)
  static const int routinesOffset = 0x28;

  // byte address of strings offset (ver 6 & 7) (word)
  static const int stringsOffset = 0x2a;

  static const int defaultBackgroundColor = 0x2c;

  static const int defaultForegroundColor = 0x2d;

  static const int terminatingCharsTable = 0x2e;

  static const int totalPixelWidth = 0x30;

  static const int revisionNumberN = 0x32;

  static const int revisionNumberM = 0x33;

  static const int alphabetTable = 0x34;

  static const int headerExtensionTable = 0x36;

  //64 bytes, by convention (1.1.1.1)
  static const int upperLimit = 0x40;

  static const int flag1V3GameType = 1 << 1;
  static const int flagV3IsStorySplit = 1 << 2;
  static const int flag1V3StatusLineAvail = 1 << 4;
  static const int flag1V3ScreenSplitAvail = 1 << 5;
  static const int flag1V3VariablePitchFontAvail = 1 << 6;

  static const int flag1VSColorAvail = 1;
  static const int flag1V6PictureDispAvail = 1 << 1;
  static const int flag1V4BoldfaceAvail = 1 << 2;
  static const int flag1V4ItalicAvail = 1 << 3;
  static const int flag1V4FixedSpaceFontAvail = 1 << 4;
  static const int flag1V4SoundEffectAvail = 1 << 5;
  static const int flag1V4TimedKeyInputAvail = 1 << 7;

  static const int flag2TranscriptOn = 1;
  static const int flag2ForcePrintFixedPitch = 1 << 1;
  static const int flag2SetStatusRedraw = 1 << 2;
  //unset these if interpreter cannot support
  static const int flag2UsePictures = 1 << 3;
  static const int flag2UseUndo = 1 << 4;
  static const int flag2UseMouse = 1 << 5;
  static const int flag2UseColor = 1 << 6;
  static const int flag2UseSound = 1 << 7;
  static const int flag2UseMenus = 1 << 8;

  static void checkLoaded() {
    // Who know that this old code would predict Game Of Thrones!
    if (!Z.isLoaded) throw GameException('A game must first be loaded.');
  }

  static void setFlags1(int flags) {
    checkLoaded();
    Z.engine.mem.storeb(Header.flags1, flags);
  }

  static void setFlags2(int flags) {
    checkLoaded();
    Z.engine.mem.storeb(Header.flags2, flags);
  }

  /// Feturns false if the game is a timed game.
  static bool isScoreGame() {
    checkLoaded();

    return !BinaryHelper.isSet(Z.engine.mem.loadb(flags1), 1);
  }
}
