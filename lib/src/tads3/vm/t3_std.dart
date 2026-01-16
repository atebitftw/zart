// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// TADS3 Standard Definitions and Utilities
///
/// This library provides standard definitions, type constants, utility functions,
/// and helper classes needed by the TADS3 VM implementation. It is a Dart port
/// of the essential components from the C++ t3std.h header file.
///
/// Ported from: packages/tads-runner/tads3/t3std.h
library;

// ----------------------------------------------------------------------------
// Type Constants
// ----------------------------------------------------------------------------

/// Maximum value for a signed 16-bit integer
const int int16MaxVal = 32767;

/// Minimum value for a signed 16-bit integer
const int int16MinVal = -32768;

/// Maximum value for an unsigned 16-bit integer
const int uint16MaxVal = 65535;

/// Maximum value for a signed 32-bit integer
const int int32MaxVal = 2147483647;

/// Minimum value for a signed 32-bit integer
const int int32MinVal = -2147483648;

/// Maximum value for an unsigned 32-bit integer
const int uint32MaxVal = 4294967295;

// ----------------------------------------------------------------------------
// Bit Shift Operations
// ----------------------------------------------------------------------------

/// Arithmetic right shift (sign-extending).
///
/// Shifts [a] right by [b] bits, filling the high bits with the sign bit.
/// This ensures consistent behavior across platforms for the VM's OPC_ASHR opcode.
///
/// JavaScript-safe: Explicitly handles 32-bit signed integer arithmetic.
///
/// Example:
/// ```dart
/// t3Ashr(-8, 1) // Returns -4 (sign bit preserved)
/// t3Ashr(8, 1)  // Returns 4
/// ```
int t3Ashr(int a, int b) {
  // For JavaScript compatibility, we need to ensure 32-bit signed behavior:
  // 1. Convert to signed 32-bit integer (handle values outside 32-bit range)
  // 2. Perform arithmetic right shift
  // 3. Ensure result stays in 32-bit signed range

  // Convert to signed 32-bit by masking and sign-extending
  final a32 = (a & 0xFFFFFFFF).toSigned(32);

  // Dart's >> operator performs arithmetic right shift on signed integers
  return a32 >> b;
}

/// Logical right shift (zero-filling).
///
/// Shifts [a] right by [b] bits, filling the high bits with zeros.
/// This ensures consistent behavior across platforms for the VM's OPC_LSHR opcode.
///
/// JavaScript-safe: Uses unsigned right shift (>>>) with 32-bit masking.
///
/// Example:
/// ```dart
/// t3Lshr(-8, 1) // Returns 2147483644 (zero-filled)
/// t3Lshr(8, 1)  // Returns 4
/// ```
int t3Lshr(int a, int b) {
  // To perform a logical right shift in Dart, we need to:
  // 1. Mask to 32 bits (in case we're on a 64-bit platform)
  // 2. Use unsigned right shift operator >>>
  // The >>> operator in Dart is JavaScript-safe and performs zero-fill right shift
  return (a & 0xFFFFFFFF) >>> b;
}

// ----------------------------------------------------------------------------
// String Utilities
// ----------------------------------------------------------------------------

/// Safe string copy with explicit source length.
///
/// Copies up to [srcLen] characters from [src] to a new string, truncating
/// if necessary. This is equivalent to the C++ lib_strcpy function.
///
/// Returns the copied string, which will be at most [srcLen] characters.
String libStrcpy(String src, int srcLen) {
  if (srcLen <= 0) return '';
  if (srcLen >= src.length) return src;
  return src.substring(0, srcLen);
}

/// Compare two counted-length strings.
///
/// Returns < 0 if [str1] < [str2], 0 if equal, > 0 if [str1] > [str2].
/// Compares up to the length of the shorter string, then by length if equal.
int libStrcmp(String str1, int len1, String str2, int len2) {
  final byLen = len1 - len2;

  // Truncate strings to their specified lengths
  final s1 = libStrcpy(str1, len1);
  final s2 = libStrcpy(str2, len2);

  // Compare the minimum length
  final minLen = len1 < len2 ? len1 : len2;
  final byMem = s1.substring(0, minLen).compareTo(s2.substring(0, minLen));

  return byMem != 0 ? byMem : byLen;
}

