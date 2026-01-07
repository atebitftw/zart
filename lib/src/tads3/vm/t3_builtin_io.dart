import 'dart:io';

import 'package:zart/src/loaders/tads/t3_exception.dart';
import 'package:zart/src/tads3/vm/t3_interpreter.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';

/// I/O built-in functions for TADS 3.
/// Includes: say, morePrompt
class T3BuiltinIO {
  /// say(val) - Display a value to main output.
  static void say(T3Interpreter interp, int argc) {
    if (argc < 1) return;
    final val = interp.stack.pop();
    if (argc > 1) interp.stack.discard(argc - 1);

    final text = interp.getStringValue(val);
    interp.printRaw(text);

    interp.registers.r0 = T3Value.nil();
  }

  /// morePrompt() - Display "[more]" and wait for input.
  static void morePrompt(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);

    interp.printRaw('[more]');
    stdin.readLineSync();

    interp.registers.r0 = T3Value.nil();
  }

  /// setLogFile(filename, flags?) - Set the log file.
  static void setLogFile(T3Interpreter interp, int argc) {
    if (argc < 1) throw T3Exception('setLogFile() requires at least 1 argument');
    interp.stack.discard(argc);
    // Logging not implemented in basic VM
    interp.registers.r0 = T3Value.nil();
  }

  /// clearScreen() - Clear the display.
  static void clearScreen(T3Interpreter interp, int argc) {
    if (argc > 0) interp.stack.discard(argc);
    // Simple ANSI clear for basic terminal
    interp.printRaw('\x1b[2J\x1b[H');
    interp.registers.r0 = T3Value.nil();
  }
}
