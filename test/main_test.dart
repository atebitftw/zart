library tests;

import 'dart:io';
import 'dart:math';

import 'package:test/test.dart';
import 'package:zart/binary_helper.dart';
import 'package:zart/debugger.dart';
import 'package:zart/game_exception.dart';
import 'package:zart/game_object.dart';
import 'package:zart/header.dart';
import 'package:zart/machines/machine.dart';
import 'package:zart/zart.dart';
import 'package:zart/zscii.dart';
import 'mock_ui_provider.dart';
import 'mock_v3_machine.dart';
import 'package:zart/utils.dart' as Utils;

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
    Z.load(f.readAsBytesSync());
  } on Exception catch (fe) {
    //TODO log then print friendly
    print('$fe');
    exit(1);
  }

  const int version = 3;
  const int programCounterAddress =
      14297; // initial program counter address for minizork
  final machine = MockV3Machine();

  Debugger.initializeMachine(machine);
  Z.IOConfig = MockUIProvider();

  print(Debugger.dumpHeader());

  // http://inform-fiction.org/zmachine/standards/z1point1/sect02.html

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
  });

  group('ZSCII Tests>', () {

    test("ZSCII.ZCharToChar(0) returns empty string''.", () {
      expect(ZSCII.ZCharToChar(0), equals(""));
    });

    test("ZSCII.ZCharToChar(9) returns tab \\t.", () {
      expect(ZSCII.ZCharToChar(9), equals('\t'));
    });

    test("ZSCII.ZCharToChar(11) returns space ' '.", () {
      expect(ZSCII.ZCharToChar(11), equals(' '));
    });

    test("ZSCII.ZCharToChar(13) returns newline \\n.", () {
      expect(ZSCII.ZCharToChar(13), equals('\n'));
    });

    test("ZSCII.ZCharToChar(33) returns 'a'.", () {
      expect(ZSCII.ZCharToChar(33), equals('a'));
    });

    test('Unicode translations work as expected in ZSCII.ZCharToChar().', () {
      var s = StringBuffer();
      for (int i = 155; i <= 223; i++) {
        s.writeCharCode(ZSCII.UNICODE_TRANSLATIONS['$i']);
        expect(ZSCII.ZCharToChar(i), equals(s.toString()));
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
      expect(Z.machine.callStack.pop(), equals(addrEnd));
    });
  });


  group("Object Tests", (){

  });
  // objectTests();

  // instructionTests();
}
