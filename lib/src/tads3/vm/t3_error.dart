// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// TADS3 VM Error Handling
///
/// This library provides the error handling system for the TADS3 VM, including
/// error codes, exception classes, and error messages. It is a Dart port of
/// the C++ vmerr.h, vmerr.cpp, vmerrmsg.cpp, and vmerrnum.h files.
///
/// Unlike the C++ implementation which uses setjmp/longjmp macros, this Dart
/// version uses native Dart exceptions (try/catch/rethrow).
///
/// Ported from: packages/tads-runner/tads3/vmerr.h
///              packages/tads-runner/tads3/vmerr.cpp
///              packages/tads-runner/tads3/vmerrmsg.cpp
///              packages/tads-runner/tads3/vmerrnum.h
library;

// ----------------------------------------------------------------------------
// Error Codes (from vmerrnum.h)
// ----------------------------------------------------------------------------

// File errors (101-111)
const int vmErrReadFile = 101;
const int vmErrWriteFile = 102;
const int vmErrFileNotFound = 103;
const int vmErrCreateFile = 104;
const int vmErrCloseFile = 105;
const int vmErrDeleteFile = 106;
const int vmErrPackParse = 107;
const int vmErrPackArgMismatch = 108;
const int vmErrPackArgcMismatch = 109;
const int vmErrNetFileNoimpl = 110;
const int vmErrRenameFile = 111;

// Memory manager errors (201-206)
const int vmErrObjInUse = 201;
const int vmErrOutOfMemory = 202;
const int vmErrNoMemForPage = 203;
const int vmErrBadPoolPageSize = 204;
const int vmErrOutOfPropids = 205;
const int vmErrCircularInit = 206;

// Image file errors (301-334)
const int vmErrUnknownMetaclass = 301;
const int vmErrUnknownFuncSet = 302;
const int vmErrReadPastImgEnd = 303;
const int vmErrNotAnImageFile = 304;
const int vmErrUnknownImageBlock = 305;
const int vmErrImageBlockTooSmall = 306;
const int vmErrImagePoolBeforeDef = 307;
const int vmErrImagePoolBadPage = 308;
const int vmErrImageBadPoolId = 309;
const int vmErrLoadBadPageIdx = 310;
const int vmErrLoadUndefPage = 311;
const int vmErrImagePoolRedef = 312;
const int vmErrImageMetadepRedef = 313;
const int vmErrImageNoMetadep = 314;
const int vmErrImageFuncdepRedef = 315;
const int vmErrImageNoFuncdep = 316;
const int vmErrImageEntryptRedef = 317;
const int vmErrImageNoEntrypt = 318;
const int vmErrImageIncompatVsn = 319;
const int vmErrImageNoCode = 320;
const int vmErrImageIncompatHdrFmt = 321;
const int vmErrUnavailIntrinsic = 322;
const int vmErrUnknownMetaclassInternal = 323;
const int vmErrXorMaskBadInMem = 324;
const int vmErrNoImageInExe = 325;
const int vmErrObjSizeOverflow = 326;
const int vmErrMetaclassTooOld = 327;
const int vmErrInvalMetaclassData = 328;
const int vmErrBadStaticNew = 329;
const int vmErrFuncsetTooOld = 330;
const int vmErrInvalExportType = 331;
const int vmErrInvalImageMacro = 332;
const int vmErrNoMainrestore = 333;
const int vmErrImageIncompatVsnDbg = 334;

// Network errors (400)
const int vmErrNetworkSafety = 400;

// Property-related errors (1001)
const int vmErrInvalidSetprop = 1001;

// Saved state file errors (1201-1210)
const int vmErrNotSavedState = 1201;
const int vmErrWrongSavedState = 1202;
const int vmErrSavedMetaTooLong = 1203;
const int vmErrSavedObjIdInvalid = 1206;
const int vmErrBadSavedState = 1207;
const int vmErrBadSavedMetaData = 1208;
const int vmErrStorageServerErr = 1209;
const int vmErrDescTabOverflow = 1210;

