// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// T3 VM Opcode Definitions.
///
/// This file contains opcode constants and instruction size helpers for the
/// TADS3 Virtual Machine. Ported from vmop.h and vmop.cpp.
library;

import 'dart:typed_data';

// ----------------------------------------------------------------------------
// Push Instructions (0x01 - 0x10)
// ----------------------------------------------------------------------------

/// Push constant integer 0.
const int opcPush0 = 0x01;

/// Push constant integer 1.
const int opcPush1 = 0x02;

/// Push SBYTE operand as integer.
const int opcPushInt8 = 0x03;

/// Push INT4 operand as integer.
const int opcPushInt = 0x04;

/// Push UINT4 operand as string constant.
const int opcPushStr = 0x05;

/// Push UINT4 operand as list constant.
const int opcPushLst = 0x06;

/// Push UINT4 operand as object ID.
const int opcPushObj = 0x07;

/// Push nil.
const int opcPushNil = 0x08;

/// Push true.
const int opcPushTrue = 0x09;

/// Push UINT2 operand as property ID.
const int opcPushPropId = 0x0A;

/// Push UINT4 code offset.
const int opcPushFnPtr = 0x0B;

/// Push inline string constant (variable-length).
const int opcPushStrI = 0x0C;

/// Push varargs parameter list.
const int opcPushParLst = 0x0D;

/// Push varargs parameter from list.
const int opcMakeLstPar = 0x0E;

/// Push an enum value.
const int opcPushEnum = 0x0F;

/// Push a pointer to a built-in function.
const int opcPushBifPtr = 0x10;

// ----------------------------------------------------------------------------
// Arithmetic/Logic Operations (0x20 - 0x30)
// ----------------------------------------------------------------------------

/// Negate.
const int opcNeg = 0x20;

/// Bitwise NOT.
const int opcBnot = 0x21;

/// Add.
const int opcAdd = 0x22;

/// Subtract.
const int opcSub = 0x23;

/// Multiply.
const int opcMul = 0x24;

/// Bitwise AND.
const int opcBand = 0x25;

/// Bitwise OR.
const int opcBor = 0x26;

/// Shift left.
const int opcShl = 0x27;

/// Arithmetic shift right.
const int opcAshr = 0x28;

/// Bitwise/logical XOR.
const int opcXor = 0x29;

/// Divide.
const int opcDiv = 0x2A;

/// MOD (remainder).
const int opcMod = 0x2B;

/// Logical NOT.
const int opcNot = 0x2C;

/// Convert top of stack to true/nil.
const int opcBoolize = 0x2D;

/// Increment value at top of stack.
const int opcInc = 0x2E;

/// Decrement value at top of stack.
const int opcDec = 0x2F;

/// Logical shift right.
const int opcLshr = 0x30;

// ----------------------------------------------------------------------------
// Comparison Operations (0x40 - 0x45)
// ----------------------------------------------------------------------------

/// Equals.
const int opcEq = 0x40;

/// Not equals.
const int opcNe = 0x41;

/// Less than.
const int opcLt = 0x42;

/// Less than or equal to.
const int opcLe = 0x43;

/// Greater than.
const int opcGt = 0x44;

/// Greater than or equal to.
const int opcGe = 0x45;

// ----------------------------------------------------------------------------
// Return Instructions (0x50 - 0x54)
// ----------------------------------------------------------------------------

/// Return with value at top of stack.
const int opcRetval = 0x50;

/// Return nil.
const int opcRetnil = 0x51;

/// Return true.
const int opcRettrue = 0x52;

/// Return with no value.
const int opcRet = 0x54;

// ----------------------------------------------------------------------------
// Named Arguments (0x56 - 0x57)
// ----------------------------------------------------------------------------

/// Pointer to named argument table.
const int opcNamedArgPtr = 0x56;

/// Named argument table (variable-length).
const int opcNamedArgTab = 0x57;

// ----------------------------------------------------------------------------
// Function Calls (0x58 - 0x59)
// ----------------------------------------------------------------------------

