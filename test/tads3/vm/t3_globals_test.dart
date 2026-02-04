// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Unit tests for TADS3 VM Globals
///
/// Tests the T3Globals class which holds all VM global state.
library;

import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_globals.dart';
import 'package:zart/src/tads3/vm/t3_metaclass_table.dart';
import 'package:zart/src/tads3/vm/t3_object_table.dart';
import 'package:zart/src/tads3/vm/t3_pool.dart';
import 'package:zart/src/tads3/vm/t3_stack.dart';

/// Mock backing store for pool testing
class MockBackingStore extends T3PoolBackingStore {
  final Map<int, Uint8List> _pages = {};
  final int _pageSize;
  final int _pageCount;

  MockBackingStore({int pageSize = 1024, int pageCount = 4})
    : _pageSize = pageSize,
      _pageCount = pageCount;

  @override
  int getPageCount() => _pageCount;

  @override
  int getCommonPageSize() => _pageSize;

  @override
  int getPageSize(PoolOffset offset, int pageSize) => _pageSize;

  @override
  Uint8List allocAndLoadPage(PoolOffset offset, int pageSize, int loadSize) {
    // PoolOffset is just an int typedef, use it directly as a page index
    final pageIndex = offset ~/ _pageSize;
    final page = Uint8List(pageSize);
    _pages[pageIndex] = page;
    return page;
  }

  @override
  void freePage(Uint8List mem, PoolOffset offset, int pageSize) {
    final pageIndex = offset ~/ _pageSize;
    _pages.remove(pageIndex);
  }

  @override
  void loadPage(PoolOffset offset, int pageSize, int loadSize, Uint8List mem) {}

  @override
  bool isWritable() => false;
}

