/// A utility class supporting common IFF operations.
class IFF {
  static int? nextByte(List stream) {
    if (stream.isEmpty) return null;

    var nb = stream[0];

    stream.removeRange(0, 1);

    return nb;
  }

  static void writeChunk(List stream, Chunk chunk) {
    var bytes = chunk.charCodes();

    for (final byte in bytes) {
      stream.add(byte);
    }
  }

  static Chunk? readChunk(List stream) {
    if (stream.length < 4) return null;

    var s = StringBuffer();

    for (int i = 0; i < 4; i++) {
      s.writeCharCode(nextByte(stream)!);
    }

    return Chunk.toChunk(s.toString());
  }

  static int read4Byte(List stream) {
    var bl = [];

    for (int i = 0; i < 4; i++) {
      bl.add(nextByte(stream));
    }

    return (bl[0] << 24) | (bl[1] << 16) | (bl[2] << 8) | bl[3];
  }

  static int read3Byte(List stream) {
    var bl = [];

    for (int i = 0; i < 3; i++) {
      bl.add(nextByte(stream));
    }

    return (bl[0] << 16) | (bl[1] << 8) | bl[2];
  }

  static int read2Byte(List stream) {
    var bl = [];

    for (int i = 0; i < 2; i++) {
      bl.add(nextByte(stream));
    }

    return (bl[0] << 8) | bl[1];
  }

  static void write4Byte(List stream, int value) {
    stream.add((value >> 24) & 0xFF);
    stream.add((value >> 16) & 0xFF);
    stream.add((value >> 8) & 0xFF);
    stream.add(value & 0xFF);
  }

  static void write3Byte(List stream, int value) {
    stream.add((value >> 16) & 0xFF);
    stream.add((value >> 8) & 0xFF);
    stream.add(value & 0xFF);
  }

  static void write2Byte(List stream, int value) {
    stream.add((value >> 8) & 0xFF);
    stream.add(value & 0xFF);
  }

  static int read16BitValue(List stream) {
    return (nextByte(stream)! << 24) |
        (nextByte(stream)! << 16) |
        (nextByte(stream)! << 8) |
        nextByte(stream)!;
  }
}

/// Enumerates IFF chunks used in the Quetzal & Blorb formats.
class Chunk {
  final String _str;

  const Chunk(this._str);

  //Blorb chunks
  static const ifrs = Chunk('IFRS');
  static const ridx = Chunk('RIdx');
  static const zcod = Chunk('ZCOD');
  static const exec = Chunk('Exec');

  //Quetzal chunks
  static const ifzs = Chunk('IFZS');
  static const ifhd = Chunk('IFhd');
  static const cmem = Chunk('CMem');
  static const umem = Chunk('UMem');
  static const stks = Chunk('Stks');
  static const intd = Chunk('IntD');

  //IFF Chunks
  static const form = Chunk('FORM');
  static const auth = Chunk('AUTH');
  static const cpyr = Chunk('(c) ');
  static const anno = Chunk('ANNO');

  @override
  String toString() => _str;

  // List<int> charCodes() => _str.charCodes;
  List<int> charCodes() => throw Exception("need to implement charCodes");

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
