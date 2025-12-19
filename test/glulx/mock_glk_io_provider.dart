import 'package:zart/src/glulx/glulx_gestalt_selectors.dart';
import 'package:zart/src/io/glk/glk_io_provider.dart';

/// A standard mock GlkIoProvider for Glulx unit tests.
class TestGlkIoProvider implements GlkIoProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #vmGestalt) {
      return _defaultVmGestalt(invocation.positionalArguments[0], invocation.positionalArguments[1]);
    }
    return null;
  }

  @override
  void setMemoryAccess({
    required void Function(int addr, int val, {int size}) write,
    required int Function(int addr, {int size}) read,
  }) {}

  @override
  void setVMState({int Function()? getHeapStart}) {}

  int _defaultVmGestalt(int selector, int arg) {
    switch (selector) {
      case GlulxGestaltSelectors.glulxVersion:
        return 0x00030103;
      case GlulxGestaltSelectors.terpVersion:
        return 0x00000100;
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
  set debugger(dynamic _debugger) {}
}
