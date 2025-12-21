import 'package:zart/src/cli/ui/terminal_colors.dart';
import 'package:zart/src/cli/config/configuration_manager.dart';
import 'package:zart/src/cli/ui/zart_terminal.dart';
import 'package:zart/zart.dart';

/// A settings screen for the Zart CLI application.
class SettingsScreen {
  /// The terminal display.
  final ZartTerminal terminal;

  /// The configuration manager.
  final ConfigurationManager config;

  /// Creates a new settings screen.
  SettingsScreen(this.terminal, this.config);

  /// Allowed keys for custom key bindings.
  static const _allowedKeys = [
    'q',
    'w',
    'e',
    'r',
    't',
    'y',
    'u',
    'i',
    'o',
    'p',
    'a',
    's',
    'd',
    'f',
    'g',
    'h',
    'j',
    'k',
    'l',
  ];

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

      while (true) {
        terminal.clearAll();
        terminal.setColors(TerminalColors.yellow, TerminalColors.defaultColor); // yellow
        terminal.appendToWindow0(getPreamble().join('\n'));
        terminal.setColors(TerminalColors.white, TerminalColors.blue);
        terminal.appendToWindow0('\nSETTINGS\n');
        terminal.setColors(TerminalColors.defaultColor, TerminalColors.defaultColor);
        if (isGameStarted) {
          terminal.appendToWindow0('[R] Resume Game\n');
        } else {
          terminal.appendToWindow0('[R] Start Game\n');
        }
        terminal.appendToWindow0('\n------------------------------------------------\n');
        terminal.setColors(TerminalColors.white, TerminalColors.blue);
        terminal.appendToWindow0('ZART BAR\n');
        terminal.setColors(TerminalColors.defaultColor, TerminalColors.defaultColor);
        terminal.appendToWindow0('[V] Visibility: ${config.zartBarVisible ? 'ON' : 'OFF'}\n');
        terminal.appendToWindow0('[F] Foreground Color\n');
        terminal.appendToWindow0('[B] Background Color\n');
        terminal.setColors(config.zartBarForeground, config.zartBarBackground);
        terminal.appendToWindow0(' [ ZART BAR STYLE PREVIEW ] ');
        terminal.setColors(TerminalColors.defaultColor, TerminalColors.defaultColor);
        terminal.appendToWindow0('\n\n------------------------------------------------\n');
        terminal.setColors(TerminalColors.white, TerminalColors.blue);
        terminal.appendToWindow0('CUSTOM KEY BINDINGS (Ctrl+Key)\n');
        terminal.setColors(TerminalColors.defaultColor, TerminalColors.defaultColor);
        terminal.appendToWindow0('Allowed Keys: ${_allowedKeys.join(', ')}\n\n');
        terminal.appendToWindow0('[A] Add Binding\n');
        terminal.appendToWindow0('[D] Delete Binding\n');

        final bindings = config.bindings;
        if (bindings.isEmpty) {
          terminal.appendToWindow0('No macros defined.\n');
        } else {
          bindings.forEach((key, val) {
            terminal.appendToWindow0('$key -> "$val"\n');
          });
          terminal.appendToWindow0('\n');
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
        } else if (lowerChar == 'v') {
          config.zartBarVisible = !config.zartBarVisible;
        } else if (lowerChar == 'f') {
          // Cycle foreground 2-10
          var c = config.zartBarForeground + 1;
          if (c > 10) c = 2;
          config.zartBarForeground = c;
        } else if (lowerChar == 'b') {
          // Cycle background 2-10
          var c = config.zartBarBackground + 1;
          if (c > 10) c = 2;
          config.zartBarBackground = c;
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
    terminal.appendToWindow0('\n\nPress Ctrl+Key combination to bind (or Esc to cancel): ');
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

    final lowerKey = charKey.toLowerCase();
    if (!_allowedKeys.contains(lowerKey)) {
      terminal.appendToWindow0('\nKey "$lowerKey" is not allowed for binding.\n');
      terminal.appendToWindow0('Allowed: ${_allowedKeys.join(',')}\n');
      await _wait(2);
      return;
    }

    final keyName = 'ctrl+$lowerKey';

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
