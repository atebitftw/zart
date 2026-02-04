// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// TADS3 BigNumber Metaclass
///
/// BigNumber provides arbitrary-precision floating-point arithmetic.
///
/// Ported from vmbignum.cpp/vmbignum.h
library;

import 'dart:math';
import 'dart:typed_data';
import 'package:zart/src/tads3/vm/t3_error.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';
import 'package:zart/src/tads3/vm/t3_globals.dart';
import 'package:zart/src/tads3/vm/t3_string.dart';

// --- Property indices (from vmbignum.cpp) ---
const int _propIdxFormat = 0;
const int _propIdxGetPrec = 2;
const int _propIdxSetPrec = 3;
const int _propIdxAbs = 4;
const int _propIdxFloor = 5;
const int _propIdxCeil = 6;
const int _propIdxGetFrac = 26;
const int _propIdxGetWhole = 27;
const int _propIdxToInt = 28;
const int _propIdxToHex = 29;
const int _propIdxSqrt = 7;
const int _propIdxExp = 12;
const int _propIdxLog = 13;
const int _propIdxLog10 = 14;
const int _propIdxSin = 16;
const int _propIdxCos = 17;
const int _propIdxTan = 18;
const int _propIdxASin = 19;
const int _propIdxACos = 20;
const int _propIdxATan = 21;
const int _propIdxATan2 = 22;
const int _propIdxSinh = 23;
const int _propIdxCosh = 24;
const int _propIdxTanh = 25;
const int _propIdxScaleTen = 1;
const int _propIdxRoundToDecimal = 8;
const int _propIdxGetScale = 9;
const int _propIdxIsNegative = 11;
const int _propIdxPow = 15;
const int _propIdxRadToDeg = 30;
const int _propIdxDegToRad = 31;
const int _propIdxNumType = 32;
const int _propIdxGetSigDigs = 33;
const int _propIdxCopySignFrom = 34;

/// BigNumber object.
class T3ObjBigNumber extends T3Object {
  int _precision;
  int _exponent = 0;
  BigInt _mantissa = BigInt.zero;
  bool _isNegative = false;
  bool _isInfinity = false;
  bool _isNaN = false;

  T3ObjBigNumber(this._precision);

  T3ObjBigNumber.zero(this._precision);

  T3ObjBigNumber.nan() : _precision = 1, _isNaN = true;

  T3ObjBigNumber.infinity(bool negative)
    : _precision = 1,
      _isInfinity = true,
      _isNegative = negative;

  @override
  T3Metaclass getMetaclassReg() => T3MetaclassBigNumber.instance;

  // --- Serialization ---

  void loadFromBcd(Uint8List data) {
    if (data.length < 5) throw T3VmException(vmErrInvalMetaclassData);

    final view = ByteData.sublistView(data);
    _precision = view.getUint16(0, Endian.little);
    _exponent = view.getInt16(2, Endian.little);
    final flags = data[4];

    _isNegative = (flags & 0x01) != 0;
    _isInfinity = (flags & 0x02) != 0;
    _isNaN = (flags & 0x04) != 0;

    if (!_isInfinity && !_isNaN) {
      _mantissa = BigInt.zero;
      final nibbleCount = _precision;
      for (int i = 0; i < nibbleCount; i++) {
        final byteIdx = 5 + (i ~/ 2);
        if (byteIdx >= data.length) break;
        final nibble = (i % 2 == 0)
            ? (data[byteIdx] >> 4)
            : (data[byteIdx] & 0x0F);
        _mantissa = _mantissa * BigInt.from(10) + BigInt.from(nibble);
      }
    }
  }

  Uint8List saveToBcd() {
    final byteCount = 5 + (_precision + 1) ~/ 2;
    final data = Uint8List(byteCount);
    final view = ByteData.view(data.buffer);

    view.setUint16(0, _precision, Endian.little);
    view.setInt16(2, _exponent, Endian.little);

    int flags = 0;
    if (_isNegative) flags |= 0x01;
    if (_isInfinity) flags |= 0x02;
    if (_isNaN) flags |= 0x04;
    data[4] = flags;

    if (!_isInfinity && !_isNaN) {
      String s = _mantissa.toString().padRight(_precision, '0');
      for (int i = 0; i < _precision; i++) {
        final digit = int.parse(s[i]);
        final byteIdx = 5 + (i ~/ 2);
        if (i % 2 == 0) {
          data[byteIdx] = (digit << 4) | (data[byteIdx] & 0x0F);
        } else {
          data[byteIdx] = (data[byteIdx] & 0xF0) | digit;
        }
      }
    }
    return data;
  }

