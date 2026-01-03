import 'dart:typed_data';

import 'package:zart/src/loaders/game_loader.dart';
import 'package:zart/src/loaders/iff.dart';
import 'package:zart/src/logging.dart' show log;

/// Blorb container file loader for Z-machine and Glulx games.
///
/// Blorb files are IFF containers that can hold:
/// - Z-machine code (ZCOD chunks)
/// - Glulx code (GLUL chunks)
/// - Images, sounds, and other resources
class Blorb {
  /// Returns true if the file is a Blorb container (.zblorb or .gblorb).
  ///
  /// Blorb files are IFF files with FORM type IFRS.
  static bool isBlorbFile(Uint8List fileBytes) {
    if (fileBytes.length < 12) return false;

    var stream = List<int>.from(fileBytes);

    if (IFF.readChunk(stream) != Chunk.form) return false;

    // Skip size (4 bytes)
    IFF.read4Byte(stream);

    // Check for interactive fiction resource chunk
    if (IFF.readChunk(stream) != Chunk.ifrs) return false;

    return true;
  }

  /// Extracts game data from a Blorb container.
  ///
  /// Returns a tuple of (gameData, fileType) or (null, null) if no game found.
  static (Uint8List?, GameFileType?) extractGameData(Uint8List fileBytes) {
    var stream = List<int>.from(fileBytes);

    // Header (already verified by isBlorbFile, but we need to consume it)
    IFF.readChunk(stream); // FORM
    IFF.read4Byte(stream); // Size
    IFF.readChunk(stream); // IFRS

    while (stream.isNotEmpty) {
      if (stream.length < 8) break;

      var chunkType = IFF.readChunk(stream);
      var chunkSize = IFF.read4Byte(stream);
      var paddedSize = chunkSize + (chunkSize % 2);

      if (chunkType == Chunk.ridx) {
        // Parse Resource Index
        var numResources = IFF.read4Byte(stream);

        for (int i = 0; i < numResources; i++) {
          var usage = IFF.readChunk(stream);
          IFF.read4Byte(stream); // number (unused)
          var start = IFF.read4Byte(stream);

          if (usage == Chunk.exec && start < fileBytes.length && start + 8 <= fileBytes.length) {
            // Check for ZCOD (Z-machine)
            if (_matchesChunk(fileBytes, start, Chunk.zcod)) {
              final data = _extractChunkData(fileBytes, start);
              if (data != null) return (data, GameFileType.z);
            }
            // Check for GLUL (Glulx)
            else if (_matchesChunk(fileBytes, start, Chunk.glul)) {
              final data = _extractChunkData(fileBytes, start);
              if (data != null) return (data, GameFileType.glulx);
            }
          }
        }
      } else {
        // Skip this chunk
        if (paddedSize > 0 && paddedSize <= stream.length) {
          stream.removeRange(0, paddedSize);
        } else {
          break;
        }
      }
    }

    log.warning("Unable to extract game data from Blorb file.");
    return (null, null);
  }

  /// Checks if bytes at offset match a chunk type.
  static bool _matchesChunk(Uint8List bytes, int offset, Chunk chunk) {
    if (offset + 4 > bytes.length) return false;
    return bytes[offset] == chunk[0] &&
        bytes[offset + 1] == chunk[1] &&
        bytes[offset + 2] == chunk[2] &&
        bytes[offset + 3] == chunk[3];
  }

  /// Extracts chunk data from an IFF chunk at the given offset.
  static Uint8List? _extractChunkData(Uint8List bytes, int offset) {
    if (offset + 8 > bytes.length) return null;

    // Read chunk size (big-endian)
    int len = (bytes[offset + 4] << 24) | (bytes[offset + 5] << 16) | (bytes[offset + 6] << 8) | bytes[offset + 7];

    if (offset + 8 + len <= bytes.length) {
      return Uint8List.fromList(bytes.sublist(offset + 8, offset + 8 + len));
    }
    return null;
  }
}
