import 'dart:typed_data';

import 'package:zart/src/loaders/tads/t3_block.dart';
import 'package:zart/src/loaders/tads/t3_exception.dart';
import 'package:zart/src/loaders/tads/t3_header.dart';

/// Parser for T3 image files.
///
/// A T3 image file consists of:
/// 1. A 69-byte header with signature, version, and timestamp
/// 2. A sequence of data blocks, each with a 10-byte block header
/// 3. An EOF block indicating the end of the file
///
/// Usage:
/// ```dart
/// final image = T3Image(fileBytes);
/// image.validate();
/// for (final block in image.blocks) {
///   print('Block: ${block.type}, size: ${block.dataSize}');
/// }
/// ```
class T3Image {
  /// The raw file data.
  final Uint8List _data;

  /// The parsed header.
  late final T3Header header;

  /// The parsed blocks.
  late final List<T3Block> blocks;

  /// Creates a new [T3Image] from the given file bytes.
  ///
  /// Parses the header and enumerates all blocks.
  /// Throws a [T3Exception] if the file is too short or malformed.
  T3Image(Uint8List data) : _data = data {
    if (data.length < T3Header.size) {
      throw T3Exception('File too short to be a valid T3 image.');
    }

    header = T3Header(data);
    blocks = _parseBlocks();
  }

  /// Parses all blocks in the file.
  List<T3Block> _parseBlocks() {
    final result = <T3Block>[];
    var offset = T3Header.size;

    while (offset + T3Block.headerSize <= _data.length) {
      final block = T3Block.parseHeader(_data, offset, offset);
      result.add(block);

      // Stop at EOF block
      if (block.isEof) break;

      // Move to next block
      offset += block.totalSize;
    }

    return result;
  }

  /// Validates the image file.
  ///
  /// Checks the header signature, version, and verifies that an EOF block exists.
  /// Throws a [T3Exception] if validation fails.
  void validate() {
    header.validate();

    if (blocks.isEmpty) {
      throw T3Exception('No blocks found in T3 image.');
    }

    // Check for EOF block
    if (!blocks.any((b) => b.isEof)) {
      throw T3Exception('No EOF block found in T3 image.');
    }
  }

  /// Returns the block data for a given block.
  Uint8List getBlockData(T3Block block) {
    if (block.dataOffset + block.dataSize > _data.length) {
      throw T3Exception('Block data extends beyond file: offset=${block.dataOffset}, size=${block.dataSize}');
    }
    return _data.sublist(block.dataOffset, block.dataOffset + block.dataSize);
  }

  /// Finds blocks by type.
  List<T3Block> findBlocks(String type) {
    return blocks.where((b) => b.type == type).toList();
  }

  /// Finds the first block of the given type, or null if not found.
  T3Block? findBlock(String type) {
    for (final block in blocks) {
      if (block.type == type) return block;
    }
    return null;
  }

  /// Returns the entrypoint block, or null if not found.
  T3Block? get entrypointBlock => findBlock(T3Block.typeEntrypoint);

  /// Returns the total number of blocks (including EOF).
  int get blockCount => blocks.length;

  @override
  String toString() => 'T3Image(version: ${header.version}, timestamp: "${header.timestamp}", blocks: $blockCount)';
}
