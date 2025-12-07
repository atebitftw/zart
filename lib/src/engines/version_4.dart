import 'package:zart/src/binary_helper.dart';
import 'package:zart/src/engines/version_3.dart';
import 'package:zart/src/game_exception.dart';
import 'package:zart/src/operand.dart';
import 'package:zart/src/z_machine.dart';

/// Implementation of Z-Machine v4
class Version4 extends Version3 {
  @override
  ZMachineVersions get version => ZMachineVersions.v4;

  Version4() {
    logName = "Version4";
    ops[247] = scanTable;
  }

  // VAR:247 17 4 scan_table x table len form -> (result)

  // Is x one of the words in table, which is len words long? If so, return the address
  // where it first occurs and branch. If not, return 0 and don't.

  // The form is optional (and only used in Version 5?): bit 7 is set for words, clear for bytes:
  // the rest contains the length of each field in the table. (The first word or byte in each field
  // being the one looked at.) Thus $82 is the default.
  void scanTable() {
    //v4 expects only 3 operands, x table len
    final operands = visitOperandsVar(4, true);

    final searchWord = operands[0].value;
    final tableAddress = operands[1].value;
    final tableLength = operands[2].value;

    if (operands.length == 3) {
      operands.add(Operand(OperandType.small)..rawValue = 0x82);
    }

    if (operands.length != 4) {
      throw GameException(
        "scan_table() expected 4 operands.  Found: ${operands.length}",
      );
    }

    final form = operands[3].value!;

    log.fine(
      "scan_table operands: search: $searchWord, table: $tableAddress, table-length: $tableLength, form: $form",
    );

    log.fine(
      BinaryHelper.isSet(form, 7)
          ? "form is set for word scanning"
          : "form is set for byte scanning",
    );

    if (BinaryHelper.isSet(form, 7)) {
      log.fine("..word scan");
      var addr = tableAddress;
      for (var i = 0; i < tableLength!; i++) {
        final value = mem.loadw(addr!);
        if (value == searchWord) {
          log.fine("...found match");
          final resultTo = readb();
          writeVariable(resultTo, addr);
          branch(true);
          return;
        }
        addr += form & 0x7f; // little trick I picked up from Frotz...
      }
    } else {
      log.fine("..byte scan");
      //byte scan
      for (var i = 0; i < tableLength!; i++) {
        var addr = tableAddress;
        for (var i = 0; i < tableLength; i++) {
          final value = mem.loadb(addr!);
          if (value == searchWord) {
            log.fine("...found match");
            final resultTo = readb();
            writeVariable(resultTo, addr);
            branch(true);
            return;
          }
          addr += form & 0x7f;
        }
      }
    }

    doReturn(0);
  }
}
