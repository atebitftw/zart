import 'dart:io';
import 'dart:typed_data';

import 'package:zart/src/loaders/tads/t3_exception.dart';
import 'package:zart/src/tads3/loaders/entp_parser.dart';
import 'package:zart/src/tads3/loaders/fnsd_parser.dart';
import 'package:zart/src/tads3/loaders/mcld_parser.dart';
import 'package:zart/src/tads3/vm/t3_code_pool.dart';
import 'package:zart/src/tads3/vm/t3_constant_pool.dart';
import 'package:zart/src/tads3/vm/t3_execution_result.dart';
import 'package:zart/src/tads3/vm/t3_function_header.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_object_table.dart';
import 'package:zart/src/tads3/vm/t3_registers.dart';
import 'package:zart/src/tads3/vm/t3_stack.dart';
import 'package:zart/src/tads3/vm/t3_utf8.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';

/// Mixin providing execution helpers for function calls, property access,
/// object creation, and output handling.
mixin T3ExecutionHelpers {
  // Required accessors - must be provided by implementing class
  T3Stack get execStack;
  T3Registers get execRegisters;
  T3CodePool? get execCodePool;
  T3ConstantPool? get execConstantPool;
  T3ObjectTable get execObjectTable;
  T3Entrypoint? get execEntrypoint;
  T3MetaclassDepList? get execMetaclasses;
  T3FunctionSetDepList? get execFunctionSets;
  Map<String, T3Value> get execSymbols;
  Map<int, String> get execDynamicStrings;
  Map<int, List<T3Value>> get execDynamicLists;
  int get execNextDynamicStringOffset;
  set execNextDynamicStringOffset(int value);
  int get execOutputIgnoreDepth;
  set execOutputIgnoreDepth(int value);
  int get execSayMethod;
  T3Value get execSayFunc;
  int? get execStringMetaclassIdx;
  int? get execListMetaclassIdx;
  int get methodHeaderSize;

  // ==================== Object Creation ====================

  /// Creates a new dynamic object from a metaclass.
  void createNewObject(int metaclassIdx, int argc, {bool isTransient = false}) {
    final metaclass = execMetaclasses!.byIndex(metaclassIdx);
    if (metaclass == null) {
      throw T3Exception('NEW: invalid metaclass index $metaclassIdx');
    }

    // Pop constructor arguments (in reverse order)
    final args = <T3Value>[];
    for (var i = 0; i < argc; i++) {
      args.add(execStack.pop());
    }
    final reversedArgs = args.reversed.toList();

    final newObjId = execObjectTable.createDynamicObject(metaclass.name, reversedArgs, isTransient: isTransient);
    execRegisters.r0 = T3Value.fromObject(newObjId);
  }

  // ==================== Exception Handling ====================

  /// Finds an exception handler for the given exception object.
  int? findExceptionHandler(int exceptionObjId) {
    while (true) {
      final ep = execRegisters.ep;
      final headerBytes = execCodePool!.readBytes(ep, methodHeaderSize);
      final header = T3FunctionHeader.parse(headerBytes);

      if (header.exceptionTableOffset > 0) {
        final currentOffset = execRegisters.ip - ep;
        final tableAddr = ep + header.exceptionTableOffset;
        final entryCount = execCodePool!.readUint16(tableAddr);

        for (var i = 0; i < entryCount; i++) {
          final entryAddr = tableAddr + 2 + (i * 10);
          final startOfs = execCodePool!.readUint16(entryAddr);
          final endOfs = execCodePool!.readUint16(entryAddr + 2);
          final exceptionClass = execCodePool!.readUint32(entryAddr + 4);
          final handlerOfs = execCodePool!.readUint16(entryAddr + 8);

          if (currentOffset >= startOfs && currentOffset <= endOfs) {
            if (exceptionClass == 0 || checkIsInstanceOf(exceptionObjId, exceptionClass)) {
              return ep + handlerOfs;
            }
          }
        }
      }

      if (execStack.depth <= 10) return null;

      final (returnAddr, oldFp, entryPtr) = execStack.popFrame();
      execRegisters.ip = returnAddr;
      execRegisters.ep = entryPtr;

      if (returnAddr == 0) return null;
    }
  }

  /// Checks if an object is an instance of (or inherits from) a class.
  bool checkIsInstanceOf(int objId, int classId) {
    if (objId == classId) return true;
    final obj = execObjectTable.lookup(objId);
    if (obj == null) return false;
    if (obj is T3TadsObject) {
      for (final superclassId in obj.superclasses) {
        if (checkIsInstanceOf(superclassId, classId)) return true;
      }
    }
    return false;
  }

  // ==================== Function Calls ====================

  /// Calls a function at the given code pool offset.
  void execCallFunction(
    int codeOffset,
    int argc, {
    T3Value? self,
    T3Value? targetObj,
    T3Value? definingObj,
    int? propId,
  }) {
    final headerBytes = execCodePool!.readBytes(codeOffset, methodHeaderSize);
    final header = T3FunctionHeader.parse(headerBytes);

    final maxArgs = header.minArgs + header.optionalArgc;
    if (!header.isVarargs && (argc < header.minArgs || argc > maxArgs)) {
      throw T3Exception(
        'Argument count mismatch at 0x${codeOffset.toRadixString(16)}: '
        'expected ${header.minArgs}-$maxArgs, got $argc',
      );
    }
    if (header.isVarargs && argc < header.minArgs) {
      throw T3Exception(
        'Varargs count mismatch at 0x${codeOffset.toRadixString(16)}: '
        'expected at least ${header.minArgs}, got $argc',
      );
    }

    final actualArgc = argc < maxArgs ? maxArgs : argc;
    for (var i = argc; i < actualArgc; i++) {
      execStack.push(T3Value.nil());
    }

    execStack.pushFrame(
      argCount: actualArgc,
      localCount: header.localCount,
      returnAddr: execRegisters.ip,
      entryPtr: execRegisters.ep,
      self: self ?? T3Value.nil(),
      targetObj: targetObj ?? T3Value.nil(),
      definingObj: definingObj ?? T3Value.nil(),
      targetProp: propId ?? 0,
      invokee: targetObj ?? T3Value.nil(),
    );

    execRegisters.ip = codeOffset + methodHeaderSize;
    execRegisters.ep = codeOffset;
  }

  /// Handles function return.
  T3ExecutionResult doReturn() {
    if (execStack.fp == 0) return T3ExecutionResult.quit;

    final (returnAddr, oldFp, entryPtr) = execStack.popFrame();
    execRegisters.ip = returnAddr;
    execRegisters.ep = entryPtr;

    if (oldFp == 0) return T3ExecutionResult.quit;
    return T3ExecutionResult.continue_;
  }

  // ==================== Property Evaluation ====================

  /// Evaluates a property on a target object.
  void execEvalProperty(T3Value target, int propId, {int? argc}) {
    switch (target.type) {
      case T3DataType.obj:
        final result = execObjectTable.lookupProperty(target.value, propId);
        if (result == null) {
          final propUndefId = getSymbolPropertyId('propNotDefined');
          if (propUndefId != null && propUndefId != propId) {
            final undefResult = execObjectTable.lookupProperty(target.value, propUndefId);
            if (undefResult != null) {
              final actualArgCount = argc ?? 0;
              execStack.insertAt(actualArgCount, T3Value.fromProp(propId));
              execEvalProperty(target, propUndefId, argc: actualArgCount + 1);
              return;
            }
          }
          if (argc != null && argc > 0) execStack.discard(argc);
          execRegisters.r0 = T3Value.nil();
          return;
        }

        final propVal = result.value;
        switch (propVal.type) {
          case T3DataType.codeofs:
          case T3DataType.funcptr:
            if (argc == null) {
              execRegisters.r0 = propVal;
              return;
            }
            execCallFunction(
              propVal.value,
              argc,
              self: target,
              targetObj: target,
              definingObj: T3Value.fromObject(result.definingObjectId),
              propId: propId,
            );
            return;

          case T3DataType.dstring:
            if (argc != null && argc > 0) {
              throw T3Exception('Arguments not allowed for dstring property');
            }
            execRegisters.r0 = propVal;
            break;

          default:
            if (argc != null && argc > 0) {
              throw T3Exception('Arguments not allowed for data property of type ${propVal.type}');
            }
            execRegisters.r0 = propVal;
            break;
        }
        break;

      case T3DataType.nil:
        throw T3Exception('Nil dereference: attempted to get property $propId of nil');

      case T3DataType.sstring:
        handleIntrinsic(execStringMetaclassIdx, target, propId, argc);
        break;

      case T3DataType.list:
        handleIntrinsic(execListMetaclassIdx, target, propId, argc);
        break;

      default:
        throw T3Exception('Cannot get property of ${target.type}');
    }
  }

  /// Handles property access on intrinsic types (string, list).
  void handleIntrinsic(int? metaclassIdx, T3Value target, int propId, int? argc) {
    if (metaclassIdx == null || execMetaclasses == null) {
      execRegisters.r0 = T3Value.nil();
      return;
    }

    final dep = execMetaclasses?.byIndex(metaclassIdx);
    if (dep != null) {
      final funcIdx = dep.propertyIds.indexOf(propId);
      if (funcIdx >= 0) {
        if (dep.name == 'string') {
          handleStringIntrinsic(funcIdx, target, argc);
          return;
        } else if (dep.name == 'list') {
          handleListIntrinsic(funcIdx, target, argc);
          return;
        }
      }
    }

    final placeholderName = target.type == T3DataType.sstring ? '*ConstStrObj' : '*ConstLstObj';
    final placeholder = execSymbols[placeholderName];
    if (placeholder != null && placeholder.type == T3DataType.obj) {
      execEvalProperty(placeholder, propId, argc: argc);
      return;
    }

    if (argc != null && argc > 0) execStack.discard(argc);
    execRegisters.r0 = T3Value.nil();
  }

  void handleStringIntrinsic(int funcIdx, T3Value target, int? argc) {
    if (funcIdx == 0) {
      if (argc != null && argc > 0) execStack.discard(argc);
      int length;
      if (execDynamicStrings.containsKey(target.value)) {
        length = execDynamicStrings[target.value]!.length;
      } else {
        length = execConstantPool!.readString(target.value).length;
      }
      execRegisters.r0 = T3Value.fromInt(length);
      return;
    }
    if (argc != null && argc > 0) execStack.discard(argc);
    execRegisters.r0 = T3Value.nil();
  }

  void handleListIntrinsic(int funcIdx, T3Value target, int? argc) {
    if (funcIdx == 2) {
      if (argc != null && argc > 0) execStack.discard(argc);
      int length;
      if (execDynamicLists.containsKey(target.value)) {
        length = execDynamicLists[target.value]!.length;
      } else {
        length = execConstantPool!.readList(target.value).length;
      }
      execRegisters.r0 = T3Value.fromInt(length);
      return;
    }
    if (argc != null && argc > 0) execStack.discard(argc);
    execRegisters.r0 = T3Value.nil();
  }

  /// Gets a property ID from the symbol table by name.
  int? getSymbolPropertyId(String name) {
    final val = execSymbols[name];
    if (val != null && val.type == T3DataType.prop) return val.value;
    return null;
  }

  // ==================== Inheritance ====================

  /// Inherits a property from the superclass.
  void inheritProperty(int propId, int argc) {
    final self = execStack.getSelf();
    if (!self.isObject) {
      throw T3Exception('INHERIT: no self object');
    }

    final defObj = execStack.getDefiningObject();
    if (!defObj.isObject) {
      final selfObj = execObjectTable.lookup(self.value);
      if (selfObj is T3TadsObject && selfObj.superclasses.isNotEmpty) {
        execEvalProperty(T3Value.fromObject(selfObj.superclasses.first), propId, argc: argc);
      } else {
        if (argc > 0) execStack.discard(argc);
        execRegisters.r0 = T3Value.nil();
      }
    } else {
      final defObjInst = execObjectTable.lookup(defObj.value);
      if (defObjInst is T3TadsObject && defObjInst.superclasses.isNotEmpty) {
        execEvalProperty(T3Value.fromObject(defObjInst.superclasses.first), propId, argc: argc);
      } else {
        if (argc > 0) execStack.discard(argc);
        execRegisters.r0 = T3Value.nil();
      }
    }
  }

  // ==================== Builtins ====================

  /// Calls a built-in function.
  void execCallBuiltin(int setIdx, int funcIdx, int argc) {
    final funcSet = execFunctionSets?.byIndex(setIdx);
    final setName = funcSet?.name ?? 'unknown-$setIdx';

    // Note: T3BuiltinRegistry.getFunction requires the interpreter instance
    // This will be provided via an indirect reference
    final func = getBuiltinFunction(setName, funcIdx);
    if (func != null) {
      func(argc);
      return;
    }

    if (argc > 0) execStack.discard(argc);
    execRegisters.r0 = T3Value.nil();
    // ignore: avoid_print
    print('Warning: Built-in $setName[$funcIdx] not implemented');
  }

  /// Gets a builtin function - implemented by T3Interpreter
  void Function(int argc)? getBuiltinFunction(String setName, int funcIdx);

  // ==================== Output ====================

  /// Invokes SAY handler for the given value.
  void invokeSay(T3Value val) {
    if (val.isString) {
      processOutputText(getStringValue(val));
      return;
    }

    final self = execStack.getSelf();
    if (execSayMethod != 0 && !self.isNil) {
      // TODO: proper property lookup
    }

    if (!execSayFunc.isNil) {
      execStack.push(val);
      callFunctionPointer(execSayFunc, 1);
      return;
    }

    printValue(val);
  }

  /// Calls a function pointer.
  void callFunctionPointer(T3Value func, int argc);

  /// Processes output text with basic HTML tag filtering.
  void processOutputText(String text) {
    var currentIndex = 0;
    while (currentIndex < text.length) {
      final tagStart = text.indexOf('<', currentIndex);
      if (tagStart == -1) {
        if (execOutputIgnoreDepth == 0) {
          printRaw(text.substring(currentIndex));
        }
        break;
      }

      if (tagStart > currentIndex && execOutputIgnoreDepth == 0) {
        printRaw(text.substring(currentIndex, tagStart));
      }

      final tagEnd = text.indexOf('>', tagStart);
      if (tagEnd == -1) {
        if (execOutputIgnoreDepth == 0) {
          printRaw(text.substring(tagStart));
        }
        break;
      }

      final tagContent = text.substring(tagStart + 1, tagEnd).trim().toLowerCase();
      final isEndTag = tagContent.startsWith('/');
      final tagName = isEndTag ? tagContent.substring(1).trim() : tagContent.split(RegExp(r'\s+'))[0];

      if (tagName == 'aboutbox' || tagName == 'title') {
        if (isEndTag) {
          execOutputIgnoreDepth = (execOutputIgnoreDepth > 0) ? execOutputIgnoreDepth - 1 : 0;
        } else {
          execOutputIgnoreDepth++;
        }
      }

      currentIndex = tagEnd + 1;
    }
  }

  /// Prints a T3 value to the console.
  void printValue(T3Value val) {
    if (execOutputIgnoreDepth > 0) return;
    printRaw(getStringValue(val));
  }

  /// Raw print to console.
  void printRaw(String text) {
    if (text.isEmpty) return;
    // ignore: avoid_print
    stdout.write(text);
  }

  /// Gets the string representation of a value.
  String getStringValue(T3Value val) {
    if (val.isStringLike) {
      if (val.data is Uint8List) {
        return T3Utf8.decode(val.data as Uint8List);
      }
      final offset = val.value;
      if (offset >= 0x80000000) {
        return execDynamicStrings[offset] ?? '';
      } else {
        return execConstantPool!.readString(offset);
      }
    } else if (val.isInt) {
      return val.value.toString();
    } else if (val.isNil) {
      return '';
    } else if (val.isList) {
      final elements = getExecListValues(val);
      final buffer = StringBuffer()..write('[');
      for (var i = 0; i < elements.length; i++) {
        if (i > 0) buffer.write(' ');
        buffer.write(getStringValue(elements[i]));
      }
      buffer.write(']');
      return buffer.toString();
    }
    return '';
  }

  /// Gets list values (handles dynamic and pool lists).
  List<T3Value> getExecListValues(T3Value listVal) {
    if (!listVal.isList) return [];
    if (execDynamicLists.containsKey(listVal.value)) {
      return execDynamicLists[listVal.value]!;
    }
    return execConstantPool!.readList(listVal.value);
  }
}
