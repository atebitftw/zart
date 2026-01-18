/// T3 VM Execution Engine Constants and Helpers.
///
/// This file contains constants for stack frame layout and special return
/// addresses used by the VM execution engine. Ported from vmrun.h/vmrun.cpp.
library;

import 'package:zart/src/tads3/vm/t3_globals.dart';
import 'package:zart/src/tads3/vm/t3_func.dart';
import 'package:zart/src/tads3/vm/t3_opcode.dart';
import 'dart:typed_data';
import 'package:zart/src/tads3/vm/t3_std.dart' show t3Ashr, t3Lshr;
import 'package:zart/src/tads3/vm/t3_type.dart';
import 'package:zart/src/tads3/vm/t3_error.dart';

// ----------------------------------------------------------------------------
// Special Return Addresses
// ----------------------------------------------------------------------------

/// Check if the given offset is a special return address.
///
/// A return address is always an offset from the start of a method header,
/// so any offset less than the header size (10) is inherently invalid as
/// an actual return address and can be used to signal special meanings.
bool vmrunIsSpecialReturn(int ofs) => ofs < 10;

/// Recursive call return address.
///
/// This value for the return offset indicates that this is a recursive
/// call into the VM, so the bytecode execution loop should simply return
/// when this frame exits.
const int vmrunRetRecursive = 0;

/// Return from operator overload.
///
/// On return from this frame, the VM executes:
/// 1. Push R0 onto the stack
/// 2. Swap top two stack elements
/// 3. Pop offset and return to that location
const int vmrunRetOp = 1;

/// Return from operator overload and assign to local.
///
/// On return from this frame, the VM assigns R0 to a local variable
/// (number stored on stack), then returns to the real return address.
const int vmrunRetOpAsilcl = 2;

// ----------------------------------------------------------------------------
// Frame Pointer Offsets
// ----------------------------------------------------------------------------

/// Offset from FP of first argument.
const int vmrunFpOfsArg1 = -11;

/// Offset from FP of target property.
const int vmrunFpOfsProp = -10;

/// Offset from FP of original target object.
const int vmrunFpOfsOrigTarg = -9;

/// Offset from FP of defining object (definer of current method).
const int vmrunFpOfsDefObj = -8;

/// Offset from FP of 'self'.
const int vmrunFpOfsSelf = -7;

/// Offset from FP of invokee (FuncPtr, DynamicFunc, AnonFunc, etc).
const int vmrunFpOfsInvokee = -6;

/// Offset from FP of frame reference (for reflection access).
const int vmrunFpOfsFrameRef = -5;

/// Offset from FP of recursive VM invocation native caller context.
const int vmrunFpOfsRcdesc = -4;

/// Offset from FP of return address.
const int vmrunFpOfsRet = -3;

/// Offset from FP of enclosing entry pointer.
const int vmrunFpOfsEncEp = -2;

/// Offset from FP of argument count.
const int vmrunFpOfsArgc = -1;

/// Offset from FP of enclosing frame pointer.
const int vmrunFpOfsEncFp = 0;

/// Offset from FP of first local variable.
const int vmrunFpOfsLcl1 = 1;

// ----------------------------------------------------------------------------
// Frame Layout Description
// ----------------------------------------------------------------------------

/// Stack frame layout (FP at position 0):
///
/// ```
/// Stack Index  | Content
/// -------------|-----------------------
///    +N        | local variable N
///    +2        | local variable 2
///    +1        | local variable 1        (VMRUN_FPOFS_LCL1)
///     0        | enclosing frame pointer (VMRUN_FPOFS_ENC_FP) <-- FP
///    -1        | argument count          (VMRUN_FPOFS_ARGC)
///    -2        | enclosing entry pointer (VMRUN_FPOFS_ENC_EP)
///    -3        | return address          (VMRUN_FPOFS_RET)
///    -4        | recursive context       (VMRUN_FPOFS_RCDESC)
///    -5        | frame reference         (VMRUN_FPOFS_FRAMEREF)
///    -6        | invokee                 (VMRUN_FPOFS_INVOKEE)
///    -7        | self                    (VMRUN_FPOFS_SELF)
///    -8        | defining object         (VMRUN_FPOFS_DEFOBJ)
///    -9        | original target object  (VMRUN_FPOFS_ORIGTARG)
///   -10        | target property         (VMRUN_FPOFS_PROP)
///   -11        | argument 1              (VMRUN_FPOFS_ARG1)
///   -12        | argument 2
///   -11-N      | argument N
/// ```

// ----------------------------------------------------------------------------
// Arithmetic Operations
// ----------------------------------------------------------------------------

/// Arithmetic operations for VM execution.
///
/// These utilities handle integer arithmetic with proper overflow and
/// error handling. Object-type operations (strings, lists, BigNumber)
/// are handled by the respective metaclasses.
///
/// Shift operations delegate to [t3Ashr] and [t3Lshr] from t3_std.dart.
class T3Arithmetic {
  T3Arithmetic._();

