import 'dart:async';
import 'package:zart/zart.dart' show IoProvider;

/// Mock UI Provider for Unit Testing
class MockUIProvider implements IoProvider {
  Future<int> glulxGlk(int selector, List<int> args) => Future.value(0);

  @override
  Future<Object?> command(Map<String, dynamic> command) async {
    print('Command received: ${command['command']} ');
    return null;
  }

  @override
  int getFlags1() => 0;
}
