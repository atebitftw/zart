import 'package:zart/src/z_machine/binary_helper.dart';
import 'package:zart/src/z_machine/interpreters/interpreter_v3.dart';
import 'package:zart/src/z_machine/game_exception.dart';
import 'package:zart/src/logging.dart' show log;
import 'package:zart/src/z_machine/operand.dart';
import 'package:zart/src/z_machine/z_machine.dart';

/// Implementation of Z-Machine v4
class InterpreterV4 extends InterpreterV3 {
  @override
  ZMachineVersions get version => ZMachineVersions.v4;

  /// Creates a new instance of [InterpreterV4].
  InterpreterV4() {
    ops[247] = scanTable;
    ops[188] = verify;
  }

  // VAR:247 17 4 scan_table x table len form -> (result)

  // Is x one of the words in table, which is len words long? If so, return the address
  // where it first occurs and branch. If not, return 0 and don't.

  // The form is optional (and only used in Version 5?): bit 7 is set for words, clear for bytes:
  // the rest contains the length of each field in the table. (The first word or byte in each field
  // being the one looked at.) Thus $82 is the default.
  /// Scans a table for a value (VAR:247).
  ///
  /// Searches table for value x. If found, returns address and branches.
  /// If not found, returns 0 and doesn't branch.
  ///
  /// ### Z-Machine Spec Reference
  /// VAR:247 (scan_table x table len form -> result)
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
      throw GameException("scan_table() expected 4 operands.  Found: ${operands.length}");
    }

    final form = operands[3].value!;
    final fieldLen = form & 0x7F;
    final isWord = BinaryHelper.isSet(form, 7);

    log.fine("scan_table operands: search: $searchWord, table: $tableAddress, table-length: $tableLength, form: $form");

    log.fine(isWord ? "form is set for word scanning" : "form is set for byte scanning");

    // Read the result store byte BEFORE the search
    final resultTo = readb();

    var addr = tableAddress!;
    for (var i = 0; i < tableLength!; i++) {
      final value = isWord ? mem.loadw(addr) : mem.loadb(addr);
      if (value == searchWord) {
        log.fine("...found match at addr 0x${addr.toRadixString(16)}");
        writeVariable(resultTo, addr);
        branch(true);
        return;
      }
      addr += fieldLen;
    }

    // Not found - store 0 and don't branch
    log.fine("...no match found");
    writeVariable(resultTo, 0);
    branch(false);
  }
}
