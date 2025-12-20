import 'package:zart/src/glulx/glulx_memory_map.dart';
import 'package:zart/src/glulx/typable_objects.dart';

/// Spec Section 1.4.1.3: Compressed strings
class CompressedString extends GlulxString {
  final int bitStreamAddress;

  CompressedString(int address) : bitStreamAddress = address + 1, super(address, GlulxTypableType.stringE1);
}

/// Spec Section 1.4.1.4: The String-Decoding Table
class HuffmanTable {
  final int address;
  final int length;
  final int nodeCount;
  final int rootAddress;
  final Map<int, HuffmanNode> nodes;

  HuffmanTable(this.address, this.length, this.nodeCount, this.rootAddress, this.nodes);

  static HuffmanTable parse(GlulxMemoryMap memory, int address) {
    final length = memory.readWord(address);
    final nodeCount = memory.readWord(address + 4);
    final rootAddress = memory.readWord(address + 8);
    final nodes = <int, HuffmanNode>{};

    // Note: We don't necessarily need to parse all nodes upfront if we're not caching,
    // but the plan includes ROM caching.
    return HuffmanTable(address, length, nodeCount, rootAddress, nodes);
  }
}

/// Base class for Huffman table nodes.
abstract class HuffmanNode {
  final int type;
  HuffmanNode(this.type);

  static HuffmanNode parse(GlulxMemoryMap memory, int address) {
    final type = memory.readByte(address);
    switch (type) {
      /// Spec 1.4.1.4: "Branch (non-leaf node) | Type: 00 | Left (0) Node | Right (1) Node"
      case 0x00:
        return BranchNode(memory.readWord(address + 1), memory.readWord(address + 5));

      /// Spec 1.4.1.4: "String terminator | Type: 01 | This ends the string-decoding process."
      case 0x01:
        return TerminatorNode();

      /// Spec 1.4.1.4: "Single character | Type: 02 | Character (1 byte)"
      case 0x02:
        return SingleCharNode(memory.readByte(address + 1));

      /// Spec 1.4.1.4: "C-style string | Type: 03 | Characters... | NUL: 00"
      case 0x03:
        final bytes = <int>[];
        int current = address + 1;
        while (true) {
          final b = memory.readByte(current++);
          if (b == 0) break;
          bytes.add(b);
        }
        return StringNode(bytes);

      /// Spec 1.4.1.4: "Single Unicode character | Type: 04 | Character (4 bytes)"
      case 0x04:
        return UnicodeCharNode(memory.readWord(address + 1));

      /// Spec 1.4.1.4: "C-style Unicode string | Type: 05 | Characters... | NUL: 00000000"
      case 0x05:
        final chars = <int>[];
        int current = address + 1;
        while (true) {
          final c = memory.readWord(current);
          current += 4;
          if (c == 0) break;
          chars.add(c);
        }
        return UnicodeStringNode(chars);

      /// Spec 1.4.1.4: "Indirect reference | Type: 08 | Address (4 bytes)"
      case 0x08:
        return IndirectNode(memory.readWord(address + 1));

      /// Spec 1.4.1.4: "Double-indirect reference | Type: 09 | Address (4 bytes)"
      case 0x09:
        return DoubleIndirectNode(memory.readWord(address + 1));

      /// Spec 1.4.1.4: "Indirect reference with arguments | Type: 0A | Address | Count | Args..."
      case 0x0A:
        final addr = memory.readWord(address + 1);
        final count = memory.readWord(address + 5);
        final args = <int>[];
        for (var i = 0; i < count; i++) {
          args.add(memory.readWord(address + 9 + (i * 4)));
        }
        return IndirectArgsNode(addr, args);

      /// Spec 1.4.1.4: "Double-indirect reference with arguments | Type: 0B | Address | Count | Args..."
      case 0x0B:
        final addr = memory.readWord(address + 1);
        final count = memory.readWord(address + 5);
        final args = <int>[];
        for (var i = 0; i < count; i++) {
          args.add(memory.readWord(address + 9 + (i * 4)));
        }
        return DoubleIndirectArgsNode(addr, args);
      default:
        throw Exception('Unknown Huffman node type: 0x${type.toRadixString(16)} at 0x${address.toRadixString(16)}');
    }
  }
}

class BranchNode extends HuffmanNode {
  final int leftAddress;
  final int rightAddress;
  BranchNode(this.leftAddress, this.rightAddress) : super(0x00);
}

class TerminatorNode extends HuffmanNode {
  TerminatorNode() : super(0x01);
}

class SingleCharNode extends HuffmanNode {
  final int char;
  SingleCharNode(this.char) : super(0x02);
}

class StringNode extends HuffmanNode {
  final List<int> bytes;
  StringNode(this.bytes) : super(0x03);
}

class UnicodeCharNode extends HuffmanNode {
  final int char;
  UnicodeCharNode(this.char) : super(0x04);
}

class UnicodeStringNode extends HuffmanNode {
  final List<int> characters;
  UnicodeStringNode(this.characters) : super(0x05);
}

class IndirectNode extends HuffmanNode {
  final int address;
  IndirectNode(this.address) : super(0x08);
}

class DoubleIndirectNode extends HuffmanNode {
  final int address;
  DoubleIndirectNode(this.address) : super(0x09);
}

class IndirectArgsNode extends HuffmanNode {
  final int address;
  final List<int> arguments;
  IndirectArgsNode(this.address, this.arguments) : super(0x0A);
}

