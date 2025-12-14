# Zart
[![Dart CI](https://github.com/atebitftw/zart/actions/workflows/dart.yaml/badge.svg)](https://github.com/atebitftw/zart/actions/workflows/dart.yaml)

Dart Implementation of the Infocom Z-Machine.

```text
West of House
You are standing in an open field west of a white house,
with a boarded front door. You could circle the house to 
the north or south.

There is a small mailbox here.
>
```

Some of my most memorable early gaming experiences were playing Infocom interactive fiction (IF) games.  I also love programming and so decided to write my own interpreter in Dart.

This project is a labor of love.
	
Enjoy!

## Features
* Plays V3, V5, V7, and V8 games.
* Supports loading different types of game files (.z3, .z5, .z8, .dat, .blorb, .zblorb, etc).
* Provides an API that allows you to build your own player for any platform that Dart runs on.
* Comes with a full-featured CLI player.

## How Can I Author My Own IF Games? 
[Inform 7](https://ganelson.github.io/inform-website/)

## Where Can I Find Games To Play? 
* **Zork Series:**  Search up "infocom-if . org" for the Zork series.  *Unfortunately I cannot link to it directly in this document because the site is old and still rocking http, not https.*
* **Many games can be found here:** [IFDB.org](https://www.ifdb.org/)

*As always, use caution when downloading games and files from the Internet.*

## How Do I Play Games With Zart?
You'll need a player that uses the Zart library.  I've provided a CLI player and a web player.

### Zart Web Player
You can use the Zart Web Player App, written in Flutter.  You can find the app here at my project website: https://atebitftw.github.io/site/. The player uses the Zart library to run the games.

You can get the Zart Web Player source code here: [Zart Web Player On Github](https://github.com/atebitftw/zart-player).

### CLI Player
The CLI player is a full-featured terminal player that supports modern quality-of-life features while remaining true to the original experience:
- Custom key bindings (macros)
- Color selection
- Zart bar visibility and color customization
- Quick-save/restore
- Text scrolling with mouse wheel support.

For more information, see the [CLI Player README](https://github.com/atebitftw/zart/blob/main/bin/README.md).

#### Flutter/Dart SDK Required
You will need the Flutter/Dart SDK installed on your system to use the CLI player.  You can download it from [Dart SDK Download](https://dart.dev/get-dart) or [Install Flutter](https://docs.flutter.dev/install).  Flutter comes with the Dart SDK.

#### Installation
You can then install the `zart` CLI player and run it to play games from the command line:

```bash
> dart pub global activate zart
> zart path/to/minizork.z3
```

*The source code for the CLI player is included in this package, in either the `bin/` or `example/` directories.*

### Roll Your Own
Use the Zart library to build your own player.  You would have to write your own client which would manage the i/o between the player and the interpreter.  The Zart library provides all the necessary functionality.

## How To Contribute
Fork. Code. Submit pull request. I'm open to any reasonable submissions.

Better support for z-machine v6 (the version we shall not speak of) is always nice.  If loading a .blorb/.zblorb file, the interpreter currently only loads the game file from the file bundle. It does not load any of the other resources from the .blorb file, like images, etc, and it ignores any audio/image commands from the game.  So this could be one area to expand on.
    
## Reference Material
* Z-Machine spec used to develop this library: https://www.inform-fiction.org/zmachine/standards/

## Fun Fact
This was the first package ever published to https://pub.dev back in the day.