# Change Log

# 1.0.1+1

- Reworked unit tests and added more tests. Lots more needed, and some no longe working.
- Removed all game files from library, except for minizork, which is used for unit testing.
- Added a Utils class that does useful things like emitting a pretty-print version of the game object tree.

# 1.0.1

- First pass at fixes and updates for Dart v2.7.x and publish to pub.dev on May 22, 2019.

# 1.0.0

- Initial publish of the library to pub.dev on Oct 5, 2012.

# 1.3.0
- Major overhaul of the library to support Dart >3 and above.
- More unit tests.
- Fixed some dictionary and object addressing issues.

# 1.3.1
- Updated bin/zart.dart to improve file handling.

# 1.3.2
- Updated the example to conform to pub guidelines.
- Updated license to MIT.
- Updated README.md to remove old info and add new info.

# 1.3.3
- `dart format` run on all files.
- Simplified internal logging.

# 1.3.4
- Updated pubspec.yaml to use ^3.10.3 for SDK version.

# 1.3.5
- Fixed an issue with directory names that made pub unhappy.

# 1.3.6

# 1.3.7
- Fixed formatting issues.

# 1.4.0
- Added GitHub Actions CI and Badge.
- Enhanced Quetzal save and restore support.
- ZSCII support for custom tables added.
- Added more unit tests.
- Added more documentation comments.

# 1.4.1
- Removed dart:io references for WASM support.

# 1.4.2
- Fixed some unit tests that were no longer working.
- Added some game files for testing.
- Engine bug fix.

# 1.5.0
- Fixed some bugs that prevented play of some z5 - z8 games.
- Added more unit tests.

# 1.5.1
- Disabled debug output by default.

# 1.6.0
- Improved state management on subsequent plays.
- Fixed async bug in z5+ opcode calls.
- Reconfigured z-machine to use a pump API for better compatiblity with Flutter.
- Improved all math operations to be compatible with Flutter web (javascript) targets.
- Added more unit tests.

# 1.6.1
- Fixed a ZSCII issue with some text not being displayed correctly.

# 1.6.2
- README updates.

# 1.7.0
- Fixed some issues with text output when stream 3 is selected.
- Added more op code support for z5+.

# 1.7.1
- Console interpreters now support chained commands (e.g., "get up.take all.north")

# 1.7.2
- Fixed a repeating text bug with stream 3.

# 1.7.3
- Reverted 1.7.2

# 1.7.4
- Improved console player output.  Now supports ANSI color and better display of status bar for z5+ games.

# 1.7.5
- Fixed a bug with the console player that caused it to display input carets improperly.

# 1.7.6
- renamed some classes to be more consistent.

# 1.7.7
- Added missing files.

# 1.7.8
- Fixed a bug that miscalculated some property lookups in v4+ games.

# 1.7.9
- Added save/restore support for z5+ games.  Interpreters that support save/restore for z3 games will automatically work for z5+ games as well now.

# 1.7.10
- Fixed a save/restore bug in the console player.  Files now save in the current directory.

# 1.7.11
- Added support for z5+ readChar expanded values so that IoProvider's can handle things like arrow-keys, etc.

# 1.7.12
- Fixed a bug in the quetzal save/restore format that was causing some games to not restore properly.

# 1.7.13
- Fixed some issues with z5+ opcodes and the way that div/0 is handled.

# 1.8.0
- Fixed a bunch of bugs with ZSCII, Dictionary, and Op Code handling.
- Completely overhauled the zart console player.  It now uses full ANSI-compliant directives for screen and color support.
- Added more unit tests.

# 1.8.1
- Exposed ScreenModel API, which allows custom players to implement their own display logic.

# 1.8.2
- Fixed a bug with the v5+ tokenise opcode that would cause some games to parse input incorrectly.
- Added more unit tests.

# 1.8.3
- Improved support for z5+ game files that use complex window 1 features, or write outside window 1 bounds.
- Added more unit tests.

# 1.8.4
- Removed debugging output.

# 1.8.5
- Save/Restore for TerminalProvider
- Added more unit tests.

# 1.8.6
- Fixed a bug with backspace in the console player.
- Arrow keys are now supported in the console player.
- Fixed a cursor alignment issue during certain windowing operations.

# 1.9.0
- CLI player now supports key macro binding, auto-save/restore, and color selection of text output (window 0 only).

# 1.9.1
- Added text scrolling for the CLI player window 0 (the main game window).
- Added readme file for the CLI player.
- "Zart bar" colors and visibility are now configurable (see README.md in bin/)

# 1.9.2
- README.md updated

# 1.9.3
- Improved CLI player settings screen options and layout.

# 2.0.0
- Added support for Glulx interpreter.  Zart now supports both Z-Machine and Glulx (Inform 6 & 7) games.
- Removed CLI player and moved it to it's own repository: https://github.com/atebitftw/zart-cli.  Required because it has dependencies on that are not available on all platforms.
- Fixed many bugs.
- Updated documentation.
- Added more unit tests.

# 2.0.1
- Fixed a bug with save/restore in the Glulx interpreter.

# 2.0.2
- Fixed a another bug with save/restore in the Glulx interpreter.

# 2.0.3
- GameRunner supports lifecycle events better.
- Removed special character from title screen.

# 2.0.4
- Optimized glulx interpreter.
