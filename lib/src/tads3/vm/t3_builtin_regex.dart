import 'package:zart/src/loaders/tads/t3_exception.dart';
import 'package:zart/src/tads3/vm/t3_interpreter.dart';
import 'package:zart/src/tads3/vm/t3_regex_pattern.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';

/// Regex built-in functions for TADS 3.
/// Includes: re_match, re_search, re_group, re_replace
class T3BuiltinRegex {
  /// Helper to get RegExp from string or RegexPattern object.
  static RegExp _getRegExp(
    T3Interpreter interp,
    T3Value patVal, {
    bool caseSensitive = true,
  }) {
    if (patVal.isObject) {
      final obj = interp.objectTable.lookup(patVal.value);
      if (obj is T3RegexPattern) {
        // Optimization: Use cached regex if default flags (case sensitive)
        // TADS 3 patterns compiled are case sensitive by default (unless patterns have flags)
        // If we need case sensitive (default), we use the cached one.
        if (caseSensitive) {
          return obj.getRegExp(interp);
        }
        // If flags differ (e.g. case insensitive requested), compile from source
        final pattern = interp.getStringValue(obj.source);
        return RegExp(pattern, caseSensitive: caseSensitive);
      }
    }
    // Fallback to string handling
    final pattern = interp.getStringValue(patVal);
    return RegExp(pattern, caseSensitive: caseSensitive);
  }

  /// Helper to get pattern string for error reporting
  static String _getPatternStr(T3Interpreter interp, T3Value patVal) {
    if (patVal.isObject) {
      final obj = interp.objectTable.lookup(patVal.value);
      if (obj is T3RegexPattern) {
        return interp.getStringValue(obj.source);
      }
    }
    return interp.getStringValue(patVal);
  }

  /// re_match(pattern, str, index?) - Match regex at start of string.
  /// Ref: vmbiftad.cpp line 2426
  /// Returns match length or nil if no match.
  static void reMatch(T3Interpreter interp, int argc) {
    if (argc < 2) throw T3Exception('re_match() requires 2-3 arguments');

    final patVal = interp.stack.pop();
    final strVal = interp.stack.pop();
    final startIdx = argc >= 3 ? interp.stack.pop().numToInt() : 1;

    if (argc > 3) interp.stack.discard(argc - 3);

    final str = interp.getStringValue(strVal);

    // Adjust to 0-based index
    int idx = startIdx < 0 ? str.length + startIdx : startIdx - 1;
    if (idx < 0) idx = 0;
    if (idx > str.length) idx = str.length;

    final substring = str.substring(idx);

    try {
      final regex = _getRegExp(interp, patVal);
      final match = regex.matchAsPrefix(substring) as RegExpMatch?;

      if (match != null) {
        interp.lastRegexMatch = match;
        interp.lastRegexString = str;
        // Return character length of match
        interp.registers.r0 = T3Value.fromInt(match.end - match.start);
      } else {
        interp.lastRegexMatch = null;
        interp.lastRegexString = null;
        interp.registers.r0 = T3Value.nil();
      }
    } catch (e) {
      throw T3Exception(
        'Invalid regex pattern: ${_getPatternStr(interp, patVal)}',
      );
    }
  }

