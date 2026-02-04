// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_opcode.dart';

void main() {
  group('Opcode Constants', () {
    group('Push Instructions', () {
      test('have correct values', () {
        expect(opcPush0, equals(0x01));
        expect(opcPush1, equals(0x02));
        expect(opcPushInt8, equals(0x03));
        expect(opcPushInt, equals(0x04));
        expect(opcPushStr, equals(0x05));
        expect(opcPushLst, equals(0x06));
        expect(opcPushObj, equals(0x07));
        expect(opcPushNil, equals(0x08));
        expect(opcPushTrue, equals(0x09));
        expect(opcPushPropId, equals(0x0A));
        expect(opcPushFnPtr, equals(0x0B));
        expect(opcPushStrI, equals(0x0C));
        expect(opcPushParLst, equals(0x0D));
        expect(opcMakeLstPar, equals(0x0E));
        expect(opcPushEnum, equals(0x0F));
        expect(opcPushBifPtr, equals(0x10));
      });
    });

    group('Arithmetic/Logic Operations', () {
      test('have correct values', () {
        expect(opcNeg, equals(0x20));
        expect(opcBnot, equals(0x21));
        expect(opcAdd, equals(0x22));
        expect(opcSub, equals(0x23));
        expect(opcMul, equals(0x24));
        expect(opcBand, equals(0x25));
        expect(opcBor, equals(0x26));
        expect(opcShl, equals(0x27));
        expect(opcAshr, equals(0x28));
        expect(opcXor, equals(0x29));
        expect(opcDiv, equals(0x2A));
        expect(opcMod, equals(0x2B));
        expect(opcNot, equals(0x2C));
        expect(opcBoolize, equals(0x2D));
        expect(opcInc, equals(0x2E));
        expect(opcDec, equals(0x2F));
        expect(opcLshr, equals(0x30));
      });
    });

    group('Comparison Operations', () {
      test('have correct values', () {
        expect(opcEq, equals(0x40));
        expect(opcNe, equals(0x41));
        expect(opcLt, equals(0x42));
        expect(opcLe, equals(0x43));
        expect(opcGt, equals(0x44));
        expect(opcGe, equals(0x45));
      });
    });

    group('Return Instructions', () {
      test('have correct values', () {
        expect(opcRetval, equals(0x50));
        expect(opcRetnil, equals(0x51));
        expect(opcRettrue, equals(0x52));
        expect(opcRet, equals(0x54));
      });
    });

    group('Control Flow', () {
      test('have correct values', () {
        expect(opcSwitch, equals(0x90));
        expect(opcJmp, equals(0x91));
        expect(opcJt, equals(0x92));
        expect(opcJf, equals(0x93));
        expect(opcJe, equals(0x94));
        expect(opcJne, equals(0x95));
        expect(opcJgt, equals(0x96));
        expect(opcJge, equals(0x97));
        expect(opcJlt, equals(0x98));
        expect(opcJle, equals(0x99));
        expect(opcJst, equals(0x9A));
        expect(opcJsf, equals(0x9B));
        expect(opcLjsr, equals(0x9C));
        expect(opcLret, equals(0x9D));
        expect(opcJnil, equals(0x9E));
        expect(opcJnotNil, equals(0x9F));
        expect(opcJr0t, equals(0xA0));
        expect(opcJr0f, equals(0xA1));
      });
    });

    group('Debug Instructions', () {
      test('have correct values', () {
        expect(opcBp, equals(0xF1));
        expect(opcNop, equals(0xF2));
      });
    });

    group('PUSHCTXELE Sub-opcodes', () {
      test('have correct values', () {
        expect(pushctxeleTargProp, equals(0x01));
        expect(pushctxeleTargObj, equals(0x02));
        expect(pushctxeleDefObj, equals(0x03));
        expect(pushctxeleInvokee, equals(0x04));
      });
    });
  });

  group('VMB_DATAHOLDER Constant', () {
    test('has correct value', () {
      expect(vmbDataHolder, equals(5));
    });
  });

  group('T3Opcodes.opSize', () {
    test('has 256 entries', () {
      expect(T3Opcodes.opSize.length, equals(256));
    });

    test('push instructions have correct sizes', () {
      expect(T3Opcodes.opSize[opcPush0], equals(1));
      expect(T3Opcodes.opSize[opcPush1], equals(1));
      expect(T3Opcodes.opSize[opcPushInt8], equals(2));
      expect(T3Opcodes.opSize[opcPushInt], equals(5));
      expect(T3Opcodes.opSize[opcPushStr], equals(5));
      expect(T3Opcodes.opSize[opcPushLst], equals(5));
      expect(T3Opcodes.opSize[opcPushObj], equals(5));
      expect(T3Opcodes.opSize[opcPushNil], equals(1));
      expect(T3Opcodes.opSize[opcPushTrue], equals(1));
      expect(T3Opcodes.opSize[opcPushPropId], equals(3));
      expect(T3Opcodes.opSize[opcPushFnPtr], equals(5));
      expect(T3Opcodes.opSize[opcPushParLst], equals(2));
      expect(T3Opcodes.opSize[opcMakeLstPar], equals(1));
      expect(T3Opcodes.opSize[opcPushEnum], equals(5));
      expect(T3Opcodes.opSize[opcPushBifPtr], equals(5));
    });

    test('variable-length instructions are marked with 0', () {
      expect(T3Opcodes.opSize[opcPushStrI], equals(0));
      expect(T3Opcodes.opSize[opcSwitch], equals(0));
      expect(T3Opcodes.opSize[opcNamedArgTab], equals(0));
      expect(T3Opcodes.opSize[opcCallExt], equals(0));
    });

    test('arithmetic operations have size 1', () {
      expect(T3Opcodes.opSize[opcNeg], equals(1));
      expect(T3Opcodes.opSize[opcBnot], equals(1));
      expect(T3Opcodes.opSize[opcAdd], equals(1));
      expect(T3Opcodes.opSize[opcSub], equals(1));
      expect(T3Opcodes.opSize[opcMul], equals(1));
      expect(T3Opcodes.opSize[opcDiv], equals(1));
      expect(T3Opcodes.opSize[opcMod], equals(1));
    });

    test('comparison operations have size 1', () {
      expect(T3Opcodes.opSize[opcEq], equals(1));
      expect(T3Opcodes.opSize[opcNe], equals(1));
      expect(T3Opcodes.opSize[opcLt], equals(1));
      expect(T3Opcodes.opSize[opcLe], equals(1));
      expect(T3Opcodes.opSize[opcGt], equals(1));
      expect(T3Opcodes.opSize[opcGe], equals(1));
    });

    test('function call instructions have correct sizes', () {
      expect(T3Opcodes.opSize[opcCall], equals(6));
      expect(T3Opcodes.opSize[opcPtrCall], equals(2));
    });

    test('property access instructions have correct sizes', () {
      expect(T3Opcodes.opSize[opcGetProp], equals(3));
      expect(T3Opcodes.opSize[opcCallProp], equals(4));
      expect(T3Opcodes.opSize[opcPtrCallProp], equals(2));
      expect(T3Opcodes.opSize[opcGetPropSelf], equals(3));
      expect(T3Opcodes.opSize[opcCallPropSelf], equals(4));
      expect(T3Opcodes.opSize[opcObjGetProp], equals(7));
      expect(T3Opcodes.opSize[opcObjCallProp], equals(8));
    });

    test('jump instructions have size 3', () {
      expect(T3Opcodes.opSize[opcJmp], equals(3));
      expect(T3Opcodes.opSize[opcJt], equals(3));
      expect(T3Opcodes.opSize[opcJf], equals(3));
      expect(T3Opcodes.opSize[opcJe], equals(3));
      expect(T3Opcodes.opSize[opcJne], equals(3));
      expect(T3Opcodes.opSize[opcJgt], equals(3));
      expect(T3Opcodes.opSize[opcJge], equals(3));
      expect(T3Opcodes.opSize[opcJlt], equals(3));
      expect(T3Opcodes.opSize[opcJle], equals(3));
    });

    test('local variable instructions have correct sizes', () {
      expect(T3Opcodes.opSize[opcGetLcl1], equals(2));
      expect(T3Opcodes.opSize[opcGetLcl2], equals(3));
      expect(T3Opcodes.opSize[opcSetLcl1], equals(2));
      expect(T3Opcodes.opSize[opcSetLcl2], equals(3));
      expect(T3Opcodes.opSize[opcIncLcl], equals(3));
      expect(T3Opcodes.opSize[opcDecLcl], equals(3));
    });

    test('object creation instructions have correct sizes', () {
      expect(T3Opcodes.opSize[opcNew1], equals(3));
      expect(T3Opcodes.opSize[opcNew2], equals(5));
      expect(T3Opcodes.opSize[opcTrNew1], equals(3));
      expect(T3Opcodes.opSize[opcTrNew2], equals(5));
    });

    test('unused opcode 0xFF has marker size 255', () {
      expect(T3Opcodes.opSize[0xFF], equals(255));
    });
  });

  group('T3Opcodes.getOpSize()', () {
    group('fixed-size instructions', () {
      test('returns correct size for single-byte instructions', () {
        final data = Uint8List.fromList([opcPush0]);
        expect(T3Opcodes.getOpSize(data, 0), equals(1));
      });

      test('returns correct size for multi-byte instructions', () {
        // opcPushInt is 5 bytes: 1 opcode + 4 data
        final data = Uint8List.fromList([opcPushInt, 0, 0, 0, 0]);
        expect(T3Opcodes.getOpSize(data, 0), equals(5));
      });

      test('handles offset correctly', () {
        final data = Uint8List.fromList([0x00, 0x00, opcJmp, 0x00, 0x00]);
        expect(T3Opcodes.getOpSize(data, 2), equals(3));
      });
    });

    group('PUSHSTRI (variable-length inline string)', () {
      test('computes size for empty string', () {
        // opcPushStrI + UINT16 length (0) = 3 bytes
        final data = Uint8List.fromList([opcPushStrI, 0x00, 0x00]);
        expect(T3Opcodes.getOpSize(data, 0), equals(3));
      });

      test('computes size for short string', () {
        // opcPushStrI + UINT16 length (5) + 5 bytes = 8 bytes
        final data = Uint8List.fromList([
          opcPushStrI,
          0x05,
          0x00,
          0x48,
          0x65,
          0x6C,
          0x6C,
          0x6F,
        ]);
        expect(T3Opcodes.getOpSize(data, 0), equals(8));
      });

      test('computes size for longer string', () {
        // opcPushStrI + UINT16 length (256) = 3 + 256 = 259 bytes
        final data = Uint8List.fromList([opcPushStrI, 0x00, 0x01]);
        expect(T3Opcodes.getOpSize(data, 0), equals(259));
      });

      test('handles little-endian length correctly', () {
        // Length = 0x0102 = 258 (little-endian: 0x02, 0x01)
        final data = Uint8List.fromList([opcPushStrI, 0x02, 0x01]);
        expect(T3Opcodes.getOpSize(data, 0), equals(3 + 258));
      });
    });

    group('SWITCH (variable-length case table)', () {
      test('computes size for empty switch', () {
        // 1 (opcode) + 2 (case count = 0) + 0 * 7 + 2 (default) = 5
        final data = Uint8List.fromList([opcSwitch, 0x00, 0x00, 0x00, 0x00]);
        expect(T3Opcodes.getOpSize(data, 0), equals(5));
      });

      test('computes size for switch with one case', () {
        // 1 + 2 + 1 * 7 + 2 = 12
        final data = Uint8List.fromList([opcSwitch, 0x01, 0x00]);
        expect(T3Opcodes.getOpSize(data, 0), equals(12));
      });

      test('computes size for switch with multiple cases', () {
        // 5 cases: 1 + 2 + 5 * 7 + 2 = 40
        final data = Uint8List.fromList([opcSwitch, 0x05, 0x00]);
        expect(T3Opcodes.getOpSize(data, 0), equals(40));
      });

      test('handles little-endian case count correctly', () {
        // 256 cases (0x0100): 1 + 2 + 256 * 7 + 2 = 1797
        final data = Uint8List.fromList([opcSwitch, 0x00, 0x01]);
        expect(T3Opcodes.getOpSize(data, 0), equals(1797));
      });
    });

    group('NAMEDARGTAB (variable-length named argument table)', () {
      test('computes size for empty table', () {
        // 1 + 2 + 0 = 3
        final data = Uint8List.fromList([opcNamedArgTab, 0x00, 0x00]);
        expect(T3Opcodes.getOpSize(data, 0), equals(3));
      });

      test('computes size for non-empty table', () {
        // 1 + 2 + 10 = 13
        final data = Uint8List.fromList([opcNamedArgTab, 0x0A, 0x00]);
        expect(T3Opcodes.getOpSize(data, 0), equals(13));
      });

      test('handles little-endian table size correctly', () {
        // Table size = 0x0100 = 256: 1 + 2 + 256 = 259
        final data = Uint8List.fromList([opcNamedArgTab, 0x00, 0x01]);
        expect(T3Opcodes.getOpSize(data, 0), equals(259));
      });
    });
  });

  group('Opcode Value Uniqueness', () {
    test('all defined opcodes have unique values', () {
      // Collect all defined opcode values
      final opcodes = <int, String>{};
      final duplicates = <String>[];

      void register(int value, String name) {
        if (opcodes.containsKey(value)) {
          duplicates.add(
            '$name and ${opcodes[value]} both have value 0x${value.toRadixString(16)}',
          );
        } else {
          opcodes[value] = name;
        }
      }

      // Push instructions
      register(opcPush0, 'opcPush0');
      register(opcPush1, 'opcPush1');
      register(opcPushInt8, 'opcPushInt8');
      register(opcPushInt, 'opcPushInt');
      register(opcPushStr, 'opcPushStr');
      register(opcPushLst, 'opcPushLst');
      register(opcPushObj, 'opcPushObj');
      register(opcPushNil, 'opcPushNil');
      register(opcPushTrue, 'opcPushTrue');
      register(opcPushPropId, 'opcPushPropId');
      register(opcPushFnPtr, 'opcPushFnPtr');
      register(opcPushStrI, 'opcPushStrI');
      register(opcPushParLst, 'opcPushParLst');
      register(opcMakeLstPar, 'opcMakeLstPar');
      register(opcPushEnum, 'opcPushEnum');
      register(opcPushBifPtr, 'opcPushBifPtr');

      // Arithmetic
      register(opcNeg, 'opcNeg');
      register(opcBnot, 'opcBnot');
      register(opcAdd, 'opcAdd');
      register(opcSub, 'opcSub');
      register(opcMul, 'opcMul');
      register(opcBand, 'opcBand');
      register(opcBor, 'opcBor');
      register(opcShl, 'opcShl');
      register(opcAshr, 'opcAshr');
      register(opcXor, 'opcXor');
      register(opcDiv, 'opcDiv');
      register(opcMod, 'opcMod');
      register(opcNot, 'opcNot');
      register(opcBoolize, 'opcBoolize');
      register(opcInc, 'opcInc');
      register(opcDec, 'opcDec');
      register(opcLshr, 'opcLshr');

      // Comparison
      register(opcEq, 'opcEq');
      register(opcNe, 'opcNe');
      register(opcLt, 'opcLt');
      register(opcLe, 'opcLe');
      register(opcGt, 'opcGt');
      register(opcGe, 'opcGe');

      // Return
      register(opcRetval, 'opcRetval');
      register(opcRetnil, 'opcRetnil');
      register(opcRettrue, 'opcRettrue');
      register(opcRet, 'opcRet');

      // Named args
      register(opcNamedArgPtr, 'opcNamedArgPtr');
      register(opcNamedArgTab, 'opcNamedArgTab');

      // Calls
      register(opcCall, 'opcCall');
      register(opcPtrCall, 'opcPtrCall');

      // Property access
      register(opcGetProp, 'opcGetProp');
      register(opcCallProp, 'opcCallProp');
      register(opcPtrCallProp, 'opcPtrCallProp');
      register(opcGetPropSelf, 'opcGetPropSelf');
      register(opcCallPropSelf, 'opcCallPropSelf');
      register(opcPtrCallPropSelf, 'opcPtrCallPropSelf');
      register(opcObjGetProp, 'opcObjGetProp');
      register(opcObjCallProp, 'opcObjCallProp');
      register(opcGetPropData, 'opcGetPropData');
      register(opcPtrGetPropData, 'opcPtrGetPropData');
      register(opcGetPropLcl1, 'opcGetPropLcl1');
      register(opcCallPropLcl1, 'opcCallPropLcl1');
      register(opcGetPropR0, 'opcGetPropR0');
      register(opcCallPropR0, 'opcCallPropR0');

      // Control flow
      register(opcSwitch, 'opcSwitch');
      register(opcJmp, 'opcJmp');
      register(opcJt, 'opcJt');
      register(opcJf, 'opcJf');
      register(opcJnil, 'opcJnil');
      register(opcJnotNil, 'opcJnotNil');

      // Debug
      register(opcBp, 'opcBp');
      register(opcNop, 'opcNop');

      expect(
        duplicates,
        isEmpty,
        reason: 'Found duplicate opcode values: $duplicates',
      );
    });
  });
}