void main() {
  group('T3Globals - Initialization', () {
    test('creates with core subsystem fields mostly null', () {
      final globals = T3Globals();

      expect(globals.constPool, isNull);
      expect(globals.codePool, isNull);
      expect(globals.stack, isNull);
      expect(globals.objTable, isNull);

      // metaTable should be initialized with standard metaclasses
      expect(globals.metaTable, isNotNull);
      expect(globals.metaTable!.count, greaterThan(0));
    });

    test('creates with scalar fields at default values', () {
      final globals = T3Globals();

      expect(globals.preinitMode, isFalse);
      expect(globals.excEntrySize, equals(0));
      expect(globals.lineEntrySize, equals(0));
      expect(globals.dbgHdrSize, equals(0));
      expect(globals.dbgLclsymHdrSize, equals(0));
      expect(globals.dbgFmtVsn, equals(0));
      expect(globals.dbgFrameSize, equals(0));
      expect(globals.iterGetNext, equals(0));
      expect(globals.iterNextAvail, equals(0));
      expect(globals.filePath, isNull);
      expect(globals.sandboxPath, isNull);
      expect(globals.syslogfile, isNull);
    });
  });

  group('T3Globals - Pool Assignment', () {
    test('assigns constPool', () {
      final globals = T3Globals();
      final backing = MockBackingStore();
      final pool = T3PoolInMem();
      pool.attachBackingStore(backing);

      globals.constPool = pool;

      expect(globals.constPool, isNotNull);
      expect(globals.constPool, same(pool));
    });

    test('assigns codePool', () {
      final globals = T3Globals();
      final backing = MockBackingStore();
      final pool = T3PoolInMem();
      pool.attachBackingStore(backing);

      globals.codePool = pool;

      expect(globals.codePool, isNotNull);
      expect(globals.codePool, same(pool));
    });
  });

  group('T3Globals - Stack Assignment', () {
    test('assigns stack', () {
      final globals = T3Globals();
      final stack = T3Stack(1024, 64); // maxDepth, reserveDepth

      globals.stack = stack;

      expect(globals.stack, isNotNull);
      expect(globals.stack, same(stack));
    });
  });

  group('T3Globals - Object System Assignment', () {
    test('assigns objTable', () {
      final globals = T3Globals();
      final objTable = T3ObjectTable();

      globals.objTable = objTable;

      expect(globals.objTable, isNotNull);
      expect(globals.objTable, same(objTable));
    });

    test('assigns metaTable', () {
      final globals = T3Globals();
      final metaTable = T3MetaclassTable();

      globals.metaTable = metaTable;

      expect(globals.metaTable, isNotNull);
      expect(globals.metaTable, same(metaTable));
    });
  });

  group('T3Globals - Scalar Field Assignment', () {
    test('sets preinitMode', () {
      final globals = T3Globals();

      globals.preinitMode = true;

      expect(globals.preinitMode, isTrue);
    });

    test('sets debug-related sizes', () {
      final globals = T3Globals();

      globals.excEntrySize = 10;
      globals.lineEntrySize = 4;
      globals.dbgHdrSize = 8;
      globals.dbgLclsymHdrSize = 6;
      globals.dbgFmtVsn = 2;
      globals.dbgFrameSize = 12;

      expect(globals.excEntrySize, equals(10));
      expect(globals.lineEntrySize, equals(4));
      expect(globals.dbgHdrSize, equals(8));
      expect(globals.dbgLclsymHdrSize, equals(6));
      expect(globals.dbgFmtVsn, equals(2));
      expect(globals.dbgFrameSize, equals(12));
    });

    test('sets iterator property IDs', () {
      final globals = T3Globals();

      globals.iterGetNext = 100;
      globals.iterNextAvail = 101;

      expect(globals.iterGetNext, equals(100));
      expect(globals.iterNextAvail, equals(101));
    });

    test('sets path strings', () {
      final globals = T3Globals();

      globals.filePath = '/path/to/game';
      globals.sandboxPath = '/sandbox';
      globals.syslogfile = 'debug.log';

      expect(globals.filePath, equals('/path/to/game'));
      expect(globals.sandboxPath, equals('/sandbox'));
      expect(globals.syslogfile, equals('debug.log'));
    });
  });

  group('T3Globals - Dispose', () {
    test('dispose on fresh instance does not throw', () {
      final globals = T3Globals();

      expect(() => globals.dispose(), returnsNormally);
    });

    test('dispose nulls out all subsystem references', () {
      final globals = T3Globals();
      globals.stack = T3Stack(1024, 64);
      globals.objTable = T3ObjectTable();
      globals.metaTable = T3MetaclassTable();

      globals.dispose();

      expect(globals.constPool, isNull);
      expect(globals.codePool, isNull);
      expect(globals.stack, isNull);
      expect(globals.objTable, isNull);
      expect(globals.metaTable, isNull);
    });

    test('dispose terminates pools', () {
      final globals = T3Globals();
      final constBacking = MockBackingStore();
      final codeBacking = MockBackingStore();

      final constPool = T3PoolInMem();
      constPool.attachBackingStore(constBacking);
      globals.constPool = constPool;

      final codePool = T3PoolInMem();
      codePool.attachBackingStore(codeBacking);
      globals.codePool = codePool;

      // Should not throw and should null out pools
      globals.dispose();

      expect(globals.constPool, isNull);
      expect(globals.codePool, isNull);
    });

    test('dispose can be called multiple times', () {
      final globals = T3Globals();
      globals.stack = T3Stack(1024, 64);

      globals.dispose();
      expect(() => globals.dispose(), returnsNormally);
    });
  });

  group('T3Globals - Full Integration', () {
    test('can initialize all subsystems', () {
      final globals = T3Globals();

      // Set up pools
      final constBacking = MockBackingStore();
      final constPool = T3PoolInMem();
      constPool.attachBackingStore(constBacking);
      globals.constPool = constPool;

      final codeBacking = MockBackingStore();
      final codePool = T3PoolInMem();
      codePool.attachBackingStore(codeBacking);
      globals.codePool = codePool;

      // Set up stack
      globals.stack = T3Stack(2048, 128);

      // Set up object system
      globals.objTable = T3ObjectTable();
      globals.metaTable = T3MetaclassTable();

      // Set scalar values
      globals.preinitMode = false;
      globals.excEntrySize = 10;
      globals.filePath = '/games/mygame.t3';

      // Verify all are set
      expect(globals.constPool, isNotNull);
      expect(globals.codePool, isNotNull);
      expect(globals.stack, isNotNull);
      expect(globals.objTable, isNotNull);
      expect(globals.metaTable, isNotNull);
      expect(globals.filePath, equals('/games/mygame.t3'));

      // Clean up
      globals.dispose();
    });

    test('multiple independent T3Globals instances are isolated', () {
      final globals1 = T3Globals();
      final globals2 = T3Globals();

      globals1.preinitMode = true;
      globals1.filePath = '/game1';

      globals2.preinitMode = false;
      globals2.filePath = '/game2';

      expect(globals1.preinitMode, isTrue);
      expect(globals2.preinitMode, isFalse);
      expect(globals1.filePath, equals('/game1'));
      expect(globals2.filePath, equals('/game2'));
    });
  });
}
