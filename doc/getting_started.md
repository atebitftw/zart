# Getting Started
- [Try It Out Using The CLI Player](#try-it-out-using-the-cli-player)
- [Building Your Own Player](#building-your-own-player)

## Try It Out Using The CLI Player
To run a game of MiniZork in CLI, first activate the zart package:

```bash
dart pub global activate zart
```

Then run:

(minizork game, included with the project)
```bash
zart assets/games/minizork.z3
```

## Building Your Own Player
Zart comes complete with two of the most popular interpreters in the IF world: the Z-Machine and the Glulx interpreter.  It provides a clean abstraction API over both of these platforms and allows you to build your own player for any platform that Flutter/Dart runs on.

Building your own player involves implementing the `PlatformProvider` interface, and passing it to the `GameRunner` class.  You can see a full
example of this in the `example/` or `bin/` directories for the CLI player.  You will see that the example uses a `CliPlatformProvider` to implement the API.

You can also view the [Zart Web Player](https://atebitftw.github.io/site/), which is a full-featured web player, built with Flutter, that uses the Zart library to run games.  The project is located here on Github: [Zart Web Player On Github](https://github.com/atebitftw/zart-player).

Essentially, you wire up all your UI and IO to the API, and it will handle the rest.  The API will pass you screen updates in the render() function and all you have to do is translate those updates into your UI.  You will also receive input events in the handleInput() function, and you can use the save/restore events to save and restore the game state.

For a full explaination of the PlatformProvider API, see the [Zart API Documentation](https://pub.dev/documentation/zart/latest/).

### The API Model
The Zart library provides a unified API for running IF games of any type.

```
┌───────────────────────────────────────────────────────┐
│         Presentation Layer (CLI/Flutter App)          │
│  - Implements PlatformProvider and:                   │
│    - Declares capabilities (fonts, colors, etc)       │
│    - Receives screen updates and renders them.        │
│    - Passes input events to the API.                  │
│    - Handles Save/Restore requests.                   │
└───────────────────────────────────────────────────────┘
                           ▲
                           │
                           │  API
┌───────────────────────────────────────────────────────┐
│           PlatformProvider (API Interface)            │
└───────────────────────────────────────────────────────┘
                           ▲
                           │
                           │ Interacts with API to run games.
    ┌─────────────────────────────────────────────┐
    │           GameRunner                        │
    │  - Receives API Implementation              │
    │  - Detects Game Type                        │
    │  - Handles Between API and IO/VM            │
    └─────────────────────────────────────────────┘
            ▲                        ▲
            │                        │
    ┌───────────────────┐   ┌───────────────────┐
    │  Z-Machine IO     │   │  Glulx/Glk IO     │
    │  (ZScreenModel)   │   │  (GlkScreenModel) │
    └───────────────────┘   └───────────────────┘
            ▲                        ▲
            │                        │
    ┌───────────────────┐   ┌───────────────────┐
    │  Z-Machine VM     │   │  Glulx VM         │
    │  (Interpreter)    │   │  (Interpreter)    │
    └───────────────────┘   └───────────────────┘
```