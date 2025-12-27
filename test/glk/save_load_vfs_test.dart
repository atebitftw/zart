import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:zart/src/io/glk/glk_io_selectors.dart';
import 'package:zart/src/io/glk/glulx_terminal_provider.dart';
import 'package:zart/src/io/glk/glk_terminal_display.dart';
import 'package:zart/zart.dart';

class MockPlatformProvider extends PlatformProvider {
  int saveCount = 0;
  int restoreCount = 0;
  List<int>? restoreData;
  String? lastSaveName;

  @override
  String get gameName => 'TestGame';
  @override
  PlatformCapabilities get capabilities => PlatformCapabilities(screenWidth: 80, screenHeight: 24);
  @override
  void render(ScreenFrame frame) {}
  @override
  void showTempMessage(String message, {int seconds = 3}) {}
  @override
  Future<void> openSettings(dynamic terminal, {bool isGameStarted = false}) async {}
  @override
  Future<String> readLine({int? maxLength, int? timeout}) async => '';
  @override
  Future<InputEvent> readInput({int? timeout}) async => InputEvent.none();
  @override
  InputEvent? pollInput() => InputEvent.none();
  @override
  ({Future<void> onKeyPressed, bool Function() wasPressed, void Function() cleanup}) setupAsyncKeyWait() {
    return (onKeyPressed: Future.value(), wasPressed: () => false, cleanup: () {});
  }

  @override
  Future<String?> saveGame(List<int> data, {String? suggestedName}) async {
    saveCount++;
    lastSaveName = suggestedName;
    return 'test.save';
  }

  @override
  Future<List<int>?> restoreGame({String? suggestedName}) async {
    restoreCount++;
    return restoreData;
  }

  @override
  Future<String?> quickSave(List<int> data) async => null;
  @override
  Future<List<int>?> quickRestore() async => null;
  @override
  void onInit(GameFileType type) {}
  @override
  void enterDisplayMode() {}
  @override
  void exitDisplayMode() {}
  @override
  void onQuit() {}
  @override
  void onError(String message) {}
}

class MockDisplay extends GlkTerminalDisplay {
  @override
  void renderGlk(dynamic model) {}
  @override
  void detectTerminalSize() {}
}