  // --- Arithmetic ---

  @override
  bool addVal(T3VM vm, T3Value result, int self, T3Value val) {
    final other = _toBigNumber(vm, val);
    if (other == null) return false;
    final res = doAdd(other);
    result.setObj(vm.objTable.allocObj(vm, false));
    vm.objTable.setObj(result.getAsObj()!, res);
    return true;
  }

  @override
  bool subVal(T3VM vm, T3Value result, int self, T3Value val) {
    final other = _toBigNumber(vm, val);
    if (other == null) return false;
    final res = doSub(other);
    result.setObj(vm.objTable.allocObj(vm, false));
    vm.objTable.setObj(result.getAsObj()!, res);
    return true;
  }

  @override
  bool mulVal(T3VM vm, T3Value result, int self, T3Value val) {
    final other = _toBigNumber(vm, val);
    if (other == null) return false;
    final res = doMul(other);
    result.setObj(vm.objTable.allocObj(vm, false));
    vm.objTable.setObj(result.getAsObj()!, res);
    return true;
  }

  @override
  bool divVal(T3VM vm, T3Value result, int self, T3Value val) {
    final other = _toBigNumber(vm, val);
    if (other == null) return false;
    if (other.isZero) throw T3VmException(vmErrDivideByZero);
    final res = doDiv(other);
    result.setObj(vm.objTable.allocObj(vm, false));
    vm.objTable.setObj(result.getAsObj()!, res);
    return true;
  }

  @override
  bool negVal(T3VM vm, T3Value result, int self) {
    final res = copy();
    res._isNegative = !res._isNegative;
    result.setObj(vm.objTable.allocObj(vm, false));
    vm.objTable.setObj(result.getAsObj()!, res);
    return true;
  }

  @override
  int compareTo(T3VM vm, int self, T3Value val) {
    final other = _toBigNumber(vm, val);
    if (other == null) throw T3VmException(vmErrNumValReqd);
    return doCompare(other);
  }

  @override
  bool equals(T3VM vm, int self, T3Value val, int depth) {
    final other = _toBigNumber(vm, val);
    if (other == null) return false;
    return doCompare(other) == 0;
  }

  // --- Property Dispatch ---

  @override
  bool getProp(
    T3VM vm,
    int propId,
    T3Value retval,
    int self,
    List<int> sourceObj,
    int? argc,
  ) {
    final funcIdx = vm.metaTable!.propToVectorIdx(
      getMetaclassReg().getRegIdx(),
      propId,
    );
    if (funcIdx == null) {
      return false; // Metaclasses don't usually have super-properties in this way
    }

    if (evalProp(vm, funcIdx, retval, self, argc)) {
      sourceObj[0] = getMetaclassReg().getClassObj(vm);
      return true;
    }
    return false;
  }

  bool evalProp(T3VM vm, int funcIdx, T3Value retval, int self, int? argc) {
    switch (funcIdx) {
      case _propIdxFormat:
        return _getpFormat(vm, retval, argc);
      case _propIdxGetPrec:
        return _getpGetPrec(vm, retval, argc);
      case _propIdxSetPrec:
        return _getpSetPrec(vm, retval, argc);
      case _propIdxAbs:
        return _getpAbs(vm, retval, argc);
      case _propIdxFloor:
        return _getpFloor(vm, retval, argc);
      case _propIdxCeil:
        return _getpCeil(vm, retval, argc);
      case _propIdxGetFrac:
        return _getpGetFrac(vm, retval, argc);
      case _propIdxGetWhole:
        return _getpGetWhole(vm, retval, argc);
      case _propIdxToInt:
        return _getpToInt(vm, retval, argc);
      case _propIdxToHex:
        return _getpToHex(vm, retval, argc);
      case _propIdxSqrt:
        return _getpSqrt(vm, retval, argc);
      case _propIdxExp:
        return _getpExp(vm, retval, argc);
      case _propIdxLog:
        return _getpLog(vm, retval, argc);
      case _propIdxLog10:
        return _getpLog10(vm, retval, argc);
      case _propIdxSin:
        return _getpSin(vm, retval, argc);
      case _propIdxCos:
        return _getpCos(vm, retval, argc);
      case _propIdxTan:
        return _getpTan(vm, retval, argc);
      case _propIdxASin:
        return _getpASin(vm, retval, argc);
      case _propIdxACos:
        return _getpACos(vm, retval, argc);
      case _propIdxATan:
        return _getpATan(vm, retval, argc);
      case _propIdxATan2:
        return _getpATan2(vm, retval, argc);
      case _propIdxSinh:
        return _getpSinh(vm, retval, argc);
      case _propIdxCosh:
        return _getpCosh(vm, retval, argc);
      case _propIdxTanh:
        return _getpTanh(vm, retval, argc);
      case _propIdxScaleTen:
        return _getpScaleTen(vm, retval, argc);
      case _propIdxRoundToDecimal:
        return _getpRoundToDecimal(vm, retval, argc);
      case _propIdxGetScale:
        return _getpGetScale(vm, retval, argc);
      case _propIdxIsNegative:
        return _getpIsNegative(vm, retval, argc);
      case _propIdxPow:
        return _getpPow(vm, retval, argc);
      case _propIdxRadToDeg:
        return _getpRadToDeg(vm, retval, argc);
      case _propIdxDegToRad:
        return _getpDegToRad(vm, retval, argc);
      case _propIdxNumType:
        return _getpNumType(vm, retval, argc);
      case _propIdxGetSigDigs:
        return _getpGetSigDigs(vm, retval, argc);
      case _propIdxCopySignFrom:
        return _getpCopySignFrom(vm, retval, argc);
      default:
        return false;
    }
  }

