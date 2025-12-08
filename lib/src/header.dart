import 'package:zart/src/binary_helper.dart';
import 'package:zart/src/game_exception.dart';
import 'package:zart/src/z_machine.dart';

/// Header address lookups (all z-machine versions).
class Header {
  /// The byte address of version.
  static const int version = 0x0;

  /// The byte address of flags.
  static const int flags1 = 0x1;

  /// The byte address of release.
  static const int release = 0x2;

  /// The byte address of high memory start point (1.1) (word)
  static const int highMemStartAddr = 0x04;

  /// The byte address of program counter initial value
  static const int programCounterInitialValueAddr = 0x06;

  /// The byte address of dictionary
  static const int dictionaryAddr = 0x08;

  /// The byte address of object table
  static const int objectTableAddr = 0x0a;

  /// The byte address of global variables table
  static const int globalVarsTableAddr = 0x0c;

  /// The byte address of static memory start (1.1) (word)
  static const int staticMemBaseAddr = 0x0e;

  /// The byte address of flags2
  static const int flags2 = 0x10;

  /// The byte address of serial number
  static const int serialNumber = 0x12;

  /// The byte address of abbreviations table
  static const int abbreviationsTableAddr = 0x18;

  /// The byte address of length of file
  static const int lengthOfFile = 0x1a;

  /// The byte address of check sum of file
  static const int checkSumOfFile = 0x1c;

  /// The byte address of interpreter number
  static const int interpreterNumber = 0x1e;

  /// The byte address of interpreter version
  static const int interpreterVersion = 0x1f;

  /// The byte address of screen height, 255 means 'infinite'
  static const int screenHeight = 0x20;

  /// The byte address of screen width
  static const int screenWidth = 0x21;

  /// The byte address of screen width units
  static const int screenWidthUnits = 0x22;

  /// The byte address of screen height units
  static const int screenHeightUnits = 0x24;

  /// The byte address of font width units
  static const int fontWidthUnits = 0x26;

  /// The byte address of font height units
  static const int fontHeightUnits = 0x27;

  /// The byte address of routine offset (ver 6 & 7) (word)
  static const int routinesOffset = 0x28;

  /// The byte address of strings offset (ver 6 & 7) (word)
  static const int stringsOffset = 0x2a;

  /// The byte address of default background color
  static const int defaultBackgroundColor = 0x2c;

  /// The byte address of default foreground color
  static const int defaultForegroundColor = 0x2d;

  /// The byte address of terminating characters table
  static const int terminatingCharsTable = 0x2e;

  /// The byte address of total pixel width
  static const int totalPixelWidth = 0x30;

  /// The byte address of revision number N
  static const int revisionNumberN = 0x32;

  /// The byte address of revision number M
  static const int revisionNumberM = 0x33;

  /// The byte address of alphabet table
  static const int alphabetTable = 0x34;

  /// The byte address of header extension table
  static const int headerExtensionTable = 0x36;

  /// The byte address of upper limit
  static const int upperLimit = 0x40;

  /// The byte address of flag1V3GameType
  static const int flag1V3GameType = 1 << 1;

  /// The byte address of flagV3IsStorySplit
  static const int flagV3IsStorySplit = 1 << 2;

  /// The byte address of flag1V3StatusLineAvail
  static const int flag1V3StatusLineAvail = 1 << 4;

  /// The byte address of flag1V3ScreenSplitAvail
  static const int flag1V3ScreenSplitAvail = 1 << 5;

  /// The byte address of flag1V3VariablePitchFontAvail
  static const int flag1V3VariablePitchFontAvail = 1 << 6;

  /// The byte address of flag1VSColorAvail
  static const int flag1VSColorAvail = 1;

  /// The byte address of flag1V6PictureDispAvail
  static const int flag1V6PictureDispAvail = 1 << 1;

  /// The byte address of flag1V4BoldfaceAvail
  static const int flag1V4BoldfaceAvail = 1 << 2;

  /// The byte address of flag1V4ItalicAvail
  static const int flag1V4ItalicAvail = 1 << 3;

  /// The byte address of flag1V4FixedSpaceFontAvail
  static const int flag1V4FixedSpaceFontAvail = 1 << 4;

  /// The byte address of flag1V4SoundEffectAvail
  static const int flag1V4SoundEffectAvail = 1 << 5;

  /// The byte address of flag1V4TimedKeyInputAvail
  static const int flag1V4TimedKeyInputAvail = 1 << 7;

  /// The byte address of flag2TranscriptOn
  static const int flag2TranscriptOn = 1;

  /// The byte address of flag2ForcePrintFixedPitch
  static const int flag2ForcePrintFixedPitch = 1 << 1;

  /// The byte address of flag2SetStatusRedraw
  static const int flag2SetStatusRedraw = 1 << 2;

  /// The byte address of flag2UsePictures
  static const int flag2UsePictures = 1 << 3;

  /// The byte address of flag2UseUndo
  static const int flag2UseUndo = 1 << 4;

  /// The byte address of flag2UseMouse
  static const int flag2UseMouse = 1 << 5;

  /// The byte address of flag2UseColor
  static const int flag2UseColor = 1 << 6;

  /// The byte address of flag2UseSound
  static const int flag2UseSound = 1 << 7;

  /// The byte address of flag2UseMenus
  static const int flag2UseMenus = 1 << 8;

  /// Checks if the game is loaded.
  static void checkLoaded() {
    if (!Z.isLoaded) throw GameException('A game must first be loaded.');
  }

  /// Sets the flags1 value.
  static void setFlags1(int flags) {
    checkLoaded();
    Z.engine.mem.storeb(Header.flags1, flags);
  }

  /// Sets the flags2 value.
  static void setFlags2(int flags) {
    checkLoaded();
    Z.engine.mem.storeb(Header.flags2, flags);
  }

  /// Returns true if the game is a scored game.
  static bool isScoreGame() {
    checkLoaded();

    return !BinaryHelper.isSet(Z.engine.mem.loadb(flags1), 1);
  }
}
