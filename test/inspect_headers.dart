// Temporary test to inspect Z8 file header
// Temporary test to inspect Z8 file header
import 'dart:io';
import 'package:zart/src/header.dart';
import 'package:zart/src/z_machine.dart';

void main() {
  // Load and inspect across.z8
  final z8bytes = File('../assets/games/across.z8').readAsBytesSync();
  print('=== across.z8 ===');
  print('Version: ${z8bytes[Header.version]}');
  final z8pc =
      (z8bytes[Header.programCounterInitialValueAddr] << 8) | z8bytes[Header.programCounterInitialValueAddr + 1];
  print('Initial PC (raw): 0x${z8pc.toRadixString(16)} ($z8pc)');
  print('Byte at PC-1 (locals count?): 0x${z8bytes[z8pc - 1].toRadixString(16)} (${z8bytes[z8pc - 1]})');
  print('First 4 bytes at PC: ${z8bytes.sublist(z8pc, z8pc + 4).map((b) => '0x${b.toRadixString(16)}').join(' ')}');

  // Load and inspect adventureland.z5 for comparison
  final z5bytes = File('../assets/games/adventureland.z5').readAsBytesSync();
  print('\n=== adventureland.z5 ===');
  print('Version: ${z5bytes[Header.version]}');
  final z5pc =
      (z5bytes[Header.programCounterInitialValueAddr] << 8) | z5bytes[Header.programCounterInitialValueAddr + 1];
  print('Initial PC (raw): 0x${z5pc.toRadixString(16)} ($z5pc)');
  print('Byte at PC-1 (locals count?): 0x${z5bytes[z5pc - 1].toRadixString(16)} (${z5bytes[z5pc - 1]})');
  print('First 4 bytes at PC: ${z5bytes.sublist(z5pc, z5pc + 4).map((b) => '0x${b.toRadixString(16)}').join(' ')}');
}
