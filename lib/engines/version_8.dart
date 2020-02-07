import 'package:zart/engines/version_5.dart';
import 'package:zart/z_machine.dart';

/**
* Version 8 is basically version 5 with different memory addressing
* offsets.
*/
class Version8 extends Version5
{
  ZVersion get version => ZVersion.V8;

  // Kb
  int get maxFileLength => 512;

  int unpack(int packedAddr) => packedAddr << 3;

  int pack(int unpackedAddr) => unpackedAddr >> 3;
}
