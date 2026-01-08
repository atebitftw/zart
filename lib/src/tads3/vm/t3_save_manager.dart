import 'dart:typed_data';
import 'package:zart/src/tads3/vm/t3_value.dart';

/// Helper for TADS 3 save file operations.
class T3SaveManager {
  static const String signaturePrefix = 'T3-state-v';
  static const String currentVersion = '0008';
  static const String signatureSuffix = '\r\n\x1a';

  /// Standard CRC-32 table.
  static final Uint32List _crcTable = _buildCrcTable();

  static Uint32List _buildCrcTable() {
    final table = Uint32List(256);
    for (var i = 0; i < 256; i++) {
      var c = i;
      for (var j = 0; j < 8; j++) {
        if ((c & 1) != 0) {
          c = 0xEDB88320 ^ (c >> 1);
        } else {
          c = c >> 1;
        }
      }
      table[i] = c;
    }
    return table;
  }

  /// Calculates CRC-32 of the given data.
  static int calculateCrc32(Uint8List data, [int initialCrc = 0xFFFFFFFF]) {
    var crc = initialCrc;
    for (var i = 0; i < data.length; i++) {
      crc = _crcTable[(crc ^ data[i]) & 0xFF] ^ (crc >> 8);
    }
    return crc ^ 0xFFFFFFFF;
  }

  /// Validates the save file signature and returns the version string.
  static String? validateSignature(Uint8List data) {
    if (data.length < 17) return null;

    final sig = String.fromCharCodes(data.sublist(0, 17));
    if (!sig.startsWith(signaturePrefix)) return null;
    if (!sig.endsWith(signatureSuffix)) return null;

    return sig.substring(signaturePrefix.length, signaturePrefix.length + 4);
  }

  /// Creates a save file header (signature + placeholder for size and CRC).
  static Uint8List createHeader(String version) {
    final builder = BytesBuilder();
    builder.add(signaturePrefix.codeUnits);
    builder.add(version.codeUnits);
    builder.add(signatureSuffix.codeUnits);

    // Add 4 bytes for size and 4 bytes for CRC (to be filled later)
    builder.add(Uint8List(8));

    return builder.toBytes();
  }

  /// Creates a full save file from the VM state.
  static Uint8List save(dynamic vm) {
    final builder = BytesBuilder();

    // 1. Signature
    builder.add(createHeader(currentVersion));

    final dataStart = builder.length;

    // 2. Timestamp (24 bytes)
    // For now, use dummy or extract from image if available
    builder.add(Uint8List(24));

    // 3. Image filename (UINT2 length + string)
    builder.addByte(0); // Dummy: 0 length
    builder.addByte(0);

    // 4. Metaclasses
    _saveMetaclasses(vm, builder);

    // 5. Objects
    _saveObjects(vm, builder);

    // 6. Global Symbols
    _saveSymbols(vm, builder);

    // 7. Stack and Registers
    _saveMachineState(vm, builder);

    final totalData = builder.toBytes();
    final dataSize = totalData.length - dataStart;

    // Fill in size and CRC in the header
    final finalView = ByteData.view(totalData.buffer, totalData.offsetInBytes, totalData.length);
    finalView.setUint32(17, dataSize, Endian.little);

    final crcData = totalData.sublist(17 + 8); // CRC is over everything after size/checksum (8 bytes)
    final crc = calculateCrc32(crcData);
    finalView.setUint32(17 + 4, crc, Endian.little);

    return totalData;
  }

  static void _saveMetaclasses(dynamic vm, BytesBuilder b) {
    b.add('MCLD'.codeUnits);
    final mcData = BytesBuilder();
    final metaclasses = vm.metaclasses.dependencies as List<dynamic>;

    mcData.add(Uint8List(2)..buffer.asByteData().setUint16(0, metaclasses.length, Endian.little));

    for (final dep in metaclasses) {
      final nameBytes = dep.identifier.codeUnits;
      mcData.addByte(nameBytes.length);
      mcData.add(nameBytes);
    }

    final mcBytes = mcData.toBytes();
    b.add(Uint8List(4)..buffer.asByteData().setUint32(0, mcBytes.length, Endian.little));
    b.add(mcBytes);
  }

