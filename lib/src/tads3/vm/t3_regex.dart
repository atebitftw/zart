// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// TADS3 Regular Expression Support
///
/// Translates TADS3 regex patterns to Dart [RegExp] patterns and provides
/// matching, searching, and replacement functionality.
library;

// ----------------------------------------------------------------------------
// Regex Group
// ----------------------------------------------------------------------------

/// Information about a captured group from a regex match.
class T3RegexGroup {
  /// Starting offset in the original string (byte offset for TADS compat).
  final int start;

  /// Ending offset (exclusive) in the original string.
  final int end;

  /// The matched text.
  final String text;

  T3RegexGroup(this.start, this.end, this.text);

  /// Length of the matched text.
  int get length => end - start;

  @override
  String toString() => 'T3RegexGroup($start, $end, "$text")';
}

// ----------------------------------------------------------------------------
// Regex Match Result
// ----------------------------------------------------------------------------

/// Result of a regex match or search operation.
class T3RegexMatch {
  /// The overall match start offset.
  final int start;

  /// The overall match end offset (exclusive).
  final int end;

  /// The matched text.
  final String text;

  /// Captured groups (index 0 is unused, 1-9 are group 1-9).
  final List<T3RegexGroup?> groups;

  T3RegexMatch(this.start, this.end, this.text, this.groups);

  /// Length of the match.
  int get length => end - start;
}

// ----------------------------------------------------------------------------
// Pattern Translation Maps
// ----------------------------------------------------------------------------

/// Named character literals that can appear in <...> sequences.
const _namedLiterals = <String, String>{
  'lparen': r'\(',
  'rparen': r'\)',
  'lsquare': r'\[',
  'rsquare': r'\]',
  'lbrace': r'\{',
  'rbrace': r'\}',
  'langle': '<',
  'rangle': '>',
  'vbar': r'\|',
  'caret': r'\^',
  'period': r'\.',
  'dot': r'\.',
  'squote': "'",
  'dquote': '"',
  'star': r'\*',
  'plus': r'\+',
  'percent': '%',
  'question': r'\?',
  'dollar': r'\$',
  'backslash': r'\\',
  'return': r'\r',
  'linefeed': r'\n',
  'tab': r'\t',
  'nul': r'\x00',
  'null': r'\x00',
};

/// Named character classes that can appear in <...> sequences.
const _namedClasses = <String, String>{
  'alpha': r'[a-zA-Z]',
  'upper': r'[A-Z]',
  'lower': r'[a-z]',
  'digit': r'[0-9]',
  'alphanum': r'[a-zA-Z0-9]',
  'space': r'[ \t]',
  'vspace': r'[\r\n\v\f\u2028\u2029]',
  'punct': r'''[!"#$%&'()*+,\-./:;<=>?@\[\\\]^_`{|}~]''',
  'newline': r'[\r\n\u2028\u2029]',
};

/// Mode flags that modify regex behavior.
const _modeFlags = <String>{'case', 'nocase', 'min', 'max', 'fe', 'fb', 'firstend', 'firstbegin'};

// ----------------------------------------------------------------------------
// T3Regex
// ----------------------------------------------------------------------------

/// TADS3 Regular Expression wrapper.
///
/// Translates TADS3 regex syntax to Dart [RegExp] and provides matching,
/// searching, and replacement functionality compatible with TADS3 semantics.
class T3Regex {
  /// The original TADS3 pattern string.
  final String tadsPattern;

  /// The translated Dart regex pattern.
  late final String dartPattern;

  /// The compiled Dart regex.
  late final RegExp _regex;

  /// Whether matching is case-sensitive.
  late final bool caseSensitive;

  /// Whether to prefer shortest match (non-greedy overall).
  late final bool shortestMatch;

  /// Whether to prefer earliest-ending match.
  late final bool firstEnd;

  /// Number of capturing groups in the pattern.
  late final int groupCount;

  /// Last match result (for re_group lookups).
  T3RegexMatch? _lastMatch;

  /// Last search string (needed for group substring extraction).
  // ignore: unused_field
  String? _lastSearchString;

  /// Create a regex from a TADS3 pattern string.
  T3Regex(this.tadsPattern) {
    final result = _translatePattern(tadsPattern);
    dartPattern = result.pattern;
    caseSensitive = result.caseSensitive;
    shortestMatch = result.shortestMatch;
    firstEnd = result.firstEnd;
    groupCount = result.groupCount;

    _regex = RegExp(dartPattern, caseSensitive: caseSensitive, unicode: true);
  }

