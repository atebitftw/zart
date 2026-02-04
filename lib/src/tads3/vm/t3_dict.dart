// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// TADS3 Dictionary Metaclass
///
/// Dictionary is used by the TADS3 parser to store word-object-property
/// associations. It provides word lookup, adding/removing words, and
/// spelling correction functionality.
///
/// Ported from: packages/tads-runner/tads3/vmdict.cpp
///              packages/tads-runner/tads3/vmdict.h
library;

import 'dart:typed_data';

import 'package:zart/src/tads3/vm/t3_error.dart';
import 'package:zart/src/tads3/vm/t3_list.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_string.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';

/// Property indices for Dictionary intrinsic methods.
const int _propIdxSetComparator = 1;
const int _propIdxFind = 2;
const int _propIdxAdd = 3;
const int _propIdxDel = 4;
const int _propIdxIsDefined = 5;
const int _propIdxForEachWord = 6;
const int _propIdxCorrect = 7;

/// XOR mask for obfuscating dictionary key strings in image data.
const int _keyXorMask = 0xBD;

/// Comparator types.
enum _DictComparatorType {
  /// No comparator - exact byte-for-byte string matching.
  none,

  /// StringComparator object - uses native string comparison.
  stringComparator,

  /// Generic comparator object - calls matchValues/calcHash methods.
  generic,
}

/// A single word association entry (object ID + property ID).
class _DictEntry {
  /// The associated object ID.
  int objId;

  /// The vocabulary property ID.
  int propId;

  /// Whether this entry was loaded from the image file.
  bool fromImage;

  _DictEntry(this.objId, this.propId, {this.fromImage = false});
}

/// A hash table entry containing a word and its list of associations.
class _DictHashEntry {
  /// The word string (UTF-8).
  final String word;

  /// List of object/property associations for this word.
  final List<_DictEntry> entries = [];

  _DictHashEntry(this.word);

  /// Add an entry if not already present.
  /// Returns true if added, false if already exists.
  bool addEntry(int objId, int propId, {bool fromImage = false}) {
    // Check if entry already exists
    for (final entry in entries) {
      if (entry.objId == objId && entry.propId == propId) {
        return false;
      }
    }

    // Find insertion point - keep entries with same property together
    int insertIdx = entries.length;
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].propId == propId) {
        // Find end of this property group
        while (i < entries.length && entries[i].propId == propId) {
          i++;
        }
        insertIdx = i;
        break;
      }
    }

    entries.insert(insertIdx, _DictEntry(objId, propId, fromImage: fromImage));
    return true;
  }

  /// Delete an entry matching the given object and property.
  /// Returns true if deleted, false if not found.
  bool delEntry(int objId, int propId) {
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].objId == objId && entries[i].propId == propId) {
        entries.removeAt(i);
        return true;
      }
    }
    return false;
  }
}

/// Trie node for spelling correction.
class _TrieNode {
  /// Transition character from parent to this node.
  final int ch;

  /// Number of words at this node.
  int wordCount = 0;

  /// Child nodes.
  final List<_TrieNode> children = [];

  /// Next sibling in parent's child list.
  _TrieNode? next;

  _TrieNode(this.ch);

  /// Add a word to the trie.
  void addWord(String word) {
    _TrieNode node = this;
    for (final rune in word.runes) {
      // Find child with this character
      _TrieNode? child;
      for (final c in node.children) {
        if (c.ch == rune) {
          child = c;
          break;
        }
      }

      // Create child if not found
      if (child == null) {
        child = _TrieNode(rune);
        node.children.add(child);
      }

      node = child;
    }
    node.wordCount++;
  }

  /// Find a word in the trie.
  _TrieNode? findWord(String word) {
    _TrieNode node = this;
    for (final rune in word.runes) {
      _TrieNode? child;
      for (final c in node.children) {
        if (c.ch == rune) {
          child = c;
          break;
        }
      }
      if (child == null) return null;
      node = child;
    }
    return node;
  }

  /// Delete a word from the trie.
  void delWord(String word) {
    final node = findWord(word);
    if (node != null && node.wordCount > 0) {
      node.wordCount--;
    }
  }
}