  /// Compute the sum of two integer values.
  ///
  /// TADS3 uses 32-bit signed integers. Dart integers are 64-bit,
  /// so we mask to 32 bits and sign-extend.
  static int computeIntSum(int a, int b) {
    return _to32BitSigned(a + b);
  }

  /// Compute the difference of two integer values.
  static int computeIntDiff(int a, int b) {
    return _to32BitSigned(a - b);
  }

  /// Compute the product of two integer values.
  static int computeIntProduct(int a, int b) {
    return _to32BitSigned(a * b);
  }

  /// Compute the quotient of two integer values.
  ///
  /// Returns null if [b] is zero (caller should throw divide-by-zero error).
  static int? computeIntQuotient(int a, int b) {
    if (b == 0) return null;
    // Use truncating division (toward zero) like C/C++
    return a ~/ b;
  }

  /// Compute the modulo of two integer values.
  ///
  /// Returns null if [b] is zero (caller should throw divide-by-zero error).
  static int? computeIntMod(int a, int b) {
    if (b == 0) return null;
    // Use remainder (matches C/C++ modulo for integers)
    return a.remainder(b);
  }

  /// Compute logical XOR.
  ///
  /// Returns true if exactly one of the values is true.
  static bool logicalXor(bool a, bool b) {
    return a ^ b;
  }

  /// Compute bitwise XOR for integers.
  static int bitwiseXor(int a, int b) {
    return _to32BitSigned(a ^ b);
  }

  /// Compute bitwise AND for integers.
  static int bitwiseAnd(int a, int b) {
    return _to32BitSigned(a & b);
  }

  /// Compute bitwise OR for integers.
  static int bitwiseOr(int a, int b) {
    return _to32BitSigned(a | b);
  }

  /// Compute bitwise NOT for an integer.
  static int bitwiseNot(int a) {
    return _to32BitSigned(~a);
  }

  /// Compute left shift.
  static int shiftLeft(int a, int b) {
    if (b < 0 || b >= 32) return 0;
    return _to32BitSigned(a << b);
  }

  /// Compute arithmetic right shift (sign-extending).
  ///
  /// Delegates to [t3Ashr] from t3_std.dart.
  static int shiftRightArithmetic(int a, int b) => t3Ashr(a, b);

  /// Compute logical right shift (zero-extending).
  ///
  /// Delegates to [t3Lshr] from t3_std.dart.
  static int shiftRightLogical(int a, int b) => t3Lshr(a, b);

  /// Convert to 32-bit signed integer (TADS3 integer range).
  static int _to32BitSigned(int value) {
    // Mask to 32 bits
    final masked = value & 0xFFFFFFFF;
    // Sign-extend if high bit is set
    if (masked >= 0x80000000) {
      return masked - 0x100000000;
    }
    return masked;
  }
}

/// Result of a property lookup.
///
/// Ported from the various property return values in vmrun.cpp.
class T3PropertyResult {
  /// Create a new property result.
  T3PropertyResult() {
    reset();
  }

  /// The value found for the property.
  final T3Value value = T3Value();

  /// The object ID where the property was actually found (for inheritance).
  int definingObj = invalidObjectId;

  /// The number of arguments the property evaluation consumed.
  int argc = 0;

  /// The property ID being evaluated.
  int propId = 0;

  /// Reset the result for a new lookup.
  void reset() {
    value.setEmpty();
    definingObj = invalidObjectId;
    argc = 0;
    propId = 0;
  }
}

/// Handles property evaluation and method invocation.
///
/// This is a Dart port of the `vmrun_prop_eval` struct in `vmrun.cpp`.
class T3PropertyEvaluator {
  /// VM globals for accessing system state.
  final T3Globals globals;

  /// The target object for the current property evaluation.
  T3Value self = T3Value();

  /// The property being evaluated.
  int targetProp = invalidPropertyId;

  /// Cached lookup result to avoid re-allocating.
  final T3PropertyResult result = T3PropertyResult();

  T3PropertyEvaluator(this.globals);

  /// Look up a property without evaluating it.
  ///
  /// This finds the raw value of [propId] on the [self] object.
  /// Ported from `get_prop_no_eval` in `vmrun.cpp`.
  bool getPropNoEval(T3Value selfValue, int propId) {
    self.copyFrom(selfValue);
    targetProp = propId;
    result.reset();

    // Property evaluation works on objects, strings, and lists.
    switch (self.type) {
      case T3DataType.obj:
        final objId = self.getAsObj();
        if (objId == null || objId == invalidObjectId) return false;

        final obj = globals.objTable?.getObj(objId);
        if (obj == null) return false;

        final source = [invalidObjectId];
        final found = obj.getProp(
          globals as dynamic, // T3VM placeholder
          propId,
          result.value,
          objId,
          source,
          null,
        );

        if (found) {
          result.definingObj = source[0];
        }
        return found;

      case T3DataType.nil:
        return false;

      default:
        return false;
    }
  }

