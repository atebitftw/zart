import 'dart:async';
import 'package:zart/src/zart_internal.dart' show ZIoDispatcher;

/// Mock UI Provider for Unit Testing
class MockUIProvider implements ZIoDispatcher {
  final List<Map<String, dynamic>> commandLog = [];
  Future<dynamic> Function(Map<String, dynamic>)? onCommand;

  Future<int> glulxGlk(int selector, List<int> args) => Future.value(0);

  @override
  Future<dynamic> command(Map<String, dynamic> command) async {
    commandLog.add(command);
    if (onCommand != null) {
      return await onCommand!(command);
    }
    return null;
  }

  @override
  int getFlags1() => 0;

  @override
  (int, int) getScreenSize() => (80, 24);

  @override
  Future<String?> quickSave(List<int> data) async => 'quick_save.sav';

  @override
  Future<List<int>?> quickRestore() async => null;
}
