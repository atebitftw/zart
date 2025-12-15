# About The Zart CLI Player
The Zart CLI Player is a command-line interface for playing Z-Machine games.  It tries to implement modern Quality-of-Life features while remaining true to the original experience.

## Installation
### Flutter/Dart SDK Required
You will need the Flutter/Dart SDK installed on your system to use the CLI player.  You can download it from [Dart SDK Download](https://dart.dev/get-dart) or [Install Flutter](https://docs.flutter.dev/install).  Flutter comes with the Dart SDK.

### Activate the CLI Player
You can then install the `zart` CLI player and run it to play games from the command line:

```bash
> dart pub global activate zart
> zart path/to/minizork.z3
```

## Usage
`zart {gamefile}`

## Features
- The player supports the following features:
    - Fullscreen mode
    - Mouse support (scrolling)
    - Custom key bindings
    - Quicksave/Quickload
    - Text color cycling
    - "Zart" status bar (at the bottom of the screen).
    - A JSON configuration file (zart.config) to preserve user settings, and allow manual editing.

### Mouse Support
If the app can detect mouse support, it will allow scrolling of the main game window, so that players can see the histor of their current game session.

## Accessing Settings - F1
While playing the game, you can press F1 to access the settings screen.

#### Configuring Zart Bar Colors and Visibility
In the Settings screen, you can configure the foreground/background colors and visibility of the Zart status bar (the bottom bar).

### Custom Key Bindings
In the Settings screen, you can configure custom key bindings to provide a more modern experience. These key binds allow the player to assign actions to Ctrl+Key combinations.  For example, you can assign "take all" to Ctrl+A, or "look" to Ctrl+L, or "take all. inventory" to assign a "macro" of multiple commands that the you use frequently.

## QuickSave/QuickLoad - F2/F3
In the Settings screen, you can configure quicksave/quickload to provide a more modern experience.  The player can press F2 at anytime to "quick save" the current game state.  This will write a save file to the current directory, with a filename based on the game name.  Note that subsequent quicksaves will overwrite the previous quicksave file.  The player can press F3 at anytime to "quick load" the current game state.  This will read the quicksave file from the current directory (if it exists), and restore the game state.

## Text Color Cycling - F4
In the Settings screen, you can configure text color cycling to provide a more modern experience.  The player can press F4 at anytime to "cycle" the text color.  This will cycle the text color through a set of colors, and save the preference to the configuration file.

### The Configuration File
Any changes made to preferences are saved to a configuration file in the current directory called "zart.config".  This file is in JSON format, and can be edited by hand if desired.

Example configuration:
```json
{
  "bindings": {
    "ctrl+a": "take all. inventory"
  },
  "text_color": 5,
  "zart_bar_visible": true,
  "zart_bar_foreground": 9,
  "zart_bar_background": 6
}
```

### Color Codes Table 
*Per Z-Machine Spec 8.3.1*

| Code | Color        |
|------|--------------|
| 1    | Default      |
| 2    | Black        |
| 3    | Red          |
| 4    | Green        |
| 5    | Yellow       |
| 6    | Blue         |
| 7    | Magenta      |
| 8    | Cyan         |
| 9    | White        |
| 10   | Light Grey   |
| 11   | Medium Grey  |
| 12   | Dark Grey    |