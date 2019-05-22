import 'package:test/test.dart' as TEST;

/// This wrapper class reduces refeactoring from old Dart 1.0 unittest framework. 
/// I should have thought of this before I hand-refactored about a hundred unit tests...
class Expect {
  static void equals(first, second, [String _]){
    TEST.expect(first, TEST.equals(second));
  }

  static void isTrue(first, [String _]){
    TEST.expect(first, TEST.equals(true));
  }

  static void isFalse(first, [String _]){
    TEST.expect(first, TEST.equals(false));
  }
}