/// Function call.
const int opcCall = 0x58;

/// Function call through pointer.
const int opcPtrCall = 0x59;

// ----------------------------------------------------------------------------
// Property Access (0x60 - 0x6D)
// ----------------------------------------------------------------------------

/// Get property.
const int opcGetProp = 0x60;

/// Call property with arguments.
const int opcCallProp = 0x61;

/// Call property through pointer with args.
const int opcPtrCallProp = 0x62;

/// Get property of 'self'.
const int opcGetPropSelf = 0x63;

/// Call method of 'self'.
const int opcCallPropSelf = 0x64;

/// Call method of 'self' through pointer.
const int opcPtrCallPropSelf = 0x65;

/// Get property of specific object.
const int opcObjGetProp = 0x66;

/// Call method of specific object.
const int opcObjCallProp = 0x67;

/// Get property, disallowing side effects.
const int opcGetPropData = 0x68;

/// Get prop through pointer, data only.
const int opcPtrGetPropData = 0x69;

/// Get property of local variable.
const int opcGetPropLcl1 = 0x6A;

/// Call property of local variable.
const int opcCallPropLcl1 = 0x6B;

/// Get property of R0.
const int opcGetPropR0 = 0x6C;

/// Call property of R0.
const int opcCallPropR0 = 0x6D;

// ----------------------------------------------------------------------------
// Inheritance and Delegation (0x72 - 0x78)
// ----------------------------------------------------------------------------

/// Inherit from superclass.
const int opcInherit = 0x72;

/// Inherit through property pointer.
const int opcPtrInherit = 0x73;

/// Inherit from an explicit superclass.
const int opcExpInherit = 0x74;

/// Inherit from explicit sc through prop ptr.
const int opcPtrExpInherit = 0x75;

/// Modifier: next call is var arg count.
const int opcVarArgC = 0x76;

/// Delegate to object on stack.
const int opcDelegate = 0x77;

/// Delegate through property pointer.
const int opcPtrDelegate = 0x78;

// ----------------------------------------------------------------------------
// Stack Swap Operations (0x7A - 0x7B)
// ----------------------------------------------------------------------------

/// Swap top two elements with next two.
const int opcSwap2 = 0x7A;

/// Swap elements at operand indices.
const int opcSwapN = 0x7B;

// ----------------------------------------------------------------------------
// Argument Access (0x7C - 0x7F)
// ----------------------------------------------------------------------------

/// Get argument #0.
const int opcGetArgN0 = 0x7C;

/// Get argument #1.
const int opcGetArgN1 = 0x7D;

/// Get argument #2.
const int opcGetArgN2 = 0x7E;

/// Get argument #3.
const int opcGetArgN3 = 0x7F;

// ----------------------------------------------------------------------------
// Local/Argument/Stack Access (0x80 - 0x8F)
// ----------------------------------------------------------------------------

/// Push a local variable (1-byte index).
const int opcGetLcl1 = 0x80;

/// Push a local (2-byte index).
const int opcGetLcl2 = 0x81;

/// Push an argument (1-byte index).
const int opcGetArg1 = 0x82;

/// Push an argument (2-byte index).
const int opcGetArg2 = 0x83;

/// Push 'self'.
const int opcPushSelf = 0x84;

/// Push debug frame local.
const int opcGetDbLcl = 0x85;

/// Push debug frame argument.
const int opcGetDbArg = 0x86;

/// Get current argument count.
const int opcGetArgC = 0x87;

/// Duplicate top of stack.
const int opcDup = 0x88;

/// Discard top of stack.
const int opcDisc = 0x89;

/// Discard n items from stack.
const int opcDisc1 = 0x8A;

/// Push the R0 register onto the stack.
const int opcGetR0 = 0x8B;

/// Push debug frame argument count.
const int opcGetDbArgC = 0x8C;

/// Swap top two stack elements.
const int opcSwap = 0x8D;