  // --- Internal Logic ---

  T3ObjBigNumber copy() {
    final res = T3ObjBigNumber(_precision);
    res._exponent = _exponent;
    res._mantissa = _mantissa;
    res._isNegative = _isNegative;
    res._isInfinity = _isInfinity;
    res._isNaN = _isNaN;
    return res;
  }

  bool get isZero => _mantissa == BigInt.zero && !_isInfinity && !_isNaN;

  int doCompare(T3ObjBigNumber other) {
    if (_isNaN || other._isNaN) return 0;
    if (_isInfinity) {
      if (other._isInfinity) {
        if (_isNegative == other._isNegative) return 0;
        return _isNegative ? -1 : 1;
      }
      return _isNegative ? -1 : 1;
    }
    if (other._isInfinity) return other._isNegative ? 1 : -1;

    if (isZero) return other.isZero ? 0 : (other._isNegative ? 1 : -1);
    if (other.isZero) return _isNegative ? -1 : 1;

    if (_isNegative != other._isNegative) return _isNegative ? -1 : 1;

    // Align and compare
    int e1 = _exponent - _precision;
    int e2 = other._exponent - other._precision;
    BigInt m1 = _mantissa;
    BigInt m2 = other._mantissa;

    if (e1 > e2) {
      m1 *= BigInt.from(10).pow(e1 - e2);
    } else if (e2 > e1) {
      m2 *= BigInt.from(10).pow(e2 - e1);
    }

    int res = m1.compareTo(m2);
    return _isNegative ? -res : res;
  }

  T3ObjBigNumber doAdd(T3ObjBigNumber other) {
    if (_isNaN || other._isNaN) return T3ObjBigNumber.nan();
    if (_isInfinity) {
      if (other._isInfinity && _isNegative != other._isNegative) {
        return T3ObjBigNumber.nan();
      }
      return copy();
    }
    if (other._isInfinity) return other.copy();

    final resPrec = _precision > other._precision
        ? _precision
        : other._precision;
    int e1 = _exponent - _precision;
    int e2 = other._exponent - other._precision;
    int minE = e1 < e2 ? e1 : e2;

    BigInt m1 = _isNegative ? -_mantissa : _mantissa;
    BigInt m2 = other._isNegative ? -other._mantissa : other._mantissa;

    m1 *= BigInt.from(10).pow(e1 - minE);
    m2 *= BigInt.from(10).pow(e2 - minE);

    BigInt resM = m1 + m2;
    if (resM == BigInt.zero) return T3ObjBigNumber.zero(resPrec);

    final res = T3ObjBigNumber(resPrec);
    res._isNegative = resM < BigInt.zero;
    res._mantissa = resM.abs();
    res._exponent = minE + res._mantissa.toString().length;
    res.normalize();
    return res;
  }

  T3ObjBigNumber doSub(T3ObjBigNumber other) {
    final negOther = other.copy();
    negOther._isNegative = !negOther._isNegative;
    return doAdd(negOther);
  }

