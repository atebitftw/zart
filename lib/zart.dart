export 'package:zart/src/z_machine.dart' show Z, ZMachineRunState;
export 'package:zart/src/io/io_provider.dart';
export 'package:zart/src/io/default_provider.dart';
export 'package:zart/src/io/blorb.dart';
export 'package:zart/src/game_exception.dart';
export 'package:zart/src/debugger.dart';
export 'package:zart/src/header.dart';

/// Returns a simple preamble that can be outputed by [IoProvider]s.
List<String> getPreamble() {
  return [
    "-----------------------------",
    "Zart: A Z-Machine Interpreter",
    "Version 1.7",
    "https://pub.dev/packages/zart",
    "-----------------------------",
    "",
  ];
}
