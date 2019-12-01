library v8_tests;

import 'dart:io';
import 'package:zart/z_machine.dart';
import 'v8_object_tests.dart';

main() {
  // Tests depend on using this file.  Tests will fail if changed.
  var defaultGameFile = 'games${Platform.pathSeparator}across.z8';

  File f = File(defaultGameFile);

  try {
    Z.load(f.readAsBytesSync());
  } on Exception catch (e) {
    //TODO log then print friendly
    print('$e');
    exit(1);
  }

  if (Z.isLoaded) {
    objectTestsV8();
  }
}