  T3ObjBigNumber doMul(T3ObjBigNumber other) {
    if (_isNaN || other._isNaN) return T3ObjBigNumber.nan();
    if (_isInfinity) {
      if (other.isZero) return T3ObjBigNumber.nan();
      return T3ObjBigNumber.infinity(_isNegative != other._isNegative);
    }
    if (other._isInfinity) {
      if (isZero) return T3ObjBigNumber.nan();
      return T3ObjBigNumber.infinity(_isNegative != other._isNegative);
    }

    final resPrec = _precision > other._precision
        ? _precision
        : other._precision;
    BigInt resM = _mantissa * other._mantissa;
    if (resM == BigInt.zero) return T3ObjBigNumber.zero(resPrec);

    final res = T3ObjBigNumber(resPrec);
    res._isNegative = _isNegative != other._isNegative;
    res._mantissa = resM;
    res._exponent =
        (_exponent - _precision) +
        (other._exponent - other._precision) +
        resM.toString().length;
    res.normalize();
    return res;
  }

  T3ObjBigNumber doDiv(T3ObjBigNumber other) {
    if (_isNaN || other._isNaN) return T3ObjBigNumber.nan();

    final resPrec = _precision > other._precision
        ? _precision
        : other._precision;
    int extra = resPrec + 5;
    BigInt m1 = _mantissa * BigInt.from(10).pow(extra);
    BigInt resM = m1 ~/ other._mantissa;

    final res = T3ObjBigNumber(resPrec);
    res._isNegative = _isNegative != other._isNegative;
    res._mantissa = resM;
    res._exponent =
        (_exponent - _precision) -
        (other._exponent - other._precision) -
        extra +
        resM.toString().length;
    res.normalize();
    return res;
  }

  void normalize() {
    if (_mantissa == BigInt.zero) {
      _exponent = 0;
      return;
    }
    String s = _mantissa.toString();
    int L = s.length;
    int P = _precision;

    if (L > P) {
      int diff = L - P;
      BigInt divisor = BigInt.from(10).pow(diff);
      BigInt half = divisor ~/ BigInt.from(2);
      BigInt remainder = _mantissa % divisor;

      _mantissa ~/= divisor;

      if (remainder > half ||
          (remainder == half && (_mantissa % BigInt.from(2) != BigInt.zero))) {
        _mantissa += BigInt.one;
        if (_mantissa.toString().length > P) {
          _mantissa ~/= BigInt.from(10);
          _exponent += 1;
        }
      }
    } else if (L < P) {
      _mantissa *= BigInt.from(10).pow(P - L);
    }
  }

  T3ObjBigNumber? _toBigNumber(T3VM vm, T3Value val) {
    if (val.type == T3DataType.obj) {
      final obj = vm.objTable!.getObj(val.getAsObj()!);
      if (obj is T3ObjBigNumber) return obj;
    } else if (val.type == T3DataType.int32) {
      return T3ObjBigNumber.fromInt(val.getAsInt()!, precision: _precision);
    }
    return null;
  }

  // --- Property Implementation ---

