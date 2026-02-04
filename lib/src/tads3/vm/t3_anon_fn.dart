import 'dart:typed_data';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_vector.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';
import 'package:zart/src/tads3/vm/t3_error.dart';

/// Anonymous Function Metaclass.
///
/// TADS3 Anonymous Functions are specialized vectors where the first element
/// is the function pointer to invoke, and subsequent elements are captured
/// closure variables.
class T3ObjAnonFn extends T3ObjVector {
  /// Registration object.
  static final T3MetaclassAnonFn metaclassReg = T3MetaclassAnonFn();

  /// Create with initial capacity.
  T3ObjAnonFn([int capacity = 0]) : super(capacity);

  @override
  T3Metaclass getMetaclassReg() => metaclassReg;

  @override
  bool isOfMetaclass(T3Metaclass meta) {
    return meta == metaclassReg || super.isOfMetaclass(meta);
  }

  /// Anonymous functions do not appear as lists to user code.
  @override
  bool isListlike(T3VM vm, int self) => false;

  /// Invoke the anonymous function.
  ///
  /// This returns the function pointer stored at index 0.
  @override
  bool getInvoker(T3VM vm, T3Value? val) {
    if (val != null) {
      // Get the function pointer from index 1 (1-based index 1 is internal index 0).
      val.copyFrom(getElement(1));

      // If the stored value is itself an object, delegate to its invoker.
      if (val.type == T3DataType.obj) {
        final objId = val.getAsObj();
        if (objId != null) {
          final obj = vm.objTable.getObj(objId);
          if (obj != null) {
            return obj.getInvoker(vm, val);
          }
        }
      }
    }
    return true;
  }

  @override
  bool equals(T3VM vm, int self, T3Value other, int depth) {
    // Anonymous functions compare strictly by reference.
    return other.type == T3DataType.obj && other.getAsObj() == self;
  }

  @override
  int calcHash(T3VM vm, int self, int depth) {
    // Hash based on object ID since we compare by reference.
    return (self & 0xFFFF) ^ ((self & 0xFFFF0000) >> 16);
  }

  /// Create an anonymous function from stack arguments.
  static int createFromStack(T3VM vm, int argc) {
    if (argc < 1) throw T3VmException(vmErrWrongNumOfArgs);

    final funcPtrVal = T3Value();
    vm.stack.pop(funcPtrVal);

    if (funcPtrVal.type != T3DataType.funcPtr &&
        funcPtrVal.type != T3DataType.codeOfs) {
      // Check if it's an invokable object.
      bool invokable = false;
      if (funcPtrVal.type == T3DataType.obj) {
        final objId = funcPtrVal.getAsObj();
        if (objId != null) {
          final obj = vm.objTable.getObj(objId);
          if (obj != null && obj.getInvoker(vm, null)) {
            invokable = true;
          }
        }
      }
      if (!invokable) throw T3VmException(vmErrFuncptrValReqd);
    }

    final anonFn = T3ObjAnonFn(argc);
    anonFn.setElementCount(argc);
    final id = vm.objTable.registerObj(anonFn, true);

    // Set index 1 to the function pointer.
    anonFn.setElement(1, funcPtrVal);

    // Set remaining elements from stack (popping in reverse order).
    for (int i = 2; i <= argc; i++) {
      final val = T3Value();
      vm.stack.pop(val);
      // vmanonfn.cpp pops into elements idx..argc-1.
      // If argc=3, and stack is [Arg1, Arg2, Arg3]:
      // Pop 1: Arg3 -> idx 0 (element 1)
      // Pop 2: Arg2 -> idx 1 (element 2)
      // Pop 3: Arg1 -> idx 2 (element 3)
      anonFn.setElement(i, val);
    }

    return id;
  }
}

/// Metaclass registration for Anonymous Functions.
class T3MetaclassAnonFn extends T3Metaclass {
  @override
  String getMetaName() => 'anon-func-ptr/030000';

  @override
  void createForImageLoad(T3VM vm, int id) {
    vm.objTable.registerObj(id, T3ObjAnonFn());
  }

  @override
  void createForRestore(T3VM vm, int id) {
    vm.objTable.registerObj(id, T3ObjAnonFn());
  }

  @override
  int createFromStack(T3VM vm, Uint8List pc, int pcOffset, int argc) {
    return T3ObjAnonFn.createFromStack(vm, argc);
  }

  @override
  T3Metaclass? getSupermetaReg() => T3ObjVector.metaclassReg;

  @override
  bool callStatProp(
    T3VM vm,
    T3Value result,
    Uint8List pc,
    int pcOffset,
    int argc,
    int prop,
  ) {
    return false;
  }

  @override
  int getClassObj(T3VM vm) => invalidObj;

  @override
  int getSupermeta(T3VM vm, int idx) => invalidObj;

  @override
  bool isMetaInstanceOf(T3VM vm, int obj) => false;
}
