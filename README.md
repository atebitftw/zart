# Zart
[![Dart CI](https://github.com/atebitftw/zart/actions/workflows/dart.yaml/badge.svg)](https://github.com/atebitftw/zart/actions/workflows/dart.yaml)

A modern, multi-platform interpreter library, for playing Interactive Fiction (IF) games.

![Zart CLI Title Screen](https://atebitftw.github.io/site/assets/zart_cli_title_screen.png)

Some of my most memorable early gaming experiences were playing Infocom interactive fiction (IF) games.  I also love programming and so decided to write my own interpreter in Dart.

This project is a labor of love.
	
Enjoy!

## Features
* Plays Z-Machine ("Infocom" games).
* Plays Inform v6 & v7 games.
* Supports all popular game file formats (.z3, .z5, .z8, .dat, .blorb, .zblorb, .gblorb, .ulx, etc).
* Provides an API that allows you to build your own player for any platform that Flutter/Dart runs on.
* Full-features CLI player and Flutter Web Player available.

## Getting Started
[You Can Read The Full Getting Started Document Here.](https://github.com/atebitftw/zart/blob/main/doc/getting_started.md)

You'll need a player that uses the Zart library.  I've provided a CLI player and a Flutter Web Player.

### Zart Web Player
You can use the Zart Web Player App, written in Flutter.  You can find the app here at my project website: https://atebitftw.github.io/site/. The player uses the Zart library to run the games.

Zart Web Player is open source.  You can find the project here: [Zart Web Player On Github](https://github.com/atebitftw/zart-player).

### Zart CLI Player
The CLI Player is a full-featured terminal player.

The CLI Player is open source.  You can find the project here: [Zart CLI Player On Github](https://github.com/atebitftw/zart_cli).

If you have the Flutter or Dart SDK installed, you can install the CLI player using the following command:

```bash
flutter pub global activate --source git git@github.com:atebitftw/zart_cli.git
```

Then you can run it this way:

(using minizork as an example)
```bash
zart minizork.z3
```

### Roll Your Own
Use the Zart library to build your own player.  You would have to write your own client which would manage the i/o between the player and the interpreter.  The Zart library provides all the necessary functionality.

For more information, see the [Zart API Docs](https://pub.dev/documentation/zart/latest/).

## How Can I Author My Own IF Games? 
[Inform 7](https://ganelson.github.io/inform-website/) is a great tool for authoring IF games.  It is a high-level language that allows you to write IF games without having to worry about the underlying mechanics.  It is also free and open source.

## Where Can I Find Games To Play? 
* **Zork Series:**  Search up "infocom-if . org" for the Zork series.  *Unfortunately I cannot link to it directly in this document because the site is old and still rocking http, not https.*
* **Many excellent games can be found here:** [IFDB.org](https://www.ifdb.org/)

*As always, use caution when downloading games and files from the Internet.*

## How To Contribute To This Project?
Fork. Code. Submit pull request. I'm open to any reasonable submissions.
    
## Gratitudes and Attributions
This project stands on the shoulders of Andrew "Zarf" Plotkin (among many others, I'm sure) and his work establishing standards for the IF community.  Thanks Andrew, et al.

[Andrew's Site](https://eblong.com/zarf/sitemap.html#code)

## Fun Fact
This was the first package ever published to https://pub.dev.