// Data manipulation and conversion errors (2001-2043)
const int vmErrNoStrConv = 2001;
const int vmErrConvBufOvf = 2002;
const int vmErrBadTypeAdd = 2003;
const int vmErrNumValReqd = 2004;
const int vmErrIntValReqd = 2005;
const int vmErrNoLogConv = 2006;
const int vmErrBadTypeSub = 2007;
const int vmErrDivideByZero = 2008;
const int vmErrInvalidComparison = 2009;
const int vmErrObjValReqd = 2010;
const int vmErrPropptrValReqd = 2011;
const int vmErrLogValReqd = 2012;
const int vmErrFuncptrValReqd = 2013;
const int vmErrCannotIndexType = 2014;
const int vmErrIndexOutOfRange = 2015;
const int vmErrBadMetaclassIndex = 2016;
const int vmErrBadDynamicNew = 2017;
const int vmErrObjValReqdSc = 2018;
const int vmErrStringValReqd = 2019;
const int vmErrListValReqd = 2020;
const int vmErrDictNoConst = 2021;
const int vmErrInvalObjType = 2022;
const int vmErrNumOverflow = 2023;
const int vmErrBadTypeMul = 2024;
const int vmErrBadTypeDiv = 2025;
const int vmErrBadTypeNeg = 2026;
const int vmErrOutOfRange = 2027;
const int vmErrStrTooLong = 2028;
const int vmErrListTooLong = 2029;
const int vmErrTreeTooDeepEq = 2030;
const int vmErrNoIntConv = 2031;
const int vmErrBadTypeMod = 2032;
const int vmErrBadTypeBitAnd = 2033;
const int vmErrBadTypeBitOr = 2034;
const int vmErrBadTypeXor = 2035;
const int vmErrBadTypeShl = 2036;
const int vmErrBadTypeAshr = 2037;
const int vmErrBadTypeBitNot = 2038;
const int vmErrCodeptrValReqd = 2039;
const int vmErrExceptionObjReqd = 2040;
const int vmErrNoDoubleConv = 2041;
const int vmErrNoNumConv = 2042;
const int vmErrBadTypeLshr = 2043;

// Method and function invocation errors (2201-2206)
const int vmErrWrongNumOfArgs = 2201;
const int vmErrWrongNumOfArgsCalling = 2202;
const int vmErrNilDeref = 2203;
const int vmErrMissingNamedArg = 2204;
const int vmErrBadTypeCall = 2205;
const int vmErrNilSelf = 2206;

// Object creation errors (2270-2271)
const int vmErrCannotCreateInst = 2270;
const int vmErrIllegalNew = 2271;

// General execution errors (2301-2316)
const int vmErrInvalidOpcode = 2301;
const int vmErrUnhandledExc = 2302;
const int vmErrStackOverflow = 2303;
const int vmErrBadTypeBif = 2304;
const int vmErrSayIsNotDefined = 2305;
const int vmErrBadValBif = 2306;
const int vmErrBreakpoint = 2307;
const int vmErrCallextNotImpl = 2308;
const int vmErrInvalidOpcodeMod = 2309;
const int vmErrNoCharmapFile = 2310;
const int vmErrUnhandledExcParam = 2311;
const int vmErrVmExcParam = 2312;
const int vmErrVmExcCode = 2313;
const int vmErrExcInStaticInit = 2314;
const int vmErrIntclsGeneralError = 2315;
const int vmErrStackOutOfBounds = 2316;
const int vmErrTzFileOpen = 2317;
const int vmErrTzFileRead = 2318;

// Debugger interface errors (2391-2396)
const int vmErrDbgAbort = 2391;
const int vmErrDbgRestart = 2392;
const int vmErrDbgHalt = 2394;
const int vmErrDbgInterrupt = 2395;
const int vmErrNoDebugger = 2396;

// Debugger-related errors (2500-2503)
const int vmErrBadFrame = 2500;
const int vmErrBadSpecEval = 2501;
const int vmErrInvalDbgExpr = 2502;
const int vmErrNoImageDbgInfo = 2503;

// BigNumber package errors (2600-2601)
const int vmErrBignumNoRegs = 2600;
const int vmErrNoBignumConv = 2601;

// ----------------------------------------------------------------------------
// T3ErrorParam - Exception Parameter
// ----------------------------------------------------------------------------

/// Parameter type for exception parameters
enum T3ErrorParamType {
  /// Integer value
  int,

  /// Unsigned long value
  ulong,

  /// String value
  string,

  /// Metaclass identifier
  metaclass,

  /// Function set identifier
  funcset,

  /// Version flag (no value)
  versionFlag,
}

/// Exception parameter
class T3ErrorParam {
  /// Type of this parameter
  final T3ErrorParamType type;

  /// Value of the parameter (interpretation depends on type)
  final Object? value;

  /// Create an integer parameter
  T3ErrorParam.int(int val) : type = T3ErrorParamType.int, value = val;

  /// Create an unsigned long parameter
  T3ErrorParam.ulong(int val) : type = T3ErrorParamType.ulong, value = val;

