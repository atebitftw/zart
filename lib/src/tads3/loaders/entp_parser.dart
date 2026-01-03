import 'dart:typed_data';

/// Parsed ENTP (entrypoint) block data.
///
/// The entrypoint block specifies the entry function address and
/// various size constants used throughout the image file.
///
/// See spec section "Entrypoint Block".
class T3Entrypoint {
  /// Code pool offset of the entry function.
  final int codeOffset;

  /// Size of method headers in bytes.
  final int methodHeaderSize;

  /// Size of exception table entries in bytes.
  final int exceptionEntrySize;

  /// Size of debugger line table entries in bytes.
  final int debugLineEntrySize;

  /// Size of debug table headers in bytes.
  final int debugTableHeaderSize;

  /// Size of debug local symbol record headers in bytes.
  final int debugLocalHeaderSize;

  /// Debug records version number.
  final int debugRecordsVersion;

  /// Size of debug frame headers in bytes (v2+).
  final int debugFrameHeaderSize;

  T3Entrypoint({
    required this.codeOffset,
    required this.methodHeaderSize,
    required this.exceptionEntrySize,
    required this.debugLineEntrySize,
    required this.debugTableHeaderSize,
    required this.debugLocalHeaderSize,
    required this.debugRecordsVersion,
    required this.debugFrameHeaderSize,
  });

  /// Parses an ENTP block from raw data.
  ///
  /// ENTP block format:
  /// - UINT4: code pool offset
  /// - UINT2: method header size
  /// - UINT2: exception entry size
  /// - UINT2: debug line entry size
  /// - UINT2: debug table header size
  /// - UINT2: debug local header size
  /// - UINT2: debug records version
  /// - UINT2: debug frame header size (v2+, optional)
  factory T3Entrypoint.parse(Uint8List data) {
    final view = ByteData.view(data.buffer, data.offsetInBytes);

    final codeOffset = view.getUint32(0, Endian.little);
    final methodHeaderSize = view.getUint16(4, Endian.little);
    final exceptionEntrySize = view.getUint16(6, Endian.little);
    final debugLineEntrySize = view.getUint16(8, Endian.little);
    final debugTableHeaderSize = view.getUint16(10, Endian.little);
    final debugLocalHeaderSize = view.getUint16(12, Endian.little);

    // These may not be present in older files
    final debugRecordsVersion = data.length >= 16 ? view.getUint16(14, Endian.little) : 0;
    final debugFrameHeaderSize = data.length >= 18 ? view.getUint16(16, Endian.little) : 4;

    return T3Entrypoint(
      codeOffset: codeOffset,
      methodHeaderSize: methodHeaderSize,
      exceptionEntrySize: exceptionEntrySize,
      debugLineEntrySize: debugLineEntrySize,
      debugTableHeaderSize: debugTableHeaderSize,
      debugLocalHeaderSize: debugLocalHeaderSize,
      debugRecordsVersion: debugRecordsVersion,
      debugFrameHeaderSize: debugFrameHeaderSize,
    );
  }

  @override
  String toString() {
    return 'T3Entrypoint(code: 0x${codeOffset.toRadixString(16)}, '
        'methodHeader: $methodHeaderSize, exception: $exceptionEntrySize)';
  }
}
