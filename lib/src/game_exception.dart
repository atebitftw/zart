import 'package:zart/src/z_machine.dart';
import 'dart:io';

/// Exception class for game errors.
class GameException implements Exception {
  /// The address of the exception.
  late final int addr;

  /// The message of the exception.
  final String msg;

  /// Initializes a new instance of the [GameException] class.
  GameException(this.msg) {
    try {
      addr = Z.engine.programCounter - 1;
    } catch (_) {
      addr = 0;
    }
    stdout.writeln(this);
  }

  /// Returns a string representation of the exception.
  @override
  String toString() {
    try {
      return 'Z-Machine exception: [0x${addr.toRadixString(16)}] $msg\n';
    } on Exception catch (_) {
      return msg;
    }
  }
}