  /// Create a string parameter
  T3ErrorParam.string(String val) : type = T3ErrorParamType.string, value = val;

  /// Create a metaclass parameter
  T3ErrorParam.metaclass(String val) : type = T3ErrorParamType.metaclass, value = val;

  /// Create a function set parameter
  T3ErrorParam.funcset(String val) : type = T3ErrorParamType.funcset, value = val;

  /// Create a version flag parameter
  T3ErrorParam.versionFlag() : type = T3ErrorParamType.versionFlag, value = null;

  /// Get as integer
  int get asInt => value as int;

  /// Get as string
  String get asString => value as String;
}

// ----------------------------------------------------------------------------
// T3VmException - VM Exception Class
// ----------------------------------------------------------------------------

/// TADS3 VM Exception
///
/// This is the Dart equivalent of the C++ CVmException class.
class T3VmException implements Exception {
  /// Error code
  final int errorCode;

  /// Exception parameters
  final List<T3ErrorParam> parameters;

  /// Is this a version-related error?
  final bool versionFlag;

  /// Metaclass identifier (for version-related errors)
  final String? metaclass;

  /// Function set identifier (for version-related errors)
  final String? funcset;

  /// Create an exception with no parameters
  T3VmException(this.errorCode) : parameters = const [], versionFlag = false, metaclass = null, funcset = null;

  /// Create an exception with parameters
  T3VmException.withParams(this.errorCode, this.parameters, {this.versionFlag = false, this.metaclass, this.funcset});

  /// Get the number of parameters
  int get paramCount => parameters.length;

  /// Get a parameter by index
  T3ErrorParam getParam(int index) => parameters[index];

  /// Get a parameter as an integer
  int getParamInt(int index) => parameters[index].asInt;

  /// Get a parameter as a string
  String getParamString(int index) => parameters[index].asString;

  /// Format the exception message
  String formatMessage({bool verbose = false}) {
    final msg = getErrorMessage(errorCode, verbose: verbose);
    if (msg == null) {
      return 'VM Error: code $errorCode';
    }
    return formatErrorMessage(msg, this);
  }

  @override
  String toString() => formatMessage();
}

// ----------------------------------------------------------------------------
// Error Messages (from vmerrmsg.cpp)
// ----------------------------------------------------------------------------

/// Error message entry
class _ErrorMessage {
  final int code;
  final String shortMsg;
  final String longMsg;

  const _ErrorMessage(this.code, this.shortMsg, this.longMsg);
}

