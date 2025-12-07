import 'package:zart/src/z_machine.dart';
import 'dart:io';

class GameException implements Exception {
  int addr = 0;
  final String msg;

  GameException(this.msg) {
    try {
      addr = Z.engine.programCounter - 1;
    } catch (_) {
      addr = 0;
    }
    stdout.writeln(this);
  }

  @override
  String toString() {
    try {
      return 'Z-Machine exception: [0x${addr.toRadixString(16)}] $msg\n';
    } on Exception catch (_) {
      return msg;
    }
  }
}
