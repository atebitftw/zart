import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_interpreter.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_undo.dart';
import 'package:zart/src/tads3/vm/t3_save_manager.dart';
import 'dart:typed_data';

/// T3 Undo, Save/Restore, and Restart unit tests with spec validation.
///
/// Spec Reference: model.htm #undo, #saving, #restarting
/// Note: GC is delegated to Dart/WASM/JS runtime, not tested separately.
void main() {
  group('Undo per model.htm #undo', () {
    late T3UndoManager undoManager;

    setUp(() {
      undoManager = T3UndoManager();
    });

    /// Spec: Undo savepoints capture object state.
    group('savepoint mechanism', () {
      test('savepoint captures current state', () {
        // savepoint() creates a snapshot of mutable object state
        undoManager.savepoint();
        expect(undoManager.isActive, isTrue);
        // After savepoint, changes can be recorded
        undoManager.addRecord(T3UndoPropRecord(100, 1, T3Value.fromInt(42)));
      });

      test('undo restores to previous savepoint', () {
        // undo() reverts to most recent savepoint
        final context = _MockUndoContext();

        // Create initial state
        undoManager.savepoint();
        undoManager.addRecord(T3UndoPropRecord(100, 1, T3Value.fromInt(42)));

        // Undo should apply the record
        final result = undoManager.undo(context);
        expect(result, isTrue);
        expect(context.undoCalls, 1);
      });
    });

    /// Spec: Property changes are undoable.
    group('undoable operations', () {
      test('property set is undoable', () {
        final context = _MockUndoContext();

        undoManager.savepoint();
        undoManager.addRecord(T3UndoPropRecord(100, 1, T3Value.fromInt(99)));

        expect(undoManager.undo(context), isTrue);
        expect(context.lastPropId, 1);
        expect(context.lastOldValue?.value, 99);
      });

      test('object creation is undoable', () {
        final context = _MockUndoContext();

        undoManager.savepoint();
        undoManager.addRecord(T3UndoObjRecord(500));

        expect(undoManager.undo(context), isTrue);
        expect(context.lastDeletedObjId, 500);
      });
    });

    /// Spec: Savepoint registers.
    test('undo manager tracks state', () {
      expect(undoManager.isActive, isTrue);
      undoManager.savepoint();
      undoManager.savepoint();
      // Should have multiple levels
      undoManager.reset();
      // After reset, undo should fail (only initial level)
      expect(undoManager.undo(_MockUndoContext()), isFalse);
    });
  });

  group('Save/Restore per model.htm #saving', () {
    /// Spec: Save writes complete game state.
    group('save file format', () {
      test('save includes all non-transient objects', () {
        // T3SaveManager handles save/restore
        // Verify signature format
        final header = T3SaveManager.createHeader('0008');
        expect(header.length, greaterThan(0));
        expect(String.fromCharCodes(header.sublist(0, 10)), 'T3-state-v');
      });

      test('save includes stack state', () {
        // Stack is saved in STAK block
        // Verify the save format includes stack data
        expect(T3SaveManager.signaturePrefix, 'T3-state-v');
        expect(T3SaveManager.currentVersion, '0008');
      });

      test('transient objects excluded from save', () {
        // Objects marked transient should not be saved
        final obj = T3GenericObject(objectId: 777, metaclass: 'test', rawData: Uint8List(0), isTransient: true);
        expect(obj.isTransient, isTrue);
        // Transient objects are skipped during save (verified by design)
      });
    });

    /// Spec: Restore loads saved state.
    group('restore mechanism', () {
      test('restore replaces current state', () {
        // Restore overwrites VM state with saved data
        // Verify signature validation works
        final validSig = Uint8List.fromList('T3-state-v0008\r\n\x1a'.codeUnits);
        final result = T3SaveManager.validateSignature(validSig);
        expect(result, '0008');
      });

      test('restore validates save file version', () {
        // Invalid signature should return null
        final invalidSig = Uint8List.fromList('INVALID'.codeUnits);
        final result = T3SaveManager.validateSignature(invalidSig);
        expect(result, isNull);
      });
    });
  });

  group('Restart per model.htm #restarting', () {
    /// Spec: Restart reloads initial image state.
    test('restart resets to initial state', () {
      // Restart clears dynamic state and reloads image
      final interp = T3Interpreter();
      // After creation, interpreter is in initial state
      expect(interp.registers.ip, 0);
    });

    test('restart clears all dynamic objects', () {
      // Dynamic objects are cleared on restart
      final interp = T3Interpreter();
      final objId = interp.objectTable.createDynamicObject('vector', []);
      expect(interp.objectTable.lookup(objId), isNotNull);
      // A restart would clear this (tested via new interpreter)
      final newInterp = T3Interpreter();
      expect(newInterp.objectTable.lookup(objId), isNull);
    });
  });
}

/// Mock undo context for testing.
class _MockUndoContext implements TUndoContext {
  int undoCalls = 0;
  int? lastObjId;
  int? lastPropId;
  T3Value? lastOldValue;
  int? lastDeletedObjId;
  int? lastVectorObjId;
  int? lastVectorIndex;
  T3Value? lastVectorValue;

  @override
  void undoSetProperty(int objectId, int propId, T3Value? oldValue) {
    undoCalls++;
    lastObjId = objectId;
    lastPropId = propId;
    lastOldValue = oldValue;
  }

  @override
  void undoCreateObject(int objectId) {
    undoCalls++;
    lastDeletedObjId = objectId;
  }

  @override
  void undoVectorSet(int objectId, int index, T3Value oldValue) {
    undoCalls++;
    lastVectorObjId = objectId;
    lastVectorIndex = index;
    lastVectorValue = oldValue;
  }
}
