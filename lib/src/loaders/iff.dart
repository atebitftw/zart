/// A utility class supporting common IFF operations.
class IFF {
  /// Returns the next byte from the stream.
  static int? nextByte(List stream) {
    if (stream.isEmpty) return null;

    var nb = stream[0];

    stream.removeRange(0, 1);

    return nb;
  }

  /// Writes a chunk to the stream.
  static void writeChunk(List stream, Chunk chunk) {
    var bytes = chunk.charCodes();

    for (final byte in bytes) {
      stream.add(byte);
    }
  }

  /// Reads a chunk from the stream.
  static Chunk? readChunk(List stream) {
    if (stream.length < 4) return null;

    var s = StringBuffer();

    for (int i = 0; i < 4; i++) {
      s.writeCharCode(nextByte(stream)!);
    }

    return Chunk.toChunk(s.toString());
  }

  /// Reads a 4 byte (32-bit) unsigned value from the stream.
  /// Uses mask to ensure unsigned interpretation in JavaScript.
  static int read4Byte(List stream) {
    var bl = [];

    for (int i = 0; i < 4; i++) {
      bl.add(nextByte(stream));
    }

    // Mask with 0xFFFFFFFF to force unsigned interpretation in JS
    // (JS bitwise ops return signed 32-bit integers)
    return ((bl[0] << 24) | (bl[1] << 16) | (bl[2] << 8) | bl[3]) & 0xFFFFFFFF;
  }

  /// Reads a 3 byte value from the stream.
  static int read3Byte(List stream) {
    var bl = [];

    for (int i = 0; i < 3; i++) {
      bl.add(nextByte(stream));
    }

    return (bl[0] << 16) | (bl[1] << 8) | bl[2];
  }

  /// Reads a 2 byte value from the stream.
  static int read2Byte(List stream) {
    var bl = [];

    for (int i = 0; i < 2; i++) {
      bl.add(nextByte(stream));
    }

    return (bl[0] << 8) | bl[1];
  }

  /// Writes a 4 byte value to the stream.
  static void write4Byte(List stream, int value) {
    stream.add((value >> 24) & 0xFF);
    stream.add((value >> 16) & 0xFF);
    stream.add((value >> 8) & 0xFF);
    stream.add(value & 0xFF);
  }

  /// Writes a 3 byte value to the stream.
  static void write3Byte(List stream, int value) {
    stream.add((value >> 16) & 0xFF);
    stream.add((value >> 8) & 0xFF);
    stream.add(value & 0xFF);
  }

  /// Writes a 2 byte value to the stream.
  static void write2Byte(List stream, int value) {
    stream.add((value >> 8) & 0xFF);
    stream.add(value & 0xFF);
  }

  /// Reads a 32-bit unsigned value from the stream.
  /// Note: Despite the name, this reads 4 bytes (32-bit), not 16-bit.
  /// Uses mask to ensure unsigned interpretation in JavaScript.
  static int read16BitValue(List stream) {
    return ((nextByte(stream)! << 24) |
            (nextByte(stream)! << 16) |
            (nextByte(stream)! << 8) |
            nextByte(stream)!) &
        0xFFFFFFFF;
  }
}

/// Enumerates IFF chunks used in the Quetzal & Blorb formats.
class Chunk {
  final String _str;

  /// Creates a new chunk from a string.
  const Chunk(this._str);

  /// Returns the character at the specified index.
  int operator [](int index) => _str.codeUnitAt(index);

  //Blorb chunks
  /// The IFRS Blorb chunk.
  static const ifrs = Chunk('IFRS');

  /// The RIdx Blorb chunk.
  static const ridx = Chunk('RIdx');

  /// The z-machine game file chunk.
  static const zcod = Chunk('ZCOD');

  /// The Glulx game file chunk.
  static const glul = Chunk('GLUL');

  /// The Exec Blorb chunk.
  static const exec = Chunk('Exec');

  //Quetzal chunks
  /// The IFZS Quetzal chunk.
  static const ifzs = Chunk('IFZS');

  /// The IFhd Quetzal chunk (game identifier chunk).
  static const ifhd = Chunk('IFhd');

  /// The CMem Quetzal chunk.
  static const cmem = Chunk('CMem');

  /// The UMem Quetzal chunk.
  static const umem = Chunk('UMem');

  /// The Stks Quetzal chunk.
  static const stks = Chunk('Stks');

  /// The IntD Quetzal chunk.
  static const intd = Chunk('IntD');

  //IFF Chunks
  /// The FORM IFF chunk.
  static const form = Chunk('FORM');

  /// The AUTH IFF chunk.
  static const auth = Chunk('AUTH');

  /// The (c)  IFF chunk.
  static const cpyr = Chunk('(c) ');

  /// The ANNO IFF chunk.
  static const anno = Chunk('ANNO');

  @override
  String toString() => _str;

  /// Returns the character codes for the chunk.
  List<int> charCodes() {
    return _str.codeUnits;
  }

  /// Converts a string to a chunk.
  static Chunk? toChunk(String chunk) {
    switch (chunk) {
      case "Exec":
        return Chunk.exec;
      case "ZCOD":
        return Chunk.zcod;
      case "RIdx":
        return Chunk.ridx;
      case "IFRS":
        return Chunk.ifrs;
      case "IFZS":
        return Chunk.ifzs;
      case "IFhd":
        return Chunk.ifhd;
      case "CMem":
        return Chunk.cmem;
      case "UMem":
        return Chunk.umem;
      case "Stks":
        return Chunk.stks;
      case "IntD":
        return Chunk.intd;
      case "FORM":
        return Chunk.form;
      case "AUTH":
        return Chunk.auth;
      case "(c) ":
        return Chunk.cpyr;
      case "ANNO":
        return Chunk.anno;
      default:
        return null;
    }
  }
}
