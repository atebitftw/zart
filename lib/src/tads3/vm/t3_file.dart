// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// TADS3 File Metaclass Implementation
///
/// This module provides the TADS3 File metaclass and its underlying data
/// source abstractions. Derived from vmfile.cpp/h and vmfilobj.cpp/h.
library;

import 'dart:io';
import 'dart:typed_data';
import 'package:zart/src/tads3/vm/t3_error.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';

// ----------------------------------------------------------------------------
// File Access and Mode Constants
// ----------------------------------------------------------------------------

/// File Access Modes
const int vmObjFileAccessRead = 1;
const int vmObjFileAccessWrite = 2;
const int vmObjFileAccessRwKeep = 3;
const int vmObjFileAccessRwTrunc = 4;
const int vmObjFileAccessDelete = 5;

/// File Opening Modes
const int vmObjFileModeText = 1;
const int vmObjFileModeData = 2;
const int vmObjFileModeRaw = 3;

// ----------------------------------------------------------------------------
// T3DataSource - Abstract Base Class for Data Sources
// ----------------------------------------------------------------------------

/// Abstract base class for all data sources (files, resources, memory).
/// Derived from CVmDataSource in TADS3. Implements the T3File placeholder.
abstract class T3DataSource implements T3File {
  /// Close the data source.
  void close();

  /// Read a single byte. Returns -1 on EOF.
  int readByte();

  /// Read a block of bytes into [buffer]. Returns count read.
  int readBytes(Uint8List buffer, int offset, int length);

  /// Write a single byte.
  void writeByte(int byte);

  /// Write a block of bytes from [buffer].
  void writeBytes(Uint8List buffer, int offset, int length);

  /// Get the current position.
  int getPos();

  /// Set the current position.
  void setPos(int pos);

  /// Get the total size of the source.
  int getSize();

  /// Flush any buffered data.
  void flush();
}

// ----------------------------------------------------------------------------
// T3FileSource - File-based Data Source
// ----------------------------------------------------------------------------

/// Implementation of T3DataSource using dart:io File.
class T3FileSource extends T3DataSource {
  final RandomAccessFile _file;

  T3FileSource(this._file);

  @override
  void close() => _file.closeSync();

  @override
  int readByte() {
    try {
      return _file.readByteSync();
    } catch (e) {
      return -1;
    }
  }

  @override
  int readBytes(Uint8List buffer, int offset, int length) {
    return _file.readIntoSync(buffer, offset, offset + length);
  }

  @override
  void writeByte(int byte) => _file.writeByteSync(byte);

  @override
  void writeBytes(Uint8List buffer, int offset, int length) {
    _file.writeFromSync(buffer, offset, offset + length);
  }

  @override
  int getPos() => _file.positionSync();

  @override
  void setPos(int pos) => _file.setPositionSync(pos);

  @override
  int getSize() => _file.lengthSync();

  @override
  void flush() => _file.flushSync();
}

// ----------------------------------------------------------------------------
// Property indices (matching C++ function table order)
// ----------------------------------------------------------------------------

const int _propIdxOpenText = 1;
const int _propIdxOpenData = 2;
const int _propIdxOpenRaw = 3;
const int _propIdxGetCharset = 4;
const int _propIdxSetCharset = 5;
const int _propIdxCloseFile = 6;
const int _propIdxReadBytes = 9;
const int _propIdxWriteBytes = 10;
const int _propIdxGetPos = 11;
const int _propIdxSetPos = 12;
const int _propIdxSetPosEnd = 13;
const int _propIdxOpenResText = 14;
const int _propIdxOpenResRaw = 15;
const int _propIdxGetSize = 16;
const int _propIdxGetMode = 17;
const int _propIdxGetRootName = 18;
const int _propIdxDeleteFile = 19;
const int _propIdxDigestMD5 = 24;

// ----------------------------------------------------------------------------
// T3ObjFile - File Metaclass Instance
// ----------------------------------------------------------------------------

/// Represents a TADS3 File object.
class T3ObjFile extends T3Object {
  T3DataSource? _source;
  final int _mode;
  int _charsetObj; // ID of the character set object

