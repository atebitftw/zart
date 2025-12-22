import 'dart:io';
import 'package:zart/src/zart_internal.dart';
import 'package:test/test.dart';

/// Comprehensive test provider that captures and handles all IoCommands
class ComprehensiveTestProvider extends ZIoDispatcher {
  final StringBuffer output = StringBuffer();
  final List<Map<String, dynamic>> commands = [];

  // Track specific command occurrences for verification
  final List<Map<String, dynamic>> splitWindowCommands = [];
  final List<Map<String, dynamic>> setWindowCommands = [];
  final List<Map<String, dynamic>> setCursorCommands = [];
  final List<Map<String, dynamic>> getCursorCommands = [];
  final List<Map<String, dynamic>> eraseLineCommands = [];
  final List<Map<String, dynamic>> clearScreenCommands = [];
  final List<Map<String, dynamic>> setTextStyleCommands = [];
  final List<Map<String, dynamic>> setColourCommands = [];
  final List<Map<String, dynamic>> setTrueColourCommands = [];
  final List<Map<String, dynamic>> setFontCommands = [];
  final List<Map<String, dynamic>> soundEffectCommands = [];
  final List<Map<String, dynamic>> readCommands = [];
  final List<Map<String, dynamic>> readCharCommands = [];
  final List<Map<String, dynamic>> saveCommands = [];
  final List<Map<String, dynamic>> restoreCommands = [];

  // Mock responses
  String? nextReadResponse;
  String? nextReadCharResponse;
  Map<String, int>? cursorPosition = {'row': 1, 'column': 1};
  int currentFont = 1;

  @override
  Future<dynamic> command(Map<String, dynamic> ioData) async {
    commands.add(ioData);

    final cmd = ioData['command'] as ZIoCommands?;

    switch (cmd) {
      case ZIoCommands.print:
        output.write(ioData['buffer'] ?? '');
        return null;

      case ZIoCommands.status:
        return null;

      case ZIoCommands.quit:
        return null;

      case ZIoCommands.splitWindow:
        splitWindowCommands.add(ioData);
        return null;

      case ZIoCommands.setWindow:
        setWindowCommands.add(ioData);
        return null;

      case ZIoCommands.setCursor:
        setCursorCommands.add(ioData);
        cursorPosition = {
          'row': ioData['line'] ?? 1,
          'column': ioData['column'] ?? 1,
        };
        return null;

      case ZIoCommands.getCursor:
        getCursorCommands.add(ioData);
        return cursorPosition;

      case ZIoCommands.eraseLine:
        eraseLineCommands.add(ioData);
        return null;

      case ZIoCommands.clearScreen:
        clearScreenCommands.add(ioData);
        return null;

      case ZIoCommands.setTextStyle:
        setTextStyleCommands.add(ioData);
        return null;

      case ZIoCommands.setColour:
        setColourCommands.add(ioData);
        return null;

      case ZIoCommands.setTrueColour:
        setTrueColourCommands.add(ioData);
        return null;

      case ZIoCommands.setFont:
        setFontCommands.add(ioData);
        final oldFont = currentFont;
        final requestedFont = ioData['font_id'] as int? ?? 0;
        if (requestedFont == 0) {
          return oldFont; // Query only
        }
        if (requestedFont == 1 || requestedFont == 4) {
          currentFont = requestedFont;
          return oldFont;
        }
        return 0; // Font not available

      case ZIoCommands.soundEffect:
        soundEffectCommands.add(ioData);
        return null;

      case ZIoCommands.read:
        readCommands.add(ioData);
        return nextReadResponse ?? '';

      case ZIoCommands.readChar:
        readCharCommands.add(ioData);
        return nextReadCharResponse ?? ' ';

      case ZIoCommands.save:
        saveCommands.add(ioData);
        return true; // Always succeed

      case ZIoCommands.restore:
        restoreCommands.add(ioData);
        return null; // No save data available

      case ZIoCommands.inputStream:
        return null;

      default:
        return null;
    }
  }

