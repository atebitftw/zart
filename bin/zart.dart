import 'dart:io';

import 'package:args/args.dart';
import 'package:zart/src/glulx/glulx_debugger.dart' show debugger;
import 'package:zart/src/logging.dart' show log;
import 'package:logging/logging.dart' show Level;
import 'package:zart/src/cli/config/configuration_manager.dart';
import 'package:zart/src/cli/ui/cli_renderer.dart';
import 'package:zart/src/game_runner.dart';

/// Zart CLI - A terminal-based player for Z-Machine and Glulx games.
void main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag('debug', abbr: 'd', help: 'Enable Glulx debugger', defaultsTo: false)
    ..addOption('startstep', help: 'Start step for debugger output')
    ..addOption('endstep', help: 'End step for debugger output')
    ..addFlag('showheader', help: 'Show Glulx header info', defaultsTo: false)
    ..addFlag('showbytes', help: 'Show raw bytes (requires --debug)', defaultsTo: false)
    ..addFlag('showmodes', help: 'Show addressing modes (requires --debug)', defaultsTo: false)
    ..addFlag('showinstructions', help: 'Show instructions (requires --debug)', defaultsTo: false)
    ..addFlag('showpc', help: 'Show PC advancement (requires --debug)', defaultsTo: false)
    ..addFlag('flight-recorder', help: 'Enable flight recorder (last 100 instructions)', defaultsTo: false)
    ..addOption('flight-recorder-size', help: 'Flight recorder size (requires --flight-recorder)', defaultsTo: '100')
    ..addFlag(
      'show-screen',
      help: 'Log screen output to flight recorder (requires --flight-recorder)',
      defaultsTo: false,
    )
    ..addOption('logfilter', help: 'Only log messages containing this string')
    ..addOption('maxstep', help: 'Maximum steps to run')
    ..addFlag('help', abbr: 'h', help: 'Show this help message', negatable: false);

  ArgResults results;
  try {
    results = parser.parse(args);
  } catch (e) {
    stdout.writeln('Error parsing arguments: $e');
    stdout.writeln(_usage(parser));
    exit(1);
  }

  if (results['help'] as bool || results.rest.isEmpty) {
    stdout.writeln(_usage(parser));
    exit(results['help'] as bool ? 0 : 1);
  }

  final filename = results.rest.first;
  final isDebug = results['debug'] as bool;
  log.level = isDebug ? Level.INFO : Level.WARNING;

  if (isDebug) {
    final logFile = File('debug.log');
    // Clear log file if it exists
    if (logFile.existsSync()) {
      logFile.writeAsStringSync('');
    }
    log.onRecord.listen((record) {
      logFile.writeAsStringSync('${record.level.name}: ${record.time}: ${record.message}\n', mode: FileMode.append);
    });
  }

  final file = File(filename);
  if (!file.existsSync()) {
    stdout.writeln('Error: Game file not found at "$filename"');
    exit(1);
  }

  // Consolidate debug flags into a config map
  final debugConfig = <String, dynamic>{
    'debug': results['debug'],
    'startstep': results['startstep'] != null ? int.tryParse(results['startstep']) : null,
    'endstep': results['endstep'] != null ? int.tryParse(results['endstep']) : null,
    'showheader': results['showheader'],
    'showbytes': results['showbytes'],
    'showmodes': results['showmodes'],
    'showinstructions': results['showinstructions'],
    'showpc': results['showpc'],
    'flight-recorder': results['flight-recorder'],
    'flight-recorder-size': int.tryParse(results['flight-recorder-size'] ?? '100'),
    'show-screen': results['show-screen'],
    'logfilter': results['logfilter'],
    'maxstep': results['maxstep'] != null ? int.tryParse(results['maxstep']) : -1,
  };

  final renderer = CliRenderer();
  final config = ConfigurationManager()..load();
  final runner = GameRunner(renderer, config: config, debugConfig: debugConfig);
  debugger.dumpDebugSettings();

  try {
    await runner.run(file.readAsBytesSync(), filename: filename);
    runner.dispose();
    _saveDebugData();
    exit(0);
  } on GameRunnerException catch (e) {
    stderr.writeln('Zart GameRunnerException Error: ${e.message}');
    _saveDebugData();
    exit(1);
  } catch (e) {
    stderr.writeln('Zart Error: $e');
    _saveDebugData();
    exit(1);
  }
}

void _saveDebugData() {
  if (debugger.enabled) {
    print('Saving debug data to log...');
    debugger.flushLogs();
    print('Finished saving debug data.');
  }
}

String _usage(ArgParser parser) =>
    '''
Zart - Z-Machine and Glulx Interpreter

Usage: zart <game_file> [options]

${parser.usage}
''';