  /// Create from a pre-compiled [RegExp] (for internal use).
  T3Regex.fromRegExp(this.tadsPattern, RegExp regex)
    : dartPattern = regex.pattern,
      caseSensitive = regex.isCaseSensitive,
      shortestMatch = false,
      firstEnd = false,
      groupCount = 0,
      _regex = regex;

  /// Get the last match result.
  T3RegexMatch? get lastMatch => _lastMatch;

  /// Match the pattern at the start of [str] (or at [startIndex]).
  ///
  /// Returns the match length if successful, or null if no match.
  int? match(String str, [int startIndex = 0]) {
    _lastSearchString = str;

    if (startIndex > str.length) {
      _lastMatch = null;
      return null;
    }

    // For match(), we need to anchor at startIndex
    final substring = str.substring(startIndex);
    final match = _regex.matchAsPrefix(substring);

    if (match == null) {
      _lastMatch = null;
      return null;
    }

    _lastMatch = _buildMatchResult(match, str, startIndex);
    return _lastMatch!.length;
  }

  /// Search for the pattern anywhere in [str] starting from [startIndex].
  ///
  /// Returns the match offset if found, or null if not found.
  int? search(String str, [int startIndex = 0]) {
    _lastSearchString = str;

    if (startIndex > str.length) {
      _lastMatch = null;
      return null;
    }

    final substring = str.substring(startIndex);
    final match = _regex.firstMatch(substring);

    if (match == null) {
      _lastMatch = null;
      return null;
    }

    _lastMatch = _buildMatchResult(match, str, startIndex);
    return _lastMatch!.start;
  }

  /// Search backwards for the pattern in [str] ending before [endIndex].
  ///
  /// Returns the match offset if found, or null if not found.
  int? searchBack(String str, [int? endIndex]) {
    _lastSearchString = str;
    endIndex ??= str.length;

    if (endIndex <= 0) {
      _lastMatch = null;
      return null;
    }

    // Find all matches and take the last one that ends before endIndex
    final substring = str.substring(0, endIndex);
    Match? lastFoundMatch;

    for (final match in _regex.allMatches(substring)) {
      if (match.end <= endIndex) {
        lastFoundMatch = match;
      }
    }

    if (lastFoundMatch == null) {
      _lastMatch = null;
      return null;
    }

    _lastMatch = _buildMatchResult(lastFoundMatch, str, 0);
    return _lastMatch!.start;
  }

  /// Get captured group [n] from the last match.
  ///
  /// Returns null if there was no match or the group didn't participate.
  /// Group 0 is the entire match, groups 1-9 are captured groups.
  T3RegexGroup? group(int n) {
    if (_lastMatch == null) return null;
    if (n < 0 || n >= _lastMatch!.groups.length) return null;
    return _lastMatch!.groups[n];
  }

  /// Replace matches in [str] with [replacement].
  ///
  /// [flags] controls replacement mode:
  /// - `ReplaceAll` (1): Replace all occurrences
  /// - `ReplaceOnce` (default): Replace only first occurrence
  ///
  /// The replacement string can contain `%n` for group backreferences.
  String replace(String str, String replacement, [int flags = 0, int? index]) {
    final replaceAll = (flags & 1) != 0;
    final startIndex = index ?? 0;

    if (startIndex > str.length) return str;

    // Translate TADS replacement syntax to Dart
    final dartReplacement = _translateReplacement(replacement);

    if (startIndex == 0) {
      if (replaceAll) {
        return str.replaceAllMapped(_regex, (m) => _applyReplacement(m, dartReplacement));
      } else {
        return str.replaceFirstMapped(_regex, (m) => _applyReplacement(m, dartReplacement));
      }
    }

    // Handle startIndex by preserving prefix
    final prefix = str.substring(0, startIndex);
    final suffix = str.substring(startIndex);

    if (replaceAll) {
      return prefix + suffix.replaceAllMapped(_regex, (m) => _applyReplacement(m, dartReplacement));
    } else {
      return prefix + suffix.replaceFirstMapped(_regex, (m) => _applyReplacement(m, dartReplacement));
    }
  }

