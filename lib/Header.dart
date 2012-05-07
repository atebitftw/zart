/**
* Header address lookups (all z-machine versions).
*/
class Header{

  //z-machine version
  static final int  VERSION= 0x00;

  //byte address of flags
  static final int  FLAGS1 = 0x01;

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

}