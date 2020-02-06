import 'package:zart/debugger.dart';
import 'package:zart/header.dart';
import 'package:zart/machines/version_5.dart';
import 'package:zart/zart.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert' as JSON;

import 'package:zart/IO/io_provider.dart';

/**
* Mock UI Provider for Unit Testing
*/
class MockUIProvider implements IOProvider
{

  Future<Object> command(String JSONCommand){
    var c = Completer();
    var cmd = JSON.json.encode(JSONCommand);
    print('Command received: ${cmd[0]} ');
    c.complete(null);
    return c.future;
  }

}

main(){
    final s = Platform.pathSeparator;
  var defaultGameFile = 'assets${s}games${s}etude.z5';

  final f = File(defaultGameFile);

  try {
    Z.load(f.readAsBytesSync());
  } on Exception catch (fe) {
    //TODO log then print friendly
    print('$fe');
    exit(1);
  }

  const int version = 3;
  const int programCounterAddress =
      14297; // initial program counter address for minizork
  final machine = Version5();

  Debugger.setMachine(machine);
  Z.IOConfig = MockUIProvider();

  print(Debugger.dumpHeader());
  print(Debugger.getObjectTree(1));
}