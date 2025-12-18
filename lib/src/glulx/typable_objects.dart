import 'package:zart/src/glulx/glulx_exception.dart';
import 'package:zart/src/glulx/glulx_memory_map.dart';

/// Spec Section 1.4: "structured objects in Glulx main memory follow a simple convention:
/// the first byte indicates the type of the object."
enum GlulxTypableType {
  /// Spec Section 1.4.3: "Type 00 is also reserved; it indicates 'no object'"
  nullObject(0x00),

  /// Spec Section 1.4.1.1: "E0 (for unencoded, C-style strings)"
  stringE0(0xE0),

  /// Spec Section 1.4.1.3: "E1 (for compressed strings)"
  stringE1(0xE1),

  /// Spec Section 1.4.1.2: "E2 (for unencoded strings of Unicode values)"
  stringE2(0xE2),

  /// Spec Section 1.4.2: "C0 (for stack-argument functions)"
  functionC0(0xC0),

  /// Spec Section 1.4.2: "C1 (for local-argument functions)"
  functionC1(0xC1),

  /// Spec Section 1.4.4: "Types 01 to 7F are available for use by the compiler, the library, or the program."
  userDefined(-1),

  /// Spec Section 1.4.3: "Type 80 to BF are reserved for future expansion."
  reserved(-2),

  /// Unknown or unsupported type.
  unknown(-3);

  final int value;
  const GlulxTypableType(this.value);

  static GlulxTypableType fromByte(int byte) {
    if (byte == 0x00) return nullObject;
    if (byte == 0xE0) return stringE0;
    if (byte == 0xE1) return stringE1;
    if (byte == 0xE2) return stringE2;
    if (byte == 0xC0) return functionC0;
    if (byte == 0xC1) return functionC1;
    if (byte >= 0x01 && byte <= 0x7F) return userDefined;
    if (byte >= 0x80 && byte <= 0xBF) return reserved;
    return unknown;
  }
}

/// Base class for all Glulx Typable Objects.
abstract class GlulxTypable {
  final int address;
  final GlulxTypableType type;

  GlulxTypable(this.address, this.type);

  /// Detects the type of object at the given address and returns the appropriate instance.
  static GlulxTypableType getType(GlulxMemoryMap memory, int address) {
    if (address == 0) return GlulxTypableType.nullObject;
    final typeByte = memory.readByte(address);
    return GlulxTypableType.fromByte(typeByte);
  }

  /// Validates that the type at the given address is a valid typable object.
  ///
  /// Throws [GlulxException] if the type is reserved, null, or unknown.
  /// Spec Section 1.4.3: "Type 00 is also reserved; it indicates 'no object',
  /// and should not be used by any typable object."
  static void validateType(GlulxMemoryMap memory, int address) {
    final type = getType(memory, address);
    final typeByte = address == 0 ? 0 : memory.readByte(address);

    switch (type) {
      case GlulxTypableType.nullObject:
        // Spec Section 1.4.3: "Type 00 is also reserved; it indicates 'no object',
        // and should not be used by any typable object."
        throw GlulxException(
          'Invalid typable object: Type 00 indicates "no object" and cannot be used '
          '(Spec Section 1.4.3) at address 0x${address.toRadixString(16).toUpperCase()}',
        );
      case GlulxTypableType.reserved:
        // Spec Section 1.4.3: "Type 80 to BF are reserved for future expansion."
        throw GlulxException(
          'Invalid typable object: Type 0x${typeByte.toRadixString(16).toUpperCase()} is reserved '
          'for future expansion (Spec Section 1.4.3) at address 0x${address.toRadixString(16).toUpperCase()}',
        );
      case GlulxTypableType.unknown:
        throw GlulxException(
          'Invalid typable object: Unknown type 0x${typeByte.toRadixString(16).toUpperCase()} '
          'at address 0x${address.toRadixString(16).toUpperCase()}',
        );
      default:
        // Valid types: stringE0, stringE1, stringE2, functionC0, functionC1, userDefined
        break;
    }
  }
}

/// Base class for all Glulx String objects.
abstract class GlulxString extends GlulxTypable {
  GlulxString(int address, GlulxTypableType type) : super(address, type);
}

/// Spec Section 1.4.1.1: "An unencoded string consists of an E0 byte,
/// followed by all the bytes of the string, followed by a zero byte."
class UnencodedString extends GlulxString {
  final List<int> bytes;

  UnencodedString(int address, this.bytes) : super(address, GlulxTypableType.stringE0);

  static UnencodedString parse(GlulxMemoryMap memory, int address) {
    final bytes = <int>[];
    int current = address + 1;
    while (true) {
      final b = memory.readByte(current++);
      if (b == 0) break;
      bytes.add(b);
    }
    return UnencodedString(address, bytes);
  }
}

/// Spec Section 1.4.1.2: "An unencoded Unicode string consists of an E2 byte,
/// followed by three padding 0 bytes, followed by the Unicode character values
/// (each one being a four-byte integer). Finally, there is a terminating value
/// (four 0 bytes)."
class UnencodedUnicodeString extends GlulxString {
  final List<int> characters;

  UnencodedUnicodeString(int address, this.characters) : super(address, GlulxTypableType.stringE2);

  static UnencodedUnicodeString parse(GlulxMemoryMap memory, int address) {
    final characters = <int>[];
    // Address + 1 is the first padding byte. Unicode chars start at address + 4.
    int current = address + 4;
    while (true) {
      final char = memory.readWord(current);
      current += 4;
      if (char == 0) break;
      characters.add(char);
    }
    return UnencodedUnicodeString(address, characters);
  }
}
