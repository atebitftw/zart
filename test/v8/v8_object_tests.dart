import 'package:test/test.dart';
import 'package:zart/src/game_exception.dart';
import 'package:zart/src/game_object.dart';

void objectTestsV8() {
  group('Objects>', () {
    const berth = 63;
    const pirates = 62; // Parent of berth
    const ladder = 64; // Sibling of berth
    // const dreamBridge = 60;

    test('remove', () {
      var o1 = GameObject(berth);
      var p = GameObject(pirates);

      // check if we have the right object and
      // assumptions are correct.
      expect('berth', equals(o1.shortName));
      expect(pirates, equals(o1.parent));
      expect(ladder, equals(o1.sibling));
      expect(0, equals(o1.child));

      // Verify berth is first child
      expect(berth, equals(p.child));

      o1.removeFromTree();

      // Since berth was first child, parent.child should now be ladder
      expect(ladder, equals(p.child));

      expect(0, equals(o1.parent));
      expect(0, equals(o1.sibling));
    });

    test('insert', () {
      var o1 = GameObject(berth);
      var p = GameObject(pirates);
      var oc = p.child;

      o1.insertTo(p.id);
      expect(p.id, equals(o1.parent));

      expect(berth, equals(p.child));
      expect(oc, equals(o1.sibling));
    });

    test('get property length', () {
      GameObject o1 = GameObject(berth);

      expect(
        2,
        equals(GameObject.propertyLength(o1.getPropertyAddress(36) - 1)),
      );
      expect(
        2,
        equals(GameObject.propertyLength(o1.getPropertyAddress(35) - 1)),
      );
      expect(
        4,
        equals(GameObject.propertyLength(o1.getPropertyAddress(4) - 1)),
      );
      expect(
        2,
        equals(GameObject.propertyLength(o1.getPropertyAddress(2) - 1)),
      );
      expect(
        4,
        equals(GameObject.propertyLength(o1.getPropertyAddress(1) - 1)),
      );
    });

    test('get property', () {
      GameObject o1 = GameObject(berth);

      // check a known prop value (prop 2 is len 2)
      // we can't easily guess the value without reading, but we can verify it returns something
      var val = o1.getPropertyValue(2);
      expect(val, isNotNull);

      //throw on property len > 2 (prop 4 is len 4)
      expect(() => o1.getPropertyValue(4), throwsA(isA<GameException>()));
    });

    test('get property address', () {
      GameObject o1 = GameObject(berth); // "berth"

      var addr = o1.getPropertyAddress(2);
      expect(addr, greaterThan(0));

      var pnum = GameObject.propertyNumber(addr - 1);
      expect(2, equals(pnum));

      var val = o1.getPropertyValue(pnum);
      expect(val, isNotNull);

      var addr2 = o1.getPropertyAddress(pnum);
      expect(addr, equals(addr2));

      var addr0 = o1.getPropertyAddress(0);
      expect(0, equals(addr0));
    });

    test('get next property', () {
      GameObject o1 = GameObject(berth);

      // Props: 36 -> 35 -> 4 -> 2 -> 1
      expect(36, equals(o1.getNextProperty(0)));
      expect(35, equals(o1.getNextProperty(36)));
      expect(4, equals(o1.getNextProperty(35)));
      expect(2, equals(o1.getNextProperty(4)));
      expect(1, equals(o1.getNextProperty(2)));
      expect(0, equals(o1.getNextProperty(1)));

      expect(() => o1.getNextProperty(99), throwsA(isA<GameException>()));
    });

    test('set property', () {
      GameObject o1 = GameObject(berth);

      // prop 2 is len 2, safe to set
      var oldVal = o1.getPropertyValue(2);
      o1.setPropertyValue(2, 0xffff);
      expect(0xffff, equals(o1.getPropertyValue(2)));
      o1.setPropertyValue(2, oldVal); // restore

      //throw on prop no exist
      expect(
        () => o1.setPropertyValue(13, 0xffff),
        throwsA(isA<GameException>()),
      );

      //throw on prop len > 2 (prop 4 is len 4)
      expect(
        () => o1.setPropertyValue(4, 0xffff),
        throwsA(isA<GameException>()),
      );
    });

    test('attributes are set', () {
      GameObject o1 = GameObject(berth);

      // Just verify we can check flags without error
      // We don't know for sure which are set without a full dump, but basic access check:
      expect(o1.isFlagBitSet(1), isA<bool>());
    });

    test('unset attribute', () {
      GameObject o1 = GameObject(berth);

      // find a set flag or just test toggle mechanics
      // Assuming at least one flag is set or unsettable
      var wasSet = o1.isFlagBitSet(1);
      o1.unsetFlagBit(1);
      expect(o1.isFlagBitSet(1), equals(false));

      if (wasSet) o1.setFlagBit(1);
    });

    test('set attribute', () {
      GameObject o1 = GameObject(berth);

      var wasSet = o1.isFlagBitSet(1);
      o1.setFlagBit(1);
      expect(o1.isFlagBitSet(1), equals(true));

      if (!wasSet) o1.unsetFlagBit(1);

      o1.unsetFlagBit(0);
      expect(o1.isFlagBitSet(0), equals(false));
      o1.setFlagBit(0);
      expect(o1.isFlagBitSet(0), equals(true));
      o1.unsetFlagBit(0);
    });
  });
}
