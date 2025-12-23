import 'package:test/test.dart';
import '../../bin/cli/cli_renderer.dart';

void main() {
  test(
    'readChar should consume injected input character by character',
    () async {
      final renderer = CliRenderer();

      renderer.pushInput('restore\n');

      expect(await renderer.readChar(), equals('r'));
      expect(await renderer.readChar(), equals('e'));
      expect(await renderer.readChar(), equals('s'));
      expect(await renderer.readChar(), equals('t'));
      expect(await renderer.readChar(), equals('o'));
      expect(await renderer.readChar(), equals('r'));
      expect(await renderer.readChar(), equals('e'));
      expect(await renderer.readChar(), equals('\n'));
    },
  );

  test('readLine should consume injected input line by line', () async {
    final renderer = CliRenderer();

    renderer.pushInput('restore\n');
    renderer.pushInput('look\n');

    expect(await renderer.readLine(), equals('restore'));
    expect(await renderer.readLine(), equals('look'));
  });
}
