import 'package:zart/src/engines/engine.dart';
import 'package:zart/src/z_machine.dart';

/// Implementation of Z-Machine v3
class Version3 extends Engine {
  @override
  ZMachineVersions get version => ZMachineVersions.v3;

  /// Creates a new instance of [Version3].
  Version3();
}
