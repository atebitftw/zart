import 'dart:convert';
import 'dart:typed_data';

import 'package:zart/src/tads3/vm/t3_dict.dart';
import 'package:zart/src/tads3/vm/t3_error.dart';
import 'package:zart/src/tads3/vm/t3_list.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_type.dart';
import 'package:zart/src/tads3/vm/t3_globals.dart';
import 'package:zart/src/tads3/vm/t3_tads_object.dart';

// Match types
enum VmGramMatchType {
  undef(0),
  prod(1),
  speech(2),
  literal(3),
  tokType(4),
  star(5),
  nSpeech(6);

  final int value;
  const VmGramMatchType(this.value);

  static VmGramMatchType fromInt(int val) {
    for (var type in VmGramMatchType.values) {
      if (type.value == val) return type;
    }
    return undef;
  }
}

class GrammarProdToken {
  int prop = 0; // T3PropertyId
  VmGramMatchType type = VmGramMatchType.undef;

  // Extra data depending on type
  int prodObjId = 0; // For prod
  int speechProp = 0; // For speech
  List<int> nSpeechProps = []; // For nSpeech
  String? literalStr; // For literal
  int literalLen = 0; // For literal
  int literalHash = 0; // For literal
  int tokTypeEnum = 0; // For tokType

  GrammarProdToken();
}

class GrammarProdMatch {
  int inputStart = 0;
  int inputEnd = 0;
  T3Value? val; // The match result value (usually a parse tree node)

  GrammarProdMatch(this.inputStart, this.inputEnd, this.val);
}

class GrammarProdAlt {
  int score = 0;
  int badness = 0;
  int procObj = 0; // T3ObjectId
  List<GrammarProdToken> toks = [];

  GrammarProdAlt();
}

class GrammarProdState {
  GrammarProdState? next; // Next in queue
  GrammarProdState? enclosingState; // The state that spawned this sub-production
  GrammarProdAlt? alt;
  int curTokIdx = 0; // Current index in alt.toks
  int inputStart = 0; // Start index in input token list
  int inputLen = 0; // Length of input consumed so far
  List<GrammarProdMatch> matches = []; // Matches for all tokens (literals are null val)

  GrammarProdState({this.alt, this.curTokIdx = 0, this.inputStart = 0, this.inputLen = 0, this.enclosingState});

  GrammarProdState clone() {
    var s = GrammarProdState(
      alt: alt,
      curTokIdx: curTokIdx,
      inputStart: inputStart,
      inputLen: inputLen,
      enclosingState: enclosingState,
    );
    s.matches = List.from(matches);
    return s;
  }
}

class GrammarProdQueue {
  GrammarProdState? workQueue;
  GrammarProdState? unknownWordQueue;
  GrammarProdState? badnessQueue;
  List<T3Value> successList = [];
}

class GrammarProdReader {
  final Uint8List _data;
  int _offset = 0;

  GrammarProdReader(Uint8List data) : _data = data;

  int readUInt1() {
    return _data[_offset++];
  }

  int readUInt2() {
    final val = _data[_offset] | (_data[_offset + 1] << 8);
    _offset += 2;
    return val;
  }

  int readInt2() {
    var val = readUInt2();
    if (val >= 0x8000) val -= 0x10000;
    return val;
  }

  int readUInt4() {
    final val = _data[_offset] | (_data[_offset + 1] << 8) | (_data[_offset + 2] << 16) | (_data[_offset + 3] << 24);
    _offset += 4;
    return val;
  }

  Uint8List readBytes(int count) {
    final start = _offset;
    _offset += count;
    return _data.sublist(start, _offset);
  }
}

class T3GrammarProd extends T3Object {
  final int id; // Needed for self-reference in circularity checks

  List<GrammarProdAlt> alts = [];

  // Image data for reset
  Uint8List? _imageData;

  bool _modified = false;

  // ignore: unused_field
  int _comparatorId = invalidObj;
  // ignore: unused_field
  bool _hasCircularAlt = false;

  T3GrammarProd(T3VM vm, this.id) {
    if (vm.objTable != null) {
      // Register if table exists (for dynamic creation)
    }
  }

  static const String metaNameString = 'grammar-production/030002';

  @override
  T3Metaclass getMetaclassReg() => T3MetaclassGrammarProd.instance;

