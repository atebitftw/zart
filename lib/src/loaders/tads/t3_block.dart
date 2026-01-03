import 'dart:typed_data';

/// Represents a data block in a T3 image file.
///
/// Each block has:
/// - Type ID: 4-byte ASCII identifier
/// - Size: 4-byte little-endian size of block data (not including header)
/// - Flags: 2-byte little-endian flags
/// - Data: Variable-length block content
///
/// The block header is 10 bytes total.
class T3Block {
  /// Size of the block header in bytes.
  static const int headerSize = 10;

  /// Block type ID offset.
  static const int typeOffset = 0;

  /// Block size offset.
  static const int sizeOffset = 4;

  /// Block flags offset.
  static const int flagsOffset = 8;

  // Common block type constants
  static const String typeEntrypoint = 'ENTP';
  static const String typeConstPoolDef = 'CPDF';
  static const String typeConstPoolPage = 'CPPG';
  static const String typeMetaclassDep = 'MCLD';
  static const String typeFunctionSetDep = 'FNSD';
  static const String typeSymbolicNames = 'SYMD';
  static const String typeStaticObjects = 'OBJS';
  static const String typeMultimediaRes = 'MRES';
  static const String typeMultimediaLink = 'MREL';
  static const String typeSourceFiles = 'SRCF';
  static const String typeGlobalSymbols = 'GSYM';
  static const String typeMethodHeaders = 'MHLS';
  static const String typeMacros = 'MACR';
  static const String typeStaticInit = 'SINI';
  static const String typeEof = 'EOF ';

  /// Flag indicating the block must be understood by the interpreter.
  static const int flagMandatory = 0x0001;

  /// The 4-character block type identifier.
  final String type;

  /// The size of the block data in bytes (not including header).
  final int dataSize;

  /// The block flags.
  final int flags;

  /// The offset of the block data in the file.
  final int dataOffset;

  /// Creates a T3Block with the given properties.
  T3Block({required this.type, required this.dataSize, required this.flags, required this.dataOffset});

  /// Returns true if this block is mandatory (must be understood by the interpreter).
  bool get isMandatory => (flags & flagMandatory) != 0;

  /// Returns true if this is the EOF block.
  bool get isEof => type == typeEof;

  /// The total size of this block including header.
  int get totalSize => headerSize + dataSize;

  /// Parses a block header from bytes at the given offset.
  ///
  /// Returns a [T3Block] with the parsed header information.
  /// The [fileOffset] is the position in the file where the block header starts.
  static T3Block parseHeader(Uint8List data, int offset, int fileOffset) {
    final view = ByteData.view(data.buffer, data.offsetInBytes + offset);

    // Read 4-character type ID
    final typeBytes = data.sublist(offset, offset + 4);
    final type = String.fromCharCodes(typeBytes);

    // Read size (little-endian 32-bit)
    final size = view.getUint32(sizeOffset, Endian.little);

    // Read flags (little-endian 16-bit)
    final flags = view.getUint16(flagsOffset, Endian.little);

    return T3Block(type: type, dataSize: size, flags: flags, dataOffset: fileOffset + headerSize);
  }

  @override
  String toString() =>
      'T3Block(type: "$type", size: $dataSize, flags: 0x${flags.toRadixString(16)}, mandatory: $isMandatory)';
}