  /// Evaluate a property value.
  ///
  /// Takes the result from [getPropNoEval] and processes it. If it's code,
  /// it sets up a call frame; if it's a value, it stores it in R0.
  ///
  /// Ported from `eval_prop_val` in `vmrun.cpp`.
  ///
  /// Returns the new program counter if a call was initiated, or [curPc] if
  /// a simple value was returned.
  int? evalPropVal(int curPc, int argc) {
    final val = result.value;

    switch (val.type) {
      case T3DataType.codeOfs:
      case T3DataType.dstring:
        // It's a method - setup call frame.
        // The induction expects 5 items already on stack:
        // [invokee, self, definingObj, targetObj, targetProp]
        // Since we are coming from evalProp, we should push these.
        // For now, we'll push placeholders based on the current evaluation result.
        final stack = globals.stack!;
        stack.push(T3Value()..setNil()); // invokee (placeholder)
        stack.push(T3Value.copy(this.self)); // self
        stack.push(T3Value(T3DataType.obj)..setObj(result.definingObj)); // definingObj
        stack.push(T3Value.copy(this.self)); // targetObj
        stack.push(T3Value(T3DataType.prop)..setPropId(targetProp)); // targetProp

        return globals.interpreter.functionCaller.doCall(curPc, val.getAsOfs()!, argc);

      default:
        // Any other value - no arguments allowed.
        if (argc != 0) {
          // throw T3VmException(vmErrWrongNumOfArgs);
        }
        // Store result in R0.
        globals.r0.copyFrom(val);
        return curPc;
    }
  }
}

/// Handles function and method calls.
///
/// This is a Dart port of the call-related methods in `CVmRun` from `vmrun.cpp`.
class T3FunctionCaller {
  /// VM globals for accessing system state.
  final T3Globals globals;

  T3FunctionCaller(this.globals);

  /// Call a function or method.
  ///
  /// [callerOfs] is the byte code offset in the caller. If 0, this is a recursive
  /// call from native code.
  /// [targetPtr] is the byte-code address (pointer-like address in pools) to invoke.
  /// [argc] is the number of arguments pushed by the caller.
  /// [recurseCtx] is an optional recursive call descriptor.
  ///
  /// Returns the new program counter (byte-code offset) or null for recursive calls.
  int? doCall(int callerOfs, int targetPtr, int argc, [dynamic recurseCtx]) {
    final stack = globals.stack!;
    final codePool = globals.codePool!;

    // Store nil in R0 (effectively clears it for the new call)
    // globals.interpreter.r0.setNil();

    // Get the function header
    final (hdrData, hdrOfs) = codePool.getPtr(targetPtr);
    final hdr = T3FuncHeader(hdrData, hdrOfs);

    final lclCnt = hdr.localCnt;

    // Check stack space (11 fixed slots + locals)
    // We don't have a checkSpace method yet, but we'll need it.
    // if (!stack.checkSpace(hdr.stackDepth + 11)) throw ...

    // The caller has already pushed 5 items: targetprop, targetobj, definingobj, self, invokee.
    // We now push the remaining 6 metadata items + lclCnt locals.

    // Push metadata
    stack.push(T3Value(T3DataType.nil)); // frameref
    stack.push(T3Value(T3DataType.codeOfs)..setCodeOfs(0)); // rcdesc (placeholder)
    stack.push(T3Value(T3DataType.codeOfs)..setCodeOfs(callerOfs)); // caller's code offset
    stack.push(T3Value(T3DataType.codeOfs)..setCodeOfs(globals.entryPtr)); // caller's entry pointer
    stack.push(T3Value(T3DataType.int32)..setInt(argc)); // actual parameter count

    // The current FP will point to the location of the OLD frame pointer
    final oldFp = globals.framePtr;
    stack.push(T3Value(T3DataType.stack)..setStack(oldFp));

    // Update frame pointer to the new frame (pointing at the slot we just pushed)
    globals.framePtr = stack.getTopPointer() - 1;

    // Validate argument count
    if (!hdr.argcOk(argc)) {
      // Throw wrong number of args
      // throw vmErrWrongNumOfArgs;
    }

    // Load new entry pointer
    globals.entryPtr = targetPtr;

    // Push locals (initialized to nil)
    for (int i = 0; i < lclCnt; i++) {
      stack.push(T3Value(T3DataType.nil));
    }

    // If it's a non-recursive call, return the PC after the header
    if (callerOfs != 0) {
      return (targetPtr + globals.funchdrSize).toInt();
    } else {
      // Recursive call - would call interpreter.run() here.
      return null;
    }
  }

