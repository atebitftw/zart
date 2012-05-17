## Zart - Dart Implementation of Infocom Z-Machine ##
Some of my most memorable early gaming experiences where Infocom interactive fiction games.

This project is a labor of love.  I'll start with z-machine v3 and see where it goes...

## Status - In Progress, Playable! ##
Minizork is included with the source and is playable.

To run the game, run the ZConsole.dart app (it works in the Dart Editor console too).

Not all opcodes are implemented yet, but so there may be a grue or two around some corners in minizork...

	Copyright (c) 1988 Infocom, Inc. All rights reserved.
	ZORK is a registered trademark of Infocom, Inc.
	Release 34 / Serial number 871124

	West of House
	You are standing in an open field west of a white house, with a 
	boarded front door. You could circle the house to the north or south.
	There is a small mailbox here.

	>
	
Enjoy!

### Next Steps ###
* Finish up the remaining opcodes for V3 Z-Machine.
* Build a web-based player and a more refined console player (word wrap, etc).
* Work on some later machine versions (V5, V8) etc.
* Load/Save game options.

## Debugging ##
There is a VERY basic runtime debugger included.  To enter it, type **/!** at any prompt.
Doing so will drop you into a simple REPL.

### Debug Commands ###
* **locals** - dumps out locals for the current routine.
* **globals** - dumps out globals.
* **dictionary** - dumps out the game dictionary.
* **move x to y** - moves object #x to object #y
* **object x** - dumps info regarding object #x.
* **enable (tracing|verbose)** - enables tracing or verbose debug mode.
* **disable (tracing|verbose)** - disables tracing or verbose debug mode.
* **q** - leave debug mode and return to game.

You can also enable tracing and/or verbose with:

	Debugger.enableDebug = true;  //toggles all debug options
    Debugger.enableTrace = true;
    Debugger.enableVerbose = true;
    
## Reference Material ##
* Z-Machine Spec: http://www.gnelson.demon.co.uk/zspec/index.html

## Acknowledgements ##
Adam Smith (RNG class found here: https://github.com/financeCoding/DRandom/blob/master/DRandom.dart)