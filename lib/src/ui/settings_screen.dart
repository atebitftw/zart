import 'package:zart/src/ui/terminal_display.dart';
import 'package:zart/src/config/configuration_manager.dart';

/// A settings screen for the Zart CLI application.
class SettingsScreen {
  /// The terminal display.
  final TerminalDisplay terminal;

  /// The configuration manager.
  final ConfigurationManager config;

  /// Creates a new settings screen.
  SettingsScreen(this.terminal, this.config);

  /// Shows the settings screen.
  Future<void> show({bool isGameStarted = false}) async {
    /// Hide status bar while in settings
    final wasStatusBarEnabled = terminal.enableStatusBar;
    terminal.enableStatusBar = false;

    /// Disable F1 handler to prevent recursive open
    final oldOnOpenSettings = terminal.onOpenSettings;
    terminal.onOpenSettings = null;

    try {
      // Save game screen state (windows, text buffer, etc)
      terminal.saveState();

      // Reset window split so settings use full screen
      terminal.splitWindow(0);
      // Ensure we are not in "input mode" effectively, or just rely on clearAll
      // Input mode state is also part of what might be saved/restored if stored in TerminalDisplay?
      // TerminalDisplay._inputLine etc are NOT part of ScreenModel save currently.
      // They are in TerminalDisplay.
      // We might need to reset them too if we want a clean slate?
      // But SettingsScreen loop uses its own input calls.
      // Let's just reset splitWindow for layout.

      while (true) {
        terminal.clearAll();
        terminal.appendToWindow0('Zart Settings\n');
        terminal.appendToWindow0(
          '------------------------------------------------\n',
        );

        final bindings = config.bindings;
        if (bindings.isEmpty) {
          terminal.appendToWindow0('No macros defined.\n');
        } else {
          bindings.forEach((key, val) {
            terminal.appendToWindow0('$key -> "$val"\n');
          });
          terminal.appendToWindow0('\n');
        }

        terminal.appendToWindow0(
          '------------------------------------------------\n',
        );
        terminal.appendToWindow0('[A] Add Binding   [D] Delete Binding\n');

        // Context-aware exit message
        if (isGameStarted) {
          terminal.appendToWindow0('[R] Resume Game\n');
        } else {
          terminal.appendToWindow0('[R] Start Game\n');
        }

        terminal.render();

        final input = await terminal.readChar();
        final lowerChar = input.toLowerCase();

        if (lowerChar == 'r') {
          break; // Exit loop
        } else if (lowerChar == 'a') {
          await _addBinding();
        } else if (lowerChar == 'd') {
          await _deleteBinding();
        }
      }

      // Restore screen state
      terminal.restoreState();

      // Restore Status Bar setting
      terminal.enableStatusBar = wasStatusBarEnabled;

      // Refresh main screen on exit
      terminal.render();
    } finally {
      // Restore F1 handler
      terminal.onOpenSettings = oldOnOpenSettings;
    }
  }

  Future<void> _addBinding() async {
    terminal.appendToWindow0(
      '\n\nPress Ctrl+Key combination to bind (or Esc to cancel): ',
    );
    terminal.render();

    // We need to read a key and see if it is a Ctrl char
    // We can't reuse terminal.readChar easily because it converts to string
    // Let's assume we can catch it.
    // Actually, TerminalDisplay.readChar returns a string, but we need the raw Key object
    // effectively to verify it's a control character.
    // For now, let's ask the user to type the letter, e.g. "a" for Ctrl+A

    // Better approach: Ask for the letter to bind to Ctrl.
    terminal.appendToWindow0('\nEnter letter `x` for Ctrl+x: ');
    terminal.render();

    final charKey = await terminal.readChar();
    if (charKey.isEmpty || charKey.length > 1) {
      terminal.appendToWindow0('\nInvalid input.\n');
      await _wait(1);
      return;
    }

    final keyName = 'ctrl+${charKey.toLowerCase()}';

    terminal.appendToWindow0('\nEnter command for $keyName: ');
    terminal.render();
    final cmd = await terminal.readLine();

    if (cmd.isNotEmpty) {
      config.setBinding(keyName, cmd);
      terminal.appendToWindow0('\nBound $keyName to "$cmd".\n');
    } else {
      terminal.appendToWindow0('\nCancelled.\n');
    }
    await _wait(1);
  }

  Future<void> _deleteBinding() async {
    terminal.appendToWindow0('\n\nEnter letter `x` to delete Ctrl+x binding: ');
    terminal.render();

    final charKey = await terminal.readChar();
    final keyName = 'ctrl+${charKey.toLowerCase()}';

    if (config.getBinding(keyName) != null) {
      config.setBinding(keyName, null);
      terminal.appendToWindow0('\nDeleted binding for $keyName.\n');
    } else {
      terminal.appendToWindow0('\nNo binding found for $keyName.\n');
    }
    await _wait(1);
  }

  Future<void> _wait(int seconds) {
    return Future.delayed(Duration(seconds: seconds));
  }
}
