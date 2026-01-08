import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_grammar_production.dart';

void main() {
  group('T3GrammarProduction', () {
    test('Creation', () {
      final gram = T3GrammarProduction.create(10);
      expect(gram.objectId, 10);
      expect(gram.metaclass, 'grammar-production');
      expect(gram.alternatives, isEmpty);
    });

    test('addAlt and clearAlts', () {
      final gram = T3GrammarProduction.create(10);
      final alt1 = T3GrammarAlt(score: 100, badness: 5, processorObjId: 99, tokens: []);
      gram.addAlt(alt1);
      expect(gram.alternatives.length, 1);
      expect(gram.alternatives[0].score, 100);

      gram.clearAlts();
      expect(gram.alternatives, isEmpty);
    });

    test('Serialization and Restoration', () {
      final gram = T3GrammarProduction.create(20);

      // Alt 1: Literal and Prod tokens
      final tokens1 = [
        T3GrammarToken(propId: 1, matchType: T3GrammarMatchType.literal, extra: 'test'),
        T3GrammarToken(
          propId: 2,
          matchType: T3GrammarMatchType.prod,
          extra: 50, // production ID
        ),
      ];
      final alt1 = T3GrammarAlt(score: 10, badness: 2, processorObjId: 30, tokens: tokens1);
      gram.addAlt(alt1);

      // Alt 2: Speech, TokType, NSpeech
      final tokens2 = [
        T3GrammarToken(
          propId: 3,
          matchType: T3GrammarMatchType.speech,
          extra: 200, // prop ID
        ),
        T3GrammarToken(
          propId: 4,
          matchType: T3GrammarMatchType.tokType,
          extra: 5, // enum ID
        ),
        T3GrammarToken(
          propId: 5,
          matchType: T3GrammarMatchType.nSpeech,
          extra: [300, 301], // prop IDs
        ),
      ];
      final alt2 = T3GrammarAlt(score: 20, badness: 0, processorObjId: 40, tokens: tokens2);
      gram.addAlt(alt2);

      final data = gram.save();

      // Restore
      final restored = T3GrammarProduction.fromData(20, data);
      expect(restored.objectId, 20);
      expect(restored.alternatives.length, 2);

      // Verify Alt 1
      final rAlt1 = restored.alternatives[0];
      expect(rAlt1.score, 10);
      expect(rAlt1.badness, 2);
      expect(rAlt1.processorObjId, 30);
      expect(rAlt1.tokens.length, 2);

      expect(rAlt1.tokens[0].matchType, T3GrammarMatchType.literal);
      expect(rAlt1.tokens[0].extra, 'test');

      expect(rAlt1.tokens[1].matchType, T3GrammarMatchType.prod);
      expect(rAlt1.tokens[1].extra, 50);

      // Verify Alt 2
      final rAlt2 = restored.alternatives[1];
      expect(rAlt2.score, 20);
      expect(rAlt2.tokens.length, 3);

      expect(rAlt2.tokens[0].matchType, T3GrammarMatchType.speech);
      expect(rAlt2.tokens[0].extra, 200);

      expect(rAlt2.tokens[1].matchType, T3GrammarMatchType.tokType);
      expect(rAlt2.tokens[1].extra, 5); // Assuming 5 is preserved

      expect(rAlt2.tokens[2].matchType, T3GrammarMatchType.nSpeech);
      expect(rAlt2.tokens[2].extra, [300, 301]);
    });
  });
}