  bool _getpGetPrec(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 0, 0);
    retval.setInt(_precision);
    return true;
  }

  bool _getpSetPrec(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 1, 1);
    final popVal = T3Value();
    (vm as T3Globals).stack!.pop(popVal);
    final newPrec = popVal.getAsInt()!;
    final res = copy();
    res._precision = newPrec;
    res.normalize();
    final id = vm.objTable!.allocObj(vm, false);
    vm.objTable!.setObj(id, res);
    retval.setObj(id);
    return true;
  }

  bool _getpAbs(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 0, 0);
    final res = copy();
    res._isNegative = false;
    final id = vm.objTable!.allocObj(vm, false);
    vm.objTable!.setObj(id, res);
    retval.setObj(id);
    return true;
  }

  bool _getpFloor(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 0, 0);
    if (_isNaN || _isInfinity) {
      retval.setObj(vm.objTable!.allocObj(vm, false));
      vm.objTable!.setObj(retval.getAsObj()!, copy());
      return true;
    }
    final res = _doFloor();
    final id = vm.objTable!.allocObj(vm, false);
    vm.objTable!.setObj(id, res);
    retval.setObj(id);
    return true;
  }

  T3ObjBigNumber _doFloor() {
    // Floor is the largest integer <= value.
    // For positive: truncate. For negative: if there's a fractional part, subtract 1.
    final whole = _doGetWhole();
    if (_isNegative && !_doGetFrac().isZero) {
      return whole.doSub(T3ObjBigNumber.fromInt(1, precision: _precision));
    }
    return whole;
  }

  bool _getpCeil(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 0, 0);
    if (_isNaN || _isInfinity) {
      retval.setObj(vm.objTable!.allocObj(vm, false));
      vm.objTable!.setObj(retval.getAsObj()!, copy());
      return true;
    }
    final res = _doCeil();
    final id = vm.objTable!.allocObj(vm, false);
    vm.objTable!.setObj(id, res);
    retval.setObj(id);
    return true;
  }

  T3ObjBigNumber _doCeil() {
    // Ceil is the smallest integer >= value.
    final whole = _doGetWhole();
    if (!_isNegative && !_doGetFrac().isZero) {
      return whole.doAdd(T3ObjBigNumber.fromInt(1, precision: _precision));
    }
    return whole;
  }

  bool _getpGetFrac(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 0, 0);
    final res = _doGetFrac();
    final id = vm.objTable!.allocObj(vm, false);
    vm.objTable!.setObj(id, res);
    retval.setObj(id);
    return true;
  }

  T3ObjBigNumber _doGetFrac() {
    if (_isNaN || _isInfinity || _exponent <= 0) return copy();
    if (_exponent >= _precision) return T3ObjBigNumber.zero(_precision);

    // Fractal part is anything after the decimal point
    // Mantissa has P digits, e is number of digits before point.
    // So fractal part starts at index e.
    final s = _mantissa.toString();
    if (_exponent <= 0) return copy();

    final res = T3ObjBigNumber(_precision);
    res._isNegative = _isNegative;
    // Fractional part: zero out the first _exponent digits
    String fracS = s
        .substring(_exponent.clamp(0, s.length))
        .padRight(_precision, '0');
    res._mantissa = BigInt.parse(fracS);
    res._exponent = 0; // or adjust accordingly?
    // Normalization will fix it.
    res.normalize();
    return res;
  }

  bool _getpGetWhole(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 0, 0);
    final res = _doGetWhole();
    final id = vm.objTable!.allocObj(vm, false);
    vm.objTable!.setObj(id, res);
    retval.setObj(id);
    return true;
  }

  T3ObjBigNumber _doGetWhole() {
    if (_isNaN || _isInfinity) return copy();
    if (_exponent <= 0) return T3ObjBigNumber.zero(_precision);

    final res = T3ObjBigNumber(_precision);
    res._isNegative = _isNegative;
    String s = _mantissa.toString();
    if (_exponent >= s.length) {
      res._mantissa = _mantissa * BigInt.from(10).pow(_exponent - s.length);
      res._exponent = _exponent;
    } else {
      String wholeS = s.substring(0, _exponent).padRight(_precision, '0');
      res._mantissa = BigInt.parse(wholeS);
      res._exponent = _exponent;
    }
    res.normalize();
    return res;
  }

  bool _getpToInt(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 0, 0);
    if (_isNaN || _isInfinity) throw T3VmException(vmErrNumOverflow);

    BigInt val = toBigInt();
    if (val < BigInt.from(-2147483648) || val > BigInt.from(2147483647)) {
      throw T3VmException(vmErrNumOverflow);
    }
    retval.setInt(val.toInt());
    return true;
  }

  BigInt toBigInt() {
    if (_exponent <= 0) return BigInt.zero;
    String s = _mantissa.toString();
    BigInt res;
    if (_exponent >= s.length) {
      res = _mantissa * BigInt.from(10).pow(_exponent - s.length);
    } else {
      res = BigInt.parse(s.substring(0, _exponent));
    }
    return _isNegative ? -res : res;
  }

  bool _getpToHex(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 0, 0);
    if (_isNaN || _isInfinity) throw T3VmException(vmErrNumOverflow);

    BigInt val = toBigInt();
    if (val < BigInt.from(-2147483648) || val > BigInt.from(2147483647)) {
      throw T3VmException(vmErrNumOverflow);
    }
    // TADS hex is usually unsigned 32-bit? No, it says signed 32-bit.
    // Actually, vmbignum.cpp uses (long)v.
    String s = (val.toUnsigned(32)).toRadixString(16).toUpperCase();
    final id = vm.objTable!.allocObj(vm, false);
    vm.objTable!.setObj(id, T3ObjString(s));
    retval.setObj(id);
    return true;
  }

  bool _getpFormat(T3VM vm, T3Value retval, int? argc) {
    // Basic implementation of format
    final s = toString();
    final id = vm.objTable.allocObj(vm, false);
    vm.objTable.setObj(id, T3ObjString(s));
    retval.setObj(id);
    return true;
  }

  // --- Transcendental ---

  bool _getpSqrt(T3VM vm, T3Value retval, int? argc) =>
      _transcendental1(vm, retval, argc, (d) => sqrt(d));
  bool _getpExp(T3VM vm, T3Value retval, int? argc) =>
      _transcendental1(vm, retval, argc, (d) => exp(d));
  bool _getpLog(T3VM vm, T3Value retval, int? argc) =>
      _transcendental1(vm, retval, argc, (d) => log(d));
  bool _getpLog10(T3VM vm, T3Value retval, int? argc) =>
      _transcendental1(vm, retval, argc, (d) => log(d) / ln10);
  bool _getpSin(T3VM vm, T3Value retval, int? argc) =>
      _transcendental1(vm, retval, argc, (d) => sin(d));
  bool _getpCos(T3VM vm, T3Value retval, int? argc) =>
      _transcendental1(vm, retval, argc, (d) => cos(d));
  bool _getpTan(T3VM vm, T3Value retval, int? argc) =>
      _transcendental1(vm, retval, argc, (d) => tan(d));
  bool _getpASin(T3VM vm, T3Value retval, int? argc) =>
      _transcendental1(vm, retval, argc, (d) => asin(d));
  bool _getpACos(T3VM vm, T3Value retval, int? argc) =>
      _transcendental1(vm, retval, argc, (d) => acos(d));
  bool _getpATan(T3VM vm, T3Value retval, int? argc) =>
      _transcendental1(vm, retval, argc, (d) => atan(d));
  bool _getpSinh(T3VM vm, T3Value retval, int? argc) =>
      _transcendental1(vm, retval, argc, (d) => (exp(d) - exp(-d)) / 2);
  bool _getpCosh(T3VM vm, T3Value retval, int? argc) =>
      _transcendental1(vm, retval, argc, (d) => (exp(d) + exp(-d)) / 2);
  bool _getpTanh(T3VM vm, T3Value retval, int? argc) {
    return _transcendental1(vm, retval, argc, (d) {
      double e2x = exp(2 * d);
      return (e2x - 1) / (e2x + 1);
    });
  }

  bool _getpATan2(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 1, 1);
    final popVal = T3Value();
    (vm as T3Globals).stack!.pop(popVal);
    final other = _toBigNumber(vm, popVal);
    if (other == null) throw T3VmException(vmErrNumValReqd);

    double d1 = toDouble();
    double d2 = other.toDouble();
    double resD = atan2(d1, d2);

    final res = T3ObjBigNumber.fromDouble(resD, precision: _precision);
    final id = vm.objTable!.allocObj(vm, false);
    vm.objTable!.setObj(id, res);
    retval.setObj(id);
    return true;
  }

  bool _transcendental1(
    T3VM vm,
    T3Value retval,
    int? argc,
    double Function(double) op,
  ) {
    _checkArgs(argc, 0, 0);
    double d = toDouble();
    double resD = op(d);
    final res = T3ObjBigNumber.fromDouble(resD, precision: _precision);
    final id = vm.objTable!.allocObj(vm, false);
    vm.objTable!.setObj(id, res);
    retval.setObj(id);
    return true;
  }

  bool _getpScaleTen(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 1, 1);
    final popVal = T3Value();
    (vm as T3Globals).stack!.pop(popVal);
    final x = popVal.getAsInt()!;
    final res = copy();
    res._exponent += x;
    final id = vm.objTable!.allocObj(vm, false);
    vm.objTable!.setObj(id, res);
    retval.setObj(id);
    return true;
  }

  bool _getpRoundToDecimal(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 1, 1);
    final popVal = T3Value();
    (vm as T3Globals).stack!.pop(popVal);
    final places = popVal.getAsInt()!;

    // Rounding: value * 10^places, floor, value / 10^places
    double d = toDouble();
    double factor = pow(10, places).toDouble();
    double resD = (d * factor).round() / factor;

    final rounded = T3ObjBigNumber.fromDouble(resD, precision: _precision);
    final id = vm.objTable!.allocObj(vm, false);
    vm.objTable!.setObj(id, rounded);
    retval.setObj(id);
    return true;
  }

  bool _getpGetScale(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 0, 0);
    retval.setInt(_exponent);
    return true;
  }

  bool _getpIsNegative(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 0, 0);
    if (_isNegative) {
      retval.setTrue();
    } else {
      retval.setNil();
    }
    return true;
  }

  bool _getpPow(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 1, 1);
    final popVal = T3Value();
    (vm as T3Globals).stack!.pop(popVal);
    final other = _toBigNumber(vm, popVal);
    if (other == null) throw T3VmException(vmErrNumValReqd);

    double d1 = toDouble();
    double d2 = other.toDouble();
    double resD = pow(d1, d2).toDouble();

    final res = T3ObjBigNumber.fromDouble(resD, precision: _precision);
    final id = vm.objTable!.allocObj(vm, false);
    vm.objTable!.setObj(id, res);
    retval.setObj(id);
    return true;
  }

  bool _getpRadToDeg(T3VM vm, T3Value retval, int? argc) =>
      _transcendental1(vm, retval, argc, (d) => d * 180 / pi);
  bool _getpDegToRad(T3VM vm, T3Value retval, int? argc) =>
      _transcendental1(vm, retval, argc, (d) => d * pi / 180);

  bool _getpNumType(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 0, 0);
    if (_isNaN)
      retval.setInt(3); // BIGNUM_NAN
    else if (_isInfinity)
      retval.setInt(2); // BIGNUM_INF
    else
      retval.setInt(1); // BIGNUM_NUM
    return true;
  }

  bool _getpGetSigDigs(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 0, 0);
    String s = _mantissa.toString();
    int count = s.length;
    retval.setInt(count);
    return true;
  }

  bool _getpCopySignFrom(T3VM vm, T3Value retval, int? argc) {
    _checkArgs(argc, 1, 1);
    final popVal = T3Value();
    (vm as T3Globals).stack!.pop(popVal);
    final other = _toBigNumber(vm, popVal);
    if (other == null) throw T3VmException(vmErrNumValReqd);
    final res = copy();
    res._isNegative = other._isNegative;
    final id = vm.objTable!.allocObj(vm, false);
    vm.objTable!.setObj(id, res);
    retval.setObj(id);
    return true;
  }

  double toDouble() {
    if (_isNaN) return double.nan;
    if (_isInfinity)
      return _isNegative ? double.negativeInfinity : double.infinity;
    if (isZero) return 0.0;
    // toString() returns "-0.MantissaeExponent"
    return double.parse(toString());
  }

  static T3ObjBigNumber fromDouble(double value, {int precision = 32}) {
    if (value.isNaN) return T3ObjBigNumber.nan();
    if (value.isInfinite) return T3ObjBigNumber.infinity(value.isNegative);
    if (value == 0.0) return T3ObjBigNumber.zero(precision);

    String s = value.toStringAsExponential(precision - 1);
    // Format is "M.NNNe+EE" or "M.NNNe-EE"
    // We want to parse this back.
    // Actually, TADS normalization uses "0.MantissaeExponent"
    // Our toString() also does that.

    // Easier: use double.toString() and then parse it?
    // value.toStringAsExponential gives us the mantissa and exponent we need.
    final match = RegExp(r'^([+-]?\d)\.(\d+)e([+-]\d+)$').firstMatch(s);
    if (match == null) {
      // Fallback for simple values like "1e+20" which might not have dots?
      // toStringAsExponential should always have a dot if precision > 1.
      return T3ObjBigNumber.zero(precision);
    }

    final sign = match.group(1)!.startsWith('-') ? -1 : 1;
    final firstDigit = match.group(1)!.replaceAll('-', '');
    final restDigits = match.group(2)!;
    final exp = int.parse(match.group(3)!);

    final res = T3ObjBigNumber(precision);
    res._isNegative = sign < 0;
    res._mantissa = BigInt.parse(firstDigit + restDigits);
    res._exponent = exp + 1;
    res.normalize();
    return res;
  }

  void _checkArgs(int? argc, int min, int max) {
    if (argc != null && (argc < min || argc > max)) {
      throw T3VmException(vmErrWrongNumOfArgs);
    }
  }

  // --- T3Object Overrides ---

  @override
  void notifyDelete(T3VM vm, bool inRootSet) {}

  @override
  void setProp(T3VM vm, T3Undo? undo, int self, int propId, T3Value val) {
    throw T3VmException(vmErrInvalidSetprop);
  }

  @override
  bool isInstanceOf(T3VM vm, int obj) => false;

  @override
  int getSuperclass(T3VM vm, int self, int index) => invalidObjectId;

  @override
  void loadFromImage(T3VM vm, int self, Uint8List ptr, int offset, int size) {
    loadFromBcd(ptr.sublist(offset, offset + size));
  }

  @override
  void markRefs(T3VM vm, int state) {}

  @override
  bool inhProp(
    T3VM vm,
    int propId,
    T3Value retval,
    int self,
    int origTargetObj,
    int definingObj,
    List<int> sourceObj,
    int? argc,
  ) => false;

  @override
  void buildPropList(T3VM vm, int self, T3Value retval) {
    retval.setNil();
  }

  @override
  void applyUndo(T3VM vm, T3UndoRecord rec) {}

  @override
  void markUndoRef(T3VM vm, T3UndoRecord rec) {}

  @override
  void removeStaleUndoWeakRef(T3VM vm, T3UndoRecord rec) {}

  @override
  void saveToFile(T3VM vm, T3File fp) {}

  @override
  void restoreFromFile(T3VM vm, int self, T3File fp, T3ObjFixup fixups) {}

  @override
  String? castToString(T3VM vm, int self, T3Value newStr) {
    final s = toString();
    final strObj = T3ObjString(s);
    final strId = vm.objTable!.allocObj(vm, false);
    vm.objTable!.setObj(strId, strObj);
    newStr.setObj(strId);
    return s;
  }

  @override
  String toString() {
    if (_isNaN) return 'NaN';
    if (_isInfinity) return _isNegative ? '-Infinity' : 'Infinity';
    if (isZero) return '0';
    String s = _mantissa.toString();
    return '${_isNegative ? "-" : ""}0.${s}e$_exponent';
  }

  static T3ObjBigNumber fromInt(int value, {int precision = 32}) {
    if (value == 0) return T3ObjBigNumber.zero(precision);
    final obj = T3ObjBigNumber(precision);
    obj._isNegative = value < 0;
    int absVal = value.abs();
    String s = absVal.toString();
    obj._exponent = s.length;
    obj._mantissa = BigInt.from(absVal);
    obj.normalize();
    return obj;
  }

  static T3ObjBigNumber parse(String s, {int precision = 32}) {
    double value = double.tryParse(s) ?? 0.0;
    return fromDouble(value, precision: precision);
  }
}

