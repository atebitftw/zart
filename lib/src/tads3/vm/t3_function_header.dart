import 'dart:typed_data';

/// TDS3 Function Header.
///
/// The function header is a 10-byte (minimum) block of data that immediately
/// precedes the first bytecode instruction in every function or method.
class T3FunctionHeader {
  /// The number of parameters the function expects.
  /// If (argc & 0x80) != 0, it takes a variable number of parameters (min: argc & 0x7f).
  final int argc;

  /// Number of additional optional parameters.
  final int optionalArgc;

  /// Number of local variables.
  final int localCount;

  /// Total stack slots required (locals + work space).
  final int stackDepth;

  /// Offset to exception table from start of header (0 if none).
  final int exceptionTableOffset;

  /// Offset to debug records from start of header (0 if none).
  final int debugOffset;

  T3FunctionHeader({
    required this.argc,
    required this.optionalArgc,
    required this.localCount,
    required this.stackDepth,
    required this.exceptionTableOffset,
    required this.debugOffset,
  });

  /// The minimum number of arguments required.
  int get minArgs => argc & 0x7f;

  /// The maximum number of arguments allowed (if not varargs).
  int get maxArgs => minArgs + optionalArgc;

  /// Whether this is a variable arguments function.
  bool get isVarargs => (argc & 0x80) != 0;

  /// Parses a function header from raw bytes.
  factory T3FunctionHeader.parse(Uint8List data) {
    final view = ByteData.view(data.buffer, data.offsetInBytes);
    return T3FunctionHeader(
      argc: view.getUint8(0),
      optionalArgc: view.getUint8(1),
      localCount: view.getUint16(2, Endian.little),
      stackDepth: view.getUint16(4, Endian.little),
      exceptionTableOffset: view.getUint16(6, Endian.little),
      debugOffset: view.getUint16(8, Endian.little),
    );
  }

  @override
  String toString() {
    return 'T3FunctionHeader(argc: $argc, locals: $localCount, stack: $stackDepth)';
  }
}
