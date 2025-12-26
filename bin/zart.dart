import 'dart:io';

import 'package:zart/src/cli/cli_platform_provider.dart';
import 'package:zart/zart.dart';

// Zart CLI - A terminal-based player for Z-Machine and Inform games.
void main(List<String> args) async {
  if (args.isEmpty) {
    stdout.writeln(_usage());
    exit(1);
  }

  final file = File(args.first);
  if (!file.existsSync()) {
    stdout.writeln(_usage());
    exit(1);
  }

  // This is the CLI implementation of the PlatformProvider API.
  // It handles all platform-specific IO operations (rendering, input, save/restore).
  final provider = CliPlatformProvider(gameName: args.first);

  // Instantiate the GameRunner with the CLI PlatformProvider.
  final runner = GameRunner(provider);

  try {
    // Run the game.  GameRunner takes care of the rest.
    await runner.run(file.readAsBytesSync());
    runner.dispose();
    exit(0);
  } on GameRunnerException catch (e) {
    stderr.writeln('Zart GameRunnerException Error: ${e.message}');
    exit(1);
  } catch (e, stack) {
    stderr.writeln('Zart Error: $e\n$stack');
    exit(1);
  }
}

String _usage() => '''
Zart CLI - Interactive Fiction Player for Z-Machine and Inform games.

Usage: zart <game_file>
''';
