// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// TADS3 VM Stack Manager
///
/// This library provides the stack implementation for the TADS3 VM, used for
/// function call frames, local variables, expression evaluation, and parameter
/// passing. It is a Dart port of the C++ vmstack.h and vmstack.cpp files.
///
/// The C++ implementation uses pointer arithmetic extensively. This Dart version
/// uses integer indices with a List<T3Value> for a more idiomatic and safe
/// implementation.
///
/// Ported from: packages/tads-runner/tads3/vmstack.h
///              packages/tads-runner/tads3/vmstack.cpp
library;

import 'package:zart/src/tads3/vm/t3_type.dart';
import 'package:zart/src/tads3/vm/t3_error.dart';

/// TADS3 VM Stack
///
/// The stack is used for:
/// - Function call frames
/// - Local variables
/// - Expression evaluation
/// - Parameter passing
/// - Return values
///
/// The stack includes reserve space for error handling. When a stack overflow
/// occurs, the reserve can be released to allow error recovery.
class T3Stack {
  /// Stack storage
  late final List<T3Value> _arr;

  /// Stack pointer (index of next free slot)
  int _sp = 0;

  /// Maximum depth (excluding reserve)
  int _maxDepth;

  /// Reserve depth for error handling
  final int _reserveDepth;

  /// Flag indicating if reserve is currently in use
  bool _reserveInUse = false;

  /// Get a pointer to the top of the stack
  int getTopPointer() => _sp;

  /// Create a stack with the specified maximum depth and reserve space
  ///
  /// The stack is allocated with [maxDepth] + [reserveDepth] + 25 slots.
  /// The extra 25 slots provide a safety buffer for intrinsics that push
  /// without checking.
  T3Stack(int maxDepth, int reserveDepth) : _maxDepth = maxDepth, _reserveDepth = reserveDepth {
    // Allocate the stack with reserve and safety buffer
    final totalSize = maxDepth + reserveDepth + 25;
    // Use generate to create distinct T3Value instances for each slot
    _arr = List<T3Value>.generate(totalSize, (_) => T3Value(), growable: false);

    // Initialize the stack pointer
    init();
  }

  /// Initialize/reset the stack pointer to the beginning
  void init() {
    _sp = 0;
  }

  /// Get the current stack depth (number of active elements)
  int getDepth() => _sp;

  /// Get the depth relative to a frame pointer
  ///
  /// Returns the number of items on the stack beyond the given frame pointer.
  /// If the frame pointer is beyond the current stack pointer (values have
  /// been popped), the return value will be negative.
  int getDepthRel(int fp) => _sp - fp;

  /// Get the current stack pointer
  int getSp() => _sp;

  /// Set the current stack pointer
  ///
  /// The pointer must always be a value previously returned by [getSp].
  void setSp(int p) {
    _sp = p;
  }

  /// Convert a stack pointer to a persistent index
  ///
  /// Returns 0 for null, non-zero for valid pointers.
  /// This can be used for saving stack locations persistently.
  int ptrToIndex(int? p) {
    return (p == null ? 0 : p + 1);
  }

  /// Convert a persistent index back to a stack pointer
  ///
  /// Returns null for index 0, otherwise returns the pointer.
  int? indexToPtr(int idx) {
    return (idx == 0 ? null : idx - 1);
  }

  /// Get an element relative to a frame pointer
  ///
  /// The offset is:
  /// - Negative for a value pushed prior to the frame pointer
  /// - Zero for the value at the frame pointer
  /// - Positive for values pushed after the frame pointer
  ///
  /// Note: In C++, fp is a pointer to the next free slot, so the formula is
  /// `fp + i - 1`. In Dart, fp is an index to the next free slot, so we use
  /// `fp + i - 1` to match the C++ semantics.
  T3Value getFromFrame(int fp, int i) {
    return _arr[fp + i - 1];
  }

  /// Get an element from the top of the stack
  ///
  /// Elements are numbered from 0 to (depth - 1).
  /// Element 0 is the most recently pushed item.
  /// Element (depth-1) is the oldest element on the stack.
  T3Value get(int i) {
    return _arr[_sp - i - 1];
  }

