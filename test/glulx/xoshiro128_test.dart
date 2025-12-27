import 'package:test/test.dart';
import 'package:zart/src/glulx/xoshiro128.dart';

/// Unit tests for Xoshiro128 random number generator.
/// These tests verify deterministic seeding produces reproducible sequences.
void main() {
  group('Xoshiro128', () {
    test('seeding produces deterministic sequence', () {
      // Spec Section 2.4.9: "setrandom L1: Seed the random-number generator."
      // When seeded with non-zero value, should produce deterministic sequence.
      final rng1 = Xoshiro128();
      final rng2 = Xoshiro128();

      rng1.seed(1);
      rng2.seed(1);

      // Both instances seeded with same value should produce same sequence
      for (var i = 0; i < 100; i++) {
        expect(
          rng1.nextInt(),
          equals(rng2.nextInt()),
          reason: 'Same seed should produce same sequence at index $i',
        );
      }
    });

    test('reseeding resets sequence', () {
      // Spec Section 2.4.9: Each setrandom should reset the generator state.
      final rng = Xoshiro128();

      // Get first few values with seed 1
      rng.seed(1);
      final firstValues = <int>[];
      for (var i = 0; i < 10; i++) {
        firstValues.add(rng.nextInt());
      }

      // Generate some more values to advance state
      for (var i = 0; i < 50; i++) {
        rng.nextInt();
      }

      // Reseed with 1 - should get same first values
      rng.seed(1);
      for (var i = 0; i < 10; i++) {
        expect(
          rng.nextInt(),
          equals(firstValues[i]),
          reason: 'Reseeding should produce same sequence at index $i',
        );
      }
    });

    test('different seeds produce different sequences', () {
      // Verify that different seeds produce different sequences.
      final rng1 = Xoshiro128();
      final rng100 = Xoshiro128();

      rng1.seed(1);
      rng100.seed(100);

      // At least the first value should differ
      expect(
        rng1.nextInt(),
        isNot(equals(rng100.nextInt())),
        reason: 'Different seeds should produce different first values',
      );
    });

    test('seed 0 switches to non-deterministic mode', () {
      // Spec Section 2.4.9: "If the argument is zero, the generator is
      // seeded with a truly random source if possible."
      final rng = Xoshiro128();

      // Seed with 0 to switch to non-deterministic mode
      rng.seed(0);

      // Values should still be in valid range (0 to 0xFFFFFFFF)
      final value = rng.nextInt();
      expect(value, isA<int>());
      expect(value, greaterThanOrEqualTo(0));
      expect(value, lessThanOrEqualTo(0xFFFFFFFF));
    });

    test('values are in valid 32-bit unsigned range', () {
      final rng = Xoshiro128();
      rng.seed(42);

      for (var i = 0; i < 1000; i++) {
        final value = rng.nextInt();
        expect(
          value,
          greaterThanOrEqualTo(0),
          reason: 'Value should be non-negative',
        );
        expect(
          value,
          lessThanOrEqualTo(0xFFFFFFFF),
          reason: 'Value should fit in 32 bits',
        );
      }
    });

    test('produces variety of values', () {
      // Verify the generator doesn't get stuck or produce only a few values
      final rng = Xoshiro128();
      rng.seed(12345);

      final values = <int>{};
      for (var i = 0; i < 1000; i++) {
        values.add(rng.nextInt());
      }

      // Should have a high variety of unique values (at least 990 out of 1000)
      expect(
        values.length,
        greaterThan(990),
        reason: 'Should produce highly varied values',
      );
    });
  });
}