  /// Call a function pointer value.
  ///
  /// Ported from `call_func_ptr` in `vmrun.cpp`.
  int? callFuncPtr(T3Value funcPtr, int argc, int callerOfs) {
    final stack = globals.stack!;

    // Prepare invocation frame (5 fixed slots)
    stack.push(T3Value(T3DataType.prop)..setPropId(invalidPropertyId));
    stack.push(T3Value(T3DataType.nil)); // targetobj
    stack.push(T3Value(T3DataType.nil)); // definingobj

    if (funcPtr.type == T3DataType.obj) {
      stack.push(T3Value(T3DataType.obj)..setObj(funcPtr.getAsObj()!));
    } else {
      stack.push(T3Value(T3DataType.nil));
    }

    stack.push(T3Value.copy(funcPtr)); // invokee

    // Handle based on type
    switch (funcPtr.type) {
      case T3DataType.funcPtr:
        final ofs = funcPtr.getAsOfs()!;
        return doCall(callerOfs, ofs, argc);

      case T3DataType.obj:
        // Anonymous function or other invokable object.
        // We'll need metaclass support to check if it's invokable.
        // For now, placeholder error.
        return null;

      case T3DataType.bifPtr:
        // Built-in function.
        // built-ins don't use the standard frame, so discard it.
        stack.discard(5);
        // globals.bifTable.callBif(funcPtr.getBifSet(), funcPtr.getBifFunc(), argc);
        return null;

      default:
        // throw vmErrFuncPtrValReqd;
        return null;
    }
  }
}

/// TADS 3 Interpreter
///
/// This class implements the main execution loop for the TADS 3 VM.
/// It fetches and executes opcodes, managing the program counter and stack.
/// This class implements the main execution loop for the TADS 3 VM.
/// It fetches and executes opcodes, managing the program counter and stack.
class T3Interpreter {
  /// VM globals
  final T3Globals globals;

  /// Property evaluator helper
  late final T3PropertyEvaluator propertyEvaluator;

  /// Function caller helper
  late final T3FunctionCaller functionCaller;

  /// Create an interpreter
  T3Interpreter(this.globals) {
    propertyEvaluator = T3PropertyEvaluator(globals);
    functionCaller = T3FunctionCaller(globals);
  }

  /// Pop an integer from the stack.
  int _popInt() {
    final val = T3Value();
    globals.stack!.pop(val);
    return val.getAsInt();
  }

