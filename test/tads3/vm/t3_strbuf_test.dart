import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_strbuf.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_object_table.dart';
import 'package:zart/src/tads3/vm/t3_stack.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';
import 'package:zart/src/tads3/vm/t3_error.dart';
import 'package:zart/src/tads3/vm/t3_metaclass_table.dart';

class MockStack extends T3Stack {
  MockStack() : super(100, 10);

  void pushInt(int val) => push(T3Value(T3DataType.int32)..setInt(val));
  // Note: pushString not implemented since T3Value doesn't store strings directly
  // (strings are pool offsets, not embedded values)
}

class MockVM extends T3VM {
  @override
  final MockStack stack = MockStack();
  @override
  final T3ObjectTable objTable = T3ObjectTable();
  @override
  final T3MetaclassTable metaTable = T3MetaclassTable();
}

void main() {
  group('T3ObjStringBuffer', () {
    late MockVM vm;

    setUp(() {
      vm = MockVM();
    });

    group('construction', () {
      test('creates with specified allocation size', () {
        final buf = T3ObjStringBuffer(100, 50);
        expect(buf.length, equals(0));
        expect(buf.allocatedSize, equals(100));
        expect(buf.increment, equals(50));
      });

      test('enforces minimum size', () {
        final buf = T3ObjStringBuffer(5, 5);
        expect(buf.allocatedSize, equals(16)); // Min size is 16
        expect(buf.increment, equals(16));
      });

      test('creates with defaults', () {
        final buf = T3ObjStringBuffer.withDefaults();
        expect(buf.allocatedSize, equals(256));
        expect(buf.increment, equals(256));
      });

      test('createFromStack with 0 args uses defaults', () {
        final id = T3ObjStringBuffer.createFromStack(vm, 0);
        final buf = vm.objTable.getObj(id) as T3ObjStringBuffer;
        expect(buf.allocatedSize, equals(256));
        expect(buf.increment, equals(256));
      });

      test('createFromStack with 1 arg sets size and computes increment', () {
        vm.stack.pushInt(128);
        final id = T3ObjStringBuffer.createFromStack(vm, 1);
        final buf = vm.objTable.getObj(id) as T3ObjStringBuffer;
        expect(buf.allocatedSize, equals(128));
        expect(buf.increment, equals(128)); // Small size: inc = alo
      });

      test('createFromStack with 2 args sets both', () {
        vm.stack.pushInt(200);
        vm.stack.pushInt(64);
        final id = T3ObjStringBuffer.createFromStack(vm, 2);
        final buf = vm.objTable.getObj(id) as T3ObjStringBuffer;
        expect(buf.allocatedSize, equals(200));
        expect(buf.increment, equals(64));
      });

      test('createFromStack with 3 args throws', () {
        vm.stack.pushInt(100);
        vm.stack.pushInt(50);
        vm.stack.pushInt(25);
        expect(() => T3ObjStringBuffer.createFromStack(vm, 3), throwsA(isA<T3VmException>()));
      });
    });

    group('append and length', () {
      test('appending text increases length', () {
        final buf = T3ObjStringBuffer.withDefaults();
        expect(buf.length, equals(0));

        buf.appendText('Hello');
        expect(buf.length, equals(5));

        buf.appendText(' World');
        expect(buf.length, equals(11));
      });

      test('append handles empty string', () {
        final buf = T3ObjStringBuffer.withDefaults();
        buf.appendText('');
        expect(buf.length, equals(0));
      });

      test('append handles unicode', () {
        final buf = T3ObjStringBuffer.withDefaults();
        buf.appendText('Hello 世界');
        expect(buf.length, equals(8)); // 6 ASCII + 2 Chinese chars
      });
    });

    group('charAt and character access', () {
      test('getCharAt returns correct character', () {
        final buf = T3ObjStringBuffer.withDefaults();
        buf.appendText('ABCDE');

        expect(buf.getCharAt(0), equals(65)); // 'A'
        expect(buf.getCharAt(2), equals(67)); // 'C'
        expect(buf.getCharAt(4), equals(69)); // 'E'
      });

      test('getCharAt throws for out of range', () {
        final buf = T3ObjStringBuffer.withDefaults();
        buf.appendText('ABC');

        expect(() => buf.getCharAt(-1), throwsA(isA<T3VmException>()));
        expect(() => buf.getCharAt(3), throwsA(isA<T3VmException>()));
      });

      test('setCharAt modifies character', () {
        final buf = T3ObjStringBuffer.withDefaults();
        buf.appendText('ABC');
        buf.setCharAt(1, 88); // 'X'

        expect(buf.getCharAt(0), equals(65)); // 'A'
        expect(buf.getCharAt(1), equals(88)); // 'X'
        expect(buf.getCharAt(2), equals(67)); // 'C'
      });
    });

    group('insert', () {
      test('insert at beginning', () {
        final buf = T3ObjStringBuffer.withDefaults();
        buf.appendText('World');
        buf.insertText(0, 'Hello ');
        expect(buf.substring(0, buf.length), equals('Hello World'));
      });

      test('insert at end is same as append', () {
        final buf = T3ObjStringBuffer.withDefaults();
        buf.appendText('Hello');
        buf.insertText(5, ' World');
        expect(buf.substring(0, buf.length), equals('Hello World'));
      });

      test('insert in middle', () {
        final buf = T3ObjStringBuffer.withDefaults();
        buf.appendText('Helo');
        buf.insertText(2, 'l');
        expect(buf.substring(0, buf.length), equals('Hello'));
      });
    });

    group('delete', () {
      test('delete from beginning', () {
        final buf = T3ObjStringBuffer.withDefaults();
        buf.appendText('Hello World');
        buf.deleteText(0, 6);
        expect(buf.substring(0, buf.length), equals('World'));
      });

      test('delete from end', () {
        final buf = T3ObjStringBuffer.withDefaults();
        buf.appendText('Hello World');
        buf.deleteText(5, 6);
        expect(buf.substring(0, buf.length), equals('Hello'));
      });

      test('delete from middle', () {
        final buf = T3ObjStringBuffer.withDefaults();
        buf.appendText('Hello World');
        buf.deleteText(5, 1);
        expect(buf.substring(0, buf.length), equals('HelloWorld'));
      });
    });

    group('splice', () {
      test('splice replaces text', () {
        final buf = T3ObjStringBuffer.withDefaults();
        buf.appendText('Hello World');
        buf.spliceUtf8(6, 5, 'Dart');
        expect(buf.substring(0, buf.length), equals('Hello Dart'));
      });

      test('splice with empty insertion is delete', () {
        final buf = T3ObjStringBuffer.withDefaults();
        buf.appendText('Hello World');
        buf.spliceUtf8(5, 6, '');
        expect(buf.substring(0, buf.length), equals('Hello'));
      });

      test('splice with zero delete is insert', () {
        final buf = T3ObjStringBuffer.withDefaults();
        buf.appendText('HelloWorld');
        buf.spliceUtf8(5, 0, ' ');
        expect(buf.substring(0, buf.length), equals('Hello World'));
      });
    });

    group('substring', () {
      test('substring extracts portion', () {
        final buf = T3ObjStringBuffer.withDefaults();
        buf.appendText('Hello World');

        expect(buf.substring(0, 5), equals('Hello'));
        expect(buf.substring(6, 5), equals('World'));
        expect(buf.substring(0, 11), equals('Hello World'));
      });

      test('substring clamps to valid range', () {
        final buf = T3ObjStringBuffer.withDefaults();
        buf.appendText('Hello');

        expect(buf.substring(0, 100), equals('Hello'));
        expect(buf.substring(3, 100), equals('lo'));
      });
    });

    group('buffer expansion', () {
      test('auto-expands when needed', () {
        final buf = T3ObjStringBuffer(20, 10);
        expect(buf.allocatedSize, equals(20));

        // Fill to capacity
        buf.appendText('12345678901234567890');
        expect(buf.length, equals(20));

        // Add more - should expand
        buf.appendText('ABCDE');
        expect(buf.length, equals(25));
        expect(buf.allocatedSize, greaterThanOrEqualTo(25));
      });

      test('ensureSpace expands in increments', () {
        final buf = T3ObjStringBuffer(20, 10);
        buf.ensureSpace(35);
        expect(buf.allocatedSize, equals(48)); // 35 rounded up by inc of 16 (min)
      });
    });

    group('equality', () {
      test('equals another StringBuffer with same content', () {
        final buf1 = T3ObjStringBuffer.withDefaults();
        buf1.appendText('Hello');

        final buf2 = T3ObjStringBuffer.withDefaults();
        buf2.appendText('Hello');

        final id1 = vm.objTable.registerObj(buf1, false);
        final id2 = vm.objTable.registerObj(buf2, false);

        expect(buf1.equals(vm, id1, T3Value(T3DataType.obj)..setObj(id2), 0), isTrue);
      });

      test('not equals StringBuffer with different content', () {
        final buf1 = T3ObjStringBuffer.withDefaults();
        buf1.appendText('Hello');

        final buf2 = T3ObjStringBuffer.withDefaults();
        buf2.appendText('World');

        final id1 = vm.objTable.registerObj(buf1, false);
        final id2 = vm.objTable.registerObj(buf2, false);

        expect(buf1.equals(vm, id1, T3Value(T3DataType.obj)..setObj(id2), 0), isFalse);
      });
    });

    group('comparison', () {
      test('compares less than', () {
        final buf1 = T3ObjStringBuffer.withDefaults();
        buf1.appendText('AAA');

        final buf2 = T3ObjStringBuffer.withDefaults();
        buf2.appendText('BBB');

        final id1 = vm.objTable.registerObj(buf1, false);
        final id2 = vm.objTable.registerObj(buf2, false);

        expect(buf1.compareTo(vm, id1, T3Value(T3DataType.obj)..setObj(id2)), lessThan(0));
      });

      test('compares greater than', () {
        final buf1 = T3ObjStringBuffer.withDefaults();
        buf1.appendText('BBB');

        final buf2 = T3ObjStringBuffer.withDefaults();
        buf2.appendText('AAA');

        final id1 = vm.objTable.registerObj(buf1, false);
        final id2 = vm.objTable.registerObj(buf2, false);

        expect(buf1.compareTo(vm, id1, T3Value(T3DataType.obj)..setObj(id2)), greaterThan(0));
      });

      test('shorter string compares less', () {
        final buf1 = T3ObjStringBuffer.withDefaults();
        buf1.appendText('AA');

        final buf2 = T3ObjStringBuffer.withDefaults();
        buf2.appendText('AAA');

        final id1 = vm.objTable.registerObj(buf1, false);
        final id2 = vm.objTable.registerObj(buf2, false);

        expect(buf1.compareTo(vm, id1, T3Value(T3DataType.obj)..setObj(id2)), lessThan(0));
      });
    });

    group('hash', () {
      test('calcHash returns consistent value', () {
        final buf = T3ObjStringBuffer.withDefaults();
        buf.appendText('Hello');
        final id = vm.objTable.registerObj(buf, false);

        final hash1 = buf.calcHash(vm, id, 0);
        final hash2 = buf.calcHash(vm, id, 0);
        expect(hash1, equals(hash2));
      });

      test('same content produces same hash', () {
        final buf1 = T3ObjStringBuffer.withDefaults();
        buf1.appendText('Hello');

        final buf2 = T3ObjStringBuffer.withDefaults();
        buf2.appendText('Hello');

        expect(buf1.calcHash(vm, 0, 0), equals(buf2.calcHash(vm, 0, 0)));
      });
    });

    group('castToString', () {
      test('converts buffer to string', () {
        final buf = T3ObjStringBuffer.withDefaults();
        buf.appendText('Hello World');
        final id = vm.objTable.registerObj(buf, false);

        final newStr = T3Value();
        final str = buf.castToString(vm, id, newStr);
        expect(str, equals('Hello World'));
      });
    });

    group('serialization', () {
      test('loadFromImage parses format correctly', () {
        // Create image data: alo=32, inc=16, len=5, "Hello"
        final data = Uint8List(12 + 5 * 2);
        final view = ByteData.sublistView(data);
        view.setUint32(0, 32, Endian.little); // alo
        view.setUint32(4, 16, Endian.little); // inc
        view.setUint32(8, 5, Endian.little); // len
        // Characters: H=72, e=101, l=108, l=108, o=111
        view.setUint16(12, 72, Endian.little);
        view.setUint16(14, 101, Endian.little);
        view.setUint16(16, 108, Endian.little);
        view.setUint16(18, 108, Endian.little);
        view.setUint16(20, 111, Endian.little);

        final buf = T3ObjStringBuffer.withDefaults();
        buf.loadFromImage(vm, 0, data, 0, data.length);

        expect(buf.length, equals(5));
        expect(buf.allocatedSize, equals(32));
        expect(buf.increment, equals(16));
        expect(buf.substring(0, 5), equals('Hello'));
      });
    });
  });

  group('T3MetaclassStringBuffer', () {
    test('has correct name', () {
      final meta = T3MetaclassStringBuffer();
      expect(meta.getMetaName(), equals('stringbuffer/030000'));
    });

    test('static name constant', () {
      expect(T3MetaclassStringBuffer.name, equals('stringbuffer/030000'));
    });
  });
}