/// Compare two counted-length strings, case-insensitive.
///
/// Returns < 0 if [str1] < [str2], 0 if equal, > 0 if [str1] > [str2].
/// Comparison is case-insensitive for ASCII characters.
int libStricmp(String str1, int len1, String str2, int len2) {
  final byLen = len1 - len2;

  // Truncate and convert to lowercase
  final s1 = libStrcpy(str1, len1).toLowerCase();
  final s2 = libStrcpy(str2, len2).toLowerCase();

  // Compare the minimum length
  final minLen = len1 < len2 ? len1 : len2;
  final byMem = s1.substring(0, minLen).compareTo(s2.substring(0, minLen));

  return byMem != 0 ? byMem : byLen;
}

/// Limited-length character search.
///
/// Searches within [src] for [ch], stopping after [len] characters or at
/// the end of the string. Returns the index of the character, or -1 if not found.
int libStrnchr(String src, int len, int ch) {
  final searchLen = len < src.length ? len : src.length;
  final charStr = String.fromCharCode(ch);

  for (int i = 0; i < searchLen; i++) {
    if (src[i] == charStr) return i;
  }

  return -1;
}

/// Limited-length string to integer conversion.
///
/// Parses an integer from the first [len] characters of [str].
/// Returns 0 if the string doesn't contain a valid integer.
int libAtoi(String str, int len) {
  if (len <= 0 || str.isEmpty) return 0;

  final truncated = libStrcpy(str, len).trim();
  return int.tryParse(truncated) ?? 0;
}

/// Compare two strings, ignoring differences in whitespace amount.
///
/// Returns true if the strings are equal (other than whitespace differences).
/// Note: We do not ignore the *presence* of whitespace, only differences in
/// the *amount*. For example, "log in" equals "log   in", but "login" does not
/// equal "log in".
bool libStrequalCollapseSpaces(String a, int aLen, String b, int bLen) {
  final s1 = libStrcpy(a, aLen);
  final s2 = libStrcpy(b, bLen);

  int i1 = 0, i2 = 0;

  while (i1 < s1.length && i2 < s2.length) {
    final c1 = s1[i1];
    final c2 = s2[i2];

    // If both are whitespace, skip all consecutive whitespace in both strings
    if (_isWhitespace(c1) && _isWhitespace(c2)) {
      while (i1 < s1.length && _isWhitespace(s1[i1])) i1++;
      while (i2 < s2.length && _isWhitespace(s2[i2])) i2++;
      continue;
    }

    // If characters don't match, strings are not equal
    if (c1 != c2) return false;

    i1++;
    i2++;
  }

  // Both strings should be exhausted for equality
  return i1 == s1.length && i2 == s2.length;
}

bool _isWhitespace(String char) {
  if (char.isEmpty) return false;
  final code = char.codeUnitAt(0);
  return code == 0x20 || code == 0x09 || code == 0x0A || code == 0x0D || code == 0x0B || code == 0x0C;
}

// ----------------------------------------------------------------------------
// Character Classification
// ----------------------------------------------------------------------------

/// Determine if a character is an ASCII character (0-127).
bool isAscii(int c) => c >= 0 && c <= 127;

/// Determine if a character is an ASCII space character.
bool isSpace(int c) => isAscii(c) && (c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D || c == 0x0B || c == 0x0C);

/// Determine if a character is an ASCII alphabetic character (a-z, A-Z).
bool isAlpha(int c) => isAscii(c) && ((c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A));

/// Determine if a character is an ASCII numeric character (0-9).
bool isDigit(int c) => isAscii(c) && c >= 0x30 && c <= 0x39;

/// Determine if a character is an ASCII octal numeric character (0-7).
bool isOdigit(int c) => isAscii(c) && c >= 0x30 && c <= 0x37;

/// Determine if a character is an ASCII hex numeric character (0-9, a-f, A-F).
bool isXdigit(int c) =>
    isAscii(c) && ((c >= 0x30 && c <= 0x39) || (c >= 0x41 && c <= 0x46) || (c >= 0x61 && c <= 0x66));

/// Get the numeric value of a decimal digit character.
int valueOfDigit(int c) => c - 0x30;

/// Get the numeric value of an octal numeric character.
int valueOfOdigit(int c) => c - 0x30;

