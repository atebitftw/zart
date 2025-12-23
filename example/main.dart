import 'dart:io';

import 'package:logging/logging.dart' show Level;
import 'package:zart/src/logging.dart' show log;
import 'package:zart/zart.dart';
import '../bin/cli/cli_platform_provider.dart';
import '../bin/cli/configuration_manager.dart';

/// Example of using Zart with the PlatformProvider API.
///
/// This demonstrates the recommended way to run Z-Machine and Glulx games.
///
/// ```dart
/// final provider = CliPlatformProvider(config, gameName: 'game.z5');
/// final runner = GameRunner(provider);
/// await runner.run(gameBytes);
/// ```
void main(List<String> args) async {
  log.level = Level.INFO;

  if (args.isEmpty) {
    stdout.writeln('Usage: dart run example/main.dart <game_file>');
    exit(1);
  }

  final filename = args.first;
  final f = File(filename);

  if (!f.existsSync()) {
    stdout.writeln('Error: Game file not found at "$filename"');
    exit(1);
  }

  // Initialize configuration
  final config = ConfigurationManager()..load();

  // Create the platform provider
  final provider = CliPlatformProvider(config, gameName: filename);

  // Create game runner
  final runner = GameRunner(provider);

  try {
    // Run the game
    await runner.run(f.readAsBytesSync());
    runner.dispose();
    exit(0);
  } on GameRunnerException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(1);
  } catch (e, stack) {
    stderr.writeln('Unexpected error: $e');
    stderr.writeln('Stack trace:\n$stack');
    exit(1);
  }
}
