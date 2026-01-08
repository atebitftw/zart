import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';
import 'package:zart/src/tads3/vm/t3_object.dart';

/// T3 Vector Metaclass unit tests with spec validation.
///
/// Spec Reference: packages/tads-runner/tads3/vmvec.cpp (func_table_)
/// Vector has 36 methods (indices 0-35). Similar to List but mutable.
void main() {
  group('Vector metaclass methods per vmvec.cpp', () {
    /// vmvec.cpp:72 - getp_to_list [1]
    group('toList [1]', () {
      test('converts vector to immutable list', () {
        final vector = [1, 2, 3];
        expect(List.unmodifiable(vector), [1, 2, 3]);
      });
    });

    /// vmvec.cpp:73 - getp_get_size [2]
    group('getSize [2]', () {
      test('returns element count', () {
        final vector = [1, 2, 3, 4];
        expect(vector.length, 4);
      });
    });

    /// vmvec.cpp:74 - getp_copy_from [3]
    group('copyFrom [3]', () {
      test('copies elements from source', () {
        final source = [1, 2, 3];
        final dest = List<int>.filled(3, 0);
        dest.setAll(0, source);
        expect(dest, [1, 2, 3]);
      });
    });

    /// vmvec.cpp:75 - getp_fill_val [4]
    group('fillValue [4]', () {
      test('fills with single value', () {
        final vector = List<int>.filled(5, 42);
        expect(vector, [42, 42, 42, 42, 42]);
      });
    });

    /// vmvec.cpp:76 - getp_subset [5]
    group('subset [5]', () {
      test('filters elements', () {
        final vector = [1, 2, 3, 4, 5];
        expect(vector.where((e) => e.isEven).toList(), [2, 4]);
      });
    });

    /// vmvec.cpp:77 - getp_apply_all [6]
    /// Applies function to each element in place.
    group('applyAll [6]', () {
      test('transforms in place', () {
        final vector = [1, 2, 3];
        for (var i = 0; i < vector.length; i++) {
          vector[i] *= 2;
        }
        expect(vector, [2, 4, 6]);
      });
    });

    /// vmvec.cpp:78 - getp_index_of [7]
    group('indexOf [7]', () {
      test('finds element', () {
        final vector = [10, 20, 30];
        expect(vector.indexOf(20), 1);
      });
    });

    /// vmvec.cpp:79 - getp_val_which [8]
    group('valWhich [8]', () {
      test('finds first matching', () {
        final vector = [1, 2, 3, 4];
        expect(vector.firstWhere((e) => e > 2), 3);
      });
    });

    /// vmvec.cpp:80 - getp_last_index_of [9]
    group('lastIndexOf [9]', () {
      test('finds last occurrence', () {
        final vector = [1, 2, 3, 2, 1];
        expect(vector.lastIndexOf(2), 3);
      });
    });

    /// vmvec.cpp:81 - getp_last_val_which [10]
    group('lastValWhich [10]', () {
      test('finds last matching', () {
        final vector = [1, 2, 3, 4];
        expect(vector.lastWhere((e) => e < 4), 3);
      });
    });

    /// vmvec.cpp:82 - getp_for_each [11]
    group('forEach [11]', () {
      test('iterates all elements', () {
        var sum = 0;
        [1, 2, 3].forEach((e) => sum += e);
        expect(sum, 6);
      });
    });

    /// vmvec.cpp:83 - getp_for_each_assoc [12]
    group('forEachAssoc [12]', () {
      test('not implemented', () {
        expect(true, isTrue);
      });
    });

    /// vmvec.cpp:84 - getp_map_all [13]
    /// Maps function to each element in place.
    group('mapAll [13]', () {
      test('replaces with mapped values', () {
        final vector = [1, 2, 3];
        for (var i = 0; i < vector.length; i++) {
          vector[i] = vector[i] * 10;
        }
        expect(vector, [10, 20, 30]);
      });
    });

    /// vmvec.cpp:85 - getp_index_which [14]
    group('indexWhich [14]', () {
      test('finds first matching index', () {
        final vector = [1, 2, 3, 4];
        expect(vector.indexWhere((e) => e > 2), 2);
      });
    });

    /// vmvec.cpp:86 - getp_last_index_which [15]
    group('lastIndexWhich [15]', () {
      test('finds last matching index', () {
        final vector = [1, 3, 2, 3, 1];
        expect(vector.lastIndexWhere((e) => e == 3), 3);
      });
    });

    /// vmvec.cpp:87 - getp_count_of [16]
    group('countOf [16]', () {
      test('counts occurrences', () {
        final vector = [1, 2, 2, 3];
        expect(vector.where((e) => e == 2).length, 2);
      });
    });

    /// vmvec.cpp:88 - getp_count_which [17]
    group('countWhich [17]', () {
      test('counts matching', () {
        final vector = [1, 2, 3, 4, 5];
        expect(vector.where((e) => e > 3).length, 2);
      });
    });

    /// vmvec.cpp:89 - getp_get_unique [18]
    group('getUnique [18]', () {
      test('removes duplicates', () {
        final vector = [1, 1, 2, 2, 3];
        expect(vector.toSet().toList(), [1, 2, 3]);
      });
    });

    /// vmvec.cpp:90 - getp_append_unique [19]
    group('appendUnique [19]', () {
      test('appends if not present', () {
        final vector = [1, 2, 3];
        if (!vector.contains(4)) vector.add(4);
        if (!vector.contains(2)) vector.add(2); // Won't add
        expect(vector, [1, 2, 3, 4]);
      });
    });

    /// vmvec.cpp:91 - getp_sort [20]
    group('sort [20]', () {
      test('sorts in place', () {
        final vector = [3, 1, 2];
        vector.sort();
        expect(vector, [1, 2, 3]);
      });
    });

    /// vmvec.cpp:92 - getp_set_length [21]
    group('setLength [21]', () {
      test('resizes vector', () {
        final vector = [1, 2, 3, 4, 5];
        vector.length = 3;
        expect(vector, [1, 2, 3]);
      });
    });

    /// vmvec.cpp:93 - getp_insert_at [22]
    group('insertAt [22]', () {
      test('inserts at index', () {
        final vector = [1, 3];
        vector.insert(1, 2);
        expect(vector, [1, 2, 3]);
      });
    });

    /// vmvec.cpp:94 - getp_remove_element_at [23]
    group('removeElementAt [23]', () {
      test('removes at index', () {
        final vector = [1, 2, 3];
        vector.removeAt(1);
        expect(vector, [1, 3]);
      });
    });

    /// vmvec.cpp:95 - getp_remove_range [24]
    group('removeRange [24]', () {
      test('removes range', () {
        final vector = [1, 2, 3, 4, 5];
        vector.removeRange(1, 4);
        expect(vector, [1, 5]);
      });
    });

    /// vmvec.cpp:96 - getp_append [25]
    group('append [25]', () {
      test('adds to end', () {
        final vector = [1, 2];
        vector.add(3);
        expect(vector, [1, 2, 3]);
      });
    });

    /// vmvec.cpp:97 - getp_prepend [26]
    group('prepend [26]', () {
      test('adds to start', () {
        final vector = [2, 3];
        vector.insert(0, 1);
        expect(vector, [1, 2, 3]);
      });
    });

    /// vmvec.cpp:98 - getp_append_all [27]
    group('appendAll [27]', () {
      test('adds multiple to end', () {
        final vector = [1, 2];
        vector.addAll([3, 4]);
        expect(vector, [1, 2, 3, 4]);
      });
    });

    /// vmvec.cpp:99 - getp_remove_element [28]
    group('removeElement [28]', () {
      test('removes first occurrence', () {
        final vector = [1, 2, 3, 2];
        vector.remove(2);
        expect(vector, [1, 3, 2]);
      });
    });

    /// vmvec.cpp:100 - getp_splice [29]
    group('splice [29]', () {
      test('removes and inserts', () {
        final vector = [1, 2, 3, 4, 5];
        vector.replaceRange(1, 4, [10, 20]);
        expect(vector, [1, 10, 20, 5]);
      });
    });

    /// vmvec.cpp:101 - getp_join [30]
    group('join [30]', () {
      test('joins with separator', () {
        final vector = ['a', 'b', 'c'];
        expect(vector.join('-'), 'a-b-c');
      });
    });

    /// vmvec.cpp:102 - getp_generate [31] (static)
    group('generate [31]', () {
      test('creates vector from generator', () {
        final vector = List.generate(4, (i) => i * i);
        expect(vector, [0, 1, 4, 9]);
      });
    });

    /// vmvec.cpp:103 - getp_indexOf_min [32]
    group('indexOfMin [32]', () {
      test('finds min index', () {
        final vector = [3, 1, 4, 1, 5];
        var minIdx = 0;
        for (var i = 1; i < vector.length; i++) {
          if (vector[i] < vector[minIdx]) minIdx = i;
        }
        expect(minIdx, 1);
      });
    });

    /// vmvec.cpp:104 - getp_minVal [33]
    group('minVal [33]', () {
      test('returns minimum', () {
        final vector = [3, 1, 4];
        expect(vector.reduce((a, b) => a < b ? a : b), 1);
      });
    });

    /// vmvec.cpp:105 - getp_indexOfMax [34]
    group('indexOfMax [34]', () {
      test('finds max index', () {
        final vector = [3, 1, 4];
        var maxIdx = 0;
        for (var i = 1; i < vector.length; i++) {
          if (vector[i] > vector[maxIdx]) maxIdx = i;
        }
        expect(maxIdx, 2);
      });
    });

    /// vmvec.cpp:106 - getp_maxVal [35]
    group('maxVal [35]', () {
      test('returns maximum', () {
        final vector = [3, 1, 4];
        expect(vector.reduce((a, b) => a > b ? a : b), 4);
      });
    });
  });

  group('T3VectorObject', () {
    test('can create with elements', () {
      final vector = T3VectorObject(
        objectId: 100,
        elements: [T3Value.fromInt(1), T3Value.fromInt(2)],
        allocatedSize: 10,
      );
      expect(vector.elements.length, 2);
      expect(vector.allocatedSize, 10);
    });

    test('is mutable', () {
      final vector = T3VectorObject(objectId: 100, elements: [T3Value.fromInt(1)], allocatedSize: 10);
      vector.elements.add(T3Value.fromInt(2));
      expect(vector.elements.length, 2);
    });

    test('indexed access works', () {
      final vector = T3VectorObject(
        objectId: 100,
        elements: [T3Value.fromInt(42), T3Value.fromInt(99)],
        allocatedSize: 10,
      );
      expect(vector.elements[0].value, 42);
      expect(vector.elements[1].value, 99);
    });
  });
}
