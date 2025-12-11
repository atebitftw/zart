import 'package:zart/src/interpreters/interpreter_v5.dart';
import 'package:zart/src/z_machine.dart';

/// Version 8 is basically version 5 with different memory addressing
/// offsets.
class InterpreterV8 extends InterpreterV5 {
  @override
  ZMachineVersions get version => ZMachineVersions.v8;

  // Kb
  @override
  int get maxFileLength => 512;

  @override
  int unpack(int packedAddr) => packedAddr << 3;

  @override
  int pack(int unpackedAddr) => unpackedAddr >> 3;
}
