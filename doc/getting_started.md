## From the console
To run a game of MiniZork in CLI, first activate the zart package:

```bash
dart pub global activate zart
```

Then run:

```bash
zart path/to/minizork.z3
```

You should be able to run any Z-machine game file up to version 8.


## Debugging
There is a VERY basic runtime debugger included.  To enter it, type **/!** at any prompt.
Doing so will drop you into a simple REPL.

### Debug Commands
* **locals** - dumps out locals for the current routine.
* **globals** - dumps out globals.
* **dictionary** - dumps out the game dictionary.
* **move x to y** - moves object #x to object #y
* **object x** - dumps info regarding object #x.
* **enable (tracing|verbose)** - enables tracing or verbose debug mode.
* **disable (tracing|verbose)** - disables tracing or verbose debug mode.
* **header** - dumps header information
* **dump addr len** dumps memory from address 'addr' to length
* **stacks** - dumps the call stack and the game stack.
* **q** - leave debug mode and return to game.
* **n or Enter** - advance to the next instruction.

You can also enable tracing and/or verbose with:

	Debugger.enableDebug = true;  //toggles all debug options
    Debugger.enableTrace = true;
    Debugger.enableVerbose = true;