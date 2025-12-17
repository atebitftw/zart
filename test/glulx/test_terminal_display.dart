import 'package:zart/src/cli/ui/terminal_display.dart';

/// A minimal TerminalDisplay implementation for unit testing.
/// Captures all output to a StringBuffer for verification without
/// actually rendering to any terminal.
class TestTerminalDisplay extends TerminalDisplay {
  final StringBuffer _buffer = StringBuffer();

  /// The captured output.
  String get output => _buffer.toString();

  /// Clear the captured output.
  void clearOutput() => _buffer.clear();

  @override
  void appendToWindow0(String text) {
    _buffer.write(text);
  }

  @override
  void writeToWindow1(String text) {
    // No-op for tests
  }

  // Override render to do nothing (avoid terminal output)
  @override
  void render() {
    // No-op for tests
  }

  // Override enterFullScreen to avoid terminal mode changes
  @override
  void enterFullScreen() {
    // No-op for tests
  }

  // Override exitFullScreen to avoid terminal mode changes
  @override
  void exitFullScreen() {
    // No-op for tests
  }
}
