import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:zart/src/tads3/loaders/entp_parser.dart';
import 'package:zart/src/tads3/loaders/fnsd_parser.dart';
import 'package:zart/src/tads3/loaders/mcld_parser.dart';

void main() {
  group('T3Entrypoint', () {
    test('parses minimal ENTP block', () {
      // Create a minimal ENTP block:
      // UINT4 code_offset: 0x12345678
      // UINT2 method_header_size: 10
      // UINT2 exception_entry_size: 8
      // UINT2 debug_line_entry_size: 4
      // UINT2 debug_table_header_size: 6
      // UINT2 debug_local_header_size: 2
      final data = Uint8List.fromList([
        0x78, 0x56, 0x34, 0x12, // code offset
        0x0A, 0x00, // method header size = 10
        0x08, 0x00, // exception entry size = 8
        0x04, 0x00, // debug line entry size = 4
        0x06, 0x00, // debug table header size = 6
        0x02, 0x00, // debug local header size = 2
      ]);

      final entp = T3Entrypoint.parse(data);

      expect(entp.codeOffset, 0x12345678);
      expect(entp.methodHeaderSize, 10);
      expect(entp.exceptionEntrySize, 8);
      expect(entp.debugLineEntrySize, 4);
      expect(entp.debugTableHeaderSize, 6);
      expect(entp.debugLocalHeaderSize, 2);
      expect(entp.debugRecordsVersion, 0); // Not present
    });

    test('parses full ENTP block with all fields', () {
      final data = Uint8List.fromList([
        0x00, 0x10, 0x00, 0x00, // code offset = 0x1000
        0x0C, 0x00, // method header size = 12
        0x0A, 0x00, // exception entry size = 10
        0x08, 0x00, // debug line entry size = 8
        0x10, 0x00, // debug table header size = 16
        0x06, 0x00, // debug local header size = 6
        0x02, 0x00, // debug records version = 2
        0x04, 0x00, // debug frame header size = 4
      ]);

      final entp = T3Entrypoint.parse(data);

      expect(entp.codeOffset, 0x1000);
      expect(entp.methodHeaderSize, 12);
      expect(entp.debugRecordsVersion, 2);
      expect(entp.debugFrameHeaderSize, 4);
    });

    test('toString provides useful info', () {
      final data = Uint8List.fromList([
        0x00,
        0x10,
        0x00,
        0x00,
        0x0C,
        0x00,
        0x0A,
        0x00,
        0x08,
        0x00,
        0x10,
        0x00,
        0x06,
        0x00,
      ]);

      final entp = T3Entrypoint.parse(data);
      final str = entp.toString();

      expect(str, contains('1000'));
      expect(str, contains('12'));
    });
  });

  group('T3MetaclassDepList', () {
    test('parses empty metaclass list', () {
      final data = Uint8List.fromList([
        0x00, 0x00, // count = 0
      ]);

      final mcld = T3MetaclassDepList.parse(data);
      expect(mcld.length, 0);
    });

    test('parses single metaclass without version', () {
      // "tads-object" without version, 0 properties
      final name = 'tads-object';
      final nameBytes = name.codeUnits;

      final data = Uint8List.fromList([
        0x01, 0x00, // count = 1
        nameBytes.length, 0x00, // name length
        ...nameBytes, // name
        0x00, 0x00, // property count = 0
      ]);

      final mcld = T3MetaclassDepList.parse(data);

      expect(mcld.length, 1);
      expect(mcld.dependencies[0].identifier, 'tads-object');
      expect(mcld.dependencies[0].name, 'tads-object');
      expect(mcld.dependencies[0].version, isNull);
      expect(mcld.dependencies[0].index, 0);
      expect(mcld.dependencies[0].propertyCount, 0);
    });

    test('parses metaclass with version', () {
      final name = 'tads-object/030005';
      final nameBytes = name.codeUnits;

      final data = Uint8List.fromList([
        0x01, 0x00, // count = 1
        nameBytes.length, 0x00, // name length
        ...nameBytes, // name
        0x00, 0x00, // property count = 0
      ]);

      final mcld = T3MetaclassDepList.parse(data);

      expect(mcld.dependencies[0].name, 'tads-object');
      expect(mcld.dependencies[0].version, 30005); // Parsed as decimal
    });

    test('parses metaclass with properties', () {
      final name = 'string';
      final nameBytes = name.codeUnits;

      final data = Uint8List.fromList([
        0x01, 0x00, // count = 1
        nameBytes.length, 0x00, // name length
        ...nameBytes, // name
        0x03, 0x00, // property count = 3
        0x10, 0x00, // prop ID 0x10
        0x11, 0x00, // prop ID 0x11
        0x12, 0x00, // prop ID 0x12
      ]);

      final mcld = T3MetaclassDepList.parse(data);

      expect(mcld.dependencies[0].propertyCount, 3);
      expect(mcld.dependencies[0].propertyIds, [0x10, 0x11, 0x12]);
    });

    test('parses multiple metaclasses', () {
      final name1 = 'tads-object';
      final name2 = 'string';

      final data = Uint8List.fromList([
        0x02, 0x00, // count = 2
        name1.length, 0x00, ...name1.codeUnits, 0x00, 0x00,
        name2.length, 0x00, ...name2.codeUnits, 0x00, 0x00,
      ]);

      final mcld = T3MetaclassDepList.parse(data);

      expect(mcld.length, 2);
      expect(mcld.dependencies[0].name, 'tads-object');
      expect(mcld.dependencies[0].index, 0);
      expect(mcld.dependencies[1].name, 'string');
      expect(mcld.dependencies[1].index, 1);
    });

    test('byIndex returns correct metaclass', () {
      final name1 = 'list';
      final name2 = 'vector';

      final data = Uint8List.fromList([
        0x02,
        0x00,
        name1.length,
        0x00,
        ...name1.codeUnits,
        0x00,
        0x00,
        name2.length,
        0x00,
        ...name2.codeUnits,
        0x00,
        0x00,
      ]);

      final mcld = T3MetaclassDepList.parse(data);

      expect(mcld.byIndex(0)?.name, 'list');
      expect(mcld.byIndex(1)?.name, 'vector');
      expect(mcld.byIndex(2), isNull);
      expect(mcld.byIndex(-1), isNull);
    });

    test('byName returns correct metaclass', () {
      final name1 = 'list';
      final name2 = 'vector';

      final data = Uint8List.fromList([
        0x02,
        0x00,
        name1.length,
        0x00,
        ...name1.codeUnits,
        0x00,
        0x00,
        name2.length,
        0x00,
        ...name2.codeUnits,
        0x00,
        0x00,
      ]);

      final mcld = T3MetaclassDepList.parse(data);

      expect(mcld.byName('list')?.index, 0);
      expect(mcld.byName('vector')?.index, 1);
      expect(mcld.byName('unknown'), isNull);
    });
  });

  group('T3FunctionSetDepList', () {
    test('parses empty function set list', () {
      final data = Uint8List.fromList([
        0x00, 0x00, // count = 0
      ]);

      final fnsd = T3FunctionSetDepList.parse(data);
      expect(fnsd.length, 0);
    });

    test('parses single function set', () {
      final name = 't3vm/030000';
      final nameBytes = name.codeUnits;

      final data = Uint8List.fromList([
        0x01, 0x00, // count = 1
        nameBytes.length, 0x00, // name length
        ...nameBytes, // name
      ]);

      final fnsd = T3FunctionSetDepList.parse(data);

      expect(fnsd.length, 1);
      expect(fnsd.dependencies[0].identifier, 't3vm/030000');
      expect(fnsd.dependencies[0].name, 't3vm');
      expect(fnsd.dependencies[0].version, 30000);
      expect(fnsd.dependencies[0].index, 0);
    });

    test('parses multiple function sets', () {
      final name1 = 't3vm/030000';
      final name2 = 'tads-gen/030000';
      final name3 = 'tads-io/030000';

      final data = Uint8List.fromList([
        0x03, 0x00, // count = 3
        name1.length, 0x00, ...name1.codeUnits,
        name2.length, 0x00, ...name2.codeUnits,
        name3.length, 0x00, ...name3.codeUnits,
      ]);

      final fnsd = T3FunctionSetDepList.parse(data);

      expect(fnsd.length, 3);
      expect(fnsd.dependencies[0].name, 't3vm');
      expect(fnsd.dependencies[1].name, 'tads-gen');
      expect(fnsd.dependencies[2].name, 'tads-io');
    });

    test('byIndex returns correct function set', () {
      final name1 = 't3vm';
      final name2 = 'tads-gen';

      final data = Uint8List.fromList([
        0x02,
        0x00,
        name1.length,
        0x00,
        ...name1.codeUnits,
        name2.length,
        0x00,
        ...name2.codeUnits,
      ]);

      final fnsd = T3FunctionSetDepList.parse(data);

      expect(fnsd.byIndex(0)?.name, 't3vm');
      expect(fnsd.byIndex(1)?.name, 'tads-gen');
      expect(fnsd.byIndex(2), isNull);
    });

    test('byName returns correct function set', () {
      final name1 = 't3vm';
      final name2 = 'tads-gen';

      final data = Uint8List.fromList([
        0x02,
        0x00,
        name1.length,
        0x00,
        ...name1.codeUnits,
        name2.length,
        0x00,
        ...name2.codeUnits,
      ]);

      final fnsd = T3FunctionSetDepList.parse(data);

      expect(fnsd.byName('t3vm')?.index, 0);
      expect(fnsd.byName('tads-gen')?.index, 1);
      expect(fnsd.byName('unknown'), isNull);
    });
  });
}
