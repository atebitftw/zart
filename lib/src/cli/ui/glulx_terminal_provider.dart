import 'package:zart/src/cli/ui/terminal_display.dart';
import 'package:zart/src/io/glk/glk_gestalt_selectors.dart' show GlkGestaltSelectors;
import 'package:zart/src/io/glk/glk_io_provider.dart';
import 'package:zart/src/io/glk/glk_io_selectors.dart';

/// IO provider for Glulx interpreter.
class GlulxTerminalProvider implements GlkIoProvider {
  /// The terminal display.
  final TerminalDisplay terminal;

  /// Creates a new GlulxTerminalProvider.
  GlulxTerminalProvider(this.terminal);

  @override
  Future<int> glkDispatch(int selector, List<int> args) async {
    switch (selector) {
      case GlkIoSelectors.tick:
        // yield back to Dart's event loop, per the Glk spec
        await Future.delayed(const Duration(milliseconds: 1));
        return 0;
      case GlkIoSelectors.gestalt:
        return await _gestaltHandler(args[0], args.sublist(1));
      case GlkIoSelectors.putChar:
        // glk_put_char(ch) - output single character
        terminal.appendToWindow0(String.fromCharCode(args[0]));
        return 0;
      case GlkIoSelectors.putCharStream:
        // glk_put_char_stream(str, ch) - args[0] is stream, args[1] is char
        terminal.appendToWindow0(String.fromCharCode(args[1]));
        return 0;
      case GlkIoSelectors.putCharUni:
        // glk_put_char_uni(ch) - Unicode character output
        terminal.appendToWindow0(String.fromCharCode(args[0]));
        return 0;
      case GlkIoSelectors.getCharStream:
        // Currently used by interpreter for char output (args[0]=stream, args[1]=char)
        terminal.appendToWindow0(String.fromCharCode(args[1]));
        return 0;
      default:
        return 0;
    }
  }

  Future<int> _gestaltHandler(int gestaltSelector, List<int> args) async {
    switch (gestaltSelector) {
      case GlkGestaltSelectors.version:
        // We will try to support the latest version at the time of this implementation.
        // The current version of the API is: 0.7.6 (0x00070600)
        return 0x00070600;
      default:
        return 0;
    }
  }
}
