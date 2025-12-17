// Reference: packages/ifarchive-if-specs/glk-spec.md
// The reference is written assuming C-style code.  It is also written to the
// perspective of the interpreter developer.  Since we are building our own
// glulx interpreter, and we are using the Dart language, we will implement
// the Glk spec as an interface class that various platform-specific implementations
// can then implement to suit their presentation layer needs.

/// IO provider to dispatch all Glk IO operations.
/// All methods implemented in this interface should be async to support
/// asynchronous operations if needed.
abstract class GlkIoProvider {
  /// Gestalt returns 0 for everything right now, and will expand as we implement more features.
  Future<int> glkDispatch(int selector, List<int> args);
}
