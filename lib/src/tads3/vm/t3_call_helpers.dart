import 'package:zart/src/tads3/vm/t3_code_pool.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_object_table.dart';
import 'package:zart/src/tads3/vm/t3_registers.dart';
import 'package:zart/src/tads3/vm/t3_stack.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';
import 'package:zart/src/loaders/tads/t3_exception.dart';

/// Mixin that provides helper methods for call opcodes in the T3 VM.
///
/// This mixin is used by [T3Interpreter] to provide the helper methods
/// for CALL, PTRCALL, CALLPROP, and BUILTIN opcodes. Extracting these
/// keeps the main interpreter file focused on opcode execution.
mixin T3CallHelpers {
  // Required accessors - must be provided by implementing class
  T3Stack get callStack;
  T3Registers get callRegisters;
  T3CodePool? get callCodePool;
  T3ObjectTable get callObjectTable;

  // Required method references - must be provided by implementing class
  void callFunction(
    int codeOffset,
    int argc, {
    T3Value? self,
    T3Value? targetObj,
    T3Value? definingObj,
    int? propId,
    T3Value? invokee,
    T3Value? context,
  });
  void evalProperty(T3Value target, int propId, {int? argc});
  void callBuiltin(int setIdx, int funcIdx, int argc);

  // ==================== Call Opcode Helpers ====================

  /// Handles CALL opcode - reads address and calls function.
  void handleCallOp(int argc) {
    final targetAddr = callCodePool!.readUint32(callRegisters.ip);
    callRegisters.ip += 4;
    callFunction(targetAddr, argc);
  }

  /// Handles PTRCALL opcode - pops function pointer and calls it.
  void handlePtrCallOp(int argc) {
    final funcPtr = callStack.pop();
    if (funcPtr.isCodeOffset || funcPtr.isFuncPtr) {
      callFunction(funcPtr.value, argc);
    } else if (funcPtr.type == T3DataType.obj) {
      // Handle anon-func-ptr objects
      final codeOfs = getCallableOffset(funcPtr.value);
      if (codeOfs != null) {
        callFunction(codeOfs, argc, self: funcPtr, invokee: funcPtr, context: funcPtr);
      } else {
        final obj = callObjectTable.lookup(funcPtr.value);
        final elementsStr = (obj is T3VectorObject) ? obj.elements.toString() : 'N/A';
        throw T3Exception(
          'PTRCALL: object ${funcPtr.value} is not callable '
          '(metaclass: ${obj?.metaclass}, '
          'runtimeType: ${obj.runtimeType}, '
          'elements: $elementsStr)',
        );
      }
    } else {
      throw T3Exception('PTRCALL requires function pointer, got ${funcPtr.type}');
    }
  }

  /// Handles CALLPROP opcode - reads property ID, pops target, and calls.
  void handleCallPropOp(int argc) {
    final propId = callCodePool!.readUint16(callRegisters.ip);
    callRegisters.ip += 2;
    final target = callStack.pop();
    evalProperty(target, propId, argc: argc);
  }

  /// Handles CALLPROPSELF opcode - reads property ID and calls on self.
  void handleCallPropSelfOp(int argc) {
    final propId = callCodePool!.readUint16(callRegisters.ip);
    callRegisters.ip += 2;
    final self = callStack.getSelf();
    evalProperty(self, propId, argc: argc);
  }

  /// Handles OBJCALLPROP opcode - reads object ID, property ID, and calls.
  void handleObjCallPropOp(int argc) {
    final objId = callCodePool!.readUint32(callRegisters.ip);
    callRegisters.ip += 4;
    final propId = callCodePool!.readUint16(callRegisters.ip);
    callRegisters.ip += 2;
    final target = T3Value.fromObject(objId);
    evalProperty(target, propId, argc: argc);
  }

  /// Handles CALLPROPLCL1 opcode - reads local number, property ID, and calls.
  void handleCallPropLcl1Op(int argc) {
    final localNum = callCodePool!.readByte(callRegisters.ip++);
    final propId = callCodePool!.readUint16(callRegisters.ip);
    callRegisters.ip += 2;
    final target = callStack.getLocal(localNum);
    evalProperty(target, propId, argc: argc);
  }

  /// Handles CALLPROPR0 opcode - reads property ID and calls on R0.
  void handleCallPropR0Op(int argc) {
    final propId = callCodePool!.readUint16(callRegisters.ip);
    callRegisters.ip += 2;

    evalProperty(callRegisters.r0, propId, argc: argc);
  }

  /// Handles BUILTIN_A/B/C/D opcodes - calls builtin from specified set.
  void handleBuiltinOp(int setIdx, int argc) {
    final funcIdx = callCodePool!.readByte(callRegisters.ip++);
    callBuiltin(setIdx, funcIdx, argc);
  }

  /// Handles BUILTIN1 opcode - reads func index and set index.
  void handleBuiltin1Op(int argc) {
    final funcIdx = callCodePool!.readByte(callRegisters.ip++);
    final setIdx = callCodePool!.readByte(callRegisters.ip++);
    callBuiltin(setIdx, funcIdx, argc);
  }

  /// Handles BUILTIN2 opcode - reads 2-byte func index and set index.
  void handleBuiltin2Op(int argc) {
    final funcIdx = callCodePool!.readUint16(callRegisters.ip);
    callRegisters.ip += 2;
    final setIdx = callCodePool!.readByte(callRegisters.ip++);
    callBuiltin(setIdx, funcIdx, argc);
  }

  /// Gets the code offset for a callable object (anon-func-ptr, etc.)
  int? getCallableOffset(int objectId) {
    final obj = callObjectTable.lookup(objectId);
    if (obj == null) return null;

    // For anon-func-ptr and vector: element 0 contains the entry point
    if (obj is T3VectorObject) {
      if (obj.elements.isNotEmpty) {
        final entryVal = obj.elements[0];
        if (entryVal.isCodeOffset || entryVal.isFuncPtr) {
          return entryVal.value;
        }
      }
    }

    // For tads-object: try looking up 'ObjectCallProp' property (property 5)
    if (obj is T3TadsObject) {
      final callProp = obj.getProperty(5);
      if (callProp != null && (callProp.isCodeOffset || callProp.isFuncPtr)) {
        return callProp.value;
      }
    }

    // print('getCallableOffset: ID $objectId, metaclass ${obj.metaclass}, type ${obj.runtimeType} -> NOT CALLABLE');
    return null;
  }

  /// Calls a function pointer or object.
  void callFunctionPointer(T3Value func, int argc) {
    if (func.type == T3DataType.funcptr || func.type == T3DataType.codeofs) {
      callFunction(func.value, argc);
    } else if (func.type == T3DataType.obj) {
      final codeOfs = getCallableOffset(func.value);
      if (codeOfs != null) {
        callFunction(codeOfs, argc, self: func, invokee: func);
      } else {
        throw T3Exception('Object ${func.value} is not callable');
      }
    } else {
      throw T3Exception('Value of type ${func.type} is not callable');
    }
  }
}
