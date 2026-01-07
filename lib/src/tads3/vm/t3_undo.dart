import 'package:zart/src/tads3/vm/t3_value.dart';

/// Base class for all undoable operations.
abstract class T3UndoRecord {
  void apply(TUndoContext context);
}

/// Interface for applying undo records (implemented by Interpreter/ObjectTable).
abstract class TUndoContext {
  void undoSetProperty(int objectId, int propId, T3Value? oldValue);
  void undoCreateObject(int objectId);
  void undoVectorSet(int objectId, int index, T3Value oldValue);
}

/// Record for a property change on an object.
class T3UndoPropRecord extends T3UndoRecord {
  final int objectId;
  final int propId;
  final T3Value? oldValue;

  T3UndoPropRecord(this.objectId, this.propId, this.oldValue);

  @override
  void apply(TUndoContext context) {
    context.undoSetProperty(objectId, propId, oldValue);
  }
}

/// Record for a dynamic object creation.
class T3UndoObjRecord extends T3UndoRecord {
  final int objectId;

  T3UndoObjRecord(this.objectId);

  @override
  void apply(TUndoContext context) {
    context.undoCreateObject(objectId);
  }
}

/// Record for a vector element change.
class T3UndoVectorRecord extends T3UndoRecord {
  final int objectId;
  final int index;
  final T3Value oldValue;

  T3UndoVectorRecord(this.objectId, this.index, this.oldValue);

  @override
  void apply(TUndoContext context) {
    context.undoVectorSet(objectId, index, oldValue);
  }
}

/// Manages undo levels and records.
class T3UndoManager {
  final List<List<T3UndoRecord>> _levels = [[]];
  bool _active = true;

  /// Whether undo recording is active.
  bool get isActive => _active;
  set isActive(bool value) => _active = value;

  /// Starts a new undo level (savepoint).
  void savepoint() {
    _levels.add([]);
  }

  /// Reverts state to the last savepoint.
  /// Returns true if successful, false if no undo available.
  bool undo(TUndoContext context) {
    if (_levels.length <= 1) return false;

    final records = _levels.removeLast();
    // Apply records in reverse order
    for (var i = records.length - 1; i >= 0; i--) {
      records[i].apply(context);
    }

    return true;
  }

  /// Adds a record to the current undo level.
  void addRecord(T3UndoRecord record) {
    if (_active && _levels.isNotEmpty) {
      _levels.last.add(record);
    }
  }

  /// Clears all undo history.
  void reset() {
    _levels.clear();
    _levels.add([]);
  }
}
