import 'dart:async';
import 'dart:typed_data';
import 'package:zart/src/io/glk/glk_provider.dart';
import 'package:zart/src/glulx/glulx_gestalt_selectors.dart';

/// A mock GlkProvider for Glulx unit tests.
///
/// Provides a minimal implementation of the GlkProvider interface
/// that can be used for testing GlulxInterpreter without requiring
/// a full terminal display.
class MockGlkProvider implements GlkProvider {
  // Memory access callbacks
  void Function(int addr, int value, {int size})? _writeMemory;
  int Function(int addr, {int size})? _readMemory;
  void Function(int addr, Uint8List block)? _writeMemoryBlock;
  Uint8List Function(int addr, int len)? _readMemoryBlock;

  // Stack access callbacks
  void Function(int value) _pushToStack = (v) {};
  int Function() _popFromStack = () => 0;

  // VM state
  int Function()? _getHeapStart;

  @override
  void setMemoryAccess({
    required void Function(int addr, int value, {int size}) write,
    required int Function(int addr, {int size}) read,
    void Function(int addr, Uint8List block)? writeBlock,
    Uint8List Function(int addr, int len)? readBlock,
  }) {
    _writeMemory = write;
    _readMemory = read;
    _writeMemoryBlock = writeBlock;
    _readMemoryBlock = readBlock;
  }

  @override
  void setVMState({int Function()? getHeapStart}) {
    _getHeapStart = getHeapStart;
  }

  @override
  void writeMemory(int addr, int value, {int size = 1}) {
    _writeMemory?.call(addr, value, size: size);
  }

  @override
  int readMemory(int addr, {int size = 1}) {
    return _readMemory?.call(addr, size: size) ?? 0;
  }

  @override
  void writeMemoryBlock(int addr, Uint8List block) {
    _writeMemoryBlock?.call(addr, block);
  }

  @override
  Uint8List readMemoryBlock(int addr, int len) {
    return _readMemoryBlock?.call(addr, len) ?? Uint8List(0);
  }

  @override
  void pushToStack(int value) {
    _pushToStack.call(value);
  }

  @override
  int popFromStack() {
    return _popFromStack.call();
  }

  @override
  void setStackAccess({required void Function(int value) push, required int Function() pop}) {
    _pushToStack = push;
    _popFromStack = pop;
  }

  @override
  FutureOr<int> dispatch(int selector, List<int> args) {
    // Mock implementation - return 0 for most calls
    return 0;
  }

  @override
  int vmGestalt(int selector, int arg) {
    switch (selector) {
      case GlulxGestaltSelectors.glulxVersion:
        return 0x00030103;
      case GlulxGestaltSelectors.terpVersion:
        return 0x00000100; // Zart version 0.1.0
      case GlulxGestaltSelectors.resizeMem:
        return 1;
      case GlulxGestaltSelectors.undo:
        return 1;
      case GlulxGestaltSelectors.ioSystem:
        return (arg >= 0 && arg <= 2) ? 1 : 0;
      case GlulxGestaltSelectors.unicode:
        return 1;
      case GlulxGestaltSelectors.memCopy:
        return 1;
      case GlulxGestaltSelectors.mAlloc:
        return 1;
      case GlulxGestaltSelectors.mAllocHeap:
        return _getHeapStart?.call() ?? 0;
      case GlulxGestaltSelectors.acceleration:
        return 1;
      case GlulxGestaltSelectors.accelFunc:
        return (arg >= 1 && arg <= 13) ? 1 : 0;
      case GlulxGestaltSelectors.float:
        return 1;
      case GlulxGestaltSelectors.extUndo:
        return 1;
      case GlulxGestaltSelectors.doubleValue:
        return 1;
      default:
        return 0;
    }
  }

  @override
  void renderScreen() {
    // No-op for testing
  }

  @override
  Future<void> showExitAndWait(String message) async {
    // No-op for testing
  }
}
