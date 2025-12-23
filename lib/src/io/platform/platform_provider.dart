import 'dart:async';

import 'package:zart/src/io/glk/glk_io_provider.dart';
import 'package:zart/src/io/platform/input_event.dart';
import 'package:zart/src/io/platform/platform_capabilities.dart';
import 'package:zart/src/io/platform/z_machine_io_command.dart';
import 'package:zart/src/io/render/render_frame.dart';
import 'package:zart/src/io/z_io_dispatcher.dart';
import 'package:zart/src/loaders/blorb.dart';

/// Unified platform provider interface for running Z-machine and Glulx games.
///
/// Any presentation layer (CLI, web, Flutter, etc.) should implement this
/// interface to run interactive fiction games. The same implementation can
/// run both Z-machine and Glulx games.
///
/// Extends [GlkIoProvider] to provide direct compatibility with [GlulxInterpreter].
///
/// ## Architecture
///
/// ```text
/// ┌─────────────────────┐
/// │   Presentation      │  Your app (CLI, Web, Flutter, etc.)
/// │   Layer             │
/// └──────────┬──────────┘
///            │ implements
/// ┌──────────▼──────────┐
/// │  PlatformProvider   │  This interface
/// └──────────┬──────────┘
///            │ passed to
/// ┌──────────▼──────────┐
/// │    GameRunner       │  Coordinates VM execution
/// └──────────┬──────────┘
///            │ runs
/// ┌──────────▼──────────┐
/// │  Z-Machine / Glulx  │  Game interpreters
/// └─────────────────────┘
/// ```
///
/// ## Implementation Guide
///
/// 1. Implement [capabilities] to describe your platform's display and input.
/// 2. Implement [render] to display game output using [RenderFrame].
/// 3. Implement input methods ([readLine], [readInput], [pollInput]).
/// 4. Implement file IO ([saveGame], [restoreGame]).
/// 5. For Glulx: implement [glkDispatch] and memory/stack access.
/// 6. For Z-machine: implement [zCommand].
///
/// ## Example
///
/// ```dart
/// class MyPlatformProvider implements PlatformProvider {
///   @override
///   PlatformCapabilities get capabilities => PlatformCapabilities(
///     screenWidth: 80,
///     screenHeight: 24,
///   );
///
///   @override
///   void render(RenderFrame frame) {
///     // Draw frame.windows to your display
///   }
///
///   // ... implement other methods
/// }
///
/// // Run a game
/// final provider = MyPlatformProvider();
/// final runner = GameRunner(provider);
/// await runner.run(gameBytes);
/// ```
abstract class PlatformProvider implements GlkIoProvider {
  /// Name of the game being run (usually the filename, or some component of it).
  String get gameName;

  /// Initialize the platform provider for a specific game type.
  ///
  /// Called by [GameRunner] before starting a game. Implementations should
  /// set up game-type-specific resources (e.g., Glk display for Glulx,
  /// ZIoDispatcher for Z-machine).
  void init(GameFileType fileType);

  // ============================================================
  // CAPABILITIES
  // ============================================================

  /// Query platform capabilities for the VM to adapt its output.
  ///
  /// The game engine queries this to know what features are available
  /// (colors, graphics, sound, screen size, etc).
  PlatformCapabilities get capabilities;

  // ============================================================
  // RENDERING
  // ============================================================

  /// Render a frame update to the display.
  ///
  /// Called by the game engine when the screen needs updating.
  /// The [frame] contains all windows and their cell grids.
  void render(RenderFrame frame);

  /// Enter game display mode (full-screen, alternate buffer, etc).
  ///
  /// Called when the game starts. The platform should set up its
  /// display for game rendering (e.g., enter alternate screen buffer
  /// in terminals, hide system UI in mobile apps).
  void enterDisplayMode();

  /// Exit game display mode and restore normal display.
  ///
  /// Called when the game ends. The platform should restore its
  /// normal display state.
  void exitDisplayMode();

  // ============================================================
  // INPUT
  // ============================================================

  /// Read a line of text input from the user.
  ///
  /// Blocks until the user presses Enter. Returns the entered text
  /// (without the newline).
  ///
  /// [maxLength] - Maximum characters to accept (optional).
  /// [timeout] - Timeout in milliseconds, or null for no timeout.
  ///
  /// If timeout expires, return the current partial input.
  Future<String> readLine({int? maxLength, int? timeout});

  /// Read a single input event (key press, mouse click, etc).
  ///
  /// Blocks until input is available or timeout expires.
  ///
  /// [timeout] - Timeout in milliseconds, or null for no timeout.
  ///
  /// Returns an [InputEvent] describing what happened.
  Future<InputEvent> readInput({int? timeout});

  /// Poll for input without blocking.
  ///
  /// Returns immediately with any pending input, or null if none.
  /// Used for real-time games and timed input.
  InputEvent? pollInput();

  // ============================================================
  // FILE IO
  // ============================================================

