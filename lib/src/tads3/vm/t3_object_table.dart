import 'dart:typed_data';
import 'package:zart/src/tads3/loaders/mcld_parser.dart';
import 'package:zart/src/tads3/loaders/objs_parser.dart';
import 'package:zart/src/tads3/vm/t3_bignumber.dart';
import 'package:zart/src/tads3/vm/t3_date.dart';
import 'package:zart/src/tads3/vm/t3_lookup_table.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_undo.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';
import 'package:zart/src/tads3/vm/t3_regex_pattern.dart';
import 'package:zart/src/tads3/vm/t3_dictionary.dart';
import 'package:zart/src/tads3/vm/t3_grammar_production.dart';
import 'package:zart/src/tads3/vm/t3_file.dart';

/// Result of a property lookup, including the defining object.
class T3PropertyLookupResult {
  /// The property value.
  final T3Value value;

  /// The object ID where the property was found.
  final int definingObjectId;

  T3PropertyLookupResult(this.value, this.definingObjectId);
}

/// Object table for the T3 VM.
///
/// Manages all loaded objects by ID for efficient lookup.
/// Objects are loaded from OBJS blocks in the image file and
/// can also be created dynamically at runtime.
class T3ObjectTable {
  /// Objects indexed by object ID.
  final Map<int, T3Object> _objects = {};

  /// Total number of registered objects.
  int get count => _objects.length;

  /// Returns true if the table is empty.
  bool get isEmpty => _objects.isEmpty;

  /// Returns true if the table is not empty.
  bool get isNotEmpty => _objects.isNotEmpty;

  /// Registers an object in the table.
  ///
  /// Throws if an object with the same ID already exists.
  void register(T3Object obj) {
    if (_objects.containsKey(obj.objectId)) {
      throw StateError('Object ID ${obj.objectId} already exists');
    }
    _objects[obj.objectId] = obj;
  }

  /// Looks up an object by ID.
  ///
  /// Returns null if the object is not found.
  T3Object? lookup(int objectId) => _objects[objectId];

  /// Returns true if an object with the given ID exists.
  bool contains(int objectId) => _objects.containsKey(objectId);

  /// Returns all registered objects.
  Iterable<T3Object> get all => _objects.values;

  /// Returns all object IDs.
  Iterable<int> get allIds => _objects.keys;

  /// Returns objects of a specific metaclass.
  Iterable<T3Object> byMetaclass(String metaclass) =>
      _objects.values.where((obj) => obj.metaclass == metaclass);

  /// Returns count of objects by metaclass.
  Map<String, int> get countByMetaclass {
    final counts = <String, int>{};
    for (final obj in _objects.values) {
      counts[obj.metaclass] = (counts[obj.metaclass] ?? 0) + 1;
    }
    return counts;
  }

  /// Removes an object from the table.
  ///
  /// Returns the removed object, or null if not found.
  T3Object? remove(int objectId) => _objects.remove(objectId);

  /// Clears all objects from the table.
  void clear() => _objects.clear();

  /// Looks up a property on an object with inheritance.
  ///
  /// Searches the object's own properties first, then iterates through
  /// superclasses in order until the property is found.
  ///
  /// Returns null if the property is not defined anywhere in the inheritance
  /// chain.
  T3PropertyLookupResult? lookupProperty(int objectId, int propId) {
    // Track visited objects to avoid cycles
    final visited = <int>{};

    // BFS queue for superclass search
    final queue = <int>[objectId];

    while (queue.isNotEmpty) {
      final currentId = queue.removeAt(0);
      if (visited.contains(currentId)) continue;
      visited.add(currentId);

      final obj = _objects[currentId];
      if (obj == null) continue;

      // Check if this object has the property
      final value = obj.getProperty(propId);
      if (value != null) {
        return T3PropertyLookupResult(value, currentId);
      }

      // Add superclasses to search queue
      if (obj is T3TadsObject) {
        queue.addAll(obj.superclasses.where((sc) => !visited.contains(sc)));
      }
    }

    return null;
  }

  /// Loads objects from a parsed OBJS block.
  ///
  /// Uses the metaclass dependency list to determine the appropriate
  /// object class to instantiate for each object.
  void loadFromObjsBlock(T3ObjsBlock block, T3MetaclassDepList metaclasses) {
    final metaclass = metaclasses.byIndex(block.metaclassIndex);
    final metaclassName = metaclass?.name ?? 'unknown-${block.metaclassIndex}';

    for (final staticObj in block.objects) {
      final obj = _createObject(
        staticObj.objectId,
        metaclassName,
        staticObj.data,
        isTransient: staticObj.isTransient,
      );
      register(obj);
    }
  }