  T3ObjFile(this._source, this._mode, this._charsetObj);

  @override
  T3Metaclass getMetaclassReg() => T3MetaclassFile.instance;

  @override
  void notifyDelete(T3VM vm, bool inRootSet) {
    _source?.close();
    _source = null;
  }

  @override
  bool getProp(T3VM vm, int propId, T3Value retval, int self, List<int> sourceObj, int? argc) {
    final funcIdx = vm.metaTable?.propToVectorIdx(getMetaclassReg().getRegIdx(), propId);
    if (funcIdx == null || funcIdx < 0 || funcIdx > _propIdxDigestMD5) {
      return false;
    }

    if (evalProp(vm, funcIdx, retval, self, argc)) {
      sourceObj[0] = getMetaclassReg().getClassObj(vm);
      return true;
    }
    return false;
  }

  /// Evaluate a property method by function index.
  bool evalProp(T3VM vm, int funcIdx, T3Value retval, int self, int? argc) {
    switch (funcIdx) {
      case _propIdxGetCharset:
        return _getpGetCharset(vm, retval, argc);
      case _propIdxSetCharset:
        return _getpSetCharset(vm, retval, argc);
      case _propIdxCloseFile:
        return _getpCloseFile(vm, retval, argc);
      case _propIdxReadBytes:
        return _getpReadBytes(vm, retval, argc);
      case _propIdxWriteBytes:
        return _getpWriteBytes(vm, retval, argc);
      case _propIdxGetPos:
        return _getpGetPos(vm, retval, argc);
      case _propIdxSetPos:
        return _getpSetPos(vm, retval, argc);
      case _propIdxSetPosEnd:
        return _getpSetPosEnd(vm, retval, argc);
      case _propIdxGetSize:
        return _getpGetSize(vm, retval, argc);
      case _propIdxGetMode:
        return _getpGetMode(vm, retval, argc);
      default:
        return false;
    }
  }

  // --- T3Object Overrides ---

  @override
  void setProp(T3VM vm, T3Undo? undo, int self, int propId, T3Value val) {
    throw T3VmException(vmErrInvalidSetprop);
  }

  @override
  bool isInstanceOf(T3VM vm, int obj) {
    // Check if it's the File class or its superclasses
    var cls = getMetaclassReg().getClassObj(vm);
    while (cls != invalidObj) {
      if (cls == obj) return true;
      final t3obj = vm.objTable.getObj(cls);
      cls = t3obj?.getSuperclass(vm, cls, 0) ?? invalidObj;
    }
    return false;
  }

  @override
  int getSuperclass(T3VM vm, int self, int index) => index == 0 ? getMetaclassReg().getClassObj(vm) : invalidObj;

  @override
  void applyUndo(T3VM vm, T3UndoRecord record) {
    // File objects are generally not undoable in terms of file system state
  }

  @override
  void markRefs(T3VM vm, int state) {
    // File objects only refer to the charset object
    if (_charsetObj != invalidObj) {
      vm.objTable.markObjRef(_charsetObj, state);
    }
  }

  @override
  void buildPropList(T3VM vm, int self, T3Value retval) {
    retval.setList(0); // placeholder
  }

  @override
  String? castToString(T3VM vm, int self, T3Value val) => null;

  @override
  int rebuildImage(T3VM vm, Uint8List buf, int offset, int size) {
    // File objects are transient and not part of the image
    return 0;
  }

  @override
  void saveToFile(T3VM vm, T3File fp) {
    // File objects are transient
  }

  @override
  void restoreFromFile(T3VM vm, int self, T3File fp, T3ObjFixup fixups) {
    // File objects are transient; restored objects are "out of sync"
  }

  @override
  bool inhProp(
    T3VM vm,
    int propId,
    T3Value retval,
    int self,
    int origTargetObj,
    int definingObj,
    List<int> sourceObj,
    int? argc,
  ) {
    return false;
  }

  @override
  void loadFromImage(T3VM vm, int self, Uint8List ptr, int offset, int size) {
    // transient
  }

