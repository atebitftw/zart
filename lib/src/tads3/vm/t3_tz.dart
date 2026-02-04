// Copyright (c) 2026, the Zart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// TADS3 Time Zone Engine
///
/// This library implements the TADS3 time zone engine, providing
/// support for historical time zone transitions, daylight savings rules,
/// and name lookups.
///
/// Ported from vmtz.cpp and vmtz.h.
library;

import 'dart:typed_data';
import 'dart:io';
import 'package:zart/src/tads3/vm/t3_error.dart';

// ----------------------------------------------------------------------------
// Constants
// ----------------------------------------------------------------------------

const int _transSize = 9;
const int _ruleSize = 17;
const int _typeSize = 9;

// ----------------------------------------------------------------------------
// Data Structures
// ----------------------------------------------------------------------------

/// Time zone transition type
class T3TimeZoneType {
  /// GMT offset in milliseconds
  final int gmtOffset;

  /// DST savings in milliseconds
  final int save;

  /// Abbreviation index (into the zone's abbr block)
  final int abbrIdx;

  /// Abbreviation string (resolved later)
  String? abbr;

  T3TimeZoneType(this.gmtOffset, this.save, this.abbrIdx);
}

/// Time zone transition
class T3TimeZoneTrans {
  /// Day number (TADS epoch: March 1, 0000)
  final int dayno;

  /// Time of day in milliseconds UTC
  final int daytime;

  /// Pointer to the type for this period
  final T3TimeZoneType type;

  T3TimeZoneTrans(this.dayno, this.daytime, this.type);
}

/// Time zone rule (for ongoing DST changes)
class T3TimeZoneRule {
  /// Abbreviation format string
  final int abbrIdx;
  String? fmt;

  /// Month (1-12)
  final int mm;

  /// "When" type: 1=fixed day, 2=last weekday, 3=>= day, 4=<= day
  final int when;

  /// Day of month (1-31)
  final int dd;

  /// Day of week (0-6, 0=Sunday)
  final int weekday;

  /// Time of day (milliseconds)
  int at;

  /// Time zone for "at": 0=UTC, 1=Standard (Wall-DST), 2=Wall
  final int atZone;

  /// GMT offset during this period (milliseconds)
  final int gmtOffset;

  /// DST savings during this period (milliseconds)
  final int save;

  T3TimeZoneRule(
    this.abbrIdx,
    this.mm,
    this.when,
    this.dd,
    this.weekday,
    this.at,
    this.atZone,
    this.gmtOffset,
    this.save,
  );
}

// ----------------------------------------------------------------------------
// T3TimeZone
// ----------------------------------------------------------------------------

/// Represents a TADS 3 time zone.
class T3TimeZone {
  /// Zone name
  final String name;

  /// Transitions list
  final List<T3TimeZoneTrans> trans = [];

  /// Types list
  final List<T3TimeZoneType> types = [];

  /// Rules list
  final List<T3TimeZoneRule> rules = [];

  /// Abbreviation block
  Uint8List? abbrs;

  /// Country code (2 chars)
  String? country;

  /// Coordinates string
  String? coords;

  /// Description
  String? desc;

  T3TimeZone(this.name);

