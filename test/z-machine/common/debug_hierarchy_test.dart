import 'package:test/test.dart';
import 'package:zart/src/z_machine/game_object.dart';
import '../test_utils.dart';

void main() {
  setupZMachine();

  test('Debug Object 4 Hierarchy', () {
    var o4 = GameObject(4);
    print('Object 4: ${o4.shortName} (ID: ${o4.id})');
    print('Parent: ${o4.parent}');
    print('Sibling: ${o4.sibling}');

    var parent = GameObject(o4.parent);
    print('Parent (ID: ${parent.id}) ShortName: ${parent.shortName}');
    print('Parent Child (Head of Sibling List): ${parent.child}');

    int current = parent.child;
    print('Traversing siblings from $current...');
    while (current != 0) {
      var obj = GameObject(current);
      print(' - Found Sibling: $current ("${obj.shortName}"), Sibling -> ${obj.sibling}');
      if (current == 4) {
        print('   -> Found Object 4!');
      }
      current = obj.sibling;
    }
  });
}