class DoubleIndirectArgsNode extends HuffmanNode {
  final int address;
  final List<int> arguments;
  DoubleIndirectArgsNode(this.address, this.arguments) : super(0x0B);
}

/// Logic for decoding compressed strings.
class GlulxStringDecoder {
  final GlulxMemoryMap memory;
  final Map<int, HuffmanTable> _tableCache = {};

  GlulxStringDecoder(this.memory);

  /// Decodes and prints a compressed string.
  ///
  /// [printChar] is called for each character, with (ch, resumeAddr, resumeBit)
  /// [printUnicode] is called for each unicode char, with (ch, resumeAddr, resumeBit)
  /// [callString] is called for indirect string references (type 0xE0-E2).
  /// [callFunc] is called for indirect function references (type 0xC0-C1).
  /// Reference: Spec 1.4.1.4 - Indirect reference handling
  void decode(
    int stringAddress,
    int tableAddress,
    void Function(int ch, int resumeAddr, int resumeBit) printChar,
    void Function(int ch, int resumeAddr, int resumeBit) printUnicode,
    void Function(int resumeAddr, int resumeBit, int stringAddr) callString,
    void Function(int resumeAddr, int resumeBit, int funcAddr, List<int> args) callFunc, {
    int? startAddr,
    int? startBit,
  }) {
    final table = _getTable(tableAddress);
    int currentBitAddr = startAddr ?? (stringAddress + 1);
    int currentBit = startBit ?? 0;

    int nextBit() {
      final byte = memory.readByte(currentBitAddr);
      final bit = (byte >> currentBit) & 1;
      currentBit++;
      if (currentBit == 8) {
        currentBit = 0;
        currentBitAddr++;
      }
      return bit;
    }

    while (true) {
      HuffmanNode node = _getNode(table, table.rootAddress);
      while (node is BranchNode) {
        final bit = nextBit();
        node = _getNode(table, bit == 0 ? node.leftAddress : node.rightAddress);
      }

      if (node is TerminatorNode) break;
      if (node is SingleCharNode) printChar(node.char, currentBitAddr, currentBit);
      if (node is StringNode) {
        for (final b in node.bytes) {
          printChar(b, currentBitAddr, currentBit);
        }
      }
      if (node is UnicodeCharNode) printUnicode(node.char, currentBitAddr, currentBit);
      if (node is UnicodeStringNode) {
        for (final c in node.characters) {
          printUnicode(c, currentBitAddr, currentBit);
        }
      }

      if (node is IndirectNode) {
        // Spec: "If it is a string, it is printed. If a function, it is called."
        if (_dispatchIndirect(node.address, [], callString, callFunc, currentBitAddr, currentBit)) return;
      }
      if (node is DoubleIndirectNode) {
        // Spec: "The address refers to a four-byte field in memory, and *that*
        // contains the address of a string or function."
        final target = memory.readWord(node.address);
        if (_dispatchIndirect(target, [], callString, callFunc, currentBitAddr, currentBit)) return;
      }
      if (node is IndirectArgsNode) {
        // If string, args are ignored. If function, args are passed.
        if (_dispatchIndirect(node.address, node.arguments, callString, callFunc, currentBitAddr, currentBit)) return;
      }
      if (node is DoubleIndirectArgsNode) {
        final target = memory.readWord(node.address);
        if (_dispatchIndirect(target, node.arguments, callString, callFunc, currentBitAddr, currentBit)) return;
      }
    }
  }

  /// Dispatches an indirect reference to either callString or callFunc based on type.
  /// Reference: Spec 1.4.1.4 "Indirect reference" - type 0xE0-E2 = string, 0xC0-C1 = function.
  /// Changed to signal for BOTH strings and functions so main loop can push 0x10 stub first.
  /// Reference: C interpreter string.c:386-407 pushes 0x10 stub before processing either.
  bool _dispatchIndirect(
    int address,
    List<int> args,
    void Function(int resumeAddr, int resumeBit, int stringAddr) callString,
    void Function(int resumeAddr, int resumeBit, int funcAddr, List<int> args) callFunc,
    int resumeAddr,
    int resumeBit,
  ) {
    if (address == 0) return false;
    final type = memory.readByte(address);
    if (type >= 0xE0 && type <= 0xE2) {
      // Indirect string reference - signal to exit decoder and let main loop handle
      callString(resumeAddr, resumeBit, address);
      return true; // Exit decoder
    } else if (type >= 0xC0 && type <= 0xC1) {
      callFunc(resumeAddr, resumeBit, address, args);
      return true;
    } else {
      throw Exception(
        'Indirect reference at 0x${address.toRadixString(16)} is neither string nor function (type 0x${type.toRadixString(16)})',
      );
    }
  }

  HuffmanTable _getTable(int address) {
    if (_tableCache.containsKey(address)) {
      return _tableCache[address]!;
    }

    final table = HuffmanTable.parse(memory, address);

    // Optimization: Cache if in ROM
    if (address < memory.ramStart) {
      _tableCache[address] = table;
    }

    return table;
  }

  HuffmanNode _getNode(HuffmanTable table, int address) {
    if (table.nodes.containsKey(address)) {
      return table.nodes[address]!;
    }

    final node = HuffmanNode.parse(memory, address);

    // Optimization: Cache if table is in ROM or already cached
    if (table.address < memory.ramStart) {
      table.nodes[address] = node;
    }

    return node;
  }
}
