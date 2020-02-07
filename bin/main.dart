import 'package:logging/logging.dart';
import 'package:zart/debugger.dart';
import 'package:zart/utils.dart' as Utils;
import 'package:zart/zart.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert' as JSON;

import 'package:zart/IO/io_provider.dart';

Logger log = Logger("main()");

/**
* Mock UI Provider for Unit Testing
*/
class MockUIProvider implements IOProvider {
  Future<Object> command(String JSONCommand) {
    var c = Completer();
    var cmd = JSON.json.encode(JSONCommand);
    print('Command received: ${cmd[0]} ');
    c.complete(null);
    return c.future;
  }
}

main([List<String> args]) {
  initLogger(Level.WARNING);

  final s = Platform.pathSeparator;
  final pathToFile = 'assets${s}games${s}hitchhik.z5';

  final f = File(pathToFile);

  try {
    Z.load(f.readAsBytesSync());
  } catch (e) {
    log.severe("An error occurred while loading the story file: $e");
    exit(1);
  }

  Debugger.initializeMachine();

  Z.IOConfig = MockUIProvider();

  print(Debugger.dumpHeader());
  print(Utils.generateObjectTree());
}

void initLogger(Level level) {
  Logger.root.level = level;

  Logger.root.onRecord.listen((LogRecord rec) {
    print('(${rec.time}:)[${rec.loggerName}]${rec.level.name}: ${rec.message}');
  });
}
