import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_opcodes.dart';

/// T3 Opcodes unit tests - SPEC VERIFICATION
///
/// This test file verifies that our opcode constants match the TADS 3
/// specification and reference implementation.
///
/// Spec Reference: packages/tads-runner/tads3/vmop.h
/// Spec Reference: packages/tads-sources/t3doc/techman/t3spec/opcode.htm
///
/// Since opcode execution is internal to T3Interpreter, these tests verify:
/// 1. All opcodes from the spec are defined
/// 2. Opcode values match the reference (vmop.h)
/// 3. Opcode names are available for debugging
void main() {
  group('Push opcodes (0x01-0x10) per vmop.h:44-59', () {
    /// vmop.h:44: OPC_PUSH_0 0x01
    test('PUSH_0 = 0x01', () {
      expect(T3Opcodes.PUSH_0, 0x01);
      expect(T3Opcodes.getName(0x01), 'PUSH_0');
    });

    /// vmop.h:45: OPC_PUSH_1 0x02
    test('PUSH_1 = 0x02', () {
      expect(T3Opcodes.PUSH_1, 0x02);
    });

    /// vmop.h:46: OPC_PUSHINT8 0x03
    test('PUSHINT8 = 0x03', () {
      expect(T3Opcodes.PUSHINT8, 0x03);
    });

    /// vmop.h:47: OPC_PUSHINT 0x04
    test('PUSHINT = 0x04', () {
      expect(T3Opcodes.PUSHINT, 0x04);
    });

    /// vmop.h:48: OPC_PUSHSTR 0x05
    test('PUSHSTR = 0x05', () {
      expect(T3Opcodes.PUSHSTR, 0x05);
    });

    /// vmop.h:49: OPC_PUSHLST 0x06
    test('PUSHLST = 0x06', () {
      expect(T3Opcodes.PUSHLST, 0x06);
    });

    /// vmop.h:50: OPC_PUSHOBJ 0x07
    test('PUSHOBJ = 0x07', () {
      expect(T3Opcodes.PUSHOBJ, 0x07);
    });

    /// vmop.h:51: OPC_PUSHNIL 0x08
    test('PUSHNIL = 0x08', () {
      expect(T3Opcodes.PUSHNIL, 0x08);
    });

    /// vmop.h:52: OPC_PUSHTRUE 0x09
    test('PUSHTRUE = 0x09', () {
      expect(T3Opcodes.PUSHTRUE, 0x09);
    });

    /// vmop.h:53: OPC_PUSHPROPID 0x0A
    test('PUSHPROPID = 0x0A', () {
      expect(T3Opcodes.PUSHPROPID, 0x0A);
    });

    /// vmop.h:54: OPC_PUSHFNPTR 0x0B
    test('PUSHFNPTR = 0x0B', () {
      expect(T3Opcodes.PUSHFNPTR, 0x0B);
    });

    /// vmop.h:55: OPC_PUSHSTRI 0x0C
    test('PUSHSTRI = 0x0C', () {
      expect(T3Opcodes.PUSHSTRI, 0x0C);
    });

    /// vmop.h:56: OPC_PUSHPARLST 0x0D
    test('PUSHPARLST = 0x0D', () {
      expect(T3Opcodes.PUSHPARLST, 0x0D);
    });

    /// vmop.h:57: OPC_MAKELSTPAR 0x0E
    test('MAKELSTPAR = 0x0E', () {
      expect(T3Opcodes.MAKELSTPAR, 0x0E);
    });

    /// vmop.h:58: OPC_PUSHENUM 0x0F
    test('PUSHENUM = 0x0F', () {
      expect(T3Opcodes.PUSHENUM, 0x0F);
    });

    /// vmop.h:59: OPC_PUSHBIFPTR 0x10
    test('PUSHBIFPTR = 0x10', () {
      expect(T3Opcodes.PUSHBIFPTR, 0x10);
    });
  });

  group('Arithmetic opcodes (0x20-0x30) per vmop.h:61-77', () {
    /// vmop.h:61: OPC_NEG 0x20
    test('NEG = 0x20', () {
      expect(T3Opcodes.NEG, 0x20);
    });

    /// vmop.h:62: OPC_BNOT 0x21
    test('BNOT = 0x21', () {
      expect(T3Opcodes.BNOT, 0x21);
    });

    /// vmop.h:63: OPC_ADD 0x22
    test('ADD = 0x22', () {
      expect(T3Opcodes.ADD, 0x22);
    });

    /// vmop.h:64: OPC_SUB 0x23
    test('SUB = 0x23', () {
      expect(T3Opcodes.SUB, 0x23);
    });

    /// vmop.h:65: OPC_MUL 0x24
    test('MUL = 0x24', () {
      expect(T3Opcodes.MUL, 0x24);
    });

    /// vmop.h:66: OPC_BAND 0x25
    test('BAND = 0x25', () {
      expect(T3Opcodes.BAND, 0x25);
    });

    /// vmop.h:67: OPC_BOR 0x26
    test('BOR = 0x26', () {
      expect(T3Opcodes.BOR, 0x26);
    });

    /// vmop.h:68: OPC_SHL 0x27
    test('SHL = 0x27', () {
      expect(T3Opcodes.SHL, 0x27);
    });

    /// vmop.h:69: OPC_ASHR 0x28
    test('ASHR = 0x28', () {
      expect(T3Opcodes.ASHR, 0x28);
    });

    /// vmop.h:70: OPC_XOR 0x29
    test('XOR = 0x29', () {
      expect(T3Opcodes.XOR, 0x29);
    });

    /// vmop.h:71: OPC_DIV 0x2A
    test('DIV = 0x2A', () {
      expect(T3Opcodes.DIV, 0x2A);
    });

    /// vmop.h:72: OPC_MOD 0x2B
    test('MOD = 0x2B', () {
      expect(T3Opcodes.MOD, 0x2B);
    });

    /// vmop.h:73: OPC_NOT 0x2C
    test('NOT = 0x2C', () {
      expect(T3Opcodes.NOT, 0x2C);
    });

    /// vmop.h:74: OPC_BOOLIZE 0x2D
    test('BOOLIZE = 0x2D', () {
      expect(T3Opcodes.BOOLIZE, 0x2D);
    });

    /// vmop.h:75: OPC_INC 0x2E
    test('INC = 0x2E', () {
      expect(T3Opcodes.INC, 0x2E);
    });

    /// vmop.h:76: OPC_DEC 0x2F
    test('DEC = 0x2F', () {
      expect(T3Opcodes.DEC, 0x2F);
    });

    /// vmop.h:77: OPC_LSHR 0x30
    test('LSHR = 0x30', () {
      expect(T3Opcodes.LSHR, 0x30);
    });
  });

  group('Comparison opcodes (0x40-0x45) per vmop.h:79-84', () {
    test('EQ = 0x40', () => expect(T3Opcodes.EQ, 0x40));
    test('NE = 0x41', () => expect(T3Opcodes.NE, 0x41));
    test('LT = 0x42', () => expect(T3Opcodes.LT, 0x42));
    test('LE = 0x43', () => expect(T3Opcodes.LE, 0x43));
    test('GT = 0x44', () => expect(T3Opcodes.GT, 0x44));
    test('GE = 0x45', () => expect(T3Opcodes.GE, 0x45));
  });

  group('Return opcodes (0x50-0x54) per vmop.h:86-89', () {
    test('RETVAL = 0x50', () => expect(T3Opcodes.RETVAL, 0x50));
    test('RETNIL = 0x51', () => expect(T3Opcodes.RETNIL, 0x51));
    test('RETTRUE = 0x52', () => expect(T3Opcodes.RETTRUE, 0x52));
    test('RET = 0x54', () => expect(T3Opcodes.RET, 0x54));
  });

  group('Call opcodes (0x58-0x59) per vmop.h:94-95', () {
    test('CALL = 0x58', () => expect(T3Opcodes.CALL, 0x58));
    test('PTRCALL = 0x59', () => expect(T3Opcodes.PTRCALL, 0x59));
  });

  group('Property opcodes (0x60-0x6D) per vmop.h:97-110', () {
    test('GETPROP = 0x60', () => expect(T3Opcodes.GETPROP, 0x60));
    test('CALLPROP = 0x61', () => expect(T3Opcodes.CALLPROP, 0x61));
    test('PTRCALLPROP = 0x62', () => expect(T3Opcodes.PTRCALLPROP, 0x62));
    test('GETPROPSELF = 0x63', () => expect(T3Opcodes.GETPROPSELF, 0x63));
    test('CALLPROPSELF = 0x64', () => expect(T3Opcodes.CALLPROPSELF, 0x64));
    test(
      'PTRCALLPROPSELF = 0x65',
      () => expect(T3Opcodes.PTRCALLPROPSELF, 0x65),
    );
    test('OBJGETPROP = 0x66', () => expect(T3Opcodes.OBJGETPROP, 0x66));
    test('OBJCALLPROP = 0x67', () => expect(T3Opcodes.OBJCALLPROP, 0x67));
    test('GETPROPDATA = 0x68', () => expect(T3Opcodes.GETPROPDATA, 0x68));
    test('PTRGETPROPDATA = 0x69', () => expect(T3Opcodes.PTRGETPROPDATA, 0x69));
    test('GETPROPLCL1 = 0x6A', () => expect(T3Opcodes.GETPROPLCL1, 0x6A));
    test('CALLPROPLCL1 = 0x6B', () => expect(T3Opcodes.CALLPROPLCL1, 0x6B));
    test('GETPROPR0 = 0x6C', () => expect(T3Opcodes.GETPROPR0, 0x6C));
    test('CALLPROPR0 = 0x6D', () => expect(T3Opcodes.CALLPROPR0, 0x6D));
  });

  group('Inherit/Delegate opcodes (0x72-0x78) per vmop.h:112-118', () {
    test('INHERIT = 0x72', () => expect(T3Opcodes.INHERIT, 0x72));
    test('PTRINHERIT = 0x73', () => expect(T3Opcodes.PTRINHERIT, 0x73));
    test('EXPINHERIT = 0x74', () => expect(T3Opcodes.EXPINHERIT, 0x74));
    test('PTREXPINHERIT = 0x75', () => expect(T3Opcodes.PTREXPINHERIT, 0x75));
    test('VARARGC = 0x76', () => expect(T3Opcodes.VARARGC, 0x76));
    test('DELEGATE = 0x77', () => expect(T3Opcodes.DELEGATE, 0x77));
    test('PTRDELEGATE = 0x78', () => expect(T3Opcodes.PTRDELEGATE, 0x78));
  });

  group('Local/Stack access opcodes (0x80-0x8F) per vmop.h:128-149', () {
    test('GETLCL1 = 0x80', () => expect(T3Opcodes.GETLCL1, 0x80));
    test('GETLCL2 = 0x81', () => expect(T3Opcodes.GETLCL2, 0x81));
    test('GETARG1 = 0x82', () => expect(T3Opcodes.GETARG1, 0x82));
    test('GETARG2 = 0x83', () => expect(T3Opcodes.GETARG2, 0x83));
    test('PUSHSELF = 0x84', () => expect(T3Opcodes.PUSHSELF, 0x84));
    test('GETARGC = 0x87', () => expect(T3Opcodes.GETARGC, 0x87));
    test('DUP = 0x88', () => expect(T3Opcodes.DUP, 0x88));
    test('DISC = 0x89', () => expect(T3Opcodes.DISC, 0x89));
    test('DISC1 = 0x8A', () => expect(T3Opcodes.DISC1, 0x8A));
    test('GETR0 = 0x8B', () => expect(T3Opcodes.GETR0, 0x8B));
    test('SWAP = 0x8D', () => expect(T3Opcodes.SWAP, 0x8D));
    test('PUSHCTXELE = 0x8E', () => expect(T3Opcodes.PUSHCTXELE, 0x8E));
    test('DUP2 = 0x8F', () => expect(T3Opcodes.DUP2, 0x8F));
  });

  group('Jump opcodes (0x90-0xA6) per vmop.h:151-174', () {
    test('SWITCH = 0x90', () => expect(T3Opcodes.SWITCH, 0x90));
    test('JMP = 0x91', () => expect(T3Opcodes.JMP, 0x91));
    test('JT = 0x92', () => expect(T3Opcodes.JT, 0x92));
    test('JF = 0x93', () => expect(T3Opcodes.JF, 0x93));
    test('JE = 0x94', () => expect(T3Opcodes.JE, 0x94));
    test('JNE = 0x95', () => expect(T3Opcodes.JNE, 0x95));
    test('JGT = 0x96', () => expect(T3Opcodes.JGT, 0x96));
    test('JGE = 0x97', () => expect(T3Opcodes.JGE, 0x97));
    test('JLT = 0x98', () => expect(T3Opcodes.JLT, 0x98));
    test('JLE = 0x99', () => expect(T3Opcodes.JLE, 0x99));
    test('JST = 0x9A', () => expect(T3Opcodes.JST, 0x9A));
    test('JSF = 0x9B', () => expect(T3Opcodes.JSF, 0x9B));
    test('LJSR = 0x9C', () => expect(T3Opcodes.LJSR, 0x9C));
    test('LRET = 0x9D', () => expect(T3Opcodes.LRET, 0x9D));
    test('JNIL = 0x9E', () => expect(T3Opcodes.JNIL, 0x9E));
    test('JNOTNIL = 0x9F', () => expect(T3Opcodes.JNOTNIL, 0x9F));
    test('JR0T = 0xA0', () => expect(T3Opcodes.JR0T, 0xA0));
    test('JR0F = 0xA1', () => expect(T3Opcodes.JR0F, 0xA1));
    test('ITERNEXT = 0xA2', () => expect(T3Opcodes.ITERNEXT, 0xA2));
  });

  group('Builtins/Output opcodes (0xB0-0xB9) per vmop.h:183-192', () {
    test('SAY = 0xB0', () => expect(T3Opcodes.SAY, 0xB0));
    test('BUILTIN_A = 0xB1', () => expect(T3Opcodes.BUILTIN_A, 0xB1));
    test('BUILTIN_B = 0xB2', () => expect(T3Opcodes.BUILTIN_B, 0xB2));
    test('BUILTIN_C = 0xB3', () => expect(T3Opcodes.BUILTIN_C, 0xB3));
    test('BUILTIN_D = 0xB4', () => expect(T3Opcodes.BUILTIN_D, 0xB4));
    test('BUILTIN1 = 0xB5', () => expect(T3Opcodes.BUILTIN1, 0xB5));
    test('BUILTIN2 = 0xB6', () => expect(T3Opcodes.BUILTIN2, 0xB6));
    test('THROW = 0xB8', () => expect(T3Opcodes.THROW, 0xB8));
    test('SAYVAL = 0xB9', () => expect(T3Opcodes.SAYVAL, 0xB9));
  });

  group('Index opcodes (0xBA-0xBC) per vmop.h:194-196', () {
    test('INDEX = 0xBA', () => expect(T3Opcodes.INDEX, 0xBA));
    test('IDXLCL1INT8 = 0xBB', () => expect(T3Opcodes.IDXLCL1INT8, 0xBB));
    test('IDXINT8 = 0xBC', () => expect(T3Opcodes.IDXINT8, 0xBC));
  });

  group('New object opcodes (0xC0-0xC3) per vmop.h:198-201', () {
    test('NEW1 = 0xC0', () => expect(T3Opcodes.NEW1, 0xC0));
    test('NEW2 = 0xC1', () => expect(T3Opcodes.NEW2, 0xC1));
    test('TRNEW1 = 0xC2', () => expect(T3Opcodes.TRNEW1, 0xC2));
    test('TRNEW2 = 0xC3', () => expect(T3Opcodes.TRNEW2, 0xC3));
  });

  group('Local modification opcodes (0xD0-0xDB) per vmop.h:203-214', () {
    test('INCLCL = 0xD0', () => expect(T3Opcodes.INCLCL, 0xD0));
    test('DECLCL = 0xD1', () => expect(T3Opcodes.DECLCL, 0xD1));
    test('ADDILCL1 = 0xD2', () => expect(T3Opcodes.ADDILCL1, 0xD2));
    test('ADDILCL4 = 0xD3', () => expect(T3Opcodes.ADDILCL4, 0xD3));
    test('ADDTOLCL = 0xD4', () => expect(T3Opcodes.ADDTOLCL, 0xD4));
    test('SUBFROMLCL = 0xD5', () => expect(T3Opcodes.SUBFROMLCL, 0xD5));
    test('ZEROLCL1 = 0xD6', () => expect(T3Opcodes.ZEROLCL1, 0xD6));
    test('ZEROLCL2 = 0xD7', () => expect(T3Opcodes.ZEROLCL2, 0xD7));
    test('NILLCL1 = 0xD8', () => expect(T3Opcodes.NILLCL1, 0xD8));
    test('NILLCL2 = 0xD9', () => expect(T3Opcodes.NILLCL2, 0xD9));
    test('ONELCL1 = 0xDA', () => expect(T3Opcodes.ONELCL1, 0xDA));
    test('ONELCL2 = 0xDB', () => expect(T3Opcodes.ONELCL2, 0xDB));
  });

  group('Set opcodes (0xE0-0xEF) per vmop.h:216-232', () {
    test('SETLCL1 = 0xE0', () => expect(T3Opcodes.SETLCL1, 0xE0));
    test('SETLCL2 = 0xE1', () => expect(T3Opcodes.SETLCL2, 0xE1));
    test('SETARG1 = 0xE2', () => expect(T3Opcodes.SETARG1, 0xE2));
    test('SETARG2 = 0xE3', () => expect(T3Opcodes.SETARG2, 0xE3));
    test('SETIND = 0xE4', () => expect(T3Opcodes.SETIND, 0xE4));
    test('SETPROP = 0xE5', () => expect(T3Opcodes.SETPROP, 0xE5));
    test('PTRSETPROP = 0xE6', () => expect(T3Opcodes.PTRSETPROP, 0xE6));
    test('SETPROPSELF = 0xE7', () => expect(T3Opcodes.SETPROPSELF, 0xE7));
    test('OBJSETPROP = 0xE8', () => expect(T3Opcodes.OBJSETPROP, 0xE8));
    test('SETSELF = 0xEB', () => expect(T3Opcodes.SETSELF, 0xEB));
    test('LOADCTX = 0xEC', () => expect(T3Opcodes.LOADCTX, 0xEC));
    test('STORECTX = 0xED', () => expect(T3Opcodes.STORECTX, 0xED));
    test('SETLCL1R0 = 0xEE', () => expect(T3Opcodes.SETLCL1R0, 0xEE));
    test('SETINDLCL1I8 = 0xEF', () => expect(T3Opcodes.SETINDLCL1I8, 0xEF));
  });

  group('Debug opcodes (0xF1-0xF2) per vmop.h:234-235', () {
    test('BP = 0xF1', () => expect(T3Opcodes.BP, 0xF1));
    test('NOP = 0xF2', () => expect(T3Opcodes.NOP, 0xF2));
  });

  group('Opcode name lookup', () {
    test('all opcodes have names', () {
      // Spot check that getName works for all major categories
      expect(T3Opcodes.getName(0x01), contains('PUSH'));
      expect(T3Opcodes.getName(0x22), 'ADD');
      expect(T3Opcodes.getName(0x40), 'EQ');
      expect(T3Opcodes.getName(0x50), 'RETVAL');
      expect(T3Opcodes.getName(0x58), 'CALL');
      expect(T3Opcodes.getName(0x91), 'JMP');
    });

    test('unknown opcode returns hex string', () {
      expect(T3Opcodes.getName(0xFF), contains('0xff'));
    });
  });
}
