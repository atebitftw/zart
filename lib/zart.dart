// ============================================================
// Zart - Z-Machine and Glulx Interpreter Library
// ============================================================
//
// This is the public API for the Zart library.

// Implement PlatformProvider to run games on your platform.

export 'package:zart/src/game_runner.dart' show GameRunner, GameRunnerException;
export 'package:zart/src/io/platform/platform_provider.dart';
export 'package:zart/src/io/platform/platform_capabilities.dart';
export 'package:zart/src/io/platform/input_event.dart';
export 'package:zart/src/io/platform/z_machine_io_command.dart';
export 'package:zart/src/io/render/render_frame.dart';
export 'package:zart/src/io/render/render_cell.dart';

/// Returns a simple preamble that can be output by platform providers.
List<String> getPreamble() {
  return [
    "-----------------------------",
    "Zart: Interactive Fiction Interpreter",
    "Version 2.0",
    "https://pub.dev/packages/zart",
    "-----------------------------",
    "",
  ];
}
