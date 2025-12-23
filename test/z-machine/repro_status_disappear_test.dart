import 'dart:io';
import 'package:test/test.dart';
import 'package:zart/src/zart_internal.dart';
import 'mock_ui_provider.dart';

void main() {
  late MockUIProvider mockUi;

  setUp(() {
    mockUi = MockUIProvider();
    Z.io = mockUi;
    // We'll use a real game file if possible, or just a mock setup
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

  test('Status line should persist and update after turn 1', () async {
    final gamePath = _findGameFile('minizork.z3');
    final bytes = File(gamePath).readAsBytesSync();
    Z.load(bytes);

    // 1. Initial run until Turn 1 prompt
    await Z.runUntilInput();

    // Check status line commands sent during init/Turn 1
    var statusCalls = mockUi.commandLog.where((c) => c['command'] == ZIoCommands.status).toList();
    print('Turn 1 status calls: ${statusCalls.length}');
    for (var call in statusCalls) {
      print('  Status: room="${call['room_name']}", score=${call['score_one']}, moves=${call['score_two']}');
    }

    expect(statusCalls, isNotEmpty, reason: 'Should send status initially');
    lastStatus = statusCalls.last;
    expect(lastStatus['room_name'], isNotEmpty);

    // 2. Perform a move (e.g., "south")
    mockUi.commandLog.clear();
    print('--- Entering "south" ---');
    await Z.submitLineInput('south');

    // 3. Check status line commands after Turn 1 processing
    statusCalls = mockUi.commandLog.where((c) => c['command'] == ZIoCommands.status).toList();
    print('Turn 2 status calls: ${statusCalls.length}');
    for (var call in statusCalls) {
      print('  Status: room="${call['room_name']}", score=${call['score_one']}, moves=${call['score_two']}');
    }

    // According to user, after first input, it disappears.
    // If it disappears, we might see room_name = "" or empty status call.
    expect(statusCalls, isNotEmpty, reason: 'Status should be updated for Turn 2');
    var turn2Status = statusCalls.last;
    expect(turn2Status['room_name'], isNotEmpty, reason: 'Room name should not be empty');
  });
}

dynamic lastStatus;