  /// Build a [T3RegexMatch] from a Dart [Match].
  T3RegexMatch _buildMatchResult(Match match, String fullString, int offset) {
    final groups = <T3RegexGroup?>[];

    // Group 0 is the entire match
    groups.add(T3RegexGroup(match.start + offset, match.end + offset, match.group(0) ?? ''));

    // Groups 1-9
    for (var i = 1; i <= 9; i++) {
      if (i <= match.groupCount) {
        final groupText = match.group(i);
        if (groupText != null) {
          // Calculate group offsets - this is tricky with Dart's Match
          // We need to find where the group appears in the match
          final groupStart = fullString.indexOf(groupText, match.start + offset);
          groups.add(T3RegexGroup(groupStart, groupStart + groupText.length, groupText));
        } else {
          groups.add(null);
        }
      } else {
        groups.add(null);
      }
    }

    return T3RegexMatch(match.start + offset, match.end + offset, match.group(0) ?? '', groups);
  }

  /// Apply replacement with group backreferences.
  String _applyReplacement(Match match, String replacement) {
    var result = replacement;

    // Replace \n with group n
    for (var i = 0; i <= 9 && i <= match.groupCount; i++) {
      final groupText = match.group(i) ?? '';
      result = result.replaceAll('\\$i', groupText);
    }

    return result;
  }

  /// Translate TADS replacement string to Dart format.
  String _translateReplacement(String replacement) {
    final buffer = StringBuffer();
    var i = 0;

    while (i < replacement.length) {
      final c = replacement[i];

      if (c == '%' && i + 1 < replacement.length) {
        final next = replacement[i + 1];
        if (next == '%') {
          buffer.write('%');
          i += 2;
        } else if (next.codeUnitAt(0) >= 0x30 && next.codeUnitAt(0) <= 0x39) {
          // %1-%9 -> \1-\9
          buffer.write('\\$next');
          i += 2;
        } else {
          buffer.write(c);
          i++;
        }
      } else {
        buffer.write(c);
        i++;
      }
    }

    return buffer.toString();
  }

  @override
  String toString() => 'T3Regex("$tadsPattern" -> "$dartPattern")';
}

// ----------------------------------------------------------------------------
// Pattern Translation Result
// ----------------------------------------------------------------------------

class _TranslationResult {
  final String pattern;
  final bool caseSensitive;
  final bool shortestMatch;
  final bool firstEnd;
  final int groupCount;

  _TranslationResult({
    required this.pattern,
    this.caseSensitive = true,
    this.shortestMatch = false,
    this.firstEnd = false,
    this.groupCount = 0,
  });
}

// ----------------------------------------------------------------------------
// Pattern Translation
// ----------------------------------------------------------------------------

