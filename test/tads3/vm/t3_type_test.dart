// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';

void main() {
  group('Type Definitions', () {
    test('constants are defined correctly', () {
      expect(maxSavepointId, equals(255));
      expect(invalidObjectId, equals(0));
      expect(invalidPropertyId, equals(0));
      expect(maxTreeDepthEq, equals(256));
    });
  });

  group('T3DataType Enum', () {
    test('all types are defined', () {
      expect(T3DataType.values.length, greaterThanOrEqualTo(18));
      expect(T3DataType.nil, isNotNull);
      expect(T3DataType.trueValue, isNotNull);
      expect(T3DataType.int32, isNotNull);
      expect(T3DataType.obj, isNotNull);
      expect(T3DataType.sstring, isNotNull);
      expect(T3DataType.list, isNotNull);
    });
  });

  group('T3Value - Basic Operations', () {
    test('default constructor creates nil', () {
      final val = T3Value();
      expect(val.type, equals(T3DataType.nil));
    });

    test('copy constructor creates identical value', () {
      final original = T3Value();
      original.setInt(42);

      final copy = T3Value.copy(original);
      expect(copy.type, equals(T3DataType.int32));
      expect(copy.getAsInt(), equals(42));
    });

    test('setEmpty sets type to empty', () {
      final val = T3Value();
      val.setEmpty();
      expect(val.type, equals(T3DataType.empty));
    });

    test('setNil sets type to nil', () {
      final val = T3Value();
      val.setInt(42);
      val.setNil();
      expect(val.type, equals(T3DataType.nil));
    });

    test('setTrue sets type to true', () {
      final val = T3Value();
      val.setTrue();
      expect(val.type, equals(T3DataType.trueValue));
    });

    test('setInt sets integer value', () {
      final val = T3Value();
      val.setInt(42);
      expect(val.type, equals(T3DataType.int32));
      expect(val.getAsInt(), equals(42));
    });

    test('setObj sets object value', () {
      final val = T3Value();
      val.setObj(100);
      expect(val.type, equals(T3DataType.obj));
      expect(val.getAsObj(), equals(100));
    });

    test('setPropId sets property ID', () {
      final val = T3Value();
      val.setPropId(50);
      expect(val.type, equals(T3DataType.prop));
    });

    test('setObjOrNil sets nil for invalid object', () {
      final val = T3Value();
      val.setObjOrNil(invalidObjectId);
      expect(val.type, equals(T3DataType.nil));
    });

    test('setObjOrNil sets object for valid ID', () {
      final val = T3Value();
      val.setObjOrNil(100);
      expect(val.type, equals(T3DataType.obj));
      expect(val.getAsObj(), equals(100));
    });

    test('setLogical sets true or nil', () {
      final val1 = T3Value();
      val1.setLogical(true);
      expect(val1.type, equals(T3DataType.trueValue));

      final val2 = T3Value();
      val2.setLogical(false);
      expect(val2.type, equals(T3DataType.nil));
    });

    test('setBifPtr sets built-in function pointer', () {
      final val = T3Value();
      val.setBifPtr(1, 2);
      expect(val.type, equals(T3DataType.bifPtr));
    });

    test('setSstring sets string constant offset', () {
      final val = T3Value();
      val.setSstring(1000);
      expect(val.type, equals(T3DataType.sstring));
    });

    test('setList sets list constant offset', () {
      final val = T3Value();
      val.setList(2000);
      expect(val.type, equals(T3DataType.list));
    });
  });

  group('T3Value - Type Checking', () {
    test('isLogical returns true for nil and true', () {
      final nil = T3Value();
      nil.setNil();
      expect(nil.isLogical(), isTrue);

      final t = T3Value();
      t.setTrue();
      expect(t.isLogical(), isTrue);

      final i = T3Value();
      i.setInt(42);
      expect(i.isLogical(), isFalse);
    });

    test('isInt returns true for integers', () {
      final val = T3Value();
      val.setInt(42);
      expect(val.isInt(), isTrue);

      val.setNil();
      expect(val.isInt(), isFalse);
    });

    test('isNumeric returns true for numeric types', () {
      final val = T3Value();
      val.setInt(42);
      expect(val.isNumeric(), isTrue);

      val.setNil();
      expect(val.isNumeric(), isFalse);
    });

    test('getLogical returns correct boolean', () {
      final t = T3Value();
      t.setTrue();
      expect(t.getLogical(), isTrue);

      final nil = T3Value();
      nil.setNil();
      expect(nil.getLogical(), isFalse);
    });

    test('getLogicalOnly throws for non-logical types', () {
      final val = T3Value();
      val.setInt(42);
      expect(() => val.getLogicalOnly(), throwsA(isA<T3TypeError>()));
    });

    test('getAsInt throws for non-integer types', () {
      final val = T3Value();
      val.setNil();
      expect(() => val.getAsInt(), throwsA(isA<T3TypeError>()));
    });

    test('getAsObj returns null for non-object types', () {
      final val = T3Value();
      val.setInt(42);
      expect(val.getAsObj(), isNull);
    });
  });

  group('T3Value - Conversion', () {
    test('numToLogical converts 0 to nil', () {
      final val = T3Value();
      val.setInt(0);
      val.numToLogical();
      expect(val.type, equals(T3DataType.nil));
    });

    test('numToLogical converts non-zero to true', () {
      final val = T3Value();
      val.setInt(42);
      val.numToLogical();
      expect(val.type, equals(T3DataType.trueValue));
    });

    test('numToLogical throws for non-numeric types', () {
      final val = T3Value();
      val.setNil();
      expect(() => val.numToLogical(), throwsA(isA<T3TypeError>()));
    });

    test('numToInt returns integer value', () {
      final val = T3Value();
      val.setInt(42);
      expect(val.numToInt(), equals(42));
    });

    test('numToDouble returns double value', () {
      final val = T3Value();
      val.setInt(42);
      expect(val.numToDouble(), equals(42.0));
    });

    test('castToInt converts true to 1', () {
      final val = T3Value();
      val.setTrue();
      expect(val.castToInt(), equals(1));
    });

    test('castToInt converts nil to 0', () {
      final val = T3Value();
      val.setNil();
      expect(val.castToInt(), equals(0));
    });

    test('castToInt returns integer value', () {
      final val = T3Value();
      val.setInt(42);
      expect(val.castToInt(), equals(42));
    });

    test('castToInt throws for non-convertible types', () {
      final val = T3Value();
      val.setObj(100);
      expect(() => val.castToInt(), throwsA(isA<T3TypeError>()));
    });

    test('numIsZero returns true for zero', () {
      final val = T3Value();
      val.setInt(0);
      expect(val.numIsZero(), isTrue);
    });

    test('numIsZero returns false for non-zero', () {
      final val = T3Value();
      val.setInt(42);
      expect(val.numIsZero(), isFalse);
    });
  });

  group('T3Value - Equality', () {
    test('nil equals nil', () {
      final a = T3Value();
      a.setNil();
      final b = T3Value();
      b.setNil();
      expect(a.equals(b), isTrue);
    });

    test('true equals true', () {
      final a = T3Value();
      a.setTrue();
      final b = T3Value();
      b.setTrue();
      expect(a.equals(b), isTrue);
    });

    test('nil does not equal true', () {
      final a = T3Value();
      a.setNil();
      final b = T3Value();
      b.setTrue();
      expect(a.equals(b), isFalse);
    });

    test('integers with same value are equal', () {
      final a = T3Value();
      a.setInt(42);
      final b = T3Value();
      b.setInt(42);
      expect(a.equals(b), isTrue);
    });

    test('integers with different values are not equal', () {
      final a = T3Value();
      a.setInt(42);
      final b = T3Value();
      b.setInt(99);
      expect(a.equals(b), isFalse);
    });

    test('objects with same ID are equal', () {
      final a = T3Value();
      a.setObj(100);
      final b = T3Value();
      b.setObj(100);
      expect(a.equals(b), isTrue);
    });

    test('objects with different IDs are not equal', () {
      final a = T3Value();
      a.setObj(100);
      final b = T3Value();
      b.setObj(200);
      expect(a.equals(b), isFalse);
    });

    test('properties with same ID are equal', () {
      final a = T3Value();
      a.setPropId(50);
      final b = T3Value();
      b.setPropId(50);
      expect(a.equals(b), isTrue);
    });

    test('empty never equals anything', () {
      final a = T3Value();
      a.setEmpty();
      final b = T3Value();
      b.setEmpty();
      expect(a.equals(b), isFalse);
    });

    test('dstring never equals anything', () {
      final a = T3Value();
      a.setDstring(100);
      final b = T3Value();
      b.setDstring(100);
      expect(a.equals(b), isFalse);
    });

    test('bifPtr with same indices are equal', () {
      final a = T3Value();
      a.setBifPtr(1, 2);
      final b = T3Value();
      b.setBifPtr(1, 2);
      expect(a.equals(b), isTrue);
    });

    test('throws on excessive recursion depth', () {
      final a = T3Value();
      a.setInt(42);
      final b = T3Value();
      b.setInt(42);
      expect(() => a.equals(b, maxTreeDepthEq + 1), throwsA(isA<T3TypeError>()));
    });
  });

  group('T3Value - Hash Calculation', () {
    test('nil has hash 0', () {
      final val = T3Value();
      val.setNil();
      expect(val.calcHash(), equals(0));
    });

    test('true has hash 1', () {
      final val = T3Value();
      val.setTrue();
      expect(val.calcHash(), equals(1));
    });

    test('empty has hash 2', () {
      final val = T3Value();
      val.setEmpty();
      expect(val.calcHash(), equals(2));
    });

    test('integers have consistent hash', () {
      final val = T3Value();
      val.setInt(42);
      final hash1 = val.calcHash();
      final hash2 = val.calcHash();
      expect(hash1, equals(hash2));
    });

    test('equal values have equal hashes', () {
      final a = T3Value();
      a.setInt(42);
      final b = T3Value();
      b.setInt(42);
      expect(a.calcHash(), equals(b.calcHash()));
    });

    test('throws on excessive recursion depth', () {
      final val = T3Value();
      val.setInt(42);
      expect(() => val.calcHash(maxTreeDepthEq + 1), throwsA(isA<T3TypeError>()));
    });
  });

  group('T3Value - Comparison', () {
    test('compareTo returns 0 for equal integers', () {
      final a = T3Value();
      a.setInt(42);
      final b = T3Value();
      b.setInt(42);
      expect(a.compareTo(b), equals(0));
    });

    test('compareTo returns positive when first is greater', () {
      final a = T3Value();
      a.setInt(100);
      final b = T3Value();
      b.setInt(50);
      expect(a.compareTo(b), greaterThan(0));
    });

    test('compareTo returns negative when first is less', () {
      final a = T3Value();
      a.setInt(50);
      final b = T3Value();
      b.setInt(100);
      expect(a.compareTo(b), lessThan(0));
    });

    test('isGt returns true when greater', () {
      final a = T3Value();
      a.setInt(100);
      final b = T3Value();
      b.setInt(50);
      expect(a.isGt(b), isTrue);
      expect(b.isGt(a), isFalse);
    });

    test('isGe returns true when greater or equal', () {
      final a = T3Value();
      a.setInt(100);
      final b = T3Value();
      b.setInt(50);
      final c = T3Value();
      c.setInt(100);

      expect(a.isGe(b), isTrue);
      expect(a.isGe(c), isTrue);
      expect(b.isGe(a), isFalse);
    });

    test('isLt returns true when less', () {
      final a = T3Value();
      a.setInt(50);
      final b = T3Value();
      b.setInt(100);
      expect(a.isLt(b), isTrue);
      expect(b.isLt(a), isFalse);
    });

    test('isLe returns true when less or equal', () {
      final a = T3Value();
      a.setInt(50);
      final b = T3Value();
      b.setInt(100);
      final c = T3Value();
      c.setInt(50);

      expect(a.isLe(b), isTrue);
      expect(a.isLe(c), isTrue);
      expect(b.isLe(a), isFalse);
    });

    test('comparison throws for incompatible types', () {
      final a = T3Value();
      a.setNil();
      final b = T3Value();
      b.setInt(42);
      expect(() => a.compareTo(b), throwsA(isA<T3TypeError>()));
    });
  });

  group('T3Value - toString', () {
    test('nil toString', () {
      final val = T3Value();
      val.setNil();
      expect(val.toString(), equals('nil'));
    });

    test('true toString', () {
      final val = T3Value();
      val.setTrue();
      expect(val.toString(), equals('true'));
    });

    test('integer toString', () {
      final val = T3Value();
      val.setInt(42);
      expect(val.toString(), equals('42'));
    });

    test('object toString', () {
      final val = T3Value();
      val.setObj(100);
      expect(val.toString(), equals('obj(100)'));
    });
  });

  group('T3NativeCodeDesc', () {
    test('exact argument count constructor', () {
      final desc = T3NativeCodeDesc(3);
      expect(desc.minArgc, equals(3));
      expect(desc.optArgc, equals(0));
      expect(desc.varargs, isFalse);
    });

    test('optional arguments constructor', () {
      final desc = T3NativeCodeDesc.withOptional(2, 3);
      expect(desc.minArgc, equals(2));
      expect(desc.optArgc, equals(3));
      expect(desc.varargs, isFalse);
    });

    test('varargs constructor', () {
      final desc = T3NativeCodeDesc.withVarargs(1, 2, true);
      expect(desc.minArgc, equals(1));
      expect(desc.optArgc, equals(2));
      expect(desc.varargs, isTrue);
    });

    test('argsOk validates exact count', () {
      final desc = T3NativeCodeDesc(3);
      expect(desc.argsOk(2), isFalse);
      expect(desc.argsOk(3), isTrue);
      expect(desc.argsOk(4), isFalse);
    });

    test('argsOk validates with optional args', () {
      final desc = T3NativeCodeDesc.withOptional(2, 2);
      expect(desc.argsOk(1), isFalse);
      expect(desc.argsOk(2), isTrue);
      expect(desc.argsOk(3), isTrue);
      expect(desc.argsOk(4), isTrue);
      expect(desc.argsOk(5), isFalse);
    });

    test('argsOk validates with varargs', () {
      final desc = T3NativeCodeDesc.withVarargs(2, 1, true);
      expect(desc.argsOk(1), isFalse);
      expect(desc.argsOk(2), isTrue);
      expect(desc.argsOk(3), isTrue);
      expect(desc.argsOk(100), isTrue);
    });
  });

  group('Portable Binary - Basic Types', () {
    test('vmbPutLen/vmbGetLen round trip', () {
      final buf = Uint8List(vmbLen);
      vmbPutLen(buf, 0, 12345);
      expect(vmbGetLen(buf, 0), equals(12345));
    });

    test('vmbPutUint2/vmbGetUint2 round trip', () {
      final buf = Uint8List(vmbUint2);
      vmbPutUint2(buf, 0, 65535);
      expect(vmbGetUint2(buf, 0), equals(65535));
    });

    test('vmbPutUint4/vmbGetUint4 round trip', () {
      final buf = Uint8List(vmbUint4);
      vmbPutUint4(buf, 0, 4294967295);
      expect(vmbGetUint4(buf, 0), equals(4294967295));
    });

    test('vmbPutInt4/vmbGetInt4 round trip with positive', () {
      final buf = Uint8List(vmbInt4);
      vmbPutInt4(buf, 0, 2147483647);
      expect(vmbGetInt4(buf, 0), equals(2147483647));
    });

    test('vmbPutInt4/vmbGetInt4 round trip with negative', () {
      final buf = Uint8List(vmbInt4);
      vmbPutInt4(buf, 0, -2147483648);
      expect(vmbGetInt4(buf, 0), equals(-2147483648));
    });

    test('vmbPutObjId/vmbGetObjId round trip', () {
      final buf = Uint8List(vmbObjectId);
      vmbPutObjId(buf, 0, 123456);
      expect(vmbGetObjId(buf, 0), equals(123456));
    });

    test('vmbPutPropId/vmbGetPropId round trip', () {
      final buf = Uint8List(vmbPropId);
      vmbPutPropId(buf, 0, 54321);
      expect(vmbGetPropId(buf, 0), equals(54321));
    });
  });

  group('Portable Binary - Dataholder', () {
    test('vmbPutDh/vmbGetDh round trip with nil', () {
      final buf = Uint8List(vmbDataholder);
      final val = T3Value();
      val.setNil();

      vmbPutDh(buf, 0, val);
      final result = vmbGetDh(buf, 0);

      expect(result.type, equals(T3DataType.nil));
    });

    test('vmbPutDh/vmbGetDh round trip with integer', () {
      final buf = Uint8List(vmbDataholder);
      final val = T3Value();
      val.setInt(42);

      vmbPutDh(buf, 0, val);
      final result = vmbGetDh(buf, 0);

      expect(result.type, equals(T3DataType.int32));
      expect(result.getAsInt(), equals(42));
    });

    test('vmbPutDh/vmbGetDh round trip with object', () {
      final buf = Uint8List(vmbDataholder);
      final val = T3Value();
      val.setObj(100);

      vmbPutDh(buf, 0, val);
      final result = vmbGetDh(buf, 0);

      expect(result.type, equals(T3DataType.obj));
      expect(result.getAsObj(), equals(100));
    });

    test('vmbPutDh/vmbGetDh round trip with property', () {
      final buf = Uint8List(vmbDataholder);
      final val = T3Value();
      val.setPropId(50);

      vmbPutDh(buf, 0, val);
      final result = vmbGetDh(buf, 0);

      expect(result.type, equals(T3DataType.prop));
    });

    test('vmbPutDh/vmbGetDh round trip with bifPtr', () {
      final buf = Uint8List(vmbDataholder);
      final val = T3Value();
      val.setBifPtr(1, 2);

      vmbPutDh(buf, 0, val);
      final result = vmbGetDh(buf, 0);

      expect(result.type, equals(T3DataType.bifPtr));
    });

    test('vmbPutDhNil creates nil dataholder', () {
      final buf = Uint8List(vmbDataholder);
      vmbPutDhNil(buf, 0);

      final result = vmbGetDh(buf, 0);
      expect(result.type, equals(T3DataType.nil));
    });

    test('vmbPutDhObj creates object dataholder', () {
      final buf = Uint8List(vmbDataholder);
      vmbPutDhObj(buf, 0, 100);

      final result = vmbGetDh(buf, 0);
      expect(result.type, equals(T3DataType.obj));
      expect(result.getAsObj(), equals(100));
    });

    test('vmbPutDhProp creates property dataholder', () {
      final buf = Uint8List(vmbDataholder);
      vmbPutDhProp(buf, 0, 50);

      final result = vmbGetDh(buf, 0);
      expect(result.type, equals(T3DataType.prop));
    });

    test('vmbGetDhType extracts type', () {
      final buf = Uint8List(vmbDataholder);
      final val = T3Value();
      val.setInt(42);

      vmbPutDh(buf, 0, val);
      expect(vmbGetDhType(buf, 0), equals(T3DataType.int32));
    });

    test('vmbGetDhObj extracts object ID', () {
      final buf = Uint8List(vmbDataholder);
      vmbPutDhObj(buf, 0, 100);
      expect(vmbGetDhObj(buf, 0), equals(100));
    });

    test('vmbGetDhInt extracts integer', () {
      final buf = Uint8List(vmbDataholder);
      final val = T3Value();
      val.setInt(42);
      vmbPutDh(buf, 0, val);
      expect(vmbGetDhInt(buf, 0), equals(42));
    });

    test('vmbGetDhProp extracts property ID', () {
      final buf = Uint8List(vmbDataholder);
      vmbPutDhProp(buf, 0, 50);
      expect(vmbGetDhProp(buf, 0), equals(50));
    });

    test('vmbGetDhOfs extracts offset', () {
      final buf = Uint8List(vmbDataholder);
      final val = T3Value();
      val.setSstring(1000);
      vmbPutDh(buf, 0, val);
      expect(vmbGetDhOfs(buf, 0), equals(1000));
    });
  });

  group('Portable Binary - Edge Cases', () {
    test('handles zero values', () {
      final buf = Uint8List(vmbInt4);
      vmbPutInt4(buf, 0, 0);
      expect(vmbGetInt4(buf, 0), equals(0));
    });

    test('handles maximum positive int32', () {
      final buf = Uint8List(vmbInt4);
      vmbPutInt4(buf, 0, 2147483647);
      expect(vmbGetInt4(buf, 0), equals(2147483647));
    });

    test('handles minimum negative int32', () {
      final buf = Uint8List(vmbInt4);
      vmbPutInt4(buf, 0, -2147483648);
      expect(vmbGetInt4(buf, 0), equals(-2147483648));
    });

    test('handles maximum uint32', () {
      final buf = Uint8List(vmbUint4);
      vmbPutUint4(buf, 0, 4294967295);
      expect(vmbGetUint4(buf, 0), equals(4294967295));
    });

    test('handles negative integer in dataholder', () {
      final buf = Uint8List(vmbDataholder);
      final val = T3Value();
      val.setInt(-100);

      vmbPutDh(buf, 0, val);
      final result = vmbGetDh(buf, 0);

      expect(result.type, equals(T3DataType.int32));
      expect(result.getAsInt(), equals(-100));
    });
  });

  group('T3TypeError', () {
    test('creates exception with message', () {
      final err = T3TypeError('test error');
      expect(err.message, equals('test error'));
      expect(err.toString(), contains('test error'));
    });
  });
}
