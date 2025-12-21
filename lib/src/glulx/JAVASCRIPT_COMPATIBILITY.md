# Glulx JavaScript/Web Compatibility Assessment

This document outlines potential issues when running the Glulx interpreter in web environments (via dart2js or Flutter Web). These issues stem from differences between native Dart integers and JavaScript's number handling.

## Background

JavaScript has only one number type: 64-bit IEEE 754 floating-point. This causes issues because:

1. **Bitwise operators** convert operands to **32-bit signed integers**
2. **Integers > 2^53** lose precision
3. Values with bit 31 set are treated as negative by bitwise ops

The Z-machine code uses `BinaryHelper` (see `lib/src/z_machine/binary_helper.dart`) which avoids direct bitwise operations on values > 2^31 by using arithmetic operations instead.

---

## Potential Problem Areas

### 1. `& 0xFFFFFFFF` Masking Pattern

**Risk Level: HIGH**

**Problem:** This pattern is used extensively to wrap values to 32-bit unsigned, but in JavaScript:
- Native Dart: `(-1) & 0xFFFFFFFF` → `4294967295` ✓
- dart2js: `(-1) & 0xFFFFFFFF` → `-1` ✗

**Affected Files:**
| File | Occurrences | Notes |
|------|-------------|-------|
| `glulx_interpreter.dart` | 50+ | Arithmetic, bitwise, shift opcodes |
| `xoshiro128.dart` | 8 | RNG state manipulation |
| `glulx_stack.dart` | 3 | Stack push operations |
| `glulx_header.dart` | 1 | Checksum calculation |
| `glulx_float.dart` | 3 | Float bit manipulation |

**Example locations in `glulx_interpreter.dart`:**
```dart
// Lines 231, 239, 248, etc.
_performStore(dest, (l1 + l2) & 0xFFFFFFFF);
_performStore(dest, (l1 - l2) & 0xFFFFFFFF);
_performStore(dest, (l1 * l2) & 0xFFFFFFFF);
```

---

### 2. Shift Operations (`<<` and `>>`)

**Risk Level: MEDIUM**

**Problem:** JavaScript's shift operators work on 32-bit signed integers. Shifting by large values or shifting values with bit 31 set can produce unexpected results.

**Affected locations:**
- `shiftl` opcode (line ~334): `(l1 << shift) & 0xFFFFFFFF`
- `ushiftr` opcode (line ~349): `((l1 & 0xFFFFFFFF) >> shift) & 0xFFFFFFFF`
- `sshiftr` opcode (line ~366): `(l1 >> shift) & 0xFFFFFFFF`
- `xoshiro128.dart` lines 56-82: Multiple shift operations

---

### 3. Multiplication Overflow

**Risk Level: MEDIUM**

**Problem:** When multiplying two 32-bit values, the result can exceed 2^53 (JavaScript's safe integer limit), causing precision loss.

**Affected locations:**
- `mul` opcode (line ~248): `(l1 * l2) & 0xFFFFFFFF`
- `xoshiro128.dart`:
  - Line 57: `s * 0x85EBCA6B`
  - Line 59: `s * 0xC2B2AE35`
  - Line 69: `_table[1] * 5`
  - Line 70: `... * 9`

---

### 4. Negation Pattern

**Risk Level: LOW-MEDIUM**

```dart
_performStore(dest, (-l1) & 0xFFFFFFFF);
```

Negating values then masking may not produce the expected two's complement result in JavaScript.

---

### 5. `toSigned(32)` Usage

**Risk Level: LOW**

```dart
final l1 = (operands[0] as int).toSigned(32);
```

This should work correctly in dart2js, but worth verifying during web testing.

---

## Safe Patterns Already Used

These patterns work correctly in JavaScript:

✅ **`Uint32List` and `ByteData`** - Use proper typed array semantics
```dart
final Uint32List _table = Uint32List(4);  // xoshiro128.dart
```

✅ **Float/double via `ByteData`** - `setFloat32`, `getFloat64` work correctly
```dart
bd.setFloat64(0, d);
return bd.getUint32(0);  // Correct in JS
```

✅ **Explicit overflow checks** - e.g., `if (shift >= 32)` handling

---

## Recommended Fixes

### Option 1: Replace `& 0xFFFFFFFF` with modulo

```dart
// Instead of:
(x + y) & 0xFFFFFFFF

// Use:
(x + y) % 0x100000000
```

### Option 2: Use `Uint32List` for Intermediate Storage

```dart
final _temp = Uint32List(1);

int toU32(int value) {
  _temp[0] = value;
  return _temp[0];
}

// Usage:
_performStore(dest, toU32(l1 + l2));
```

### Option 3: Create a `GlulxBinaryHelper` Class

Similar to Z-machine's `BinaryHelper`, create a helper class that uses arithmetic instead of bitwise operations for values that may have bit 31 set.

```dart
class GlulxBinaryHelper {
  static final _temp = Uint32List(1);
  
  /// Wraps value to 32-bit unsigned.
  static int toU32(int value) {
    _temp[0] = value;
    return _temp[0];
  }
  
  /// Bitwise AND that works in JavaScript.
  static int and32(int a, int b) {
    _temp[0] = a;
    a = _temp[0];
    _temp[0] = b;
    b = _temp[0];
    _temp[0] = a & b;
    return _temp[0];
  }
  
  // ... similar for or32, xor32, not32, shl32, shr32
}
```

---

## Testing Priority

1. **HIGH**: Run full `glulxercise` test suite in Flutter Web build
2. **HIGH**: Verify `xoshiro128.dart` produces identical sequences in web vs native
3. **MEDIUM**: Test arithmetic opcodes with values near 2^31 boundary
4. **MEDIUM**: Test shift opcodes with various shift amounts
5. **LOW**: Float/double operations (likely already correct via ByteData)

---

## Test Cases to Add

When fixing for web compatibility, add unit tests for:

```dart
// Edge cases near 32-bit boundary
test('add wraps at 32-bit boundary', () {
  // 0xFFFFFFFF + 1 should = 0
  expect(toU32(0xFFFFFFFF + 1), equals(0));
});

test('multiply large values', () {
  // 0x80000000 * 2 should = 0
  expect(toU32(0x80000000 * 2), equals(0));
});

test('negate zero', () {
  // -0 should = 0
  expect(toU32(-0), equals(0));
});

test('negate 1', () {
  // -1 should = 0xFFFFFFFF
  expect(toU32(-1), equals(0xFFFFFFFF));
});
```

---

## References

- Z-machine's `BinaryHelper`: `lib/src/z_machine/binary_helper.dart`
- Dart2js integer behavior: https://dart.dev/guides/language/numbers
- JavaScript bitwise operators: MDN documentation on bitwise operators