/// Correction types for spelling correction.
enum _CorrType { noChange, insertion, deletion, replacement, transposition }

/// State for spelling correction search.
class _CorrState {
  final List<int> str;
  final int dist;
  final int repl;
  final int ipos;
  final _TrieNode node;
  final _CorrType type;

  _CorrState(this.str, this.dist, this.repl, this.ipos, this.node, this.type);
}

/// Result of spelling correction.
class _CorrWord {
  final List<int> str;
  int dist;
  int repl;

  _CorrWord(this.str, this.dist, this.repl);
}

/// Dictionary metaclass.
class T3ObjDict extends T3Object {
  /// Metaclass registration.
  static final T3MetaclassDict metaclassReg = T3MetaclassDict();

  /// Hash table mapping words to their entries.
  final Map<String, _DictHashEntry> _hashTable = {};

  /// Comparator object ID, or invalidObj if none.
  int _comparator = invalidObj;

  /// Type of comparator.
  _DictComparatorType _comparatorType = _DictComparatorType.none;

  /// Trie for spelling correction (built lazily).
  _TrieNode? _trie;

  /// Whether the dictionary has been modified since image load.
  bool _modified = false;

  /// Image data pointer and size (for reset).
  Uint8List? _imageData;
  int _imageDataOffset = 0;
  int _imageDataSize = 0;

  /// Create an empty Dictionary.
  T3ObjDict();

  @override
  T3Metaclass getMetaclassReg() => metaclassReg;

  @override
  bool isOfMetaclass(T3Metaclass meta) {
    return meta == metaclassReg || super.isOfMetaclass(meta);
  }

  /// Create from stack arguments.
  static int createFromStack(T3VM vm, int argc) {
    int comparator = invalidObj;

    if (argc == 0) {
      // No arguments - no comparator
    } else if (argc == 1) {
      final val = vm.stack.popVal();
      if (val.type == T3DataType.nil) {
        comparator = invalidObj;
      } else if (val.type == T3DataType.obj) {
        comparator = val.getAsObj() ?? invalidObj;
      } else {
        throw T3VmException(vmErrBadTypeBif);
      }
    } else {
      throw T3VmException(vmErrWrongNumOfArgs);
    }

    final obj = T3ObjDict();
    obj._comparator = comparator;
    obj._updateComparatorType(vm);
    obj._modified = true;

    return vm.objTable.registerObj(obj, false);
  }

  /// Update the comparator type based on the current comparator object.
  void _updateComparatorType(T3VM vm) {
    if (_comparator == invalidObj) {
      _comparatorType = _DictComparatorType.none;
    } else {
      // Check if it's a StringComparator (TODO: implement proper check)
      // For now, treat all comparators as generic
      _comparatorType = _DictComparatorType.generic;
    }
  }

  // -------------------------------------------------------------------------
  // T3Object abstract method implementations
  // -------------------------------------------------------------------------

  @override
  void notifyDelete(T3VM vm, bool inRootSet) {}

  @override
  bool isInstanceOf(T3VM vm, int obj) => false;

  @override
  int getSuperclass(T3VM vm, int self, int index) => invalidObj;

  @override
  void setProp(T3VM vm, T3Undo? undo, int self, int propId, T3Value val) {
    throw T3VmException(vmErrInvalidSetprop);
  }

  @override
  bool getProp(
    T3VM vm,
    int propId,
    T3Value retval,
    int self,
    List<int> sourceObj,
    int? argc,
  ) {
    final funcIdx = vm.metaTable.propToVectorIdx(
      metaclassReg.getRegIdx(),
      propId,
    );
    if (funcIdx != null && funcIdx >= 1 && funcIdx <= _propIdxCorrect) {
      sourceObj[0] = self;
      switch (funcIdx) {
        case _propIdxSetComparator:
          return _getpSetComparator(vm, self, retval, argc ?? 0);
        case _propIdxFind:
          return _getpFind(vm, retval, argc ?? 0);
        case _propIdxAdd:
          return _getpAdd(vm, self, retval, argc ?? 0);
        case _propIdxDel:
          return _getpDel(vm, self, retval, argc ?? 0);
        case _propIdxIsDefined:
          return _getpIsDefined(vm, retval, argc ?? 0);
        case _propIdxForEachWord:
          return _getpForEachWord(vm, self, retval, argc ?? 0);
        case _propIdxCorrect:
          return _getpCorrect(vm, retval, argc ?? 0);
      }
    }
    return false;
  }

