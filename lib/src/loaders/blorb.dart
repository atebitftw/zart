import 'dart:typed_data';

import 'package:zart/src/loaders/iff.dart';
import 'package:zart/src/logging.dart' show log;

/// Enumerates story file types.
enum GameFileType {
  /// Z-Machine Game File
  z,

  /// Glulx Game File
  glulx,
}

/// Detects and loads Z game file component, if present.
class Blorb {
  /// Returns true if the file is recognized as a blorb type file (.zblorb or .gblorb)
  static bool isBlorbFile(Uint8List fileBytes) {
    var stream = List<int>.from(fileBytes);

    if (stream.length < 12) return false;

    if (IFF.readChunk(stream) != Chunk.form) return false;

    // Skip size (4 bytes)
    IFF.read4Byte(stream);

    // Check for interactive fiction resource chunk
    if (IFF.readChunk(stream) != Chunk.ifrs) return false;

    return true;
  }

  /// Returns a game file (if found) and the type of game file.
  static (Uint8List?, GameFileType?) getStoryFileData(Uint8List fileBytes) {
    if (!isBlorbFile(fileBytes)) {
      // Not a blorb file, then we assume it's a old-school game file (.z3, .dat, etc)
      // and just return the bytes.
      return (fileBytes, GameFileType.z);
    }
    // Use a growable list for stream processing (Uint8List is fixed-length)
    var stream = List<int>.from(fileBytes);

    // Header (already verified by isBlorb, but we need to consume it)
    IFF.readChunk(stream); // FORM
    IFF.read4Byte(stream); // Size
    IFF.readChunk(stream); // IFRS

    while (stream.isNotEmpty) {
      if (stream.length < 8) break; // Not enough for Chunk Header

      var chunkType = IFF.readChunk(stream);
      var chunkSize = IFF.read4Byte(stream);

      // Pad chunk size to even number of bytes as per IFF spec
      var paddedSize = chunkSize + (chunkSize % 2);

      if (chunkType == Chunk.ridx) {
        // Parse Resource Index
        var numResources = IFF.read4Byte(stream);

        for (int i = 0; i < numResources; i++) {
          var usage = IFF.readChunk(stream);
          IFF.read4Byte(stream); // number (unused)
          var start = IFF.read4Byte(stream);

          if (usage == Chunk.exec) {
            // Found Executable Resource (Story File)
            // The 'start' is the offset in the original file (absolute)

            if (start < fileBytes.length) {
              // Read chunk at 'start' in original file
              // Z-Machine Game Chunk: ZCOD + Size + Data

              // Verify ZCOD
              // fileBytes[start..start+3] should equal 'ZCOD'
              if (start + 8 <= fileBytes.length) {
                // Check for 'ZCOD' (90, 67, 79, 68)
                if (fileBytes[start] == 90 &&
                    fileBytes[start + 1] == 67 &&
                    fileBytes[start + 2] == 79 &&
                    fileBytes[start + 3] == 68) {
                  // Read size
                  int len =
                      (fileBytes[start + 4] << 24) |
                      (fileBytes[start + 5] << 16) |
                      (fileBytes[start + 6] << 8) |
                      fileBytes[start + 7];

                  if (start + 8 + len <= fileBytes.length) {
                    return (_getZData(fileBytes), GameFileType.z);
                  }
                } else {
                  // check for 'GLUL' (71, 76, 85, 76)
                  if (fileBytes[start] == 71 &&
                      fileBytes[start + 1] == 76 &&
                      fileBytes[start + 2] == 85 &&
                      fileBytes[start + 3] == 76) {
                    // we aren't supporting glulx just yet so return null.
                    return (_getGlulxData(fileBytes), GameFileType.glulx);
                  } else {
                    return (null, null);
                  }
                }
              }
            }
          }
        }
      } else {
        // Skip this chunk
        if (paddedSize > 0) {
          if (paddedSize > stream.length) break; // Corrupted
          stream.removeRange(0, paddedSize);
        }
      }
    }
    log.warning("Unable to load file.");
    return (null, null);
  }

