/// Glk event types (for glk_select event structure).
class GlkEventTypes {
  /// No event.
  static const int none = 0;

  /// Timer event.
  static const int timer = 1;

  /// Character input event.
  static const int charInput = 2;

  /// Line input event.
  static const int lineInput = 3;

  /// Mouse input event.
  static const int mouseInput = 4;

  /// Window arrange event.
  static const int arrange = 5;

  /// Window redraw event.
  static const int redraw = 6;

  /// Sound notify event.
  static const int soundNotify = 7;

  /// Hyperlink event.
  static const int hyperlink = 8;

  /// Volume notify event.
  static const int volumeNotify = 9;
}

/// Defines the IO selectors for Glk.
class GlkIoSelectors {
  /// Exit the program.
  static const int exit = 1;

  /// Set an interrupt handler.
  static const int setInterruptHandler = 2;

  /// Yields back to the host for async/threaded processing.
  static const int tick = 3;

  /// Gestalt selector.
  static const int gestalt = 4;

  /// Gestalt selector extension.
  static const int gestaltExt = 5;

  /// Iterate over windows.
  static const int windowIterate = 0x20;

  /// Get the rock of a window.
  static const int windowGetRock = 0x21;

  /// Get the root window.
  static const int windowGetRoot = 0x22;

  /// Open a window.
  static const int windowOpen = 0x23;

  /// Close a window.
  static const int windowClose = 0x24;

  /// Get the size of a window.
  static const int windowGetSize = 0x25;

  /// Set the arrangement of a window.
  static const int windowSetArrangement = 0x26;

  /// Get the arrangement of a window.
  static const int windowGetArrangement = 0x27;

  /// Get the type of a window.
  static const int windowGetType = 0x28;

  /// Get the parent of a window.
  static const int windowGetParent = 0x29;

  /// Clear a window.
  static const int windowClear = 0x2A;

  /// Move the cursor in a window.
  static const int windowMoveCursor = 0x2B;

  /// Get the stream of a window.
  static const int windowGetStream = 0x2C;

  /// Set the echo stream of a window.
  static const int windowSetEchoStream = 0x2D;

  /// Get the echo stream of a window.
  static const int windowGetEchoStream = 0x2E;

  /// Set the current window.
  static const int setWindow = 0x2F;

  /// Get the sibling of a window.
  static const int windowGetSibling = 0x30;

  /// Iterate over streams.
  static const int streamIterate = 0x40;

  /// Get the rock of a stream.
  static const int streamGetRock = 0x41;

  /// Open a file stream.
  static const int streamOpenFile = 0x42;

  /// Open a memory stream.
  static const int streamOpenMemory = 0x43;

  /// Close a stream.
  static const int streamClose = 0x44;

  /// Set the position of a stream.
  static const int streamSetPosition = 0x45;

  /// Get the position of a stream.
  static const int streamGetPosition = 0x46;

  /// Set the current stream.
  static const int streamSetCurrent = 0x47;

  /// Get the current stream.
  static const int streamGetCurrent = 0x48;

  /// Open a resource stream.
  static const int streamOpenResource = 0x49;

  /// Create a temporary file reference.
  static const int filerefCreateTemp = 0x60;

  /// Create a file reference by name.
  static const int filerefCreateByName = 0x61;

  /// Create a file reference by prompt.
  static const int filerefCreateByPrompt = 0x62;

  /// Destroy a file reference.
  static const int filerefDestroy = 0x63;

  /// Iterate over file references.
  static const int filerefIterate = 0x64;

  /// Get the rock of a file reference.
  static const int filerefGetRock = 0x65;

  /// Delete a file.
  static const int filerefDeleteFile = 0x66;

  /// Check if a file exists.
  static const int filerefDoesFileExist = 0x67;

  /// Create a file reference from another file reference.
  static const int filerefCreateFromFileref = 0x68;

  /// Put a character.
  static const int putChar = 0x80;

  /// Put a character to a stream.
  static const int putCharStream = 0x81;

  /// Put a string.
  static const int putString = 0x82;

  /// Put a string to a stream.
  static const int putStringStream = 0x83;

  /// Put a buffer.
  static const int putBuffer = 0x84;

  /// Put a buffer to a stream.
  static const int putBufferStream = 0x85;

  /// Set a style.
  static const int setStyle = 0x86;

  /// Set a style to a stream.
  static const int setStyleStream = 0x87;

  /// Get a character from a stream.
  static const int getCharStream = 0x90;

  /// Get a line from a stream.
  static const int getLineStream = 0x91;

  /// Get a buffer from a stream.
  static const int getBufferStream = 0x92;

  /// Convert a character to lowercase.
  static const int charToLower = 0xA0;

  /// Convert a character to uppercase.
  static const int charToUpper = 0xA1;

  /// Set a style hint.
  static const int stylehintSet = 0xB0;

  /// Clear a style hint.
  static const int stylehintClear = 0xB1;

  /// Distinguish a style.
  static const int styleDistinguish = 0xB2;

  /// Measure a style.
  static const int styleMeasure = 0xB3;

  /// Select.
  static const int select = 0xC0;

  /// Select with polling.
  static const int selectPoll = 0xC1;

  /// Request a line event.
  static const int requestLineEvent = 0xD0;

