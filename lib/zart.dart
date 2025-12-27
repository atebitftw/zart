// ============================================================
// Zart - Z-Machine and Glulx Interpreter Library
// ============================================================
//
// This is the public API for the Zart library.

// Implement PlatformProvider to run games on your platform.

export 'package:zart/src/game_runner.dart' show GameRunner;
export 'package:zart/src/game_runner_exception.dart' show GameRunnerException;
export 'package:zart/src/io/platform/platform_provider.dart'
    show PlatformProvider;
export 'package:zart/src/io/platform/platform_capabilities.dart'
    show PlatformCapabilities;
export 'package:zart/src/io/platform/input_event.dart'
    show InputEvent, InputEventType, MouseButton, SpecialKeys, SpecialKey;
export 'package:zart/src/io/render/screen_frame.dart' show ScreenFrame;
export 'package:zart/src/io/render/render_cell.dart' show RenderCell;
export 'package:zart/src/loaders/blorb.dart' show GameFileType;
export 'package:zart/src/zart_debugger.dart';