  /// re_search(pattern, str, index?) - Search for regex in string.
  /// Ref: vmbiftad.cpp line 2694
  /// Returns [matchStart, matchLen, matchStr] or nil if not found.
  static void reSearch(T3Interpreter interp, int argc) {
    if (argc < 2) throw T3Exception('re_search() requires 2-3 arguments');

    final patVal = interp.stack.pop();
    final strVal = interp.stack.pop();
    final startIdx = argc >= 3 ? interp.stack.pop().numToInt() : 1;

    if (argc > 3) interp.stack.discard(argc - 3);

    final str = interp.getStringValue(strVal);

    // Adjust to 0-based index
    int idx = startIdx < 0 ? str.length + startIdx : startIdx - 1;
    if (idx < 0) idx = 0;
    if (idx > str.length) idx = str.length;

    final substring = str.substring(idx);

    try {
      final regex = _getRegExp(interp, patVal);
      final match = regex.firstMatch(substring);

      if (match != null) {
        interp.lastRegexMatch = match;
        interp.lastRegexString = str;

        // Return [matchStart (1-based), matchLen, matchStr]
        final matchStart = idx + match.start + 1;
        final matchLen = match.end - match.start;
        final matchStr = match.group(0) ?? '';

        final strOffset = interp.addDynamicString(matchStr);
        final list = [
          T3Value.fromInt(matchStart),
          T3Value.fromInt(matchLen),
          T3Value.fromString(strOffset),
        ];

        final offset = interp.addDynamicList(list);
        interp.registers.r0 = T3Value.fromList(offset);
      } else {
        interp.lastRegexMatch = null;
        interp.lastRegexString = null;
        interp.registers.r0 = T3Value.nil();
      }
    } catch (e) {
      throw T3Exception(
        'Invalid regex pattern: ${_getPatternStr(interp, patVal)}',
      );
    }
  }

  /// re_search_back(pattern, str, index?) - Search backwards for regex.
  /// Ref: vmbiftad.cpp line 2710
  /// Returns [matchStart, matchLen, matchStr] or nil if not found.
  static void reSearchBack(T3Interpreter interp, int argc) {
    if (argc < 2) throw T3Exception('re_search_back() requires 2-3 arguments');

    final patVal = interp.stack.pop();
    final strVal = interp.stack.pop();
    final startIdx = argc >= 3 ? interp.stack.pop().numToInt() : -1;

    if (argc > 3) interp.stack.discard(argc - 3);

    final str = interp.getStringValue(strVal);

    // If startIdx is -1 (default), start from the end of the string.
    // TADS indices are 1-based.
    int idx = startIdx == -1
        ? str.length
        : (startIdx < 0 ? str.length + startIdx + 1 : startIdx);
    if (idx < 0) idx = 0;
    if (idx > str.length) idx = str.length;

    // Search backwards by checking all possible endings
    try {
      final regex = _getRegExp(interp, patVal);

      RegExpMatch? lastMatch;
      for (var i = idx; i >= 0; i--) {
        final substring = str.substring(0, i);
        final matches = regex.allMatches(substring);
        if (matches.isNotEmpty) {
          // Find the match that ends closest to i
          for (final m in matches) {
            if (m.end == i) {
              lastMatch = m;
              break;
            }
          }
          if (lastMatch != null) break;
        }
      }

      if (lastMatch != null) {
        interp.lastRegexMatch = lastMatch;
        interp.lastRegexString = str;

        final matchStart = lastMatch.start + 1;
        final matchLen = lastMatch.end - lastMatch.start;
        final matchStr = lastMatch.group(0) ?? '';

        final strOffset = interp.addDynamicString(matchStr);
        final list = [
          T3Value.fromInt(matchStart),
          T3Value.fromInt(matchLen),
          T3Value.fromString(strOffset),
        ];

        final offset = interp.addDynamicList(list);
        interp.registers.r0 = T3Value.fromList(offset);
      } else {
        interp.lastRegexMatch = null;
        interp.lastRegexString = null;
        interp.registers.r0 = T3Value.nil();
      }
    } catch (e) {
      throw T3Exception(
        'Invalid regex pattern: ${_getPatternStr(interp, patVal)}',
      );
    }
  }

