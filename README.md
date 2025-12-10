# Zart
[![Dart CI](https://github.com/atebitftw/zart/actions/workflows/dart.yaml/badge.svg)](https://github.com/atebitftw/zart/actions/workflows/dart.yaml)

Dart Implementation of the Infocom Z-Machine.

```
West of House
You are standing in an open field west of a white house, with a boarded front door. You could circle the house to the north or south.

There is a small mailbox here.

> open the mailbox
```

Some of my most memorable early gaming experiences were playing Infocom interactive fiction (IF) games.  I also love programming and so decided to write my own interpreter in Dart.

This project is a labor of love.
	
Enjoy!

## Features
* Plays V3, V5, V7, and V8 games.
* Supports loading raw game files (.z3, .z5, .z8, .dat, etc).
* Supports loading .zblorb files, but only uses the game file from the package at this time.
* Separates the UI implementation from the core interpreter functions, providing extensibility to virtually any platform that Dart runs on (currently Mac, Linux, Windows, and Web).

## Want to author your own IF games? 
[Inform 7](https://ganelson.github.io/inform-website/)

## Where can I find games to play? 
There are Interactive Fiction communities online that can get you started.

* IFDB: https://www.ifdb.org/  This is a good resource to download and play IF games.

## How Do I Play Games With This Library
### CLI
You can install and run the CLI utility to play games from the command line:

```bash
dart pub global activate zart
zart path/to/minizork.z3
```

I would only recommend playing version 3 games with this CLI tool because some of the newer games use special screen features that are not well-supported in a CLI environment.  The good news is that all of the classic games are usually version 3.

### Zart Web Player
You can use the Zart Web Player App, written in Flutter.  You can find the app here at my project website: https://atebitftw.github.io/site/. The player uses the Zart library to play games.

### Roll Your Own
Use the Zart library to build your own player.  You would have to write your own client which would manage the i/o between the player and the interpreter.  The Zart library provides all the necessary functionality.


## How To Contribute
Fork. Code. Submit pull request. I'm open to any reasonable submissions.

The interpreter currently only loads the game file from any .blorb/.zblorb file (these are like bundled game files for IF games).  It does not load any of the other resources from the .blorb file, like images, etc, and it ignores any audio/image commands from the game.  So this could be one area to expand on.
    
## Reference Material
* Z-Machine spec used to develop this library: https://www.inform-fiction.org/zmachine/standards/

## Fun Fact
This was the first package ever published to https://pub.dev back in the day.