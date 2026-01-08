import 'dart:io';

import 'package:zart/src/tads3/vm/t3_interpreter.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';

/// I/O built-in functions for TADS 3 (tads-io).
class T3BuiltinIO {
  // ==================== Input Functions ====================

  /// inputLine() - Read a line of text.
  static void inputLine(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    // TODO: Connect to PlatformProvider via interp
    final line = stdin.readLineSync() ?? '';
    final strOffset = interp.addDynamicString(line);
    interp.registers.r0 = T3Value.fromString(strOffset);
  }

  /// inputKey() - Read a single keystroke.
  static void inputKey(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    // Not fully supported in basic CLI without raw mode, return space
    interp.registers.r0 = T3Value.fromString(interp.addDynamicString(' '));
  }

  /// inputEvent(timeout?) - Wait for an input event.
  static void inputEvent(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    // Stub: return EOF event
    // list[0] = event type (1=Key, 2=Str, 3=Timeout, 4=EOF)
    final listOffset = interp.addDynamicList([T3Value.fromInt(4), T3Value.nil()]);
    interp.registers.r0 = T3Value.fromList(listOffset);
  }

  /// inputTimeout(timeout) - Wait for input with timeout.
  static void inputTimeout(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    interp.registers.r0 = T3Value.nil();
  }

  // ==================== Output Functions ====================

  /// tadsSay(val) - Display a value.
  static void tadsSay(T3Interpreter interp, int argc) {
    if (argc < 1) return;
    final val = interp.stack.pop();
    if (argc > 1) interp.stack.discard(argc - 1);

    final text = interp.getStringValue(val);
    interp.printRaw(text);

    interp.registers.r0 = T3Value.nil();
  }

  /// flushOutput() - Flush output buffer.
  static void flushOutput(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    // No-op for direct print
    interp.registers.r0 = T3Value.nil();
  }

  /// morePrompt() - Display "[more]" prompt.
  static void morePrompt(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    interp.printRaw('[more]');
    stdin.readLineSync();
    interp.registers.r0 = T3Value.nil();
  }

  // ==================== Status & Banners ====================

  static void statusMode(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    interp.registers.r0 = T3Value.nil();
  }

  static void statusRight(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    interp.registers.r0 = T3Value.nil();
  }

  static void bannerCreate(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    // Return dummy handle 1
    interp.registers.r0 = T3Value.fromInt(1);
  }

  static void bannerDelete(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    interp.registers.r0 = T3Value.nil();
  }

  static void bannerSay(T3Interpreter interp, int argc) {
    if (argc < 2) return; // handle, str
    final strVal = interp.stack.pop();
    final _ = interp.stack.pop(); // handle
    if (argc > 2) interp.stack.discard(argc - 2);

    final text = interp.getStringValue(strVal);
    interp.printRaw(text); // Just print to main out for now
    interp.registers.r0 = T3Value.nil();
  }

  static void bannerSizeTo(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    interp.registers.r0 = T3Value.nil();
  }

  static void bannerSetSize(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    interp.registers.r0 = T3Value.nil();
  }

  // ==================== Files & System ====================

  static void setLogFile(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    interp.registers.r0 = T3Value.nil();
  }

  static void setScriptFile(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    interp.registers.r0 = T3Value.nil();
  }

  static void systemInfo(T3Interpreter interp, int argc) {
    if (argc < 1) {
      interp.registers.r0 = T3Value.nil();
      return;
    }
    final selector = interp.stack.pop();
    if (argc > 1) interp.stack.discard(argc - 1);

    // 1=SysInfoVersion, 25=SysInfoOsName, etc.
    if (selector.value == 1) {
      interp.registers.r0 = T3Value.fromString(interp.addDynamicString('3.1.0'));
    } else {
      interp.registers.r0 = T3Value.nil();
    }
  }

  static void clearScreen(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    interp.registers.r0 = T3Value.nil();
  }

  static void inputDialog(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    interp.registers.r0 = T3Value.fromInt(1); // Default to button 1
  }

  static void inputFile(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    interp.registers.r0 = T3Value.nil();
  }

  static void timeDelay(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    interp.registers.r0 = T3Value.nil();
  }

  static void resExists(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    interp.registers.r0 = T3Value.nil();
  }

  static void inputLineCancel(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    interp.registers.r0 = T3Value.nil();
  }

  static void bannerClear(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    interp.registers.r0 = T3Value.nil();
  }

  static void bannerGoTo(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    interp.registers.r0 = T3Value.nil();
  }

  static void bannerSetTextColor(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    interp.registers.r0 = T3Value.nil();
  }

  static void bannerSetScreenColor(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    interp.registers.r0 = T3Value.nil();
  }

  static void bannerGetInfo(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    interp.registers.r0 = T3Value.nil();
  }

  static void logConsoleCreate(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    interp.registers.r0 = T3Value.nil();
  }

  static void logConsoleClose(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    interp.registers.r0 = T3Value.nil();
  }

  static void logConsoleSay(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    interp.registers.r0 = T3Value.nil();
  }

  static void logInputEvent(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    interp.registers.r0 = T3Value.nil();
  }

  static void getLocalCharSet(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    interp.registers.r0 = T3Value.nil();
  }
}
