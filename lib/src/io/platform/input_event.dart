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

  /// A macro command was triggered.
  macro,

  /// No input available (for polling).
  none,
}

/// Mouse button identifiers.
enum MouseButton {
  /// Left mouse button.
  left,

  /// Right mouse button.
  right,

  /// Middle mouse button.
  middle,
}

/// Unified special key identifiers for internal use.
enum SpecialKey {
  /// Delete key.
  delete,

  /// Tab key.
  tab,

  /// Enter key.
  enter,

  /// Escape key.
  escape,

  /// Arrow up key.
  arrowUp,

  /// Arrow down key.
  arrowDown,

  /// Arrow left key.
  arrowLeft,

  /// Arrow right key.
  arrowRight,

  /// Page up key.
  pageUp,

  /// Page down key.
  pageDown,

  /// F1 key.
  f1,

  /// F2 key.
  f2,

  /// F3 key.
  f3,

  /// F4 key.
  f4,

  /// F5 key.
  f5,

  /// F6 key.
  f6,

  /// F7 key.
  f7,

  /// F8 key.
  f8,

  /// F9 key.
  f9,

  /// F10 key.
  f10,

  /// F11 key.
  f11,

  /// F12 key.
  f12,

  /// Keypad 0 key.
  keypad0,

  /// Keypad 1 key.
  keypad1,

  /// Keypad 2 key.
  keypad2,

  /// Keypad 3 key.
  keypad3,

  /// Keypad 4 key.
  keypad4,

  /// Keypad 5 key.
  keypad5,

  /// Keypad 6 key.
  keypad6,

  /// Keypad 7 key.
  keypad7,

  /// Keypad 8 key.
  keypad8,

  /// Keypad 9 key.
  keypad9,

  /// None (no key pressed).
  none,
}

/// Represents an input event from the platform.
///
/// Used for both Z-machine and Glulx games to receive keyboard, mouse,
/// and timer input in a unified way.
class InputEvent {
  /// The type of input event.
  final InputEventType type;

  /// For character input: the character string (may be empty for special keys).
  final String? character;

  /// The internal special key identifier (if applicable).
  final SpecialKey? specialKey;

  final int? _keyCode;

  /// For character input: Z-machine/Glk key code for special keys.
  /// - Arrow keys: 129-132 (up, down, left, right)
  /// - Function keys: 133-144 (F1-F12)
  /// - Delete: 8, Escape: 27, Enter: 13
  int? get keyCode =>
      _keyCode ??
      (specialKey != null ? SpecialKeys.toKeyCode(specialKey!) : null);

  /// For macro events: the command string to execute.
  final String? macroCommand;

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
    this.specialKey,
    int? keyCode,
    this.macroCommand,
    this.x,
    this.y,
    this.button,
    this.windowId,
    this.isTimeout = false,
    this.newWidth,
    this.newHeight,
  }) : _keyCode = keyCode;

  /// Create a character input event.
  const InputEvent.character(
    String char, {
    SpecialKey? specialKey,
    int? keyCode,
  }) : this._(
         type: InputEventType.character,
         character: char,
         specialKey: specialKey,
         keyCode: keyCode,
       );

  /// Create a special key event (arrows, function keys, etc).
  const InputEvent.specialKey(SpecialKey specialKey, {int? keyCode})
    : this._(
        type: InputEventType.character,
        character: '',
        specialKey: specialKey,
        keyCode: keyCode,
      );

  /// Create a macro command event.
  const InputEvent.macro(String command)
    : this._(type: InputEventType.macro, macroCommand: command);

  /// Create a mouse click event.
  const InputEvent.mouseClick(int x, int y, MouseButton button, {int? windowId})
    : this._(
        type: InputEventType.mouse,
        x: x,
        y: y,
        button: button,
        windowId: windowId,
      );

  /// Create a timer/timeout event.
  const InputEvent.timeout()
    : this._(type: InputEventType.timer, isTimeout: true);

  /// Create a resize event.
  const InputEvent.resize(int width, int height)
    : this._(type: InputEventType.resize, newWidth: width, newHeight: height);

  /// Create a "no input" event for polling.
  const InputEvent.none() : this._(type: InputEventType.none);

  /// True if this is a printable character (not a special key).
  bool get isPrintable =>
      type == InputEventType.character &&
      character != null &&
      character!.isNotEmpty;

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
      case InputEventType.macro:
        return 'InputEvent.macro("$macroCommand")';
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

  /// Page up key
  static const int pageUp = 155;

  /// Page down key
  static const int pageDown = 156;

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

  /// Map a SpecialKey enum to its corresponding integer key code.
  static int toKeyCode(SpecialKey key) {
    switch (key) {
      case SpecialKey.delete:
        return delete;
      case SpecialKey.tab:
        return tab;
      case SpecialKey.enter:
        return enter;
      case SpecialKey.escape:
        return escape;
      case SpecialKey.arrowUp:
        return arrowUp;
      case SpecialKey.arrowDown:
        return arrowDown;
      case SpecialKey.arrowLeft:
        return arrowLeft;
      case SpecialKey.arrowRight:
        return arrowRight;
      case SpecialKey.pageUp:
        return pageUp;
      case SpecialKey.pageDown:
        return pageDown;
      case SpecialKey.f1:
        return f1;
      case SpecialKey.f2:
        return f2;
      case SpecialKey.f3:
        return f3;
      case SpecialKey.f4:
        return f4;
      case SpecialKey.f5:
        return f5;
      case SpecialKey.f6:
        return f6;
      case SpecialKey.f7:
        return f7;
      case SpecialKey.f8:
        return f8;
      case SpecialKey.f9:
        return f9;
      case SpecialKey.f10:
        return f10;
      case SpecialKey.f11:
        return f11;
      case SpecialKey.f12:
        return f12;
      case SpecialKey.keypad0:
        return keypad0;
      case SpecialKey.keypad1:
        return keypad1;
      case SpecialKey.keypad2:
        return keypad2;
      case SpecialKey.keypad3:
        return keypad3;
      case SpecialKey.keypad4:
        return keypad4;
      case SpecialKey.keypad5:
        return keypad5;
      case SpecialKey.keypad6:
        return keypad6;
      case SpecialKey.keypad7:
        return keypad7;
      case SpecialKey.keypad8:
        return keypad8;
      case SpecialKey.keypad9:
        return keypad9;
      case SpecialKey.none:
        return 0;
    }
  }

  /// Map an integer key code to its corresponding SpecialKey enum.
  static SpecialKey fromKeyCode(int code) {
    if (code == delete) return SpecialKey.delete;
    if (code == tab) return SpecialKey.tab;
    if (code == enter) return SpecialKey.enter;
    if (code == escape) return SpecialKey.escape;
    if (code == arrowUp) return SpecialKey.arrowUp;
    if (code == arrowDown) return SpecialKey.arrowDown;
    if (code == arrowLeft) return SpecialKey.arrowLeft;
    if (code == arrowRight) return SpecialKey.arrowRight;
    if (code == pageUp) return SpecialKey.pageUp;
    if (code == pageDown) return SpecialKey.pageDown;
    if (code >= f1 && code <= f12) {
      return SpecialKey.values[SpecialKey.f1.index + (code - f1)];
    }
    if (code >= keypad0 && code <= keypad9) {
      return SpecialKey.values[SpecialKey.keypad0.index + (code - keypad0)];
    }
    return SpecialKey.none;
  }
}