  /// Creates a T3Object from raw data based on metaclass name.
  T3Object _createObject(
    int objectId,
    String metaclassName,
    Uint8List data, {
    bool isTransient = false,
  }) {
    switch (metaclassName) {
      case 'tads-object':
        return T3TadsObject.fromData(objectId, data, isTransient: isTransient);
      case 'string':
        return T3StringObject.fromData(
          objectId,
          data,
          isTransient: isTransient,
        );
      case 'list':
        return T3ListObject.fromData(objectId, data, isTransient: isTransient);
      case 'vector':
        return T3VectorObject.fromData(
          objectId,
          data,
          isTransient: isTransient,
        );
      case 'anon-func-ptr':
        return T3AnonFnObject.fromData(
          objectId,
          data,
          isTransient: isTransient,
        );
      case 'iterator':
        return T3IteratorObject.fromData(
          objectId,
          data,
          isTransient: isTransient,
        );
      case 'lookup-table':
        return T3LookupTable.fromData(objectId, data, isTransient: isTransient);
      case 'string-buffer':
        return T3StringBuffer.fromData(
          objectId,
          data,
          isTransient: isTransient,
        );
      case 'bignumber':
        return T3BigNumber.fromData(objectId, data, isTransient: isTransient);
      case 'date':
        return T3Date.fromData(objectId, data, isTransient: isTransient);
      case 'timezone':
        return T3TimeZone.fromData(objectId, data, isTransient: isTransient);
      case 'regex-pattern':
        return T3RegexPattern.fromData(objectId, data);
      case 'dictionary2':
        return T3Dictionary.fromData(objectId, data);
      case 'grammar-production':
        return T3GrammarProduction.fromData(objectId, data);
      case 'file':
        return T3File.fromData(objectId, data, isTransient: isTransient);
      default:
        // Unknown metaclass - store as generic object
        return T3GenericObject(
          objectId: objectId,
          metaclass: metaclassName,
          rawData: data,
          isTransient: isTransient,
        );
    }
  }

  /// Next object ID for dynamically created objects.
  /// Uses high range to avoid conflicts with static objects.
  int _nextDynamicObjectId = 0x80000000;

  /// Allocates a new object ID without creating an object.
  /// Used when the caller will create the object directly.
  int allocateObjectId() => _nextDynamicObjectId++;

  /// Registers a pre-created object in the table.
  void registerObject(T3Object obj) {
    _objects[obj.objectId] = obj;
  }

  /// Restores an object from saved data.
  ///
  /// This creates the object using _createObject and registers it,
  /// overwriting any existing object with the same ID.
  void restoreObject(int objectId, String metaclassName, Uint8List data) {
    final obj = _createObject(objectId, metaclassName, data);
    _objects[objectId] = obj;
  }

