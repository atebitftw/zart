import 'dart:typed_data';

import 'package:zart/IO/iff.dart';

/// Detects and loads Z game file component, if present.
class Blorb {

  /// This function only needs the first 8 bytes of
  /// the file data in order to return a result.
  static bool isBlorb(List fileBytes){
    if (fileBytes.length < 12) return false;

    if (IFF.readChunk(fileBytes) != Chunk.form) return false;

    // var size = IFF.read4Byte(fileBytes);

    if (IFF.readChunk(fileBytes) != Chunk.ifrs) return false;

    return true;
  }


  /// Attempts to extract the Z-Machine game file data from the Blorb
  /// file bytes in [fileBytes].  If the file is not a Blorb type, then the 
  /// original bytes are returned (assumes it's a valid compiled ZIL file.)
  static Uint8List? getZData(Uint8List fileBytes){
    var rawBytes = fileBytes;

    if (!isBlorb(List.from(fileBytes.getRange(0, 12)))) return fileBytes;

    fileBytes = List.from(fileBytes) as Uint8List;

    //print(fileBytes);

    IFF.readChunk(fileBytes);
    IFF.readChunk(fileBytes);
    IFF.readChunk(fileBytes);

    if (IFF.readChunk(fileBytes) != Chunk.ridx) return null;

    // var resourceIndexSize = IFF.read16BitValue(fileBytes);
    var numResources = IFF.read16BitValue(fileBytes);

    int i = 0;

    while (i < numResources){
      var resourceChunk = IFF.readChunk(fileBytes);

      if (resourceChunk != null && resourceChunk == Chunk.exec){
        IFF.read16BitValue(fileBytes); //number of resource, should be 0

        var start = IFF.read16BitValue(fileBytes);

        fileBytes = List.from(rawBytes.getRange(start, rawBytes.length - start)) as Uint8List;

        if (IFF.readChunk(fileBytes) != Chunk.zcod) return null;

        var len = IFF.read16BitValue(fileBytes);

        return fileBytes.getRange(0, len) as Uint8List?;
      }


      i++;
    }

    return null;
  }
}