  @override
  void buildPropList(T3VM vm, int self, T3Value retval) {
    retval.setNil();
  }

  @override
  void markRefs(T3VM vm, int state) {
    // Mark the comparator object if we have one
    if (_comparator != invalidObj) {
      // TODO: Mark comparator reference
    }
    // Note: Dictionary uses weak references for word associations,
    // so we don't mark the objects in entries.
  }

  @override
  void applyUndo(T3VM vm, T3UndoRecord rec) {}

  @override
  void markUndoRef(T3VM vm, T3UndoRecord rec) {}

  @override
  void removeStaleUndoWeakRef(T3VM vm, T3UndoRecord rec) {}

  @override
  void saveToFile(T3VM vm, T3File fp) {}

  @override
  void restoreFromFile(T3VM vm, int self, T3File fp, T3ObjFixup fixups) {}

  @override
  String? castToString(T3VM vm, int self, T3Value newStr) => null;

  @override
  bool inhProp(
    T3VM vm,
    int propId,
    T3Value retval,
    int self,
    int origTargetObj,
    int definingObj,
    List<int> sourceObj,
    int? argc,
  ) {
    return false;
  }

  @override
  void loadFromImage(T3VM vm, int self, Uint8List ptr, int offset, int size) {
    // Save image data reference for reset
    _imageData = ptr;
    _imageDataOffset = offset;
    _imageDataSize = size;

    // Parse image data
    _buildHashFromImage(vm, ptr, offset, size);
  }

  /// Build hash table from image data.
  void _buildHashFromImage(T3VM vm, Uint8List ptr, int offset, int size) {
    if (size < 6) return;

    final view = ByteData.sublistView(ptr, offset, offset + size);
    var pos = 0;

    // Read comparator object ID
    _comparator = view.getUint32(pos, Endian.little);
    if (_comparator == 0) _comparator = invalidObj;
    pos += 4;

    // Read entry count
    final entryCount = view.getUint16(pos, Endian.little);
    pos += 2;

    // Clear existing entries
    _hashTable.clear();
    _trie = null;

    // Read entries
    for (var i = 0; i < entryCount && pos < size; i++) {
      // Read key length
      final keyLen = ptr[offset + pos];
      pos++;

      if (pos + keyLen > size) break;

      // Read and decode key (XOR'd with 0xBD)
      final keyBytes = Uint8List(keyLen);
      for (var j = 0; j < keyLen; j++) {
        keyBytes[j] = ptr[offset + pos + j] ^ _keyXorMask;
      }
      final key = String.fromCharCodes(keyBytes);
      pos += keyLen;

      if (pos + 2 > size) break;

      // Read sub-entry count
      final subEntryCount = view.getUint16(pos, Endian.little);
      pos += 2;

      // Get or create hash entry
      var hashEntry = _hashTable[key];
      if (hashEntry == null) {
        hashEntry = _DictHashEntry(key);
        _hashTable[key] = hashEntry;
      }

      // Read sub-entries
      for (var j = 0; j < subEntryCount && pos + 6 <= size; j++) {
        final objId = view.getUint32(pos, Endian.little);
        pos += 4;
        final propId = view.getUint16(pos, Endian.little);
        pos += 2;

        hashEntry.addEntry(objId, propId, fromImage: true);
      }
    }

    // Don't set comparator type yet - object may not be loaded
    _comparatorType = _DictComparatorType.none;
    _modified = false;
  }

  @override
  void postLoadInit(T3VM vm, int self) {
    // Now that all objects are loaded, set up the comparator
    if (_comparator != invalidObj) {
      _updateComparatorType(vm);
      // Hash values might change with comparator - for now, we keep existing
    }
  }