  void run([int? startPc]) {
    // Set the initial program counter if provided
    if (startPc != null) {
      globals.pc = startPc;
    }

    final stack = globals.stack!;

    // The execution loop
    while (true) {
      // Get the current instruction pointer (absolute offset in code pool)
      final curPc = globals.pc;

      // Get the bytecode data and absolute pointer for the current PC
      final (codeData, p) = globals.codePool!.getPtr(curPc);

      // Fetch the opcode
      final opcode = codeData[p];
      globals.pc++;

      // Dispatch the opcode
      switch (opcode) {
        // --- 0x01 - 0x10: Push Constants ---
        case opcPush0:
          stack.push(T3Value(T3DataType.int32)..setInt(0));
          break;

        case opcPush1:
          stack.push(T3Value(T3DataType.int32)..setInt(1));
          break;

        case opcPushInt8:
          stack.push(T3Value(T3DataType.int32)..setInt(_getOpInt8(codeData, p + 1)));
          globals.pc += 1;
          break;

        case opcPushInt:
          stack.push(T3Value(T3DataType.int32)..setInt(_getOpInt32(codeData, p + 1)));
          globals.pc += 4;
          break;

        case opcPushStr:
          stack.push(T3Value(T3DataType.sstring)..setSstring(_getOpUint32(codeData, p + 1)));
          globals.pc += 4;
          break;

        case opcPushObj:
          stack.push(T3Value(T3DataType.obj)..setObj(_getOpUint32(codeData, p + 1)));
          globals.pc += 4;
          break;

        case opcPushNil:
          stack.push(T3Value(T3DataType.nil));
          break;

        case opcPushTrue:
          stack.push(T3Value(T3DataType.trueValue));
          break;

        case opcPushFnPtr:
          stack.push(T3Value(T3DataType.funcPtr)..setFnPtr(_getOpUint32(codeData, p + 1)));
          globals.pc += 4;
          break;

        // --- Arithmetic/Logic Operations (0x20 - 0x30) ---
        case opcNeg:
          final v = _popInt();
          stack.push(T3Value(T3DataType.int32)..setInt(-v));
          break;

        case opcAdd:
          final v2 = _popInt();
          final v1 = _popInt();
          stack.push(T3Value(T3DataType.int32)..setInt(v1 + v2));
          break;

        case opcSub:
          final v2 = _popInt();
          final v1 = _popInt();
          stack.push(T3Value(T3DataType.int32)..setInt(v1 - v2));
          break;

        // --- Comparison Operations (0x40 - 0x45) ---
        case opcEq:
          final v2 = T3Value();
          stack.pop(v2);
          final v1 = T3Value();
          stack.pop(v1);
          stack.push(T3Value()..setLogical(v1.equals(v2)));
          break;

        // --- Return Instructions (0x50 - 0x54) ---
        case opcRetval:
          globals.r0.copyFrom(stack.get(0));
          stack.discard();
          if (_doReturn()) return;
          break;

        case opcRetnil:
          globals.r0.setNil();
          if (_doReturn()) return;
          break;

        case opcRettrue:
          globals.r0.setTrue();
          if (_doReturn()) return;
          break;

        case opcRet:
          if (_doReturn()) return;
          break;

        // --- Function Calls (0x58 - 0x59) ---
        case opcCall:
          final argc = _getOpUint8(codeData, p + 1);
          final target = _getOpUint32(codeData, p + 2);
          globals.pc += 5;

          // Push context (5 items) for direct function call (no object context)
          globals.stack!.push(T3Value(T3DataType.prop)..setPropId(invalidPropertyId));
          globals.stack!.push(T3Value(T3DataType.nil)); // targetobj
          globals.stack!.push(T3Value(T3DataType.nil)); // definingobj
          globals.stack!.push(T3Value(T3DataType.nil)); // self
          globals.stack!.push(T3Value(T3DataType.nil)); // invokee

          final nextPc = functionCaller.doCall(globals.pc, target, argc);
          if (nextPc != null) {
            globals.pc = nextPc;
          }
          break;

        case opcPtrCall: // 0x59
          final argc = _getOpUint8(codeData, p + 1);
          globals.pc += 1; // Instruction size 2 (increment 1)
          final funcPtr = T3Value();
          stack.pop(funcPtr);

          final nextPc = functionCaller.callFuncPtr(funcPtr, argc, globals.pc);
          if (nextPc != null) {
            globals.pc = nextPc;
          }
          break;

        // --- Property Access (0x60 - 0x6D) ---
        case opcGetProp:
          final propId = _getOpUint16(codeData, p + 1);
          globals.pc += 2;
          final self = T3Value();
          stack.pop(self);
          propertyEvaluator.self.copyFrom(self);
          if (propertyEvaluator.getPropNoEval(propertyEvaluator.self, propId)) {
            final nextPc = propertyEvaluator.evalPropVal(globals.pc, 0);
            if (nextPc != null) globals.pc = nextPc;
          } else {
            globals.r0.setNil();
          }
          break;

        case opcCallProp:
          final propId = _getOpUint16(codeData, p + 1);
          final argc = _getOpUint8(codeData, p + 3);
          globals.pc += 3;
          final self = T3Value();
          stack.pop(self);
          propertyEvaluator.self.copyFrom(self);
          if (propertyEvaluator.getPropNoEval(propertyEvaluator.self, propId)) {
            final nextPc = propertyEvaluator.evalPropVal(globals.pc, argc);
            if (nextPc != null) globals.pc = nextPc;
          } else {
            globals.r0.setNil();
          }
          break;

        // --- Argument Access (0x7C - 0x7F) ---
        case opcGetArgN0:
          stack.push(T3Value.copy(stack.getRef(globals.framePtr + vmrunFpOfsArg1)));
          break;
        case opcGetArgN1:
          stack.push(T3Value.copy(stack.getRef(globals.framePtr + vmrunFpOfsArg1 - 1)));
          break;

        // --- Stack/Local Access (0x80 - 0x8F) ---
        case opcGetLcl1:
          stack.push(T3Value.copy(stack.getRef(globals.framePtr + vmrunFpOfsLcl1 + _getOpUint8(codeData, p + 1))));
          globals.pc += 1;
          break;

        case opcGetArg1:
          stack.push(T3Value.copy(stack.getRef(globals.framePtr + vmrunFpOfsArg1 - _getOpUint8(codeData, p + 1))));
          globals.pc += 1;
          break;

        case opcPushSelf:
          final selfVal = stack.getRef(globals.framePtr + vmrunFpOfsSelf);
          stack.push(T3Value.copy(selfVal));
          break;

        case opcDup:
          stack.push(T3Value.copy(stack.get(0)));
          break;

        case opcDisc:
          stack.discard();
          break;

        case opcGetR0:
          stack.push(T3Value.copy(globals.r0));
          break;

        case opcSwap:
          final v1 = T3Value();
          stack.pop(v1);
          final v2 = T3Value();
          stack.pop(v2);
          stack.push(v1);
          stack.push(v2);
          break;

        // --- Built-in Functions and I/O (0xB0 - 0xBC) ---
        case opcSay:
          final strId = _getOpUint32(codeData, p + 1);
          globals.pc += 4;
          final str = globals.constPool!.getString(strId);
          globals.printFn(str); // Placeholder
          break;

        case opcBuiltinA:
          final funcIdx = _getOpUint8(codeData, p + 1);
          final argc = _getOpUint8(codeData, p + 2);
          globals.pc += 2;
          globals.bifTable?.callBif(0, funcIdx, argc);
          break;

        case opcBuiltinB:
          final funcIdx = _getOpUint8(codeData, p + 1);
          final argc = _getOpUint8(codeData, p + 2);
          globals.pc += 2;
          globals.bifTable?.callBif(1, funcIdx, argc);
          break;

        case opcBuiltinC:
          final funcIdx = _getOpUint8(codeData, p + 1);
          final argc = _getOpUint8(codeData, p + 2);
          globals.pc += 2;
          globals.bifTable?.callBif(2, funcIdx, argc);
          break;

        case opcBuiltinD:
          final funcIdx = _getOpUint8(codeData, p + 1);
          final argc = _getOpUint8(codeData, p + 2);
          globals.pc += 2;
          globals.bifTable?.callBif(3, funcIdx, argc);
          break;

        case opcBuiltin1:
          final setIdx = _getOpUint8(codeData, p + 1);
          final funcIdx = _getOpUint8(codeData, p + 2);
          final argc = _getOpUint8(codeData, p + 3);
          globals.pc += 3;
          globals.bifTable?.callBif(setIdx, funcIdx, argc);
          break;

        case opcBuiltin2:
          final setIdx = _getOpUint8(codeData, p + 1);
          final funcIdx = _getOpUint16(codeData, p + 2);
          final argc = _getOpUint8(codeData, p + 4);
          globals.pc += 4;
          globals.bifTable?.callBif(setIdx, funcIdx, argc);
          break;

        case opcSayVal:
          final val = T3Value();
          stack.pop(val);
          if (val.type == T3DataType.sstring) {
            globals.printFn(globals.constPool!.getString(val.getAsSstring()!));
          } else if (val.type == T3DataType.int32) {
            globals.printFn(val.getAsInt().toString());
          } else {
            globals.printFn(val.toString());
          }
          break;

        // --- Inheritance and Delegation (0x72 - 0x78) ---
        case opcInherit:
          final argc = _getOpUint8(codeData, p + 1);
          final propId = _getOpUint16(codeData, p + 2);
          globals.pc += 3;

          // Get 'self' and 'definingObj' from current frame
          final selfVal = stack.getRef(globals.framePtr + vmrunFpOfsSelf);
          final defObjVal = stack.getRef(globals.framePtr + vmrunFpOfsDefObj);

          if (selfVal.type != T3DataType.obj || defObjVal.type != T3DataType.obj) {
            throw T3VmException(vmErrObjValReqd);
          }

          final defObjId = defObjVal.getAsObj()!;
          final selfObjId = selfVal.getAsObj()!;

          // Note: inherit uses inhProp on the self object, passing definingObj
          // to let the object system determine where to start the search.
          final selfObjEntry = globals.objTable!.getEntry(selfObjId);
          if (selfObjEntry == null) throw T3VmException(vmErrObjValReqd);

          final retval = T3Value();
          final sourceObj = <int>[];

          // inhProp(vm, propId, retval, self, origTarget, definingObj, sourceObj, argc)
          final found = selfObjEntry.obj!.inhProp(
            globals,
            propId,
            retval,
            selfObjId,
            selfObjId,
            defObjId,
            sourceObj,
            argc,
          );

          if (!found) {
            // Unhandled inheritance is usually an error or returns nil?
            throw T3VmException(vmErrInvalidSetprop); // Placeholder for PropNotDefined (1001)
          }

          // Push return value (even if nil)
          stack.push(retval);
          break;

        case opcDelegate:
          final argc = _getOpUint8(codeData, p + 1);
          final propId = _getOpUint16(codeData, p + 2);
          globals.pc += 3;

          final targetVal = stack.popVal();
          if (targetVal.type != T3DataType.obj) throw T3VmException(vmErrObjValReqd);

          final targetId = targetVal.getAsObj()!;
          final targetEntry = globals.objTable!.getEntry(targetId);
          if (targetEntry == null) throw T3VmException(vmErrObjValReqd);

          // Invoke prop on target
          final retval = T3Value();
          final sourceObj = <int>[];

          // getProp(vm, propId, retval, self, sourceObj, argc)
          final found = targetEntry.obj!.getProp(globals, propId, retval, targetId, sourceObj, argc);

          if (!found) {
            throw T3VmException(vmErrInvalidSetprop);
          }

          stack.push(retval);
          break;

        // --- Control Flow (0x90 - 0xA6) ---
        case opcJmp:
          globals.pc += 2 + _getOpInt16(codeData, p + 1);
          break;

        case opcJt:
          final v = T3Value();
          stack.pop(v);
          if (v.isLogicalTrue) {
            globals.pc += 2 + _getOpInt16(codeData, p + 1);
          } else {
            globals.pc += 2;
          }
          break;

        case opcJf:
          final v = T3Value();
          stack.pop(v);
          if (!v.isLogicalTrue) {
            globals.pc += 2 + _getOpInt16(codeData, p + 1);
          } else {
            globals.pc += 2;
          }
          break;

        case opcJnil:
          if (stack.get(0).type == T3DataType.nil) {
            globals.pc += 2 + _getOpInt16(codeData, p + 1);
          } else {
            globals.pc += 2;
          }
          stack.discard();
          break;

        case opcJe:
          final v2 = T3Value();
          stack.pop(v2);
          final v1 = T3Value();
          stack.pop(v1);
          if (v1.equals(v2)) {
            globals.pc += 2 + _getOpInt16(codeData, p + 1);
          } else {
            globals.pc += 2;
          }
          break;

        case opcJne:
          final v2 = T3Value();
          stack.pop(v2);
          final v1 = T3Value();
          stack.pop(v1);
          if (!v1.equals(v2)) {
            globals.pc += 2 + _getOpInt16(codeData, p + 1);
          } else {
            globals.pc += 2;
          }
          break;

        case opcJgt:
          _popInts((v1, v2) {
            if (v1 > v2)
              globals.pc += 2 + _getOpInt16(codeData, p + 1);
            else
              globals.pc += 2;
          });
          break;

        case opcJge:
          _popInts((v1, v2) {
            if (v1 >= v2)
              globals.pc += 2 + _getOpInt16(codeData, p + 1);
            else
              globals.pc += 2;
          });
          break;

        case opcJlt:
          _popInts((v1, v2) {
            if (v1 < v2)
              globals.pc += 2 + _getOpInt16(codeData, p + 1);
            else
              globals.pc += 2;
          });
          break;

        case opcJle:
          _popInts((v1, v2) {
            if (v1 <= v2)
              globals.pc += 2 + _getOpInt16(codeData, p + 1);
            else
              globals.pc += 2;
          });
          break;

        case opcJst:
          if (stack.get(0).isLogicalTrue) {
            globals.pc += 2 + _getOpInt16(codeData, p + 1);
          } else {
            globals.pc += 2;
            stack.discard();
          }
          break;

        case opcJsf:
          if (!stack.get(0).isLogicalTrue) {
            globals.pc += 2 + _getOpInt16(codeData, p + 1);
          } else {
            globals.pc += 2;
            stack.discard();
          }
          break;

        case opcJr0t:
          if (globals.r0.isLogicalTrue)
            globals.pc += 2 + _getOpInt16(codeData, p + 1);
          else
            globals.pc += 2;
          break;

        case opcJr0f:
          if (!globals.r0.isLogicalTrue)
            globals.pc += 2 + _getOpInt16(codeData, p + 1);
          else
            globals.pc += 2;
          break;

        case opcJnotNil:
          if (stack.get(0).type != T3DataType.nil) {
            globals.pc += 2 + _getOpInt16(codeData, p + 1);
          } else {
            globals.pc += 2;
          }
          break;

        case opcSwitch:
          final count = _getOpUint16(codeData, p + 1);
          final defOfs = _getOpInt16(codeData, p + 3);
          // globals.pc was p+1.
          // Table starts at p+5. Loop iterates count times (size 6).
          // Match skips 4 + (count*6) + caseOfs?
          // Spec says caseOfs is relative to start of instruction?
          // If so, globals.pc = p + caseOfs. Current globals.pc = p+1.
          // So += caseOfs - 1.

          final v = stack.popVal();
          final val = v.getAsInt();

          var found = false;
          for (var i = 0; i < count; i++) {
            final caseVal = _getOpInt32(codeData, p + 5 + i * 6);
            if (caseVal == val) {
              final caseOfs = _getOpInt16(codeData, p + 5 + i * 6 + 4);
              globals.pc += caseOfs - 1; // Assuming caseOfs relative to Opcode start
              found = true;
              break;
            }
          }

          if (!found) {
            // Skip table (4 + count*6) and add defOfs (relative to next instr?)
            // Spec says "branches relative to start of next instr".
            // Next instr start = p + 5 + count*6.
            // So target = p + 5 + count*6 + defOfs.
            // globals.pc = p+1. Diff = 4 + count*6 + defOfs.
            globals.pc += 4 + (count * 6) + defOfs;
          }
          break;

        case opcThrow:
          final exc = stack.popVal();
          _throwException(exc);
          break;

        // --- Object Creation (0xC0 - 0xC3) ---
        case opcNew1:
          final argc = _getOpUint8(codeData, p + 1);
          globals.pc += 1;

          final clsVal = stack.popVal();
          if (clsVal.type != T3DataType.obj) throw T3VmException(vmErrObjValReqd);

          final clsId = clsVal.getAsObj()!;
          final clsEntry = globals.objTable!.getEntry(clsId);
          if (clsEntry == null) throw T3VmException(vmErrObjValReqd);

          // createInstance(vm, self, pc, pcOfs, argc)
          clsEntry.obj!.createInstance(globals, clsId, codeData, p, argc);
          break;

        case opcNew2:
          final argc = _getOpUint8(codeData, p + 1);
          final metaIdx = _getOpUint16(codeData, p + 2);
          globals.pc += 3;

          final metaTable = globals.metaTable;
          if (metaTable == null) throw T3VmException(vmErrUnknownMetaclass);

          final metaEntry = metaTable.getEntryFromReg(metaIdx);
          if (metaEntry == null) throw T3VmException(vmErrUnknownMetaclass);

          metaEntry.meta.createFromStack(globals, codeData, p, argc);
          break;

        // --- Quick Local Access (0xAA - 0xAF) ---

        // --- Quick Local Access (0xAA - 0xAF) ---
        case opcGetLclN0:
          stack.push(T3Value.copy(stack.getRef(globals.framePtr + vmrunFpOfsLcl1)));
          break;
        case opcGetLclN1:
          stack.push(T3Value.copy(stack.getRef(globals.framePtr + vmrunFpOfsLcl1 + 1)));
          break;

        // --- Assignment Operations (0xE0 - 0xEF) ---
        case opcSetLcl1:
          stack.getRef(globals.framePtr + vmrunFpOfsLcl1 + _getOpUint8(codeData, p + 1)).copyFrom(stack.get(0));
          stack.discard();
          globals.pc += 1;
          break;

        case opcSetProp:
          final propId = _getOpUint16(codeData, p + 1);
          globals.pc += 2;
          final val = T3Value();
          stack.pop(val);
          final self = T3Value();
          stack.pop(self);
          if (self.type == T3DataType.obj) {
            final obj = globals.objTable!.getEntry(self.getAsObj()!)?.obj;
            obj?.setProp(globals, null, self.getAsObj()!, propId, val);
          }
          break;

        default:
          // Unknown opcode - throw an error
          throw Exception('Unknown opcode: 0x${opcode.toRadixString(16).toUpperCase()} at PC ${globals.pc - 1}');
      }
    }
  }