  /// Load a zone from the database file data.
  T3TimeZone.fromData(this.name, Uint8List data) {
    var p = 0;
    final view = ByteData.view(data.buffer, data.offsetInBytes);

    final transCnt = view.getUint16(p, Endian.little);
    p += 2;
    final typeCnt = view.getUint16(p, Endian.little);
    p += 2;
    final ruleCnt = view.getUint8(p);
    p += 1;
    final abbrBytes = view.getUint8(p);
    p += 1;

    // Decode types first so transitions and rules can reference them
    for (var i = 0; i < typeCnt; i++) {
      final gmtOffset = view.getInt32(p, Endian.little);
      final save = view.getInt32(p + 4, Endian.little);
      final abbrIdx = view.getUint8(p + 8);
      types.add(T3TimeZoneType(gmtOffset, save, abbrIdx));
      p += _typeSize;
    }

    // Decode transitions
    for (var i = 0; i < transCnt; i++) {
      final dayno = view.getInt32(p, Endian.little);
      final daytime = view.getInt32(p + 4, Endian.little);
      final typeIdx = view.getUint8(p + 8);
      if (typeIdx < types.length) {
        trans.add(T3TimeZoneTrans(dayno, daytime, types[typeIdx]));
      }
      p += _transSize;
    }

    // Decode rules
    for (var i = 0; i < ruleCnt; i++) {
      final abbrIdx = view.getUint8(p);
      final mm = view.getUint8(p + 1);
      final when = view.getUint8(p + 2);
      final dd = view.getUint8(p + 3);
      final weekday = view.getUint8(p + 4);
      var at = view.getInt32(p + 5, Endian.little);
      final atZone = (at >> 24) & 0xff;
      at &= 0x00ffffff;
      final gmtOffset = view.getInt32(p + 9, Endian.little);
      final save = view.getInt32(p + 13, Endian.little);

      rules.add(T3TimeZoneRule(abbrIdx, mm, when, dd, weekday, at, atZone, gmtOffset, save));
      p += _ruleSize;
    }

    // Abbreviations
    if (abbrBytes > 0) {
      abbrs = Uint8List.fromList(data.sublist(p, p + abbrBytes));
      p += abbrBytes;

      // Resolve abbreviations
      String getAbbr(int idx) {
        if (idx >= abbrs!.length) return "";
        var end = idx;
        while (end < abbrs!.length && abbrs![end] != 0) {
          end++;
        }
        return String.fromCharCodes(abbrs!.sublist(idx, end));
      }

      for (var t in types) {
        t.abbr = getAbbr(t.abbrIdx);
      }
      for (var r in rules) {
        r.fmt = getAbbr(r.abbrIdx);
      }
    }

    // Descriptive data
    if (p < data.length && data[p] != 0) {
      country = String.fromCharCodes(data.sublist(p, p + 2));
      p += 2;
      coords = String.fromCharCodes(data.sublist(p, p + 16)).trim();
      p += 16;
      if (p < data.length) {
        final dlen = data[p];
        p++;
        desc = String.fromCharCodes(data.sublist(p, p + dlen));
      }
    }
  }

  /// Create a synthetic zone from a GMT offset (in seconds).
  T3TimeZone.fromGmtOffset(int seconds) : name = "GMT${seconds >= 0 ? '+' : '-'}${seconds.abs() ~/ 3600}" {
    final type = T3TimeZoneType(seconds * 1000, 0, 0);
    type.abbr = name;
    types.add(type);
    // No transitions or rules for fixed offset
  }
}

// ----------------------------------------------------------------------------
// T3TimeZoneCache
// ----------------------------------------------------------------------------

/// Cache and factory for TADS 3 time zones.
class T3TimeZoneCache {
  final Map<String, T3TimeZone> _cache = {};
  final Map<String, int> _zonePositions = {};
  final Map<String, String> _links = {};
  final List<String> _zoneIndex = [];
  String? _t3tzPath;

  bool _initialized = false;

  /// Initialize the cache from the `timezones.t3tz` file.
  void init(String path) {
    if (_initialized) return;
    _t3tzPath = path;
    final file = File(path);
    if (!file.existsSync()) {
      throw T3VmException(vmErrTzFileOpen);
    }

    final data = file.readAsBytesSync();
    final view = ByteData.view(data.buffer, data.offsetInBytes);

    if (data.length < 24 || String.fromCharCodes(data.sublist(0, 4)) != "T3TZ") {
      throw T3VmException(vmErrTzFileRead);
    }

    final zoneTableLen = view.getUint32(16, Endian.little) - 4;
    final zoneCnt = view.getUint32(20, Endian.little);

    var p = 24;
    final zoneEnd = p + zoneTableLen;
    for (var i = 0; i < zoneCnt && p < zoneEnd; i++) {
      final len = data[p];
      p++;
      final name = String.fromCharCodes(data.sublist(p, p + len));
      p += len;
      // Skip the extra byte after the name (likely a null terminator or flag)
      p++;
      final seekPos = view.getUint32(p, Endian.little);
      p += 4;
      // skip country code (2 bytes)
      p += 2;
      _zonePositions[name] = seekPos;
      _zoneIndex.add(name);
    }

    // Read the links
    if (p + 8 <= data.length) {
      p += 4; // skip link table length
      final linkCount = view.getUint32(p, Endian.little);
      p += 4;
      // The C++ logic for linkTableLen includes the count, so we adjust.
      // However, we're using linkCount directly, so the `linkTableLen` is just for validation.
      // The original C++ code uses `linkTableLen` to determine the end of the link block.
      // Let's use `linkCount` and ensure `p` doesn't go out of bounds.
      for (var i = 0; i < linkCount && p < data.length; i++) {
        final len = data[p];
        p++;
        final name = String.fromCharCodes(data.sublist(p, p + len));
        p += len;
        // Skip gap
        p++;
        final targetIdx = view.getUint32(p, Endian.little);
        p += 4;
        if (targetIdx < _zoneIndex.length) {
          _links[name] = _zoneIndex[targetIdx];
        }
      }
    }

    _initialized = true;
  }

