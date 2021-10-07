import 'dart:io';

import 'package:test/test.dart';
import 'package:zart/IO/blorb.dart';
import 'package:zart/binary_helper.dart';
import 'package:zart/debugger.dart';
import 'package:zart/game_exception.dart';
import 'package:zart/header.dart';
import 'package:zart/engines/engine.dart';
import 'package:zart/math_helper.dart';
import 'package:zart/z_machine.dart';
import 'package:zart/zart.dart';
import 'package:zart/zscii.dart';
import 'mock_ui_provider.dart';
import 'mock_v3_machine.dart';
import 'package:zart/utils.dart' as utils;

import 'object_test.dart';

part 'integers_test.dart';
part 'math_test.dart';
part 'division_test.dart';
part 'binary_test.dart';
part 'memory_test.dart';

void main() {
  final s = Platform.pathSeparator;
  var defaultGameFile = 'assets${s}games${s}minizork.z3';

  final f = File(defaultGameFile);

  try {
    final rawBytes = f.readAsBytesSync();
    final data = Blorb.getZData(rawBytes);
    Z.load(data);
  } on Exception catch (fe) {
    //TODO log then print friendly
    stdout.writeln('$fe');
    exit(1);
  }

  const int version = 3;
  const int programCounterAddress =
      14297; // initial program counter address for minizork
  final machine = MockV3Machine();

  Debugger.initializeEngine(machine);
  Z.io = MockUIProvider();

  stdout.writeln(Debugger.dumpHeader());
  stdout.writeln(utils.generateObjectTree(1));

  group("All>", () {
    group('Maths>', () {
      mathTests();
    });

    group('Binary', () {
      binaryTests();
    });

    group('Z Memory> ', () {
      memoryTests(version, programCounterAddress);
    });

    group("Game Objects", (){
      objectTests();
    });
  });

  group('ZSCII Tests>', () {

    test("ZSCII.ZCharToChar(0) returns empty string''.", () {
      expect(ZSCII.zCharToChar(0), equals(""));
    });

    test("ZSCII.ZCharToChar(9) returns tab \\t.", () {
      expect(ZSCII.zCharToChar(9), equals('\t'));
    });


    test("ZSCII.ZCharToChar(11) returns double space '  '.", () {
      expect(ZSCII.zCharToChar(11), equals("  "));
    });

    test("ZSCII.ZCharToChar(13) returns newline \\n.", () {
      expect(ZSCII.zCharToChar(13), equals('\n'));
    });

    test("ZSCII.ZCharToChar(32-126) returns expected letter.", () {
      // ignore: unnecessary_string_escapes
      const ascii = " !\"#\$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~";
      for (var i = 0; i < 95; i++){

        expect(ZSCII.zCharToChar(i+32), equals(ascii[i]));
      }
    });

    test('Unicode translations work as expected in ZSCII.ZCharToChar().', () {
      var s = StringBuffer();
      for (int i = 155; i <= 223; i++) {
        s.writeCharCode(unicodeTranslations[i]!);
        expect(ZSCII.zCharToChar(i), equals(s.toString()));
        s.clear();
      }
    });

    test('ZSCII.readZString() returns the expected string from the address.',
        () {
      var addrStart = 0xb0a0;
      var addrEnd = 0xb0be;
      var testString = 'An old leather bag, bulging with coins, is here.';
      expect(ZSCII.readZString(addrStart), equals(testString));

      // address after string end should be at 0xb0be
      expect(Z.engine.callStack.pop(), equals(addrEnd));
    });
  });


  group("Object Tests", (){

  });
  // objectTests();

  // instructionTests();
}