  /// Perform a return from the current frame.
  ///
  /// Returns true if we should exit the execution loop (recursive return).
  /// Perform a return from the current frame.
  ///
  /// Returns true if we should exit the execution loop (recursive return).
  bool _doReturn() {
    final stack = globals.stack!;
    final fp = globals.framePtr;

    // Capture the return address and old frame pointer
    // Capture the return address and old frame pointer
    // Capture the return address and old frame pointer
    final retPc = stack.getRef(fp + vmrunFpOfsRet).getAsOfs()!;
    final oldFp = stack.getRef(fp + vmrunFpOfsEncFp).getAsStack()!;
    final oldEp = stack.getRef(fp + vmrunFpOfsEncEp).getAsOfs()!;

    // Pop the frame
    stack.setSp(fp + vmrunFpOfsArg1);

    // Update VM state
    globals.framePtr = oldFp;
    globals.entryPtr = oldEp;
    globals.pc = retPc;

    // If the return address is special, handle it.
    if (vmrunIsSpecialReturn(retPc)) {
      if (retPc == vmrunRetRecursive) {
        return true;
      }
      // TODO: Handle other special returns (vmrunRetOp, etc)
    }

    return false;
  }

  void _popInts(void Function(int v1, int v2) callback) {
    final stack = globals.stack!;
    final v2Val = T3Value();
    stack.pop(v2Val);
    final v1Val = T3Value();
    stack.pop(v1Val);
    callback(v1Val.getAsInt(), v2Val.getAsInt());
  }

