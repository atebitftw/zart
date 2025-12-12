import 'dart:io';
import 'package:zart/src/z_machine.dart';
import 'v8_object_tests.dart';

void main() {
  // Tests depend on using this file.  Tests will fail if changed.
  var defaultGameFile = 'assets/games/across.z8';

  File f = File(defaultGameFile);

  try {
    Z.load(f.readAsBytesSync());
  } on Exception catch (e) {
    stdout.writeln('$e');
    exit(1);
  }

  if (Z.isLoaded) {
    objectTestsV8();
  } else {
    print('Game not loaded');
    exit(1);
  }
}
