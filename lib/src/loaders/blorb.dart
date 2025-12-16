import 'dart:typed_data';

import 'package:zart/src/loaders/iff.dart';

/// Detects and loads Z game file component, if present.
class Blorb {
  /// This function only needs the first 12 bytes of
  /// the file data in order to return a result.
  static bool isBlorb(List fileBytes) {
    // Ensure we are working with a growable list for consumption
    var stream = List.from(fileBytes);

    if (stream.length < 12) return false;

    if (IFF.readChunk(stream) != Chunk.form) return false;

    // Skip size (4 bytes)
    IFF.read4Byte(stream);

    if (IFF.readChunk(stream) != Chunk.ifrs) return false;

    return true;
  }

  /// Attempts to extract the Z-Machine game file data from the Blorb
  /// file bytes in [fileBytes].  If the file is not a Blorb type, then the
  /// original bytes are returned (assumes it's a valid compiled ZIL file.)
  static Uint8List? getZData(Uint8List fileBytes) {
    // Check if it is a Blorb file.
    if (fileBytes.length < 12 ||
        !isBlorb(List.from(fileBytes.getRange(0, 12)))) {
      return fileBytes;
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
                }
              }
            }
          }
        }
        // If we processed RIdx but didn't return, continue loop?
        // Usually RIdx is unique. If we didn't find Exec, maybe failure?
        // But let's continue parsing just in case.
        // Also we consumed the stream inside the loop.
        // Wait, the loop consumed `numResources * 12` bytes.
        // We need to ensure we align with `chunkSize`.
        // Ideally we should just rely on paddedSize to skip,
        // but since we read FROM the stream, `stream` is already advanced by `numResources * 12`.
        // But `chunkSize` includes `numResources` (4 bytes) + assignments.
        // So actual bytes read = 4 + (numResources * 12).
        // If `chunkSize` matches that, we are good.
        // If not, we might be desync.
        // Because we manually read the RIdx body, `stream` should be at the end of RIdx body.
        // But let's be safe: sublist is safer way to jump, but we are consuming.
        // If we trust our parsing, `stream` is correct.
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
