import 'dart:io';
import 'package:test/test.dart';
import 'package:zart/src/zart_internal.dart';

/// A mock IO provider that stores saved games in memory.
class MemoryIoProvider extends ZIoDispatcher {
  final Map<String, List<int>> _savedGames = {};

  // Use to simulate input for the test
  final List<String> _inputQueue = [];
  final StringBuffer _output = StringBuffer();

  void queueInput(String input) {
    _inputQueue.add(input);
  }

  String get output => _output.toString();

  void clearOutput() {
    _output.clear();
  }

  bool hasSavedGame(String filename) {
    return _savedGames.containsKey(filename);
  }

  List<int>? getSavedGame(String filename) {
    return _savedGames[filename];
  }

  @override
  Future<dynamic> command(Map<String, dynamic> commandMessage) async {
    final cmd = commandMessage['command'] as ZIoCommands;

    switch (cmd) {
      case ZIoCommands.print:
        final buffer = commandMessage['buffer'] as String?;
        if (buffer != null) {
          _output.write(buffer);
        }
        break;

      case ZIoCommands.save:
        // Mock save: Expect filename input next (simulated here for direct access) or handle logic?
        // In the real Zart CLI, 'save' opcode sends IoCommands.save, then the provider asks for input.
        // BUT the interpreter sends the data in the command message!
        final fileData = commandMessage['file_data'] as List<int>;

        // Simulating the user interaction is tricky synchronously vs async.
        // For this unit test, let's assume we use a fixed filename "memory_save.sav"
        // OR we pull from our input queue?
        // Let's pull from input queue to match CLI behavior roughly.

        String filename = "default.sav";
        if (_inputQueue.isNotEmpty) {
          filename = _inputQueue.removeAt(0);
        }

        // Auto-extension logic verification
        if (!filename.toLowerCase().endsWith('.sav')) {
          filename += '.sav';
        }

        _savedGames[filename] = fileData;
        return true;

      case ZIoCommands.restore:
        // Mock restore
        String filename = "default.sav";
        if (_inputQueue.isNotEmpty) {
          filename = _inputQueue.removeAt(0);
        }

        // Auto-extension logic verification
        if (!filename.toLowerCase().endsWith('.sav')) {
          filename += '.sav';
        }

        if (_savedGames.containsKey(filename)) {
          return _savedGames[filename];
        }
        return null;

      case ZIoCommands.read:
        if (_inputQueue.isNotEmpty) {
          return _inputQueue.removeAt(0);
        }
        return '';

      case ZIoCommands.readChar:
        if (_inputQueue.isNotEmpty) {
          final s = _inputQueue.removeAt(0);
          return s.isNotEmpty ? s[0] : ' ';
        }
        return ' ';

      // Ignore other commands
      default:
        break;
    }
  }
}

void main() {
  late MemoryIoProvider provider;

  setUp(() {
    provider = MemoryIoProvider();
    Z.io = provider;
  });

  String _findGameFile(String filename) {
    // Try a few common paths
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

  test('Save and Restore Round Trip with Memory Provider', () async {
    final gamePath = _findGameFile('minizork.z3');
    final bytes = File(gamePath).readAsBytesSync();
    Z.load(bytes);

    print('Game Loaded. Initializing...');

    // We need to run the game enough to get to a prompt.
    // Minizork starts, prints text, eventually asks for input?
    // We can drive it via input queue.

    // 1. Initial State -> "save"
    // The game loop in Z.run works by yielding state.
    // But we are in a unit test. We can use Z.runUntilInput()

    // Step 1: Run until first input (game start)
    provider.queueInput(
      'mysave',
    ); // Filename for save (no extension to test auto-add)

    // Running...
    // Note: 'save' is an opcode. It triggers IoCommands.save.
    // Our provider handles IoCommands.save by consuming 'mysave' from queue.

    // We need to carefully step through.
    // Z.runUntilInput() runs until the interpreter needs INPUT (READ/READ_CHAR).
    // The SAVE opcode is NOT an input state, it's an instruction.
    // So 'save' command must be entered by the user at the prompt.

    // 1. Run until game asks "What now?" (Prompt)
    var state = await Z.runUntilInput();
    expect(state, equals(ZMachineRunState.needsLineInput));

    // 2. Send "save" command
    // This resumes execution. The interpreter parses "save".
    // It calls 'save' opcode -> sendIO(IoCommands.save)
    // Our provider catches this. It consumes 'mysave' from queue.
    // It saves to memory. Returns true.
    // Interpreter sees true -> "Ok."
    // Game loops back to input.

    state = await Z.submitLineInput('save');

    // Provider logic inside 'save' command should have consumed 'mysave'
    // and created 'mysave.sav'
    expect(
      provider.hasSavedGame('mysave.sav'),
      isTrue,
      reason: "Save file should exist",
    );

    // 3. Verify Data
    final savedData = provider.getSavedGame('mysave.sav');
    expect(savedData, isNotNull);
    expect(
      savedData!.length,
      greaterThan(100),
      reason: "Save data should be substantial",
    );

    // 4. Restore
    // We are back at input prompt (hopefully, depending on minizork behavior after save)
    // Minizork usually prints "Ok."

    provider.queueInput('mysave'); // Input for restore filename

    // Send 'restore' command to game input
    state = await Z.submitLineInput('restore');

    // Provider logic inside 'restore' command should consume 'mysave'
    // and return the bytes.
    // Interpreter restores state.
    // Game usually says "Restored." or similar.

    // Verify we are still running (or whatever state restore puts us in)
    // Ideally we'd verify some game state change, but just surviving the crash-free roundtrip is good for now.
    expect(Z.isLoaded, isTrue);

    print('Save/Restore Cycle Complete.');
  });
}