  /// Push a value onto the stack
  void push(T3Value val) {
    _arr[_sp++] = val;
  }

  /// Push a slot and return a reference to it
  ///
  /// The new element is not filled in yet on return, so the caller
  /// should immediately fill it with a valid value.
  /// Returns the index of the pushed slot.
  int pushSlot() {
    return _sp++;
  }

  /// Push multiple slots and return the index of the first one
  ///
  /// The slots are uninitialized, so the caller must set the values
  /// immediately. Subsequent elements are at returnValue + 1, + 2, etc.
  int pushMultiple(int n) {
    final ret = _sp;
    _sp += n;
    return ret;
  }

  /// Push a value, checking for available space first
  void pushCheck(T3Value val) {
    checkThrow(1);
    push(val);
  }

  /// Push a slot with space check, returning its index
  int pushSlotCheck() {
    checkThrow(1);
    return pushSlot();
  }

  /// Push multiple slots with space check, returning the first index
  int pushMultipleCheck(int n) {
    checkThrow(n);
    return pushMultiple(n);
  }

  /// Insert space for [num] slots at index [idx]
  ///
  /// If [idx] is 0, this is the same as pushing [num] slots.
  /// Returns the index of the first slot allocated.
  int insert(int idx, int num) {
    // Make sure there's room
    checkThrow(num);

    // Add the space
    _sp += num;

    // If idx is non-zero, move the idx slots by num to make room
    if (idx != 0) {
      // Move elements: copy from (sp - idx - num) to (sp - idx)
      for (int i = 0; i < idx; i++) {
        _arr[_sp - idx + i] = _arr[_sp - idx - num + i];
      }
    }

    // Return the start of the inserted block
    return _sp - idx - num;
  }

  /// Pop the top element off the stack into [val]
  void pop(T3Value val) {
    val.copyFrom(_arr[--_sp]);
  }

  /// Pop and return the top element
  T3Value popVal() {
    final v = T3Value();
    pop(v);
    return v;
  }

  /// Discard the top element
  void discard([int n = 1]) {
    _sp -= n;
  }

  /// Check if [nslots] slots are available
  ///
  /// Returns true if the required amount of space is available, false if not.
  /// Does NOT actually allocate the space.
  ///
  /// Note: [nslots] is signed to handle a compiler bug in older TADS3
  /// versions that could generate negative reservation sizes. This makes
  /// the check more forgiving for faulty .t3 files.
  bool checkSpace(int nslots) {
    return (getDepth() + nslots <= _maxDepth);
  }

  /// Check space for [nslots] new slots, throwing an error on overflow
  void checkThrow(int nslots) {
    if (!checkSpace(nslots)) {
      throw T3VmException(vmErrStackOverflow);
    }
  }

  /// Release the reserve space for error recovery
  ///
  /// Debuggers can use this to allow manual recovery from stack overflows,
  /// by making extra stack temporarily available for error handling.
  ///
  /// Returns true if reserve space was available and released, false if
  /// the reserve is already in use.
  bool releaseReserve() {
    // If the reserve is already in use, we can't release it again
    if (_reserveInUse) {
      return false;
    }

    // Add the reserve space to the maximum stack depth
    _maxDepth += _reserveDepth;

    // Note that the reserve has been released
    _reserveInUse = true;

    // Indicate success
    return true;
  }

  /// Recover the reserve space after error handling
  ///
  /// If the debugger releases the reserve to handle a stack overflow,
  /// it can call this once the situation has been dealt with to take
  /// the reserve back out of play.
  void recoverReserve() {
    // If the reserve is in use, put it back in reserve
    if (_reserveInUse) {
      // Remove the reserve from the stack
      _maxDepth -= _reserveDepth;

      // Mark the reserve as available again
      _reserveInUse = false;
    }
  }

  /// Get a reference to the stack element at the given index
  ///
  /// This allows direct manipulation of stack elements.
  /// Use with caution - index must be valid.
  T3Value getRef(int idx) {
    return _arr[idx];
  }

  /// Set a stack element at the given index
  ///
  /// Use with caution - index must be valid.
  void setAt(int idx, T3Value val) {
    _arr[idx] = val;
  }
}
