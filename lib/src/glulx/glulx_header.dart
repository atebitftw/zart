import 'dart:typed_data';

import 'package:zart/src/glulx/glulx_exception.dart';

/// The Glulx header (the first 36 bytes of memory).
///
/// Spec: "The header is the first 36 bytes of memory. It is always in ROM,
/// so its contents cannot change during execution. The header is organized
/// as nine 32-bit values. (Recall that values in memory are always big-endian.)"
class GlulxHeader {
  /// Size of the header in bytes.
  ///
  /// Spec: "The header is the first 36 bytes of memory."
  static const int size = 36;

  /// The expected magic number value (ASCII 'Glul').
  ///
  /// Spec: "Magic number: 47 6C 75 6C, which is to say ASCII 'Glul'."
  static const int expectedMagicNumber = 0x476C756C;

  /// Offset for the magic number field.
  static const int magicNumberOffset = 0x00;

  /// Offset for the version field.
  static const int versionOffset = 0x04;

  /// Offset for the RAMSTART field.
  static const int ramStartOffset = 0x08;

  /// Offset for the EXTSTART field.
  static const int extStartOffset = 0x0C;

  /// Offset for the ENDMEM field.
  static const int endMemOffset = 0x10;

  /// Offset for the stack size field.
  static const int stackSizeOffset = 0x14;

  /// Offset for the start function field.
  static const int startFuncOffset = 0x18;

  /// Offset for the decoding table field.
  static const int decodingTblOffset = 0x1C;

  /// Offset for the checksum field.
  static const int checksumOffset = 0x20;

  final Uint8List _data;
  late final ByteData _view;

  /// Creates a new [GlulxHeader] from the given bytes.
  ///
  /// Throws a [GlulxException] if the data is too short.
  GlulxHeader(Uint8List data) : _data = Uint8List(size) {
    if (data.length < size) {
      throw GlulxException('Glulx header must be at least $size bytes.');
    }
    // Copy header bytes
    for (var i = 0; i < size; i++) {
      _data[i] = data[i];
    }
    _view = ByteData.view(_data.buffer);
  }

  /// Magic number: 47 6C 75 6C, which is to say ASCII 'Glul'.
  ///
  /// Spec: "Magic number: 47 6C 75 6C, which is to say ASCII 'Glul'."
  int get magicNumber => _view.getUint32(magicNumberOffset, Endian.big);

  /// Glulx version number as a single 32-bit value.
  ///
  /// Spec: "The upper 16 bits stores the major version number; the next 8 bits
  /// stores the minor version number; the low 8 bits stores an even more
  /// minor version number, if any."
  int get version => _view.getUint32(versionOffset, Endian.big);

  /// Major version number (upper 16 bits of version field).
  ///
  /// Spec: "The upper 16 bits stores the major version number."
  int get majorVersion => (version >> 16) & 0xFFFF;

  /// Minor version number (bits 8-15 of version field).
  ///
  /// Spec: "The next 8 bits stores the minor version number."
  int get minorVersion => (version >> 8) & 0xFF;

  /// Subminor version number (low 8 bits of version field).
  ///
  /// Spec: "The low 8 bits stores an even more minor version number, if any."
  int get subminorVersion => version & 0xFF;

  /// Returns a human-readable version string (e.g., "3.1.3").
  String get versionString => '$majorVersion.$minorVersion.$subminorVersion';

  /// RAMSTART: The first address which the program can write to.
  ///
  /// Spec: "RAMSTART: The first address which the program can write to."
  int get ramStart => _view.getUint32(ramStartOffset, Endian.big);

  /// EXTSTART: The end of the game-file's stored initial memory.
  ///
  /// Spec: "EXTSTART: The end of the game-file's stored initial memory
  /// (and therefore the length of the game file.)"
  int get extStart => _view.getUint32(extStartOffset, Endian.big);

  /// ENDMEM: The end of the program's memory map.
  ///
  /// Spec: "ENDMEM: The end of the program's memory map."
  int get endMem => _view.getUint32(endMemOffset, Endian.big);