  // -------------------------------------------------------------------------
  // Core Dictionary Operations
  // -------------------------------------------------------------------------

  /// Calculate hash for a string.
  int _calcStrHash(String str) {
    // Simple hash - for exact matching
    var hash = 0;
    for (final rune in str.runes) {
      hash = ((hash << 5) + hash) ^ rune;
    }
    return hash & 0x7FFFFFFF;
  }

  /// Match two strings according to current comparator.
  /// Returns true if they match, false otherwise.
  bool _matchStrings(T3VM vm, String valStr, String refStr) {
    switch (_comparatorType) {
      case _DictComparatorType.none:
        // Exact byte-for-byte comparison
        return valStr == refStr;

      case _DictComparatorType.stringComparator:
      case _DictComparatorType.generic:
        // TODO: Implement comparator-based matching
        // For now, fall back to exact match
        return valStr == refStr;
    }
  }

  /// Add a word-object-property association.
  void addWord(T3VM vm, int self, String word, int objId, int propId) {
    var entry = _hashTable[word];
    if (entry == null) {
      entry = _DictHashEntry(word);
      _hashTable[word] = entry;
    }

    final added = entry.addEntry(objId, propId, fromImage: false);

    // Add to trie if we have one
    if (added && _trie != null) {
      _trie!.addWord(word);
    }

    _modified = true;
  }

  /// Delete a word-object-property association.
  void delWord(T3VM vm, int self, String word, int objId, int propId) {
    final entry = _hashTable[word];
    if (entry == null) return;

    final deleted = entry.delEntry(objId, propId);

    if (deleted) {
      // Remove from trie if we have one
      if (_trie != null) {
        _trie!.delWord(word);
      }

      // Remove hash entry if no more associations
      if (entry.entries.isEmpty) {
        _hashTable.remove(word);
      }

      _modified = true;
    }
  }

  /// Find all objects associated with a word.
  /// Returns a list of [obj, matchResult, obj, matchResult, ...].
  List<T3Value> findWord(T3VM vm, String word, int? propFilter) {
    final results = <T3Value>[];

    // Search all entries that might match
    for (final entry in _hashTable.values) {
      if (_matchStrings(vm, word, entry.word)) {
        for (final assoc in entry.entries) {
          // Filter by property if specified
          if (propFilter != null && assoc.propId != propFilter) {
            continue;
          }

          // Add object and match result (1 for exact match)
          results.add(T3Value()..setObj(assoc.objId));
          results.add(T3Value()..setInt(1));
        }
      }
    }

    return results;
  }

