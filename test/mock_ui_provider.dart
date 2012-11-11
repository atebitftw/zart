part of tests;

/**
* Mock UI Provider for Unit Testing
*/
class MockUIProvider implements IOProvider
{

  Future<Object> command(String JSONCommand){
    var c = new Completer();
    var cmd = JSON.parse(JSONCommand);
    print('Command received: ${cmd[0]} ');
    c.complete(null);
    return c.future;
  }

}
