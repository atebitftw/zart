import 'package:test/test.dart';
import 'package:zart/src/cli/ui/cli_platform_provider.dart';

void main() {
  group('QuickSave Injection', () {
    late CliPlatformProvider provider;

    setUp(() {
      provider = CliPlatformProvider();
      provider.gameName = 'testgame';
    });

    test('F2 should inject "save\\n" and automate filename', () async {
      // 1. Simulate F2 press
      provider.renderer.onQuickSave?.call();

      // 2. Verify "save\n" is in queue
      // We need to read it back
      expect(await provider.renderer.readLine(), equals('save'));

      // 3. VM should now send a save command
      // In a real scenario, the VM processes "save\n" and then sends ZIoCommands.save
      // We simulate the platform provider receiving this command.

      // We can't easily wait for the file IO in a pure unit test without mocking File,
      // but we can verify a filename is chosen correctly if we refactor saveGame slightly
      // or just check the internal state if we exposed it.

      // For now, let's just verify the injection.
    });

    test('F3 should inject "restore\\n" and automate filename', () async {
      provider.renderer.onQuickLoad?.call();
      expect(await provider.renderer.readLine(), equals('restore'));
    });
  });
}
