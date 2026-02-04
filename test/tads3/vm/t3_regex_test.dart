// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:zart/src/tads3/vm/t3_regex.dart';

void main() {
  group('T3Regex Pattern Translation', () {
    group('Basic escapes', () {
      test('%d translates to \\d', () {
        final regex = T3Regex('%d+');
        expect(regex.dartPattern, equals(r'\d+'));
      });

      test('%D translates to \\D', () {
        final regex = T3Regex('%D+');
        expect(regex.dartPattern, equals(r'\D+'));
      });

      test('%s translates to \\s', () {
        final regex = T3Regex('%s+');
        expect(regex.dartPattern, equals(r'\s+'));
      });

      test('%S translates to \\S', () {
        final regex = T3Regex('%S+');
        expect(regex.dartPattern, equals(r'\S+'));
      });

      test('%w translates to \\w', () {
        final regex = T3Regex('%w+');
        expect(regex.dartPattern, equals(r'\w+'));
      });

      test('%W translates to \\W', () {
        final regex = T3Regex('%W+');
        expect(regex.dartPattern, equals(r'\W+'));
      });

      test('%b translates to \\b', () {
        final regex = T3Regex('%b');
        expect(regex.dartPattern, equals(r'\b'));
      });

      test('%B translates to \\B', () {
        final regex = T3Regex('%B');
        expect(regex.dartPattern, equals(r'\B'));
      });

      test('%% translates to %', () {
        final regex = T3Regex('100%%');
        expect(regex.dartPattern, equals('100%'));
      });

      test('%< (word start) translates correctly', () {
        final regex = T3Regex('%<word');
        expect(regex.dartPattern, contains(r'\b'));
      });

      test('%> (word end) translates correctly', () {
        final regex = T3Regex('word%>');
        expect(regex.dartPattern, contains(r'\b'));
      });
    });

    group('Backreferences', () {
      test('%1-%9 translate to \\1-\\9', () {
        final regex = T3Regex('(.)%1');
        expect(regex.dartPattern, equals(r'(.)\1'));
      });
    });

    group('Named literals', () {
      test('<lparen> translates to \\(', () {
        final regex = T3Regex('<lparen>');
        expect(regex.dartPattern, equals(r'[\(]'));
      });

      test('<tab> translates to \\t', () {
        final regex = T3Regex('<tab>');
        expect(regex.dartPattern, equals(r'[\t]'));
      });

      test('<period> translates to \\.', () {
        final regex = T3Regex('<period>');
        expect(regex.dartPattern, equals(r'[\.]'));
      });
    });

    group('Named classes', () {
      test('<Alpha> translates to [a-zA-Z]', () {
        final regex = T3Regex('<Alpha>');
        expect(regex.dartPattern, equals('[a-zA-Z]'));
      });

      test('<Upper> translates to [A-Z]', () {
        final regex = T3Regex('<Upper>');
        expect(regex.dartPattern, equals('[A-Z]'));
      });

      test('<Lower> translates to [a-z]', () {
        final regex = T3Regex('<Lower>');
        expect(regex.dartPattern, equals('[a-z]'));
      });

      test('<Digit> translates to [0-9]', () {
        final regex = T3Regex('<Digit>');
        expect(regex.dartPattern, equals('[0-9]'));
      });

      test('<AlphaNum> translates to [a-zA-Z0-9]', () {
        final regex = T3Regex('<AlphaNum>');
        expect(regex.dartPattern, equals('[a-zA-Z0-9]'));
      });

      test('<Space> translates to [ \\t]', () {
        final regex = T3Regex('<Space>');
        expect(regex.dartPattern, equals(r'[ \t]'));
      });
    });

    group('Combined classes', () {
      test('<Upper|Digit> combines classes', () {
        final regex = T3Regex('<Upper|Digit>');
        expect(regex.dartPattern, contains('A-Z'));
        expect(regex.dartPattern, contains('0-9'));
      });

      test('<Alpha|Star|Plus> combines class with literals', () {
        final regex = T3Regex('<Alpha|Star|Plus>');
        expect(regex.dartPattern, contains('a-zA-Z'));
      });

      test('<^Alpha> creates exclusion class', () {
        final regex = T3Regex('<^Alpha>');
        expect(regex.dartPattern, contains('[^'));
      });
    });

    group('Mode flags', () {
      test('<Case> sets caseSensitive to true', () {
        final regex = T3Regex('<Case>abc');
        expect(regex.caseSensitive, isTrue);
      });

      test('<NoCase> sets caseSensitive to false', () {
        final regex = T3Regex('<NoCase>abc');
        expect(regex.caseSensitive, isFalse);
      });

      test('<Min> sets shortestMatch to true', () {
        final regex = T3Regex('<Min>abc');
        expect(regex.shortestMatch, isTrue);
      });

      test('<Max> sets shortestMatch to false', () {
        final regex = T3Regex('<Max>abc');
        expect(regex.shortestMatch, isFalse);
      });

      test('<FirstEnd> sets firstEnd to true', () {
        final regex = T3Regex('<FirstEnd>abc');
        expect(regex.firstEnd, isTrue);
      });

      test('<FE> is alias for FirstEnd', () {
        final regex = T3Regex('<FE>abc');
        expect(regex.firstEnd, isTrue);
      });
    });

    group('Group counting', () {
      test('counts capturing groups', () {
        final regex = T3Regex('(a)(b)(c)');
        expect(regex.groupCount, equals(3));
      });

      test('does not count non-capturing groups', () {
        final regex = T3Regex('(?:a)(b)');
        expect(regex.groupCount, equals(1));
      });
    });
  });

  group('T3Regex Matching', () {
    test('match returns length on success', () {
      final regex = T3Regex('hello');
      final result = regex.match('hello world');
      expect(result, equals(5));
    });

    test('match returns null on failure', () {
      final regex = T3Regex('hello');
      final result = regex.match('goodbye world');
      expect(result, isNull);
    });

    test('match respects startIndex', () {
      final regex = T3Regex('world');
      final result = regex.match('hello world', 6);
      expect(result, equals(5));
    });

    test('match at startIndex requires pattern at that position', () {
      final regex = T3Regex('world');
      final result = regex.match('hello world', 0);
      expect(result, isNull);
    });

    test('match with digits', () {
      final regex = T3Regex('%d+');
      final result = regex.match('12345abc');
      expect(result, equals(5));
    });
  });

  group('T3Regex Searching', () {
    test('search returns offset on success', () {
      final regex = T3Regex('world');
      final result = regex.search('hello world');
      expect(result, equals(6));
    });

    test('search returns null on failure', () {
      final regex = T3Regex('xyz');
      final result = regex.search('hello world');
      expect(result, isNull);
    });

    test('search respects startIndex', () {
      final regex = T3Regex('o');
      final result = regex.search('hello world', 5);
      expect(result, equals(7)); // second 'o' in 'world'
    });

    test('search finds pattern with %w', () {
      final regex = T3Regex('%w+');
      final result = regex.search('  hello  ');
      expect(result, equals(2));
    });
  });

  group('T3Regex searchBack', () {
    test('searchBack finds last occurrence', () {
      final regex = T3Regex('o');
      final result = regex.searchBack('hello world');
      expect(result, equals(7)); // 'o' in 'world'
    });

    test('searchBack respects endIndex', () {
      final regex = T3Regex('o');
      final result = regex.searchBack('hello world', 5);
      expect(result, equals(4)); // 'o' in 'hello'
    });

    test('searchBack returns null when not found', () {
      final regex = T3Regex('xyz');
      final result = regex.searchBack('hello world');
      expect(result, isNull);
    });
  });

  group('T3Regex Groups', () {
    test('group 0 returns entire match', () {
      final regex = T3Regex('(hello) (world)');
      regex.match('hello world');

      final group0 = regex.group(0);
      expect(group0, isNotNull);
      expect(group0!.text, equals('hello world'));
    });

    test('group 1 returns first capture', () {
      final regex = T3Regex('(hello) (world)');
      regex.match('hello world');

      final group1 = regex.group(1);
      expect(group1, isNotNull);
      expect(group1!.text, equals('hello'));
    });

    test('group 2 returns second capture', () {
      final regex = T3Regex('(hello) (world)');
      regex.match('hello world');

      final group2 = regex.group(2);
      expect(group2, isNotNull);
      expect(group2!.text, equals('world'));
    });

    test('group returns null for unmatched group', () {
      final regex = T3Regex('(hello)');
      regex.match('hello world');

      expect(regex.group(5), isNull);
    });

    test('group returns null before any match', () {
      final regex = T3Regex('hello');
      expect(regex.group(0), isNull);
    });
  });

  group('T3Regex Replace', () {
    test('replace first occurrence', () {
      final regex = T3Regex('o');
      final result = regex.replace('hello world', 'O');
      expect(result, equals('hellO world'));
    });

    test('replace all occurrences with flag', () {
      final regex = T3Regex('o');
      final result = regex.replace('hello world', 'O', 1); // ReplaceAll
      expect(result, equals('hellO wOrld'));
    });

    test('replace with backreference', () {
      final regex = T3Regex('(%w+) (%w+)');
      final result = regex.replace('hello world', '%2 %1');
      expect(result, equals('world hello'));
    });

    test('replace respects startIndex', () {
      final regex = T3Regex('o');
      final result = regex.replace('hello world', 'O', 0, 5);
      expect(result, equals('hello wOrld')); // Only affects after index 5
    });
  });

  group('T3Regex Case Sensitivity', () {
    test('case-sensitive by default', () {
      final regex = T3Regex('HELLO');
      expect(regex.match('hello'), isNull);
    });

    test('<NoCase> makes case-insensitive', () {
      final regex = T3Regex('<NoCase>HELLO');
      expect(regex.match('hello'), equals(5));
    });
  });

  group('T3Regex Edge Cases', () {
    test('empty pattern matches empty string', () {
      final regex = T3Regex('');
      expect(regex.match(''), equals(0));
    });

    test('pattern longer than string returns null', () {
      final regex = T3Regex('verylongpattern');
      expect(regex.match('short'), isNull);
    });

    test('startIndex beyond string length returns null', () {
      final regex = T3Regex('a');
      expect(regex.match('hello', 100), isNull);
    });

    test('special regex chars in TADS pattern', () {
      final regex = T3Regex('%.%*%+');
      expect(regex.dartPattern, equals(r'\.\*\+'));
    });
  });
}