void main() {
  group('Glk Save/Load VFS', () {
    late GlulxTerminalProvider provider;
    late MockPlatformProvider platform;
    late Uint8List ram;

    setUp(() {
      platform = MockPlatformProvider();
      provider = GlulxTerminalProvider(display: MockDisplay());
      provider.setPlatformProvider(platform);
      ram = Uint8List(1024);
      provider.setMemoryAccess(
        read: (addr, {size = 1}) {
          if (size == 1) return ram[addr];
          if (size == 4) {
            return ByteData.sublistView(ram, addr, addr + 4).getUint32(0);
          }
          return 0;
        },
        write: (addr, val, {size = 1}) {
          if (size == 1) ram[addr] = val;
          if (size == 4) {
            ByteData.sublistView(ram, addr, addr + 4).setUint32(0, val);
          }
        },
      );
    });

    void putString(int addr, String s) {
      for (var i = 0; i < s.length; i++) {
        ram[addr + i] = s.codeUnitAt(i);
      }
      ram[addr + s.length] = 0;
    }

    test('Named File Persistence (Scenario 1)', () async {
      putString(100, "scores.dat");

      // Create first fileref
      final fref1 = await provider.dispatch(GlkIoSelectors.filerefCreateByName, [0x03, 100, 0]);
      expect(fref1, isNot(0));

      // Open stream for writing
      final stream1 = await provider.dispatch(GlkIoSelectors.streamOpenFile, [fref1, 0x01, 0]);
      expect(stream1, isNot(0));

      // Write some data
      await provider.dispatch(GlkIoSelectors.putCharStream, [stream1, 65]); // 'A'
      await provider.dispatch(GlkIoSelectors.putCharStream, [stream1, 66]); // 'B'

      // Close stream
      await provider.dispatch(GlkIoSelectors.streamClose, [stream1, 0]);
      expect(platform.saveCount, equals(0)); // Named files don't prompt

      // Create NEW fileref to same name
      final fref2 = await provider.dispatch(GlkIoSelectors.filerefCreateByName, [0x03, 100, 0]);

      // Open for reading
      final stream2 = await provider.dispatch(GlkIoSelectors.streamOpenFile, [fref2, 0x02, 0]);

      // Read back
      final char1 = await provider.dispatch(GlkIoSelectors.getCharStream, [stream2]);
      final char2 = await provider.dispatch(GlkIoSelectors.getCharStream, [stream2]);

      expect(char1, equals(65));
      expect(char2, equals(66));
    });

    test('Existence Logic (Scenario 2)', () async {
      putString(100, "exists.txt");
      final fref = await provider.dispatch(GlkIoSelectors.filerefCreateByName, [0x03, 100, 0]);

      // Initially doesn't exist
      expect(await provider.dispatch(GlkIoSelectors.filerefDoesFileExist, [fref]), equals(0));

      // Write something
      final stream = await provider.dispatch(GlkIoSelectors.streamOpenFile, [fref, 0x01, 0]);
      await provider.dispatch(GlkIoSelectors.putCharStream, [stream, 33]);
      await provider.dispatch(GlkIoSelectors.streamClose, [stream, 0]);

      // Now it exists
      expect(await provider.dispatch(GlkIoSelectors.filerefDoesFileExist, [fref]), equals(1));
    });

    test('Silent Follow-up Read (Scenario 3)', () async {
      // Create prompted fileref
      final fref = await provider.dispatch(GlkIoSelectors.filerefCreateByPrompt, [
        0x00,
        0x01,
        0,
      ]); // usage save, fmode write

      // Open for writing
      final streamW = await provider.dispatch(GlkIoSelectors.streamOpenFile, [fref, 0x01, 0]);
      await provider.dispatch(GlkIoSelectors.putCharStream, [streamW, 88]); // 'X'

      // Closing triggers save prompt
      await provider.dispatch(GlkIoSelectors.streamClose, [streamW, 0]);
      expect(platform.saveCount, equals(1));

      // NOW: open same fileref handle for reading (game verifying save)
      final streamR = await provider.dispatch(GlkIoSelectors.streamOpenFile, [fref, 0x02, 0]);

      // VERIFY: restoreGame was NOT called (silent read)
      expect(platform.restoreCount, equals(0));

      final char = await provider.dispatch(GlkIoSelectors.getCharStream, [streamR]);
      expect(char, equals(88));
    });

    test('Explicit Destruction (Scenario 4)', () async {
      putString(100, "trash.txt");
      final fref = await provider.dispatch(GlkIoSelectors.filerefCreateByName, [0x03, 100, 0]);

      // Write data
      final stream = await provider.dispatch(GlkIoSelectors.streamOpenFile, [fref, 0x01, 0]);
      await provider.dispatch(GlkIoSelectors.putCharStream, [stream, 99]);
      await provider.dispatch(GlkIoSelectors.streamClose, [stream, 0]);

      expect(await provider.dispatch(GlkIoSelectors.filerefDoesFileExist, [fref]), equals(1));

      // Destroy fileref
      await provider.dispatch(GlkIoSelectors.filerefDestroy, [fref]);

      // Now filerefDoesFileExist for that handle should be 0 (record gone)
      expect(await provider.dispatch(GlkIoSelectors.filerefDoesFileExist, [fref]), equals(0));
    });

    test('Prompted Persistence (@PROMPT)', () async {
      // Setup platform with some "existing" save data
      platform.restoreData = [1, 2, 3];

      // Create prompted fileref
      final fref = await provider.dispatch(GlkIoSelectors.filerefCreateByPrompt, [
        0x00,
        0x02,
        0,
      ]); // usage save, fmode read

      // Open for reading (triggers prompt)
      final stream = await provider.dispatch(GlkIoSelectors.streamOpenFile, [fref, 0x02, 0]);
      expect(platform.restoreCount, equals(1));

      await provider.dispatch(GlkIoSelectors.streamClose, [stream, 0]);

      // Create ANOTHER prompted fileref - it should still see existence due to @PROMPT
      // but opening it should still trigger a prompt (cross-handle isolation for dialogs)
      final fref2 = await provider.dispatch(GlkIoSelectors.filerefCreateByPrompt, [0x00, 0x02, 0]);
      expect(await provider.dispatch(GlkIoSelectors.filerefDoesFileExist, [fref2]), equals(1));

      await provider.dispatch(GlkIoSelectors.streamOpenFile, [fref2, 0x02, 0]);
      expect(platform.restoreCount, equals(2)); // Prompted again
    });

    test('ReadWrite Restore (Scenario 5) - Regression Test', () async {
      platform.restoreData = [5, 6, 7];

      // Create prompted fileref
      final fref = await provider.dispatch(GlkIoSelectors.filerefCreateByPrompt, [
        0x00,
        0x03,
        0,
      ]); // usage save, fmode ReadWrite

      // Open for ReadWrite (0x03)
      // This should trigger a restore prompt because the handle and cache are empty
      final stream = await provider.dispatch(GlkIoSelectors.streamOpenFile, [fref, 0x03, 0]);
      expect(platform.restoreCount, equals(1));

      final char = await provider.dispatch(GlkIoSelectors.getCharStream, [stream]);
      expect(char, equals(5));
      await provider.dispatch(GlkIoSelectors.streamClose, [stream, 0]);
      expect(platform.saveCount, equals(0)); // Should NOT have saved because no writes occurred
    });
  });
}
