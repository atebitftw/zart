import 'package:test/test.dart';
import 'package:zart/src/zart_internal.dart';
import '../test_utils.dart';

void main() {
  test('Dictionary loads multiple entries', () {
    setupZMachine();

    // Verify dictionary is initialized
    expect(Z.engine.mem.dictionary.isInitialized, isTrue);

    // Verify total entries is greater than 1 (specifically, minizork should have many)
    print(
      'Dictionary loaded with ${Z.engine.mem.dictionary.totalEntries} entries.',
    );
    expect(Z.engine.mem.dictionary.totalEntries, greaterThan(1));
  });
}
