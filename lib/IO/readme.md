# Using The IOProvider interface #
IO Providers allow devs to plug in their own presentation interface, such
that the engine will route and accept IO via that interface.

The library provides a default console provider (ConsoleProvider.dart).

## Other Possibilities ##
* Web
* Handheld
* Tablet

## Registering A Provider ##
    Z.load(storyFileBytes);

    // Do this anytime before running the z-machine.
    Z.IOConfig = new MyIOProvider();
    Z.run();
    // That's it.