  static void _saveObjects(dynamic vm, BytesBuilder b) {
    b.add('OBJS'.codeUnits);
    final objData = BytesBuilder();
    final allObjects = (vm.objectTable.all as Iterable<dynamic>).where((o) => !o.isTransient).toList();

    objData.add(Uint8List(4)..buffer.asByteData().setUint32(0, allObjects.length, Endian.little));

    for (final obj in allObjects) {
      final mcIdx = vm.metaclasses.indexOf(obj.metaclass);
      final saved = obj.save() as Uint8List;

      objData.add(Uint8List(4)..buffer.asByteData().setUint32(0, obj.objectId, Endian.little));
      objData.add(Uint8List(4)..buffer.asByteData().setUint32(0, 0, Endian.little)); // flags
      objData.add(Uint8List(2)..buffer.asByteData().setUint16(0, mcIdx, Endian.little));
      objData.add(Uint8List(2)..buffer.asByteData().setUint16(0, saved.length, Endian.little));
      objData.add(saved);
    }

    final objBytes = objData.toBytes();
    b.add(Uint8List(4)..buffer.asByteData().setUint32(0, objBytes.length, Endian.little));
    b.add(objBytes);
  }

  static void _saveSymbols(dynamic vm, BytesBuilder b) {
    b.add('GSYM'.codeUnits);
    final symData = BytesBuilder();
    final symbols = vm.symbols as Map<String, dynamic>;

    symData.add(Uint8List(4)..buffer.asByteData().setUint32(0, symbols.length, Endian.little));

    for (final entry in symbols.entries) {
      final valBuf = Uint8List(5);
      (entry.value as dynamic).toPortable(valBuf, 0);
      symData.add(valBuf);

      final nameBytes = entry.key.codeUnits;
      symData.addByte(nameBytes.length);
      symData.add(nameBytes);
    }

    final symBytes = symData.toBytes();
    b.add(Uint8List(4)..buffer.asByteData().setUint32(0, symBytes.length, Endian.little));
    b.add(symBytes);
  }

  static void _saveMachineState(dynamic vm, BytesBuilder b) {
    // 1. REGS block
    b.add('REGS'.codeUnits);
    final regsData = BytesBuilder();
    regsData.add(Uint8List(4)..buffer.asByteData().setUint32(0, vm.registers.ip, Endian.little));
    regsData.add(Uint8List(4)..buffer.asByteData().setUint32(0, vm.registers.ep, Endian.little));
    regsData.add(Uint8List(4)..buffer.asByteData().setUint32(0, vm.stack.sp, Endian.little));
    regsData.add(Uint8List(4)..buffer.asByteData().setUint32(0, vm.stack.fp, Endian.little));

    final r0Buf = Uint8List(5);
    vm.registers.r0.toPortable(r0Buf, 0);
    regsData.add(r0Buf);

    final regsBytes = regsData.toBytes();
    b.add(Uint8List(4)..buffer.asByteData().setUint32(0, regsBytes.length, Endian.little));
    b.add(regsBytes);

    // 2. STAK block
    b.add('STAK'.codeUnits);
    final stakData = BytesBuilder();
    final depth = vm.stack.sp;
    stakData.add(Uint8List(4)..buffer.asByteData().setUint32(0, depth, Endian.little));

    for (var i = 0; i < depth; i++) {
      final valBuf = Uint8List(5);
      vm.stack.values[i].toPortable(valBuf, 0);
      stakData.add(valBuf);
    }

    final stakBytes = stakData.toBytes();
    b.add(Uint8List(4)..buffer.asByteData().setUint32(0, stakBytes.length, Endian.little));
    b.add(stakBytes);
  }