  /// Request to save game state (interactive).
  ///
  /// The platform should prompt the user for a filename (or use
  /// [suggestedName]) and save the data.
  ///
  /// Returns the filename used, or null if the save was cancelled.
  Future<String?> saveGame(List<int> data, {String? suggestedName});

  /// Request to restore game state (interactive).
  ///
  /// The platform should prompt the user to select a save file
  /// (or use [suggestedName]) and return the data.
  ///
  /// Returns the save data, or null if cancelled/failed.
  Future<List<int>?> restoreGame({String? suggestedName});

  /// Request to save game state (non-interactive).
  ///
  /// The platform should save the data to a default or internal location
  /// without prompting the user.
  ///
  /// Returns the location used, or null if it failed.
  Future<String?> quickSave(List<int> data);

  /// Request to restore game state (non-interactive).
  ///
  /// The platform should restore data from a default or internal location
  /// without prompting the user.
  ///
  /// Returns the save data, or null if not found/failed.
  Future<List<int>?> quickRestore();

  // ============================================================
  // GLULX / GLK SUPPORT
  // ============================================================

  /// Handle a Glk dispatch call.
  ///
  /// Glulx games use Glk for all IO. This method receives Glk function
  /// calls and should return the appropriate result.
  ///
  /// [selector] - The Glk function selector (e.g., glk_put_char = 0x80).
  /// [args] - The function arguments.
  ///
  /// Returns the Glk function result.
  FutureOr<int> glkDispatch(int selector, List<int> args);

  /// Configure memory access callbacks for Glk operations.
  ///
  /// Glk needs to read/write game memory for certain operations
  /// (e.g., reading strings, writing event structures).
  void setGlkMemoryAccess({
    required void Function(int addr, int value, {int size}) write,
    required int Function(int addr, {int size}) read,
  });

  /// Configure stack access callbacks for Glk operations.
  ///
  /// Some Glk operations push/pop values from the VM stack
  /// (when addresses are -1).
  void setGlkStackAccess({required void Function(int value) push, required int Function() pop});

  /// Configure VM state callbacks.
  ///
  /// Provides access to VM state that Glk needs (e.g., heap start address).
  void setGlkVMState({int Function()? getHeapStart});

  /// Handle Glulx VM-level gestalt queries (the @gestalt opcode).
  ///
  /// This is separate from Glk gestalt - it queries the VM capabilities.
  int vmGestalt(int selector, int arg);

  /// Render the Glk screen immediately.
  ///
  /// Forces a refresh of the Glk display. Called after game execution
  /// completes to ensure final output is shown.
  void renderScreen();

  /// Show an exit message and wait for user input.
  ///
  /// Displays [message] and blocks until the user presses any key.
  /// Used for the "Press any key to exit" prompt at game end.
  Future<void> showExitAndWait(String message);

  // ============================================================
  // Z-MACHINE SUPPORT
  // ============================================================

  /// Get Z-machine capability flags (for header byte Flags1).
  ///
  /// This tells the Z-machine what features the interpreter supports.
  /// Use [PlatformCapabilities.getZMachineFlags1] for default implementation.
  int getZMachineFlags1() => capabilities.getZMachineFlags1();

  /// Execute a Z-machine IO command.
  ///
  /// Z-machine games use commands for IO (print, clear, colors, etc).
  /// This method receives typed command objects and should execute them.
  ///
  /// Returns a result value for commands that produce output (e.g.,
  /// GetCursorCommand returns cursor position).
  Future<dynamic> zCommand(ZMachineIOCommand command);

  /// Get the Z-machine IO dispatcher.
  ///
  /// Returns null if Z-machine is not initialized.
  ZIoDispatcher? get zDispatcher;

  /// Get the Z-machine display interface for input/output.
  ///
  /// Returns null if Z-machine is not initialized.
  ZMachineDisplay? get zDisplay;

  // ============================================================
  // LIFECYCLE
  // ============================================================

  /// Called when the game is quitting normally.
  ///
  /// The platform can show an exit message, clean up resources, etc.
  void onQuit();

  /// Called when an error occurs.
  ///
  /// The platform should display the error message appropriately.
  void onError(String message);

  /// Dispose of any resources held by the provider.
  ///
  /// Called when the game runner is done with the provider.
  void dispose() {}
}

/// Abstract interface for Z-machine display operations.
///
/// Represents the display/input surface for Z-machine games.
/// [GameRunner] uses this interface to drive the Z-machine game loop
/// without knowing the concrete display implementation.
abstract class ZMachineDisplay {
  /// Whether the status bar is enabled.
  bool get enableStatusBar;
  set enableStatusBar(bool value);

  /// Render the current display state.
  void render();

  /// Detect and update terminal size.
  void detectTerminalSize();

  /// Read a line of text input.
  ///
  /// Returns the input text, or `'__RESTORED__'` if a quick restore
  /// was triggered and the game state was restored.
  Future<String> readLine();

  /// Read a single character.
  ///
  /// Returns the character as a string.
  Future<String> readChar();

  /// Append text to window 0 (main window).
  void appendToWindow0(String text);

  /// Append echoed input text to the display.
  void appendInputEcho(String text);
}