/// Translate a TADS3 regex pattern to Dart regex syntax.
_TranslationResult _translatePattern(String tadsPattern) {
  final buffer = StringBuffer();
  var caseSensitive = true;
  var shortestMatch = false;
  var firstEnd = false;
  var groupCount = 0;
  var i = 0;

  while (i < tadsPattern.length) {
    final c = tadsPattern[i];

    if (c == '%') {
      // TADS escape sequence
      if (i + 1 >= tadsPattern.length) {
        buffer.write('%');
        i++;
        continue;
      }

      final next = tadsPattern[i + 1];
      switch (next) {
        case '%':
          buffer.write('%');
          i += 2;
        case 'd':
          buffer.write(r'\d');
          i += 2;
        case 'D':
          buffer.write(r'\D');
          i += 2;
        case 's':
          buffer.write(r'\s');
          i += 2;
        case 'S':
          buffer.write(r'\S');
          i += 2;
        case 'w':
          buffer.write(r'\w');
          i += 2;
        case 'W':
          buffer.write(r'\W');
          i += 2;
        case 'b':
          buffer.write(r'\b');
          i += 2;
        case 'B':
          buffer.write(r'\B');
          i += 2;
        case '<':
          // Word start: \b followed by word char
          buffer.write(r'\b(?=\w)');
          i += 2;
        case '>':
          // Word end: after word char, before \b
          buffer.write(r'(?<=\w)\b');
          i += 2;
        case 'v':
          buffer.write(r'[\r\n\v\f\u2028\u2029]');
          i += 2;
        case 'V':
          buffer.write(r'[^\r\n\v\f\u2028\u2029]');
          i += 2;
        case '1':
        case '2':
        case '3':
        case '4':
        case '5':
        case '6':
        case '7':
        case '8':
        case '9':
          // Backreference
          buffer.write('\\$next');
          i += 2;
        case '^':
        case r'$':
        case '|':
        case '.':
        case '(':
        case ')':
        case '*':
        case '?':
        case '+':
        case '[':
          // Escaped special char
          buffer.write('\\$next');
          i += 2;
        default:
          // Unknown escape, pass through
          buffer.write('%$next');
          i += 2;
      }
    } else if (c == '<') {
      // Named sequence <...>
      final closeIdx = tadsPattern.indexOf('>', i);
      if (closeIdx == -1) {
        buffer.write('<');
        i++;
        continue;
      }

      final content = tadsPattern.substring(i + 1, closeIdx).toLowerCase();
      i = closeIdx + 1;

      // Check for mode flags
      if (_modeFlags.contains(content)) {
        switch (content) {
          case 'case':
            caseSensitive = true;
          case 'nocase':
            caseSensitive = false;
          case 'min':
            shortestMatch = true;
          case 'max':
            shortestMatch = false;
          case 'fe':
          case 'firstend':
            firstEnd = true;
          case 'fb':
          case 'firstbegin':
            firstEnd = false;
        }
        continue;
      }

      // Check for exclusion
      var exclusion = false;
      var classContent = content;
      if (classContent.startsWith('^')) {
        exclusion = true;
        classContent = classContent.substring(1);
      }

      // Parse pipe-separated components
      final components = classContent.split('|');
      final charClassParts = <String>[];

      for (final comp in components) {
        final trimmed = comp.trim();
        if (trimmed.isEmpty) continue;

        // Check for named literal
        if (_namedLiterals.containsKey(trimmed)) {
          charClassParts.add(_namedLiterals[trimmed]!);
        }
        // Check for named class
        else if (_namedClasses.containsKey(trimmed)) {
          charClassParts.add(_namedClasses[trimmed]!);
        }
        // Check for range a-z
        else if (trimmed.length == 3 && trimmed[1] == '-') {
          charClassParts.add('${trimmed[0]}-${trimmed[2]}');
        }
        // Single character
        else if (trimmed.length == 1) {
          // Escape if needed
          if (r'[]^-\'.contains(trimmed)) {
            charClassParts.add('\\$trimmed');
          } else {
            charClassParts.add(trimmed);
          }
        }
        // Unknown, pass through
        else {
          charClassParts.add(trimmed);
        }
      }

      if (charClassParts.isNotEmpty) {
        // Combine into character class
        final combined = _combineCharClassParts(charClassParts, exclusion);
        buffer.write(combined);
      }
    } else if (c == '(') {
      // Count groups
      if (i + 1 < tadsPattern.length && tadsPattern[i + 1] != '?') {
        groupCount++;
      }
      buffer.write(c);
      i++;
    } else {
      buffer.write(c);
      i++;
    }
  }

  return _TranslationResult(
    pattern: buffer.toString(),
    caseSensitive: caseSensitive,
    shortestMatch: shortestMatch,
    firstEnd: firstEnd,
    groupCount: groupCount,
  );
}

/// Combine character class parts into a single regex fragment.
String _combineCharClassParts(List<String> parts, bool exclusion) {
  // If there's only one complete class like [a-zA-Z], use it directly
  if (parts.length == 1) {
    final part = parts[0];
    if (part.startsWith('[') && part.endsWith(']')) {
      if (exclusion) {
        // Convert [abc] to [^abc]
        return '[^${part.substring(1, part.length - 1)}]';
      }
      return part;
    }
  }

  // Combine all parts into one character class
  final buffer = StringBuffer();
  buffer.write(exclusion ? '[^' : '[');

  for (final part in parts) {
    if (part.startsWith('[') && part.endsWith(']')) {
      // Extract contents from existing class
      buffer.write(part.substring(1, part.length - 1));
    } else {
      buffer.write(part);
    }
  }

  buffer.write(']');
  return buffer.toString();
}

// ----------------------------------------------------------------------------
// Global Regex State (for BIF functions)
// ----------------------------------------------------------------------------

/// Global regex state for BIF function access.
class T3RegexState {
  /// The current regex pattern (compiled or string).
  T3Regex? currentRegex;

  /// Reset state.
  void reset() {
    currentRegex = null;
  }
}
