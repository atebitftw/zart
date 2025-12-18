import 'dart:typed_data';

import 'package:zart/src/glulx/glulx_locals_descriptor.dart';
import 'package:zart/src/glulx/glulx_memory_map.dart';
import 'package:zart/src/glulx/typable_objects.dart';

/// Spec Section 1.4.2: Functions
abstract class GlulxFunction extends GlulxTypable {
  /// The descriptor for local variables.
  final GlulxLocalsDescriptor localsDescriptor;

  /// The address where opcodes begin.
  final int entryPoint;

  GlulxFunction(int address, GlulxTypableType type, this.localsDescriptor, this.entryPoint) : super(address, type);

  /// Parses a function from memory at the given address.
  ///
  /// Spec 1.4.2: "Functions have a type byte of C0 (for stack-argument functions)
  /// or C1 (for local-argument functions). Types C2 to DF are reserved."
  static GlulxFunction parse(GlulxMemoryMap memory, int address) {
    final typeByte = memory.readByte(address);
    final type = GlulxTypableType.fromByte(typeByte);

    if (type != GlulxTypableType.functionC0 && type != GlulxTypableType.functionC1) {
      throw Exception('Not a function at address 0x${address.toRadixString(16)}: 0x${typeByte.toRadixString(16)}');
    }

    // Spec: "The locals-format list is encoded... a list of LocalType/LocalCount byte pairs,
    // terminated by a zero/zero pair. (There is, however, no extra padding to reach four-byte alignment.)"
    final formatBytes = <int>[];
    int current = address + 1;
    while (true) {
      final localType = memory.readByte(current++);
      final localCount = memory.readByte(current++);
      formatBytes.add(localType);
      formatBytes.add(localCount);
      if (localType == 0 && localCount == 0) break;
    }

    final descriptor = GlulxLocalsDescriptor.parse(Uint8List.fromList(formatBytes));
    final entryPoint = current;

    /// Spec 1.4.2: "If the type is C0, the arguments are passed on the stack."
    if (type == GlulxTypableType.functionC0) {
      return StackArgsFunction(address, descriptor, entryPoint);
    } else {
      /// Spec 1.4.2: "If the type is C1, the arguments are written into the locals."
      return LocalArgsFunction(address, descriptor, entryPoint);
    }
  }
}

/// Spec Section 1.4.2: "If the type is C0, the arguments are passed on the stack,
/// and are made available on the stack."
class StackArgsFunction extends GlulxFunction {
  StackArgsFunction(int address, GlulxLocalsDescriptor localsDescriptor, int entryPoint)
    : super(address, GlulxTypableType.functionC0, localsDescriptor, entryPoint);
}

/// Spec Section 1.4.2: "If the type is C1, the arguments are passed on the stack,
/// and are written into the locals according to the 'format of locals' list of the function."
class LocalArgsFunction extends GlulxFunction {
  LocalArgsFunction(int address, GlulxLocalsDescriptor localsDescriptor, int entryPoint)
    : super(address, GlulxTypableType.functionC1, localsDescriptor, entryPoint);
}
