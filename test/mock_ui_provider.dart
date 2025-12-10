import 'dart:async';
import 'package:zart/zart.dart' show IoProvider;

/// Mock UI Provider for Unit Testing
class MockUIProvider implements IoProvider {
  @override
  Future<Object?> command(Map<String, dynamic> command) async {
    print('Command received: ${command['command']} ');
    return null;
  }

  @override
  int getFlags1() => 0;
}
