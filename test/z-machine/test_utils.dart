import 'package:zart/src/loaders/game_loader.dart';
import 'package:zart/src/z_machine/interpreters/interpreter_v3.dart';
import 'package:zart/src/zart_internal.dart';
import 'mock_ui_provider.dart';
import 'dart:io';

void setupZMachine({InterpreterV3? engine}) {
  var defaultGameFile = 'assets/games/z/minizork.z3';

  final f = File(defaultGameFile);

  try {
    final rawBytes = f.readAsBytesSync();
    final (data, fileType) = GameLoader.load(rawBytes);
    Z.load(data);
  } on Exception catch (fe) {
    stdout.writeln('$fe');
    exit(1);
  }

  Z.io = MockUIProvider();
}
