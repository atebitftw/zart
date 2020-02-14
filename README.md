## Zart - Dart Implementation of Infocom Z-Machine ##
	West of House
	You are standing in an open field west of a white house, with a boarded 
	front door. You could circle the house to the north or south.
	
	There is a small mailbox here.

	> open the mailbox

Some of my most memorable early gaming experiences were playing Infocom interactive fiction games.  I also love programming and so decided to write my own interpreter in Dart.

This project is a labor of love.
	
Enjoy!

## Features ##
* Plays V3, V5, V7, and V8 games (see "Limitations" below).
* Supports loading raw game files (.z3, .z5, .z8, .dat, etc).
* Supports loading .zblorb files, but only uses the game file from the package at this time.
* Separates the UI implementation from the core interpreter functions, providing extensibility to virtually any platform that Dart runs on (currently Mac, Linux, Windows, and Web).

## Limitations ##

**Older Games May Not Work**
Some games, especially ones compiled with older versions of Inform, may not work properly.  Trial and error is the only way to know.  Please report any bugs while playing games with this interpreter here: https://github.com/prujohn/zart/issues.

The older Infocom games (V3 & V5) appear to work fine.

Games compiled with the latest Inform 7 appear to work fine.

## Want to author your own IF games? ##
<http://inform7.com/>

## Where can I find games to play? ##
There are Interactive Fiction communities online that can get you started.  Minizork is included in this library for unit testing purposes, but you can also play it if you wish.

Here are some links to some popular games:

**I make NO warranty as to the safety or usability of these links/files.  Proceed with caution.**

* Zork Series: http://infocom-if.org/downloads/downloads.html  (you will need to download the .zip file and then find the ".dat" file, which is the actual game file needed by this interpreter).
* Hitchiker's Guide To The Galaxy: https://www.myabandonware.com/game/the-hitchhikers-guide-to-the-galaxy-42
* Infidel: https://www.myabandonware.com/game/infidel-2d

## How Do I Play Games With This Library
You would have to write your own client which would manage the i/o between the player and the interpreter.

I have started working on a web based player, which is still in very early stages: https://prujohn.github.io/zart/#/

I will be open-sourcing the code for it soon.

## Next Steps ##
* Bug fixes, optimization, enhancements to some op codes.
* Add in some detection to warn if the game file may not be playable.
* Improve unit test coverage.

## How To Contribute ##
Clone.  Code.  Submit pull request.  I'm open to any reasonable submissions.
    
## Reference Material ##
* Z-Machine spec used to develop this library: https://www.inform-fiction.org/zmachine/standards/

## License ##
Source Code: Apache 2.0 (see LICENSE file)

Any game files include are covered under their own applicable copyrights and licensing.

## Fun Fact ##
This was the first package ever published to https://pub.dev back in the day.