  /// Creates a new dynamic object at runtime.
  ///
  /// This is called by the NEW1/NEW2/TRNEW1/TRNEW2 opcodes.
  /// Returns the new object's ID.
  int createDynamicObject(
    String metaclassName,
    List<T3Value> args, {
    bool isTransient = false,
    T3UndoManager? undoManager,
  }) {
    final objId = _nextDynamicObjectId++;

    if (!isTransient && undoManager != null && undoManager.isActive) {
      undoManager.addRecord(T3UndoObjRecord(objId));
    }

    // Create appropriate object type based on metaclass
    T3Object obj;
    switch (metaclassName) {
      case 'tads-object':
        // For tads-object, first arg (if object) is the superclass
        final superclasses = <int>[];
        if (args.isNotEmpty && args[0].isObject) {
          superclasses.add(args[0].value);
        }
        obj = T3TadsObject(
          objectId: objId,
          superclasses: superclasses,
          loadImageProperties: [],
          flags: 0,
          isTransient: isTransient,
        );
        break;
      case 'list':
        // Create a list from the constructor arguments
        obj = T3ListObject(
          objectId: objId,
          elements: args,
          isTransient: isTransient,
        );
        break;
      case 'vector':
        // Create a vector from the constructor arguments
        // Args are popped in reverse order from stack, so:
        // - For Vector(capacity): args = [capacity]
        // - For Vector(capacity, fillCount): args = [fillCount, capacity]
        // - For Vector(sourceList): args = [sourceList]
        int allocatedSize = 10;
        var elements = <T3Value>[];

        if (args.isNotEmpty) {
          // Handle Vector constructor patterns:
          // TADS pushes args left-to-right: first arg ends up at stack top
          // Our pop gives: args[0]=first param, args[1]=second param
          // - Vector(capacity): args = [capacity]
          // - Vector(capacity, fillCount): args = [capacity, fillCount] (both ints)
          // - Vector(sourceList): args = [sourceList]
          // - Vector(capacity, sourceList): args = [capacity, sourceList]

          if (args.length >= 2 &&
              args[0].type == T3DataType.int_ &&
              args[1].type == T3DataType.int_) {
            // Vector(capacity, fillCount) - fill with nil elements
            // args[0] = capacity (first param), args[1] = fillCount (second param)
            allocatedSize = args[0].value;
            final fillCount = args[1].value;
            for (var i = 0; i < fillCount; i++) {
              elements.add(T3Value.nil());
            }
            if (allocatedSize < fillCount) allocatedSize = fillCount;
          } else if (args.length >= 2 &&
              args[0].type == T3DataType.int_ &&
              (args[1].isList || args[1].isObject)) {
            // Vector(capacity, sourceList)
            // args[0] = capacity, args[1] = sourceList
            allocatedSize = args[0].value;
            if (args[1].isList) {
              elements = _getListElements(args[1]);
            } else {
              final sourceObj = lookup(args[1].value);
              if (sourceObj is T3VectorObject) {
                elements = sourceObj.elements.map((e) => e.copy()).toList();
              } else if (sourceObj is T3ListObject) {
                elements = sourceObj.elements.map((e) => e.copy()).toList();
              }
            }
            if (allocatedSize < elements.length)
              allocatedSize = elements.length;
          } else if (args[0].type == T3DataType.int_) {
            // Vector(capacity) - capacity only, no elements
            allocatedSize = args[0].value;
          } else if (args[0].isList || args[0].isObject) {
            // Vector(sourceList) - single source list/object
            if (args[0].isList) {
              elements = _getListElements(args[0]);
            } else {
              final sourceObj = lookup(args[0].value);
              if (sourceObj is T3VectorObject) {
                elements = sourceObj.elements.map((e) => e.copy()).toList();
              } else if (sourceObj is T3ListObject) {
                elements = sourceObj.elements.map((e) => e.copy()).toList();
              }
            }
            allocatedSize = elements.length;
          }
        }

        obj = T3VectorObject(
          objectId: objId,
          elements: elements,
          allocatedSize: allocatedSize,
          isTransient: isTransient,
        );
        break;
      case 'anon-func-ptr':
        // Create an anonymous function object (inherits from Vector)
        obj = T3AnonFnObject(
          objectId: objId,
          elements: args,
          allocatedSize: args.length,
          isTransient: isTransient,
        );
        break;
      case 'lookup-table':
      case 'lookuptable': // Handle both standard and potentially alternate forms if needed, but 'lookuptable' is the image spec form.
        int bucketCount = 32;
        if (args.isNotEmpty && args[0].isInt) {
          bucketCount = args[0].value;
        }
        obj = T3LookupTable(
          objectId: objId,
          bucketCount: bucketCount,
          isTransient: isTransient,
        );
        break;
      case 'string-buffer':
      case 'stringbuffer':
        int alloc = 256;
        int incr = 256;
        // args[0] is stack top (last arg), args[1] is second to last (first arg)...
        // StringBuffer(alloc, incr) -> push alloc, push incr. args=[incr, alloc]
        if (args.length >= 2 && args[0].isInt && args[1].isInt) {
          incr = args[0].value;
          alloc = args[1].value;
        } else if (args.isNotEmpty && args[0].isInt) {
          alloc = args[0].value;
        }
        obj = T3StringBuffer(
          objectId: objId,
          allocatedSize: alloc,
          increment: incr,
          isTransient: isTransient,
        );
        break;
      case 'bignumber':
        // new BigNumber(val) or new BigNumber(str) or new BigNumber()
        // We'll create a default one for now as we don't fully parse args yet.
        // TODO: Parse constructor args to set initial value/precision
        obj = T3BigNumber.create(objId, isTransient: isTransient);
        break;
      case 'date':
        obj = T3Date.create(objId, isTransient: isTransient);
        break;
      case 'timezone':
        obj = T3TimeZone.create(objId, isTransient: isTransient);
        break;
      case 'regex-pattern':
        T3Value val = T3Value.nil();
        if (args.isNotEmpty) val = args[0];
        obj = T3RegexPattern.create(objId, val);
        break;
      case 'dictionary2':
      case 'dictionary':
        obj = T3Dictionary.create(objId);
        break;
      case 'grammar-production':
        obj = T3GrammarProduction.create(objId);
        break;
      case 'file':
        obj = T3File.create(objId);
        break;
      case 'iterator':
        // Collection is passed as first argument, remaining args are the snapshot elements
        final collection = args.isNotEmpty ? args[0] : T3Value.nil();
        final elements = args.length > 1 ? args.sublist(1) : <T3Value>[];
        obj = T3IteratorObject(
          objectId: objId,
          collection: collection,
          elements: elements,
          isTransient: isTransient,
        );
        break;
      default:
        // Unknown metaclass - create as generic object
        obj = T3GenericObject(
          objectId: objId,
          metaclass: metaclassName,
          rawData: Uint8List(0),
          isTransient: isTransient,
        );
    }

    _objects[objId] = obj;
    return objId;
  }

  /// Helper to extract elements from a list-type T3Value.
  ///
  /// Handles both pool-based list references and list object references.
  List<T3Value> _getListElements(T3Value listValue) {
    if (listValue.isObject) {
      final obj = lookup(listValue.value);
      if (obj is T3ListObject) {
        return obj.elements.map((e) => e.copy()).toList();
      }
    }
    // For pool list or empty case, return empty list
    // The caller should handle pool list lookup via constant pool if needed
    return <T3Value>[];
  }

  @override
  String toString() => 'T3ObjectTable($count objects)';

  /// Returns a summary of the object table for debugging.
  String get summary {
    final buffer = StringBuffer();
    buffer.writeln('T3ObjectTable: $count objects');
    final counts = countByMetaclass;
    for (final entry in counts.entries) {
      buffer.writeln('  ${entry.key}: ${entry.value}');
    }
    return buffer.toString();
  }
}
