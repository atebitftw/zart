library DRandom;
import 'dart:math' as Math;

const int INTMAX = 2147483647;
const int INTMIN = -2147483648;

const int MSEED = 161803398;

/**
 * Suppliment pseudorandom random number generator for dart based on
 * similar implementations in mono C#
 */
class DRandom
{

    int MBIG;

    int inext;
    int inextp;

    List<int> SeedArray;

    DRandom.withSeed(int Seed)
    {
        _init();
        _seed(Seed);
    }

    /// Create [DRandom]
    DRandom()
    {
        _init();
        int i = new Math.Random().nextInt((1<<32) - 1);
        int Seed = (i*MBIG).floor().toInt();
        _seed(Seed);
    }


    void _seed(int Seed)
    {
        int ii;
        int mj;
        int mk;

        if (Seed == INTMIN)
        {
            mj = MSEED - (INTMAX + 1).abs();
        }
        else
        {
            mj = MSEED - Seed.abs();
        }

        SeedArray[55] = mj;
        mk = 1;
        for (int i=1; i<55; i++)
        {
            ii = (21 * i) % 55;
            SeedArray[ii] = mk;
            mk = mj - mk;
            if (mk < 0)
            {
                mk += MBIG;
            }

            mj = SeedArray[ii];
        }

        for (int k=1; k<5; k++)
        {
            for (int i=1; i<56; i++)
            {
                SeedArray[i] -= SeedArray[1 + (i + 30) % 55];
                if (SeedArray[i] < 0)
                {
                    SeedArray[i] += MBIG;
                }
            }
        }

        inext = 0;
        inextp = 31;
    }

    void _init()
    {
        MBIG = INTMAX;
        SeedArray = new List<int>(56);
    }

    /// Return sample from PRNG
    double Sample()
    {
        int retVal;

        if (++inext >= 56)
        {
            inext=1;
        }

        if (++inextp >= 56)
        {
            inextp=1;
        }

        retVal = SeedArray[inext] - SeedArray[inextp];

        if (retVal < 0)
        {
            retVal += MBIG;
        }

        SeedArray[inext] = retVal;

        return retVal * (1.0 / MBIG);
    }

    /// Return the next random integer.
    int Next()
    {
        int retVal = (Sample() * MBIG).floor().toInt();
        return retVal;
    }

    /// Get the next random integer exclusive to [maxValue].
    int NextFromMax(int maxValue)
    {
        if (maxValue < 0)
        {
            throw new ArgumentError("maxValue less then zero");
        }

        int retVal = (Sample() * maxValue).toInt();
        return retVal;
    }

    /// Return the next random integer inclusive to [minValue] exclusive to [maxValue].
    int NextFromRange(int minValue, int maxValue)
    {
        if (minValue > maxValue)
        {
            throw new ArgumentError("Min value is greater than max value.");
        }

        int diff = maxValue - minValue;
        if (diff.abs() <= 1)
        {
            return minValue;
        }

        int retVal = ((Sample() * diff) + minValue).toInt();
        return retVal;
    }

    /// Return a list of random ints of [size].
    List<int> NextInts(int size)
    {
        if (size <= 0)
        {
            throw new ArgumentError("size less then equal to zero");
        }

        List<int> buff = new List<int>(size);
        for (int i=0; i<size; i++)
        {
            buff[i] = (Sample() * (MBIG + 1)).toInt();
        }

        return buff;
    }

    /// Returns a [Map] of unique integers of [size] with random integer inclusive to [minValue] exclusive to [maxValue].
    Map<int,int> NextIntsUnique(int minValue, int maxValue, int size)
    {
        if (minValue > maxValue)
        {
            throw new ArgumentError("Min value is greater than max value.");
        }

        if (size > (maxValue - minValue))
        {
            throw new ArgumentError("size less then maxValue-minValue");
        }

        Map<int,int> intMap = new Map<int,int>();
        for (int i=1; i<=size; i++)
        {
            bool unique = false;
            while (unique!=true)
            {
                int v = NextFromRange(minValue,maxValue);
                if (!intMap.containsValue(v) &&
                v >= minValue &&
                v <= maxValue)
                {
                    intMap[i] = v;
                    unique = true;
                }
            }
        }

        return intMap;
    }

    /// Returns random [double] value between 0.0 to 1.0.
    double NextDouble()
    {
        return Sample();
    }
}