import 'dart:typed_data';

import 'package:zart/src/loaders/iff.dart';
import 'package:zart/src/logging.dart' show log;

/// Image format types supported by Blorb.
enum BlorbImageFormat {
  /// PNG image format.
  png,

  /// JPEG image format.
  jpeg,
}

/// An image resource from a Blorb file.
class BlorbImage {
  /// The image format (PNG or JPEG).
  final BlorbImageFormat format;

  /// The raw image data bytes.
  final Uint8List data;

  /// Creates a new BlorbImage.
  BlorbImage({required this.format, required this.data});
}

/// A sound resource from a Blorb file.
class BlorbSound {
  /// The sound format chunk type (e.g., 'AIFF', 'OGGV', 'MOD ').
  final String format;

  /// The raw sound data bytes.
  final Uint8List data;

  /// Creates a new BlorbSound.
  BlorbSound({required this.format, required this.data});
}

/// Resource index entry parsed from Blorb RIdx chunk.
class _ResourceEntry {
  /// Usage type (Pict, Snd, Exec, Data).
  final Chunk usage;

  /// Resource number.
  final int number;

  /// Byte offset from start of file to resource chunk.
  final int start;

  _ResourceEntry({
    required this.usage,
    required this.number,
    required this.start,
  });
}

/// Manages resources from a Blorb file.
///
/// Parses the resource index on construction and provides
/// methods to retrieve images and sounds by resource ID.
///
/// Blorb Spec: "The first chunk in the FORM must be a resource index
/// (chunk type 'RIdx'.) This lists all the resources stored in the IFRS FORM."
class BlorbResourceManager {
  /// The raw Blorb file bytes.
  final Uint8List _bytes;

  /// Parsed resource index entries.
  final List<_ResourceEntry> _resources = [];

  /// Creates a BlorbResourceManager from Blorb file bytes.
  ///
  /// Parses the resource index immediately.
  BlorbResourceManager(this._bytes) {
    _parseResourceIndex();
  }

  /// Parse the RIdx chunk to build resource index.
  void _parseResourceIndex() {
    if (_bytes.length < 12) return;

    // Verify FORM header
    final formTag = String.fromCharCodes(_bytes.sublist(0, 4));
    if (formTag != 'FORM') {
      log.warning('BlorbResourceManager: Not an IFF FORM');
      return;
    }

    // Skip FORM length (4 bytes)
    // Verify IFRS type
    final ifrsTag = String.fromCharCodes(_bytes.sublist(8, 12));
    if (ifrsTag != 'IFRS') {
      log.warning('BlorbResourceManager: Not an IFRS Blorb file');
      return;
    }

    // Parse chunks starting at offset 12
    int offset = 12;
    while (offset + 8 <= _bytes.length) {
      final chunkType = String.fromCharCodes(
        _bytes.sublist(offset, offset + 4),
      );
      final chunkLength = _read4Bytes(offset + 4);

      if (chunkType == 'RIdx') {
        // Found resource index
        _parseRIdx(offset + 8, chunkLength);
        break; // RIdx should be first, we're done
      }

      // Skip to next chunk (pad to even)
      offset += 8 + chunkLength + (chunkLength % 2);
    }
  }

  /// Parse RIdx chunk contents.
  void _parseRIdx(int dataOffset, int length) {
    if (dataOffset + 4 > _bytes.length) return;

    final numResources = _read4Bytes(dataOffset);
    int offset = dataOffset + 4;

    for (int i = 0; i < numResources; i++) {
      if (offset + 12 > _bytes.length) break;

      final usageStr = String.fromCharCodes(_bytes.sublist(offset, offset + 4));
      final usage = Chunk.toChunk(usageStr);
      final number = _read4Bytes(offset + 4);
      final start = _read4Bytes(offset + 8);

      if (usage != null) {
        _resources.add(
          _ResourceEntry(usage: usage, number: number, start: start),
        );
      }

      offset += 12;
    }

    log.info('BlorbResourceManager: Parsed ${_resources.length} resources');
  }

  /// Read a big-endian 4-byte integer at the given offset.
  int _read4Bytes(int offset) {
    return (_bytes[offset] << 24) |
        (_bytes[offset + 1] << 16) |
        (_bytes[offset + 2] << 8) |
        _bytes[offset + 3];
  }

  /// Get an image resource by its number.
  ///
  /// Returns null if the resource doesn't exist or is not an image.
  BlorbImage? getImage(int resourceId) {
    // Find the resource entry
    final entry = _resources.firstWhere(
      (e) => e.usage == Chunk.pict && e.number == resourceId,
      orElse: () => _ResourceEntry(usage: Chunk.pict, number: -1, start: -1),
    );

    if (entry.start < 0 || entry.start + 8 > _bytes.length) {
      return null;
    }

    // Read the chunk at entry.start
    final chunkType = String.fromCharCodes(
      _bytes.sublist(entry.start, entry.start + 4),
    );
    final chunkLength = _read4Bytes(entry.start + 4);

    if (entry.start + 8 + chunkLength > _bytes.length) {
      log.warning('BlorbResourceManager: Image chunk $resourceId truncated');
      return null;
    }

    final data = Uint8List.sublistView(
      _bytes,
      entry.start + 8,
      entry.start + 8 + chunkLength,
    );

    BlorbImageFormat? format;
    if (chunkType == 'PNG ') {
      format = BlorbImageFormat.png;
    } else if (chunkType == 'JPEG') {
      format = BlorbImageFormat.jpeg;
    } else {
      log.warning('BlorbResourceManager: Unknown image format: $chunkType');
      return null;
    }

    return BlorbImage(format: format, data: data);
  }

  /// Get a sound resource by its number.
  ///
  /// Returns null if the resource doesn't exist or is not a sound.
  BlorbSound? getSound(int resourceId) {
    // Find the resource entry
    final entry = _resources.firstWhere(
      (e) => e.usage == Chunk.snd && e.number == resourceId,
      orElse: () => _ResourceEntry(usage: Chunk.snd, number: -1, start: -1),
    );

    if (entry.start < 0 || entry.start + 8 > _bytes.length) {
      return null;
    }

    // Read the chunk at entry.start
    final chunkType = String.fromCharCodes(
      _bytes.sublist(entry.start, entry.start + 4),
    );
    final chunkLength = _read4Bytes(entry.start + 4);

    if (entry.start + 8 + chunkLength > _bytes.length) {
      log.warning('BlorbResourceManager: Sound chunk $resourceId truncated');
      return null;
    }

    final data = Uint8List.sublistView(
      _bytes,
      entry.start + 8,
      entry.start + 8 + chunkLength,
    );

    return BlorbSound(format: chunkType, data: data);
  }

  /// Check if a picture resource exists.
  bool hasImage(int resourceId) {
    return _resources.any(
      (e) => e.usage == Chunk.pict && e.number == resourceId,
    );
  }

  /// Check if a sound resource exists.
  bool hasSound(int resourceId) {
    return _resources.any(
      (e) => e.usage == Chunk.snd && e.number == resourceId,
    );
  }

  /// Get all picture resource IDs.
  List<int> get imageIds => _resources
      .where((e) => e.usage == Chunk.pict)
      .map((e) => e.number)
      .toList();

  /// Get all sound resource IDs.
  List<int> get soundIds => _resources
      .where((e) => e.usage == Chunk.snd)
      .map((e) => e.number)
      .toList();
}
