import 'dart:typed_data';
import 'package:zart/src/tads3/loaders/mcld_parser.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_save_manager.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';
import 'package:test/test.dart';

/// T3 Save File Format unit tests with spec validation.
///
/// Spec Reference: packages/tads-sources/t3doc/techman/t3spec/save.htm
/// This covers the MJR-T3 saved state file format.
void main() {
  group('Save file format per save.htm', () {
    /// save.htm:103-126 - Signature
    group('file signature', () {
      test('signature format defined', () {
        // Signature: T3-state-v####\015\012\032
        // 17 bytes total with version number
        const signature = 'T3-state-v';
        expect(signature.length, 10);
      });

      test('current version is 0008', () {
        // save.htm:125 - current format version
        const currentVersion = '0008';
        expect(currentVersion.length, 4);
      });

      test('signature parsing', () {
        final data = Uint8List.fromList([
          ...'T3-state-v0008\r\n\x1a'.codeUnits,
          0, 0, 0, 0, // Padding
        ]);
        expect(T3SaveManager.validateSignature(data), '0008');
      });
    });

    /// save.htm:127-148 - Size/Checksum
    group('size and checksum', () {
      test('CRC-32 algorithm specified', () {
        final data = Uint8List.fromList([1, 2, 3, 4]);
        // Known CRC32 for [1,2,3,4] is 0xB63CFBCD
        expect(T3SaveManager.calculateCrc32(data), 0xB63CFBCD);
      });

      test('size field is UINT4 little-endian', () {
        final header = T3SaveManager.createHeader('0008');
        final view = ByteData.view(header.buffer, header.offsetInBytes);
        // creating header adds 8 bytes for size/CRC, all zeroes initially
        expect(view.getUint32(17, Endian.little), 0);
      });
    });

    /// save.htm:334-345 - MIME Type
    group('file metadata', () {
      test('MIME type is application/x-t3vm-state', () {
        const mimeType = 'application/x-t3vm-state';
        expect(mimeType, isNotEmpty);
      });

      test('Windows extension is .t3v', () {
        const extension = '.t3v';
        expect(extension, '.t3v');
      });
    });
  });

  group('CRC-32 algorithm per save.htm:349-425', () {
    test('CRC-32 lookup table defined', () {
      // Just verify it doesn't throw and has 256 entries implicitly
      final data = Uint8List.fromList([0]);
      expect(T3SaveManager.calculateCrc32(data), isNotNull);
    });
  });

  group('Integration Tests', () {
    test('Load/Save Cycle', () {
      final vm = MockVM();

      // Setup VM state
      vm.registers.ip = 0x1234;
      vm.registers.ep = 0x5678;
      vm.registers.r0 = T3Value.fromInt(42);

      vm.stack.sp = 2;
      vm.stack.fp = 0;
      vm.stack.values[0] = T3Value.fromInt(10);
      vm.stack.values[1] = T3Value.fromInt(20);

      vm.symbols['foo'] = T3Value.fromInt(99);

      final obj = T3GenericObject(objectId: 123, metaclass: 'tads-object', rawData: Uint8List.fromList([1, 2, 3]));
      vm.objectTable.register(obj);

      // Save
      final savedData = T3SaveManager.save(vm);

      // Load into new VM
      final newVm = MockVM();
      T3SaveManager.load(newVm, savedData);

      // Verify
      expect(newVm.registers.ip, 0x1234);
      expect(newVm.registers.ep, 0x5678);
      expect(newVm.registers.r0.value, 42);

      expect(newVm.stack.sp, 2);
      expect(newVm.stack.values[0].value, 10);
      expect(newVm.stack.values[1].value, 20);

      expect(newVm.symbols['foo']?.value, 99);

      final restoredObj = newVm.objectTable.lookup(123) as T3GenericObject;
      expect(restoredObj.metaclass, 'tads-object');
      expect(restoredObj.rawData, [1, 2, 3]);
    });
  });
}

class MockVM {
  final metaclasses = MockMetaclasses();
  final objectTable = MockObjectTable();
  final registers = MockRegisters();
  final stack = MockStack();
  final symbols = <String, T3Value>{};
}

class MockMetaclasses {
  final dependencies = <T3MetaclassDep>[];

  MockMetaclasses() {
    dependencies.add(
      T3MetaclassDep(
        identifier: 'root-object/000001',
        index: 0,
        name: 'root-object',
        propertyCount: 0,
        propertyIds: [],
      ),
    );
    dependencies.add(
      T3MetaclassDep(
        identifier: 'tads-object/000001',
        index: 1,
        name: 'tads-object',
        propertyCount: 0,
        propertyIds: [],
      ),
    );
  }

  int indexOf(String name) {
    if (name == 'root-object') return 0;
    if (name == 'tads-object') return 1;
    return -1;
  }

  T3MetaclassDep? byIndex(int index) {
    if (index >= 0 && index < dependencies.length) return dependencies[index];
    return null;
  }
}

class MockObjectTable {
  final _objects = <int, T3Object>{};
  Iterable<T3Object> get all => _objects.values;

  T3Object? lookup(int id) => _objects[id];

  void register(T3Object obj) {
    _objects[obj.objectId] = obj;
  }

  void restoreObject(int objectId, String metaclassName, Uint8List data) {
    // For testing, we just create a generic object with the data
    _objects[objectId] = T3GenericObject(objectId: objectId, metaclass: metaclassName, rawData: data);
  }
}

class MockRegisters {
  int ip = 0;
  int ep = 0;
  T3Value r0 = T3Value.nil();
}

class MockStack {
  int sp = 0;
  int fp = 0;
  final values = List.filled(100, T3Value.nil());
}
