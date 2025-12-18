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
      case 0x00:
        return BranchNode(memory.readWord(address + 1), memory.readWord(address + 5));
      case 0x01:
        return TerminatorNode();
      case 0x02:
        return SingleCharNode(memory.readByte(address + 1));
      case 0x03:
        final bytes = <int>[];
        int current = address + 1;
        while (true) {
          final b = memory.readByte(current++);
          if (b == 0) break;
          bytes.add(b);
        }
        return StringNode(bytes);
      case 0x04:
        return UnicodeCharNode(memory.readWord(address + 1));
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
      case 0x08:
        return IndirectNode(memory.readWord(address + 1));
      case 0x09:
        return DoubleIndirectNode(memory.readWord(address + 1));
      case 0x0A:
        final addr = memory.readWord(address + 1);
        final count = memory.readWord(address + 5);
        final args = <int>[];
        for (var i = 0; i < count; i++) {
          args.add(memory.readWord(address + 9 + (i * 4)));
        }
        return IndirectArgsNode(addr, args);
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
  /// This is currently a stub for the actual output logic, as we haven't
  /// implemented the I/O system's string printing yet.
  void decode(
    int stringAddress,
    int tableAddress,
    void Function(int) printChar,
    void Function(int) printUnicode,
    void Function(int, List<int>) callFunc,
  ) {
    final table = _getTable(tableAddress);
    int currentBitAddr = stringAddress + 1;
    int currentBit = 0;

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
      if (node is SingleCharNode) printChar(node.char);
      if (node is StringNode) {
        for (final b in node.bytes) {
          printChar(b);
        }
      }
      if (node is UnicodeCharNode) printUnicode(node.char);
      if (node is UnicodeStringNode) {
        for (final c in node.characters) {
          printUnicode(c);
        }
      }
      if (node is IndirectNode) {
        callFunc(node.address, []);
      }
      if (node is DoubleIndirectNode) {
        final target = memory.readWord(node.address);
        callFunc(target, []);
      }
      if (node is IndirectArgsNode) {
        callFunc(node.address, node.arguments);
      }
      if (node is DoubleIndirectArgsNode) {
        final target = memory.readWord(node.address);
        callFunc(target, node.arguments);
      }
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
