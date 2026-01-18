// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_bif.dart';
import 'package:zart/src/tads3/vm/t3_error.dart';
import 'package:zart/src/tads3/vm/t3_func.dart';

void main() {
  group('T3BifDesc', () {
    test('creates descriptor with correct values', () {
      final desc = T3BifDesc(minArgc: 2, optArgc: 3, varargs: true);

      expect(desc.minArgc, equals(2));
      expect(desc.optArgc, equals(3));
      expect(desc.varargs, isTrue);
      expect(desc.maxArgc, equals(5));
    });

    test('creates descriptor with defaults', () {
      final desc = T3BifDesc(minArgc: 1);

      expect(desc.minArgc, equals(1));
      expect(desc.optArgc, equals(0));
      expect(desc.varargs, isFalse);
      expect(desc.maxArgc, equals(1));
    });

    test('synthHdr has correct size', () {
      final desc = T3BifDesc(minArgc: 0);
      expect(desc.synthHdr.length, equals(vmFuncHdrMinSize));
    });

    test('synthHdr encodes argc correctly for non-varargs', () {
      final desc = T3BifDesc(minArgc: 5, optArgc: 2);

      // argc byte: 5 (no varargs bit)
      expect(desc.synthHdr[0], equals(5));
      // opt argc byte: 2
      expect(desc.synthHdr[1], equals(2));
    });

    test('synthHdr encodes argc correctly for varargs', () {
      final desc = T3BifDesc(minArgc: 3, varargs: true);

      // argc byte: 3 | 0x80 = 0x83
      expect(desc.synthHdr[0], equals(0x83));
    });

    group('argcOk', () {
      test('validates exact match for non-varargs', () {
        final desc = T3BifDesc(minArgc: 2);

        expect(desc.argcOk(1), isFalse);
        expect(desc.argcOk(2), isTrue);
        expect(desc.argcOk(3), isFalse);
      });

      test('validates range for optional args', () {
        final desc = T3BifDesc(minArgc: 1, optArgc: 2);

        expect(desc.argcOk(0), isFalse);
        expect(desc.argcOk(1), isTrue);
        expect(desc.argcOk(2), isTrue);
        expect(desc.argcOk(3), isTrue);
        expect(desc.argcOk(4), isFalse);
      });

      test('validates any count >= min for varargs', () {
        final desc = T3BifDesc(minArgc: 1, varargs: true);

        expect(desc.argcOk(0), isFalse);
        expect(desc.argcOk(1), isTrue);
        expect(desc.argcOk(5), isTrue);
        expect(desc.argcOk(100), isTrue);
      });
    });

    test('setBifPtr sets pointer values', () {
      final desc = T3BifDesc(minArgc: 0);
      desc.setBifPtr(2, 5);

      expect(desc.bifPtrSetIdx, equals(2));
      expect(desc.bifPtrFuncIdx, equals(5));
    });
  });

  group('T3BifEntry', () {
    test('creates entry with correct values', () {
      final funcs = [T3BifDesc(minArgc: 0), T3BifDesc(minArgc: 1), T3BifDesc(minArgc: 2)];
      final entry = T3BifEntry(funcSetId: 'test-set/010000', functions: funcs);

      expect(entry.funcSetId, equals('test-set/010000'));
      expect(entry.funcCount, equals(3));
    });

    test('linkToImage sets bifptr values', () {
      final funcs = [T3BifDesc(minArgc: 0), T3BifDesc(minArgc: 1)];
      final entry = T3BifEntry(funcSetId: 'test-set', functions: funcs);

      entry.linkToImage(3);

      expect(funcs[0].bifPtrSetIdx, equals(3));
      expect(funcs[0].bifPtrFuncIdx, equals(0));
      expect(funcs[1].bifPtrSetIdx, equals(3));
      expect(funcs[1].bifPtrFuncIdx, equals(1));
    });

    test('linkToImage calls attach callback', () {
      var attachCalled = false;
      final entry = T3BifEntry(funcSetId: 'test-set', functions: [], attach: () => attachCalled = true);

      entry.linkToImage(0);
      expect(attachCalled, isTrue);
    });

    test('unloadImage calls detach callback', () {
      var detachCalled = false;
      final entry = T3BifEntry(funcSetId: 'test-set', functions: [], detach: () => detachCalled = true);

      entry.unloadImage();
      expect(detachCalled, isTrue);
    });
  });

  group('T3BifTable', () {
    test('starts empty', () {
      final table = T3BifTable();
      expect(table.count, equals(0));
    });

    test('addEntry adds and returns index', () {
      final table = T3BifTable();
      final entry = T3BifEntry(funcSetId: 'set1', functions: []);

      final idx = table.addEntry(entry);
      expect(idx, equals(0));
      expect(table.count, equals(1));

      final idx2 = table.addEntry(T3BifEntry(funcSetId: 'set2', functions: []));
      expect(idx2, equals(1));
      expect(table.count, equals(2));
    });

    test('getEntry returns correct entry', () {
      final table = T3BifTable();
      final entry1 = T3BifEntry(funcSetId: 'set1', functions: []);
      final entry2 = T3BifEntry(funcSetId: 'set2', functions: []);

      table.addEntry(entry1);
      table.addEntry(entry2);

      expect(table.getEntry(0), same(entry1));
      expect(table.getEntry(1), same(entry2));
    });

    test('getEntry returns null for invalid index', () {
      final table = T3BifTable();

      expect(table.getEntry(-1), isNull);
      expect(table.getEntry(0), isNull);
      expect(table.getEntry(100), isNull);
    });

    test('getDesc returns function descriptor', () {
      final desc1 = T3BifDesc(minArgc: 1);
      final desc2 = T3BifDesc(minArgc: 2);
      final entry = T3BifEntry(funcSetId: 'set1', functions: [desc1, desc2]);

      final table = T3BifTable();
      table.addEntry(entry);

      expect(table.getDesc(0, 0), same(desc1));
      expect(table.getDesc(0, 1), same(desc2));
    });

    test('getDesc returns null for invalid indices', () {
      final table = T3BifTable();
      table.addEntry(T3BifEntry(funcSetId: 'set1', functions: [T3BifDesc(minArgc: 0)]));

      expect(table.getDesc(-1, 0), isNull);
      expect(table.getDesc(0, -1), isNull);
      expect(table.getDesc(0, 5), isNull);
      expect(table.getDesc(5, 0), isNull);
    });

    test('validateEntry returns true for valid function', () {
      final table = T3BifTable();
      table.addEntry(
        T3BifEntry(
          funcSetId: 'set1',
          functions: [T3BifDesc(minArgc: 0, func: (argc) {})],
        ),
      );

      expect(table.validateEntry(0, 0), isTrue);
    });

    test('validateEntry returns false for missing function', () {
      final table = T3BifTable();
      table.addEntry(
        T3BifEntry(
          funcSetId: 'set1',
          functions: [
            T3BifDesc(minArgc: 0), // No func provided
          ],
        ),
      );

      expect(table.validateEntry(0, 0), isFalse);
    });

    test('validateEntry returns false for invalid indices', () {
      final table = T3BifTable();
      table.addEntry(
        T3BifEntry(
          funcSetId: 'set1',
          functions: [T3BifDesc(minArgc: 0, func: (argc) {})],
        ),
      );

      expect(table.validateEntry(-1, 0), isFalse);
      expect(table.validateEntry(0, -1), isFalse);
      expect(table.validateEntry(5, 0), isFalse);
      expect(table.validateEntry(0, 5), isFalse);
    });

    test('getEntryByName finds entry without version', () {
      final table = T3BifTable();
      final entry = T3BifEntry(funcSetId: 'tads-gen', functions: []);
      table.addEntry(entry);

      expect(table.getEntryByName('tads-gen'), same(entry));
    });

    test('getEntryByName respects version suffix', () {
      final table = T3BifTable();
      final entry = T3BifEntry(funcSetId: 'tads-gen/030000', functions: []);
      table.addEntry(entry);

      // Request older or same version - should succeed
      expect(table.getEntryByName('tads-gen/020000'), same(entry));
      expect(table.getEntryByName('tads-gen/030000'), same(entry));

      // Request newer version - should fail
      expect(table.getEntryByName('tads-gen/040000'), isNull);
    });

    test('clear removes all entries and calls detach', () {
      var detachCalled = false;
      final table = T3BifTable();
      table.addEntry(T3BifEntry(funcSetId: 'set1', functions: [], detach: () => detachCalled = true));

      expect(table.count, equals(1));

      table.clear();
      expect(table.count, equals(0));
      expect(detachCalled, isTrue);
    });
  });

  group('T3BifHelper', () {
    test('checkArgc passes for correct count', () {
      expect(() => T3BifHelper.checkArgc(3, 3), returnsNormally);
    });

    test('checkArgc throws for incorrect count', () {
      expect(
        () => T3BifHelper.checkArgc(2, 3),
        throwsA(isA<T3VmException>().having((e) => e.errorCode, 'errorCode', equals(vmErrWrongNumOfArgs))),
      );
    });

    test('checkArgcRange passes for count in range', () {
      expect(() => T3BifHelper.checkArgcRange(1, 1, 3), returnsNormally);
      expect(() => T3BifHelper.checkArgcRange(2, 1, 3), returnsNormally);
      expect(() => T3BifHelper.checkArgcRange(3, 1, 3), returnsNormally);
    });

    test('checkArgcRange throws for count outside range', () {
      expect(() => T3BifHelper.checkArgcRange(0, 1, 3), throwsA(isA<T3VmException>()));
      expect(() => T3BifHelper.checkArgcRange(4, 1, 3), throwsA(isA<T3VmException>()));
    });
  });
}
