import 'dart:async';
import 'dart:io';

import 'package:zart/IO/io_provider.dart';

/// Mock UI Provider for Unit Testing
class MockUIProvider implements IOProvider
{

  @override
  Future<Object?> command(Map<String, dynamic> command) async {
    stdout.writeln('Command received: ${command['command']} ');
    return null;
  }
}
