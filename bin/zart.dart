import 'dart:io';

import 'package:zart/zart.dart';
import 'cli/cli_platform_provider.dart';

/// Zart CLI - A terminal-based player for Z-Machine and Glulx games.
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

  final provider = CliPlatformProvider(gameName: args.first);
  final runner = GameRunner(provider);

  try {
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
Zart - Interactive Fiction Player for Z-Machine and Glulx games

Usage: zart <game_file> [options]
''';
