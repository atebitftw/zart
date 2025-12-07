import 'dart:async';
import 'dart:io';

import 'package:zart/zart.dart' show IoProvider;

/// Mock UI Provider for Unit Testing
class MockUIProvider implements IoProvider {
  @override
  Future<Object?> command(Map<String, dynamic> command) async {
    stdout.writeln('Command received: ${command['command']} ');
    return null;
  }
}