/// Push a method context value.
const int opcPushCtxEle = 0x8E;

/// Duplicate the top two stack elements.
const int opcDup2 = 0x8F;

// ----------------------------------------------------------------------------
// PUSHCTXELE Sub-opcodes
// ----------------------------------------------------------------------------

/// Push target property.
const int pushctxeleTargProp = 0x01;

/// Push target object.
const int pushctxeleTargObj = 0x02;

/// Push defining object.
const int pushctxeleDefObj = 0x03;

/// Push the invokee.
const int pushctxeleInvokee = 0x04;

// ----------------------------------------------------------------------------
// Control Flow (0x90 - 0xA6)
// ----------------------------------------------------------------------------

/// Jump through case table (variable-length).
const int opcSwitch = 0x90;

/// Unconditional branch.
const int opcJmp = 0x91;

/// Jump if true.
const int opcJt = 0x92;

/// Jump if false.
const int opcJf = 0x93;

/// Jump if equal.
const int opcJe = 0x94;

/// Jump if not equal.
const int opcJne = 0x95;

/// Jump if greater than.
const int opcJgt = 0x96;

/// Jump if greater or equal.
const int opcJge = 0x97;

/// Jump if less than.
const int opcJlt = 0x98;

/// Jump if less than or equal.
const int opcJle = 0x99;

/// Jump and save if true.
const int opcJst = 0x9A;

/// Jump and save if false.
const int opcJsf = 0x9B;

/// Local jump to subroutine.
const int opcLjsr = 0x9C;

/// Local return from subroutine.
const int opcLret = 0x9D;

/// Jump if nil.
const int opcJnil = 0x9E;

/// Jump if not nil.
const int opcJnotNil = 0x9F;

/// Jump if R0 is true.
const int opcJr0t = 0xA0;

/// Jump if R0 is false.
const int opcJr0f = 0xA1;

/// Iterator next.
const int opcIterNext = 0xA2;

/// Set local from R0 and leave value on stack.
const int opcGetSetLcl1R0 = 0xA3;

/// Set local and leave value on stack.
const int opcGetSetLcl1 = 0xA4;

/// Push R0 twice.
const int opcDupR0 = 0xA5;

/// Get stack element at given index.
const int opcGetSpN = 0xA6;

// ----------------------------------------------------------------------------
// Quick Local Access (0xAA - 0xAF)
// ----------------------------------------------------------------------------

/// Get local #0.
const int opcGetLclN0 = 0xAA;

/// Get local #1.
const int opcGetLclN1 = 0xAB;

/// Get local #2.
const int opcGetLclN2 = 0xAC;

/// Get local #3.
const int opcGetLclN3 = 0xAD;

/// Get local #4.
const int opcGetLclN4 = 0xAE;

/// Get local #5.
const int opcGetLclN5 = 0xAF;

// ----------------------------------------------------------------------------
// Built-in Functions and I/O (0xB0 - 0xBC)
// ----------------------------------------------------------------------------

/// Display a constant string.
const int opcSay = 0xB0;

/// Call built-in func from set 0.
const int opcBuiltinA = 0xB1;

/// Call built-in from set 1.
const int opcBuiltinB = 0xB2;

/// Call built-in from set 2.
const int opcBuiltinC = 0xB3;

/// Call built-in from set 3.
const int opcBuiltinD = 0xB4;

/// Call built-in from any set, 8-bit index.
const int opcBuiltin1 = 0xB5;

/// Call built-in from any set, 16-bit index.
const int opcBuiltin2 = 0xB6;

/// Call external function (reserved; not currently implemented).
const int opcCallExt = 0xB7;

/// Throw an exception.
const int opcThrow = 0xB8;

/// Display the value at top of stack.
const int opcSayVal = 0xB9;

/// Index a list.
const int opcIndex = 0xBA;

/// Index a local variable by an int8 value.
const int opcIdxLcl1Int8 = 0xBB;

/// Index by an int8 value.
const int opcIdxInt8 = 0xBC;

