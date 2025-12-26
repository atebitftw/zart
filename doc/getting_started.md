# Getting Started

Zart comes complete with two of the most popular interpreters in the Interactive Fiction (IF) world: the Z-Machine and the Glulx interpreter.  It provides a clean abstraction API over both of these platforms and allows you to build your own player for any platform that Flutter/Dart runs on.

Building your own player involves implementing the `PlatformProvider` interface, and passing it to the `GameRunner` class.

Full examples of this can be found:

- [CLI Player On Github](https://github.com/atebitftw/zart-cli) Only tested on Windows but should work on Mac/Linux.  Requires Flutter or Dart SDK installed.
- [Zart Web Player On Github](https://github.com/atebitftw/zart-player) ([Play Online](https://atebitftw.github.io/site/))

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