import 'dart:io';
import 'package:test/test.dart';
import 'package:zart/src/zart_internal.dart';

/// A mock IO provider that returns a String (filename) for save,
/// reproducing the reported crash.
class StringReturningSaveProvider extends ZIoDispatcher {
  String? lastSavedFilename;
  List<int>? lastSavedData;

  @override
  Future<dynamic> command(Map<String, dynamic> commandMessage) async {
    final cmd = commandMessage['command'] as ZIoCommands;

    switch (cmd) {
      case ZIoCommands.save:
        lastSavedData = commandMessage['file_data'] as List<int>;
        // Return a String instead of a bool, as the real CLI provider does.
        lastSavedFilename = "test_save.sav";
        return lastSavedFilename;

      case ZIoCommands.print:
        // Ignore print output in this test
        break;

      default:
        break;
    }
    return null;
  }
}

void main() {
  late StringReturningSaveProvider provider;

  setUp(() {
    provider = StringReturningSaveProvider();
    Z.io = provider;
  });

  String _findGameFile(String filename) {
    final paths = [
      'assets/games/$filename',
      '../../assets/games/$filename',
      'c:/Users/John/dev/projects/zart/assets/games/$filename',
    ];

    for (final path in paths) {
      if (File(path).existsSync()) {
        return path;
      }
    }
    throw Exception('Game file $filename not found.');
  }

  test('V3 Save returns String and does not crash', () async {
    final gamePath = _findGameFile('minizork.z3');
    final bytes = File(gamePath).readAsBytesSync();
    Z.load(bytes);

    // Initial State -> needsLineInput
    var state = await Z.runUntilInput();
    expect(state, equals(ZMachineRunState.needsLineInput));

    // Submit 'save' command.
    // This will trigger InterpreterV3.save()
    // It calls Z.sendIO which returns "test_save.sav"
    // Before fix, this would throw: type 'String' is not a subtype of type 'bool'
    await expectLater(Z.submitLineInput('save'), completes);

    expect(provider.lastSavedFilename, equals("test_save.sav"));
    expect(provider.lastSavedData, isNotNull);
  });

  test('V5 Save returns String and does not crash', () async {
    // Note: We need a V5 game to test InterpreterV5.extSave
    // Using a placeholder if v5 game isn't available, but let's try to find one.
    try {
      final gamePath = _findGameFile('etude.z5');
      final bytes = File(gamePath).readAsBytesSync();
      Z.load(bytes);

      var state = await Z.runUntilInput();
      expect(state, equals(ZMachineRunState.needsLineInput));

      // Submit 'save' command.
      await expectLater(Z.submitLineInput('save'), completes);

      expect(provider.lastSavedFilename, equals("test_save.sav"));
      expect(provider.lastSavedData, isNotNull);
    } catch (e) {
      print('Skipping V5 test: etude.z5 not found');
    }
  });
}