/// Error message table
const List<_ErrorMessage> _errorMessages = [
  _ErrorMessage(
    vmErrReadFile,
    'error reading file',
    'Error reading file. The file might be corrupted or a media error might have occurred.',
  ),
  _ErrorMessage(
    vmErrWriteFile,
    'error writing file',
    'Error writing file. The media might be full, or another media error might have occurred.',
  ),
  _ErrorMessage(
    vmErrFileNotFound,
    'file not found',
    'Error opening file. The specified file might not exist, you might not have sufficient privileges to open the file, or a sharing violation might have occurred.',
  ),
  _ErrorMessage(
    vmErrCreateFile,
    'error creating file',
    'Error creating file. You might not have sufficient privileges to open the file, or a sharing violation might have occurred.',
  ),
  _ErrorMessage(
    vmErrCloseFile,
    'error closing file',
    'Error closing file. Some or all changes made to the file might not have been properly written to the physical disk/media.',
  ),
  _ErrorMessage(
    vmErrDeleteFile,
    'error deleting file',
    "Error deleting file. This could because you don't have sufficient privileges, the file is marked as read-only, another program is using the file, or a physical media error occurred.",
  ),
  _ErrorMessage(
    vmErrObjInUse,
    'object ID in use - the image/save file might be corrupted',
    'An object ID requested by the image/save file is already in use and cannot be allocated to the file. This might indicate that the file is corrupted.',
  ),
  _ErrorMessage(
    vmErrOutOfMemory,
    'out of memory',
    'Out of memory. Try making more memory available by closing other applications if possible.',
  ),
  _ErrorMessage(
    vmErrNoMemForPage,
    'out of memory allocating pool page',
    'Out of memory allocating pool page. Try making more memory available by closing other applications.',
  ),
  _ErrorMessage(
    vmErrBadPoolPageSize,
    'invalid page size - file is not valid',
    'Invalid page size. The file being loaded is not valid.',
  ),
  _ErrorMessage(
    vmErrOutOfPropids,
    "no more property ID's are available",
    "Out of property ID's. No more properties can be allocated.",
  ),
  _ErrorMessage(
    vmErrCircularInit,
    'circular initialization dependency in intrinsic class (internal error)',
    'Circular initialization dependency detected in intrinsic class. This indicates an internal error in the interpreter. Please report this error to the interpreter\'s maintainer.',
  ),
  _ErrorMessage(
    vmErrUnknownMetaclass,
    'this interpreter version cannot run this program (program requires intrinsic class %s, which is not available in this interpreter)',
    'This image file requires an intrinsic class with the identifier "%s", but the class is not available in this interpreter. This program cannot be executed with this interpreter.',
  ),
  _ErrorMessage(
    vmErrUnknownFuncSet,
    'this interpreter version cannot run this program (program requires intrinsic function set %s, which is not available in this interpreter)',
    'This image file requires a function set with the identifier "%s", but the function set is not available in this interpreter. This program cannot be executed with this interpreter.',
  ),
  _ErrorMessage(
    vmErrReadPastImgEnd,
    'reading past end of image file - program might be corrupted',
    'Reading past end of image file. The image file might be corrupted.',
  ),
  _ErrorMessage(
    vmErrNotAnImageFile,
    'this is not an image file (no valid signature found)',
    'This file is not a valid image file - the file has an invalid signature. The image file might be corrupted.',
  ),
  _ErrorMessage(
    vmErrUnknownImageBlock,
    'this interpreter version cannot run this program (unknown block type in image file)',
    'Unknown block type. This image file is either incompatible with this version of the interpreter, or has been corrupted.',
  ),
  _ErrorMessage(
    vmErrImageBlockTooSmall,
    'data block too small',
    'A data block in the image file is too small. The image file might be corrupted.',
  ),
  _ErrorMessage(
    vmErrImagePoolBeforeDef,
    'invalid image file: pool page before pool definition',
    "This image file is invalid because it specifies a pool page before the pool's definition. The image file might be corrupted.",
  ),
  _ErrorMessage(
    vmErrImagePoolBadPage,
    'invalid image file: pool page out of range of definition',
    "This image file is invalid because it specifies a pool page outside of the range of the pool's definition. The image file might be corrupted.",
  ),
  _ErrorMessage(
    vmErrImageBadPoolId,
    'invalid image file: invalid pool ID',
    'This image file is invalid because it specifies an invalid pool ID. The image file might be corrupted.',
  ),
  _ErrorMessage(
    vmErrLoadBadPageIdx,
    'invalid image file: bad page index',
    'This image file is invalid because it specifies an invalid page index. The image file might be corrupted.',
  ),
  _ErrorMessage(
    vmErrLoadUndefPage,
    'loading undefined pool page',
    'The program is attempting to load a pool page that is not present in the image file. The image file might be corrupted.',
  ),
  _ErrorMessage(
    vmErrImagePoolRedef,
    'invalid image file: pool is defined more than once',
    'This image file is invalid because it defines a pool more than once. The image file might be corrupted.',
  ),
  _ErrorMessage(
    vmErrImageMetadepRedef,
    'invalid image file: multiple intrinsic class dependency tables found',
    'This image file is invalid because it contains multiple intrinsic class tables. The image file might be corrupted.',
  ),
  _ErrorMessage(
    vmErrImageNoMetadep,
    'invalid image file: no intrinsic class dependency table found',
    'This image file is invalid because it contains no intrinsic class tables. The image file might be corrupted.',
  ),
  _ErrorMessage(
    vmErrImageFuncdepRedef,
    'invalid image file: multiple function set dependency tables found',
    'This image file is invalid because it contains multiple function set tables. The image file might be corrupted.',
  ),
  _ErrorMessage(
    vmErrImageNoFuncdep,
    'invalid image file: no function set dependency table found',
    'This image file is invalid because it contains no function set tables. The image file might be corrupted.',
  ),
  _ErrorMessage(
    vmErrImageEntryptRedef,
    'invalid image file: multiple entrypoints found',
    'This image file is invalid because it contains multiple entrypoint definitions. The image file might be corrupted.',
  ),
  _ErrorMessage(
    vmErrImageNoEntrypt,
    'invalid image file: no entrypoint found',
    'This image file is invalid because it contains no entrypoint specification. The image file might be corrupted.',
  ),
  _ErrorMessage(
    vmErrImageIncompatVsn,
    'incompatible image file format version',
    'This image file has an incompatible format version. You must obtain a newer version of the interpreter to execute this program.',
  ),
  _ErrorMessage(
    vmErrImageNoCode,
    'image contains no code',
    'This image file contains no executable code. The file might be corrupted.',
  ),
  _ErrorMessage(
    vmErrImageIncompatHdrFmt,
    'incomptabile image file format: method header too old',
    'This image file has an incompatible method header format. This is an older image file version which this interpreter does not support.',
  ),
  _ErrorMessage(
    vmErrUnavailIntrinsic,
    'unavailable intrinsic function called (index %d in function set "%s")',
    'Unavailable intrinsic function called (the function is at index %d in function set "%s"). This function is not available in this version of the interpreter and cannot be called when running the program with this version.',
  ),
  _ErrorMessage(
    vmErrUnknownMetaclassInternal,
    'unknown internal intrinsic class ID %x',
    'Unknown internal intrinsic class ID %x. This indicates an internal error in the interpreter. Please report this error to the interpreter\'s maintainer.',
  ),
  _ErrorMessage(
    vmErrMetaclassTooOld,
    'this interpreter is too old to run this program (program requires intrinsic class version %s, interpreter provides version %s)',
    'This program needs the intrinsic class "%s". This VM implementation does not provide a sufficiently recent version of this intrinsic class; the latest version available in this VM is "%s". This program cannot run with this version of the VM; you must use a more recent version of the VM to execute this program.',
  ),
  _ErrorMessage(
    vmErrInvalMetaclassData,
    'invalid intrinsic class data - image file may be corrupted',
    'Invalid data were detected in an intrinsic class. This might indicate that the image file has been corrupted. You might need to re-install the program.',
  ),
  _ErrorMessage(
    vmErrBadStaticNew,
    'invalid object - class does not allow loading',
    'An object in the image file cannot be loaded because its class does not allow creation of objects of the class. This usually means that the class is abstract and cannot be instantiated as a concrete object.',
  ),
  _ErrorMessage(
    vmErrFuncsetTooOld,
    'this interpreter is too old to run this program (program requires function set version %s, interpreter provides version %s)',
    'This program needs the function set "%s". This VM implementation does not provide a sufficiently recent version of this function set; the latest version available in this VM is "%s". This program cannot run with this version of the VM; you must use a more recent version of the VM to execute this program.',
  ),
  _ErrorMessage(
    vmErrInvalidSetprop,
    'property cannot be set for object',
    'Invalid property change - this property cannot be set for this object. This normally indicates that the object is of a type that does not allow setting of properties at all, or at least of certain properties. For example, a string object does not allow setting properties at all.',
  ),
  _ErrorMessage(
    vmErrNotSavedState,
    'file is not a valid saved state file',
    'This file is not a valid saved state file. Either the file was not created as a saved state file, or its contents have been corrupted.',
  ),
  _ErrorMessage(
    vmErrWrongSavedState,
    'saved state is for a different program or a different version of this program',
    'This file does not contain saved state information for this program. The file was saved by another program, or by a different version of this program; in either case, it cannot be restored with this version of this program.',
  ),
  _ErrorMessage(
    vmErrBadSavedState,
    'saved state file is corrupted (incorrect checksum)',
    "The saved state file's checksum is invalid. This usually indicates that the file has been corrupted (which could be due to a media error, modification by another application, or a file transfer that lost or changed data).",
  ),
  _ErrorMessage(vmErrNoStrConv, 'cannot convert value to string', 'This value cannot be converted to a string.'),
  _ErrorMessage(
    vmErrConvBufOvf,
    'string conversion buffer overflow',
    'An internal buffer overflow occurred converting this value to a string.',
  ),
  _ErrorMessage(
    vmErrBadTypeAdd,
    'invalid datatypes for addition operator',
    'Invalid datatypes for addition operator. The values being added cannot be combined in this manner.',
  ),
  _ErrorMessage(vmErrNumValReqd, 'numeric value required', 'Invalid value type - a numeric value is required.'),
  _ErrorMessage(vmErrIntValReqd, 'integer value required', 'Invalid value type - an integer value is required.'),
  _ErrorMessage(
    vmErrNoLogConv,
    'cannot convert value to logical (true/nil)',
    'This value cannot be converted to a logical (true/nil) value.',
  ),
  _ErrorMessage(
    vmErrBadTypeSub,
    'invalid datatypes for subtraction operator',
    'Invalid datatypes for subtraction operator. The values used cannot be combined in this manner.',
  ),
  _ErrorMessage(vmErrDivideByZero, 'division by zero', 'Arithmetic error - Division by zero.'),
  _ErrorMessage(
    vmErrInvalidComparison,
    'invalid comparison',
    'Invalid comparison - these values cannot be compared to one another.',
  ),
  _ErrorMessage(vmErrObjValReqd, 'object value required', 'An object value is required.'),
  _ErrorMessage(vmErrPropptrValReqd, 'property pointer required', 'A property pointer value is required.'),
  _ErrorMessage(vmErrLogValReqd, 'logical value required', 'A logical (true/nil) value is required.'),
  _ErrorMessage(vmErrFuncptrValReqd, 'function pointer required', 'A function pointer value is required.'),
  _ErrorMessage(
    vmErrCannotIndexType,
    'invalid index operation - this type of value cannot be indexed',
    'This type of value cannot be indexed.',
  ),
  _ErrorMessage(
    vmErrIndexOutOfRange,
    'index out of range',
    'The index value is out of range for the value being indexed (it is too low or too high).',
  ),
  _ErrorMessage(
    vmErrBadMetaclassIndex,
    'invalid intrinsic class index',
    'The intrinsic class index is out of range. This probably indicates that the image file is corrupted.',
  ),
  _ErrorMessage(
    vmErrBadDynamicNew,
    'invalid dynamic object creation (intrinsic class does not support NEW)',
    'This type of object cannot be dynamically created, because the intrinsic class does not support dynamic creation.',
  ),
  _ErrorMessage(
    vmErrObjValReqdSc,
    'object value required for base class',
    'An object value must be specified for the base class of a dynamic object creation operation. The superclass value is of a non-object type.',
  ),
  _ErrorMessage(vmErrStringValReqd, 'string value required', 'A string value is required.'),
  _ErrorMessage(vmErrListValReqd, 'list value required', 'A list value is required.'),
  _ErrorMessage(
    vmErrInvalObjType,
    'invalid object type - cannot convert to required object type',
    'An object is not of the correct type. The object specified cannot be converted to the required object type.',
  ),
  _ErrorMessage(vmErrNumOverflow, 'numeric overflow', 'A numeric calculation overflowed the limits of the datatype.'),
  _ErrorMessage(
    vmErrBadTypeMul,
    'invalid datatypes for multiplication operator',
    'Invalid datatypes for multiplication operator. The values being added cannot be combined in this manner.',
  ),
  _ErrorMessage(
    vmErrBadTypeDiv,
    'invalid datatypes for division operator',
    'Invalid datatypes for division operator. The values being added cannot be combined in this manner.',
  ),
  _ErrorMessage(
    vmErrBadTypeNeg,
    'invalid datatype for arithmetic negation operator',
    'Invalid datatype for arithmetic negation operator. The value cannot be negated.',
  ),
  _ErrorMessage(
    vmErrOutOfRange,
    'value is out of range',
    'A value that was outside of the legal range of inputs was specified for a calculation.',
  ),
  _ErrorMessage(
    vmErrStrTooLong,
    'string is too long',
    'A string value is limited to 65535 bytes in length. This string exceeds the length limit.',
  ),
  _ErrorMessage(
    vmErrListTooLong,
    'list too long',
    'A list value is limited to about 13100 elements. This list exceeds the limit.',
  ),
  _ErrorMessage(
    vmErrTreeTooDeepEq,
    'maximum equality test/hash recursion depth exceeded',
    'This equality comparison or hash calculation is too complex and cannot be performed. This usually indicates that a value contains circular references, such as a Vector that contains a reference to itself, or to another Vector that contains a reference to the first one. This type of value cannot be compared for equality or used in a LookupTable.',
  ),
  _ErrorMessage(vmErrNoIntConv, 'cannot convert value to integer', 'This value cannot be converted to an integer.'),
  _ErrorMessage(
    vmErrBadTypeMod,
    'invalid datatype for modulo operator',
    "Invalid datatype for the modulo operator. These values can't be combined with this operator.",
  ),
  _ErrorMessage(
    vmErrBadTypeBitAnd,
    'invalid datatype for bitwise AND operator',
    "Invalid datatype for the bitwise AND operator. These values can't be combined with this operator.",
  ),
  _ErrorMessage(
    vmErrBadTypeBitOr,
    'invalid datatype for bitwise OR operator',
    "Invalid datatype for the bitwise OR operator. These values can't be combined with this operator.",
  ),
  _ErrorMessage(
    vmErrBadTypeXor,
    'invalid datatype for XOR operator',
    "Invalid datatype for the XOR operator. These values can't be combined with this operator.",
  ),
  _ErrorMessage(
    vmErrBadTypeShl,
    "invalid datatype for left-shift operator '<<'",
    "Invalid datatype for the left-shift operator '<<'. These values can't be combined with this operator.",
  ),
  _ErrorMessage(
    vmErrBadTypeAshr,
    "invalid datatype for arithmetic right-shift operator '>>'",
    "Invalid datatype for the arithmetic right-shift operator '>>'. These values can't be combined with this operator.",
  ),
  _ErrorMessage(
    vmErrBadTypeBitNot,
    'invalid datatype for bitwise NOT operator',
    "Invalid datatype for the bitwise NOT operator. These values can't be combined with this operator.",
  ),
  _ErrorMessage(
    vmErrCodeptrValReqd,
    'code pointer value required',
    'Invalid type - code pointer value required. (This probably indicates an internal problem in the interpreter.)',
  ),
  _ErrorMessage(
    vmErrExceptionObjReqd,
    "exception object required, but 'new' did not yield an object",
    "The VM tried to construct a new program-defined exception object to represent a run-time error that occurred, but 'new' did not yield an object. Note that another underlying run-time error occurred that triggered the throw in the first place, but information on that error is not available now because of the problem creating the exception object to represent that error.",
  ),
  _ErrorMessage(
    vmErrNoDoubleConv,
    'cannot convert value to native floating point',
    'The value cannot be converted to a floating-point type.',
  ),
  _ErrorMessage(
    vmErrNoNumConv,
    'cannot convert value to a numeric type',
    'The value cannot be converted to a numeric type. Only values that can be converted to integer or BigNumber can be used in this context.',
  ),
  _ErrorMessage(
    vmErrBadTypeLshr,
    "invalid datatype for logical right-shift operator '>>>'",
    "Invalid datatype for the logical right-shift operator '>>>'. These values can't be combined with this operator.",
  ),
  _ErrorMessage(
    vmErrWrongNumOfArgs,
    'wrong number of arguments',
    'The wrong number of arguments was passed to a function or method in the invocation of the function or method.',
  ),
  _ErrorMessage(
    vmErrWrongNumOfArgsCalling,
    'argument mismatch calling %s - function definition is incorrect',
    "The number of arguments doesn't match the number expected calling %s. Check the function or method and correct the number of parameters that it is declared to receive.",
  ),
  _ErrorMessage(
    vmErrNilDeref,
    'nil object reference',
    "The value 'nil' was used to reference an object property. Only valid object references can be used in property evaluations.",
  ),
  _ErrorMessage(
    vmErrMissingNamedArg,
    "missing named argument '%s'",
    "The named argument '%s' was expected in a function or method call, but it wasn't provided by the caller.",
  ),
  _ErrorMessage(vmErrBadTypeCall, 'invalid type for call', 'The value cannot be invoked as a method or function.'),
  _ErrorMessage(
    vmErrNilSelf,
    "nil 'self' value is not allowed",
    "'self' cannot be nil. The function or method context has a nil value for 'self', which is not allowed.",
  ),
  _ErrorMessage(
    vmErrCannotCreateInst,
    'cannot create instance of object - object is not a class',
    'An instance of this object cannot be created, because this object is not a class.',
  ),
  _ErrorMessage(
    vmErrIllegalNew,
    'cannot create instance - class does not allow dynamic construction',
    'An instance of this class cannot be created, because this class does not allow dynamic construction.',
  ),
  _ErrorMessage(
    vmErrInvalidOpcode,
    'invalid opcode - possible image file corruption',
    'Invalid instruction opcode - the image file might be corrupted.',
  ),
  _ErrorMessage(
    vmErrUnhandledExc,
    'unhandled exception',
    'An exception was thrown but was not caught by the program. The interpreter is terminating execution of the program.',
  ),
  _ErrorMessage(
    vmErrStackOverflow,
    'stack overflow',
    'Stack overflow. This indicates that function or method calls were nested too deeply; this might have occurred because of unterminated recursion, which can happen when a function or method calls itself (either directly or indirectly).',
  ),
  _ErrorMessage(
    vmErrBadTypeBif,
    'invalid type for intrinsic function argument',
    'An invalid datatype was provided for an intrinsic function argument.',
  ),
  _ErrorMessage(
    vmErrSayIsNotDefined,
    'default output function is not defined',
    'The default output function is not defined. Implicit string display is not allowed until a default output function is specified.',
  ),
  _ErrorMessage(
    vmErrBadValBif,
    'invalid value for intrinsic function argument',
    'An invalid value was specified for an intrinsic function argument. The value is out of range or is not an allowed value.',
  ),
  _ErrorMessage(
    vmErrBreakpoint,
    'breakpoint encountered',
    'A breakpoint instruction was encountered, and no debugger is active. The compiler might have inserted this breakpoint to indicate an invalid or unreachable location in the code, so executing this instruction probably indicates an error in the program.',
  ),
  _ErrorMessage(
    vmErrInvalidOpcodeMod,
    'invalid opcode modifier - possible image file corruption',
    'Invalid instruction opcode modifier - the image file might be corrupted.',
  ),
  _ErrorMessage(vmErrUnhandledExcParam, 'Unhandled exception: %s', 'Unhandled exception: %s'),
  _ErrorMessage(vmErrVmExcParam, 'VM Error: %s', 'VM Error: %s'),
  _ErrorMessage(vmErrVmExcCode, 'VM Error: code %d', 'VM Error: code %d'),
  _ErrorMessage(
    vmErrExcInStaticInit,
    'Exception in static initializer for %s.%s: %s',
    'An exception occurred in the static initializer for %s.%s: %s',
  ),
  _ErrorMessage(vmErrIntclsGeneralError, 'intrinsic class exception: %s', 'Exception in intrinsic class method: %s'),
  _ErrorMessage(
    vmErrStackOutOfBounds,
    'stack access is out of bounds',
    "The program attempted to access a stack location that isn't part of the current expression storage area. This probably indicates a problem with the compiler that was used to create this program, or a corrupted program file.",
  ),
  _ErrorMessage(vmErrDbgAbort, "'abort' signal", "'abort' signal"),
];

