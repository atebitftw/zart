import 'package:zart/src/engines/version_5.dart';
import 'package:zart/src/z_machine.dart';
import 'package:zart/zart.dart';
import 'package:zart/src/zscii.dart';

/// Implementation of Z-Machine v7
class Version7 extends Version5 {
  @override
  ZMachineVersions get version => ZMachineVersions.v7;

  // Kb
  @override
  int get maxFileLength => 320;

  @override
  int unpack(int packedAddr) {
    return (packedAddr << 2) + (mem.loadw(Header.routinesOffset) << 3);
  }

  @override
  int pack(int unpackedAddr) {
    throw GameException("Unsupported call to pack() in Version 7 engine.");
  }

  /// Unpacks a print address.
  int unpackPAddr(int packedPrintAddr) {
    return (packedPrintAddr << 2) + (mem.loadw(Header.stringsOffset) << 3);
  }

  @override
  void printPAddr() {
    //Debugger.verbose('${pcHex(-1)} [print_paddr]');

    var operand = visitOperandsShortForm();

    var addr = unpackPAddr(operand.value!);

    var str = ZSCII.readZStringAndPop(addr);

    Debugger.verbose('${pcHex()} "$str"');

    Z.sbuff.write(str);
  }
}
