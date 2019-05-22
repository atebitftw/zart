import 'dart:async';
import 'dart:convert' as JSON;

import 'package:zart/IO/io_provider.dart';

/**
* Mock UI Provider for Unit Testing
*/
class MockUIProvider implements IOProvider
{

  Future<Object> command(String JSONCommand){
    var c = new Completer();
    var cmd = JSON.json.encode(JSONCommand);
    print('Command received: ${cmd[0]} ');
    c.complete(null);
    return c.future;
  }

}