  @override
  void loadFromImage(T3VM vm, int self, Uint8List ptr, int offset, int size) {
    _imageData = ptr.sublist(offset, offset + size);
    var reader = GrammarProdReader(_imageData!);
    _loadAlts(reader);
    _modified = false;
  }

  @override
  void resetToImage(T3VM vm, int self) {
    if (_modified && _imageData != null) {
      var reader = GrammarProdReader(_imageData!);
      _loadAlts(reader);
      _modified = false;
      _comparatorId = invalidObj;
    }
  }

  @override
  void saveToFile(T3VM vm, T3File fp) {
    if (_modified) {
      // Only save if dynamically modified.
    }
  }

  void _loadAlts(GrammarProdReader reader) {
    alts.clear();
    _hasCircularAlt = false;

    int altCnt = reader.readUInt2();
    for (int i = 0; i < altCnt; i++) {
      var alt = GrammarProdAlt();
      alt.score = reader.readInt2();
      alt.badness = reader.readInt2();
      alt.procObj = reader.readUInt4();
      int tokCnt = reader.readUInt2();

      for (int j = 0; j < tokCnt; j++) {
        var tok = GrammarProdToken();
        tok.prop = reader.readUInt2();
        tok.type = VmGramMatchType.fromInt(reader.readUInt1());

        switch (tok.type) {
          case VmGramMatchType.prod:
            tok.prodObjId = reader.readUInt4();
            break;
          case VmGramMatchType.speech:
            tok.speechProp = reader.readUInt2();
            break;
          case VmGramMatchType.nSpeech:
            int cnt = reader.readUInt2();
            tok.nSpeechProps = List.generate(cnt, (_) => reader.readUInt2());
            break;
          case VmGramMatchType.literal:
            tok.literalLen = reader.readUInt2();
            List<int> bytes = reader.readBytes(tok.literalLen);
            tok.literalStr = utf8.decode(bytes, allowMalformed: true);
            break;
          case VmGramMatchType.tokType:
            tok.tokTypeEnum = reader.readUInt4();
            break;
          case VmGramMatchType.star:
            break;
          default:
            break;
        }
        alt.toks.add(tok);
      }

      if (alt.toks.isNotEmpty && alt.toks[0].type == VmGramMatchType.prod && alt.toks[0].prodObjId == id) {
        _hasCircularAlt = true;
      }

      alts.add(alt);
    }
  }

  @override
  bool getProp(T3VM vm, int propId, T3Value retval, int self, List<int> sourceObj, int? argc) {
    sourceObj[0] = self;
    switch (propId) {
      case 1: // VMOBJGRAM_PARSE
        return _getPropParse(vm, retval, self, argc);
      default:
        return false;
    }
  }

  bool _getPropParse(T3VM vm, T3Value retval, int self, int? argc) {
    if (argc == null || argc < 1 || argc > 2) {
      throw T3VmException(vmErrWrongNumOfArgs);
    }

    var tokListVal = vm.stack!.popVal();

    // To properly support generic lists, we should use T3Collection or similar
    List<T3Value> tokens = [];
    var list = getListElements((vm as T3Globals), tokListVal);
    if (list != null) {
      tokens = list;
    }

    // Dictionary argument
    T3ObjDict? dict;
    if (argc == 2) {
      var dictVal = vm.stack!.popVal();
      if (dictVal.type != T3DataType.nil && dictVal.type == T3DataType.obj) {
        var objEntry = vm.objTable!.getEntry(dictVal.getAsObj()!);
        if (objEntry?.obj is T3ObjDict) {
          dict = objEntry!.obj as T3ObjDict;
        }
      }
    }

    // Perform parsing
    var matches = _parseTokens(vm, tokens, dict);

    // Create new T3List with results
    var listObj = T3ObjList(matches);
    int listId = vm.objTable!.registerObj(listObj);
    retval.setObj(listId);

    return true;
  }

  List<T3Value> _parseTokens(T3VM vm, List<T3Value> tokens, T3ObjDict? dict) {
    var queues = GrammarProdQueue();
    _enqueueAlts(vm, tokens, 0, null, queues, id, false, null, dict);
    _processWorkQueue(vm, tokens, queues, dict);
    return queues.successList;
  }

