// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_func.dart';

void main() {
  group('Constants', () {
    test('vmFuncHdrMinSize is correct', () {
      expect(vmFuncHdrMinSize, equals(10));
    });

    test('vmExcEntrySize is correct', () {
      expect(vmExcEntrySize, equals(10));
    });
  });

  group('T3FuncHeader', () {
    group('basic parsing', () {
      test('parses argc correctly', () {
        // argc=3, optArgc=0, locals=0, stack=0, excOfs=0, debugOfs=0
        final data = Uint8List.fromList([3, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
        final header = T3FuncHeader.fromData(data);

        expect(header.minArgc, equals(3));
        expect(header.maxArgc, equals(3));
        expect(header.isVarargs, isFalse);
      });

      test('parses optional argc correctly', () {
        // argc=2, optArgc=3, locals=0, stack=0, excOfs=0, debugOfs=0
        final data = Uint8List.fromList([2, 3, 0, 0, 0, 0, 0, 0, 0, 0]);
        final header = T3FuncHeader.fromData(data);

        expect(header.minArgc, equals(2));
        expect(header.optArgc, equals(3));
        expect(header.maxArgc, equals(5));
      });

      test('parses varargs correctly', () {
        // argc=0x82 (varargs + min 2), optArgc=0
        final data = Uint8List.fromList([0x82, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
        final header = T3FuncHeader.fromData(data);

        expect(header.minArgc, equals(2));
        expect(header.isVarargs, isTrue);
      });

      test('parses local count correctly', () {
        // locals = 0x0105 = 261 (little-endian)
        final data = Uint8List.fromList([0, 0, 0x05, 0x01, 0, 0, 0, 0, 0, 0]);
        final header = T3FuncHeader.fromData(data);

        expect(header.localCnt, equals(261));
      });

      test('parses stack depth correctly', () {
        // stack = 0x0200 = 512 (little-endian)
        final data = Uint8List.fromList([0, 0, 0, 0, 0x00, 0x02, 0, 0, 0, 0]);
        final header = T3FuncHeader.fromData(data);

        expect(header.stackDepth, equals(512));
      });

      test('parses exception table offset correctly', () {
        // excOfs = 0x0014 = 20 (little-endian)
        final data = Uint8List.fromList([0, 0, 0, 0, 0, 0, 0x14, 0x00, 0, 0]);
        final header = T3FuncHeader.fromData(data);

        expect(header.excOfs, equals(20));
        expect(header.hasExcTable, isTrue);
      });

      test('parses debug records offset correctly', () {
        // debugOfs = 0x002A = 42 (little-endian)
        final data = Uint8List.fromList([0, 0, 0, 0, 0, 0, 0, 0, 0x2A, 0x00]);
        final header = T3FuncHeader.fromData(data);

        expect(header.debugOfs, equals(42));
        expect(header.hasDebugRecords, isTrue);
      });

      test('hasExcTable returns false when offset is 0', () {
        final data = Uint8List.fromList([0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
        final header = T3FuncHeader.fromData(data);

        expect(header.hasExcTable, isFalse);
      });

      test('hasDebugRecords returns false when offset is 0', () {
        final data = Uint8List.fromList([0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
        final header = T3FuncHeader.fromData(data);

        expect(header.hasDebugRecords, isFalse);
      });

      test('codeOffset returns header size', () {
        final data = Uint8List.fromList([0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
        final header = T3FuncHeader.fromData(data);

        expect(header.codeOffset, equals(10));
      });

      test('handles non-zero base offset', () {
        // Header at offset 5
        final data = Uint8List.fromList([
          0, 0, 0, 0, 0, // padding
          4, 2, 0x10, 0x00, 0x20, 0x00, 0, 0, 0, 0, // header
        ]);
        final header = T3FuncHeader(data, 5);

        expect(header.minArgc, equals(4));
        expect(header.optArgc, equals(2));
        expect(header.localCnt, equals(16));
        expect(header.stackDepth, equals(32));
        expect(header.codeOffset, equals(15));
      });
    });

    group('argcOk', () {
      test('accepts exact match for non-varargs', () {
        final data = Uint8List.fromList([3, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
        final header = T3FuncHeader.fromData(data);

        expect(header.argcOk(3), isTrue);
        expect(header.argcOk(2), isFalse);
        expect(header.argcOk(4), isFalse);
      });

      test('accepts range for optional args', () {
        // min=2, opt=2, so valid range is 2-4
        final data = Uint8List.fromList([2, 2, 0, 0, 0, 0, 0, 0, 0, 0]);
        final header = T3FuncHeader.fromData(data);

        expect(header.argcOk(1), isFalse);
        expect(header.argcOk(2), isTrue);
        expect(header.argcOk(3), isTrue);
        expect(header.argcOk(4), isTrue);
        expect(header.argcOk(5), isFalse);
      });

      test('accepts any count >= min for varargs', () {
        // varargs with min=1
        final data = Uint8List.fromList([0x81, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
        final header = T3FuncHeader.fromData(data);

        expect(header.argcOk(0), isFalse);
        expect(header.argcOk(1), isTrue);
        expect(header.argcOk(5), isTrue);
        expect(header.argcOk(100), isTrue);
      });

      test('handles zero-arg functions', () {
        final data = Uint8List.fromList([0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
        final header = T3FuncHeader.fromData(data);

        expect(header.argcOk(0), isTrue);
        expect(header.argcOk(1), isFalse);
      });

      test('handles varargs with optional', () {
        // varargs with min=1, opt=2, so valid: 1, 2, 3, 4, 5, ...
        final data = Uint8List.fromList([0x81, 2, 0, 0, 0, 0, 0, 0, 0, 0]);
        final header = T3FuncHeader.fromData(data);

        expect(header.argcOk(0), isFalse);
        expect(header.argcOk(1), isTrue);
        expect(header.argcOk(3), isTrue);
        expect(header.argcOk(10), isTrue);
      });
    });
  });

  group('T3ExcEntry', () {
    test('parses entry fields correctly', () {
      // startOfs=0x0010, endOfs=0x0020, excClass=0x00001234, handlerOfs=0x0030
      final data = Uint8List.fromList([
        0x10, 0x00, // startOfs
        0x20, 0x00, // endOfs
        0x34, 0x12, 0x00, 0x00, // exceptionClass
        0x30, 0x00, // handlerOfs
      ]);
      final entry = T3ExcEntry(data, 0);

      expect(entry.startOfs, equals(16));
      expect(entry.endOfs, equals(32));
      expect(entry.exceptionClass, equals(0x1234));
      expect(entry.handlerOfs, equals(48));
    });

    test('coversOffset works correctly', () {
      final data = Uint8List.fromList([
        0x10, 0x00, // startOfs = 16
        0x20, 0x00, // endOfs = 32
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00,
      ]);
      final entry = T3ExcEntry(data, 0);

      expect(entry.coversOffset(15), isFalse);
      expect(entry.coversOffset(16), isTrue);
      expect(entry.coversOffset(24), isTrue);
      expect(entry.coversOffset(32), isTrue);
      expect(entry.coversOffset(33), isFalse);
    });
  });

  group('T3ExcTable', () {
    test('parses count correctly', () {
      // count=3
      final data = Uint8List.fromList([0x03, 0x00]);
      final table = T3ExcTable(data, 0);

      expect(table.count, equals(3));
    });

    test('getEntry returns correct entries', () {
      // count=2, followed by 2 entries
      final data = Uint8List.fromList([
        0x02, 0x00, // count
        // Entry 0
        0x10, 0x00, // startOfs
        0x20, 0x00, // endOfs
        0x01, 0x00, 0x00, 0x00, // exceptionClass
        0x30, 0x00, // handlerOfs
        // Entry 1
        0x40, 0x00, // startOfs
        0x50, 0x00, // endOfs
        0x02, 0x00, 0x00, 0x00, // exceptionClass
        0x60, 0x00, // handlerOfs
      ]);
      final table = T3ExcTable(data, 0);

      final entry0 = table.getEntry(0);
      expect(entry0.startOfs, equals(16));
      expect(entry0.exceptionClass, equals(1));

      final entry1 = table.getEntry(1);
      expect(entry1.startOfs, equals(64));
      expect(entry1.exceptionClass, equals(2));
    });

    test('getEntry throws for invalid index', () {
      final data = Uint8List.fromList([0x01, 0x00]);
      final table = T3ExcTable(data, 0);

      expect(() => table.getEntry(-1), throwsRangeError);
      expect(() => table.getEntry(1), throwsRangeError);
    });

    test('fromFuncHeader returns null when no exception table', () {
      final data = Uint8List.fromList([0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
      final header = T3FuncHeader.fromData(data);

      expect(T3ExcTable.fromFuncHeader(header, data), isNull);
    });

    test('fromFuncHeader creates table at correct offset', () {
      // Header with excOfs=10 (pointing right after header)
      // Then exception table with count=1
      final data = Uint8List.fromList([
        0, 0, 0, 0, 0, 0, 0x0A, 0x00, 0, 0, // header (excOfs=10)
        0x01, 0x00, // exception table count=1
        0x00, 0x00, 0x10, 0x00, 0x99, 0x00, 0x00, 0x00, 0x20, 0x00, // entry
      ]);
      final header = T3FuncHeader.fromData(data);
      final table = T3ExcTable.fromFuncHeader(header, data);

      expect(table, isNotNull);
      expect(table!.count, equals(1));
    });

    test('findHandler finds matching entry', () {
      final data = Uint8List.fromList([
        0x02, 0x00, // count
        // Entry 0: covers 16-32, handles class 1
        0x10, 0x00, 0x20, 0x00, 0x01, 0x00, 0x00, 0x00, 0x30, 0x00,
        // Entry 1: covers 64-80, handles class 2
        0x40, 0x00, 0x50, 0x00, 0x02, 0x00, 0x00, 0x00, 0x60, 0x00,
      ]);
      final table = T3ExcTable(data, 0);

      // Find handler for offset 20, class 1
      final found = table.findHandler(20, (classId) => classId == 1);
      expect(found, isNotNull);
      expect(found!.handlerOfs, equals(48));

      // Find handler for offset 70, class 2
      final found2 = table.findHandler(70, (classId) => classId == 2);
      expect(found2, isNotNull);
      expect(found2!.handlerOfs, equals(96));

      // No handler for offset 50 (not in any range)
      final notFound = table.findHandler(50, (classId) => true);
      expect(notFound, isNull);

      // No handler for offset 20 if class doesn't match
      final wrongClass = table.findHandler(20, (classId) => classId == 99);
      expect(wrongClass, isNull);
    });
  });

  group('T3DbgTable', () {
    test('fromFuncHeader returns null when no debug records', () {
      final data = Uint8List.fromList([0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
      final header = T3FuncHeader.fromData(data);

      expect(T3DbgTable.fromFuncHeader(header, data), isNull);
    });

    test('fromFuncHeader creates table when debug records exist', () {
      // Header with debugOfs=10
      final data = Uint8List.fromList([
        0, 0, 0, 0, 0, 0, 0, 0, 0x0A, 0x00, // header (debugOfs=10)
        0x00, 0x00, // some debug data
      ]);
      final header = T3FuncHeader.fromData(data);
      final table = T3DbgTable.fromFuncHeader(header, data);

      expect(table, isNotNull);
      expect(table!.isValid, isTrue);
    });
  });
}
