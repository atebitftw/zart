import 'package:zart/z_machine.dart';
import 'package:zart/debugger.dart';

class GameException implements Exception
{
  final int addr;
  final String msg;

  GameException(this.msg)
  :
    addr = Z.machine.PC - 1;

  String toString() {
    try{
      return 'Z-Machine exception: [0x${addr.toRadixString(16)}] $msg\n${Debugger.crashReport()}';
    } on Exception catch (_){
      return msg;
    }
  }
}
