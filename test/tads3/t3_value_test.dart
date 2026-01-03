import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';

void main() {
  group('T3DataType', () {
    test('fromCode returns correct type', () {
      expect(T3DataType.fromCode(1), T3DataType.nil);
      expect(T3DataType.fromCode(2), T3DataType.true_);
      expect(T3DataType.fromCode(5), T3DataType.obj);
      expect(T3DataType.fromCode(6), T3DataType.prop);
      expect(T3DataType.fromCode(7), T3DataType.int_);
      expect(T3DataType.fromCode(8), T3DataType.sstring);
      expect(T3DataType.fromCode(10), T3DataType.list);
      expect(T3DataType.fromCode(12), T3DataType.funcptr);
    });

    test('fromCode returns null for invalid code', () {
      expect(T3DataType.fromCode(0), isNull);
      expect(T3DataType.fromCode(100), isNull);
    });
  });

  group('T3Value construction', () {
    test('nil creates nil value', () {
      final val = T3Value.nil();
      expect(val.type, T3DataType.nil);
      expect(val.value, 0);
      expect(val.isNil, isTrue);
      expect(val.isLogicalTrue, isFalse);
    });

    test('true_ creates true value', () {
      final val = T3Value.true_();
      expect(val.type, T3DataType.true_);
      expect(val.isTrue, isTrue);
      expect(val.isLogicalTrue, isTrue);
    });

    test('fromInt creates integer value', () {
      final val = T3Value.fromInt(42);
      expect(val.type, T3DataType.int_);
      expect(val.value, 42);
      expect(val.isInt, isTrue);
      expect(val.asInt(), 42);
    });

    test('fromInt handles negative values', () {
      final val = T3Value.fromInt(-100);
      expect(val.value, -100);
      expect(val.asInt(), -100);
    });

    test('fromObject creates object reference', () {
      final val = T3Value.fromObject(12345);
      expect(val.type, T3DataType.obj);
      expect(val.value, 12345);
      expect(val.isObject, isTrue);
      expect(val.asObject(), 12345);
    });

    test('fromObjectOrNil returns nil for object ID 0', () {
      final val = T3Value.fromObjectOrNil(0);
      expect(val.isNil, isTrue);
    });

    test('fromObjectOrNil returns object for non-zero ID', () {
      final val = T3Value.fromObjectOrNil(123);
      expect(val.isObject, isTrue);
      expect(val.asObject(), 123);
    });

    test('fromProp creates property ID value', () {
      final val = T3Value.fromProp(256);
      expect(val.type, T3DataType.prop);
      expect(val.isProp, isTrue);
      expect(val.asProp(), 256);
    });

    test('fromString creates string constant value', () {
      final val = T3Value.fromString(0x1000);
      expect(val.type, T3DataType.sstring);
      expect(val.isString, isTrue);
      expect(val.isStringLike, isTrue);
      expect(val.asStringOffset(), 0x1000);
    });

    test('fromDString creates self-printing string value', () {
      final val = T3Value.fromDString(0x2000);
      expect(val.type, T3DataType.dstring);
      expect(val.isDString, isTrue);
      expect(val.isStringLike, isTrue);
    });

    test('fromList creates list constant value', () {
      final val = T3Value.fromList(0x3000);
      expect(val.type, T3DataType.list);
      expect(val.isList, isTrue);
      expect(val.asListOffset(), 0x3000);
    });

    test('fromCodeOffset creates code offset value', () {
      final val = T3Value.fromCodeOffset(0x4000);
      expect(val.type, T3DataType.codeofs);
      expect(val.isCodeOffset, isTrue);
      expect(val.asCodeOffset(), 0x4000);
    });

    test('fromFuncPtr creates function pointer value', () {
      final val = T3Value.fromFuncPtr(0x5000);
      expect(val.type, T3DataType.funcptr);
      expect(val.isFuncPtr, isTrue);
      expect(val.asCodeOffset(), 0x5000);
    });

    test('fromEnum creates enum value', () {
      final val = T3Value.fromEnum(0x12345678);
      expect(val.type, T3DataType.enum_);
      expect(val.isEnum, isTrue);
      expect(val.value, 0x12345678);
    });

    test('fromBifPtr creates built-in function pointer', () {
      final val = T3Value.fromBifPtr(2, 10);
      expect(val.type, T3DataType.bifptr);
      expect(val.isBifPtr, isTrue);

      final (setIdx, funcIdx) = val.asBifPtr()!;
      expect(setIdx, 2);
      expect(funcIdx, 10);
    });
  });

  group('T3Value type checking', () {
    test('isNumeric returns true only for integers', () {
      expect(T3Value.fromInt(42).isNumeric, isTrue);
      expect(T3Value.nil().isNumeric, isFalse);
      expect(T3Value.fromObject(1).isNumeric, isFalse);
      expect(T3Value.fromString(0).isNumeric, isFalse);
    });

    test('isLogicalTrue returns false only for nil', () {
      expect(T3Value.nil().isLogicalTrue, isFalse);
      expect(T3Value.true_().isLogicalTrue, isTrue);
      expect(T3Value.fromInt(0).isLogicalTrue, isTrue);
      expect(T3Value.fromInt(1).isLogicalTrue, isTrue);
      expect(T3Value.fromObject(0).isLogicalTrue, isTrue);
    });
  });

  group('T3Value equality', () {
    test('nil equals nil', () {
      expect(T3Value.nil().equals(T3Value.nil()), isTrue);
    });

    test('true equals true', () {
      expect(T3Value.true_().equals(T3Value.true_()), isTrue);
    });

    test('nil does not equal true', () {
      expect(T3Value.nil().equals(T3Value.true_()), isFalse);
    });

    test('integers with same value are equal', () {
      expect(T3Value.fromInt(42).equals(T3Value.fromInt(42)), isTrue);
    });

    test('integers with different values are not equal', () {
      expect(T3Value.fromInt(42).equals(T3Value.fromInt(43)), isFalse);
    });

    test('different types are not equal', () {
      expect(T3Value.fromInt(1).equals(T3Value.true_()), isFalse);
      expect(T3Value.fromInt(0).equals(T3Value.nil()), isFalse);
    });

    test('operator == works correctly', () {
      final a = T3Value.fromInt(42);
      final b = T3Value.fromInt(42);
      final c = T3Value.fromInt(43);

      expect(a == b, isTrue);
      expect(a == c, isFalse);
    });

    test('hashCode is consistent with equals', () {
      final a = T3Value.fromInt(42);
      final b = T3Value.fromInt(42);

      expect(a.hashCode, b.hashCode);
    });
  });

  group('T3Value portable format', () {
    test('fromPortable reads correct values', () {
      // Type 7 (int_) + value 0x12345678 in little-endian
      final data = Uint8List.fromList([7, 0x78, 0x56, 0x34, 0x12]);
      final val = T3Value.fromPortable(data, 0);

      expect(val.type, T3DataType.int_);
      expect(val.value, 0x12345678);
    });

    test('toPortable writes correct bytes', () {
      final val = T3Value.fromInt(0x12345678);
      final data = Uint8List(5);
      val.toPortable(data, 0);

      expect(data[0], 7); // T3DataType.int_.code
      expect(data[1], 0x78);
      expect(data[2], 0x56);
      expect(data[3], 0x34);
      expect(data[4], 0x12);
    });

    test('roundtrip through portable format', () {
      final values = [
        T3Value.nil(),
        T3Value.true_(),
        T3Value.fromInt(-12345),
        T3Value.fromObject(999),
        T3Value.fromProp(42),
        T3Value.fromString(0x1234),
        T3Value.fromList(0x5678),
        T3Value.fromFuncPtr(0xABCD),
      ];

      for (final original in values) {
        final data = Uint8List(5);
        original.toPortable(data, 0);
        final restored = T3Value.fromPortable(data, 0);

        expect(restored.type, original.type, reason: 'Type mismatch for $original');
        expect(restored.value, original.value, reason: 'Value mismatch for $original');
      }
    });

    test('fromPortable with offset', () {
      // Padding + Type 1 (nil) + value 0
      final data = Uint8List.fromList([0xFF, 0xFF, 1, 0, 0, 0, 0]);
      final val = T3Value.fromPortable(data, 2);

      expect(val.type, T3DataType.nil);
    });
  });

  group('T3Value copy', () {
    test('copy creates independent value', () {
      final original = T3Value.fromInt(42);
      final copy = original.copy();

      expect(copy.value, 42);
      expect(copy.type, T3DataType.int_);

      // Modify original
      original.value = 100;
      expect(copy.value, 42); // Copy should be unchanged
    });
  });

  group('T3Value toString', () {
    test('nil toString', () {
      expect(T3Value.nil().toString(), 'nil');
    });

    test('true toString', () {
      expect(T3Value.true_().toString(), 'true');
    });

    test('int toString', () {
      expect(T3Value.fromInt(42).toString(), 'int(42)');
      expect(T3Value.fromInt(-5).toString(), 'int(-5)');
    });

    test('obj toString', () {
      expect(T3Value.fromObject(123).toString(), 'obj(#123)');
    });

    test('prop toString', () {
      expect(T3Value.fromProp(456).toString(), 'prop(&456)');
    });

    test('sstring toString', () {
      expect(T3Value.fromString(0x1000).toString(), 'sstring(@4096)');
    });

    test('bifptr toString', () {
      expect(T3Value.fromBifPtr(1, 5).toString(), 'bifptr(1:5)');
    });
  });
}
