import 'dart:io';
import 'package:zart/src/zart_internal.dart';
import 'package:test/test.dart';

/// Test IoProvider that collects output for verification
class TestProvider extends ZIoDispatcher {
  final StringBuffer output = StringBuffer();
  final List<Map<String, dynamic>> commands = [];

  @override
  Future<dynamic> command(Map<String, dynamic> ioData) async {
    commands.add(ioData);

    final cmd = ioData['command'] as ZIoCommands?;

    switch (cmd) {
      case ZIoCommands.print:
        output.write(ioData['buffer'] ?? '');
        return null;
      case ZIoCommands.status:
        // Ignore status updates for test
        return null;
      case ZIoCommands.quit:
        return null;
      default:
        // For other commands, return null
        return null;
    }
  }

  void clear() {
    output.clear();
    commands.clear();
  }
}

void main() {
  late TestProvider provider;

  setUp(() {
    provider = TestProvider();
    Z.io = provider;
  });

  group('Pump API Tests', () {
    test(
      'runUntilInput returns needsLineInput when game needs input',
      () async {
        final gamePath = _findGameFile();
        final bytes = File(gamePath).readAsBytesSync();

        Z.load(bytes.toList());

        final state = await Z.runUntilInput();

        expect(
          state,
          equals(ZMachineRunState.needsLineInput),
          reason: 'Game should pause waiting for line input',
        );

        // Verify some intro text was printed
        final outputText = provider.output.toString().toLowerCase();
        expect(
          outputText.contains('zork') || outputText.contains('west of house'),
          isTrue,
          reason: 'Should have printed some intro text: ${provider.output}',
        );

        print('==== Initial Output ====');
        print(provider.output.toString());
      },
    );

    test('submitLineInput processes "open mailbox" command correctly', () async {
      final gamePath = _findGameFile();
      final bytes = File(gamePath).readAsBytesSync();

      Z.load(bytes.toList());

      // Run until first input prompt
      var state = await Z.runUntilInput();
      expect(state, equals(ZMachineRunState.needsLineInput));

      // Clear output to only see response to our command
      provider.clear();

      // Submit "open mailbox" command
      state = await Z.submitLineInput('open mailbox');

      expect(
        state,
        equals(ZMachineRunState.needsLineInput),
        reason: 'Game should pause waiting for next input',
      );

      // Verify the response mentions the leaflet
      final outputText = provider.output.toString().toLowerCase();
      expect(
        outputText.contains('leaflet') ||
            outputText.contains('opening') ||
            outputText.contains('small mailbox'),
        isTrue,
        reason:
            'Response should mention leaflet or opening the mailbox: ${provider.output}',
      );

      print('==== "open mailbox" Response ====');
      print(provider.output.toString());
    });

    test('multiple commands work in sequence', () async {
      final gamePath = _findGameFile();
      final bytes = File(gamePath).readAsBytesSync();

      Z.load(bytes.toList());

      // Run until first input prompt
      var state = await Z.runUntilInput();
      expect(state, equals(ZMachineRunState.needsLineInput));

      // Command 1: look
      provider.clear();
      state = await Z.submitLineInput('look');
      expect(state, equals(ZMachineRunState.needsLineInput));

      final lookOutput = provider.output.toString().toLowerCase();
      expect(
        lookOutput.contains('west of house') ||
            lookOutput.contains('white house'),
        isTrue,
        reason: 'Look should describe location',
      );

      print('==== "look" Response ====');
      print(provider.output.toString());

      // Command 2: open mailbox
      provider.clear();
      state = await Z.submitLineInput('open mailbox');
      expect(state, equals(ZMachineRunState.needsLineInput));

      final openOutput = provider.output.toString().toLowerCase();
      expect(
        openOutput.contains('leaflet') || openOutput.contains('opening'),
        isTrue,
        reason: 'Should mention leaflet',
      );

      print('==== "open mailbox" Response ====');
      print(provider.output.toString());

      // Command 3: take leaflet
      provider.clear();
      state = await Z.submitLineInput('take leaflet');
      expect(state, equals(ZMachineRunState.needsLineInput));

      print('==== "take leaflet" Response ====');
      print(provider.output.toString());
    });
  });
}

String _findGameFile() {
  // Try multiple paths
  final paths = [
    'assets/games/minizork.z3',
    '../../assets/games/minizork.z3',
    'e:/dev/projects/zart/assets/games/minizork.z3',
  ];

  for (final path in paths) {
    if (File(path).existsSync()) {
      return path;
    }
  }

  throw Exception(
    'Game file not found. Tried: $paths. CWD: ${Directory.current.path}',
  );
}
