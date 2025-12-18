import 'dart:typed_data';

import 'package:zart/src/glulx/glulx_exception.dart';

/// The Glulx header (the first 36 bytes of memory).
///
/// It is organized as nine 32-bit big-endian values.
/// See [Glulx Spec](packages/ifarchive-if-specs/Glulx-Spec.md) L188-L224.
class GlulxHeader {
  /// Size of the header (36 bytes).
  static const int size = 36;

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
  GlulxHeader(Uint8List data) : _data = Uint8List.fromList(data.sublist(0, size)) {
    if (data.length < size) {
      throw GlulxException('Glulx header must be at least $size bytes.');
    }
    _view = ByteData.view(_data.buffer);
  }

  /// Magic number: 47 6C 75 6C, which is ASCII 'Glul'.
  int get magicNumber => _view.getUint32(magicNumberOffset, Endian.big);

  /// Glulx version number.
  /// Upper 16 bits: major; next 8 bits: minor; low 8 bits: subminor.
  int get version => _view.getUint32(versionOffset, Endian.big);

  /// RAMSTART: The first address which the program can write to.
  int get ramStart => _view.getUint32(ramStartOffset, Endian.big);

  /// EXTSTART: The end of the game-file's stored initial memory (and length of file).
  int get extStart => _view.getUint32(extStartOffset, Endian.big);

  /// ENDMEM: The end of the program's memory map.
  int get endMem => _view.getUint32(endMemOffset, Endian.big);

  /// Stack size: The size of the stack needed by the program.
  int get stackSize => _view.getUint32(stackSizeOffset, Endian.big);

  /// Address of function to execute: Execution commences by calling this function.
  int get startFunc => _view.getUint32(startFuncOffset, Endian.big);

  /// Address of string-decoding table: This table is used to decode compressed strings.
  /// This may be zero, indicating that no compressed strings are to be decoded.
  int get decodingTbl => _view.getUint32(decodingTblOffset, Endian.big);

  /// Checksum: A simple sum of the entire initial contents of memory,
  /// considered as an array of big-endian 32-bit integers.
  int get checksum => _view.getUint32(checksumOffset, Endian.big);

  /// Validates the magic number and the Glulx version number.
  ///
  /// An interpreter which is written to version X.Y.Z of this specification
  /// should accept game files whose Glulx version is between X.0.0 and X.Y.*.
  ///
  /// EXCEPTION: A version 3.* interpreter should accept version 2.0 game files.
  /// An interpreter written to this version of the spec (3.1.3) should accept
  /// game files whose version is between 2.0.0 and 3.1.* (0x00020000 and 0x000301FF inclusive).
  void validate() {
    if (magicNumber != 0x476C756C) {
      throw GlulxException('Invalid Glulx magic number: 0x${magicNumber.toRadixString(16).padLeft(8, '0')}');
    }

    // Spec version 3.1.3 accepts 2.0.0 to 3.1.*
    if (version < 0x00020000 || version > 0x000301FF) {
      throw GlulxException('Incompatible Glulx version: 0x${version.toRadixString(16).padLeft(8, '0')}');
    }
  }
}
