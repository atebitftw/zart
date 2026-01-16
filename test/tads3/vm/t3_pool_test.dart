// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_pool.dart';
import 'package:zart/src/tads3/vm/t3_error.dart';

/// Mock backing store for testing
class MockBackingStore implements T3PoolBackingStore {
  final int pageCount;
  final int pageSize;
  final Map<int, Uint8List> _pages = {};

  MockBackingStore({required this.pageCount, required this.pageSize}) {
    // Pre-populate pages with test data
    for (int i = 0; i < pageCount; i++) {
      final data = Uint8List(pageSize);
      // Fill with pattern: page number repeated
      for (int j = 0; j < pageSize; j++) {
        data[j] = (i * 256 + j) & 0xFF;
      }
      _pages[i * pageSize] = data;
    }
  }

  @override
  int getPageCount() => pageCount;

  @override
  int getCommonPageSize() => pageSize;

  @override
  int getPageSize(PoolOffset offset, int pageSize) {
    // Return full page size for simplicity
    return pageSize;
  }

  @override
  Uint8List allocAndLoadPage(PoolOffset offset, int pageSize, int loadSize) {
    // Return a copy of the page data
    final data = _pages[offset];
    if (data == null) {
      throw Exception('Page not found at offset $offset');
    }
    return Uint8List.fromList(data.sublist(0, loadSize));
  }

  @override
  void freePage(Uint8List mem, PoolOffset offset, int pageSize) {
    // Nothing to do in mock
  }

  @override
  void loadPage(PoolOffset offset, int pageSize, int loadSize, Uint8List mem) {
    final data = _pages[offset];
    if (data == null) {
      throw Exception('Page not found at offset $offset');
    }
    mem.setRange(0, loadSize, data);
  }

  @override
  bool isWritable() => false;
}

