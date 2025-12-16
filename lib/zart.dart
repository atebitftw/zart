export 'package:zart/src/z_machine/z_machine.dart' show Z, ZMachineRunState;
export 'package:zart/src/io/io_provider.dart';
export 'package:zart/src/io/default_provider.dart';
export 'package:zart/src/loaders/blorb.dart';
export 'package:zart/src/z_machine/game_exception.dart';
export 'package:zart/src/z_machine/debugger.dart';
export 'package:zart/src/z_machine/header.dart';
export 'package:zart/src/io/screen_model.dart';
export 'package:zart/src/io/io_commands.dart';
export 'package:zart/src/io/cell.dart';

/// Returns a simple preamble that can be outputed by [IoProvider]s.
List<String> getPreamble() {
  return [
    "-----------------------------",
    "Zart: A Z-Machine Interpreter Library",
    "Version 1.9",
    "https://pub.dev/packages/zart",
    "-----------------------------",
    "",
  ];
}
