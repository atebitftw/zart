import 'package:zart/src/cli/ui/terminal_display.dart';
import 'package:zart/zart.dart';

/// IO provider for Glulx interpreter.
class GlulxTerminalProvider implements IoProvider {
  /// The terminal display.
  final TerminalDisplay terminal;

  /// Creates a new GlulxTerminalProvider.
  GlulxTerminalProvider(this.terminal);

  @override
  int getFlags1() => 0;

  @override
  Future<dynamic> command(Map<String, dynamic> commandMessage) async {
    // not used in the glulx terminal provider
    return null;
  }

  @override
  Future<int> glulxGlk(int selector, List<int> args) {
    terminal.appendToWindow0("GlulxTerminalProvider: Got selector: $selector with args: [${args.join(', ')}]");
    return Future.value(0);
  }
}