// ----------------------------------------------------------------------------
// Object Creation (0xC0 - 0xC3)
// ----------------------------------------------------------------------------

/// Create new object instance.
const int opcNew1 = 0xC0;

/// Create new object (2-byte operands).
const int opcNew2 = 0xC1;

/// Create new transient instance.
const int opcTrNew1 = 0xC2;

/// Create transient object (2-byte operands).
const int opcTrNew2 = 0xC3;

// ----------------------------------------------------------------------------
// Local Variable Modification (0xD0 - 0xDB)
// ----------------------------------------------------------------------------

/// Increment local variable by 1.
const int opcIncLcl = 0xD0;

/// Decrement local variable by 1.
const int opcDecLcl = 0xD1;

/// Add immediate 1-byte int to local.
const int opcAddILcl1 = 0xD2;

/// Add immediate 4-byte int to local.
const int opcAddILcl4 = 0xD3;

/// Add value to local variable.
const int opcAddToLcl = 0xD4;

/// Subtract value from local variable.
const int opcSubFromLcl = 0xD5;

/// Set local to zero (1-byte local number).
const int opcZeroLcl1 = 0xD6;

/// Set local to zero (2-byte local number).
const int opcZeroLcl2 = 0xD7;

/// Set local to nil (1-byte local number).
const int opcNilLcl1 = 0xD8;

/// Set local to nil (2-byte local number).
const int opcNilLcl2 = 0xD9;

/// Set local to numeric value 1 (1-byte local number).
const int opcOneLcl1 = 0xDA;

/// Set local to numeric value 1 (2-byte local number).
const int opcOneLcl2 = 0xDB;

// ----------------------------------------------------------------------------
// Assignment Operations (0xE0 - 0xEF)
// ----------------------------------------------------------------------------

/// Set local (1-byte local number).
const int opcSetLcl1 = 0xE0;

/// Set local (2-byte local number).
const int opcSetLcl2 = 0xE1;

/// Set parameter (1-byte param number).
const int opcSetArg1 = 0xE2;

/// Set parameter (2-byte param number).
const int opcSetArg2 = 0xE3;

/// Set value at index.
const int opcSetInd = 0xE4;

/// Set property in object.
const int opcSetProp = 0xE5;

/// Set property through prop pointer.
const int opcPtrSetProp = 0xE6;

/// Set property in self.
const int opcSetPropSelf = 0xE7;

/// Set property in immediate object.
const int opcObjSetProp = 0xE8;

/// Set debugger local variable.
const int opcSetDbLcl = 0xE9;

/// Set debugger parameter variable.
const int opcSetDbArg = 0xEA;

/// Set 'self'.
const int opcSetSelf = 0xEB;

/// Load method context from stack.
const int opcLoadCtx = 0xEC;

/// Store method context and push on stack.
const int opcStoreCtx = 0xED;

/// Set local (1-byte local number) from R0.
const int opcSetLcl1R0 = 0xEE;

/// Set indexed local.
const int opcSetIndLcl1I8 = 0xEF;

// ----------------------------------------------------------------------------
// Debug Instructions (0xF1 - 0xF2)
// ----------------------------------------------------------------------------

/// Debugger breakpoint.
const int opcBp = 0xF1;

/// No operation.
const int opcNop = 0xF2;

// ----------------------------------------------------------------------------
// VMB_DATAHOLDER size constant
// ----------------------------------------------------------------------------

/// Size of a data holder in bytes (type byte + 4 data bytes).
const int vmbDataHolder = 5;

// ----------------------------------------------------------------------------
// T3Opcodes Class
// ----------------------------------------------------------------------------

/// T3 VM Opcode utilities.
///
/// Provides instruction size information for disassembly and bytecode analysis.
class T3Opcodes {
  T3Opcodes._();

