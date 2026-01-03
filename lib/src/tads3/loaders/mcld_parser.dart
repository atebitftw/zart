import 'dart:typed_data';

/// A metaclass dependency entry.
///
/// The metaclass dependency table maps small integer indices (used in
/// bytecode and object blocks) to metaclass identifier strings.
class T3MetaclassDep {
  /// The full metaclass identifier string (e.g., "tads-object/030005").
  final String identifier;

  /// The dependency table index.
  final int index;

  /// The base name without version (e.g., "tads-object").
  final String name;

  /// The version number, or null if not specified.
  final int? version;

  /// Number of property ID's exported by this metaclass.
  final int propertyCount;

  /// Property IDs for metaclass methods.
  final List<int> propertyIds;

  T3MetaclassDep({
    required this.identifier,
    required this.index,
    required this.name,
    this.version,
    required this.propertyCount,
    required this.propertyIds,
  });

  @override
  String toString() => 'T3MetaclassDep($index: $identifier, props: $propertyCount)';
}

/// Parsed MCLD (metaclass dependency) block.
///
/// The metaclass dependency list tells the VM which metaclasses the
/// program requires. Each entry maps an index to a metaclass identifier
/// string like "tads-object/030005" (name/version).
///
/// See spec section "MCLD Metaclass Dependency List Block".
class T3MetaclassDepList {
  /// The list of metaclass dependencies, indexed by dependency table index.
  final List<T3MetaclassDep> dependencies;

  T3MetaclassDepList(this.dependencies);

  /// Parses an MCLD block from raw data.
  ///
  /// MCLD block format:
  /// - UINT2: number of entries
  /// - For each entry:
  ///   - UINT2: name length
  ///   - bytes: name (ASCII)
  ///   - UINT2: number of property IDs
  ///   - UINT2 * n: property IDs
  factory T3MetaclassDepList.parse(Uint8List data) {
    final view = ByteData.view(data.buffer, data.offsetInBytes);
    final count = view.getUint16(0, Endian.little);

    final deps = <T3MetaclassDep>[];
    var offset = 2;

    for (var i = 0; i < count; i++) {
      // Read name length and name
      final nameLen = view.getUint16(offset, Endian.little);
      offset += 2;

      final nameBytes = data.sublist(offset, offset + nameLen);
      final identifier = String.fromCharCodes(nameBytes);
      offset += nameLen;

      // Parse name and version
      String name;
      int? version;
      final slashIdx = identifier.indexOf('/');
      if (slashIdx >= 0) {
        name = identifier.substring(0, slashIdx);
        final versionStr = identifier.substring(slashIdx + 1);
        version = int.tryParse(versionStr);
      } else {
        name = identifier;
        version = null;
      }

      // Read property count and IDs
      final propCount = view.getUint16(offset, Endian.little);
      offset += 2;

      final propIds = <int>[];
      for (var j = 0; j < propCount; j++) {
        propIds.add(view.getUint16(offset, Endian.little));
        offset += 2;
      }

      deps.add(
        T3MetaclassDep(
          identifier: identifier,
          index: i,
          name: name,
          version: version,
          propertyCount: propCount,
          propertyIds: propIds,
        ),
      );
    }

    return T3MetaclassDepList(deps);
  }

  /// Gets a metaclass dependency by index.
  T3MetaclassDep? byIndex(int index) {
    if (index < 0 || index >= dependencies.length) return null;
    return dependencies[index];
  }

  /// Gets a metaclass dependency by base name.
  T3MetaclassDep? byName(String name) {
    for (final dep in dependencies) {
      if (dep.name == name) return dep;
    }
    return null;
  }

  /// Number of metaclass dependencies.
  int get length => dependencies.length;

  @override
  String toString() => 'T3MetaclassDepList(${dependencies.length} entries)';
}