  /// re_group(n) - Get captured group from last match.
  /// Ref: vmbiftad.cpp line 2712
  /// Group 0 = entire match, 1+ = capture groups.
  /// Returns [groupStart, groupLen, groupStr] or nil.
  static void reGroup(T3Interpreter interp, int argc) {
    if (argc < 1) throw T3Exception('re_group() requires 1 argument');

    final groupNo = interp.stack.pop().numToInt();
    if (argc > 1) interp.stack.discard(argc - 1);

    if (interp.lastRegexMatch == null || interp.lastRegexString == null) {
      interp.registers.r0 = T3Value.nil();
      return;
    }

    final match = interp.lastRegexMatch!;

    // Check group number
    if (groupNo < 0 || groupNo > match.groupCount) {
      interp.registers.r0 = T3Value.nil();
      return;
    }

    final groupStr = match.group(groupNo);
    if (groupStr == null) {
      interp.registers.r0 = T3Value.nil();
      return;
    }

    // Find group position in original string
    // NOTE: Dart's RegExpMatch doesn't provide group offsets directly.
    // We attempt to find the group string within the match string.
    // If the group matches an empty string, we use the match start.
    int matchStart = match.start;
    String fullMatch = match.group(0)!;
    int groupInMatchIdx = fullMatch.indexOf(groupStr);

    // TADS indices are 1-based
    int groupStart = matchStart + groupInMatchIdx + 1;
    int groupLen = groupStr.length;

    final strOffset = interp.addDynamicString(groupStr);
    final list = [
      T3Value.fromInt(groupStart),
      T3Value.fromInt(groupLen),
      T3Value.fromString(strOffset),
    ];

    final offset = interp.addDynamicList(list);
    interp.registers.r0 = T3Value.fromList(offset);
  }

  /// re_replace(pattern, str, replacement, flags?, index?) - Replace matches.
  /// Ref: vmbiftad.cpp line 2813
  static void reReplace(T3Interpreter interp, int argc) {
    if (argc < 3) throw T3Exception('re_replace() requires 3-5 arguments');

    final patVal = interp.stack.pop();
    final strVal = interp.stack.pop();
    final replVal = interp.stack.pop();

    // Flags: 1 = replace all, 2 = case insensitive
    int flags = 0;
    if (argc >= 4) flags = interp.stack.pop().numToInt();

    // Start index
    int startIdx = 1;
    if (argc >= 5) startIdx = interp.stack.pop().numToInt();

    if (argc > 5) interp.stack.discard(argc - 5);

    final str = interp.getStringValue(strVal);
    String replacement = interp.getStringValue(replVal);

    // TADS replacement strings use %n for groups, Dart uses $n.
    // Also %% becomes % in TADS.
    replacement = replacement.replaceAllMapped(RegExp(r'%(%|\d)'), (m) {
      final val = m.group(1);
      if (val == '%') return '%';
      return '\$${val}';
    });

    final replaceAll = (flags & 1) != 0;
    final caseInsensitive = (flags & 2) != 0;

    // Adjust to 0-based index
    int idx = startIdx < 0 ? str.length + startIdx : startIdx - 1;
    if (idx < 0) idx = 0;
    if (idx > str.length) idx = str.length;

    try {
      final regex = _getRegExp(interp, patVal, caseSensitive: !caseInsensitive);

      String applyReplacement(Match m) {
        return replacement.replaceAllMapped(RegExp(r'\$(\d)'), (rm) {
          int groupNum = int.parse(rm.group(1)!);
          return m.group(groupNum) ?? '';
        });
      }

      String result;
      if (idx == 0) {
        result = replaceAll
            ? str.replaceAllMapped(regex, applyReplacement)
            : str.replaceFirstMapped(regex, applyReplacement);
      } else {
        // Replace only in substring, then rejoin
        final prefix = str.substring(0, idx);
        final suffix = str.substring(idx);
        final replaced = replaceAll
            ? suffix.replaceAllMapped(regex, applyReplacement)
            : suffix.replaceFirstMapped(regex, applyReplacement);
        result = prefix + replaced;
      }

      final offset = interp.addDynamicString(result);
      interp.registers.r0 = T3Value.fromString(offset);
    } catch (e) {
      throw T3Exception(
        'Invalid regex pattern: ${_getPatternStr(interp, patVal)}',
      );
    }
  }
}