  /// Get all aliases for a given primary zone name.
  List<String> getAliases(String name) {
    final results = <String>[];
    _links.forEach((alias, target) {
      if (target == name) results.add(alias);
    });
    return results;
  }

  /// Get a time zone by name.
  T3TimeZone? getZone(String name) {
    if (_cache.containsKey(name)) return _cache[name];

    if (name == ":local") {
      // ... handled below ...
    } else if (_links.containsKey(name)) {
      return getZone(_links[name]!);
    }

    if (name == ":local") {
      final now = DateTime.now();
      final offset = now.timeZoneOffset.inMilliseconds;
      final tz = T3TimeZone(name);
      final type = T3TimeZoneType(offset, 0, 0);
      type.abbr = now.timeZoneName;
      tz.types.add(type);
      _cache[name] = tz;
      return tz;
    }

    if (!_zonePositions.containsKey(name)) {
      if (name.startsWith("GMT") || name.startsWith("UTC")) {
        final match = RegExp(r"^(?:GMT|UTC)([+-])(\d+)(?::(\d+))?$").firstMatch(name);
        if (match != null) {
          final sign = match.group(1) == "+" ? 1 : -1;
          final hours = int.parse(match.group(2)!);
          final mins = match.group(3) != null ? int.parse(match.group(3)!) : 0;
          final offset = sign * (hours * 3600 + mins * 60);
          final tz = T3TimeZone.fromGmtOffset(offset);
          _cache[name] = tz;
          return tz;
        }
      }
      if (name == "UTC" || name == "GMT") {
        final tz = T3TimeZone(name);
        final type = T3TimeZoneType(0, 0, 0);
        type.abbr = name;
        tz.types.add(type);
        _cache[name] = tz;
        return tz;
      }
      return null;
    }

    final seekPos = _zonePositions[name]!;
    final path = _t3tzPath;
    if (path == null) return null;
    final file = File(path);
    final raf = file.openSync(mode: FileMode.read);
    try {
      raf.setPositionSync(seekPos);
      final pfx = raf.readSync(2);
      final len = ByteData.view(pfx.buffer).getUint16(0, Endian.little);
      final body = raf.readSync(len);
      final tz = T3TimeZone.fromData(name, body);
      _cache[name] = tz;
      return tz;
    } finally {
      raf.closeSync();
    }
  }

  /// Create a missing zone placeholder.
  T3TimeZone createMissingZone(String name, int stdOfs, int dstSave, String abbr) {
    final tz = T3TimeZone(name);
    // Create a single type with the given parameters
    final type = T3TimeZoneType(stdOfs, dstSave, 0); // isDst=0? or depends on save?
    // If dstSave != 0, it's DST?
    // Usually "missing zone" implies we don't have rules, just current state?
    // C++ uses std_ofs and dst_ofs (total).
    // Here we get stdOfs (ms) and dstSave (ms) from the image.
    // We'll create a type.
    type.abbr = abbr;
    tz.types.add(type);

    // Add to cache so we don't recreate it
    _cache[name] = tz;
    return tz;
  }
}
