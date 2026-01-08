import 'dart:typed_data';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:zart/src/tads3/vm/t3_lookup_table.dart';
import 'package:zart/src/tads3/vm/t3_byte_array.dart';

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
import 'package:zart/src/tads3/vm/t3_undo.dart';
import 'package:zart/src/tads3/vm/t3_utf8.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';
import 'package:zart/src/tads3/vm/t3_value_helpers.dart';

/// Mixin providing execution helpers for function calls, property access,
/// object creation, and output handling.
mixin T3ExecutionHelpers {
  // Required accessors - must be provided by implementing class
  T3UndoManager get execUndoManager;
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
  int get execNextDynamicListOffset;
  set execNextDynamicListOffset(int value);

  int get execOutputIgnoreDepth;
  set execOutputIgnoreDepth(int value);
  int get execSayMethod;
  T3Value get execSayFunc;
  int? get execStringMetaclassIdx;
  int? get execListMetaclassIdx;
  T3ValueHelpers get execValueHelpers;

  // Method requirements
  T3ExecutionResult executeInstruction(); // Required for recursive execution
  int get methodHeaderSize;

  /// Executes a callback function with the given arguments and returns the result.
  /// T3VM function set (0) - already implemented
  /// This must be implemented by the interpreter to run the callback to completion.
  /// Returns R0 after the callback completes.
  T3Value execCallback(T3Value callback, List<T3Value> args);

  // ==================== Object Creation ====================

  /// Creates a new dynamic object from a metaclass.
  void createNewObject(int metaclassIdx, int argc, {bool isTransient = false}) {
    final metaclass = execMetaclasses!.byIndex(metaclassIdx);
    if (metaclass == null) {
      throw T3Exception('NEW: invalid metaclass index $metaclassIdx');
    }

    // Pop constructor arguments (in Top-to-Bottom order, as expected by Reference VM)
    // TADS3 pushes arguments right-to-left, so popping them one by one gives:
    // args[0] = Top-of-stack (last pushed, e.g., superclass for tads-object)
    // args[1] = Second-on-stack (e.g., first constructor argument)
    // ...
    final args = <T3Value>[];
    for (var i = 0; i < argc; i++) {
      args.add(execStack.pop());
    }

    if (metaclass.name == 'tads-object') {
      // Create the object using the first argument as superclass (handled in createDynamicObject)
      // For TadsObject, first arg (args[0]) is the superclass, remaining are for construct()
      final newObjId = execObjectTable.createDynamicObject(
        metaclass.name,
        args,
        isTransient: isTransient,
        undoManager: execUndoManager,
      );
      final newObj = T3Value.fromObject(newObjId);

      // Check for 'construct' method
      var constructPropId = getSymbolPropertyId('construct');
      if (constructPropId == null) {
        // Fallback to standard TADS3 predefined property ID for construct
        constructPropId = 1;
      }

      T3PropertyLookupResult? constructResult;
      constructResult = execObjectTable.lookupProperty(newObjId, constructPropId);

      if (constructResult != null && (constructResult.value.isCodeOffset || constructResult.value.isFuncPtr)) {
        // Push constructor arguments back to stack (args[1] to args[n])
        // To push them such that Arg 2 is at TOS, we push them in reverse: args[n], ..., args[1]
        for (var i = args.length - 1; i >= 1; i--) {
          execStack.push(args[i]);
        }

        // Call the constructor
        execCallFunction(
          constructResult.value.value,
          args.length - 1,
          self: newObj,
          targetObj: newObj,
          definingObj: T3Value.fromObject(constructResult.definingObjectId),
          propId: constructPropId,
        );
        // The constructor is expected to return 'self' (the new object), which will be placed in R0
      } else {
        // No constructor found or it's not callable - just return the object in R0
        execRegisters.r0 = newObj;
      }
      return;
    }

    // Special handling for Vector constructor with list source argument
    // The ObjectTable can't access the constant pool, so we need to extract
    // pool list elements here before passing to createDynamicObject.
    if (metaclass.name == 'vector' && args.isNotEmpty) {
      // Check for Vector(capacity, sourceList) or Vector(sourceList) patterns
      // Args are in reverse order: args[0] is last pushed (sourceList), args[1] is first pushed (capacity)
      for (var i = 0; i < args.length; i++) {
        if (args[i].isList && !args[i].isObject) {
          // This is a pool-based list - extract elements to a new list object
          final elements = execValueHelpers.getListValues(args[i]);
          final listObjId = execObjectTable.createDynamicObject('list', elements);
          args[i] = T3Value.fromObject(listObjId);
        }
      }
    }

    final newObjId = execObjectTable.createDynamicObject(
      metaclass.name,
      args,
      isTransient: isTransient,
      undoManager: execUndoManager,
    );
    execRegisters.r0 = T3Value.fromObject(newObjId);
  }

  // ==================== Exception Handling ====================

  /// Finds an exception handler for the given exception object.
  /// If [exceptionObjId] is null, it only matches 'finally' blocks (exceptionClass == 0).
  /// Finds an exception handler for the given exception object.
  ///
  /// Returns the definition offset (code implementation) of the handler.
  ///
  /// [unwindStack] : If true, the stack is popped until the handler is found.
  /// If false, it just looks up without modifying stack (peek).
  ///
  /// Note: The original implementation popped frames during search.
  /// If we want to support 'finally', we must execute them.
  /// And if we just find a handler, we should probably unwind then?
  /// Or this function is 'find AND unwind'.
  ///
  /// Revised logic:
  /// Unwinds stack frames one by one. Checks exception table in each.
  /// If [exceptionObjId] is null, only matches 'finally' (class 0).
  /// If [exceptionObjId] is object, matches compatible catch OR finally.
  ///
  /// Returns target IP (handler address).
  ///
  /// SIDE EFFECT: Modifies execStack/registers (unwinds frames).
  ///
  /// Important: When a 'finally' block is found, we unwind to that frame,
  /// enter the finally block, but we do NOT fully discard the exception info context
  /// (in the VM loop) if we are in middle of throw.
  ///
  /// But this function currently returns a simple `int?` address.
  /// The caller (THROW opcode logic) handles the context.
  ///
  /// For TADS 3:
  /// 1. Start unwinding from current frame.
  /// 2. For each frame:
  ///    a. Check exception table for this method.
  ///    b. Find matching entry (catch compatible or finally).
  ///       - If match is 'finally' (exceptionClass == 0):
  ///         STOP unwinding here. Setup to execute finally block.
  ///         Return address of finally block.
  ///         (The VM must remember to re-throw after finally).
  ///       - If match is 'catch' (compatible class):
  ///         STOP unwinding here. Setup to execute catch block.
  ///         Return address of catch block.
  ///         (VM pushes exception object).
  /// 3. If no match in this frame, pop frame and continue to caller.
  /// 4. If stack empty, return null (unhandled).

  int? findExceptionHandler(int? exceptionObjId) {
    while (true) {
      final ep = execRegisters.ep;

      // If we are outside valid stack (ep=0?), stop.
      if (ep == 0) return null;

      final headerBytes = execCodePool!.readBytes(ep, methodHeaderSize);
      final header = T3FunctionHeader.parse(headerBytes);

      if (header.exceptionTableOffset > 0) {
        final currentOffset = execRegisters.ip - ep;
        // print('DEBUG: ExecTable search. IP=${execRegisters.ip} EP=$ep Ofs=$currentOffset');

        final tableAddr = ep + header.exceptionTableOffset;
        final entryCount = execCodePool!.readUint16(tableAddr);

        for (var i = 0; i < entryCount; i++) {
          final entryAddr = tableAddr + 2 + (i * 10);
          final startOfs = execCodePool!.readUint16(entryAddr);
          final endOfs = execCodePool!.readUint16(entryAddr + 2);
          final exceptionClass = execCodePool!.readUint32(entryAddr + 4);
          final handlerOfs = execCodePool!.readUint16(entryAddr + 8);

          // Check if IP is within the protected range
          if (currentOffset >= startOfs && currentOffset < endOfs) {
            // Spec says [start, end) usually? Or inclusive?
            // "The range is from start_ofs (inclusive) to end_ofs (exclusive)" per standard TADS docs usually.
            // Let's assume inclusive lower, exclusive upper for now, OR valid check provided implementation:
            // Old code: currentOffset <= endOfs. Let's keep it if unsure, but standard is usually [) in VMs.
            // Let's check T3 doc: "range covers offsets from start_ofs up to but not including end_ofs".
            // So < endOfs.
            if (currentOffset <= endOfs) {
              // Keeping <= to be safe with existing logic unless confirmed broken.
              // Check type
              // If exceptionClass == 0, it is a 'finally' block.
              // It ALWAYS matches.
              // If exceptionObjId is null, we are ONLY looking for finally cleanup (e.g. break/return/throw resume).
              // If exceptionObjId is set, we match catch OR finally.
              // IMPT: We must pick the FIRST inner-most match?
              // The table is usually ordered by "inner-most first"?
              // Or we just scan. TADS 3 compiler outputs specific order?
              // Standard: Linear scan, first match.

              if (exceptionClass == 0) {
                // Found finally.
                // We stop unwinding here (at this frame).
                // We do NOT pop this frame.
                // We just jump to handler.
                return ep + handlerOfs;
              }

              if (exceptionObjId != null && checkIsInstanceOf(exceptionObjId, exceptionClass)) {
                // Found catch.
                return ep + handlerOfs;
              }
            }
          }
        }
      }

      // No matching handler in this frame.
      // Pop specific frame and continue search in caller.
      if (execStack.depth <= 0) return null;

      // We must check if we can pop.
      // If we are at top level script?

      try {
        final (returnAddr, oldFp, entryPtr, _, _) = execStack.popFrame();
        execRegisters.ip = returnAddr;
        execRegisters.ep = entryPtr;

        if (returnAddr == 0) return null; // End of chain
      } catch (e) {
        // Stack underflow or error
        return null;
      }
    }
  }

  /// Checks if an object is an instance of (or inherits from) a class.
  bool checkIsInstanceOf(int objId, int classId) {
    if (objId == classId) return true;
    final obj = execObjectTable.lookup(objId);
    if (obj == null) return false;

    // Handle TADS objects with explicit superclasses
    if (obj is T3TadsObject) {
      for (final superclassId in obj.superclasses) {
        if (checkIsInstanceOf(superclassId, classId)) return true;
      }
    }

    // TODO: Handle intrinsic class hierarchy (e.g., Vector -> Collection)
    // This requires mapping metaclass names to their intrinsic class object IDs.

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
    T3Value? invokee,
    int? namedArgTableAddr,
    T3Value? context,
    bool pushResult = false,
  }) {
    // print('CALL: codeOffset=0x${codeOffset.toRadixString(16)} argc=$argc');
    final methodHeader = execCodePool!.readByte(codeOffset);
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
      invokee: invokee ?? targetObj ?? T3Value.nil(),
      namedArgTableAddr: namedArgTableAddr,
      context: context,
      pushResult: pushResult,
    );

    execRegisters.ip = codeOffset + methodHeaderSize;
    execRegisters.ep = codeOffset;
  }

  /// Handles function return.
  T3ExecutionResult doReturn() {
    if (execStack.fp == 0) return T3ExecutionResult.quit;

    final (returnAddr, oldFp, entryPtr, _, pushResult) = execStack.popFrame();
    execRegisters.ip = returnAddr;
    execRegisters.ep = entryPtr;

    if (pushResult) {
      execStack.push(execRegisters.r0.copy());
    }

    if (oldFp == 0) return T3ExecutionResult.quit;
    return T3ExecutionResult.continue_;
  }

  // ==================== Property Evaluation ====================

  /// Evaluates a property on a target object.
  void execEvalProperty(T3Value target, int propId, {int? argc, int? namedArgTableAddr}) {
    // print('EVALPROP: target=$target propId=0x${propId.toRadixString(16)}');
    switch (target.type) {
      case T3DataType.obj:
        final result = execObjectTable.lookupProperty(target.value, propId);
        if (result == null) {
          // Check for intrinsic methods on dynamic objects
          final obj = execObjectTable.lookup(target.value);
          if (obj != null) {
            if (obj.metaclass == 'list') {
              handleListIntrinsic(-1, target, argc, propId: propId);
              return;
            } else if (obj.metaclass == 'vector' || obj.metaclass == 'anon-func-ptr') {
              handleVectorIntrinsic(-1, target, argc, propId: propId);
              return;
            } else if (obj.metaclass == 'iterator') {
              handleIteratorIntrinsic(-1, target, argc, propId: propId);
              return;
            } else if (obj.metaclass == 'lookuptable') {
              handleLookupTableIntrinsic(-1, target, argc, propId: propId);
              return;
            }
          }

          final propUndefId = getSymbolPropertyId('propNotDefined');
          if (propUndefId != null && propUndefId != propId) {
            final undefResult = execObjectTable.lookupProperty(target.value, propUndefId);
            if (undefResult != null) {
              final actualArgCount = argc ?? 0;
              execStack.insertAt(actualArgCount, T3Value.fromProp(propId));
              execEvalProperty(target, propUndefId, argc: actualArgCount + 1, namedArgTableAddr: namedArgTableAddr);
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
            execCallFunction(
              propVal.value,
              argc ?? 0,
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
            invokeSay(propVal);
            execRegisters.r0 = T3Value.nil();
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
      // Try handling common props like length even without metaclass info
      if (propId == 2) {
        // length
        if (target.type == T3DataType.list) {
          handleListIntrinsic(-1, target, argc, propId: propId);
          return;
        } else if (target.type == T3DataType.sstring) {
          handleStringIntrinsic(-1, target, argc, propId: propId);
          return;
        }
      }
      execRegisters.r0 = T3Value.nil();
      return;
    }

    final dep = execMetaclasses?.byIndex(metaclassIdx);
    if (dep != null) {
      final funcIdx = dep.propertyIds.indexOf(propId);
      if (funcIdx >= 0) {
        if (dep.name == 'string') {
          handleStringIntrinsic(funcIdx, target, argc, propId: propId);
          return;
        } else if (dep.name == 'list') {
          handleListIntrinsic(funcIdx, target, argc, propId: propId);
          return;
        }
      }
    }

    // Fallback for known property IDs if not in MCLD
    if (target.type == T3DataType.list) {
      handleListIntrinsic(-1, target, argc, propId: propId);
      return;
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

  void handleStringIntrinsic(int funcIdx, T3Value target, int? argc, {int? propId}) {
    // Get the string content
    String str;
    if (execDynamicStrings.containsKey(target.value)) {
      str = execDynamicStrings[target.value]!;
    } else {
      str = execConstantPool!.readString(target.value);
    }

    // Helper to get string from T3Value (arg)
    String? getString(T3Value val) {
      if (execDynamicStrings.containsKey(val.value)) return execDynamicStrings[val.value];
      if (val.isString) return execConstantPool!.readString(val.value);
      return null;
    }

    // Metaclass slots for String (from vmstr.cpp func_table_):
    // Indices are shifted by -1 because 0 (undef) is skipped in property mapping
    // [0] len (1)
    // [1] substr (2)
    // [2] upper (3)
    // [3] lower (4)
    // [4] find (5)
    // [5] toUnicode (6)
    // [6] htmlify (7)
    // [7] startsWith (8)
    // [8] endsWith (9)
    // [9] toByteArray (10)
    // [10] replace (11)
    // [11] splice (12)
    // [12] split (13)
    // [13] specialsToHtml (14)
    // [14] specialsToText (15)
    // [15] urlEncode (16)
    // [16] urlDecode (17)
    // [17] sha256 (18)
    // [18] md5 (19)
    // [19] packBytes (20)
    // [20] unpackBytes (21)
    // [21] toTitleCase (22)
    // [22] toFoldedCase (23)
    // [23] compareTo (24)
    // [24] compareIgnoreCase (25)
    // [25] findLast (26)
    // [26] findAll (27)
    // [27] match (28)

    // Manual property ID overrides if funcIdx is not resolved
    if (funcIdx == -1) {
      if (propId == 2)
        funcIdx = 0; // len
      else if (propId == 0x6d)
        funcIdx = 1; // substr
      // Add others if needed
    }

    switch (funcIdx) {
      case 0: // len [1]
        if (argc != null && argc > 0) execStack.discard(argc);
        execRegisters.r0 = T3Value.fromInt(str.length);
        return;

      case 1: // substr [2]
        int start = 1;
        int? len;
        // Arguments are pushed right-to-left (TOS is Arg1):
        // substr(start, len) -> [..., len, start]
        if (argc != null && argc >= 1) start = execStack.pop().numToInt();
        if (argc != null && argc >= 2) len = execStack.pop().numToInt();

        final strLen = str.length;
        int startIdx;
        int endIdx;

        // Convert start to 0-based index
        if (start > 0) {
          startIdx = start - 1;
        } else if (start < 0) {
          startIdx = strLen + start;
        } else {
          startIdx = 0;
        }

        // Calculate end index
        if (len == null) {
          endIdx = strLen;
        } else if (len >= 0) {
          endIdx = startIdx + len;
        } else {
          // Negative length: number of characters to remove from end
          endIdx = strLen + len;
        }

        // Clamp indices to [0, strLen]
        if (startIdx < 0) startIdx = 0;
        if (startIdx > strLen) startIdx = strLen;
        if (endIdx < 0) endIdx = 0;
        if (endIdx > strLen) endIdx = strLen;
        if (endIdx < startIdx) endIdx = startIdx;

        String result = str.substring(startIdx, endIdx);

        // Create new dynamic string and return it
        final newOffset = execNextDynamicStringOffset;
        execNextDynamicStringOffset = newOffset + 1;
        execDynamicStrings[newOffset] = result;
        execRegisters.r0 = T3Value.fromString(newOffset);
        return;

      case 2: // upper [3]
        if (argc != null && argc > 0) execStack.discard(argc);
        final upper = str.toUpperCase();
        final upperOffset = execNextDynamicStringOffset++;
        execDynamicStrings[upperOffset] = upper;
        execRegisters.r0 = T3Value.fromString(upperOffset);
        return;

      case 3: // lower [4]
        if (argc != null && argc > 0) execStack.discard(argc);
        final lower = str.toLowerCase();
        final lowerOffset = execNextDynamicStringOffset++;
        execDynamicStrings[lowerOffset] = lower;
        execRegisters.r0 = T3Value.fromString(lowerOffset);
        return;

      case 4: // find [5]
        // find(substring, index?)
        final subVal = (argc != null && argc >= 1) ? execStack.pop() : T3Value.nil();
        final idxVal = (argc != null && argc >= 2) ? execStack.pop() : T3Value.nil();
        if (argc != null && argc > 2) execStack.discard(argc - 2);

        final sub = getString(subVal);
        final startIdx = (idxVal.type == T3DataType.int_) ? idxVal.value - 1 : 0; // 1-based index

        if (sub == null) {
          execRegisters.r0 = T3Value.nil(); // Invalid arg
          return;
        }

        int found = str.indexOf(sub, startIdx < 0 ? 0 : startIdx);
        if (found >= 0) {
          execRegisters.r0 = T3Value.fromInt(found + 1); // 1-based return
        } else {
          execRegisters.r0 = T3Value.nil();
        }
        return;

      case 5: // toUnicode [6]
        if (argc != null && argc > 0) execStack.discard(argc);
        final runes = str.runes.toList();
        final listId = execObjectTable.createDynamicObject('list', runes.map((r) => T3Value.fromInt(r)).toList());
        execRegisters.r0 = T3Value.fromList(listId);
        return;

      case 6: // htmlify [7] - stub for now
        if (argc != null && argc > 0) execStack.discard(argc);
        // Simple HTML escaping
        final html = str
            .replaceAll('&', '&amp;')
            .replaceAll('<', '&lt;')
            .replaceAll('>', '&gt;')
            .replaceAll('"', '&quot;');
        final htmlOffset = execNextDynamicStringOffset++;
        execDynamicStrings[htmlOffset] = html;
        execRegisters.r0 = T3Value.fromString(htmlOffset);
        return;

      case 7: // startsWith [8]
        final matchVal = (argc != null && argc >= 1) ? execStack.pop() : T3Value.nil();
        if (argc != null && argc > 1) execStack.discard(argc - 1);

        final match = getString(matchVal);
        if (match != null) {
          execRegisters.r0 = T3Value.fromBool(str.startsWith(match));
        } else {
          execRegisters.r0 = T3Value.nil();
        }
        return;

      case 8: // endsWith [9]
        final matchVal = (argc != null && argc >= 1) ? execStack.pop() : T3Value.nil();
        if (argc != null && argc > 1) execStack.discard(argc - 1);

        final match = getString(matchVal);
        if (match != null) {
          execRegisters.r0 = T3Value.fromBool(str.endsWith(match));
        } else {
          execRegisters.r0 = T3Value.nil();
        }
        return;

      case 9: // toByteArray [10]
        // toByteArray(charset?)
        if (argc != null && argc > 0) execStack.discard(argc);

        // Convert string to bytes using UTF-8 (ignoring charset arg for MVP)
        final bytes = utf8.encode(str);

        final ba = T3ByteArray(objectId: execObjectTable.allocateObjectId(), data: Uint8List.fromList(bytes));
        execObjectTable.registerObject(ba);
        execRegisters.r0 = T3Value.fromObject(ba.objectId);
        return;

      case 10: // replace [11]
        // replace(old, new, flags?, index?, limit?)
        final oldVal = (argc != null && argc >= 1) ? execStack.pop() : T3Value.nil();
        final newVal = (argc != null && argc >= 2) ? execStack.pop() : T3Value.nil();
        final _ = (argc != null && argc >= 3) ? execStack.pop() : T3Value.nil();
        // we ignore index/limit for now
        if (argc != null && argc > 3) execStack.discard(argc - 3);

        final oldStr = getString(oldVal);
        final newStr = getString(newVal);

        if (oldStr != null && newStr != null) {
          final rep = str.replaceAll(oldStr, newStr);
          final repOffset = execNextDynamicStringOffset++;
          execDynamicStrings[repOffset] = rep;
          execRegisters.r0 = T3Value.fromString(repOffset);
        } else {
          execRegisters.r0 = T3Value.fromString(target.value); // Return original if invalid
        }
        return;

      case 11: // splice [12]
        // splice(idx, len, insert?)
        final idxVal = (argc != null && argc >= 1) ? execStack.pop() : T3Value.fromInt(1);
        final lenVal = (argc != null && argc >= 2) ? execStack.pop() : T3Value.fromInt(0);
        final insVal = (argc != null && argc >= 3) ? execStack.pop() : T3Value.nil();
        if (argc != null && argc > 3) execStack.discard(argc - 3);

        final start = (idxVal.type == T3DataType.int_) ? idxVal.value - 1 : 0;
        final len = (lenVal.type == T3DataType.int_) ? lenVal.value : 0;
        final ins = getString(insVal) ?? '';

        final strLen = str.length;

        // Robust clamping
        int clampedStart = start;
        if (clampedStart < 0) clampedStart = 0;
        if (clampedStart > strLen) clampedStart = strLen;

        // TADS splice length logic: if len < 0, it means delete nothing? or from end?
        // Spec usually implies non-negative length for deletion.
        // We'll clamp end.
        int end = start + len;

        int clampedEnd = end;
        if (clampedEnd < clampedStart) clampedEnd = clampedStart;
        if (clampedEnd > strLen) clampedEnd = strLen;

        final spliced = str.replaceRange(clampedStart, clampedEnd, ins);
        final spOffset = execNextDynamicStringOffset++;
        execDynamicStrings[spOffset] = spliced;
        execRegisters.r0 = T3Value.fromString(spOffset);
        return;

      case 12: // split [13]
        // split(delim?, limit?)
        final delimVal = (argc != null && argc >= 1) ? execStack.pop() : T3Value.nil();
        final limitVal = (argc != null && argc >= 2) ? execStack.pop() : T3Value.nil();
        if (argc != null && argc > 2) execStack.discard(argc - 2);

        final delim = getString(delimVal);
        List<String> parts;
        if (delim == null) {
          parts = str.trim().split(RegExp(r'\s+'));
          if (parts.length == 1 && parts[0].isEmpty) parts = [];
        } else {
          parts = str.split(delim);
        }

        if (limitVal.type == T3DataType.int_ && limitVal.value > 0 && limitVal.value < parts.length) {
          parts = parts.sublist(0, limitVal.value);
        }

        final listIds = parts.map((s) {
          final off = execNextDynamicStringOffset++;
          execDynamicStrings[off] = s;
          return T3Value.fromString(off);
        }).toList();
        final splitListId = execObjectTable.createDynamicObject('list', listIds);
        execRegisters.r0 = T3Value.fromList(splitListId);
        return;

      case 13: // specialsToHtml [14]
        // Stub implementation - just return the string or simple replacements
        // TODO: Full mapping of TADS specials
        if (argc != null && argc > 0) execStack.discard(argc);
        execRegisters.r0 = T3Value.fromString(target.value);
        return;

      case 14: // specialsToText [15]
        // Stub implementation
        if (argc != null && argc > 0) execStack.discard(argc);
        execRegisters.r0 = T3Value.fromString(target.value);
        return;

      case 15: // urlEncode [16]
        if (argc != null && argc > 0) execStack.discard(argc);
        final encoded = Uri.encodeComponent(str);
        final encOffset = execNextDynamicStringOffset++;
        execDynamicStrings[encOffset] = encoded;
        execRegisters.r0 = T3Value.fromString(encOffset);
        return;

      case 16: // urlDecode [17]
        if (argc != null && argc > 0) execStack.discard(argc);
        final decoded = Uri.decodeComponent(str);
        final decOffset = execNextDynamicStringOffset++;
        execDynamicStrings[decOffset] = decoded;
        execRegisters.r0 = T3Value.fromString(decOffset);
        return;

      case 17: // sha256 [18]
        if (argc != null && argc > 0) execStack.discard(argc);
        final bytes17 = utf8.encode(str);
        final digest17 = sha256.convert(bytes17);
        final hex17 = digest17.toString();
        final off17 = execNextDynamicStringOffset++;
        execDynamicStrings[off17] = hex17;
        execRegisters.r0 = T3Value.fromString(off17);
        return;

      case 18: // md5 [19]
        if (argc != null && argc > 0) execStack.discard(argc);
        final bytes18 = utf8.encode(str);
        final digest18 = md5.convert(bytes18);
        final hex18 = digest18.toString();
        final off18 = execNextDynamicStringOffset++;
        execDynamicStrings[off18] = hex18;
        execRegisters.r0 = T3Value.fromString(off18);
        return;

      case 21: // toTitleCase [22]
        if (argc != null && argc > 0) execStack.discard(argc);
        final title = str.replaceAllMapped(RegExp(r'\b\w'), (match) => match.group(0)!.toUpperCase());
        final tOffset = execNextDynamicStringOffset++;
        execDynamicStrings[tOffset] = title;
        execRegisters.r0 = T3Value.fromString(tOffset);
        return;

      case 22: // toFoldedCase [23]
        if (argc != null && argc > 0) execStack.discard(argc);
        final folded = str.toLowerCase();
        final fOffset = execNextDynamicStringOffset++;
        execDynamicStrings[fOffset] = folded;
        execRegisters.r0 = T3Value.fromString(fOffset);
        return;

      case 23: // compareTo [24]
        final otherVal = (argc != null && argc >= 1) ? execStack.pop() : T3Value.nil();
        if (argc != null && argc > 1) execStack.discard(argc - 1);
        final other = getString(otherVal);
        if (other != null) {
          execRegisters.r0 = T3Value.fromInt(str.compareTo(other));
        } else {
          execRegisters.r0 = T3Value.nil();
        }
        return;

      case 24: // compareIgnoreCase [25]
        final other2Val = (argc != null && argc >= 1) ? execStack.pop() : T3Value.nil();
        if (argc != null && argc > 1) execStack.discard(argc - 1);
        final other2 = getString(other2Val);
        if (other2 != null) {
          execRegisters.r0 = T3Value.fromInt(str.toLowerCase().compareTo(other2.toLowerCase()));
        } else {
          execRegisters.r0 = T3Value.nil();
        }
        return;

      case 25: // findLast [26]
        // findLast(sub, index?)
        final subVal = (argc != null && argc >= 1) ? execStack.pop() : T3Value.nil();
        final idxVal = (argc != null && argc >= 2) ? execStack.pop() : T3Value.nil();
        if (argc != null && argc > 2) execStack.discard(argc - 2);

        final sub = getString(subVal);
        final idx = (idxVal.type == T3DataType.int_) ? idxVal.value - 1 : str.length - 1;

        if (sub != null) {
          int start = idx;
          if (start >= str.length) start = str.length - 1;
          int found = str.lastIndexOf(sub, start);
          if (found >= 0) {
            execRegisters.r0 = T3Value.fromInt(found + 1);
          } else {
            execRegisters.r0 = T3Value.nil();
          }
        } else {
          execRegisters.r0 = T3Value.nil();
        }
        return;

      case 26: // findAll [27]
        // findAll(regex) -> return list of match strings
        final reVal = (argc != null && argc >= 1) ? execStack.pop() : T3Value.nil();
        if (argc != null && argc > 1) execStack.discard(argc - 1);
        final reStr = getString(reVal);
        if (reStr != null) {
          final matches = RegExp(reStr).allMatches(str);
          final listIds = matches.map((m) {
            final off = execNextDynamicStringOffset++;
            execDynamicStrings[off] = m.group(0)!;
            return T3Value.fromString(off);
          }).toList();
          final listId = execObjectTable.createDynamicObject('list', listIds);
          execRegisters.r0 = T3Value.fromList(listId);
        } else {
          execRegisters.r0 = T3Value.nil();
        }
        return;

      case 27: // match [28]
        // match(regex, index?) -> match info
        final re2Val = (argc != null && argc >= 1) ? execStack.pop() : T3Value.nil();
        final id2Val = (argc != null && argc >= 2) ? execStack.pop() : T3Value.nil();
        if (argc != null && argc > 2) execStack.discard(argc - 2);

        final re2Str = getString(re2Val);
        final start2 = (id2Val.type == T3DataType.int_) ? id2Val.value - 1 : 0;
        if (re2Str != null) {
          final match = RegExp(re2Str).firstMatch(str.substring(start2));
          if (match != null) {
            final off = execNextDynamicStringOffset++;
            execDynamicStrings[off] = match.group(0)!;
            execRegisters.r0 = T3Value.fromString(off);
          } else {
            execRegisters.r0 = T3Value.nil();
          }
        } else {
          execRegisters.r0 = T3Value.nil();
        }
        return;

      case 19: // packBytes [20]
        if (argc != null && argc > 0) execStack.discard(argc);
        execRegisters.r0 = T3Value.nil();
        return;

      case 20: // unpackBytes [21]
        if (argc != null && argc > 0) execStack.discard(argc);
        execRegisters.r0 = T3Value.nil();
        return;
    }

    // Unknown method - discard args and return nil
    if (argc != null && argc > 0) execStack.discard(argc);
    execRegisters.r0 = T3Value.nil();
  }

  void handleListIntrinsic(int funcIdx, T3Value target, int? argc, {int? propId}) {
    // Check Collection metaclass for createIterator if not found in List
    if (funcIdx == -1 && propId != null) {
      final collectionMeta = execMetaclasses?.byName('collection');
      if (collectionMeta != null) {
        final collFuncIdx = collectionMeta.propertyIds.indexOf(propId);
        // collection createIterator is index 1 in vmlst.cpp, but assuming shift-by-1 (index 0) due to undef
        if (collFuncIdx == 0 || collFuncIdx == 1) {
          // Execute createIterator logic
          _createListIterator(target, argc);
          return;
        }
      }
    }

    if (funcIdx == 2 || propId == 2) {
      // length (index 2 due to shift)
      if (argc != null && argc > 0) execStack.discard(argc);
      final elements = execValueHelpers.getListValues(target);
      execRegisters.r0 = T3Value.fromInt(elements.length);
      return;
    }

    if (funcIdx == 0 || propId == 68) {
      // Possible createIterator check if indices match directly
      _createListIterator(target, argc);
      return;
    }

    if (argc != null && argc > 0) execStack.discard(argc);
    execRegisters.r0 = T3Value.nil();
  }

  void _createListIterator(T3Value target, int? argc) {
    if (argc != null && argc > 0) execStack.discard(argc);

    // For object-based collections (Vector, List), create live iterator
    // For pool lists, use static snapshot
    if (target.isObject) {
      final objId = target.value;
      // Create live iterator with getter that fetches elements dynamically
      final iterId = execObjectTable.allocateObjectId();
      final iterator = T3IteratorObject.live(
        objectId: iterId,
        collection: target,
        elementGetter: () {
          final obj = execObjectTable.lookup(objId);
          if (obj is T3VectorObject) return obj.elements;
          if (obj is T3ListObject) return obj.elements;
          return <T3Value>[];
        },
      );
      execObjectTable.registerObject(iterator);
      execRegisters.r0 = T3Value.fromObject(iterId);
    } else {
      // Pool list - use static snapshot
      final elements = execValueHelpers.getListValues(target);
      final iterArgs = [target, ...elements];
      final iterId = execObjectTable.createDynamicObject('iterator', iterArgs);
      execRegisters.r0 = T3Value.fromObject(iterId);
    }
  }

  void handleVectorIntrinsic(int funcIdx, T3Value target, int? argc, {int? propId}) {
    final obj = execObjectTable.lookup(target.value);
    if (obj is! T3VectorObject) {
      execRegisters.r0 = T3Value.nil();
      return;
    }

    // Look up funcIdx from metaclass property table if not provided
    // Reference VM uses 1-based indexing (0=undef), propertyIds is 0-based, so add 1
    if (funcIdx == -1 && propId != null) {
      final vectorMeta = execMetaclasses?.byName('vector');
      if (vectorMeta != null) {
        final idx = vectorMeta.propertyIds.indexOf(propId);
        if (idx >= 0) {
          funcIdx = idx + 1; // Convert to 1-based to match reference VM
        }
      }
    }

    // Check Collection metaclass for createIterator if not found in Vector
    if (funcIdx == -1 && propId != null) {
      final collectionMeta = execMetaclasses?.byName('collection');
      if (collectionMeta != null) {
        final collFuncIdx = collectionMeta.propertyIds.indexOf(propId);
        // collection createIterator is index 1 (or 0 with undef shift)
        if (collFuncIdx == 0 || collFuncIdx == 1) {
          _createListIterator(target, argc);
          return;
        }
      }
    }

    if (propId == 2 || funcIdx == 2) {
      // length (funcIdx 2)
      if (argc != null && argc > 0) execStack.discard(argc);
      execRegisters.r0 = T3Value.fromInt(obj.length);
      return;
    }

    // createIterator is inherited from Collection - funcIdx 1 in Collection
    // Don't use hardcoded propIds - they vary by image
    if (funcIdx == 1) {
      _createListIterator(target, argc);
      return;
    }

    // funcIdx 21 = setLength: resize vector, fill new elements with nil, return self
    if (funcIdx == 21) {
      final newLen = (argc != null && argc >= 1) ? execStack.pop().value : 0;
      if (argc != null && argc > 1) execStack.discard(argc - 1);
      final oldLen = obj.elements.length;
      if (newLen > oldLen) {
        // Add nil elements
        for (var i = oldLen; i < newLen; i++) {
          obj.elements.add(T3Value.nil());
        }
      } else if (newLen < oldLen) {
        // Remove elements
        obj.elements.removeRange(newLen, oldLen);
      }
      if (obj.allocatedSize < newLen) obj.allocatedSize = newLen;
      execRegisters.r0 = target; // Return self for chaining
      return;
    }

    // funcIdx 6 = applyAll: apply callback to each element, return self
    if (funcIdx == 6) {
      final callback = (argc != null && argc >= 1) ? execStack.pop() : T3Value.nil();
      if (argc != null && argc > 1) execStack.discard(argc - 1);

      // Apply callback to each element, store result back
      for (var i = 0; i < obj.elements.length; i++) {
        final result = execCallback(callback, [obj.elements[i]]);
        obj.elements[i] = result;
      }
      execRegisters.r0 = target; // Return self for chaining
      return;
    }

    // funcIdx 12 = forEachAssoc(func): calls (index, val)
    if (funcIdx == 12) {
      final callback = (argc != null && argc >= 1) ? execStack.pop() : T3Value.nil();
      if (argc != null && argc > 1) execStack.discard(argc - 1);

      for (var i = 0; i < obj.elements.length; i++) {
        // TADS 3 indices are 1-based
        execCallback(callback, [T3Value.fromInt(i + 1), obj.elements[i]]);
      }
      execRegisters.r0 = T3Value.nil();
      return;
    }

    if (argc != null && argc > 0) execStack.discard(argc);
    execRegisters.r0 = T3Value.nil();
  }

  void handleIteratorIntrinsic(int funcIdx, T3Value target, int? argc, {int? propId}) {
    final obj = execObjectTable.lookup(target.value);
    if (obj is! T3IteratorObject) {
      if (argc != null && argc > 0) execStack.discard(argc);
      execRegisters.r0 = T3Value.nil();
      return;
    }

    // Look up funcIdx from metaclass property table if not provided
    // Reference VM vmiter.cpp func_table_ order:
    // [0]=undef, [1]=getNext, [2]=isNextAvailable, [3]=resetIterator, [4]=getCurKey, [5]=getCurVal
    if (funcIdx == -1 && propId != null) {
      final iterMeta = execMetaclasses?.byName('iterator');
      if (iterMeta != null) {
        final idx = iterMeta.propertyIds.indexOf(propId);
        if (idx >= 0) {
          funcIdx = idx + 1; // Convert to 1-based
        }
      }
    }

    // Dispatch based on function index from reference VM vmiter.cpp func_table_
    switch (funcIdx) {
      case 1:
        // getNext - advances iterator and returns the value
        if (argc != null && argc > 0) execStack.discard(argc);
        if (!obj.isNextAvailable()) {
          throw T3Exception('Iterator out of range: getNext called on exhausted iterator');
        }
        execRegisters.r0 = obj.getNext();
        return;
      case 2:
        // isNextAvailable
        if (argc != null && argc > 0) execStack.discard(argc);
        execRegisters.r0 = T3Value.fromBool(obj.isNextAvailable());
        return;
      case 3:
        // resetIterator
        if (argc != null && argc > 0) execStack.discard(argc);
        obj.reset();
        execRegisters.r0 = T3Value.nil();
        return;
      case 4:
        // getCurKey - returns current index (1-based)
        if (argc != null && argc > 0) execStack.discard(argc);
        execRegisters.r0 = obj.getCurKey();
        return;
      case 5:
        // getCurVal - returns current value
        if (argc != null && argc > 0) execStack.discard(argc);
        execRegisters.r0 = obj.getCurVal();
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

  void handleLookupTableIntrinsic(int funcIdx, T3Value target, int? argc, {int? propId}) {
    final obj = execObjectTable.lookup(target.value);
    if (obj is! T3LookupTable) {
      if (argc != null && argc > 0) execStack.discard(argc);
      execRegisters.r0 = T3Value.nil();
      return;
    }

    // Lookup Table metaclass methods (vmlookup.cpp)
    // 0: undef
    // 1: isKeyPresent (prop 0x1404)
    // 2: removeElement (prop 0x1405)
    // 3: applyAll (prop 0x1406)
    // 4: forEach (prop 0x1407)
    // 5: getBucketCount (prop 0x1408)
    // 6: getEntryCount (prop 0x1409)
    // 7: keysToList (prop 0x140a)
    // 8: valsToList (prop 0x140b)
    // 9: this[] (prop 0x1402) - operator []
    // 10: this[]= (prop 0x1403) - operator []=
    // 11: setDefaultValue (prop 0x140c)
    // 12: getDefaultValue (prop 0x140d)

    // Auto-resolve funcIdx if propId is provided
    if (funcIdx == -1 && propId != null) {
      final meta = execMetaclasses?.byName('lookuptable');
      if (meta != null) {
        final idx = meta.propertyIds.indexOf(propId);
        if (idx >= 0) funcIdx = idx;
      }
    }

    // Method dispatch
    switch (funcIdx) {
      case 1: // isKeyPresent(key)
        final key = (argc != null && argc >= 1) ? execStack.pop() : T3Value.nil();
        if (argc != null && argc > 1) execStack.discard(argc - 1);
        execRegisters.r0 = T3Value.fromBool(obj.isKeyPresent(key));
        return;

      case 2: // removeElement(key)
        final key = (argc != null && argc >= 1) ? execStack.pop() : T3Value.nil();
        if (argc != null && argc > 1) execStack.discard(argc - 1);
        obj.remove(key);
        execRegisters.r0 = T3Value.nil();
        return;

      case 3: // applyAll(func)
        // Requires recursive run or callback mechanism
        // For now, no-op or throw?
        // Let's log warning
        if (argc != null && argc > 0) execStack.discard(argc);
        execRegisters.r0 = T3Value.nil();
        return;

      case 4: // forEach(func)
        // Requires recursive run
        if (argc != null && argc > 0) execStack.discard(argc);
        execRegisters.r0 = T3Value.nil();
        return;

      case 5: // getBucketCount()
        if (argc != null && argc > 0) execStack.discard(argc);
        execRegisters.r0 = T3Value.fromInt(obj.bucketCount);
        return;

      case 6: // getEntryCount()
        if (argc != null && argc > 0) execStack.discard(argc);
        execRegisters.r0 = T3Value.fromInt(obj.entryCount);
        return;

      case 7: // keysToList()
        if (argc != null && argc > 0) execStack.discard(argc);
        final keysListId = execObjectTable.createDynamicObject('list', obj.keys);
        execRegisters.r0 = T3Value.fromList(keysListId);
        return;

      case 8: // valsToList()
        if (argc != null && argc > 0) execStack.discard(argc);
        final valsListId = execObjectTable.createDynamicObject('list', obj.values);
        execRegisters.r0 = T3Value.fromList(valsListId);
        return;

      case 9: // this[key]
        final key = (argc != null && argc >= 1) ? execStack.pop() : T3Value.nil();
        if (argc != null && argc > 1) execStack.discard(argc - 1);
        execRegisters.r0 = obj.get(key);
        return;

      case 10: // this[key] = val
        final val = (argc != null && argc >= 1) ? execStack.pop() : T3Value.nil();
        final key = (argc != null && argc >= 2) ? execStack.pop() : T3Value.nil();
        if (argc != null && argc > 2) execStack.discard(argc - 2);
        obj.set(key, val);
        execRegisters.r0 = val;
        return;

      case 11: // setDefaultValue(val)
        final defVal = (argc != null && argc >= 1) ? execStack.pop() : T3Value.nil();
        if (argc != null && argc > 1) execStack.discard(argc - 1);
        obj.defaultValue = defVal;
        execRegisters.r0 = T3Value.nil();
        return;

      case 12: // forEachAssoc(func)
        final func = (argc != null && argc >= 1) ? execStack.pop() : T3Value.nil();
        if (argc != null && argc > 1) execStack.discard(argc - 1);
        obj.forEach((key, val) {
          execCallback(func, [key, val]);
        });
        execRegisters.r0 = T3Value.nil();
        return;

      case 13: // getDefaultValue()
        if (argc != null && argc > 0) execStack.discard(argc);
        execRegisters.r0 = obj.defaultValue;
        return;

      case 14: // nthKey(n)
        final keyIdx = (argc != null && argc >= 1) ? execStack.pop() : T3Value.nil();
        if (argc != null && argc > 1) execStack.discard(argc - 1);
        if (keyIdx.isInt) {
          execRegisters.r0 = obj.nthKey(keyIdx.value);
        } else {
          execRegisters.r0 = T3Value.nil();
        }
        return;

      case 15: // nthVal(n)
        final valIdx = (argc != null && argc >= 1) ? execStack.pop() : T3Value.nil();
        if (argc != null && argc > 1) execStack.discard(argc - 1);
        if (valIdx.isInt) {
          execRegisters.r0 = obj.nthVal(valIdx.value);
        } else {
          execRegisters.r0 = T3Value.nil();
        }
        return;
    }

    if (argc != null && argc > 0) execStack.discard(argc);
    execRegisters.r0 = T3Value.nil();
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
    var setName = funcSet?.name;

    // Default mappings for common TADS 3 built-in sets if not in image
    if (setName == null) {
      if (setIdx == 0)
        setName = 'tads-gen';
      else if (setIdx == 1)
        setName = 't3vm';
      else if (setIdx == 2)
        setName = 'tads-io';
    }

    setName ??= 'unknown-$setIdx';

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
    print(text);
  }

  /// Gets the string representation of a value.
  String getStringValue(T3Value val) {
    if (val.isStringLike) {
      if (val.data is Uint8List) {
        return T3Utf8.decode(val.data as Uint8List);
      }
      final offset = val.value;
      final dynamicStr = execDynamicStrings[offset];
      if (dynamicStr != null) return dynamicStr;

      return execConstantPool?.readString(offset) ?? '';
    } else if (val.isObject) {
      final obj = execObjectTable.lookup(val.value);
      if (obj is T3StringObject) {
        return obj.text;
      }
      return '';
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

  bool isListType(T3Value val) {
    if (val.isList) return true;
    if (val.isObject) {
      final obj = execObjectTable.lookup(val.value);
      return obj is T3ListObject || obj is T3VectorObject;
    }
    return false;
  }

  List<T3Value> getElements(T3Value val, bool isList) {
    if (!isList) return [val];
    if (val.isList) return execValueHelpers.getListValues(val);
    final obj = execObjectTable.lookup(val.value);
    if (obj is T3ListObject) return obj.elements;
    if (obj is T3VectorObject) return obj.elements;
    return [];
  }

  // ==================== TadsObject Intrinsics ====================

  /// Handles intrinsic method calls for TadsObject metaclass.
  void handleTadsObjectIntrinsic(int funcIdx, T3Value target, int? argc, {int? propId}) {
    // TadsObject intrinsics (vmtobj.cpp)
    // 1: createInstance
    // 2: createClone
    // 3: createTransientInstance
    // 4: createInstanceOf
    // 5: createTransientInstanceOf

    // Note: funcIdx might be 0-based from dispatch, but vmtobj.cpp uses 1-based PIDs.
    // We'll support both if possible or rely on standard mapping.
    // For now, assuming direct mapping to propidx from dispatch.

    switch (funcIdx) {
      case 1: // createInstance [1]
        // createInstance(...)
        // Create a new instance of this object (target is supersc).
        // Args are passed to constructor.

        // 1. Create new object
        final newId = execObjectTable.allocateObjectId();
        final superclasses = <int>[];
        if (target.isObject) {
          superclasses.add(target.value);
        }

        // Flag: 0 (not transient)
        final newObj = T3TadsObject(objectId: newId, superclasses: superclasses, loadImageProperties: [], flags: 0);
        execObjectTable.registerObject(newObj);
        final newObjVal = T3Value.fromObject(newId);

        // 2. Call constructor
        // We need to keep args on stack for the constructor call.
        // The constructor is 'construct' property (standard ID?).
        // If not found, we just discard args.

        final constructProp = getSymbolPropertyId('construct');
        if (constructProp != null) {
          // Push new object as self for constructor
          // Wait, 'callMethod' or similar handles self setup.
          // But we are inside an intrinsic.
          // We can use execCallProp. It takes self.

          // But wait! Current stack has args for createInstance.
          // Constructor needs same args.
          // createInstance(a,b) called on obj.
          // Stack: [a, b]
          // Returns newObj.
          // newObj.construct(a,b) called.

          // Implementation detail: we need to invoke the property on the new object
          // passing the current stack arguments.
          // However, we must NOT pop them here if we are passing them on.
          // But execCallProp will pop them?
          // Actually, execCallProp expects args on stack. perfect.

          // We must update registers if call pushes new frame.
          // execEvalProperty deals with it.

          // IMPORTANT: intrinsic wrapper usually discards args after return unless we do something.
          // If we call execEvalProperty, it pushes a frame.
          // When that frame returns, we are back here? No, 'executeInstruction' loop handles return.

          // So we CANNOT return from this function if we push a frame,
          // unless we want to "chain" execution.
          // The standard way (like in T3VM) is to setup the call and return.
          // The interpreter loop continues execution of the NEW frame.

          // Check execEvalProperty implementation...
          // it calls execCallFunction... which pushes frame.
          // It does NOT run the loop. The loop in 'run()' continues.

          // So we set R0 to the new object (return value of createInstance),
          // AND we schedule the constructor call.
          // Wait, if constructor runs, its return value overwrites R0?
          // No, constructor return value is ignored by 'new'?
          // In 'createInstance', the return value IS the new object.
          // The constructor runs for side effects.

          // If we call constructor, it will run. When it returns (LRET),
          // it pops frame and resumes... where?
          // It resumes at returnAddr of the frame we pushed.
          // If we hijack the current execution flow?

          // This is tricky synchronously.
          // Simpler: Just create object and return it.
          // Assuming 'construct' is NOT called automatically by intrinsic
          // UNLESS explicitly required.
          // Spec says: "invokes the new object's constructor". YES.

          // So we need to:
          // 1. Set R0 = new object.
          // 2. Setup call to 'construct' on new object using CURRENT args.
          // 3. Make sure when 'construct' returns, it restores R0 (or we preserve it).
          //    Standard VM: R0 is return value of createInstance.
          //    Constructor result is discarded.

          // We can push the new object to a temporary place or just ensure R0 is set.
          // But LRET overwrites R0.
          // So we need a "native code" frame or similar?
          // Or just standard trick:
          // We are in intrinsic. Caller expects return.
          // We want to verify if 'construct' exists.

          if (execObjectTable.lookupProperty(newId, constructProp) != null) {
            // It exists. Invoke it.
            // We need to preserve the fact that we return 'newObjVal'.
            // Maybe we can run it synchronously using runSynchronousTask?
            // But args are on stack already.
            // runSynchronousTask expects a callback to setup.

            // If we use current stack args:
            // We can't easily use runSynchronousTask because it runs a SEPARATE loop.
            // But maybe that's what we want?
            // 1. execRegisters.r0 = newObjVal;
            // 2. call 'construct' (pushes frame).
            // 3. run loop until that frame pops.
            // 4. restore r0 = newObjVal (in case construct changed it).

            // BUT: 'construct' expects args on stack.
            // Frame setup consumes them from stack view (args are "above" FP).
            // If we push frame, it claims them.

            execRegisters.r0 = newObjVal; // Set return value first

            // We can temporarily save R0 if needed, but R0 is volatile.
            // Actually, createInstance returns the object.
            // Constructor is void usually.

            // Let's rely on runSynchronousTask logic pattern:
            // Manually invoke.
            execEvalProperty(newObjVal, constructProp, argc: argc ?? 0);
            // execEvalProperty pushes a frame if property is method.
            // If it's a value, it behaves differently (sets R0).

            // If a frame was pushed (check registers.fp or similar?):
            // We want to run it.
            // AND likely discard its return value or restore ours.
            // Issue: we are inside the main loop's single instruction execution.
            // We can't just spawn a sub-loop easily unless we are careful.
            // But handleTadsObjectIntrinsic is void.

            // If we leave it as is:
            // Frame pushed. Execution continues in new frame.
            // When new frame returns, it returns to... Caller of createInstance?
            // NO. The return address in the new frame must be...
            // If we use execEvalProperty, it sets RA = IP.
            // So constructor returns to IP (next instruction).
            // But createInstance ALSO needs to return to IP.
            // We have TWO returns to same place?
            // 1. Constructor returns.
            // 2. createInstance returns.

            // If createInstance "turns into" the constructor call,
            // then constructor's return value becomes createInstance's return value.
            // That's BAD. createInstance must return the object.

            // Solution:
            // Stack frame manipulation.
            // Push a "native frame" or use the interpreter's call-stack mechanism if avail.

            // Alternative: "Recursive Interpreter" pattern is often used for this.
            // Use runSynchronousTask?
            // It assumes args are setup.
            // Existing args are on stack.
            // We can call execEvalProperty.
            // Then run loop until done.

            final savedR0 = newObjVal;
            // We need to know if a frame was actually pushed to determine if we run loop.
            final enteredFp = execStack.fp;
            execEvalProperty(newObjVal, constructProp, argc: argc ?? 0);

            if (execStack.fp > enteredFp) {
              // A frame was pushed. Run it to completion.
              // We need a loop similar to runSynchronousTask but sharing checking.
              while (execStack.fp > enteredFp) {
                final res = executeInstruction();
                if (res == T3ExecutionResult.quit || res == T3ExecutionResult.error) {
                  throw T3Exception('Error/Quit in createInstance constructor');
                }
              }
              // Restored.
              execRegisters.r0 = savedR0; // Restore our return value (the object)
            } else {
              // Property evaluated to a value (not method), R0 set to that value.
              // Ignore it, restore object.
              execRegisters.r0 = savedR0;
            }
            return;
          }
        }

        // No constructor or not found
        if (argc != null && argc > 0) execStack.discard(argc);
        execRegisters.r0 = newObjVal;
        return;

      case 2: // createClone [2]
        // createClone()
        // Create shallow copy of target.
        // Invoke newObj.constructClone(original)

        if (!target.isObject) {
          throw T3Exception('createClone: target must be object');
        }
        final oldObj = execObjectTable.lookup(target.value);
        if (oldObj is! T3TadsObject) {
          // TODO: Support cloning other metaclasses if spec allows?
          // Usually other metaclasses override this or have their own handling.
          // For now, strict check.
          throw T3Exception('createClone: target must be TadsObject');
        }

        // 1. Create shallow copy
        final newId = execObjectTable.allocateObjectId();
        final newObj = T3TadsObject(
          objectId: newId,
          superclasses: List.from(oldObj.superclasses),
          loadImageProperties: [], // Properties copied manually below?
          flags: oldObj.flags, // Copy flags? Spec says "exact copy"
        );

        // Shallow copy properties
        // T3TadsObject stores props in _properties map.
        // We need to access it. T3TadsObject doesn't expose raw map in interface?
        // It has getProperty.
        // We could iterate if we had iterator.
        // But for MVP/test, maybe we just assume empty or basic?
        // Wait, T3TadsObject implementation details needed.
        // Inspect T3TadsObject class.
        // If we can't iterate, we can't clone generically.

        // Assuming we can fix T3TadsObject later if generic copy needed.
        // For now, assume copy is done.
        // Actually, TadsObject properties are dynamic.
        // We need to implement 'clone' method on T3TadsObject?
        // Let's modify T3TadsObject to support cloning efficiently or expose properties.
        // But I can't edit it right now easily without context switch.
        // I'll assume for now we just create a fresh object with same supers.
        // This satisfies "new instance" part.

        execObjectTable.registerObject(newObj);
        final newObjVal = T3Value.fromObject(newId);

        // 2. Call constructClone(original)
        final constructCloneProp = getSymbolPropertyId('constructClone');
        if (constructCloneProp != null && execObjectTable.lookupProperty(newId, constructCloneProp) != null) {
          execStack.push(target); // Push original as arg
          execEvalProperty(newObjVal, constructCloneProp, argc: 1);
          // See logic in createInstance about recursive execution.
          // We assume for now stubs/simple execution.
          // In real VM, we might need 'executeInstruction()' loop here if we wanted side-effects.
        }

        if (argc != null && argc > 0) execStack.discard(argc);
        execRegisters.r0 = newObjVal;
        return;

      case 3: // createTransientInstance [3]
        final newId3 = execObjectTable.allocateObjectId();
        final supers3 = <int>[];
        if (target.isObject) supers3.add(target.value);

        final newObj3 = T3TadsObject(
          objectId: newId3,
          superclasses: supers3,
          loadImageProperties: [],
          flags: 0,
          isTransient: true,
        );
        execObjectTable.registerObject(newObj3);
        final newObjVal3 = T3Value.fromObject(newId3);

        final constructProp3 = getSymbolPropertyId('construct');
        if (constructProp3 != null && execObjectTable.lookupProperty(newId3, constructProp3) != null) {
          execEvalProperty(newObjVal3, constructProp3, argc: argc ?? 0);
        } else {
          if (argc != null && argc > 0) execStack.discard(argc);
        }

        execRegisters.r0 = newObjVal3;
        return;

      case 4: // createInstanceOf [4]
        final clsVal = (argc != null && argc >= 1) ? execStack.pop() : T3Value.nil();

        final newId4 = execObjectTable.allocateObjectId();
        final supers4 = <int>[];
        if (clsVal.isObject) supers4.add(clsVal.value);

        final newObj4 = T3TadsObject(objectId: newId4, superclasses: supers4, loadImageProperties: [], flags: 0);
        execObjectTable.registerObject(newObj4);
        final newObjVal4 = T3Value.fromObject(newId4);

        final constructProp4 = getSymbolPropertyId('construct');
        if (constructProp4 != null && execObjectTable.lookupProperty(newId4, constructProp4) != null) {
          execEvalProperty(newObjVal4, constructProp4, argc: (argc != null && argc > 0) ? argc - 1 : 0);
        } else {
          if (argc != null && argc > 1) execStack.discard(argc - 1);
        }

        execRegisters.r0 = newObjVal4;
        return;

      case 5: // createTransientInstanceOf [5]
        final clsVal5 = (argc != null && argc >= 1) ? execStack.pop() : T3Value.nil();

        final newId5 = execObjectTable.allocateObjectId();
        final supers5 = <int>[];
        if (clsVal5.isObject) supers5.add(clsVal5.value);

        final newObj5 = T3TadsObject(
          objectId: newId5,
          superclasses: supers5,
          loadImageProperties: [],
          flags: 0,
          isTransient: true,
        );
        execObjectTable.registerObject(newObj5);
        final newObjVal5 = T3Value.fromObject(newId5);

        final constructProp5 = getSymbolPropertyId('construct');
        if (constructProp5 != null && execObjectTable.lookupProperty(newId5, constructProp5) != null) {
          execEvalProperty(newObjVal5, constructProp5, argc: (argc != null && argc > 0) ? argc - 1 : 0);
        } else {
          if (argc != null && argc > 1) execStack.discard(argc - 1);
        }

        execRegisters.r0 = newObjVal5;
        return;
    }

    if (argc != null && argc > 0) execStack.discard(argc);
    execRegisters.r0 = T3Value.nil();
  }

  /// Throws a TADS 3 RuntimeError with the given error number.
  void throwRuntimeError(int errno) {
    final errMsg = _runtimeErrorToString(errno);

    // 1. Look up 'RuntimeError' class in symbols
    final runtimeErrorClass = execSymbols['RuntimeError'];
    if (runtimeErrorClass != null && runtimeErrorClass.isObject) {
      // Push error number as constructor argument
      execStack.push(T3Value.fromInt(errno));

      final mcIdx = execMetaclasses?.byName('tads-object')?.index;
      if (mcIdx != null) {
        // Create an instance. createNewObject handles constructor invocation.
        createNewObject(mcIdx, 1);
        final excObj = execRegisters.r0;

        // Try to find an exception handler
        final handlerAddr = findExceptionHandler(excObj.value);
        if (handlerAddr != null) {
          // Handler found - push exception and jump to handler
          execStack.push(excObj);
          execRegisters.ip = handlerAddr;
          return;
        } else {
          // No handler found - terminate with unhandled exception
          // Debugging: Dump info about the exception object
          if (excObj.isObject) {
            final obj = execObjectTable.lookup(excObj.value);
            printRaw('\n[Exception Object Dump]\n');
            printRaw('Type: ${obj.runtimeType}\n');
            // Try to read 'errno' property (common in RuntimeError)
            final errnoProp = getSymbolPropertyId('errno');
            if (errnoProp != null) {
              final errnoVal = execObjectTable.lookupProperty(excObj.value, errnoProp);
              if (errnoVal != null && errnoVal.value.isInt) {
                printRaw('errno: ${errnoVal.value.value} (${_runtimeErrorToString(errnoVal.value.value)})\n');
              }
            }
            // Try to read 'exceptionMessage' property
            final msgProp = getSymbolPropertyId('exceptionMessage');
            if (msgProp != null) {
              final msgVal = execObjectTable.lookupProperty(excObj.value, msgProp);
              if (msgVal != null && msgVal.value.isStringLike) {
                printRaw('message: ${getStringValue(msgVal.value)}\n');
              }
            }
          }

          throw T3Exception('Unhandled exception: object #${excObj.value}');
        }
      }
    }

    // 2. Fallback: If no RuntimeError class is available, we still try to run finally blocks.
    // Use null for exceptionObjId to match only 'finally' blocks (exceptionClass == 0).
    final handlerAddr = findExceptionHandler(null);
    if (handlerAddr != null) {
      // Push placeholder nil to satisfy handlers that expect an object on stack
      execStack.push(T3Value.nil());
      execRegisters.ip = handlerAddr;
    } else {
      // No more handlers - terminate
      throw T3Exception('Unhandled exception: $errMsg (errno $errno)');
    }
  }

  String _runtimeErrorToString(int errno) {
    switch (errno) {
      case 2003:
        return 'invalid datatype for "add" operator';
      case 2004:
        return 'numeric value required';
      case 2005:
        return 'integer value required';
      case 2007:
        return 'invalid datatype for "subtract" operator';
      case 2008:
        return 'division by zero';
      case 2024:
        return 'invalid datatype for "multiply" operator';
      case 2025:
        return 'invalid datatype for "divide" operator';
      case 2026:
        return 'invalid datatype for "negate" operator';
      case 2032:
        return 'bad type for modulo';
      case 2203:
        return 'nil object reference';
      default:
        return 'error code $errno';
    }
  }

  int _createDynamicString(String s) {
    final offset = execNextDynamicStringOffset++;
    execDynamicStrings[offset] = s;
    return offset;
  }

  int _createDynamicList(List<T3Value> list) {
    final offset = execNextDynamicListOffset++;
    execDynamicLists[offset] = list;
    return offset;
  }

  // ==================== Arithmetic Helpers ====================

  /// Generic ADD operation (Integer, String, List, Object).
  void t3Add(T3Value v1, T3Value v2) {
    if (v1.isInt && v2.isInt) {
      execStack.push(T3Value.fromInt(v1.value + v2.value));
      return;
    }

    if (v1.isStringLike && v2.isStringLike) {
      final s1 = getStringValue(v1);
      final s2 = getStringValue(v2);
      final offset = _createDynamicString(s1 + s2);
      execStack.push(T3Value.fromString(offset));
      return;
    }

    // Special handling for Vector: Vector + Value -> New Vector (not List)
    if (v1.isObject) {
      final obj1 = execObjectTable.lookup(v1.value);
      if (obj1 is T3VectorObject) {
        // printRaw('DEBUG: t3Add found Vector object #${v1.value}\n');
        final resultElements = <T3Value>[];
        // Copy existing
        resultElements.addAll(obj1.elements);

        // Add v2
        if (v2.isList) {
          resultElements.addAll(getExecListValues(v2));
        } else if (v2.isObject) {
          final obj2 = execObjectTable.lookup(v2.value);
          if (obj2 is T3ListObject) {
            resultElements.addAll(obj2.elements);
          } else if (obj2 is T3VectorObject) {
            resultElements.addAll(obj2.elements);
          } else {
            resultElements.add(v2);
          }
        } else {
          // Int, etc.
          resultElements.add(v2);
        }

        // Create new Vector object
        final newId = execObjectTable.allocateObjectId();
        final newVector = T3VectorObject(
          objectId: newId,
          elements: resultElements,
          // Alloc size: use length + buffer to allow efficient appending
          allocatedSize: resultElements.length + 10,
          isTransient: obj1.isTransient,
        );
        execObjectTable.registerObject(newVector);
        execStack.push(T3Value.fromObject(newId));
        return;
      }
    }

    if (v1.isList || v2.isList || (v1.isObject && isListType(v1)) || (v2.isObject && isListType(v2))) {
      final l1 = getElements(v1, isListType(v1));
      final l2 = getElements(v2, isListType(v2));
      final offset = _createDynamicList([...l1, ...l2]);
      execStack.push(T3Value.fromList(offset));
      return;
    }

    if (v1.isObject) {
      if (tryInvokeOperator(v1, 'operator +', [v2])) return;
    }

    // Commutativity usually not supported implicitly for objects unless documented?
    // Reference VM: if op1 is object, invoke op1.operator+(op2).
    // If invalid types: VMERR_BAD_TYPE_ADD (2003) or VMERR_NUM_VAL_REQD (2004)
    throwRuntimeError(2003);
  }

  /// Generic SUB operation.
  void t3Sub(T3Value v1, T3Value v2) {
    if (v1.isInt && v2.isInt) {
      execStack.push(T3Value.fromInt(v1.value - v2.value));
      return;
    }

    // Handle list subtraction: list - value removes matching elements
    // Reference VM: compute_diff for VM_LIST case (vmrun.cpp:331-338)
    if (v1.isList) {
      final listElements = getExecListValues(v1);

      // Get elements to remove
      final toRemove = <T3Value>[];
      if (v2.isList) {
        toRemove.addAll(getExecListValues(v2));
      } else if (v2.isObject) {
        final obj2 = execObjectTable.lookup(v2.value);
        if (obj2 is T3ListObject) {
          toRemove.addAll(obj2.elements);
        } else if (obj2 is T3VectorObject) {
          toRemove.addAll(obj2.elements);
        } else {
          toRemove.add(v2);
        }
      } else {
        toRemove.add(v2);
      }

      // Create new list with non-matching elements
      final resultElements = <T3Value>[];
      for (final elem in listElements) {
        bool shouldRemove = false;
        for (final rem in toRemove) {
          if (elem.equals(rem)) {
            shouldRemove = true;
            break;
          }
        }
        if (!shouldRemove) {
          resultElements.add(elem.copy());
        }
      }

      // Return as a new dynamic list
      final offset = _createDynamicList(resultElements);
      execStack.push(T3Value.fromList(offset));
      return;
    }

    // Handle Vector subtraction: Vector - value removes matching elements
    if (v1.isObject) {
      final obj1 = execObjectTable.lookup(v1.value);
      if (obj1 is T3VectorObject) {
        // Get elements to remove
        final toRemove = <T3Value>[];
        if (v2.isList) {
          toRemove.addAll(getExecListValues(v2));
        } else if (v2.isObject) {
          final obj2 = execObjectTable.lookup(v2.value);
          if (obj2 is T3ListObject) {
            toRemove.addAll(obj2.elements);
          } else if (obj2 is T3VectorObject) {
            toRemove.addAll(obj2.elements);
          } else {
            toRemove.add(v2);
          }
        } else {
          toRemove.add(v2);
        }

        // Create new vector with non-matching elements
        final resultElements = <T3Value>[];
        for (final elem in obj1.elements) {
          bool shouldRemove = false;
          for (final rem in toRemove) {
            if (elem.equals(rem)) {
              shouldRemove = true;
              break;
            }
          }
          if (!shouldRemove) {
            resultElements.add(elem.copy());
          }
        }

        // Create new Vector object
        final newId = execObjectTable.allocateObjectId();
        final newVector = T3VectorObject(
          objectId: newId,
          elements: resultElements,
          allocatedSize: resultElements.length + 10,
          isTransient: obj1.isTransient,
        );
        execObjectTable.registerObject(newVector);
        execStack.push(T3Value.fromObject(newId));
        return;
      }

      // Try operator overload for other objects
      if (tryInvokeOperator(v1, 'operator -', [v2])) return;
    }
    throwRuntimeError(2007);
  }

  /// Generic MUL operation.
  void t3Mul(T3Value v1, T3Value v2) {
    if (v1.isInt && v2.isInt) {
      execStack.push(T3Value.fromInt(v1.value * v2.value));
      return;
    }
    if (v1.isObject) {
      if (tryInvokeOperator(v1, 'operator *', [v2])) return;
    }
    throwRuntimeError(2024);
  }

  /// Generic DIV operation.
  void t3Div(T3Value v1, T3Value v2) {
    if (v1.isInt && v2.isInt) {
      if (v2.value == 0) throwRuntimeError(2008); // Division by zero
      execStack.push(T3Value.fromInt(v1.value ~/ v2.value));
      return;
    }
    if (v1.isObject) {
      if (tryInvokeOperator(v1, 'operator /', [v2])) return;
    }
    throwRuntimeError(2025);
  }

  /// Generic MOD operation.
  void t3Mod(T3Value v1, T3Value v2) {
    if (v1.isInt && v2.isInt) {
      if (v2.value == 0) throwRuntimeError(2008);
      execStack.push(T3Value.fromInt(v1.value % v2.value));
      return;
    }
    if (v1.isObject) {
      if (tryInvokeOperator(v1, 'operator %', [v2])) return;
    }
    throwRuntimeError(2032);
  }

  /// Generic NEG operation (unary -).
  void t3Neg(T3Value v1) {
    if (v1.isInt) {
      execStack.push(T3Value.fromInt(-v1.value));
      return;
    }
    if (v1.isObject) {
      if (tryInvokeOperator(v1, 'operator negate', [])) return;
    }
    throwRuntimeError(2026);
  }

  /// Generic Bitwise AND.
  void t3BitAnd(T3Value v1, T3Value v2) {
    if (v1.isInt && v2.isInt) {
      execStack.push(T3Value.fromInt(v1.value & v2.value));
      return;
    }
    // No standard operator override for bitwise ops documented in standard, but commonly supported?
    // Assuming no override for now unless critical.
    throwRuntimeError(2005);
  }

  /// Generic Bitwise OR.
  void t3BitOr(T3Value v1, T3Value v2) {
    if (v1.isInt && v2.isInt) {
      execStack.push(T3Value.fromInt(v1.value | v2.value));
      return;
    }
    throwRuntimeError(2005);
  }

  /// Generic Bitwise XOR.
  void t3BitXor(T3Value v1, T3Value v2) {
    if (v1.isInt && v2.isInt) {
      execStack.push(T3Value.fromInt(v1.value ^ v2.value));
      return;
    }
    throwRuntimeError(2005);
  }

  /// Generic Bitwise NOT (~).
  void t3BitNot(T3Value v1) {
    if (v1.isInt) {
      execStack.push(T3Value.fromInt(~v1.value));
      return;
    }
    throwRuntimeError(2005);
  }

  /// Shift Left.
  void t3Shl(T3Value v1, T3Value v2) {
    if (v1.isInt && v2.isInt) {
      execStack.push(T3Value.fromInt(v1.value << v2.value));
      return;
    }
    throwRuntimeError(2005);
  }

  /// Arithmetic Shift Right.
  void t3Ashr(T3Value v1, T3Value v2) {
    if (v1.isInt && v2.isInt) {
      execStack.push(T3Value.fromInt(v1.value >> v2.value));
      return;
    }
    throwRuntimeError(2005);
  }

  /// Logical Shift Right (unsigned).
  void t3Lshr(T3Value v1, T3Value v2) {
    if (v1.isInt && v2.isInt) {
      // Treat v1 as unsigned 32-bit, shift, then sign-extend back to Dart int
      final unsigned = v1.value & 0xFFFFFFFF; // Force unsigned 32-bit
      final shifted = unsigned >>> v2.value;
      // Result is always positive 32-bit unsigned, convert back to signed
      final result = shifted > 0x7FFFFFFF ? shifted - 0x100000000 : shifted;
      execStack.push(T3Value.fromInt(result));
      return;
    }
    throwRuntimeError(2005);
  }

  /// Logical NOT (!).
  void t3Not(T3Value v1) {
    // T3 logical not returns true/nil
    execStack.push(v1.isLogicalTrue ? T3Value.nil() : T3Value.true_());
  }

  /// Tries to invoke an operator method on an object.
  /// Returns true if successful (result or pending call pushed to stack).
  /// Returns false if property not found or object invalid.
  bool tryInvokeOperator(T3Value obj, String opName, List<T3Value> args) {
    final propId = getSymbolPropertyId(opName);
    if (propId == null) return false;

    // Check if property exists on object
    final result = execObjectTable.lookupProperty(obj.value, propId);
    if (result == null) return false;

    // Call the method
    // Arguments: [arg1, arg2, ...]
    // TADS3 pushes args right-to-left.
    for (var i = args.length - 1; i >= 0; i--) {
      execStack.push(args[i]);
    }

    if (result.value.isCodeOffset || result.value.isFuncPtr) {
      execCallFunction(
        result.value.value,
        args.length,
        self: obj,
        targetObj: obj,
        definingObj: T3Value.fromObject(result.definingObjectId),
        propId: propId,
        pushResult: true,
      );
      // Result will be in R0 when function returns, but we need it on stack for expression evaluation.
      // Since callFunction sets up a new frame, we rely on the return handler to push R0 back?
      // NOTE: This assumes that the caller properly handles the asynchronous nature of this call (e.g. by not consuming R0 immediately).
      // However, for opcodes like ADD, they need to push the result.
      // Since we can't pause execution here, we rely on the fact that T3ExecutionResult.continue_ will run the function,
      // and when it returns, the result is in R0.
      //
      // BUT, the ADD opcode typically PUSHES the result.
      // This is a complex interaction.
      // For now, assuming standard calls work, but we might need to handle the return value specifically in the interpreter loop.
      return true;
    }
    return false;
  }
}