  /// Opcode size table.
  ///
  /// Index by opcode; each entry gives the size in bytes of the instruction.
  /// A value of 0 is special - it means that the instruction is variable-length.
  static const List<int> opSize = [
    0, //  0x00 - unused
    1, //  0x01 - opcPush0
    1, //  0x02 - opcPush1
    2, //  0x03 - opcPushInt8
    5, //  0x04 - opcPushInt
    5, //  0x05 - opcPushStr
    5, //  0x06 - opcPushLst
    5, //  0x07 - opcPushObj
    1, //  0x08 - opcPushNil
    1, //  0x09 - opcPushTrue
    3, //  0x0A - opcPushPropId
    5, //  0x0B - opcPushFnPtr
    0, //  0x0C - opcPushStrI - variable-length
    2, //  0x0D - opcPushParLst
    1, //  0x0E - opcMakeLstPar
    5, //  0x0F - opcPushEnum
    5, //  0x10 - opcPushBifPtr
    1, //  0x11 - unused
    1, //  0x12 - unused
    1, //  0x13 - unused
    1, //  0x14 - unused
    1, //  0x15 - unused
    1, //  0x16 - unused
    1, //  0x17 - unused
    1, //  0x18 - unused
    1, //  0x19 - unused
    1, //  0x1A - unused
    1, //  0x1B - unused
    1, //  0x1C - unused
    1, //  0x1D - unused
    1, //  0x1E - unused
    1, //  0x1F - unused
    1, //  0x20 - opcNeg
    1, //  0x21 - opcBnot
    1, //  0x22 - opcAdd
    1, //  0x23 - opcSub
    1, //  0x24 - opcMul
    1, //  0x25 - opcBand
    1, //  0x26 - opcBor
    1, //  0x27 - opcShl
    1, //  0x28 - opcAshr
    1, //  0x29 - opcXor
    1, //  0x2A - opcDiv
    1, //  0x2B - opcMod
    1, //  0x2C - opcNot
    1, //  0x2D - opcBoolize
    1, //  0x2E - opcInc
    1, //  0x2F - opcDec
    1, //  0x30 - opcLshr
    1, //  0x31 - unused
    1, //  0x32 - unused
    1, //  0x33 - unused
    1, //  0x34 - unused
    1, //  0x35 - unused
    1, //  0x36 - unused
    1, //  0x37 - unused
    1, //  0x38 - unused
    1, //  0x39 - unused
    1, //  0x3A - unused
    1, //  0x3B - unused
    1, //  0x3C - unused
    1, //  0x3D - unused
    1, //  0x3E - unused
    1, //  0x3F - unused
    1, //  0x40 - opcEq
    1, //  0x41 - opcNe
    1, //  0x42 - opcLt
    1, //  0x43 - opcLe
    1, //  0x44 - opcGt
    1, //  0x45 - opcGe
    1, //  0x46 - unused
    1, //  0x47 - unused
    1, //  0x48 - unused
    1, //  0x49 - unused
    1, //  0x4A - unused
    1, //  0x4B - unused
    1, //  0x4C - unused
    1, //  0x4D - unused
    1, //  0x4E - unused
    1, //  0x4F - unused
    1, //  0x50 - opcRetval
    1, //  0x51 - opcRetnil
    1, //  0x52 - opcRettrue
    1, //  0x53 - unused
    1, //  0x54 - opcRet
    1, //  0x55 - unused
    4, //  0x56 - opcNamedArgPtr
    0, //  0x57 - opcNamedArgTab - variable-length
    6, //  0x58 - opcCall
    2, //  0x59 - opcPtrCall
    1, //  0x5A - unused
    1, //  0x5B - unused
    1, //  0x5C - unused
    1, //  0x5D - unused
    1, //  0x5E - unused
    1, //  0x5F - unused
    3, //  0x60 - opcGetProp
    4, //  0x61 - opcCallProp
    2, //  0x62 - opcPtrCallProp
    3, //  0x63 - opcGetPropSelf
    4, //  0x64 - opcCallPropSelf
    2, //  0x65 - opcPtrCallPropSelf
    7, //  0x66 - opcObjGetProp
    8, //  0x67 - opcObjCallProp
    3, //  0x68 - opcGetPropData
    1, //  0x69 - opcPtrGetPropData
    4, //  0x6A - opcGetPropLcl1
    5, //  0x6B - opcCallPropLcl1
    3, //  0x6C - opcGetPropR0
    4, //  0x6D - opcCallPropR0
    1, //  0x6E - unused
    1, //  0x6F - unused
    1, //  0x70 - unused
    1, //  0x71 - unused
    4, //  0x72 - opcInherit
    2, //  0x73 - opcPtrInherit
    8, //  0x74 - opcExpInherit
    6, //  0x75 - opcPtrExpInherit
    1, //  0x76 - opcVarArgC
    4, //  0x77 - opcDelegate
    2, //  0x78 - opcPtrDelegate
    1, //  0x79 - unused
    1, //  0x7A - opcSwap2
    3, //  0x7B - opcSwapN
    1, //  0x7C - opcGetArgN0
    1, //  0x7D - opcGetArgN1
    1, //  0x7E - opcGetArgN2
    1, //  0x7F - opcGetArgN3
    2, //  0x80 - opcGetLcl1
    3, //  0x81 - opcGetLcl2
    2, //  0x82 - opcGetArg1
    3, //  0x83 - opcGetArg2
    1, //  0x84 - opcPushSelf
    5, //  0x85 - opcGetDbLcl
    5, //  0x86 - opcGetDbArg
    1, //  0x87 - opcGetArgC
    1, //  0x88 - opcDup
    1, //  0x89 - opcDisc
    2, //  0x8A - opcDisc1
    1, //  0x8B - opcGetR0
    3, //  0x8C - opcGetDbArgC
    1, //  0x8D - opcSwap
    2, //  0x8E - opcPushCtxEle
    1, //  0x8F - opcDup2
    0, //  0x90 - opcSwitch - variable-length
    3, //  0x91 - opcJmp
    3, //  0x92 - opcJt
    3, //  0x93 - opcJf
    3, //  0x94 - opcJe
    3, //  0x95 - opcJne
    3, //  0x96 - opcJgt
    3, //  0x97 - opcJge
    3, //  0x98 - opcJlt
    3, //  0x99 - opcJle
    3, //  0x9A - opcJst
    3, //  0x9B - opcJsf
    3, //  0x9C - opcLjsr
    3, //  0x9D - opcLret
    3, //  0x9E - opcJnil
    3, //  0x9F - opcJnotNil
    3, //  0xA0 - opcJr0t
    3, //  0xA1 - opcJr0f
    5, //  0xA2 - opcIterNext
    2, //  0xA3 - opcGetSetLcl1R0
    2, //  0xA4 - opcGetSetLcl1
    1, //  0xA5 - opcDupR0
    2, //  0xA6 - opcGetSpN
    1, //  0xA7 - unused
    1, //  0xA8 - unused
    1, //  0xA9 - unused
    1, //  0xAA - opcGetLclN0
    1, //  0xAB - opcGetLclN1
    1, //  0xAC - opcGetLclN2
    1, //  0xAD - opcGetLclN3
    1, //  0xAE - opcGetLclN4
    1, //  0xAF - opcGetLclN5
    5, //  0xB0 - opcSay
    3, //  0xB1 - opcBuiltinA
    3, //  0xB2 - opcBuiltinB
    3, //  0xB3 - opcBuiltinC
    3, //  0xB4 - opcBuiltinD
    3, //  0xB5 - opcBuiltin1
    4, //  0xB6 - opcBuiltin2
    0, //  0xB7 - opcCallExt (reserved; not implemented)
    1, //  0xB8 - opcThrow
    1, //  0xB9 - opcSayVal
    1, //  0xBA - opcIndex
    3, //  0xBB - opcIdxLcl1Int8
    2, //  0xBC - opcIdxInt8
    1, //  0xBD - unused
    1, //  0xBE - unused
    1, //  0xBF - unused
    3, //  0xC0 - opcNew1
    5, //  0xC1 - opcNew2
    3, //  0xC2 - opcTrNew1
    5, //  0xC3 - opcTrNew2
    1, //  0xC4 - unused
    1, //  0xC5 - unused
    1, //  0xC6 - unused
    1, //  0xC7 - unused
    1, //  0xC8 - unused
    1, //  0xC9 - unused
    1, //  0xCA - unused
    1, //  0xCB - unused
    1, //  0xCC - unused
    1, //  0xCD - unused
    1, //  0xCE - unused
    1, //  0xCF - unused
    3, //  0xD0 - opcIncLcl
    3, //  0xD1 - opcDecLcl
    3, //  0xD2 - opcAddILcl1
    7, //  0xD3 - opcAddILcl4
    3, //  0xD4 - opcAddToLcl
    3, //  0xD5 - opcSubFromLcl
    2, //  0xD6 - opcZeroLcl1
    3, //  0xD7 - opcZeroLcl2
    2, //  0xD8 - opcNilLcl1
    3, //  0xD9 - opcNilLcl2
    2, //  0xDA - opcOneLcl1
    3, //  0xDB - opcOneLcl2
    1, //  0xDC - unused
    1, //  0xDD - unused
    1, //  0xDE - unused
    1, //  0xDF - unused
    2, //  0xE0 - opcSetLcl1
    3, //  0xE1 - opcSetLcl2
    2, //  0xE2 - opcSetArg1
    3, //  0xE3 - opcSetArg2
    1, //  0xE4 - opcSetInd
    3, //  0xE5 - opcSetProp
    1, //  0xE6 - opcPtrSetProp
    3, //  0xE7 - opcSetPropSelf
    7, //  0xE8 - opcObjSetProp
    5, //  0xE9 - opcSetDbLcl
    5, //  0xEA - opcSetDbArg
    1, //  0xEB - opcSetSelf
    1, //  0xEC - opcLoadCtx
    1, //  0xED - opcStoreCtx
    2, //  0xEE - opcSetLcl1R0
    3, //  0xEF - opcSetIndLcl1I8
    1, //  0xF0 - unused
    1, //  0xF1 - opcBp
    1, //  0xF2 - opcNop
    1, //  0xF3 - unused
    1, //  0xF4 - unused
    1, //  0xF5 - unused
    1, //  0xF6 - unused
    1, //  0xF7 - unused
    1, //  0xF8 - unused
    1, //  0xF9 - unused
    1, //  0xFA - unused
    1, //  0xFB - unused
    1, //  0xFC - unused
    1, //  0xFD - unused
    1, //  0xFE - unused
    255, // 0xFF - unused
  ];

  /// Get the size in bytes of an opcode.
  ///
  /// This computes the actual size of varying-length instructions.
  /// The [data] buffer must contain the instruction at [offset].
  ///
  /// Returns the size in bytes of the instruction, including the opcode byte.
  static int getOpSize(Uint8List data, int offset) {
    final opcode = data[offset];

    switch (opcode) {
      case opcPushStrI:
        // Size = 3 + string_length (UINT2 at offset+1)
        return 3 + _readUint16(data, offset + 1);

      case opcSwitch:
        // Size = 1 + 2 + (VMB_DATAHOLDER + 2) * case_count + 2
        // = 1 (opcode) + 2 (case_count) + 7 * case_count + 2 (default_offset)
        final caseCount = _readUint16(data, offset + 1);
        return 1 + 2 + (vmbDataHolder + 2) * caseCount + 2;

      case opcNamedArgTab:
        // Size = 1 + 2 + table_size
        return 1 + 2 + _readUint16(data, offset + 1);

      default:
        // All others have fixed sizes from the table
        return opSize[opcode];
    }
  }

  /// Read a little-endian UINT16 from the data buffer.
  static int _readUint16(Uint8List data, int offset) {
    return data[offset] | (data[offset + 1] << 8);
  }
}
