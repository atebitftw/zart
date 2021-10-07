import 'package:zart/engines/version_5.dart';
import 'package:zart/z_machine.dart';


/// Version 8 is basically version 5 with different memory addressing
/// offsets.
class Version8 extends Version5
{
  @override
  zMachineVersions get version => zMachineVersions.v8;

  // Kb
  @override
  int get maxFileLength => 512;

  @override
  int unpack(int packedAddr) => packedAddr << 3;

  @override
  int pack(int unpackedAddr) => unpackedAddr >> 3;
}