  void _enqueueAlts(
    T3VM vm,
    List<T3Value> inputTokens,
    int startTokPos,
    GrammarProdState? enclosingState,
    GrammarProdQueue queues,
    int self,
    bool circOnly,
    GrammarProdMatch? circMatch,
    T3ObjDict? dict,
  ) {
    for (var alt in alts) {
      bool isCirc = alt.toks.isNotEmpty && alt.toks[0].type == VmGramMatchType.prod && alt.toks[0].prodObjId == self;

      if (circOnly && !isCirc) continue;

      var state = GrammarProdState(
        alt: alt,
        curTokIdx: 0,
        inputStart: startTokPos,
        inputLen: 0,
        enclosingState: enclosingState,
      );

      if (isCirc && circMatch != null) {
        state.curTokIdx++;
        state.inputLen += circMatch.inputEnd - circMatch.inputStart;
        state.matches.add(circMatch);
      }

      state.next = queues.workQueue;
      queues.workQueue = state;
    }
  }

  void _processWorkQueue(T3VM vm, List<T3Value> inputTokens, GrammarProdQueue queues, T3ObjDict? dict) {
    while (true) {
      if (queues.workQueue == null) break;

      var state = queues.workQueue!;
      queues.workQueue = state.next;

      _processState(vm, state, inputTokens, queues, dict);
    }
  }

  void _processState(
    T3VM vm,
    GrammarProdState state,
    List<T3Value> inputTokens,
    GrammarProdQueue queues,
    T3ObjDict? dict,
  ) {
    if (state.alt == null) return;
    if (state.curTokIdx >= state.alt!.toks.length) {
      if (state.enclosingState != null) {
        var val = _buildMatchTree(vm, state);
        var match = GrammarProdMatch(state.inputStart, state.inputStart + state.inputLen, val);

        var newState = state.enclosingState!.clone();
        newState.curTokIdx++;
        newState.inputLen += state.inputLen;
        newState.matches.add(match);

        newState.next = queues.workQueue;
        queues.workQueue = newState;
      } else {
        var val = _buildMatchTree(vm, state);
        if (val != null) {
          queues.successList.add(val);
        }
      }
      return;
    }

    var tok = state.alt!.toks[state.curTokIdx];
    int currentInputPos = state.inputStart + state.inputLen;
    bool endOfInput = currentInputPos >= inputTokens.length;

    switch (tok.type) {
      case VmGramMatchType.literal:
        if (endOfInput) break;
        _matchLiteral(vm, state, inputTokens[currentInputPos], tok, queues, dict);
        break;

      case VmGramMatchType.prod:
        var targetProdFn = vm.objTable.getEntry(tok.prodObjId);
        if (targetProdFn != null && targetProdFn.obj is T3GrammarProd) {
          var targetProd = targetProdFn.obj as T3GrammarProd;
          targetProd._enqueueAlts(vm, inputTokens, currentInputPos, state, queues, tok.prodObjId, false, null, dict);
        }
        break;

      case VmGramMatchType.tokType:
        if (endOfInput) break;
        _matchTokType(vm, state, inputTokens[currentInputPos], tok, queues);
        break;

      case VmGramMatchType.speech:
        if (endOfInput) break;
        if (dict != null) {
          _matchSpeech(vm, state, inputTokens[currentInputPos], tok, queues, dict);
        }
        break;

      default:
        break;
    }
  }

  void _matchTokType(T3VM vm, GrammarProdState state, T3Value inputTok, GrammarProdToken tok, GrammarProdQueue queues) {
    // Stub for token type matching
  }

  void _matchLiteral(
    T3VM vm,
    GrammarProdState state,
    T3Value inputTok,
    GrammarProdToken tok,
    GrammarProdQueue queues,
    T3ObjDict? dict,
  ) {
    String? valStr = _getTokenString(vm, inputTok);
    bool matched = false;

    if (valStr != null && tok.literalStr != null) {
      if (valStr == tok.literalStr) {
        // Simple exact match for now
        matched = true;
      }
    }

    if (matched) {
      var newState = state.clone();
      newState.curTokIdx++;
      newState.inputLen++;
      // Match literal
      newState.matches.add(
        GrammarProdMatch(state.inputStart + state.inputLen, state.inputStart + state.inputLen + 1, null),
      );

      newState.next = queues.workQueue;
      queues.workQueue = newState;
    }
  }

