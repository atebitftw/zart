// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_error.dart';

void main() {
  group('Error Codes', () {
    test('file error codes are defined', () {
      expect(vmErrReadFile, equals(101));
      expect(vmErrWriteFile, equals(102));
      expect(vmErrFileNotFound, equals(103));
      expect(vmErrCreateFile, equals(104));
      expect(vmErrCloseFile, equals(105));
      expect(vmErrDeleteFile, equals(106));
    });

    test('memory error codes are defined', () {
      expect(vmErrObjInUse, equals(201));
      expect(vmErrOutOfMemory, equals(202));
      expect(vmErrNoMemForPage, equals(203));
      expect(vmErrBadPoolPageSize, equals(204));
      expect(vmErrOutOfPropids, equals(205));
      expect(vmErrCircularInit, equals(206));
    });

    test('image file error codes are defined', () {
      expect(vmErrUnknownMetaclass, equals(301));
      expect(vmErrUnknownFuncSet, equals(302));
      expect(vmErrNotAnImageFile, equals(304));
      expect(vmErrImageIncompatVsn, equals(319));
      expect(vmErrImageNoCode, equals(320));
    });

    test('data manipulation error codes are defined', () {
      expect(vmErrNoStrConv, equals(2001));
      expect(vmErrBadTypeAdd, equals(2003));
      expect(vmErrNumValReqd, equals(2004));
      expect(vmErrIntValReqd, equals(2005));
      expect(vmErrDivideByZero, equals(2008));
      expect(vmErrInvalidComparison, equals(2009));
    });

    test('execution error codes are defined', () {
      expect(vmErrInvalidOpcode, equals(2301));
      expect(vmErrUnhandledExc, equals(2302));
      expect(vmErrStackOverflow, equals(2303));
      expect(vmErrBadTypeBif, equals(2304));
    });
  });

  group('T3ErrorParam', () {
    test('creates integer parameter', () {
      final param = T3ErrorParam.int(42);
      expect(param.type, equals(T3ErrorParamType.int));
      expect(param.asInt, equals(42));
    });

    test('creates unsigned long parameter', () {
      final param = T3ErrorParam.ulong(4294967295);
      expect(param.type, equals(T3ErrorParamType.ulong));
      expect(param.asInt, equals(4294967295));
    });

    test('creates string parameter', () {
      final param = T3ErrorParam.string('test error');
      expect(param.type, equals(T3ErrorParamType.string));
      expect(param.asString, equals('test error'));
    });

    test('creates metaclass parameter', () {
      final param = T3ErrorParam.metaclass('String/030000');
      expect(param.type, equals(T3ErrorParamType.metaclass));
      expect(param.asString, equals('String/030000'));
    });

    test('creates funcset parameter', () {
      final param = T3ErrorParam.funcset('tads-gen/030008');
      expect(param.type, equals(T3ErrorParamType.funcset));
      expect(param.asString, equals('tads-gen/030008'));
    });

    test('creates version flag parameter', () {
      final param = T3ErrorParam.versionFlag();
      expect(param.type, equals(T3ErrorParamType.versionFlag));
      expect(param.value, isNull);
    });
  });

  group('T3VmException - Basic', () {
    test('creates exception with no parameters', () {
      final exc = T3VmException(vmErrDivideByZero);
      expect(exc.errorCode, equals(vmErrDivideByZero));
      expect(exc.paramCount, equals(0));
      expect(exc.versionFlag, isFalse);
      expect(exc.metaclass, isNull);
      expect(exc.funcset, isNull);
    });

    test('creates exception with parameters', () {
      final params = [T3ErrorParam.int(42), T3ErrorParam.string('test')];
      final exc = T3VmException.withParams(vmErrWrongNumOfArgs, params);
      expect(exc.errorCode, equals(vmErrWrongNumOfArgs));
      expect(exc.paramCount, equals(2));
      expect(exc.getParamInt(0), equals(42));
      expect(exc.getParamString(1), equals('test'));
    });

    test('creates exception with version flag', () {
      final exc = T3VmException.withParams(vmErrMetaclassTooOld, [], versionFlag: true, metaclass: 'String/030000');
      expect(exc.versionFlag, isTrue);
      expect(exc.metaclass, equals('String/030000'));
    });

    test('creates exception with funcset', () {
      final exc = T3VmException.withParams(vmErrFuncsetTooOld, [], versionFlag: true, funcset: 'tads-gen/030008');
      expect(exc.versionFlag, isTrue);
      expect(exc.funcset, equals('tads-gen/030008'));
    });
  });

  group('T3VmException - Parameter Access', () {
    test('getParam returns parameter by index', () {
      final params = [T3ErrorParam.int(10), T3ErrorParam.string('error')];
      final exc = T3VmException.withParams(vmErrBadTypeBif, params);

      final param0 = exc.getParam(0);
      expect(param0.type, equals(T3ErrorParamType.int));
      expect(param0.asInt, equals(10));

      final param1 = exc.getParam(1);
      expect(param1.type, equals(T3ErrorParamType.string));
      expect(param1.asString, equals('error'));
    });

    test('getParamInt returns integer value', () {
      final params = [T3ErrorParam.int(123)];
      final exc = T3VmException.withParams(vmErrIndexOutOfRange, params);
      expect(exc.getParamInt(0), equals(123));
    });

    test('getParamString returns string value', () {
      final params = [T3ErrorParam.string('test message')];
      final exc = T3VmException.withParams(vmErrIntclsGeneralError, params);
      expect(exc.getParamString(0), equals('test message'));
    });
  });

  group('Error Messages', () {
    test('getErrorMessage returns short message by default', () {
      final msg = getErrorMessage(vmErrDivideByZero);
      expect(msg, equals('division by zero'));
    });

    test('getErrorMessage returns verbose message when requested', () {
      final msg = getErrorMessage(vmErrDivideByZero, verbose: true);
      expect(msg, equals('Arithmetic error - Division by zero.'));
    });

    test('getErrorMessage returns null for unknown error code', () {
      final msg = getErrorMessage(99999);
      expect(msg, isNull);
    });

    test('all common error codes have messages', () {
      final errorCodes = [
        vmErrReadFile,
        vmErrOutOfMemory,
        vmErrUnknownMetaclass,
        vmErrDivideByZero,
        vmErrStackOverflow,
        vmErrInvalidOpcode,
      ];

      for (final code in errorCodes) {
        final msg = getErrorMessage(code);
        expect(msg, isNotNull, reason: 'Error code $code should have a message');
        expect(msg, isNotEmpty);
      }
    });
  });

  group('Message Formatting', () {
    test('formats message with no parameters', () {
      final exc = T3VmException(vmErrDivideByZero);
      final formatted = exc.formatMessage();
      expect(formatted, equals('division by zero'));
    });

    test('formats message with %s string parameter', () {
      final params = [T3ErrorParam.string('MyClass')];
      final exc = T3VmException.withParams(vmErrUnknownMetaclass, params);
      final formatted = exc.formatMessage();
      expect(formatted, contains('MyClass'));
    });

    test('formats message with %d integer parameter', () {
      final template = 'Error at index %d';
      final params = [T3ErrorParam.int(42)];
      final exc = T3VmException.withParams(vmErrPackParse, params);
      final formatted = formatErrorMessage(template, exc);
      expect(formatted, equals('Error at index 42'));
    });

    test('formats message with %u unsigned parameter', () {
      final template = 'Value: %u';
      final params = [T3ErrorParam.ulong(4294967295)];
      final exc = T3VmException.withParams(vmErrNumOverflow, params);
      final formatted = formatErrorMessage(template, exc);
      expect(formatted, equals('Value: 4294967295'));
    });

    test('formats message with %x hexadecimal parameter', () {
      final template = 'Address: %x';
      final params = [T3ErrorParam.int(255)];
      final exc = T3VmException.withParams(vmErrInvalidOpcode, params);
      final formatted = formatErrorMessage(template, exc);
      expect(formatted, equals('Address: ff'));
    });

    test('formats message with %% escape', () {
      final template = 'Progress: 50%%';
      final exc = T3VmException(vmErrOutOfMemory);
      final formatted = formatErrorMessage(template, exc);
      expect(formatted, equals('Progress: 50%'));
    });

    test('formats message with multiple parameters', () {
      final template = 'Error %d: %s at %x';
      final params = [T3ErrorParam.int(42), T3ErrorParam.string('overflow'), T3ErrorParam.int(0x1234)];
      final exc = T3VmException.withParams(vmErrNumOverflow, params);
      final formatted = formatErrorMessage(template, exc);
      expect(formatted, equals('Error 42: overflow at 1234'));
    });

    test('handles missing parameters gracefully', () {
      final template = 'Error: %s %d';
      final params = [T3ErrorParam.string('test')];
      final exc = T3VmException.withParams(vmErrBadTypeBif, params);
      final formatted = formatErrorMessage(template, exc);
      expect(formatted, equals('Error: test %d'));
    });

    test('handles wrong parameter type gracefully', () {
      final template = 'Value: %d';
      final params = [T3ErrorParam.string('not a number')];
      final exc = T3VmException.withParams(vmErrBadTypeBif, params);
      final formatted = formatErrorMessage(template, exc);
      expect(formatted, equals('Value: ?'));
    });

    test('formats verbose message', () {
      final exc = T3VmException(vmErrStackOverflow);
      final formatted = exc.formatMessage(verbose: true);
      expect(formatted, contains('Stack overflow'));
      expect(formatted, contains('function or method calls'));
    });
  });

  group('Exception toString', () {
    test('toString returns formatted message', () {
      final exc = T3VmException(vmErrDivideByZero);
      expect(exc.toString(), equals('division by zero'));
    });

    test('toString formats parameters', () {
      final params = [T3ErrorParam.string('TestClass')];
      final exc = T3VmException.withParams(vmErrUnknownMetaclass, params);
      final str = exc.toString();
      expect(str, contains('TestClass'));
    });

    test('toString handles unknown error code', () {
      final exc = T3VmException(99999);
      expect(exc.toString(), equals('VM Error: code 99999'));
    });
  });

  group('Utility Functions', () {
    test('throwVmError throws exception', () {
      expect(
        () => throwVmError(vmErrDivideByZero),
        throwsA(isA<T3VmException>().having((e) => e.errorCode, 'errorCode', vmErrDivideByZero)),
      );
    });

    test('throwVmErrorWithParams throws exception with parameters', () {
      final params = [T3ErrorParam.int(42)];
      expect(
        () => throwVmErrorWithParams(vmErrIndexOutOfRange, params),
        throwsA(
          isA<T3VmException>()
              .having((e) => e.errorCode, 'errorCode', vmErrIndexOutOfRange)
              .having((e) => e.paramCount, 'paramCount', 1)
              .having((e) => e.getParamInt(0), 'param[0]', 42),
        ),
      );
    });
  });

  group('Real-World Error Scenarios', () {
    test('division by zero error', () {
      final exc = T3VmException(vmErrDivideByZero);
      expect(exc.toString(), equals('division by zero'));
    });

    test('stack overflow error', () {
      final exc = T3VmException(vmErrStackOverflow);
      final msg = exc.formatMessage(verbose: true);
      expect(msg, contains('Stack overflow'));
      expect(msg, contains('recursion'));
    });

    test('wrong number of arguments error', () {
      final params = [T3ErrorParam.string('myFunction')];
      final exc = T3VmException.withParams(vmErrWrongNumOfArgsCalling, params);
      final msg = exc.toString();
      expect(msg, contains('myFunction'));
      expect(msg, contains('argument'));
    });

    test('nil dereference error', () {
      final exc = T3VmException(vmErrNilDeref);
      expect(exc.toString(), equals('nil object reference'));
    });

    test('index out of range error', () {
      final exc = T3VmException(vmErrIndexOutOfRange);
      expect(exc.toString(), equals('index out of range'));
    });

    test('metaclass too old error with version info', () {
      final params = [T3ErrorParam.string('String/030005'), T3ErrorParam.string('String/030000')];
      final exc = T3VmException.withParams(vmErrMetaclassTooOld, params, versionFlag: true, metaclass: 'String/030005');

      expect(exc.versionFlag, isTrue);
      expect(exc.metaclass, equals('String/030005'));
      final msg = exc.toString();
      expect(msg, contains('String/030005'));
      expect(msg, contains('String/030000'));
    });

    test('unavailable intrinsic function error', () {
      final params = [T3ErrorParam.int(15), T3ErrorParam.string('tads-gen/030008')];
      final exc = T3VmException.withParams(vmErrUnavailIntrinsic, params);
      final msg = exc.toString();
      expect(msg, contains('15'));
      expect(msg, contains('tads-gen/030008'));
    });
  });

  group('Edge Cases', () {
    test('exception with empty parameter list', () {
      final exc = T3VmException.withParams(vmErrOutOfMemory, []);
      expect(exc.paramCount, equals(0));
    });

    test('format message with no format codes', () {
      final template = 'Simple error message';
      final exc = T3VmException(vmErrOutOfMemory);
      final formatted = formatErrorMessage(template, exc);
      expect(formatted, equals('Simple error message'));
    });

    test('format message with only %% escapes', () {
      final template = '100%% complete';
      final exc = T3VmException(vmErrOutOfMemory);
      final formatted = formatErrorMessage(template, exc);
      expect(formatted, equals('100% complete'));
    });

    test('negative integer parameter', () {
      final params = [T3ErrorParam.int(-42)];
      final exc = T3VmException.withParams(vmErrNumOverflow, params);
      expect(exc.getParamInt(0), equals(-42));
    });

    test('zero integer parameter', () {
      final params = [T3ErrorParam.int(0)];
      final exc = T3VmException.withParams(vmErrIndexOutOfRange, params);
      expect(exc.getParamInt(0), equals(0));
    });

    test('empty string parameter', () {
      final params = [T3ErrorParam.string('')];
      final exc = T3VmException.withParams(vmErrIntclsGeneralError, params);
      expect(exc.getParamString(0), equals(''));
    });

    test('very long string parameter', () {
      final longString = 'x' * 1000;
      final params = [T3ErrorParam.string(longString)];
      final exc = T3VmException.withParams(vmErrIntclsGeneralError, params);
      expect(exc.getParamString(0), equals(longString));
    });
  });
}