void main() {
  group('T3PoolPage', () {
    test('creates with null mem and zero size', () {
      final page = T3PoolPage();
      expect(page.mem, isNull);
      expect(page.size, equals(0));
    });

    test('can set mem and size', () {
      final page = T3PoolPage();
      final data = Uint8List(100);
      page.mem = data;
      page.size = 100;

      expect(page.mem, equals(data));
      expect(page.size, equals(100));
    });
  });

  group('MockBackingStore', () {
    test('returns correct page count', () {
      final store = MockBackingStore(pageCount: 5, pageSize: 1024);
      expect(store.getPageCount(), equals(5));
    });

    test('returns correct page size', () {
      final store = MockBackingStore(pageCount: 5, pageSize: 1024);
      expect(store.getCommonPageSize(), equals(1024));
      expect(store.getPageSize(0, 1024), equals(1024));
    });

    test('allocates and loads page with test data', () {
      final store = MockBackingStore(pageCount: 3, pageSize: 256);
      final page = store.allocAndLoadPage(0, 256, 256);

      expect(page.length, equals(256));
      // Check pattern
      for (int i = 0; i < 256; i++) {
        expect(page[i], equals(i & 0xFF));
      }
    });

    test('loads different data for different pages', () {
      final store = MockBackingStore(pageCount: 3, pageSize: 256);
      final page0 = store.allocAndLoadPage(0, 256, 256);
      final page1 = store.allocAndLoadPage(256, 256, 256);

      expect(page0[0], equals(0));
      expect(page1[0], equals(0)); // Pattern wraps
      expect(page0[1], equals(1));
      expect(page1[1], equals(1));
    });
  });

  group('T3PoolPaged - Initialization', () {
    test('initializes with zero pages', () {
      final pool = T3PoolPaged();
      expect(pool.getPageCount(), equals(0));
      expect(pool.getPageSize(), equals(0));
    });

    test('attaches to backing store', () {
      final pool = T3PoolPaged();
      final store = MockBackingStore(pageCount: 5, pageSize: 1024);

      pool.attachBackingStore(store);

      expect(pool.getPageCount(), equals(5));
      expect(pool.getPageSize(), equals(1024));
    });

    test('validates page size is power of 2', () {
      final pool = T3PoolPaged();
      // Create a mock with non-power-of-2 page size
      final store = MockBackingStore(pageCount: 1, pageSize: 1000);

      expect(
        () => pool.attachBackingStore(store),
        throwsA(isA<T3VmException>().having((e) => e.errorCode, 'errorCode', vmErrBadPoolPageSize)),
      );
    });

    test('accepts valid power-of-2 page sizes', () {
      final pool = T3PoolPaged();
      for (final size in [256, 512, 1024, 2048, 4096]) {
        final store = MockBackingStore(pageCount: 1, pageSize: size);
        expect(() => pool.attachBackingStore(store), returnsNormally);
        pool.detachBackingStore();
      }
    });

    test('uses default page size when backing store has zero pages', () {
      final pool = T3PoolPaged();
      final store = MockBackingStore(pageCount: 0, pageSize: 0);

      pool.attachBackingStore(store);

      expect(pool.getPageSize(), equals(1024)); // Default
    });
  });

  group('T3PoolPaged - Page Calculations', () {
    late T3PoolPaged pool;

    setUp(() {
      pool = T3PoolPaged();
      final store = MockBackingStore(pageCount: 10, pageSize: 1024);
      pool.attachBackingStore(store);
    });

    test('calculates page number from offset', () {
      expect(pool.getPageForOffset(0), equals(0));
      expect(pool.getPageForOffset(1023), equals(0));
      expect(pool.getPageForOffset(1024), equals(1));
      expect(pool.getPageForOffset(2047), equals(1));
      expect(pool.getPageForOffset(2048), equals(2));
      expect(pool.getPageForOffset(5120), equals(5));
    });

    test('calculates offset within page', () {
      expect(pool.getOffsetInPage(0), equals(0));
      expect(pool.getOffsetInPage(100), equals(100));
      expect(pool.getOffsetInPage(1023), equals(1023));
      expect(pool.getOffsetInPage(1024), equals(0));
      expect(pool.getOffsetInPage(1100), equals(76));
      expect(pool.getOffsetInPage(2048), equals(0));
    });

    test('calculates page start offset', () {
      expect(pool.getPageStartOffset(0), equals(0));
      expect(pool.getPageStartOffset(1), equals(1024));
      expect(pool.getPageStartOffset(2), equals(2048));
      expect(pool.getPageStartOffset(5), equals(5120));
    });

    test('round-trip offset calculations', () {
      for (final offset in [0, 100, 1023, 1024, 2000, 5000]) {
        final page = pool.getPageForOffset(offset);
        final pageOffset = pool.getOffsetInPage(offset);
        final reconstructed = pool.getPageStartOffset(page) + pageOffset;
        expect(reconstructed, equals(offset));
      }
    });
  });

  group('T3PoolInMem - Initialization', () {
    test('loads all pages on attach', () {
      final pool = T3PoolInMem();
      final store = MockBackingStore(pageCount: 3, pageSize: 256);

      pool.attachBackingStore(store);

      expect(pool.getPageCount(), equals(3));
      expect(pool.getPageSize(), equals(256));
    });

    test('frees pages on detach', () {
      final pool = T3PoolInMem();
      final store = MockBackingStore(pageCount: 3, pageSize: 256);

      pool.attachBackingStore(store);
      pool.detachBackingStore();

      expect(pool.getPageCount(), equals(0));
    });

    test('can reattach after detach', () {
      final pool = T3PoolInMem();
      final store1 = MockBackingStore(pageCount: 2, pageSize: 256);
      final store2 = MockBackingStore(pageCount: 4, pageSize: 512);

      pool.attachBackingStore(store1);
      expect(pool.getPageCount(), equals(2));

      pool.detachBackingStore();
      pool.attachBackingStore(store2);
      expect(pool.getPageCount(), equals(4));
      expect(pool.getPageSize(), equals(512));
    });
  });

  group('T3PoolInMem - Memory Access', () {
    late T3PoolInMem pool;
    late MockBackingStore store;

    setUp(() {
      pool = T3PoolInMem();
      store = MockBackingStore(pageCount: 4, pageSize: 256);
      pool.attachBackingStore(store);
    });

    test('getPtr returns correct page and offset', () {
      final (mem, offset) = pool.getPtr(0);
      expect(offset, equals(0));
      expect(mem[0], equals(0)); // First byte of first page

      final (mem2, offset2) = pool.getPtr(100);
      expect(offset2, equals(100));
      expect(mem2[100], equals(100));

      final (mem3, offset3) = pool.getPtr(256);
      expect(offset3, equals(0)); // First byte of second page
    });

    test('reads data from pool', () {
      // Read from first page
      final (mem1, off1) = pool.getPtr(50);
      expect(mem1[off1], equals(50));

      // Read from second page
      final (mem2, off2) = pool.getPtr(256 + 10);
      expect(mem2[off2], equals(10));

      // Read from third page
      final (mem3, off3) = pool.getPtr(512 + 100);
      expect(mem3[off3], equals(100));
    });

    test('validates correct offsets', () {
      expect(pool.validateOffset(0), isTrue);
      expect(pool.validateOffset(100), isTrue);
      expect(pool.validateOffset(255), isTrue);
      expect(pool.validateOffset(256), isTrue);
      expect(pool.validateOffset(1023), isTrue);
    });

    test('rejects invalid offsets', () {
      // Beyond all pages
      expect(pool.validateOffset(4 * 256), isFalse);
      expect(pool.validateOffset(10000), isFalse);
    });

    test('getOffsetFromPtr returns correct offset', () {
      final (mem, _) = pool.getPtr(100);
      final offset = pool.getOffsetFromPtr(mem, 100);
      expect(offset, equals(100));
    });

    test('getOffsetFromPtr returns null for invalid pointer', () {
      final invalidMem = Uint8List(100);
      final offset = pool.getOffsetFromPtr(invalidMem, 0);
      expect(offset, isNull);
    });
  });

  group('T3PoolInMem - Edge Cases', () {
    test('handles empty pool', () {
      final pool = T3PoolInMem();
      final store = MockBackingStore(pageCount: 0, pageSize: 0);

      pool.attachBackingStore(store);

      expect(pool.getPageCount(), equals(0));
      expect(pool.validateOffset(0), isFalse);
    });

    test('handles single page pool', () {
      final pool = T3PoolInMem();
      final store = MockBackingStore(pageCount: 1, pageSize: 256);

      pool.attachBackingStore(store);

      expect(pool.getPageCount(), equals(1));
      expect(pool.validateOffset(0), isTrue);
      expect(pool.validateOffset(255), isTrue);
      expect(pool.validateOffset(256), isFalse);
    });

    test('handles large pool', () {
      final pool = T3PoolInMem();
      final store = MockBackingStore(pageCount: 100, pageSize: 4096);

      pool.attachBackingStore(store);

      expect(pool.getPageCount(), equals(100));
      expect(pool.validateOffset(0), isTrue);
      expect(pool.validateOffset(100 * 4096 - 1), isTrue);
      expect(pool.validateOffset(100 * 4096), isFalse);
    });

    test('handles different page sizes', () {
      for (final pageSize in [256, 512, 1024, 2048, 4096]) {
        final pool = T3PoolInMem();
        final store = MockBackingStore(pageCount: 5, pageSize: pageSize);

        pool.attachBackingStore(store);

        expect(pool.getPageSize(), equals(pageSize));
        expect(pool.validateOffset(0), isTrue);
        expect(pool.validateOffset(pageSize - 1), isTrue);
        expect(pool.validateOffset(pageSize), isTrue);

        pool.terminate();
      }
    });
  });

  group('T3PoolInMem - Real-World Scenarios', () {
    test('simulates constant pool access', () {
      final pool = T3PoolInMem();
      final store = MockBackingStore(pageCount: 10, pageSize: 1024);

      pool.attachBackingStore(store);

      // Simulate reading a string constant at offset 500
      final (mem, offset) = pool.getPtr(500);
      expect(pool.validateOffset(500), isTrue);
      expect(mem[offset], equals(500 & 0xFF));

      // Simulate reading another constant at offset 2000
      final (mem2, offset2) = pool.getPtr(2000);
      expect(pool.validateOffset(2000), isTrue);
      expect(mem2[offset2], equals(2000 & 0xFF));
    });

    test('simulates code pool access', () {
      final pool = T3PoolInMem();
      final store = MockBackingStore(pageCount: 20, pageSize: 2048);

      pool.attachBackingStore(store);

      // Simulate reading bytecode at various offsets
      for (final offset in [0, 1000, 5000, 10000, 20000]) {
        expect(pool.validateOffset(offset), isTrue);
        final (mem, off) = pool.getPtr(offset);
        expect(mem[off], equals(offset & 0xFF));
      }
    });

    test('handles sequential access pattern', () {
      final pool = T3PoolInMem();
      final store = MockBackingStore(pageCount: 5, pageSize: 256);

      pool.attachBackingStore(store);

      // Read sequentially through first page
      for (int i = 0; i < 256; i++) {
        final (mem, offset) = pool.getPtr(i);
        expect(mem[offset], equals(i));
      }

      // Read sequentially through second page
      for (int i = 0; i < 256; i++) {
        final (mem, offset) = pool.getPtr(256 + i);
        expect(mem[offset], equals(i));
      }
    });

    test('handles random access pattern', () {
      final pool = T3PoolInMem();
      final store = MockBackingStore(pageCount: 10, pageSize: 512);

      pool.attachBackingStore(store);

      // Random offsets
      final offsets = [0, 511, 512, 1000, 2500, 4000, 5119];
      for (final offset in offsets) {
        expect(pool.validateOffset(offset), isTrue);
        final (mem, off) = pool.getPtr(offset);
        expect(mem[off], equals(offset & 0xFF));
      }
    });

    test('cleanup releases all resources', () {
      final pool = T3PoolInMem();
      final store = MockBackingStore(pageCount: 5, pageSize: 1024);

      pool.attachBackingStore(store);
      expect(pool.getPageCount(), equals(5));

      pool.terminate();
      expect(pool.getPageCount(), equals(0));
    });
  });
}
