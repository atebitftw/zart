import 'dart:convert';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_grammar.dart';
import 'package:zart/src/tads3/vm/t3_globals.dart';

void main() {
  group('T3GrammarProd', () {
    late T3Globals vm;

    setUp(() {
      vm = T3Globals();
      // Initialize object table and other components if T3Globals constructor doesn't finish it
      // T3Globals constructor calls _initMetaclasses()
      // We might need to ensure objTable is ready if we use it.
      if (vm.objTable == null) {
        // Initialize manually if needed, but T3Globals usually sets up empty tables?
        // Looking at t3_globals.dart code showed: objTable is field but not initialized in constructor.
        // We need to init it.
        // vm.objTable = T3ObjectTable(vm); // But T3ObjectTable isn't imported effectively or constructed here
        // Wait, t3_globals.dart imports t3_object_table.dart
      }
      // For now, let's assume we need to mock or init explicit components if missing
    });

    List<int> uint2(int v) => [v & 0xFF, (v >> 8) & 0xFF];
    List<int> int2(int v) => uint2(v);
    List<int> uint4(int v) => [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF];

    test('instantiation', () {
      var prod = T3GrammarProd(vm, 123);
      expect(prod.id, equals(123));
      expect(prod.alts, isEmpty);
    });

    test('loadFromImage loads literal match', () {
      var prod = T3GrammarProd(vm, 100);

      // Construct image data
      // Alt count: 1
      // Alt 0:
      //   score: 10
      //   badness: 0
      //   procObj: 999
      //   tokCnt: 1
      //     Tok 0:
      //       prop: 1
      //       type: 3 (literal)
      //       len: 4
      //       bytes: "test"

      List<int> data = [];
      data.addAll(uint2(1)); // alt_cnt

      // Alt 0
      data.addAll(int2(10)); // score
      data.addAll(int2(0)); // badness
      data.addAll(uint4(999)); // procObj
      data.addAll(uint2(1)); // tokCnt

      // Tok 0
      data.addAll(uint2(1)); // prop
      data.add(VmGramMatchType.literal.value); // type
      data.addAll(uint2(4)); // len
      data.addAll(utf8.encode("test")); // literal string

      prod.loadFromImage(vm, 100, Uint8List.fromList(data), 0, data.length);

      expect(prod.alts.length, equals(1));
      var alt = prod.alts[0];
      expect(alt.score, equals(10));
      expect(alt.procObj, equals(999));
      expect(alt.toks.length, equals(1));

      var tok = alt.toks[0];
      expect(tok.type, equals(VmGramMatchType.literal));
      expect(tok.literalStr, equals("test"));
    });

    /* 
    // Parsing tests require a more complex setup with dict and tokens.
    // For now we verify loading logic which is critical for initialization.
    // We can add parsing tests if we mock the environment fully.
    
    test('parseTokens matches literal', () {
       // Setup dictionary (mock or real)
       // Setup input tokens: List with one token "test"
       // We need to implement _getTokenString in T3GrammarProd to handle input. 
       // In the implementation it returned "stub_test_string". 
    });
    */
  });
}