/// TADS 3 BigNumber metaclass.
class T3MetaclassBigNumber extends T3Metaclass {
  static final instance = T3MetaclassBigNumber._();
  T3MetaclassBigNumber._();

  @override
  String getMetaName() => 'bignumber/030001';

  @override
  int createFromStack(T3VM vm, Uint8List pc, int pcOffset, int argc) {
    if (argc < 1 || argc > 2) throw T3VmException(vmErrWrongNumOfArgs);
    final g = vm as T3Globals;
    final val = T3Value();
    g.stack!.pop(val);
    int precision = 32;
    if (argc > 1) {
      final pVal = T3Value();
      g.stack!.pop(pVal);
      precision = pVal.getAsInt()!;
    }

    T3ObjBigNumber res;
    if (val.type == T3DataType.int32) {
      res = T3ObjBigNumber.fromInt(val.getAsInt()!, precision: precision);
    } else if (val.type == T3DataType.obj) {
      final obj = g.objTable!.getObj(val.getAsObj()!);
      if (obj is T3ObjBigNumber) {
        res = obj.copy();
        res._precision = precision;
        res.normalize();
      } else if (obj is T3ObjString) {
        res = T3ObjBigNumber.parse(obj.toString(), precision: precision);
      } else {
        throw T3VmException(vmErrBadTypeBif);
      }
    } else {
      throw T3VmException(vmErrBadTypeBif);
    }

    final id = g.objTable!.allocObj(g, false);
    g.objTable!.setObj(id, res);
    return id;
  }

  @override
  void createForImageLoad(T3VM vm, int id) {
    vm.objTable!.setObj(id, T3ObjBigNumber(0));
  }

  @override
  void createForRestore(T3VM vm, int id) {
    vm.objTable!.setObj(id, T3ObjBigNumber(0));
  }

  @override
  bool callStatProp(
    T3VM vm,
    T3Value result,
    Uint8List pc,
    int pcOffset,
    int argc,
    int prop,
  ) {
    return false;
  }

  @override
  int getClassObj(T3VM vm) => vm.metaTable!.getClassObj(getRegIdx());

  @override
  int getSupermeta(T3VM vm, int idx) => invalidObj;

  @override
  T3Metaclass? getSupermetaReg() => null;

  @override
  bool isMetaInstanceOf(T3VM vm, int obj) => false;
}
