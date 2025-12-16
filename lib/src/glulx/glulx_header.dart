/// Constants for the Glulx Header.
class GlulxHeader {
  /// The magic number for the Glulx header.
  static const int magicNumber = 0x00; // 'Glul'
  /// Version of the Glulx header.
  static const int version = 0x04;

  /// RAM start address.
  static const int ramStart = 0x08;

  /// External start address.
  static const int extStart = 0x0C;

  /// End of memory address.
  static const int endMem = 0x10;

  /// Stack size.
  static const int stackSize = 0x14;

  /// Start function address.
  static const int startFunc = 0x18;

  /// Decoding table address.
  static const int decodingTbl = 0x1C;

  /// Checksum.
  static const int checksum = 0x20;

  /// Size of the header.
  static const int size = 36;
}
