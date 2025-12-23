## Try It Out Using The CLI Player
To run a game of MiniZork in CLI, first activate the zart package:

```bash
dart pub global activate zart
```

Then run:

(z-machine game)
```bash
zart path/to/minizork.z3
```

or

(glulx game)
```bash
zart path/to/minizork.ulx
```

## The API Model
The Zart library handles running the interpreter for whichever type of game you are playing (Z-Machine or Glulx).  It also provides a abstraction layer for the screen model and input events, so that you can build your own player for any platform that Dart runs on, by rendering the screen information and handling input events.
```
┌───────────────────────────────────────────────────────┐
│            Presentation Layer (CLI/Web/Flutter)       │
│  - Extends PlatformProvider and implements:           │
│    - Gestalt query interface                          │
│    - Receives unified cells and renders them          │
│    - Handles input events                             │
│    - Save/Restore events                              │
└───────────────────────────────────────────────────────┘
                           ▲
                           │  Unified Cell Grid + Events
                           │
┌───────────────────────────────────────────────────────┐
│                  PlatformProvider                     │
│  - Common cell type (char, fg, bg, bold, italic)      │
│  - Window regions with positions                      │
│  - Capability query interface (gestalt-like)          │
└───────────────────────────────────────────────────────┘
                ▲                       ▲
                │                       │
    ┌───────────────────┐   ┌───────────────────┐
    │  Z-Machine IO     │   │  Glulx/Glk IO     │
    │  (ScreenModel)    │   │  (GlkScreenModel) │
    └───────────────────┘   └───────────────────┘
```