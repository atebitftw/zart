import 'dart:io';
import 'package:zart/src/tads3/vm/t3_interpreter.dart';
import 'package:zart/src/loaders/tads/t3_exception.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart t3_run.dart <file.t3>');
    return;
  }

  final data = File(args[0]).readAsBytesSync();
  final interp = T3Interpreter();

  try {
    print('Loading ${args[0]}...');
    interp.load(data);
    print('Loading successful.');
  } catch (e, stack) {
    print('Failed to load ${args[0]}: $e');
    print(stack);
    return;
  }

  print('Entrypoint: ${interp.entrypoint}');

  // Debug output for metaclasses is now in _loadMetaclasses in t3_interpreter.dart
  print('Object table count: ${interp.objectTable.count}');
  // interp.objectTable.dump();

  // Debug: Check BigNumber symbol
  try {
    print('Symbol table has ${interp.symbols.length} symbols');
    if (interp.symbols.containsKey('BigNumber')) {
      final bigNumberSym = interp.symbols['BigNumber'];
      print('BigNumber symbol exists: $bigNumberSym');
    } else {
      print('BigNumber symbol NOT FOUND');
      print('All symbols: ${interp.symbols.keys.take(20).join(", ")}');
    }
  } catch (e, st) {
    print('Error accessing symbols: $e');
    print(st);
  }

  print('Starting execution...');
  try {
    interp.traceExecution = false;
    interp.maxInstructions = 5000000; // Limit execution for safety in debug tool
    await interp.run();
    print('Execution finished.');
  } catch (e, stack) {
    print('Execution stopped at IP 0x${interp.registers.ip.toRadixString(16)}: $e');
    // print('Registers: ${interp.debugInfo()}');
    if (e is! T3Exception) {
      print(stack);
    }
  }
}
