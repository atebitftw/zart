import 'dart:typed_data';

import 'package:zart/src/loaders/blorb.dart';

/// Enumerates story file types.
enum GameFileType {
  /// Z-Machine Game File
  z,

  /// Glulx Game File
  glulx,

  /// TADS 3 Game File
  tads,
}

/// Unified game file loader that detects and loads game data from various formats.
///
/// Supports:
/// - Z-Machine files (.z3, .z5, .z8, etc.)
/// - Glulx files (.ulx, .gblorb)
/// - Blorb containers (.zblorb, .gblorb)
/// - TADS 3 files (.t3)
class GameLoader {
  /// T3 image file signature: "T3-image\r\n\x1A"
  static const _t3Signature = [0x54, 0x33, 0x2D, 0x69, 0x6D, 0x61, 0x67, 0x65, 0x0D, 0x0A, 0x1A];

  /// Glulx magic number: "Glul"
  static const _glulxMagic = [0x47, 0x6C, 0x75, 0x6C];

  /// Detects the game file type and extracts the game data.
  ///
  /// Returns a tuple of (gameData, fileType) or (null, null) if unrecognized.
  static (Uint8List?, GameFileType?) load(Uint8List fileBytes) {
    // Check for TADS 3 file first (most specific signature)
    if (_isT3File(fileBytes)) {
      return (fileBytes, GameFileType.tads);
    }

    // Check for Blorb container (IFF-based, contains Z or Glulx)
    if (Blorb.isBlorbFile(fileBytes)) {
      return Blorb.extractGameData(fileBytes);
    }

    // Check for raw Glulx file
    if (_isGlulxFile(fileBytes)) {
      return (fileBytes, GameFileType.glulx);
    }

    // Check for raw Z-machine file
    if (_isZMachineFile(fileBytes)) {
      return (fileBytes, GameFileType.z);
    }

    return (null, null);
  }

  /// Checks if the file is a TADS 3 image file.
  ///
  /// T3 files start with the signature "T3-image\r\n\x1A" (11 bytes).
  static bool _isT3File(Uint8List fileBytes) {
    if (fileBytes.length < _t3Signature.length) return false;

    for (int i = 0; i < _t3Signature.length; i++) {
      if (fileBytes[i] != _t3Signature[i]) return false;
    }
    return true;
  }

  /// Checks if the file is a raw Glulx game file.
  ///
  /// Glulx files start with magic bytes "Glul" (0x47, 0x6C, 0x75, 0x6C).
  static bool _isGlulxFile(Uint8List fileBytes) {
    if (fileBytes.length < _glulxMagic.length) return false;

    for (int i = 0; i < _glulxMagic.length; i++) {
      if (fileBytes[i] != _glulxMagic[i]) return false;
    }
    return true;
  }

  /// Checks if the file is a raw Z-machine game file.
  ///
  /// Z-machine files start with a version byte (1-8), not a magic string.
  static bool _isZMachineFile(Uint8List fileBytes) {
    if (fileBytes.isEmpty) return false;
    // Z-machine version is the first byte, valid versions are 1-8
    final version = fileBytes[0];
    return version >= 1 && version <= 8;
  }
}
