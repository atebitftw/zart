import 'dart:math' as math;
import 'dart:typed_data';

/// xoshiro128** random number generator implementation.
/// Reference: osdepend.c - "xoshiro128**" random-number generator
/// Adapted from: https://prng.di.unimi.it/xoshiro128starstar.c
///
/// Spec Section 2.4.9: The Glulx spec requires deterministic random number
/// sequences when seeded with a non-zero value.
class Xoshiro128 {
  /// RNG state (4 x 32-bit values)
  /// Reference: osdepend.c xo_table
  final Uint32List _table = Uint32List(4);

  /// Whether to use native (non-deterministic) random
  /// Reference: osdepend.c rand_use_native
  bool _useNative = true;

  /// Native Dart Random for non-deterministic mode
  final math.Random _nativeRandom = math.Random();

  /// Seeds the random number generator.
  /// Reference: osdepend.c glulx_setrandom()
  ///
  /// If [seed] is 0, switches to non-deterministic mode.
  /// If [seed] is non-zero, seeds the xoshiro128** generator.
  void seed(int seed) {
    if (seed == 0) {
      _useNative = true;
    } else {
      _useNative = false;
      _seedRandom(seed);
    }
  }

  /// Returns a random 32-bit unsigned integer.
  /// Reference: osdepend.c glulx_random()
  int nextInt() {
    if (_useNative) {
      // Non-deterministic: use Dart's Random
      int result = _nativeRandom.nextInt(0x80000000);
      if (_nativeRandom.nextBool()) result |= 0x80000000;
      return result;
    } else {
      // Deterministic: use xoshiro128**
      return _random();
    }
  }

  /// SplitMix32 expansion from single seed to 128-bit state.
  /// Reference: osdepend.c xo_seed_random()
  void _seedRandom(int seed) {
    for (int ix = 0; ix < 4; ix++) {
      seed = (seed + 0x9E3779B9) & 0xFFFFFFFF;
      int s = seed;
      s ^= s >> 15;
      s = (s * 0x85EBCA6B) & 0xFFFFFFFF;
      s ^= s >> 13;
      s = (s * 0xC2B2AE35) & 0xFFFFFFFF;
      s ^= s >> 16;
      _table[ix] = s;
    }
  }

  /// xoshiro128** random number generator.
  /// Reference: osdepend.c xo_random()
  int _random() {
    // rotl(x, k) => (x << k) | (x >> (32 - k))
    final t1x5 = (_table[1] * 5) & 0xFFFFFFFF;
    final result =
        ((((t1x5 << 7) | (t1x5 >> 25)) & 0xFFFFFFFF) * 9) & 0xFFFFFFFF;

    final t1s9 = (_table[1] << 9) & 0xFFFFFFFF;

    _table[2] ^= _table[0];
    _table[3] ^= _table[1];
    _table[1] ^= _table[2];
    _table[0] ^= _table[3];

    _table[2] ^= t1s9;

    final t3 = _table[3];
    _table[3] = ((t3 << 11) | (t3 >> 21)) & 0xFFFFFFFF;

    return result;
  }
}
