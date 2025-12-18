import 'dart:typed_data';

/// Information about a single local variable.
class LocalInfo {
  /// The size of the local in bytes (1, 2, or 4).
  final int type;

  /// The byte offset of the local relative to the start of the locals segment.
  final int offset;

  LocalInfo(this.type, this.offset);
}

/// A descriptor for the layout of local variables in a Glulx call frame.
class GlulxLocalsDescriptor {
  /// The list of local variables in order.
  final List<LocalInfo> locals;

  /// The total size of the locals segment in bytes, including internal padding.
  final int localsSize;

  /// The total length of the locals section including trailing padding to align the stack values (4-byte boundary).
  final int totalSizeWithPadding;

  /// The original format bytes, used when pushing frames.
  final Uint8List formatBytes;

  GlulxLocalsDescriptor(this.locals, this.localsSize, this.formatBytes)
    : totalSizeWithPadding = (localsSize + 3) & ~3;

  /// Parses the "Format of Locals" descriptor from the function header.
  ///
  /// The format is a series of (Type, Count) pairs, terminated by (0, 0).
  static GlulxLocalsDescriptor parse(Uint8List format) {
    final locals = <LocalInfo>[];
    int currentOffset = 0;

    for (int i = 0; i < format.length; i += 2) {
      final type = format[i];
      if (i + 1 >= format.length) break;
      final count = format[i + 1];

      if (type == 0 && count == 0) break;

      // Align currentOffset to type boundary
      if (type > 1) {
        final padding = (type - (currentOffset % type)) % type;
        currentOffset += padding;
      }

      for (int c = 0; c < count; c++) {
        locals.add(LocalInfo(type, currentOffset));
        currentOffset += type;
      }
    }

    return GlulxLocalsDescriptor(locals, currentOffset, format);
  }
}