  /// Check if a word is defined.
  bool isWordDefined(T3VM vm, String word) {
    for (final entry in _hashTable.values) {
      if (_matchStrings(vm, word, entry.word) && entry.entries.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  // -------------------------------------------------------------------------
  // Spelling Correction
  // -------------------------------------------------------------------------

  /// Build the trie from the hash table.
  void _buildTrie() {
    if (_trie != null) return;

    _trie = _TrieNode(0);
    for (final word in _hashTable.keys) {
      _trie!.addWord(word);
    }
  }

  /// Get spelling corrections for a misspelled word.
  List<List<dynamic>> correct(String word, int maxDist) {
    _buildTrie();

    final results = <_CorrWord>[];
    final wordRunes = word.runes.toList();
    final stack = <_CorrState>[];

    // Initial state
    stack.add(_CorrState([], 0, 0, 0, _trie!, _CorrType.noChange));

    while (stack.isNotEmpty) {
      final s = stack.removeLast();

      // Check for accept state
      if (s.node.wordCount > 0 && s.ipos == wordRunes.length) {
        // Found a matching word
        final existing = results
            .where(
              (w) => w.str.length == s.str.length && _listEquals(w.str, s.str),
            )
            .firstOrNull;

        if (existing == null) {
          results.add(_CorrWord(List.from(s.str), s.dist, s.repl));
        } else if (s.dist < existing.dist ||
            (s.dist == existing.dist && s.repl < existing.repl)) {
          existing.dist = s.dist;
          existing.repl = s.repl;
        }
      }

      // Try insertion (skip input character)
      if (s.dist < maxDist &&
          s.ipos < wordRunes.length &&
          s.type != _CorrType.deletion) {
        stack.add(
          _CorrState(
            List.from(s.str),
            s.dist + 1,
            s.repl,
            s.ipos + 1,
            s.node,
            _CorrType.insertion,
          ),
        );
      }

      // Try each child transition
      for (final child in s.node.children) {
        final newStr = List<int>.from(s.str)..add(child.ch);

        // Check for match
        if (s.ipos < wordRunes.length) {
          if (wordRunes[s.ipos] == child.ch) {
            // Exact match
            stack.add(
              _CorrState(
                newStr,
                s.dist,
                s.repl,
                s.ipos + 1,
                child,
                _CorrType.noChange,
              ),
            );
          }

          // Try corrections if we have edit distance remaining
          if (s.dist < maxDist) {
            // Replacement
            if (wordRunes[s.ipos] != child.ch) {
              stack.add(
                _CorrState(
                  newStr,
                  s.dist + 1,
                  s.repl + 1,
                  s.ipos + 1,
                  child,
                  _CorrType.replacement,
                ),
              );
            }

            // Deletion (input missing a character)
            if (s.type != _CorrType.insertion) {
              stack.add(
                _CorrState(
                  newStr,
                  s.dist + 1,
                  s.repl,
                  s.ipos,
                  child,
                  _CorrType.deletion,
                ),
              );
            }
          }

          // Check for transposition
          if (s.type == _CorrType.replacement &&
              s.ipos > 0 &&
              s.ipos < wordRunes.length &&
              s.str.isNotEmpty &&
              wordRunes[s.ipos - 1] == child.ch &&
              wordRunes[s.ipos] == s.str.last) {
            stack.add(
              _CorrState(
                newStr,
                s.dist,
                s.repl - 1,
                s.ipos + 1,
                child,
                _CorrType.transposition,
              ),
            );
          }
        } else if (s.dist < maxDist && s.type != _CorrType.insertion) {
          // Past end of input - try deletion
          stack.add(
            _CorrState(
              newStr,
              s.dist + 1,
              s.repl,
              s.ipos,
              child,
              _CorrType.deletion,
            ),
          );
        }
      }
    }

    // Filter out exact matches (dist == 0) and format results
    return results
        .where((w) => w.dist > 0)
        .map((w) => [String.fromCharCodes(w.str), w.dist, w.repl])
        .toList();
  }

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // -------------------------------------------------------------------------
  // Property Evaluators
  // -------------------------------------------------------------------------

  bool _getpSetComparator(T3VM vm, int self, T3Value retval, int argc) {
    if (argc != 1) throw T3VmException(vmErrWrongNumOfArgs);

    final val = vm.stack.popVal();
    int comp;

    if (val.type == T3DataType.nil) {
      comp = invalidObj;
    } else if (val.type == T3DataType.obj) {
      comp = val.getAsObj() ?? invalidObj;
    } else {
      throw T3VmException(vmErrBadTypeBif);
    }

    _comparator = comp;
    _updateComparatorType(vm);
    _modified = true;

    retval.setNil();
    return true;
  }

  bool _getpFind(T3VM vm, T3Value retval, int argc) {
    if (argc < 1 || argc > 2) throw T3VmException(vmErrWrongNumOfArgs);

    // Get optional property filter
    int? propFilter;
    if (argc >= 2) {
      final propVal = vm.stack.popVal();
      if (propVal.type == T3DataType.nil) {
        propFilter = null;
      } else if (propVal.type == T3DataType.prop) {
        propFilter = propVal.getAsProp();
      } else {
        throw T3VmException(vmErrPropptrValReqd);
      }
    }

    // Get search string
    final strVal = vm.stack.popVal();
    final str = _getStringValue(vm, strVal);
    if (str == null) throw T3VmException(vmErrStringValReqd);

    // Find matches
    final results = findWord(vm, str, propFilter);

    // Create result list
    final list = T3ObjList(results);
    final listId = vm.objTable.registerObj(list, false);
    retval.setObj(listId);

    return true;
  }

  bool _getpAdd(T3VM vm, int self, T3Value retval, int argc) {
    if (argc != 3) throw T3VmException(vmErrWrongNumOfArgs);

    // Pop arguments: object, string, property
    final propVal = vm.stack.popVal();
    final strVal = vm.stack.popVal();
    final objVal = vm.stack.popVal();

    final propId = propVal.getAsProp();
    if (propId == null) throw T3VmException(vmErrPropptrValReqd);

    final objId = objVal.getAsObj();
    if (objId == null) throw T3VmException(vmErrObjValReqd);

    // Handle string or list of strings
    if (_isListLike(vm, strVal)) {
      final length = _getListLength(vm, strVal);
      for (var i = 1; i <= length; i++) {
        final eleVal = _getListElement(vm, strVal, i);
        final str = _getStringValue(vm, eleVal);
        if (str == null) throw T3VmException(vmErrStringValReqd);
        addWord(vm, self, str, objId, propId);
      }
    } else {
      final str = _getStringValue(vm, strVal);
      if (str == null) throw T3VmException(vmErrStringValReqd);
      addWord(vm, self, str, objId, propId);
    }

    retval.setNil();
    return true;
  }

  bool _getpDel(T3VM vm, int self, T3Value retval, int argc) {
    if (argc != 3) throw T3VmException(vmErrWrongNumOfArgs);

    // Pop arguments: object, string, property
    final propVal = vm.stack.popVal();
    final strVal = vm.stack.popVal();
    final objVal = vm.stack.popVal();

    final propId = propVal.getAsProp();
    if (propId == null) throw T3VmException(vmErrPropptrValReqd);

    final objId = objVal.getAsObj();
    if (objId == null) throw T3VmException(vmErrObjValReqd);

    // Handle string or list of strings
    if (_isListLike(vm, strVal)) {
      final length = _getListLength(vm, strVal);
      for (var i = 1; i <= length; i++) {
        final eleVal = _getListElement(vm, strVal, i);
        final str = _getStringValue(vm, eleVal);
        if (str == null) throw T3VmException(vmErrStringValReqd);
        delWord(vm, self, str, objId, propId);
      }
    } else {
      final str = _getStringValue(vm, strVal);
      if (str == null) throw T3VmException(vmErrStringValReqd);
      delWord(vm, self, str, objId, propId);
    }

    retval.setNil();
    return true;
  }

  bool _getpIsDefined(T3VM vm, T3Value retval, int argc) {
    if (argc < 1 || argc > 2) throw T3VmException(vmErrWrongNumOfArgs);

    // Get optional filter function (ignored for now)
    if (argc >= 2) {
      vm.stack.popVal(); // filter function
    }

    // Get search string
    final strVal = vm.stack.popVal();
    final str = _getStringValue(vm, strVal);
    if (str == null) throw T3VmException(vmErrStringValReqd);

    retval.setLogical(isWordDefined(vm, str));
    return true;
  }

  bool _getpForEachWord(T3VM vm, int self, T3Value retval, int argc) {
    if (argc != 1) throw T3VmException(vmErrWrongNumOfArgs);

    final callback = vm.stack.popVal();

    // Iterate all word associations
    for (final entry in _hashTable.values) {
      for (final assoc in entry.entries) {
        // Create string object for the word
        final strObj = T3ObjString(entry.word);
        final strId = vm.objTable.registerObj(strObj, false);

        // Push arguments: obj, str, prop
        vm.stack.pushVal(T3Value()..setPropId(assoc.propId));
        vm.stack.pushVal(T3Value()..setObj(strId));
        vm.stack.pushVal(T3Value()..setObj(assoc.objId));

        // Call the callback
        vm.interpreter.callFuncPtr(callback, 3);
      }
    }

    retval.setNil();
    return true;
  }

  bool _getpCorrect(T3VM vm, T3Value retval, int argc) {
    if (argc != 2) throw T3VmException(vmErrWrongNumOfArgs);

    // Pop arguments: string, maxDist
    final maxDistVal = vm.stack.popVal();
    final strVal = vm.stack.popVal();

    final maxDist = maxDistVal.getAsInt();
    final str = _getStringValue(vm, strVal);
    if (str == null) throw T3VmException(vmErrStringValReqd);

    // Get corrections
    final corrections = correct(str, maxDist);

    // Build result list
    final resultItems = <T3Value>[];
    for (final corr in corrections) {
      // Create sublist [word, dist, repl]
      final subItems = <T3Value>[
        T3Value()..setObj(
          vm.objTable.registerObj(T3ObjString(corr[0] as String), false),
        ),
        T3Value()..setInt(corr[1] as int),
        T3Value()..setInt(corr[2] as int),
      ];
      final subList = T3ObjList(subItems);
      resultItems.add(
        T3Value()..setObj(vm.objTable.registerObj(subList, false)),
      );
    }

    final list = T3ObjList(resultItems);
    retval.setObj(vm.objTable.registerObj(list, false));
    return true;
  }

  // -------------------------------------------------------------------------
  // Helper Methods
  // -------------------------------------------------------------------------

  /// Get string value from a T3Value.
  String? _getStringValue(T3VM vm, T3Value val) {
    if (val.type == T3DataType.sstring) {
      // Constant string - get from constant pool
      final offset = val.getAsSstring();
      if (offset == null) return null;
      return vm.constPool.getString(offset);
    } else if (val.type == T3DataType.obj) {
      final objId = val.getAsObj();
      if (objId == null) return null;
      final obj = vm.objTable.getObj(objId);
      if (obj is T3ObjString) {
        return obj.value;
      }
    }
    return null;
  }

  /// Check if a value is list-like.
  bool _isListLike(T3VM vm, T3Value val) {
    if (val.type == T3DataType.list) return true;
    if (val.type == T3DataType.obj) {
      final objId = val.getAsObj();
      if (objId == null) return false;
      final obj = vm.objTable.getObj(objId);
      return obj?.isListlike(vm, objId) ?? false;
    }
    return false;
  }

  /// Get length of a list-like value.
  int _getListLength(T3VM vm, T3Value val) {
    if (val.type == T3DataType.list) {
      // TODO: Parse list constant
      return 0;
    }
    if (val.type == T3DataType.obj) {
      final objId = val.getAsObj();
      if (objId == null) return 0;
      final obj = vm.objTable.getObj(objId);
      return obj?.llLength(vm, objId) ?? 0;
    }
    return 0;
  }

  /// Get element from a list-like value.
  T3Value _getListElement(T3VM vm, T3Value val, int index) {
    if (val.type == T3DataType.obj) {
      final objId = val.getAsObj();
      if (objId == null) return T3Value()..setNil();
      final obj = vm.objTable.getObj(objId);
      if (obj != null) {
        final result = T3Value();
        if (obj.indexValQ(vm, result, objId, T3Value()..setInt(index))) {
          return result;
        }
      }
    }
    return T3Value()..setNil();
  }
}

/// Dictionary metaclass registration.
class T3MetaclassDict extends T3Metaclass {
  static const String name = 'dictionary2/030001';

  @override
  String getMetaName() => name;

  @override
  int createFromStack(T3VM vm, Uint8List pc, int pcOffset, int argc) {
    return T3ObjDict.createFromStack(vm, argc);
  }

  @override
  void createForImageLoad(T3VM vm, int id) {
    vm.objTable.setObj(id, T3ObjDict());
  }

  @override
  void createForRestore(T3VM vm, int id) {
    vm.objTable.setObj(id, T3ObjDict());
  }

  @override
  bool callStatProp(
    T3VM vm,
    T3Value result,
    Uint8List pc,
    int pcOffset,
    int argc,
    int prop,
  ) => false;

  @override
  int getSupermeta(T3VM vm, int idx) => invalidObj;

  @override
  bool isMetaInstanceOf(T3VM vm, int obj) => false;

  @override
  T3Metaclass? getSupermetaReg() => null;

  @override
  int getClassObj(T3VM vm) => invalidObj;
}