/// Get an error message by error code
String? getErrorMessage(int errorCode, {bool verbose = false}) {
  for (final msg in _errorMessages) {
    if (msg.code == errorCode) {
      return verbose ? msg.longMsg : msg.shortMsg;
    }
  }
  return null;
}

// ----------------------------------------------------------------------------
// Message Formatting
// ----------------------------------------------------------------------------

/// Format an error message with parameters
///
/// Supports the following format codes:
/// - %s - String parameter
/// - %d - Signed decimal integer
/// - %u - Unsigned decimal integer
/// - %x - Hexadecimal integer
/// - %% - Literal percent sign
String formatErrorMessage(String template, T3VmException exc) {
  final result = StringBuffer();
  int paramIndex = 0;

  for (int i = 0; i < template.length; i++) {
    if (template[i] == '%' && i + 1 < template.length) {
      final formatChar = template[i + 1];

      // Handle %% escape first (doesn't consume parameters)
      if (formatChar == '%') {
        result.write('%');
        i++; // Skip the second %
        continue;
      }

      // If we've run out of parameters, just copy the format code as-is
      if (paramIndex >= exc.paramCount) {
        result.write(template[i]);
        continue;
      }

      final param = exc.getParam(paramIndex);

      switch (formatChar) {
        case 's':
          // String parameter
          if (param.type == T3ErrorParamType.string) {
            result.write(param.asString);
          } else {
            result.write('?');
          }
          paramIndex++;
          i++; // Skip the format character
          break;

        case 'd':
          // Signed decimal integer
          if (param.type == T3ErrorParamType.int || param.type == T3ErrorParamType.ulong) {
            result.write(param.asInt.toString());
          } else {
            result.write('?');
          }
          paramIndex++;
          i++; // Skip the format character
          break;

        case 'u':
          // Unsigned decimal integer
          if (param.type == T3ErrorParamType.int || param.type == T3ErrorParamType.ulong) {
            result.write(param.asInt.toUnsigned(32).toString());
          } else {
            result.write('?');
          }
          paramIndex++;
          i++; // Skip the format character
          break;

        case 'x':
          // Hexadecimal integer
          if (param.type == T3ErrorParamType.int || param.type == T3ErrorParamType.ulong) {
            result.write(param.asInt.toRadixString(16));
          } else {
            result.write('?');
          }
          paramIndex++;
          i++; // Skip the format character
          break;

        default:
          // Unknown format code - just copy it as-is
          result.write(template[i]);
          break;
      }
    } else {
      result.write(template[i]);
    }
  }

  return result.toString();
}

// ----------------------------------------------------------------------------
// Utility Functions
// ----------------------------------------------------------------------------

/// Throw a VM error with no parameters
Never throwVmError(int errorCode) {
  throw T3VmException(errorCode);
}

/// Throw a VM error with parameters
Never throwVmErrorWithParams(int errorCode, List<T3ErrorParam> params) {
  throw T3VmException.withParams(errorCode, params);
}