  @override
  void markUndoRef(T3VM vm, T3UndoRecord rec) {}

  @override
  void removeStaleUndoWeakRef(T3VM vm, T3UndoRecord rec) {}

  // --- Property Methods ---

  bool _getpGetCharset(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 0, 0);
    retval.setObj(_charsetObj);
    return true;
  }

  bool _getpSetCharset(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 1, 1);
    final val = vm.stack.popVal();
    _charsetObj = val.getAsObj() ?? invalidObj;
    retval.setNil();
    return true;
  }

  bool _getpCloseFile(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 0, 0);
    _source?.close();
    _source = null;
    retval.setNil();
    return true;
  }

  bool _getpReadBytes(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 1, 3);
    if (_source == null) throw T3VmException(vmErrCloseFile);
    // TODO: Implementation of readBytes into T3ObjByteArray
    final baVal = vm.stack.popVal();
    if (baVal.type != T3DataType.obj) throw T3VmException(vmErrBadTypeBif);
    return false;
  }

  bool _getpWriteBytes(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 1, 3);
    if (_source == null) throw T3VmException(vmErrCloseFile);
    // TODO: Implementation of writeBytes from T3ObjByteArray
    return false;
  }

  bool _getpGetPos(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 0, 0);
    if (_source == null) throw T3VmException(vmErrCloseFile);
    retval.setInt(_source!.getPos());
    return true;
  }

  bool _getpSetPos(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 1, 1);
    if (_source == null) throw T3VmException(vmErrCloseFile);
    final pos = vm.stack.popVal().getAsInt();
    _source!.setPos(pos);
    retval.setNil();
    return true;
  }

  bool _getpSetPosEnd(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 0, 0);
    if (_source == null) throw T3VmException(vmErrCloseFile);
    _source!.setPos(_source!.getSize());
    retval.setNil();
    return true;
  }

  bool _getpGetSize(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 0, 0);
    if (_source == null) throw T3VmException(vmErrCloseFile);
    retval.setInt(_source!.getSize());
    return true;
  }

  bool _getpGetMode(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 0, 0);
    retval.setInt(_mode);
    return true;
  }

  void _checkArgs(int? argc, int min, int max) {
    if (argc == null) return;
    if (argc < min || argc > max) throw T3VmException(vmErrWrongNumOfArgs);
  }
}

// ----------------------------------------------------------------------------
// T3MetaclassFile - File Metaclass Registry
// ----------------------------------------------------------------------------

/// Metaclass registry for the File class.
class T3MetaclassFile extends T3Metaclass {
  static final T3MetaclassFile instance = T3MetaclassFile();

  @override
  String getMetaName() => 'file/030001';

  @override
  int createFromStack(T3VM vm, Uint8List pc, int pcOffset, int argc) {
    // TADS3 File objects cannot be created with 'new'
    throw T3VmException(vmErrBadDynamicNew);
  }

  @override
  void createForImageLoad(T3VM vm, int id) {
    // Reconstruct from image data
  }

  @override
  void createForRestore(T3VM vm, int id) {
    // Reconstruct for restore
  }

  @override
  bool callStatProp(T3VM vm, T3Value result, Uint8List pc, int pcOffset, int argc, int prop) {
    switch (prop) {
      case _propIdxOpenText:
      case _propIdxOpenData:
      case _propIdxOpenRaw:
        // TODO: Implement open file methods
        return false;
      case _propIdxDeleteFile:
        // TODO: Implement deleteFile
        return false;
      case _propIdxGetRootName:
        // TODO: Implement getRootName
        return false;
      case _propIdxOpenResText:
      case _propIdxOpenResRaw:
        // TODO: Resource handling
        return false;
      default:
        return false;
    }
  }

  @override
  int getSupermeta(T3VM vm, int idx) => invalidObj;

  @override
  T3Metaclass? getSupermetaReg() => null; // File derives from root Object

  @override
  int getClassObj(T3VM vm) => invalidObj;

  @override
  bool isMetaInstanceOf(T3VM vm, int obj) => false;
}
