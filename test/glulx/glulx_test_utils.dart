import 'dart:io';
import 'dart:typed_data';
import 'package:zart/src/loaders/game_loader.dart';
import 'package:zart/src/loaders/blorb.dart';

class GlulxTestUtils {
  static Uint8List? _cachedTestGame;

  static Uint8List loadTestGame(String path) {
    if (_cachedTestGame != null) {
      return _cachedTestGame!;
    }
    final file = File(path);
    if (!file.existsSync()) {
      throw Exception('Test game file not found: $path');
    }

    final bytes = file.readAsBytesSync();

    if (Blorb.isBlorbFile(bytes)) {
      final (storyData, type) = GameLoader.load(bytes);
      if (storyData == null) {
        throw Exception('No story data found in Blorb file: $path');
      }
      _cachedTestGame = storyData;
      return storyData;
    }

    _cachedTestGame = bytes;
    return bytes;
  }
}
