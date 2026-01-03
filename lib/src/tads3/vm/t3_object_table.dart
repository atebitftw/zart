import 'dart:typed_data';

import 'package:zart/src/tads3/loaders/mcld_parser.dart';
import 'package:zart/src/tads3/loaders/objs_parser.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';

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
  Iterable<T3Object> byMetaclass(String metaclass) => _objects.values.where((obj) => obj.metaclass == metaclass);

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
      final obj = _createObject(staticObj.objectId, metaclassName, staticObj.data, isTransient: staticObj.isTransient);
      register(obj);
    }
  }

  /// Creates a T3Object from raw data based on metaclass name.
  T3Object _createObject(int objectId, String metaclassName, Uint8List data, {bool isTransient = false}) {
    switch (metaclassName) {
      case 'tads-object':
        return T3TadsObject.fromData(objectId, data, isTransient: isTransient);
      case 'string':
        return T3StringObject.fromData(objectId, data, isTransient: isTransient);
      case 'list':
        return T3ListObject.fromData(objectId, data, isTransient: isTransient);
      case 'vector':
        return T3VectorObject.fromData(objectId, data, isTransient: isTransient);
      default:
        // Unknown metaclass - store as generic object
        return T3GenericObject(objectId: objectId, metaclass: metaclassName, rawData: data, isTransient: isTransient);
    }
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
