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
There are Interactive Fiction communities online that can get you started.  Minizork is included in this library for unit testing purposes, but you can also play it if you wish.

Here are some links to some popular games:

**I make NO warranty as to the safety or usability of these links/files.  Proceed with caution.**

* Zork Series: You can find these online.  Unfortunately, I can't put the link here because it's http instead of https.  Contact me if you need help.
* Hitchiker's Guide To The Galaxy: https://www.myabandonware.com/game/the-hitchhikers-guide-to-the-galaxy-42
* Infidel: https://www.myabandonware.com/game/infidel-2d

## How Do I Play Games With This Library
You would have to write your own client which would manage the i/o between the player and the interpreter.

You can also run the CLI utility to play games from the command line:

```bash
dart pub global activate zart
zart path/to/minizork.z3
```

## How To Contribute
Clone.  Code.  Submit pull request.  I'm open to any reasonable submissions.
    
## Reference Material
* Z-Machine spec used to develop this library: https://www.inform-fiction.org/zmachine/standards/

## Fun Fact
This was the first package ever published to https://pub.dev back in the day.