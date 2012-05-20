
class GameException implements Exception
{
  final int addr;
  final String msg;

  GameException(this.msg)
  :
    addr = Z.machine.pc - 1;

  String toString() {
    try{
      return 'Z-Machine exception: [0x${addr.toRadixString(16)}] $msg\n${Debugger.crashReport()}';
    }catch (Exception e){
      return msg;
    }
  }
}
