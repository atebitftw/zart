import 'package:zart/z_machine.dart';
import 'dart:io';

class GameException implements Exception {
  final int addr;
  final String msg;

  GameException(this.msg) : addr = Z.engine.programCounter- 1 {
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
