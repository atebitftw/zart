import 'dart:typed_data';

/// A function set dependency entry.
///
/// Function sets are groups of built-in functions that the program
/// can call. Each set has a name and version.
class T3FunctionSetDep {
  /// The full identifier string (e.g., "t3vm/030000").
  final String identifier;

  /// The dependency table index.
  final int index;

  /// The base name without version (e.g., "t3vm").
  final String name;

  /// The version number, or null if not specified.
  final int? version;

  T3FunctionSetDep({required this.identifier, required this.index, required this.name, this.version});

  @override
  String toString() => 'T3FunctionSetDep($index: $identifier)';
}

/// Parsed FNSD (function set dependency) block.
///
/// The function set dependency list tells the VM which function sets
/// (groups of built-in intrinsic functions) the program requires.
///
/// See spec section "FNSD Function Set Dependency List Block".
class T3FunctionSetDepList {
  /// The list of function set dependencies.
  final List<T3FunctionSetDep> dependencies;

  T3FunctionSetDepList(this.dependencies);

  /// Parses an FNSD block from raw data.
  ///
  /// FNSD block format:
  /// - UINT2: number of entries
  /// - For each entry:
  ///   - UINT2: name length
  ///   - bytes: name (ASCII)
  factory T3FunctionSetDepList.parse(Uint8List data) {
    final view = ByteData.view(data.buffer, data.offsetInBytes);
    final count = view.getUint16(0, Endian.little);

    final deps = <T3FunctionSetDep>[];
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

      deps.add(T3FunctionSetDep(identifier: identifier, index: i, name: name, version: version));
    }

    return T3FunctionSetDepList(deps);
  }

  /// Gets a function set dependency by index.
  T3FunctionSetDep? byIndex(int index) {
    if (index < 0 || index >= dependencies.length) return null;
    return dependencies[index];
  }

  /// Gets a function set dependency by base name.
  T3FunctionSetDep? byName(String name) {
    for (final dep in dependencies) {
      if (dep.name == name) return dep;
    }
    return null;
  }

  /// Number of function set dependencies.
  int get length => dependencies.length;

  @override
  String toString() => 'T3FunctionSetDepList(${dependencies.length} entries)';
}