  static Uint8List? _getGlulxData(Uint8List fileBytes) {
    // Use a growable list for stream processing (Uint8List is fixed-length)
    var stream = List<int>.from(fileBytes);

    // Header (already verified by isBlorb, but we need to consume it)
    IFF.readChunk(stream); // FORM
    IFF.read4Byte(stream); // Size
    IFF.readChunk(stream); // IFRS

    while (stream.isNotEmpty) {
      if (stream.length < 8) break; // Not enough for Chunk Header

      var chunkType = IFF.readChunk(stream);
      var chunkSize = IFF.read4Byte(stream);

      // Pad chunk size to even number of bytes as per IFF spec
      var paddedSize = chunkSize + (chunkSize % 2);

      if (chunkType == Chunk.ridx) {
        // Parse Resource Index
        var numResources = IFF.read4Byte(stream);

        for (int i = 0; i < numResources; i++) {
          var usage = IFF.readChunk(stream);
          IFF.read4Byte(stream); // number (unused)
          var start = IFF.read4Byte(stream);

          if (usage == Chunk.exec) {
            // Found Executable Resource (Story File)
            // The 'start' is the offset in the original file (absolute)

            if (start < fileBytes.length) {
              // Read chunk at 'start' in original file
              // Z-Machine Game Chunk: ZCOD + Size + Data

              // Verify ZCOD
              // fileBytes[start..start+3] should equal 'ZCOD'
              if (start + 8 <= fileBytes.length) {
                // Check for 'GLUL' (71, 76, 85, 76)
                if (fileBytes[start] == 71 &&
                    fileBytes[start + 1] == 76 &&
                    fileBytes[start + 2] == 85 &&
                    fileBytes[start + 3] == 76) {
                  // Read size
                  var len =
                      (fileBytes[start + 4] << 24) |
                      (fileBytes[start + 5] << 16) |
                      (fileBytes[start + 6] << 8) |
                      fileBytes[start + 7];

                  if (start + 8 + len <= fileBytes.length) {
                    return Uint8List.fromList(
                      fileBytes.sublist(start + 8, start + 8 + len),
                    );
                  }
                } else {
                  log.warning("GLUL chunk not found.");
                  return null;
                }
              }
            }
          }
        }
      } else {
        // Skip this chunk
        if (paddedSize > 0) {
          if (paddedSize > stream.length) break; // Corrupted
          stream.removeRange(0, paddedSize);
        }
      }
    }

    // If we get here, we found a Blorb but no Z-Code in it?
    // Or parsing failed. Return null to indicate failure.
    return null;
  }

  /// Attempts to extract the Z-Machine game file data from the Blorb
  /// file bytes in [fileBytes].  If the file is not a Blorb type, then the
  /// original bytes are returned (assumes it's a valid compiled ZIL file.)
  static Uint8List? _getZData(Uint8List fileBytes) {
    // Use a growable list for stream processing (Uint8List is fixed-length)
    var stream = List<int>.from(fileBytes);

    // Header (already verified by isBlorb, but we need to consume it)
    IFF.readChunk(stream); // FORM
    IFF.read4Byte(stream); // Size
    IFF.readChunk(stream); // IFRS

    while (stream.isNotEmpty) {
      if (stream.length < 8) break; // Not enough for Chunk Header

      var chunkType = IFF.readChunk(stream);
      var chunkSize = IFF.read4Byte(stream);

      // Pad chunk size to even number of bytes as per IFF spec
      var paddedSize = chunkSize + (chunkSize % 2);

      if (chunkType == Chunk.ridx) {
        // Parse Resource Index
        var numResources = IFF.read4Byte(stream);

        for (int i = 0; i < numResources; i++) {
          var usage = IFF.readChunk(stream);
          IFF.read4Byte(stream); // number (unused)
          var start = IFF.read4Byte(stream);

          if (usage == Chunk.exec) {
            // Found Executable Resource (Story File)
            // The 'start' is the offset in the original file (absolute)

            if (start < fileBytes.length) {
              // Read chunk at 'start' in original file
              // Z-Machine Game Chunk: ZCOD + Size + Data

              // Verify ZCOD
              // fileBytes[start..start+3] should equal 'ZCOD'
              if (start + 8 <= fileBytes.length) {
                // Check for 'ZCOD' (90, 67, 79, 68)
                if (fileBytes[start] == 90 &&
                    fileBytes[start + 1] == 67 &&
                    fileBytes[start + 2] == 79 &&
                    fileBytes[start + 3] == 68) {
                  // Read size
                  var len =
                      (fileBytes[start + 4] << 24) |
                      (fileBytes[start + 5] << 16) |
                      (fileBytes[start + 6] << 8) |
                      fileBytes[start + 7];

                  if (start + 8 + len <= fileBytes.length) {
                    return Uint8List.fromList(
                      fileBytes.sublist(start + 8, start + 8 + len),
                    );
                  }
                } else {
                  log.warning("ZCOD chunk not found.");
                  return null;
                }
              }
            }
          }
        }
      } else {
        // Skip this chunk
        if (paddedSize > 0) {
          if (paddedSize > stream.length) break; // Corrupted
          stream.removeRange(0, paddedSize);
        }
      }
    }

    // If we get here, we found a Blorb but no Z-Code in it?
    // Or parsing failed. Return null to indicate failure.
    return null;
  }
}