/// Get the numeric value of a hex numeric character.
int valueOfXdigit(int c) {
  if (c >= 0x61) return c - 0x61 + 10; // 'a'-'f'
  if (c >= 0x41) return c - 0x41 + 10; // 'A'-'F'
  return c - 0x30; // '0'-'9'
}

/// Convert a number 0-15 to a hex digit character.
String intToXdigit(int i) {
  if (i >= 0 && i < 10) return String.fromCharCode(0x30 + i);
  if (i >= 10 && i < 16) return String.fromCharCode(0x41 + i - 10);
  return '?';
}

/// Convert a byte to a pair of hex digits.
String byteToXdigits(int b) {
  final high = (b >> 4) & 0x0F;
  final low = b & 0x0F;
  return intToXdigit(high) + intToXdigit(low);
}

/// Determine if a character is a valid symbol initial character.
///
/// Underscores and alphabetic characters can start symbols.
bool isSyminit(int c) => isAscii(c) && (c == 0x5F || isAlpha(c));

/// Determine if a character is a valid symbol non-initial character.
///
/// Underscores, alphabetics, and digits can be in symbols.
bool isSym(int c) => isAscii(c) && (c == 0x5F || isAlpha(c) || isDigit(c));

/// Determine if a character is ASCII lower-case.
bool isLower(int c) => isAscii(c) && c >= 0x61 && c <= 0x7A;

/// Convert ASCII lower-case to upper-case.
///
/// Returns the character unchanged if it's not ASCII lower-case.
int toUpper(int c) => (isAscii(c) && c >= 0x61 && c <= 0x7A) ? c - 32 : c;

/// Convert ASCII upper-case to lower-case.
///
/// Returns the character unchanged if it's not ASCII upper-case.
int toLower(int c) => (isAscii(c) && c >= 0x41 && c <= 0x5A) ? c + 32 : c;

// ----------------------------------------------------------------------------
// Array List Utility
// ----------------------------------------------------------------------------

/// A simple dynamic array list that automatically expands as needed.
///
/// This is a Dart port of the C++ CArrayList class. It provides a growable
/// list with configurable initial size and increment.
class T3ArrayList<T> {
  /// The underlying list storage
  List<T>? _arr;

  /// Number of elements currently in use
  int _count = 0;

  /// Number of elements allocated
  int _allocated;

  /// Increment size when expanding
  final int _incrementSize;

  /// Create an array list with default initial size (16) and increment (16).
  T3ArrayList() : _allocated = 16, _incrementSize = 16;

  /// Create an array list with custom initial size and increment.
  T3ArrayList.withSize(int initialSize, int incrementSize) : _allocated = initialSize, _incrementSize = incrementSize;

  /// Get the number of elements in the array.
  int get count => _count;

  /// Get the element at the given index (no bounds checking).
  T operator [](int index) => _arr![index];

  /// Set the element at the given index (no bounds checking).
  void operator []=(int index, T value) => _arr![index] = value;

  /// Find an element's index; returns -1 if not found.
  int findElement(T element) {
    if (_arr == null) return -1;

    for (int i = 0; i < _count; i++) {
      if (_arr![i] == element) return i;
    }

    return -1;
  }

  /// Add a new element to the list.
  void addElement(T element) {
    // Initialize array if needed
    if (_arr == null) {
      _arr = List<T>.filled(_allocated, element);
      _count = 0;
    }

    // Expand if necessary
    if (_count >= _allocated) {
      final newSize = _allocated + _incrementSize;
      final newArr = List<T>.filled(newSize, element);

      // Copy existing elements
      for (int i = 0; i < _count; i++) {
        newArr[i] = _arr![i];
      }

      _arr = newArr;
      _allocated = newSize;
    }

    // Add the new element
    _arr![_count++] = element;
  }

  /// Remove one element by value; returns true if found, false if not.
  bool removeElement(T element) {
    final index = findElement(element);
    if (index == -1) return false;

    removeAt(index);
    return true;
  }

  /// Remove the element at the given index.
  void removeAt(int index) {
    if (_arr == null || index >= _count) return;

    // Shift elements down
    for (int i = index; i < _count - 1; i++) {
      _arr![i] = _arr![i + 1];
    }

    _count--;
  }

  /// Clear the entire list.
  void clear() {
    _count = 0;
  }
}
