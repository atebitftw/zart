import 'dart:async';
import 'package:zart/src/zart_internal.dart' show ZIoDispatcher;

/// Mock UI Provider for Unit Testing
class MockUIProvider implements ZIoDispatcher {
  Future<int> glulxGlk(int selector, List<int> args) => Future.value(0);

  @override
  Future<Object?> command(Map<String, dynamic> command) async {
    print('Command received: ${command['command']} ');
    return null;
  }

  @override
  int getFlags1() => 0;
}
