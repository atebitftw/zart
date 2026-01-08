import 'dart:io';
import 'dart:typed_data';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';
import 'package:zart/src/tads3/vm/t3_undo.dart';

/// The File metaclass.
class T3File extends T3Object {
  // Constants from vmfilobj.h
  static const int VMOBJFILE_OUT_OF_SYNC = 0x0001;
  static const int VMOBJFILE_STDIO_BUF_DIRTY = 0x0002;
  static const int VMOBJFILE_LAST_OP_WRITE = 0x0004;

  static const int VMOBJFILE_MODE_TEXT = 0x01;
  static const int VMOBJFILE_MODE_DATA = 0x02;
  static const int VMOBJFILE_MODE_RAW = 0x03;

  static const int VMOBJFILE_ACCESS_READ = 0x0001;
  static const int VMOBJFILE_ACCESS_WRITE = 0x0002;
  static const int VMOBJFILE_ACCESS_RW_KEEP = 0x0003;
  static const int VMOBJFILE_ACCESS_RW_TRUNC = 0x0004;

  // Data mode tags
  static const int VMOBJFILE_TAG_INT = 0x01;
  static const int VMOBJFILE_TAG_STRING = 0x03;
  static const int VMOBJFILE_TAG_TRUE = 0x08;
  static const int VMOBJFILE_TAG_ENUM = 0x20;
  static const int VMOBJFILE_TAG_BIGNUM = 0x21;
  static const int VMOBJFILE_TAG_BYTEARRAY = 0x22;

  /// Charset ID or value.
  T3Value _charset = T3Value.nil();

  /// File mode (text, data, raw).
  int _mode = 0;

  /// Access mode (read, write, etc.).
  int _access = 0;

  /// Flags (out of sync, etc.).
  int _flags = 0;

  /// Underlying Dart file object (transient).
  RandomAccessFile? _raf;

  /// File path for reference.
  String? _path;

  T3File._({required int objectId, bool isTransient = false})
    : super(objectId: objectId, metaclass: 'file', isTransient: isTransient);

  /// Creates a new File object (TADS 3 constructor).
  static T3File create(int objectId) {
    return T3File._(objectId: objectId);
  }

  /// Opens the file with the given configuration.
  void open(String path, int mode, int access, {T3Value? charset}) {
    _path = path;
    _mode = mode;
    _access = access;
    _charset = charset ?? T3Value.nil();
    _flags = 0;

    try {
      final f = File(path);
      if (access == VMOBJFILE_ACCESS_READ) {
        _raf = f.openSync(mode: FileMode.read);
      } else if (access == VMOBJFILE_ACCESS_WRITE) {
        _raf = f.openSync(mode: FileMode.write);
      } else if (access == VMOBJFILE_ACCESS_RW_TRUNC) {
        _raf = f.openSync(mode: FileMode.write);
      } else if (access == VMOBJFILE_ACCESS_RW_KEEP) {
        _raf = f.openSync(mode: FileMode.append);
      }
    } catch (e) {
      throw Exception('Cannot open file: $path ($e)');
    }
  }

  void close() {
    if (_raf != null) {
      _raf!.closeSync();
      _raf = null;
    }
  }

  // --- Property Access ---

  @override
  T3Value? getProperty(int propId) {
    // TODO: Implement getProperty for things like close(), read(), write()
    return null;
  }

  @override
  void setProperty(int propId, T3Value value, {T3UndoManager? undoManager}) {
    throw UnsupportedError('File properties are read-only');
  }

  @override
  Map<String, dynamic> get debugInfo => {
    'objectId': objectId,
    'metaclass': metaclass,
    'mode': _mode,
    'access': _access,
    'flags': _flags,
    'isOpen': _raf != null,
    'path': _path,
  };

  // --- Serialization ---

  @override
  Uint8List save() {
    // Format: charset objid (4), mode (1), access (1), flags (4)
    int charsetId = 0;
    if (_charset.type == T3DataType.obj) {
      charsetId = _charset.value;
    }

    final data = ByteData(10);
    data.setUint32(0, charsetId, Endian.little);
    data.setUint8(4, _mode);
    data.setUint8(5, _access);
    data.setUint32(6, _flags, Endian.little);

    return data.buffer.asUint8List();
  }

  factory T3File.fromData(int objectId, Uint8List data, {bool isTransient = false}) {
    final view = ByteData.view(data.buffer, data.offsetInBytes);
    var offset = 0;

    final charsetId = view.getUint32(offset, Endian.little);
    offset += 4;

    final file = T3File._(objectId: objectId, isTransient: isTransient);

    if (charsetId == 0) {
      file._charset = T3Value.nil();
    } else {
      file._charset = T3Value.fromObject(charsetId);
    }

    file._mode = view.getUint8(offset++);
    file._access = view.getUint8(offset++);

    file._flags = view.getUint32(offset, Endian.little);
    offset += 4;

    // When restoring, the file is NOT open.
    // Set OUT_OF_SYNC flag.
    file._flags |= VMOBJFILE_OUT_OF_SYNC;
    file._raf = null;

    return file;
  }

  // --- Helper methods for testing ---

  bool get isOutOfSync => (_flags & VMOBJFILE_OUT_OF_SYNC) != 0;
  bool get isOpen => _raf != null;
  int get mode => _mode;
  int get flags => _flags;
  String? get path => _path;
}
