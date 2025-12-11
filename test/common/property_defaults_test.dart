import 'dart:io';
import 'package:test/test.dart';
import 'package:zart/zart.dart';
import 'package:zart/src/game_object.dart';
import '../mock_ui_provider.dart';
import 'package:zart/src/z_machine.dart';

void loadGame(String path) {
  final f = File(path);
  if (!f.existsSync()) {
    throw Exception('Game file not found: $path');
  }
  final rawBytes = f.readAsBytesSync();
  final data = Blorb.getZData(rawBytes);
  if (data == null) {
    throw Exception('Failed to load game data from $path');
  }
  Z.load(data);
  Z.io = MockUIProvider();
}

void main() {
  group('GameObject Property Defaults (Version Dependent)', () {
    test('V3 (Minizork) - Max 31 properties', () {
      loadGame('assets/games/minizork.z3');
      expect(Z.engine.version, equals(ZMachineVersions.v3), reason: 'Should be Version 3');

      // Should work for 1-31
      // Property defaults table is readable
      expect(GameObject.getPropertyDefault(1), isA<int>());
      expect(GameObject.getPropertyDefault(31), isA<int>());

      // Should throw for 32+ (V3 limit)
      expect(
        () => GameObject.getPropertyDefault(32),
        throwsA(isA<GameException>()),
        reason: 'Should throw for property 32 in V3',
      );
    });

    test('V5 (Adventureland) - Max 63 properties', () {
      loadGame('assets/games/adventureland.z5');
      expect(Z.engine.version, equals(ZMachineVersions.v5), reason: 'Should be Version 5');

      // Should work for 1-63
      expect(GameObject.getPropertyDefault(1), isA<int>());
      expect(GameObject.getPropertyDefault(31), isA<int>());

      // Property 35 (Description) - this was the bug location
      // In V5+, this should be valid and return a default value (usually 0 or similar)
      expect(GameObject.getPropertyDefault(35), isA<int>());

      expect(GameObject.getPropertyDefault(63), isA<int>());

      // Should throw for 64+ (V5 limit)
      expect(
        () => GameObject.getPropertyDefault(64),
        throwsA(isA<GameException>()),
        reason: 'Should throw for property 64 in V5',
      );
    });

    test('V8 (Anchorhead) - Max 63 properties', () {
      loadGame('assets/games/anchor.z8');
      expect(Z.engine.version, equals(ZMachineVersions.v8), reason: 'Should be Version 8');

      // Should work for 1-63
      expect(GameObject.getPropertyDefault(1), isA<int>());
      expect(GameObject.getPropertyDefault(35), isA<int>(), reason: 'Property 35 should be valid in V8');
      expect(GameObject.getPropertyDefault(63), isA<int>());

      // Should throw for 64+
      expect(
        () => GameObject.getPropertyDefault(64),
        throwsA(isA<GameException>()),
        reason: 'Should throw for property 64 in V8',
      );
    });
  });
}
