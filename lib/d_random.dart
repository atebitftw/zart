// DRandom.dart
//
// Authors:
// Adam Singer (financeCoding@gmail.com)
// (C) 2012 Adam Singer. http://goo.gl/qouCM
//
// System.Random.cs
//
// Authors:
//   Bob Smith (bob@thestuff.net)
//   Ben Maurer (bmaurer@users.sourceforge.net)
//
// (C) 2001 Bob Smith.  http://www.thestuff.net
// (C) 2003 Ben Maurer
//
//
// Copyright (C) 2004 Novell, Inc (http://www.novell.com)
//
// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
// LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import 'dart:math' as math;

const int intMax = 2147483647;
const int intMin = -2147483648;

const int mSeed = 161803398;

/// Suppliment pseudorandom random number generator for dart based on
/// similar implementations in mono C#
class DRandom {
  late int mBig;

  late int inext;
  late int inextp;

  late List<int> seedArray;

  DRandom.withSeed(int seed) {
    _init();
    _seed(seed);
  }

  /// Create [DRandom]
  DRandom() {
    _init();
    int i = math.Random().nextInt((1 << 32) - 1);
    int seed = (i * mBig).floor().toInt();
    _seed(seed);
  }

  void _seed(int seed) {
    int ii;
    int? mj;
    int mk;

    if (seed == intMin) {
      mj = mSeed - (intMax + 1).abs();
    } else {
      mj = mSeed - seed.abs();
    }

    seedArray[55] = mj;
    mk = 1;
    for (int i = 1; i < 55; i++) {
      ii = (21 * i) % 55;
      seedArray[ii] = mk;
      mk = mj! - mk;
      if (mk < 0) {
        mk += mBig;
      }

      mj = seedArray[ii];
    }

    for (int k = 1; k < 5; k++) {
      for (int i = 1; i < 56; i++) {
        seedArray[i] -= seedArray[1 + (i + 30) % 55];
        if (seedArray[i]< 0) {
          seedArray[i] += mBig;
        }
      }
    }

    inext = 0;
    inextp = 31;
  }

  void _init() {
    mBig = intMax;
    seedArray = List<int>.filled(56, 0, growable: false);
  }

  /// Return sample from PRNG
  double sample() {
    int retVal;

    if (++inext >= 56) {
      inext = 1;
    }

    if (++inextp >= 56) {
      inextp = 1;
    }

    retVal = seedArray[inext]- seedArray[inextp];

    if (retVal < 0) {
      retVal += mBig;
    }

    seedArray[inext] = retVal;

    return retVal * (1.0 / mBig);
  }

  /// Return the next random integer.
  int next() {
    int retVal = (sample() * mBig).floor().toInt();
    return retVal;
  }

  /// Get the next random integer exclusive to [maxValue].
  int nextFromMax(int maxValue) {
    if (maxValue < 0) {
      throw ArgumentError("maxValue less then zero");
    }

    int retVal = (sample() * maxValue).toInt();
    return retVal;
  }

  /// Return the next random integer inclusive to [minValue] exclusive to [maxValue].
  int nextFromRange(int minValue, int maxValue) {
    if (minValue > maxValue) {
      throw ArgumentError("Min value is greater than max value.");
    }

    int diff = maxValue - minValue;
    if (diff.abs() <= 1) {
      return minValue;
    }

    int retVal = ((sample() * diff) + minValue).toInt();
    return retVal;
  }

  /// Return a list of random ints of [size].
  List<int?> nextInts(int size) {
    if (size <= 0) {
      throw ArgumentError("size less then equal to zero");
    }

    List<int> buff = List.filled(size, 0);
    for (int i = 0; i < size; i++) {
      buff[i] = (sample() * (mBig + 1)).toInt();
    }

    return buff;
  }

  /// Returns a [Map] of unique integers of [size] with random integer inclusive to [minValue] exclusive to [maxValue].
  Map<int, int> nextIntsUnique(int minValue, int maxValue, int size) {
    if (minValue > maxValue) {
      throw ArgumentError("Min value is greater than max value.");
    }

    if (size > (maxValue - minValue)) {
      throw ArgumentError("size less then maxValue-minValue");
    }

    Map<int, int> intMap = <int, int>{};
    for (int i = 1; i <= size; i++) {
      bool unique = false;
      while (unique != true) {
        int v = nextFromRange(minValue, maxValue);
        if (!intMap.containsValue(v) && v >= minValue && v <= maxValue) {
          intMap[i] = v;
          unique = true;
        }
      }
    }

    return intMap;
  }

  /// Returns random [double] value between 0.0 to 1.0.
  double nextDouble() {
    return sample();
  }
}
