# IO Provider Reference for Flutter Players

This document provides a comprehensive reference for implementing an IO provider for a Flutter-based Z-Machine player. It documents all opcodes that communicate with the IO provider, including the IoCommand type, parameters, data types, and expected return values.

## Table of Contents

- [Overview](#overview)
- [IoCommand Reference](#iocommand-reference)
  - [Windowing Commands](#windowing-commands)
  - [Cursor Commands](#cursor-commands)
  - [Display Commands](#display-commands)
  - [Input Commands](#input-commands)
  - [Style Commands](#style-commands)
  - [Game State Commands](#game-state-commands)
  - [Sound Commands](#sound-commands)
- [Version Compatibility Matrix](#version-compatibility-matrix)

---

## Overview

The Z-Machine interpreter communicates with the UI layer through an `IoProvider` interface. Commands are sent as `Map<String, dynamic>` objects with a `"command"` key containing an `IoCommands` enum value, plus additional keys for parameters.

### Basic Pattern

```dart
// Interpreter sends:
await Z.sendIO({
  "command": IoCommands.someCommand,
  "param1": value1,
  "param2": value2,
});

// Provider returns:
dynamic result = await provider.command(message);
```

---

## IoCommand Reference

### Windowing Commands

#### `splitWindow`

Splits the screen to create an upper (status) window.

| Property | Details |
|----------|---------|
| **Opcode** | VAR:234 |
| **Versions** | V3+ |
| **IoCommand** | `IoCommands.splitWindow` |

**Parameters:**

| Key | Type | Description |
|-----|------|-------------|
| `lines` | `int` | Number of lines for the upper window |

**Behavior:**
- If `lines` is 0, close the upper window (unsplit)
- If `lines` > 0, create or resize the upper window
- In V3, the upper window is always cleared when called
- The upper window does not scroll

**Returns:** None

---

#### `setWindow`

Switches output to the specified window.

| Property | Details |
|----------|---------|
| **Opcode** | VAR:235 |
| **Versions** | V3+ |
| **IoCommand** | `IoCommands.setWindow` |

**Parameters:**

| Key | Type | Description |
|-----|------|-------------|
| `window` | `int` | Window number (0 = lower/main, 1 = upper/status) |

**Behavior:**
- When switching to window 1 (upper), the interpreter also sends a `setCursor` command to position (1, 1)
- Window 0 is the scrolling main text window
- Window 1 is the fixed-position status window

**Returns:** None

---

#### `clearScreen` (erase_window)

Clears one or more windows.

| Property | Details |
|----------|---------|
| **Opcode** | VAR:237 |
| **Versions** | V4+ |
| **IoCommand** | `IoCommands.clearScreen` |

**Parameters:**

| Key | Type | Description |
|-----|------|-------------|
| `window_id` | `int` (signed) | Window to clear (see below) |

**Window ID Values:**

| Value | Action |
|-------|--------|
| `-2` | Clear all windows AND unsplit (close upper window) |
| `-1` | Clear all windows (keep the split) |
| `0` | Clear lower window only |
| `1` | Clear upper window only |

**Returns:** None

---

### Cursor Commands

#### `setCursor`

Moves the cursor to a specific position.

| Property | Details |
|----------|---------|
| **Opcode** | VAR:239 |
| **Versions** | V4+ |
| **IoCommand** | `IoCommands.setCursor` |

**Parameters:**

| Key | Type | Description |
|-----|------|-------------|
| `line` | `int` | Line number (1-indexed, from top) |
| `column` | `int` | Column number (1-indexed, from left) |

**Behavior:**
- Only valid when the upper window is selected
- The interpreter ignores this command when window 0 is selected
- Coordinates are 1-indexed (top-left is 1,1)

**Returns:** None

---

#### `getCursor`

Gets the current cursor position.

| Property | Details |
|----------|---------|
| **Opcode** | VAR:240 |
| **Versions** | V4+ |
| **IoCommand** | `IoCommands.getCursor` |

**Parameters:** None

**Returns:** `Map<String, int>`

| Key | Type | Description |
|-----|------|-------------|
| `row` | `int` | Current line (1-indexed) |
| `column` | `int` | Current column (1-indexed) |

**Example:**
```dart
return {"row": 1, "column": 1};  // Top-left position
```

---

#### `eraseLine`

Erases from the current cursor position to end of line.

| Property | Details |
|----------|---------|
| **Opcode** | VAR:238 |
| **Versions** | V4+ |
| **IoCommand** | `IoCommands.eraseLine` |

**Parameters:** None

**Behavior:**
- Only sent when the opcode operand is 1
- Clears from cursor position to the right edge of the window

**Returns:** None

---

### Display Commands

#### `print`

Outputs text to the current window.

| Property | Details |
|----------|---------|
| **Opcodes** | Various print opcodes |
| **Versions** | V3+ |
| **IoCommand** | `IoCommands.print` |

**Parameters:**

| Key | Type | Description |
|-----|------|-------------|
| `window` | `int` | Target window (0 = lower, 1 = upper) |
| `buffer` | `String` | Text to print |

**Behavior:**
- The buffer is flushed via `Z.printBuffer()` before window switches or cursor movements
- Text should be appended to the current position
- In window 0, scrolling occurs when text reaches the bottom

**Returns:** None

---

#### `status`

Updates the V3 status line.

| Property | Details |
|----------|---------|
| **Opcode** | 0OP:188 (show_status) |
| **Versions** | V3 only |
| **IoCommand** | `IoCommands.status` |

**Parameters:**

| Key | Type | Description |
|-----|------|-------------|
| `room_name` | `String` | Current location name |
| `game_type` | `String` | `"SCORE"` or `"TIME"` |
| `score_one` | `int` | Score (if SCORE) or hours (if TIME) |
| `score_two` | `int` | Turns (if SCORE) or minutes (if TIME) |

**Returns:** None

---

### Input Commands

#### `read`

Requests a line of text input from the user.

| Property | Details |
|----------|---------|
| **Opcode** | VAR:228 (aread/sread) |
| **Versions** | V3+ |
| **IoCommand** | `IoCommands.read` |

**Parameters:** None (all context is internal to the interpreter)

**Behavior:**
- The interpreter pauses until input is provided
- Input should be echoed to the screen
- The interpreter handles tokenization internally

**Returns:** `String` - The user's input text (without newline)

---

#### `readChar`

Requests a single character input.

| Property | Details |
|----------|---------|
| **Opcode** | VAR:246 |
| **Versions** | V4+ |
| **IoCommand** | `IoCommands.readChar` |

**Parameters:** None

**Behavior:**
- Waits for a single keypress
- Should not echo the character
- Special keys should be converted to ZSCII codes

**Returns:** `String` - Single character (or special key representation)

**Special Key Codes (ZSCII):**

| Key | ZSCII Code |
|-----|------------|
| Delete/Backspace | 8 |
| Enter/Return | 13 |
| Escape | 27 |
| Up Arrow | 129 |
| Down Arrow | 130 |
| Left Arrow | 131 |
| Right Arrow | 132 |
| F1-F12 | 133-144 |

---

### Style Commands

#### `setTextStyle`

Sets the current text rendering style.

| Property | Details |
|----------|---------|
| **Opcode** | VAR:241 |
| **Versions** | V4+ |
| **IoCommand** | `IoCommands.setTextStyle` |

**Parameters:**

| Key | Type | Description |
|-----|------|-------------|
| `style` | `int` | Style bitmask (see below) |

**Style Bitmask:**

| Bit | Value | Style |
|-----|-------|-------|
| - | 0 | Roman (reset all styles) |
| 0 | 1 | Reverse video |
| 1 | 2 | Bold |
| 2 | 4 | Italic |
| 3 | 8 | Fixed-pitch (monospace) |

**Notes:**
- Style 0 clears ALL style bits
- Styles are cumulative (can be OR'd together)

**Returns:** None

---

#### `setColour`

Sets foreground and background colors.

| Property | Details |
|----------|---------|
| **Opcode** | 2OP:27 |
| **Versions** | V5+ |
| **IoCommand** | `IoCommands.setColour` |

**Parameters:**

| Key | Type | Description |
|-----|------|-------------|
| `foreground` | `int` | Foreground color code |
| `background` | `int` | Background color code |

**Color Codes:**

| Code | Color |
|------|-------|
| 0 | Current (no change) |
| 1 | Default |
| 2 | Black |
| 3 | Red |
| 4 | Green |
| 5 | Yellow |
| 6 | Blue |
| 7 | Magenta |
| 8 | Cyan |
| 9 | White |
| 10 | Light grey (V6+) |
| 11 | Medium grey (V6+) |
| 12 | Dark grey (V6+) |

**Returns:** None

---

#### `setTrueColour`

Sets colors using 15-bit RGB values (Standard 1.1+).

| Property | Details |
|----------|---------|
| **Opcode** | EXT:13 |
| **Versions** | V5+ (Standard 1.1) |
| **IoCommand** | `IoCommands.setTrueColour` |

**Parameters:**

| Key | Type | Description |
|-----|------|-------------|
| `foreground` | `int` | 15-bit color or special value |
| `background` | `int` | 15-bit color or special value |

**Special Values:**

| Value | Meaning |
|-------|---------|
| `0xFFFE` | Current color (no change) |
| `0xFFFF` | Default color |

**15-bit Color Format:**
- Bits 0-4: Red (0-31)
- Bits 5-9: Green (0-31)
- Bits 10-14: Blue (0-31)

**Returns:** None

---

#### `setFont`

Changes the current font.

| Property | Details |
|----------|---------|
| **Opcode** | EXT:4 |
| **Versions** | V5+ |
| **IoCommand** | `IoCommands.setFont` |

**Parameters:**

| Key | Type | Description |
|-----|------|-------------|
| `font_id` | `int` | Font number |

**Font Numbers:**

| Font | Description |
|------|-------------|
| 0 | Query current font (no change) |
| 1 | Normal (proportional) font |
| 3 | Character graphics font (unsupported) |
| 4 | Fixed-pitch (monospace) font |

**Returns:** `int` - Previous font number, or 0 if requested font unavailable

---

### Game State Commands

#### `save`

Saves the current game state.

| Property | Details |
|----------|---------|
| **Opcodes** | 0OP:181 (V3), EXT:0 (V5+) |
| **Versions** | V3+ |
| **IoCommand** | `IoCommands.save` |

**Parameters:**

| Key | Type | Description |
|-----|------|-------------|
| `file_data` | `Uint8List` | Quetzal-format save data |

**Behavior:**
- Provider should prompt user for save location
- Store the Quetzal data to a file

**Returns:** `bool` - `true` on success, `false` on failure/cancel

---

#### `restore`

Restores a previously saved game.

| Property | Details |
|----------|---------|
| **Opcodes** | 0OP:182 (V3), EXT:1 (V5+) |
| **Versions** | V3+ |
| **IoCommand** | `IoCommands.restore` |

**Parameters:** None

**Behavior:**
- Provider should prompt user to select a save file
- Return the Quetzal data bytes

**Returns:** `Uint8List?` - Quetzal save data, or `null` on failure/cancel

---

#### `quit`

Terminates the game.

| Property | Details |
|----------|---------|
| **Opcode** | 0OP:186 |
| **Versions** | V3+ |
| **IoCommand** | `IoCommands.quit` |

**Parameters:** None

**Behavior:**
- Game execution stops
- Provider should display final output and offer restart option

**Returns:** None

---

### Sound Commands

#### `soundEffect`

Plays a sound effect.

| Property | Details |
|----------|---------|
| **Opcode** | VAR:245 |
| **Versions** | V3+ |
| **IoCommand** | `IoCommands.soundEffect` |

**Parameters:**

| Key | Type | Description |
|-----|------|-------------|
| `number` | `int` | Sound number |
| `effect` | `int?` | Effect type (optional) |
| `volume` | `int?` | Volume/repeats (optional) |
| `routine` | `int?` | Callback routine address (optional) |

**Sound Numbers:**

| Number | Sound |
|--------|-------|
| 1 | High-pitched beep |
| 2 | Low-pitched beep |
| 3+ | Blorb sound resource |

**Effect Types:**

| Value | Action |
|-------|--------|
| 1 | Prepare/load sound |
| 2 | Start playing |
| 3 | Stop playing |
| 4 | Finish with cleanup |

**Returns:** None

---

## Version Compatibility Matrix

| IoCommand | V3 | V4 | V5 | V6 | V7 | V8 |
|-----------|:--:|:--:|:--:|:--:|:--:|:--:|
| `splitWindow` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `setWindow` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `clearScreen` | - | ✓ | ✓ | ✓ | ✓ | ✓ |
| `setCursor` | - | ✓ | ✓ | ✓ | ✓ | ✓ |
| `getCursor` | - | ✓ | ✓ | ✓ | ✓ | ✓ |
| `eraseLine` | - | ✓ | ✓ | ✓ | ✓ | ✓ |
| `print` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `status` | ✓ | - | - | - | - | - |
| `read` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `readChar` | - | ✓ | ✓ | ✓ | ✓ | ✓ |
| `setTextStyle` | - | ✓ | ✓ | ✓ | ✓ | ✓ |
| `setColour` | - | - | ✓ | ✓ | ✓ | ✓ |
| `setTrueColour` | - | - | ✓ | ✓ | ✓ | ✓ |
| `setFont` | - | - | ✓ | ✓ | ✓ | ✓ |
| `save` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `restore` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `quit` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `soundEffect` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

---

## Implementation Notes

### Window Model

```
┌─────────────────────────────────┐
│  Upper Window (Window 1)        │  ← Fixed position, doesn't scroll
│  Status bar / info display      │     Cursor positioning supported
├─────────────────────────────────┤
│                                 │
│  Lower Window (Window 0)        │  ← Main text, scrolls
│  Main game text output          │     No cursor positioning
│                                 │
│                                 │
└─────────────────────────────────┘
```

### Recommended Default Styles

| Element | Recommended Style |
|---------|-------------------|
| Default foreground | White or Light Grey |
| Default background | Black |
| Default font | Proportional (though many prefer fixed) |
| Upper window font | Fixed-pitch (monospace) |
| Line height | ~1.5x font size |

### Buffer Flushing

The interpreter calls `Z.printBuffer()` before:
- Switching windows (`set_window`)
- Moving cursor (`set_cursor`)
- Requesting input (`read`, `read_char`)

This flushes accumulated text to the provider's `print` command.

---

## Example Provider Implementation

```dart
class MyFlutterProvider implements IoProvider {
  @override
  Future<dynamic> command(Map<String, dynamic> msg) async {
    final cmd = msg['command'] as IoCommands;
    
    switch (cmd) {
      case IoCommands.print:
        appendText(msg['buffer'] as String, msg['window'] as int);
        return null;
        
      case IoCommands.read:
        return await getUserInput();
        
      case IoCommands.setCursor:
        setCursorPosition(msg['line'] as int, msg['column'] as int);
        return null;
        
      case IoCommands.getCursor:
        return {'row': currentRow, 'column': currentColumn};
        
      case IoCommands.setFont:
        final oldFont = currentFont;
        if (msg['font_id'] == 1 || msg['font_id'] == 4) {
          currentFont = msg['font_id'] as int;
        }
        return msg['font_id'] == 0 ? oldFont : (currentFont == msg['font_id'] ? oldFont : 0);
        
      // ... handle other commands
    }
  }
}
```

---

*This document corresponds to Z-Machine Standard 1.1 compliance.*
