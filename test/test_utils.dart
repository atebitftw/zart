import 'package:zart/src/interpreters/interpreter_v3.dart';
import 'package:zart/zart.dart';
import 'mock_ui_provider.dart';
import 'mock_v3_machine.dart';
import 'dart:io';

void setupZMachine({InterpreterV3? engine}) {
  var defaultGameFile = 'assets/games/minizork.z3';

  final f = File(defaultGameFile);

  try {
    final rawBytes = f.readAsBytesSync();
    final data = Blorb.getZData(rawBytes);
    Z.load(data);
  } on Exception catch (fe) {
    stdout.writeln('$fe');
    exit(1);
  }

  final machine = engine ?? MockV3Machine();

  Debugger.initializeEngine(machine);
  Z.io = MockUIProvider();
}
