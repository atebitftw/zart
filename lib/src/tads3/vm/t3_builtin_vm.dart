import 'package:zart/src/loaders/tads/t3_exception.dart';
import 'package:zart/src/tads3/vm/t3_interpreter.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';
import 'package:zart/src/tads3/vm/t3_stack.dart';
import 'package:zart/src/tads3/vm/t3_lookup_table.dart';

/// T3 VM built-in functions.
/// Includes: t3RunGC, t3SetSay, t3GetVMVsn, t3GetVMID, t3GetVMBanner, etc.
class T3BuiltinVm {
  static const String _vmId = 'zart-t3';
  static const String _vmBanner = 'Zart T3 VM - TADS 3 Interpreter';
  static const int _vmVersion = 0x030100; // 3.1.0

  /// t3RunGC() - Run garbage collector.
  /// Ref: vmbift3.cpp line 54
  /// In Dart, GC is automatic, so this is a no-op.
  static void runGC(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    interp.registers.r0 = T3Value.nil();
  }

  /// t3SetSay(func or prop) - Set the default display function/method.
  /// Ref: vmbift3.cpp line 68
  static void setSay(T3Interpreter interp, int argc) {
    if (argc < 1) throw T3Exception('set_say() requires 1 argument');
    final val = interp.stack.pop();
    if (argc > 1) interp.stack.discard(argc - 1);

    const setSayNoFunc = 1;
    const setSayNoMethod = 2;

    if (val.type == T3DataType.prop ||
        (val.type == T3DataType.int_ && val.value == setSayNoMethod)) {
      // Return old prop
      final oldProp = interp.sayMethod;
      interp.registers.r0 = oldProp != 0
          ? T3Value.fromProp(oldProp)
          : T3Value.fromInt(setSayNoMethod);

      // Set new prop
      if (val.type == T3DataType.int_) {
        interp.sayMethod = 0;
      } else {
        interp.sayMethod = val.value;
      }
    } else {
      // Return old func
      final oldFunc = interp.sayFunc;
      interp.registers.r0 = !oldFunc.isNil
          ? oldFunc
          : T3Value.fromInt(setSayNoFunc);

      // Set new func
      if (val.type == T3DataType.int_ && val.value == setSayNoFunc) {
        interp.sayFunc = T3Value.nil();
      } else {
        interp.sayFunc = val;
      }
    }
  }

  /// t3GetVMVsn() - Get VM version number.
  /// Ref: vmbift3.cpp line 137
  /// Returns encoded version: MMmmpp (major, minor, patch)
  static void getVmVsn(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    interp.registers.r0 = T3Value.fromInt(_vmVersion);
  }

  /// t3GetVMID() - Get VM identification string.
  /// Ref: vmbift3.cpp line 149
  static void getVmId(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    final offset = interp.addDynamicString(_vmId);
    interp.registers.r0 = T3Value.fromString(offset);
  }

  /// t3GetVMBanner() - Get VM banner string.
  /// Ref: vmbift3.cpp line 162
  static void getVmBanner(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    final offset = interp.addDynamicString(_vmBanner);
    interp.registers.r0 = T3Value.fromString(offset);
  }

  /// t3GetVMPreinitMode() - Returns true if in preinit mode.
  /// Ref: vmbift3.cpp line 174
  static void getVmPreinitMode(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    // We are always in normal mode for now
    interp.registers.r0 = T3Value.nil();
  }

  /// t3DebugTrace(mode, ...) - Debug tracing.
  /// Ref: vmbift3.cpp line 183
  /// Mode 1: check if debugger present (return nil)
  /// Mode 2: break into debugger (no-op)
  /// Mode 3: write to debug log
  static void debugTrace(T3Interpreter interp, int argc) {
    if (argc < 1)
      throw T3Exception('debug_trace() requires at least 1 argument');

    final mode = interp.stack.pop().numToInt();
    if (argc > 1) interp.stack.discard(argc - 1);

    switch (mode) {
      case 1: // Check debugger present
        interp.registers.r0 = T3Value.nil();
        break;
      case 2: // Break into debugger
        interp.registers.r0 = T3Value.nil();
        break;
      case 3: // Write to debug log
        // Could log message if provided
        interp.registers.r0 = T3Value.nil();
        break;
      default:
        interp.registers.r0 = T3Value.nil();
    }
  }

  /// t3GetGlobalSymbols(which?) - Get global symbol table.
  /// Ref: vmbift3.cpp line 186
  /// Currently returns nil (symbol table not available).
  static void getGlobalSymbols(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);

    // Create a new LookupTable
    final tableId = interp.objectTable.allocateObjectId();
    final table = T3LookupTable(
      objectId: tableId,
      bucketCount: 32, // Arbitrary small bucket count
    );

