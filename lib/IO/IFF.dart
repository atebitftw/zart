
/**
* A utility class supporting common IFF operations.
*/
class IFF {

  static int nextByte(List stream){

    if (stream.isEmpty()) return null;

    var nb = stream[0];

    stream.removeRange(0, 1);

    return nb;
  }

  static void writeChunk(List stream, Chunk chunk){

    var bytes = chunk.charCodes();

    for(final byte in bytes){
      stream.add(byte);
    }
  }

  static Chunk readChunk(List stream){
    if (stream.length < 4) return null;

    var s = new StringBuffer();

    for(int i = 0; i < 4; i++){
      s.addCharCode(nextByte(stream));
    }

    return Chunk.toChunk(s.toString());
  }

  static int read4Byte(List stream){
    var bl = new List();

    for(int i = 0; i < 4; i++){
      bl.add(nextByte(stream));
    }

    return (bl[0] << 24) | (bl[1] << 16) | (bl[2] << 8) | bl[3];
  }

  static int read3Byte(List stream){
    var bl = new List();

    for(int i = 0; i < 3; i++){
      bl.add(nextByte(stream));
    }

    return (bl[0] << 16) | (bl[1] << 8) | bl[2];
  }

  static int read2Byte(List stream){
    var bl = new List();

    for(int i = 0; i < 2; i++){
      bl.add(nextByte(stream));
    }

    return (bl[0] << 8) | bl[1];
  }

  static void write4Byte(List stream, int value){
    stream.add((value >> 24) & 0xFF);
    stream.add((value >> 16) & 0xFF);
    stream.add((value >> 8) & 0xFF);
    stream.add(value & 0xFF);
   }

  static void write3Byte(List stream, int value){
    stream.add((value >> 16) & 0xFF);
    stream.add((value >> 8) & 0xFF);
    stream.add(value & 0xFF);
   }

  static void write2Byte(List stream, int value){
    stream.add((value >> 8) & 0xFF);
    stream.add(value & 0xFF);
  }

  static int read16BitValue(List stream){
     return (nextByte(stream) << 24)
         | (nextByte(stream) << 16)
         | (nextByte(stream) << 8)
         | nextByte(stream);
  }
}



/**
* Enumerates IFF chunks used in the Quetzal & Blorb formats.
*
*/
class Chunk{
  final String _str;

  const Chunk(this._str);

  //Blorb chunks
  static final IFRS = const Chunk('IFRS');
  static final RIdx = const Chunk('RIdx');
  static final ZCOD = const Chunk('ZCOD');
  static final Exec = const Chunk('Exec');

  //Quetzal chunks
  static final IFZS = const Chunk('IFZS');
  static final IFhd = const Chunk('IFhd');
  static final CMem = const Chunk('CMem');
  static final UMem = const Chunk('UMem');
  static final Stks = const Chunk('Stks');
  static final IntD = const Chunk('IntD');

  //IFF Chunks
  static final FORM = const Chunk('FORM');
  static final AUTH = const Chunk('AUTH');
  static final CPYR = const Chunk('(c) ');
  static final ANNO = const Chunk('ANNO');

  String toString() => _str;

  List<int> charCodes() => _str.charCodes();

  static Chunk toChunk(String chunk){
    switch(chunk){
      case "Exec": return Chunk.Exec;
      case "ZCOD": return Chunk.ZCOD;
      case "RIdx": return Chunk.RIdx;
      case "IFRS": return Chunk.IFRS;
      case "IFZS": return Chunk.IFZS;
      case "IFhd": return Chunk.IFhd;
      case "CMem": return Chunk.CMem;
      case "UMem": return Chunk.UMem;
      case "Stks": return Chunk.Stks;
      case "IntD": return Chunk.IntD;
      case "FORM": return Chunk.FORM;
      case "AUTH": return Chunk.AUTH;
      case "(c) ": return Chunk.CPYR;
      case "ANNO": return Chunk.ANNO;
      default:
        return null;
    }
  }
}