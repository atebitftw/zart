// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// TADS3 VM Globals
///
/// This library provides a simple class to hold all VM global state. This is
/// a Dart port of the C++ vmglob.h, vmglobv.h, and vmglob.cpp files.
///
/// The C++ implementation uses a complex macro-based system with 4 different
/// configurations to support various deployment scenarios. In Dart, we use a
/// simple class-based approach that's more idiomatic and easier to maintain.
///
/// Each VM instance gets its own T3Globals object, which naturally supports:
/// - Multiple VM instances in the same process
/// - Proper isolation between instances
/// - Automatic cleanup via garbage collection
///
/// Ported from: packages/tads-runner/tads3/vmglob.h
///              packages/tads-runner/tads3/vmglobv.h
///              packages/tads-runner/tads3/vmglob.cpp
library;

import 'package:zart/src/tads3/vm/t3_metaclass_table.dart';
import 'package:zart/src/tads3/vm/t3_object_table.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';
import 'package:zart/src/tads3/vm/t3_pool.dart';
import 'package:zart/src/tads3/vm/t3_bif.dart';
import 'package:zart/src/tads3/vm/t3_stack.dart';

import 'package:zart/src/tads3/vm/t3_object.dart';

/// TADS3 VM Global State
///
/// This class holds all global state for a single VM instance. Fields are
/// added incrementally as we implement each subsystem.
///
/// The C++ version uses macros to support 4 different configurations:
/// - Individual global variables (fastest, single VM)
/// - Static global structure (fast, single VM)
/// - Global pointer to structure (flexible, single-threaded)
/// - Parameter-passed structure (most flexible, multi-threaded)
///
/// In Dart, we just use a simple class, which is equivalent to the most
/// flexible C++ configuration but more idiomatic.
class T3Globals extends T3VM {
  // ========================================================================
  // Pool Managers (implemented)
  // ========================================================================

  /// Constant pool manager
  ///
  /// Manages read-only constant data (strings, lists, etc.) loaded from the
  /// image file.
  T3PoolInMem? constPool;

  /// Code pool manager
  ///
  /// Manages compiled bytecode loaded from the image file.
  T3Pool? codePool;

  // ========================================================================
  // Stack and Interpreter (partially implemented)
  // ========================================================================

  /// VM stack
  ///
  /// Used for function call frames, local variables, expression evaluation,
  /// and parameter passing.
  T3Stack? stack;

  /// VM interpreter
  ///
  /// The execution engine that handles opcode fetching and dispatch.
  dynamic interpreter;

  // ========================================================================
  // Object System (implemented)
  // ========================================================================

  /// Object table
  ///
  /// Manages all TADS3 objects with page-based allocation and free list
  /// management.
  T3ObjectTable? objTable;

  /// Metaclass dependency table
  ///
  /// Manages metaclass registration and dynamic linking.
  T3MetaclassTable? metaTable;

  // TODO: Implement T3Memory (object memory manager)
  // T3Memory? mem;

  // TODO: Implement T3VarHeap (variable-size block heap manager)
  // T3VarHeap? varheap;

  // ========================================================================
  // Subsystems (not yet implemented)
  // ========================================================================

  // TODO: Implement T3Undo (undo manager)
  // T3Undo? undo;

  /// Built-in function set table
  ///
  /// Manages registered BIF sets for intrinsic functions.
  T3BifTable? bifTable;

  // TODO: Implement T3SrcfTable (source file list for debugger)
  // T3SrcfTable? srcfTable;

  // TODO: Implement T3ImageLoader
  // T3ImageLoader? imageLoader;

  // TODO: Implement T3Console
  // T3Console? console;

  // TODO: Implement T3Debugger
  // T3Debugger? debugger;

  // ========================================================================
  // Registers and Execution State
  // ========================================================================

  /// Current program counter (byte-code offset)
  int pc = 0;

  /// Current entry pointer (base address of current function)
  int entryPtr = 0;

  /// Current frame pointer (stack index)
  int framePtr = 0;

  /// Method header size (loaded from image)
  int funchdrSize = 0;

  /// Data register 0
  final T3Value r0 = T3Value();

  // ========================================================================
  // Scalar Globals
  // ========================================================================

  /// Preinit mode flag
  ///
  /// True if we're running in preinit mode (executing static initializers).
  bool preinitMode = false;

  /// Size of each exception table entry in the image file
  int excEntrySize = 0;

  /// Size of each debugger source line entry in the image file
  int lineEntrySize = 0;

  /// Size of header of each method's debug table
  int dbgHdrSize = 0;

  /// Size of each debugger local symbol header
  int dbgLclsymHdrSize = 0;

  /// Debug record format version
  int dbgFmtVsn = 0;

  /// Debug frame record size
  int dbgFrameSize = 0;

  /// Iterator getNext property ID
  int iterGetNext = 0;

  /// Iterator isNextAvailable property ID
  int iterNextAvail = 0;

  /// Base path for file I/O operations
  String? filePath;

  /// Sandbox path for file safety feature
  String? sandboxPath;

  /// System debug log file name
  String? syslogfile;

  // ========================================================================
  // Constructor and Cleanup
  // ========================================================================

  /// Create a new VM globals instance
  T3Globals();

  /// Dispose of all resources
  ///
  /// This should be called when the VM instance is being shut down.
  /// It cleans up all allocated resources.
  void dispose() {
    // Clean up pool managers
    constPool?.terminate();
    constPool = null;

    codePool?.terminate();
    codePool = null;

    // Stack doesn't need explicit cleanup (no native resources)
    stack = null;

    // Clean up object system (note: relies on Dart GC, no explicit cleanup needed)
    objTable = null;
    metaTable = null;

    // TODO: Clean up other subsystems as they're implemented
    // interpreter?.dispose();
    // mem?.dispose();
    // varheap?.dispose();
    // undo?.dispose();
    // metaTable?.dispose();
    // Clean up BIF table
    bifTable?.clear();
    bifTable = null;
    // srcfTable?.dispose();
    // imageLoader?.dispose();
    // console?.dispose();
    // debugger?.dispose();
  }
}