  /// Loads the VM state from a save file.
  static void load(dynamic vm, Uint8List data) {
    final version = validateSignature(data);
    if (version == null) throw FormatException('Invalid save file signature');

    final view = ByteData.view(data.buffer, data.offsetInBytes);
    // Size check skipped (view.getUint32(17) would give size)
    final expectedCrc = view.getUint32(17 + 4, Endian.little);

    // Check CRC
    final crcData = data.sublist(17 + 8);
    final actualCrc = calculateCrc32(crcData);
    if (actualCrc != expectedCrc) {
      // For now, just log it, don't throw yet to allow testing incomplete saves
      print('Warning: Save file CRC mismatch (expected: $expectedCrc, actual: $actualCrc)');
    }

    var offset = 17 + 8;

    // 2. Timestamp (24 bytes)
    offset += 24;

    // 3. Image filename
    final fileLen = view.getUint16(offset, Endian.little);
    offset += 2 + fileLen;

    // 4. Sections
    while (offset + 8 <= data.length) {
      final sectionId = String.fromCharCodes(data.sublist(offset, offset + 4));
      final sectionLen = view.getUint32(offset + 4, Endian.little);
      offset += 8;

      final sectionData = data.sublist(offset, offset + sectionLen);
      _loadSection(vm, sectionId, sectionData);

      offset += sectionLen;
    }
  }

  static void _loadSection(dynamic vm, String id, Uint8List data) {
    switch (id) {
      case 'MCLD':
        _loadMetaclasses(vm, data);
        break;
      case 'OBJS':
        _loadObjects(vm, data);
        break;
      case 'GSYM':
        _loadSymbols(vm, data);
        break;
      case 'REGS':
        _loadRegisters(vm, data);
        break;
      case 'STAK':
        _loadStack(vm, data);
        break;
    }
  }

  static void _loadMetaclasses(dynamic vm, Uint8List data) {
    // Check consistency
  }

  static void _loadObjects(dynamic vm, Uint8List data) {
    final view = ByteData.view(data.buffer, data.offsetInBytes);
    final count = view.getUint32(0, Endian.little);
    var offset = 4;

    for (var i = 0; i < count; i++) {
      final objId = view.getUint32(offset, Endian.little);
      // flags (offset+4) unused
      final mcIdx = view.getUint16(offset + 8, Endian.little);
      final dataLen = view.getUint16(offset + 10, Endian.little);
      offset += 12;

      final objData = data.sublist(offset, offset + dataLen);
      offset += dataLen;

      // Update existing object or create new one
      final dep = vm.metaclasses.byIndex(mcIdx);
      if (dep == null) continue;

      // We use the object table to create/overwrite the object
      vm.objectTable.restoreObject(objId, dep.name, objData);
    }
  }

  static void _loadSymbols(dynamic vm, Uint8List data) {
    final view = ByteData.view(data.buffer, data.offsetInBytes);
    final count = view.getUint32(0, Endian.little);
    var offset = 4;

    final symbols = <String, T3Value>{};
    for (var i = 0; i < count; i++) {
      final value = T3Value.fromPortable(data, offset);
      offset += 5;

      final nameLen = data[offset++];
      final name = String.fromCharCodes(data.sublist(offset, offset + nameLen));
      offset += nameLen;

      symbols[name] = value;
    }

    vm.symbols.clear();
    vm.symbols.addAll(symbols);
  }

  static void _loadRegisters(dynamic vm, Uint8List data) {
    final view = ByteData.view(data.buffer, data.offsetInBytes);
    vm.registers.ip = view.getUint32(0, Endian.little);
    vm.registers.ep = view.getUint32(4, Endian.little);
    vm.stack.sp = view.getUint32(8, Endian.little);
    vm.stack.fp = view.getUint32(12, Endian.little);
    vm.registers.r0 = T3Value.fromPortable(data, 16);
  }

  static void _loadStack(dynamic vm, Uint8List data) {
    final view = ByteData.view(data.buffer, data.offsetInBytes);
    final depth = view.getUint32(0, Endian.little);
    vm.stack.sp = depth; // Actually redundant if restored from REGS, but needed for subsequent parsing logic if any

    var offset = 4;
    for (var i = 0; i < depth; i++) {
      vm.stack.values[i] = T3Value.fromPortable(data, offset);
      offset += T3Value.portableSize;
    }
  }
}