  /// Stack size: The size of the stack needed by the program.
  ///
  /// Spec: "Stack size: The size of the stack needed by the program."
  int get stackSize => _view.getUint32(stackSizeOffset, Endian.big);

  /// Address of function to execute: Execution commences by calling this function.
  ///
  /// Spec: "Address of function to execute: Execution commences by calling this function."
  int get startFunc => _view.getUint32(startFuncOffset, Endian.big);

  /// Address of string-decoding table: This table is used to decode compressed strings.
  ///
  /// Spec: "Address of string-decoding table: This table is used to decode
  /// compressed strings. This may be zero, indicating that no compressed
  /// strings are to be decoded."
  int get decodingTbl => _view.getUint32(decodingTblOffset, Endian.big);

  /// Checksum: A simple sum of the entire initial contents of memory.
  ///
  /// Spec: "Checksum: A simple sum of the entire initial contents of memory,
  /// considered as an array of big-endian 32-bit integers. The checksum
  /// should be computed with this field set to zero."
  int get checksum => _view.getUint32(checksumOffset, Endian.big);

  /// Validates the magic number and the Glulx version number.
  ///
  /// Spec: "The interpreter should validate the magic number and the Glulx
  /// version number. An interpreter which is written to version X.Y.Z of
  /// this specification should accept game files whose Glulx version between
  /// X.0.0 and X.Y.*."
  ///
  /// Spec: "EXCEPTION: A version 3.* interpreter should accept version 2.0
  /// game files. Therefore, an interpreter written to this version of the
  /// spec (3.1.3) should accept game files whose version is between 2.0.0
  /// and 3.1.* (0x00020000 and 0x000301FF inclusive)."
  void validate() {
    if (magicNumber != expectedMagicNumber) {
      throw GlulxException(
        'Invalid Glulx magic number: 0x${magicNumber.toRadixString(16).padLeft(8, '0')}',
      );
    }

    // Spec version 3.1.3 accepts 2.0.0 to 3.1.*
    if (version < 0x00020000 || version > 0x000301FF) {
      throw GlulxException(
        'Incompatible Glulx version: $versionString (0x${version.toRadixString(16).padLeft(8, '0')})',
      );
    }
  }

  /// Computes the checksum of the given memory contents.
  ///
  /// Spec: "Checksum: A simple sum of the entire initial contents of memory,
  /// considered as an array of big-endian 32-bit integers. The checksum
  /// should be computed with this field set to zero."
  ///
  /// The [memory] should be the complete initial memory contents.
  /// Returns the computed checksum as a 32-bit unsigned integer.
  static int computeChecksum(Uint8List memory) {
    // Pad memory to a multiple of 4 bytes if necessary
    final paddedLength = (memory.length + 3) & ~3;
    final padded =
        memory.length == paddedLength ? memory : Uint8List(paddedLength)
          ..setRange(0, memory.length, memory);

    final view = ByteData.view(padded.buffer);
    int sum = 0;

    for (var i = 0; i < paddedLength; i += 4) {
      if (i == checksumOffset) {
        // Skip the checksum field itself (treat as zero)
        continue;
      }
      sum = (sum + view.getUint32(i, Endian.big)) & 0xFFFFFFFF;
    }

    return sum;
  }

  /// Verifies the checksum of the given memory contents against the stored checksum.
  ///
  /// Returns `true` if the computed checksum matches the stored checksum.
  /// This is used by the `verify` opcode.
  static bool verifyChecksum(Uint8List memory) {
    if (memory.length < size) return false;

    final storedChecksum = ByteData.view(
      memory.buffer,
    ).getUint32(checksumOffset, Endian.big);
    final computed = computeChecksum(memory);
    return storedChecksum == computed;
  }

  /// Returns the raw header bytes (for serialization/IFhd chunk).
  ///
  /// Spec (Save-Game Format): "The contents of the game-file identifier
  /// ('IFhd' chunk) are simply the first 128 bytes of memory."
  /// Note: This returns only the 36-byte header, not full 128 bytes.
  Uint8List get rawData => _data;
}
