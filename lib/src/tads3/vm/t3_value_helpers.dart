import 'package:zart/src/tads3/vm/t3_constant_pool.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_object_table.dart';
import 'package:zart/src/tads3/vm/t3_registers.dart';
import 'package:zart/src/tads3/vm/t3_stack.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';
import 'package:zart/src/loaders/tads/t3_exception.dart';

/// Mixin that provides helper methods for value manipulation in the T3 VM.
///
/// This mixin is used by [T3Interpreter] to provide common operations
/// like property access, indexing, and value conversion. Extracting these
/// helpers keeps the main interpreter file focused on opcode execution.
mixin T3ValueHelpers {
  // Required accessors that must be provided by the implementing class
  T3Stack get helperStack;
  T3Registers get helperRegisters;
  T3ObjectTable get helperObjectTable;
  T3ConstantPool? get helperConstantPool;
  Map<int, List<T3Value>> get helperDynamicLists;
  Map<int, String> get helperDynamicStrings;
  int get helperNextDynamicStringOffset;
  set helperNextDynamicStringOffset(int value);

  /// Applies an index to a list or string value.
  /// Returns the indexed element. Returns nil if container is nil.
  T3Value applyIndex(T3Value container, int index) {
    // Nil container returns nil (TADS behavior)
    if (container.isNil) {
      return T3Value.nil();
    }

    if (container.isList) {
      // Check if it's a dynamic list
      if (helperDynamicLists.containsKey(container.value)) {
        final list = helperDynamicLists[container.value]!;
        // TADS uses 1-based indexing
        if (index < 1 || index > list.length) {
          throw T3Exception('List index out of range: $index (length: ${list.length})');
        }
        return list[index - 1].copy();
      }
      // Otherwise read from constant pool
      final list = helperConstantPool!.readList(container.value);
      // TADS uses 1-based indexing
      if (index < 1 || index > list.length) {
        throw T3Exception('List index out of range: $index (length: ${list.length})');
      }
      return list[index - 1];
    } else if (container.isStringLike) {
      // String indexing - return a single character string
      String str;
      if (helperDynamicStrings.containsKey(container.value)) {
        str = helperDynamicStrings[container.value]!;
      } else {
        str = helperConstantPool!.readString(container.value);
      }
      // TADS uses 1-based indexing
      if (index < 1 || index > str.length) {
        throw T3Exception('String index out of range: $index (length: ${str.length})');
      }
      final char = str[index - 1];
      // Store as dynamic string and return
      final offset = helperNextDynamicStringOffset++;
      helperDynamicStrings[offset] = char;
      return T3Value.fromString(offset);
    } else if (container.isObject) {
      // Try indexing a Vector or List object
      final obj = helperObjectTable.lookup(container.value);
      if (obj is T3ListObject) {
        if (index < 1 || index > obj.elements.length) {
          throw T3Exception('List index out of range: $index (length: ${obj.elements.length})');
        }
        return obj.elements[index - 1].copy();
      }
      if (obj is T3VectorObject) {
        if (index < 1 || index > obj.elements.length) {
          throw T3Exception('Vector index out of range: $index (length: ${obj.elements.length})');
        }
        return obj.elements[index - 1].copy();
      }
      throw T3Exception('Cannot index object of type ${obj?.metaclass}');
    } else {
      throw T3Exception('Cannot index value of type ${container.type}');
    }
  }

  /// Sets a value at an index in a container (list or vector).
  void setIndexedValue(T3Value container, int index, T3Value value) {
    if (container.isList) {
      // For lists, we need to get/modify the dynamic list
      if (helperDynamicLists.containsKey(container.value)) {
        final list = helperDynamicLists[container.value]!;
        if (index >= 1 && index <= list.length) {
          list[index - 1] = value; // 1-based indexing
        } else {
          throw T3Exception('SETIND: list index $index out of bounds (1..${list.length})');
        }
      } else {
        // Constant pool list - need to copy to dynamic list first
        final originalList = helperConstantPool!.readList(container.value);
        if (index >= 1 && index <= originalList.length) {
          final newList = originalList.map((v) => v.copy()).toList();
          newList[index - 1] = value;
          helperDynamicLists[container.value] = newList;
        } else {
          throw T3Exception('SETIND: list index $index out of bounds (1..${originalList.length})');
        }
      }
    } else if (container.isObject) {
      // Check if it's a vector object
      final obj = helperObjectTable.lookup(container.value);
      if (obj is T3VectorObject) {
        if (index >= 1 && index <= obj.elements.length) {
          obj.elements[index - 1] = value;
        } else {
          throw T3Exception('SETIND: vector index $index out of bounds (1..${obj.elements.length})');
        }
      } else if (obj is T3ListObject) {
        if (index >= 1 && index <= obj.elements.length) {
          obj.elements[index - 1] = value;
        } else {
          throw T3Exception('SETIND: list index $index out of bounds (1..${obj.elements.length})');
        }
      } else {
        throw T3Exception('SETIND: cannot set index on object type ${obj?.metaclass}');
      }
    } else {
      throw T3Exception('SETIND: cannot set index on ${container.type}');
    }
  }

  /// Sets a property on a target object.
  void setPropertyValue(T3Value target, int propId, T3Value value) {
    if (target.type != T3DataType.obj) {
      throw T3Exception('Cannot set property $propId on type ${target.type}');
    }

    final obj = helperObjectTable.lookup(target.value);
    if (obj == null) {
      throw T3Exception('Attempted to set property $propId on non-existent object ${target.value}');
    }

    obj.setProperty(propId, value);
  }

  /// Gets the list of values for a list T3Value (handles dynamic and pool lists).
  List<T3Value> getListValues(T3Value listVal) {
    if (listVal.isList) {
      if (helperDynamicLists.containsKey(listVal.value)) {
        return helperDynamicLists[listVal.value]!;
      } else {
        return helperConstantPool!.readList(listVal.value);
      }
    } else if (listVal.isObject) {
      final obj = helperObjectTable.lookup(listVal.value);
      if (obj is T3ListObject) return obj.elements;
      if (obj is T3VectorObject) return obj.elements;
    }
    return [];
  }

  /// Checks if a value is a list (constant, dynamic, or object).
  bool isListValue(T3Value val) {
    if (val.isList) return true;
    if (val.isObject) {
      final obj = helperObjectTable.lookup(val.value);
      return obj is T3ListObject || obj is T3VectorObject;
    }
    return false;
  }

  /// Gets the next value from an iterator object.
  /// Returns null if the iterator is exhausted.
  ///
  /// Iterators in TADS are objects with internal state tracking position.
  /// For list/vector iterators, we track position in a simple way.
  T3Value? getIteratorNext(T3Value iterator) {
    if (!iterator.isObject) return null;

    final obj = helperObjectTable.lookup(iterator.value);
    if (obj == null) return null;

    if (obj is T3IteratorObject) {
      if (obj.isNextAvailable()) {
        return obj.getNext();
      }
      return null;
    }

    // Check if it's a list-like iterator (IndexedIterator or similar)
    if (obj is T3TadsObject) {
      // Get the 'curVal_' property which holds the current index
      // and 'coll_' which holds the collection being iterated
      final curIdxProp = obj.getProperty(1); // curVal_ is typically prop 1
      final collProp = obj.getProperty(2); // coll_ is typically prop 2

      if (curIdxProp != null && curIdxProp.isInt && collProp != null) {
        final currentIdx = curIdxProp.value;
        List<T3Value> elements = [];

        if (collProp.isList) {
          elements = getListValues(collProp);
        } else if (collProp.isObject) {
          final coll = helperObjectTable.lookup(collProp.value);
          if (coll is T3ListObject) elements = coll.elements;
          if (coll is T3VectorObject) elements = coll.elements;
        }

        if (currentIdx <= elements.length) {
          // Get current value and increment index
          final value = elements[currentIdx - 1];
          obj.setProperty(1, T3Value.fromInt(currentIdx + 1));
          return value;
        }
      }
    }

    return null;
  }

  /// Checks if an object is an instance of (or inherits from) a class.
  bool isInstanceOf(int objId, int classId) {
    if (objId == classId) return true;

    final obj = helperObjectTable.lookup(objId);
    if (obj == null) return false;

    if (obj is T3TadsObject) {
      // Check superclasses recursively
      for (final superclassId in obj.superclasses) {
        if (isInstanceOf(superclassId, classId)) return true;
      }
    }

    return false;
  }

  /// Gets the string content of a T3Value (handles constant and dynamic strings).
  String getStringValue(T3Value strVal) {
    if (strVal.type == T3DataType.sstring) {
      // Constant string
      return helperConstantPool!.readString(strVal.value);
    } else if (strVal.type == T3DataType.dstring) {
      // Dynamic string
      if (helperDynamicStrings.containsKey(strVal.value)) {
        return helperDynamicStrings[strVal.value]!;
      }
      return ''; // Unknown dynamic string
    } else if (strVal.type == T3DataType.list) {
      // Use list to string conversion if needed? Or error?
      // For now return empty or meaningful representation?
      return '[List]';
    }
    return '';
  }
}
