import 'dart:io';
import 'package:zart/src/tads3/vm/t3_interpreter.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart t3_run.dart <file.t3>');
    return;
  }

  final data = File(args[0]).readAsBytesSync();
  final interp = T3Interpreter();

  print('Loading ${args[0]}...');
  interp.load(data);

  print('Entrypoint: ${interp.entrypoint}');

  print('Starting execution...');
  try {
    interp.maxInstructions = 10000; // Limit execution for safety in debug tool
    await interp.run();
    print('Execution finished.');
  } catch (e, stack) {
    print('Execution stopped at IP 0x${interp.registers.ip.toRadixString(16)}: $e');
    print('Registers: ${interp.debugInfo()}');
    print(stack);
  }
}
