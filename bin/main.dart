import 'package:logging/logging.dart';
import 'package:zart/debugger.dart';
import 'package:zart/utils.dart' as utils;
import 'package:zart/zart.dart';
import 'dart:io';
import 'dart:async';

import 'package:zart/IO/io_provider.dart';

Logger log = Logger("main()");

/// Mock UI Provider for Unit Testing
class MockUIProvider implements IOProvider {
  @override
  Future<dynamic> command(Map<String, dynamic> command) async {
    final cmd = command['command'];
    stdout.writeln('Command received: $cmd ');
    return;
  }
}

main([List<String>? args]) {
  initLogger(Level.WARNING);

  final s = Platform.pathSeparator;
  final pathToFile = 'assets${s}games${s}minizork.z3';

  final f = File(pathToFile);

  try {
    Z.load(f.readAsBytesSync());
  } catch (e) {
    log.severe("An error occurred while loading the story file: $e");
    exit(1);
  }

  Debugger.initializeEngine();

  Z.io = MockUIProvider();

  stdout.writeln(Debugger.dumpHeader());
  stdout.writeln(utils.generateObjectTree());
}

void initLogger(Level level) {
  Logger.root.level = level;

  Logger.root.onRecord.listen((LogRecord rec) {
    stdout.writeln('(${rec.time}:)[${rec.loggerName}]${rec.level.name}: ${rec.message}');
  });
}
