/// Input event types from the platform.
enum InputEventType {
  /// A character or key was pressed.
  character,

  /// A mouse event occurred.
  mouse,

  /// A timer event occurred (for timed input).
  timer,

  /// The window was resized.
  resize,

  /// No input available (for polling).
  none,
}

/// Mouse button identifiers.
enum MouseButton { left, right, middle }

/// Represents an input event from the platform.
///
/// Used for both Z-machine and Glulx games to receive keyboard, mouse,
/// and timer input in a unified way.
class InputEvent {
  /// The type of input event.
  final InputEventType type;

  /// For character input: the character string (may be empty for special keys).
  final String? character;

  /// For character input: Z-machine/Glk key code for special keys.
  /// - Arrow keys: 129-132 (up, down, left, right)
  /// - Function keys: 133-144 (F1-F12)
  /// - Delete: 8, Escape: 27, Enter: 13
  final int? keyCode;

  /// For mouse input: X position in window coordinates.
  final int? x;

  /// For mouse input: Y position in window coordinates.
  final int? y;

  /// For mouse input: which button was pressed/released.
  final MouseButton? button;

  /// For mouse input: the window ID where the click occurred.
  final int? windowId;

  /// True if this event is a timeout (no input received within time limit).
  final bool isTimeout;

  /// For resize events: new width.
  final int? newWidth;

  /// For resize events: new height.
  final int? newHeight;

  const InputEvent._({
    required this.type,
    this.character,
    this.keyCode,
    this.x,
    this.y,
    this.button,
    this.windowId,
    this.isTimeout = false,
    this.newWidth,
    this.newHeight,
  });

  /// Create a character input event.
  const InputEvent.character(String char, {int? keyCode})
    : this._(type: InputEventType.character, character: char, keyCode: keyCode);

  /// Create a special key event (arrows, function keys, etc).
  const InputEvent.specialKey(int keyCode) : this._(type: InputEventType.character, character: '', keyCode: keyCode);

  /// Create a mouse click event.
  const InputEvent.mouseClick(int x, int y, MouseButton button, {int? windowId})
    : this._(type: InputEventType.mouse, x: x, y: y, button: button, windowId: windowId);

  /// Create a timer/timeout event.
  const InputEvent.timeout() : this._(type: InputEventType.timer, isTimeout: true);

  /// Create a resize event.
  const InputEvent.resize(int width, int height)
    : this._(type: InputEventType.resize, newWidth: width, newHeight: height);

  /// Create a "no input" event for polling.
  const InputEvent.none() : this._(type: InputEventType.none);

  /// True if this is a printable character (not a special key).
  bool get isPrintable => type == InputEventType.character && character != null && character!.isNotEmpty;

  @override
  String toString() {
    switch (type) {
      case InputEventType.character:
        if (isPrintable) {
          return 'InputEvent.character("$character")';
        }
        return 'InputEvent.specialKey($keyCode)';
      case InputEventType.mouse:
        return 'InputEvent.mouseClick($x, $y, $button)';
      case InputEventType.timer:
        return 'InputEvent.timeout()';
      case InputEventType.resize:
        return 'InputEvent.resize($newWidth, $newHeight)';
      case InputEventType.none:
        return 'InputEvent.none()';
    }
  }
}

/// Special key codes for Z-machine and Glk.
/// These are the standard key codes used by both VMs.
abstract class SpecialKeys {
  // Control keys
  /// Delete key
  static const int delete = 8;

  /// Tab key
  static const int tab = 9;

  /// Enter key
  static const int enter = 13;

  /// Escape key
  static const int escape = 27;

  // Arrow keys (Z-machine codes)
  /// Arrow up key
  static const int arrowUp = 129;

  /// Arrow down key
  static const int arrowDown = 130;

  /// Arrow left key
  static const int arrowLeft = 131;

  /// Arrow right key
  static const int arrowRight = 132;

  // Function keys
  /// F1 key
  static const int f1 = 133;

  /// F2 key
  static const int f2 = 134;

  /// F3 key
  static const int f3 = 135;

  /// F4 key
  /// F4 key
  static const int f4 = 136;

  /// F5 key
  static const int f5 = 137;

  /// F6 key
  static const int f6 = 138;

  /// F7 key
  static const int f7 = 139;

  /// F8 key
  static const int f8 = 140;

  /// F9 key
  static const int f9 = 141;

  /// F10 key
  static const int f10 = 142;

  /// F11 key
  static const int f11 = 143;

  /// F12 key
  static const int f12 = 144;

  // Keypad (for Z-machine v6+)
  /// Keypad 0 key
  static const int keypad0 = 145;

  /// Keypad 1 key
  static const int keypad1 = 146;

  /// Keypad 2 key
  static const int keypad2 = 147;

  /// Keypad 3 key
  static const int keypad3 = 148;

  /// Keypad 4 key
  static const int keypad4 = 149;

  /// Keypad 5 key
  static const int keypad5 = 150;

  /// Keypad 6 key
  static const int keypad6 = 151;

  /// Keypad 7 key
  static const int keypad7 = 152;

  /// Keypad 8 key
  static const int keypad8 = 153;

  /// Keypad 9 key
  static const int keypad9 = 154;
}