  void _throwException(T3Value exc) {
    // Search for a handler starting from the current frame
    var fp = globals.framePtr;
    var pc = globals.pc;
    var ep = globals.entryPtr;
    final stack = globals.stack!;

    while (fp != -1 && !vmrunIsSpecialReturn(pc)) {
      // Get the function header and exception table
      final (codeData, p) = globals.codePool!.getPtr(ep);
      final hdr = T3FuncHeader(codeData, p);
      if (hdr.hasExcTable) {
        final table = T3ExcTable.fromFuncHeader(hdr, codeData)!;

        // Match relative PC
        final relPc = pc - ep;

        // Find handler
        final entry = table.findHandler(relPc, (excClassId) {
          // TODO: Implement proper instanceOf check
          // For now, if it's an object, we'll assume it matches if we want to be simple
          // But we should really check the object table.
          return true;
        });

        if (entry != null) {
          // Found a handler!
          globals.framePtr = fp;
          globals.entryPtr = ep;
          globals.pc = ep + entry.handlerOfs;

          // Push exception onto stack for handler
          stack.push(exc);
          return;
        }
      }

      // No handler in this frame, unwind
      if (fp == -1) break;

      final retPc = stack.getRef(fp + vmrunFpOfsRet).getAsOfs()!;
      final nextFp = stack.getRef(fp + vmrunFpOfsEncFp).getAsStack()!;
      final nextEp = stack.getRef(fp + vmrunFpOfsEncEp).getAsOfs()!;

      // If we hit a recursive return, we can't unwind further here
      if (vmrunIsSpecialReturn(retPc)) break;

      pc = retPc;
      fp = nextFp;
      ep = nextEp;
    }

    // If no handler found, it's an unhandled exception
    throw T3VmException(vmErrUnhandledExc);
  }

  // --- Operand Fetch Helpers ---

  int _getOpUint8(Uint8List data, int p) => data[p];
  int _getOpInt8(Uint8List data, int p) {
    int v = data[p];
    return v > 127 ? v - 256 : v;
  }

  int _getOpUint16(Uint8List data, int p) {
    return data[p] | (data[p + 1] << 8);
  }

  int _getOpInt16(Uint8List data, int p) {
    int v = data[p] | (data[p + 1] << 8);
    return v > 32767 ? v - 65536 : v;
  }

  int _getOpUint32(Uint8List data, int p) {
    return data[p] | (data[p + 1] << 8) | (data[p + 2] << 16) | (data[p + 3] << 24);
  }

  int _getOpInt32(Uint8List data, int p) {
    int v = data[p] | (data[p + 1] << 8) | (data[p + 2] << 16) | (data[p + 3] << 24);
    // Dart integers are 64-bit, so we need to handle 32-bit sign extension if needed.
    // However, TADS3 UINT4 and INT4 are the same bit pattern.
    return (v & 0xffffffff).toSigned(32);
  }
}