  /// Cancel a line event.
  static const int cancelLineEvent = 0xD1;

  /// Request a character event.
  static const int requestCharEvent = 0xD2;

  /// Cancel a character event.
  static const int cancelCharEvent = 0xD3;

  /// Request a mouse event.
  static const int requestMouseEvent = 0xD4;

  /// Cancel a mouse event.
  static const int cancelMouseEvent = 0xD5;

  /// Request timer events.
  static const int requestTimerEvents = 0xD6;

  /// Get image information.
  static const int imageGetInfo = 0xE0;

  /// Draw an image.
  static const int imageDraw = 0xE1;

  /// Draw an image scaled.
  static const int imageDrawScaled = 0xE2;

  /// Flow break in a window.
  static const int windowFlowBreak = 0xE8;

  /// Erase a rectangle in a window.
  static const int windowEraseRect = 0xE9;

  /// Fill a rectangle in a window.
  static const int windowFillRect = 0xEA;

  /// Set the background color of a window.
  static const int windowSetBackgroundColor = 0xEB;

  /// Draw an image scaled with extended parameters.
  static const int imageDrawScaledExt = 0xEC;

  /// Iterate over sound channels.
  static const int schannelIterate = 0xF0;

  /// Get the rock of a sound channel.
  static const int schannelGetRock = 0xF1;

  /// Create a sound channel.
  static const int schannelCreate = 0xF2;

  /// Destroy a sound channel.
  static const int schannelDestroy = 0xF3;

  /// Create a sound channel with extended parameters.
  static const int schannelCreateExt = 0xF4;

  /// Play multiple sounds.
  static const int schannelPlayMulti = 0xF7;

  /// Play a sound.
  static const int schannelPlay = 0xF8;

  /// Play a sound with extended parameters.
  static const int schannelPlayExt = 0xF9;

  /// Stop a sound.
  static const int schannelStop = 0xFA;

  /// Set the volume of a sound.
  static const int schannelSetVolume = 0xFB;

  /// Load a sound.
  static const int soundLoadHint = 0xFC;

  /// Set the volume of a sound with extended parameters.
  static const int schannelSetVolumeExt = 0xFD;

  /// Pause a sound.
  static const int schannelPause = 0xFE;

  /// Unpause a sound.
  static const int schannelUnpause = 0xFF;

  /// Set a hyperlink.
  static const int setHyperlink = 0x100;

  /// Set a hyperlink to a stream.
  static const int setHyperlinkStream = 0x101;

  /// Request a hyperlink event.
  static const int requestHyperlinkEvent = 0x102;

  /// Cancel a hyperlink event.
  static const int cancelHyperlinkEvent = 0x103;

  /// Convert a buffer to lowercase.
  static const int bufferToLowerCaseUni = 0x120;

  /// Convert a buffer to uppercase.
  static const int bufferToUpperCaseUni = 0x121;

  /// Convert a buffer to title case.
  static const int bufferToTitleCaseUni = 0x122;

  /// Convert a buffer to canonical decomposition.
  static const int bufferCanonDecomposeUni = 0x123;

  /// Convert a buffer to canonical normalization.
  static const int bufferCanonNormalizeUni = 0x124;

  /// Put a character.
  static const int putCharUni = 0x128;

  /// Put a string.
  static const int putStringUni = 0x129;

  /// Put a buffer.
  static const int putBufferUni = 0x12A;

  /// Put a character to a stream.
  static const int putCharStreamUni = 0x12B;

  /// Put a string to a stream.
  static const int putStringStreamUni = 0x12C;

  /// Put a buffer to a stream.
  static const int putBufferStreamUni = 0x12D;

  /// Get a character from a stream.
  static const int getCharStreamUni = 0x130;

  /// Get a buffer from a stream.
  static const int getBufferStreamUni = 0x131;

  /// Get a line from a stream.
  static const int getLineStreamUni = 0x132;

  /// Open a file stream.
  static const int streamOpenFileUni = 0x138;

  /// Open a memory stream.
  static const int streamOpenMemoryUni = 0x139;

  /// Open a resource stream.
  static const int streamOpenResourceUni = 0x13A;

  /// Request a character event.
  static const int requestCharEventUni = 0x140;

  /// Request a line event.
  static const int requestLineEventUni = 0x141;

  /// Set echo line event.
  static const int setEchoLineEvent = 0x150;

  /// Set terminators line event.
  static const int setTerminatorsLineEvent = 0x151;

  /// Get the current time.
  static const int currentTime = 0x160;

  /// Get the current simple time.
  static const int currentSimpleTime = 0x161;

  /// Convert a time to a date.
  static const int timeToDateUtc = 0x168;

  /// Convert a time to a date.
  static const int timeToDateLocal = 0x169;

  /// Convert a simple time to a date.
  static const int simpleTimeToDateUtc = 0x16A;

  /// Convert a simple time to a date.
  static const int simpleTimeToDateLocal = 0x16B;

  /// Convert a date to a time.
  static const int dateToTimeUtc = 0x16C;

  /// Convert a date to a time.
  static const int dateToTimeLocal = 0x16D;

  /// Convert a date to a simple time.
  static const int dateToSimpleTimeUtc = 0x16E;

  /// Convert a date to a simple time.
  static const int dateToSimpleTimeLocal = 0x16F;
}