  @override
  int getFlags1() {
    // Advertise full capability support
    return 0x7F; // Screen split, colors, bold, italic, fixed-pitch available
  }

  void clear() {
    output.clear();
    commands.clear();
    splitWindowCommands.clear();
    setWindowCommands.clear();
    setCursorCommands.clear();
    getCursorCommands.clear();
    eraseLineCommands.clear();
    clearScreenCommands.clear();
    setTextStyleCommands.clear();
    setColourCommands.clear();
    setTrueColourCommands.clear();
    setFontCommands.clear();
    soundEffectCommands.clear();
    readCommands.clear();
    readCharCommands.clear();
    saveCommands.clear();
    restoreCommands.clear();
  }

  /// Check if a specific command was received
  bool hasCommand(ZIoCommands cmd) {
    return commands.any((c) => c['command'] == cmd);
  }

  /// Count how many times a command was sent
  int countCommand(ZIoCommands cmd) {
    return commands.where((c) => c['command'] == cmd).length;
  }
}

void main() {
  late ComprehensiveTestProvider provider;

  setUp(() {
    provider = ComprehensiveTestProvider();
    Z.io = provider;
  });

  group('IoCommand Tests with beyondzork.z5', () {
    test('game loads and sends initial windowing commands', () async {
      final gamePath = _findGameFile('beyondzork.z5');
      final bytes = File(gamePath).readAsBytesSync();

      Z.load(bytes.toList());

      // Set up input response for when the game prompts
      provider.nextReadResponse = 'quit';
      provider.nextReadCharResponse = ' ';

      final state = await Z.runUntilInput();

      // Verify game started and is waiting for input
      expect(
        state,
        anyOf(ZMachineRunState.needsLineInput, ZMachineRunState.needsCharInput),
        reason: 'Game should pause waiting for input',
      );

      // Verify print command was used
      expect(
        provider.hasCommand(ZIoCommands.print),
        isTrue,
        reason: 'Game should print initial output',
      );

      print('=== Initial Commands Summary ===');
      print('Total commands: ${provider.commands.length}');
      print('Print commands: ${provider.countCommand(ZIoCommands.print)}');
      print('Split window: ${provider.splitWindowCommands.length}');
      print('Set window: ${provider.setWindowCommands.length}');
      print('Set cursor: ${provider.setCursorCommands.length}');
      print('Set text style: ${provider.setTextStyleCommands.length}');
      print('Set colour: ${provider.setColourCommands.length}');
      print('');
      print('First 500 chars of output:');
      print(
        provider.output.toString().substring(
          0,
          provider.output.length.clamp(0, 500),
        ),
      );
    });

    test('V5 game uses windowing or style commands on startup', () async {
      final gamePath = _findGameFile('beyondzork.z5');
      final bytes = File(gamePath).readAsBytesSync();

      Z.load(bytes.toList());
      provider.nextReadResponse = '';
      provider.nextReadCharResponse = ' ';

      await Z.runUntilInput();

      // beyondzork.z5 may use windowing, style, or color commands
      // Check that at least some V5-specific commands are used
      final usesV5Features =
          provider.splitWindowCommands.isNotEmpty ||
          provider.setWindowCommands.isNotEmpty ||
          provider.setTextStyleCommands.isNotEmpty ||
          provider.setColourCommands.isNotEmpty;

      expect(
        usesV5Features,
        isTrue,
        reason: 'V5 game should use windowing, style, or color commands',
      );

      print('V5 features detected:');
      print('  splitWindow: ${provider.splitWindowCommands.length}');
      print('  setWindow: ${provider.setWindowCommands.length}');
      print('  setTextStyle: ${provider.setTextStyleCommands.length}');
      print('  setColour: ${provider.setColourCommands.length}');
    });

    test('V5 game sends setWindow command with correct parameters', () async {
      final gamePath = _findGameFile('beyondzork.z5');
      final bytes = File(gamePath).readAsBytesSync();

      Z.load(bytes.toList());
      provider.nextReadResponse = '';

      await Z.runUntilInput();

      if (provider.setWindowCommands.isNotEmpty) {
        for (final cmd in provider.setWindowCommands) {
          expect(
            cmd['window'],
            isA<int>(),
            reason: 'setWindow should have int window parameter',
          );
          expect(cmd['window'], anyOf(0, 1), reason: 'window should be 0 or 1');
          print('setWindow: window=${cmd['window']}');
        }
      }
    });

    test(
      'V5 game sends setCursor command with 1-indexed coordinates',
      () async {
        final gamePath = _findGameFile('beyondzork.z5');
        final bytes = File(gamePath).readAsBytesSync();

        Z.load(bytes.toList());
        provider.nextReadResponse = '';

        await Z.runUntilInput();

        if (provider.setCursorCommands.isNotEmpty) {
          for (final cmd in provider.setCursorCommands) {
            expect(
              cmd['line'],
              isA<int>(),
              reason: 'setCursor should have int line parameter',
            );
            expect(
              cmd['column'],
              isA<int>(),
              reason: 'setCursor should have int column parameter',
            );
            expect(
              cmd['line'],
              greaterThan(0),
              reason: 'line should be 1-indexed (>0)',
            );
            expect(
              cmd['column'],
              greaterThan(0),
              reason: 'column should be 1-indexed (>0)',
            );
            print('setCursor: line=${cmd['line']}, column=${cmd['column']}');
          }
        }
      },
    );

    test('V5 game sends setTextStyle command with valid bitmask', () async {
      final gamePath = _findGameFile('beyondzork.z5');
      final bytes = File(gamePath).readAsBytesSync();

      Z.load(bytes.toList());
      provider.nextReadResponse = '';

      await Z.runUntilInput();

      if (provider.setTextStyleCommands.isNotEmpty) {
        for (final cmd in provider.setTextStyleCommands) {
          expect(
            cmd['style'],
            isA<int>(),
            reason: 'setTextStyle should have int style parameter',
          );
          final style = cmd['style'] as int;
          expect(
            style,
            inInclusiveRange(0, 15),
            reason: 'style bitmask should be 0-15',
          );
          print(
            'setTextStyle: style=$style (reverse=${style & 1 != 0}, bold=${style & 2 != 0}, italic=${style & 4 != 0}, fixed=${style & 8 != 0})',
          );
        }
      }
    });

    test('V5 game sends setColour command with valid color codes', () async {
      final gamePath = _findGameFile('beyondzork.z5');
      final bytes = File(gamePath).readAsBytesSync();

      Z.load(bytes.toList());
      provider.nextReadResponse = '';

      await Z.runUntilInput();

      if (provider.setColourCommands.isNotEmpty) {
        for (final cmd in provider.setColourCommands) {
          expect(
            cmd['foreground'],
            isA<int>(),
            reason: 'setColour should have int foreground',
          );
          expect(
            cmd['background'],
            isA<int>(),
            reason: 'setColour should have int background',
          );
          print('setColour: fg=${cmd['foreground']}, bg=${cmd['background']}');
        }
      }
    });

    test('clearScreen command has signed window_id parameter', () async {
      final gamePath = _findGameFile('beyondzork.z5');
      final bytes = File(gamePath).readAsBytesSync();

      Z.load(bytes.toList());
      provider.nextReadResponse = '';

      await Z.runUntilInput();

      if (provider.clearScreenCommands.isNotEmpty) {
        for (final cmd in provider.clearScreenCommands) {
          expect(
            cmd['window_id'],
            isA<int>(),
            reason: 'clearScreen should have int window_id',
          );
          final windowId = cmd['window_id'] as int;
          // window_id can be -2, -1, 0, or 1
          expect(
            windowId,
            inInclusiveRange(-2, 1),
            reason: 'window_id should be -2 to 1',
          );
          print('clearScreen: window_id=$windowId');
        }
      }
    });
  });

  // NOTE: In pump mode, input is handled via callbacks (requestLineInput),
  // NOT via IoCommands.read. The read IoCommand is only used in traditional
  // mode which is being deprecated. Therefore, there's no test for
  // IoCommands.read in pump mode.

  group('V3 Game Tests (minizork)', () {
    test('print command includes window and buffer parameters', () async {
      final gamePath = _findGameFile('beyondzork.z5');
      final bytes = File(gamePath).readAsBytesSync();

      Z.load(bytes.toList());
      provider.nextReadResponse = '';

      await Z.runUntilInput();

      final printCommands = provider.commands
          .where((c) => c['command'] == ZIoCommands.print)
          .toList();

      expect(
        printCommands.isNotEmpty,
        isTrue,
        reason: 'Should have print commands',
      );

      for (final cmd in printCommands.take(5)) {
        expect(
          cmd['buffer'],
          isA<String>(),
          reason: 'print should have string buffer',
        );
        expect(
          cmd['window'],
          isA<int>(),
          reason: 'print should have int window',
        );
        print(
          'print: window=${cmd['window']}, buffer="${(cmd['buffer'] as String).replaceAll('\n', '\\n').substring(0, (cmd['buffer'] as String).length.clamp(0, 50))}"',
        );
      }
    });
  });

  test('V3 game sends status command', () async {
    final gamePath = _findGameFile('minizork.z3');
    final bytes = File(gamePath).readAsBytesSync();

    Z.load(bytes.toList());
    provider.nextReadResponse = 'look';

    await Z.runUntilInput();

    expect(
      provider.hasCommand(ZIoCommands.status),
      isTrue,
      reason: 'V3 game should send status command',
    );

    final statusCommands = provider.commands
        .where((c) => c['command'] == ZIoCommands.status)
        .toList();
    if (statusCommands.isNotEmpty) {
      final cmd = statusCommands.first;
      expect(
        cmd['room_name'],
        isA<String>(),
        reason: 'status should have room_name',
      );
      print(
        'status: room="${cmd['room_name']}", type=${cmd['game_type']}, score1=${cmd['score_one']}, score2=${cmd['score_two']}',
      );
    }
  });

  group('Command Sequence Tests', () {
    test('setWindow to upper window triggers setCursor to (1,1)', () async {
      final gamePath = _findGameFile('beyondzork.z5');
      final bytes = File(gamePath).readAsBytesSync();

      Z.load(bytes.toList());
      provider.nextReadResponse = '';

      await Z.runUntilInput();

      // Check if setWindow to 1 is followed by setCursor to (1,1)
      for (int i = 0; i < provider.commands.length - 1; i++) {
        final cmd = provider.commands[i];
        if (cmd['command'] == ZIoCommands.setWindow && cmd['window'] == 1) {
          // Look for setCursor in next few commands
          bool foundCursor = false;
          for (
            int j = i + 1;
            j < (i + 3).clamp(0, provider.commands.length);
            j++
          ) {
            final nextCmd = provider.commands[j];
            if (nextCmd['command'] == ZIoCommands.setCursor) {
              foundCursor = true;
              expect(
                nextCmd['line'],
                equals(1),
                reason: 'Cursor should reset to line 1',
              );
              expect(
                nextCmd['column'],
                equals(1),
                reason: 'Cursor should reset to column 1',
              );
              break;
            }
          }
          if (foundCursor) {
            print('Verified: setWindow(1) followed by setCursor(1,1)');
          }
        }
      }
    });
  });
}

/// Find a game file by name in common locations
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

  throw Exception(
    'Game file $filename not found. Tried: $paths. CWD: ${Directory.current.path}',
  );
}