    // Populate with global symbols
    // interp.symbols is Map<String, T3Value>
    if (interp.symbols.isNotEmpty) {
      interp.symbols.forEach((name, value) {
        // Convert name to T3Value string
        // Since T3ValueKey handles equality, we can just use the string if we convert it.
        // But LookupTable expects T3Value keys. Strings must be T3Value.sstring/dstring.
        // Since these are global symbols, they might not be in the pool?
        // Actually, TADS 3 LookupTables can use strings as keys.
        // We need to verify if we need to intern the string.
        // For simplicity, we can create a dynamic string for each key.
        final strOffset = interp.addDynamicString(name);
        table.set(T3Value.fromString(strOffset), value);
      });
    }

    interp.objectTable.registerObject(table);
    interp.registers.r0 = T3Value.fromObject(tableId);
  }

  /// t3AllocProp() - Allocate a new property ID.
  /// Ref: vmbift3.cpp line 219
  static void allocProp(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    final newProp = interp.allocatePropertyId();
    interp.registers.r0 = T3Value.fromProp(newProp);
  }

  /// t3GetStackTrace(level?, flags?) - Get stack trace.
  /// Ref: vmbift3.cpp line 233
  static void getStackTrace(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);

    final frames = <T3Value>[];
    interp.stack.walkFrames((fp, depth) {
      final invokee = interp.stack.getValueAt(fp, T3Stack.fpOfsInvokee);
      final self = interp.stack.getValueAt(fp, T3Stack.fpOfsSelf);
      final definingObj = interp.stack.getValueAt(fp, T3Stack.fpOfsDefObj);
      final propId = interp.stack.getValueAt(fp, T3Stack.fpOfsTargetProp);
      final targetObj = interp.stack.getValueAt(fp, T3Stack.fpOfsTargetObj);
      final argCount = interp.stack.getValueAt(fp, T3Stack.fpOfsArgCount);

      final frameInfo = [
        invokee,
        self,
        definingObj,
        propId,
        targetObj,
        argCount,
      ];

      final frameInfoId = interp.addDynamicList(frameInfo);
      frames.add(T3Value.fromList(frameInfoId));
      return true;
    });

    final listId = interp.addDynamicList(frames);
    interp.registers.r0 = T3Value.fromList(listId);
  }

  /// t3GetNamedArg(name) - Get a named argument value.
  /// Ref: vmbift3.cpp line 800 (ish)
  static void getNamedArg(T3Interpreter interp, int argc) {
    if (argc < 1) throw T3Exception('t3_get_named_arg() requires 1 argument');

    final nameVal = interp.stack.pop();
    if (argc > 1) interp.stack.discard(argc - 1);

    final name = interp.getStringValue(nameVal);
    final tableAddr = interp.stack
        .getFromFrame(T3Stack.fpOfsNamedArgs)
        .numToInt();

    if (tableAddr == 0 || tableAddr == -1 || interp.codePool == null) {
      interp.registers.r0 = T3Value.nil();
      return;
    }

    final pool = interp.codePool!;
    final count = pool.readUint16(tableAddr);
    for (var i = 0; i < count; i++) {
      final entryAddr = tableAddr + 2 + (i * 6);
      final nameOffset = pool.readUint32(entryAddr);
      final argIdx = pool.readUint16(entryAddr + 4);

      // Resolve the name from the constant pool (it's a string offset)
      // Actually, nametab offsets are usually relative to the table or image?
      // Spec says: "name_offset is the offset of the name string in the image file"
      // Wait, it says "relative to the start of the image file".
      // But usually it's in the constant pool.
      // Reference VM: it's a global string offset.
      final entryName = interp.constantPool?.readString(nameOffset);
      if (entryName == name) {
        // argIdx is 1-based index into the argument list.
        // In our T3Stack, getArg(0) is the first argument.
        interp.registers.r0 = interp.stack.getArg(argIdx - 1);
        return;
      }
    }

    interp.registers.r0 = T3Value.nil();
  }

  /// t3GetNamedArgList() - Get all named arguments as a list.
  /// Ref: vmbift3.cpp line 810 (ish)
  static void getNamedArgList(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);

    final tableAddr = interp.stack
        .getFromFrame(T3Stack.fpOfsNamedArgs)
        .numToInt();
    if (tableAddr == 0 || tableAddr == -1 || interp.codePool == null) {
      final listId = interp.addDynamicList([]);
      interp.registers.r0 = T3Value.fromList(listId);
      return;
    }

    final pool = interp.codePool!;
    final count = pool.readUint16(tableAddr);
    final result = <T3Value>[];

    for (var i = 0; i < count; i++) {
      final entryAddr = tableAddr + 2 + (i * 6);
      final nameOffset = pool.readUint32(entryAddr);
      final entryName = interp.constantPool?.readString(nameOffset) ?? '';

      final strOffset = interp.addDynamicString(entryName);
      result.add(T3Value.fromString(strOffset));
    }

    final listId = interp.addDynamicList(result);
    interp.registers.r0 = T3Value.fromList(listId);
  }
}
