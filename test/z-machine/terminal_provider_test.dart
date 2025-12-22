import 'package:test/test.dart';
import 'package:zart/src/cli/ui/z_terminal_display.dart';
import 'package:zart/src/cli/ui/z_machine_io_dispatcher.dart';
import 'package:zart/src/io/platform/platform_capabilities.dart';
import 'package:zart/src/io/platform/platform_provider.dart';
import 'package:zart/src/zart_internal.dart';

// Mock TerminalDisplay to capture calls
class MockTerminalDisplay extends ZTerminalDisplay {
  // Capture outputs
  final List<String> window1Writes = [];
  final List<int> stylesSet = [];
  int cursorRow = 0;
  int cursorCol = 0;
  int splitLines = 0;

  @override
  int get cols => 80;

  @override
  int get rows => 24;

  @override
  void writeToWindow1(String text) {
    window1Writes.add(text);
  }

  @override
  void setStyle(int style) {
    stylesSet.add(style);
  }

  @override
  void setCursor(int row, int col) {
    cursorRow = row;
    cursorCol = col;
  }

  @override
  void splitWindow(int lines) {
    splitLines = lines;
  }

  // Stubs for other methods not tested here
  @override
  void enterFullScreen() {}
  @override
  void exitFullScreen() {}
  @override
  void showPreamble(List<String> lines) {}
  @override
  void clearWindow1() {}
  @override
  void clearWindow0() {}
  @override
  void clearAll() {}
  @override
  Map<String, int> getCursor() => {'row': cursorRow, 'column': cursorCol};
  @override
  void setColors(int fg, int bg) {}
  @override
  void appendToWindow0(String text) {}
  @override
  void render() {}

  // Private members not needed for mock interface
  // Private members not needed for mock interface
  // @override
  // dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockPlatformProvider extends PlatformProvider {
  @override
  PlatformCapabilities get capabilities =>
      const PlatformCapabilities.terminal(width: 80, height: 24);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('TerminalProvider', () {
    late MockTerminalDisplay mockDisplay;
    late ZMachineIoDispatcher provider;

    setUp(() {
      mockDisplay = MockTerminalDisplay();
      provider = ZMachineIoDispatcher(mockDisplay, MockPlatformProvider());
    });

    test(
      'IoCommands.status renders correctly with Bold+Reverse style',
      () async {
        final command = {
          'command': ZIoCommands.status,
          'room_name': 'Kitchen',
          'score_one': '10',
          'score_two': '20',
          'game_type': 'SCORE', // Score/Moves game
        };

        await provider.command(command);

        // Verify Split Window forced (since default height 0)
        expect(mockDisplay.splitLines, equals(1));

        // Verify Style was set to 3 (Bold + Reverse)
        expect(mockDisplay.stylesSet, contains(3));

        // Verify Content Written
        // Room Name
        expect(mockDisplay.window1Writes, contains(' Kitchen'));

        // Padding (spaces)
        expect(
          mockDisplay.window1Writes.any(
            (s) => s.trim().isEmpty && s.isNotEmpty,
          ),
          isTrue,
        );

        // Score
        expect(mockDisplay.window1Writes, contains('Score: 10 Moves: 20 '));

        // Verify Reset Style
        expect(mockDisplay.stylesSet.last, equals(0));
      },
    );
  });
}
