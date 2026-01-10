import 'package:zart/src/tads3/vm/t3_intrinsic_class.dart';
import 'package:zart/src/tads3/vm/t3_bignumber.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';
import 'dart:typed_data';
import 'dart:math' as math;

/// Handles static method calls on IntrinsicClass objects.
///
/// This mixin provides the implementation for static methods like
/// BigNumber.getPi(), BigNumber.getE(), etc.
mixin T3IntrinsicClassHandlers {
  // These must be provided by the implementing class
  dynamic get execStack;
  dynamic get execRegisters;
  dynamic get execObjectTable;
  dynamic get execMetaclasses;

  void handleIntrinsicClassMethod(T3IntrinsicClass intrinsicClass, int propId, int? argc) {
    final metaclassName = intrinsicClass.metaclassName;

    if (metaclassName == 'bignumber') {
      _handleBigNumberStaticMethod(intrinsicClass, propId, argc);
    } else {
      // Other intrinsic classes not yet implemented
      if (argc != null && argc > 0) execStack.discard(argc);
      execRegisters.r0 = T3Value.nil();
    }
  }

  void _handleBigNumberStaticMethod(T3IntrinsicClass intrinsicClass, int propId, int? argc) {
    // Find which property index this is
    final metaclass = execMetaclasses?.byIndex(intrinsicClass.metaclassIndex);
    if (metaclass == null) {
      if (argc != null && argc > 0) execStack.discard(argc);
      execRegisters.r0 = T3Value.nil();
      return;
    }

    final funcIdx = metaclass.propertyIds.indexOf(propId);
    if (funcIdx < 0) {
      if (argc != null && argc > 0) execStack.discard(argc);
      execRegisters.r0 = T3Value.nil();
      return;
    }

    // BigNumber static methods (from vmbignum.h):
    // Index 33 = getPi
    // Index 34 = getE
    switch (funcIdx) {
      case 33: // getPi
        _handleGetPi(argc);
        break;
      case 34: // getE
        _handleGetE(argc);
        break;
      default:
        if (argc != null && argc > 0) execStack.discard(argc);
        execRegisters.r0 = T3Value.nil();
    }
  }

  void _handleGetPi(int? argc) {
    if (argc == null || argc < 1) {
      execRegisters.r0 = T3Value.nil();
      return;
    }

    // Pop the precision argument
    final precisionVal = execStack.pop();
    if (precisionVal.type != T3DataType.int_) {
      execRegisters.r0 = T3Value.nil();
      return;
    }

    final precision = precisionVal.value;

    // High-precision pi string (600+ digits)
    const piDigits =
        '3'
        '1415926535897932384626433832795028841971693993751058209749445923'
        '0781640628620899862803482534211706798214808651328230664709384460'
        '9550582231725359408128481117450284102701938521105559644622948954'
        '9303819644288109756659334461284756482337867831652712019091456485'
        '6692346034861045432664821339360726024914127372458700660631558817'
        '4881520920962829254091715364367892590360011330530548820466521384'
        '1469519415116094330572703657595919530921861173819326117931051185'
        '4807446237996274956735188575272489122793818301194912983367336244'
        '0656643086021394946395224737190702179860943702770539217176293176'
        '7523846748184676694051320005681271452635608277857713427577896091';

    final requestedDigits = math.min(precision, piDigits.length);

    // Create BCD representation
    // Format: precision(2), actual_prec(2), exponent(2), flags(2), digits...
    final bcdBytes = <int>[];

    // Precision fields (little-endian UINT16)
    bcdBytes.add(requestedDigits & 0xFF);
    bcdBytes.add((requestedDigits >> 8) & 0xFF);
    bcdBytes.add(requestedDigits & 0xFF);
    bcdBytes.add((requestedDigits >> 8) & 0xFF);

    // Exponent: pi = 3.14... so exponent is 1 (one digit before decimal)
    final expValue = 1;
    bcdBytes.add(expValue & 0xFF);
    bcdBytes.add((expValue >> 8) & 0xFF);

    // Flags: 0 for positive, normal number
    bcdBytes.add(0);
    bcdBytes.add(0);

    // Now encode digits in BCD (2 digits per byte)
    for (int i = 0; i < requestedDigits; i += 2) {
      final digit1 = int.parse(piDigits[i]);
      final digit2 = i + 1 < requestedDigits ? int.parse(piDigits[i + 1]) : 0;
      bcdBytes.add((digit1 << 4) | digit2);
    }

    // Create the BigNumber object
    final objId = execObjectTable.allocateObjectId();
    final bigNum = T3BigNumber(objectId: objId, data: Uint8List.fromList(bcdBytes), isTransient: true);

    execObjectTable.registerObject(bigNum);
    execRegisters.r0 = T3Value.fromObject(objId);
  }

  void _handleGetE(int? argc) {
    // Stub for now - similar to getPi but with e
    if (argc != null && argc > 0) execStack.discard(argc);
    execRegisters.r0 = T3Value.nil();
  }
}
