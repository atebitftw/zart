/**
* Header address lookups (all z-machine versions).
*/
class Header{

  //z-machine version
  static final int  VERSION= 0x0;

  //byte address of flags
  static final int  FLAGS1 = 0x1;

  static final int RELEASE = 0x2;

  //byte address of high memory start point (1.1) (word)
  static final int  HIGHMEM_START_ADDR = 0x04;

  //byte address of program counter initial value
  static final int  PC_INITIAL_VALUE_ADDR = 0x06;

  //byte address of dictionary
  static final int  DICTIONARY_ADDR = 0x08;

  //byte address of object table
  static final int  OBJECT_TABLE_ADDR = 0x0a;

  //byte address of global variables table
  static final int  GLOBAL_VARS_TABLE_ADDR = 0x0c;

  //byte address of static memory start (1.1) (word)
  static final int  STATIC_MEM_BASE_ADDR = 0x0e;

  static final int  FLAGS2 = 0x10;

  static final int  SERIAL_NUMBER = 0x12;

  static final int  ABBREVIATIONS_TABLE_ADDR = 0x18;

  static final int  LENGTHOFFILE = 0x1a;

  static final int  CHECKSUMOFFILE = 0x1c;

  static final int  INTERPRETER_NUMBER = 0x1e;

  static final int  INTERPRETER_VERSION = 0x1f;

  // lines of text, 255 means 'infinite'
  static final int  SCREEN_HEIGHT = 0x20;

  // characters
  static final int  SCREEN_WIDTH = 0x21;

  static final int  SCREEN_WIDTH_UNITS = 0x22;

  static final int  SCREEN_HEIGHT_UNITS = 0x24;

  static final int  FONT_WIDTH_UNITS = 0x26;

  static final int  FONT_HEIGHT_UNITS = 0x27;

  // byte address of routine offset (ver 6 & 7) (word)
  static final int  ROUTINES_OFFSET = 0x28;

  // byte address of strings offset (ver 6 & 7) (word)
  static final int  STRINGS_OFFSET = 0x2a;

  static final int  DEFAULT_BACKGROUND_COLOR = 0x2c;

  static final int  DEFAULT_FOREGROUND_COLOR = 0x2d;

  static final int  TERMINATING_CHARS_TABLE = 0x2e;

  static final int  TOTAL_PIXEL_WIDTH = 0x30;

  static final int  REVISION_NUMBER = 0x32;

  static final int  ALPHABET_TABLE = 0x34;

  static final int  HEADER_EXTENSION_TABLE = 0x36;
  
  //64 bytes, by convention (1.1.1.1)
  static final int  UPPER_LIMIT = 0x40;

  static final int FLAG1_V3_GAMETYPE = 1 << 1;
  static final int FLAG1_V3_IS_STORY_SPLIT = 1 << 2;
  static final int FLAG1_V3_STATUSLINE_AVAIL = 1 << 4;
  static final int FLAG1_V3_SCREENSPLIT_AVAIL = 1 << 5;
  static final int FLAG1_V3_VARIABLE_PITCH_FONT_AVAIL = 1 << 6;
  
  static final int FLAG1_V5_COLOR_AVAIL = 1;
  static final int FLAG1_V6_PICTURE_DISP_AVAIL = 1 << 1;
  static final int FLAG1_V4_BOLDFACE_AVAIL = 1 << 2;
  static final int FLAG1_V4_ITALIC_AVAIL = 1 << 3;
  static final int FLAG1_V4_FIXED_SPACE_FONT_AVAIL = 1 << 4;
  static final int FLAG1_V4_SOUND_EFFECT_AVAIL = 1 << 5;
  static final int FLAG1_V4_TIMED_KEY_INPUT_AVAIL = 1 << 7;
  
  static final int FLAG2_TRANSCRIPT_ON = 1;
  static final int FLAG2_FORCE_PRINT_FIXED_PITCH = 1 << 1;
  static final int FLAG2_SET_STATUS_REDRAW = 1 << 2;
  //unset these if interpreter cannot support
  static final int FLAG2_USE_PICTURES = 1 << 3;
  static final int FLAG2_USE_UNDO = 1 << 4;
  static final int FLAG2_USE_MOUSE = 1 << 5;
  static final int FLAG2_USE_COLOR = 1 << 6;
  static final int FLAG2_USE_SOUND = 1 << 7;
  static final int FLAG2_USE_MENUS = 1 << 8;
  
  static void checkLoaded() {
    if (!Z.isLoaded) throw new GameException('A game must first be loaded.');
  }
  
  static bool setFlags1(int flags){
    checkLoaded();
    Z.machine.mem.storeb(Header.FLAGS1, flags);
  }
  
  static bool setFlags2(int flags){
    checkLoaded();
    Z.machine.mem.storeb(Header.FLAGS2, flags);
  }
   
  /// Feturns false if the game is a timed game.
  static bool isScoreGame(){
    checkLoaded();
    
    return !BinaryHelper.isSet(Z.machine.mem.loadb(FLAGS1), 1);
  }

}