import 'package:zart/IO/iff.dart';

/// Detects and loads Z game file component, if present.
class Blorb {

  /// This function only needs the first 8 bytes of
  /// the file data in order to return a result.
  static bool isBlorb(List fileBytes){
    if (fileBytes.length < 12) return false;

    if (IFF.readChunk(fileBytes) != Chunk.FORM) return false;

    // var size = IFF.read4Byte(fileBytes);

    if (IFF.readChunk(fileBytes) != Chunk.IFRS) return false;

    return true;
  }


  /// Attempts to extract the Z-Machine game file data form the Blorb
  /// file.  If the file is not a Blorb type, then the original
  /// data is returned.
  static List<int> getZData(List fileBytes){
    var rawBytes = fileBytes;

    if (!isBlorb(new List.from(fileBytes.getRange(0, 12)))) return fileBytes;

    fileBytes = new List.from(fileBytes);

    //print(fileBytes);

    IFF.readChunk(fileBytes);
    IFF.readChunk(fileBytes);
    IFF.readChunk(fileBytes);

    if (IFF.readChunk(fileBytes) != Chunk.RIdx) return null;

    // var resourceIndexSize = IFF.read16BitValue(fileBytes);
    var numResources = IFF.read16BitValue(fileBytes);

    int i = 0;

    while (i < numResources){
      var resourceChunk = IFF.readChunk(fileBytes);

      if (resourceChunk != null && resourceChunk == Chunk.Exec){
        IFF.read16BitValue(fileBytes); //number of resource, should be 0

        var start = IFF.read16BitValue(fileBytes);

        fileBytes = new List.from(rawBytes.getRange(start, rawBytes.length - start));

        if (IFF.readChunk(fileBytes) != Chunk.ZCOD) return null;

        var len = IFF.read16BitValue(fileBytes);

        return fileBytes.getRange(0, len);
      }


      i++;
    }

    return null;
  }
}
