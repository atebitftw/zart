import 'package:zart/binary_helper.dart';
import 'package:zart/game_exception.dart';
import 'package:zart/z_machine.dart';

/// Header address lookups (all z-machine versions).
class Header {
  //z-machine version
  static const int VERSION = 0x0;

  //byte address of flags
  static const int FLAGS1 = 0x1;

  static const int RELEASE = 0x2;

  //byte address of high memory start point (1.1) (word)
  static const int HIGHMEM_START_ADDR = 0x04;

  //byte address of program counter initial value
  static const int PC_INITIAL_VALUE_ADDR = 0x06;

  //byte address of dictionary
  static const int DICTIONARY_ADDR = 0x08;

  //byte address of object table
  static const int OBJECT_TABLE_ADDR = 0x0a;

  //byte address of global variables table
  static const int GLOBAL_VARS_TABLE_ADDR = 0x0c;

  //byte address of static memory start (1.1) (word)
  static const int STATIC_MEM_BASE_ADDR = 0x0e;

  static const int FLAGS2 = 0x10;

  static const int SERIAL_NUMBER = 0x12;

  static const int ABBREVIATIONS_TABLE_ADDR = 0x18;

  static const int LENGTHOFFILE = 0x1a;

  static const int CHECKSUMOFFILE = 0x1c;

  static const int INTERPRETER_NUMBER = 0x1e;

  static const int INTERPRETER_VERSION = 0x1f;

  // lines of text, 255 means 'infinite'
  static const int SCREEN_HEIGHT = 0x20;

  // characters
  static const int SCREEN_WIDTH = 0x21;

  static const int SCREEN_WIDTH_UNITS = 0x22;

  static const int SCREEN_HEIGHT_UNITS = 0x24;

  static const int FONT_WIDTH_UNITS = 0x26;

  static const int FONT_HEIGHT_UNITS = 0x27;

  // byte address of routine offset (ver 6 & 7) (word)
  static const int ROUTINES_OFFSET = 0x28;

  // byte address of strings offset (ver 6 & 7) (word)
  static const int STRINGS_OFFSET = 0x2a;

  static const int DEFAULT_BACKGROUND_COLOR = 0x2c;

  static const int DEFAULT_FOREGROUND_COLOR = 0x2d;

  static const int TERMINATING_CHARS_TABLE = 0x2e;

  static const int TOTAL_PIXEL_WIDTH = 0x30;

  static const int REVISION_NUMBER_N = 0x32;

  static const int REVISION_NUMBER_M = 0x33;

  static const int ALPHABET_TABLE = 0x34;

  static const int HEADER_EXTENSION_TABLE = 0x36;

  //64 bytes, by convention (1.1.1.1)
  static const int UPPER_LIMIT = 0x40;

  static const int FLAG1_V3_GAMETYPE = 1 << 1;
  static const int FLAG1_V3_IS_STORY_SPLIT = 1 << 2;
  static const int FLAG1_V3_STATUSLINE_AVAIL = 1 << 4;
  static const int FLAG1_V3_SCREENSPLIT_AVAIL = 1 << 5;
  static const int FLAG1_V3_VARIABLE_PITCH_FONT_AVAIL = 1 << 6;

  static const int FLAG1_V5_COLOR_AVAIL = 1;
  static const int FLAG1_V6_PICTURE_DISP_AVAIL = 1 << 1;
  static const int FLAG1_V4_BOLDFACE_AVAIL = 1 << 2;
  static const int FLAG1_V4_ITALIC_AVAIL = 1 << 3;
  static const int FLAG1_V4_FIXED_SPACE_FONT_AVAIL = 1 << 4;
  static const int FLAG1_V4_SOUND_EFFECT_AVAIL = 1 << 5;
  static const int FLAG1_V4_TIMED_KEY_INPUT_AVAIL = 1 << 7;

  static const int FLAG2_TRANSCRIPT_ON = 1;
  static const int FLAG2_FORCE_PRINT_FIXED_PITCH = 1 << 1;
  static const int FLAG2_SET_STATUS_REDRAW = 1 << 2;
  //unset these if interpreter cannot support
  static const int FLAG2_USE_PICTURES = 1 << 3;
  static const int FLAG2_USE_UNDO = 1 << 4;
  static const int FLAG2_USE_MOUSE = 1 << 5;
  static const int FLAG2_USE_COLOR = 1 << 6;
  static const int FLAG2_USE_SOUND = 1 << 7;
  static const int FLAG2_USE_MENUS = 1 << 8;

  static void checkLoaded() {
    // Who know that this old code would predict Game Of Thrones!
    if (!Z.isLoaded) throw GameException('A game must first be loaded.');
  }

  

  static void setFlags1(int flags) {
    checkLoaded();
    Z.engine.mem.storeb(Header.FLAGS1, flags);
  }

  static void setFlags2(int flags) {
    checkLoaded();
    Z.engine.mem.storeb(Header.FLAGS2, flags);
  }

  /// Feturns false if the game is a timed game.
  static bool isScoreGame() {
    checkLoaded();

    return !BinaryHelper.isSet(Z.engine.mem.loadb(FLAGS1), 1);
  }
}