  void _matchSpeech(
    T3VM vm,
    GrammarProdState state,
    T3Value inputTok,
    GrammarProdToken tok,
    GrammarProdQueue queues,
    T3ObjDict dict,
  ) {
    String? valStr = _getTokenString(vm, inputTok);
    if (valStr != null) {
      var findings = dict.findWord(vm, valStr, tok.speechProp);
      for (int i = 0; i < findings.length; i += 2) {
        var vocabObj = findings[i];

        var newState = state.clone();
        newState.curTokIdx++;
        newState.inputLen++;

        var matchVal = T3Value.copy(vocabObj);
        newState.matches.add(
          GrammarProdMatch(state.inputStart + state.inputLen, state.inputStart + state.inputLen + 1, matchVal),
        );

        newState.next = queues.workQueue;
        queues.workQueue = newState;
      }
    }
  }

  T3Value? _buildMatchTree(T3VM vm, GrammarProdState state) {
    if (state.alt != null && state.alt!.procObj != invalidObj) {
      // Using T3TadsObject default constructor and initialization
      int newId = vm.objTable.allocObj(vm, false);
      var newObj = T3TadsObject();
      newObj.initHeader(propCount: state.matches.length);

      vm.objTable.registerObj(newObj, id: newId);

      if (state.matches.length == state.alt!.toks.length) {
        for (int i = 0; i < state.matches.length; i++) {
          var m = state.matches[i];
          var t = state.alt!.toks[i];
          if (t.prop != 0 && m.val != null) {
            newObj.setProp(vm, null, newId, t.prop, m.val!);
          }
        }
      }

      var res = T3Value();
      res.setObj(newId);
      return res;
    }
    return null;
  }

  String? _getTokenString(T3VM vm, T3Value tok) {
    if (tok.type == T3DataType.sstring) {
      var globals = vm as T3Globals;
      if (globals.constPool != null) {
        // return globals.constPool.getString(tok.getAsOfs());
        return "stub_token_string";
      }
    }
    return null;
  }

  // Other method stubs
  @override
  void notifyDelete(T3VM vm, bool inRootSet) {}
  @override
  void markRefs(T3VM vm, int state) {}
  @override
  void applyUndo(T3VM vm, T3UndoRecord rec) {}
  @override
  void markUndoRef(T3VM vm, T3UndoRecord rec) {}
  @override
  void removeStaleUndoWeakRef(T3VM vm, T3UndoRecord rec) {}
  @override
  void restoreFromFile(T3VM vm, int self, T3File fp, T3ObjFixup fixups) {}
  @override
  void buildPropList(T3VM vm, int self, T3Value retval) {
    retval.setNil();
  }

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
  ) => false;
  @override
  String? castToString(T3VM vm, int self, T3Value newStr) => null;
  @override
  int getSuperclass(T3VM vm, int self, int index) => invalidObj;
  @override
  bool isInstanceOf(T3VM vm, int obj) => false;
  @override
  void setProp(T3VM vm, T3Undo? undo, int self, int propId, T3Value val) {
    throw T3VmException(vmErrInvalidSetprop);
  }
}

class T3MetaclassGrammarProd extends T3Metaclass {
  static final instance = T3MetaclassGrammarProd();

  @override
  String getMetaName() => T3GrammarProd.metaNameString;

  @override
  int createFromStack(T3VM vm, Uint8List pc, int pcOffset, int argc) {
    int id = vm.objTable.allocObj(vm, true);
    var obj = T3GrammarProd(vm, id);
    vm.objTable.registerObj(obj, id: id);
    obj._modified = true;
    if (argc > 0) {
      throw T3VmException(vmErrWrongNumOfArgs);
    }
    return id;
  }

  @override
  void createForImageLoad(T3VM vm, int id) {
    vm.objTable.registerObj(T3GrammarProd(vm, id), id: id);
  }

  @override
  void createForRestore(T3VM vm, int id) {
    vm.objTable.registerObj(T3GrammarProd(vm, id), id: id);
  }

  @override
  bool callStatProp(T3VM vm, T3Value result, Uint8List pc, int pcOffset, int argc, int prop) {
    return false;
  }

  @override
  int getSupermeta(T3VM vm, int idx) => invalidObj;

  @override
  bool isMetaInstanceOf(T3VM vm, int obj) => false;

  @override
  T3Metaclass? getSupermetaReg() => null;

  @override
  int getClassObj(T3VM vm) => invalidObj;
}
