import 'dart:convert';
import 'dart:typed_data';

import 'package:zart/src/tads3/vm/t3_object.dart';
import 'package:zart/src/tads3/vm/t3_undo.dart';
import 'package:zart/src/tads3/vm/t3_value.dart';

/// Grammar match types.
enum T3GrammarMatchType {
  undef(0),
  prod(1),
  speech(2),
  literal(3),
  tokType(4),
  star(5),
  nSpeech(6);

  final int id;
  const T3GrammarMatchType(this.id);

  static T3GrammarMatchType fromId(int id) => values.firstWhere((e) => e.id == id, orElse: () => undef);
}

/// Token in a grammar rule alternative.
class T3GrammarToken {
  /// The property to set on the processor object if this token matches.
  final int propId;

  /// The match type.
  final T3GrammarMatchType matchType;

  /// Extra data depending on matchType.
  /// - prod: production object ID
  /// - speech: property ID
  /// - literal: string
  /// - tokType: token type enum value
  /// - nSpeech: List<int> (property IDs)
  final dynamic extra;

  T3GrammarToken({required this.propId, required this.matchType, this.extra});
}

/// A single alternative in a grammar production rule.
class T3GrammarAlt {
  final int score;
  final int badness;
  final int processorObjId;
  final List<T3GrammarToken> tokens;

  T3GrammarAlt({required this.score, required this.badness, required this.processorObjId, required this.tokens});
}

/// TADS 3 GrammarProduction Metaclass.
/// matches "grammar-production/030002"
class T3GrammarProduction extends T3Object {
  static const String metaclassName = 'grammar-production';

  /// List of alternatives for this production.
  final List<T3GrammarAlt> alternatives = [];

  T3GrammarProduction({required super.objectId, super.isTransient = false}) : super(metaclass: metaclassName);

  /// Creates a new grammar production.
  static T3GrammarProduction create(int objectId) {
    return T3GrammarProduction(objectId: objectId);
  }

  /// Adds an alternative to this production.
  void addAlt(T3GrammarAlt alt) {
    alternatives.add(alt);
  }

  /// Clears all alternatives.
  void clearAlts() {
    alternatives.clear();
  }

  /// Restoration from saved data.
  /// Data format:
  /// UINT2 alt_count
  /// Alternatives...
  static T3GrammarProduction fromData(int objectId, Uint8List data) {
    final prod = T3GrammarProduction(objectId: objectId);
    final reader = ByteData.sublistView(data);
    var offset = 0;

    // UINT2 alt_count
    final altCount = reader.getUint16(offset, Endian.little);
    offset += 2;

    for (var i = 0; i < altCount; i++) {
      // INT2 score
      final score = reader.getInt16(offset, Endian.little);
      offset += 2;

      // INT2 badness
      final badness = reader.getInt16(offset, Endian.little);
      offset += 2;

      // UINT4 processor_object_id
      final procId = reader.getUint32(offset, Endian.little);
      offset += 4;

      // UINT2 token_count
      final tokCount = reader.getUint16(offset, Endian.little);
      offset += 2;

      final tokens = <T3GrammarToken>[];
      for (var k = 0; k < tokCount; k++) {
        // UINT2 property_association
        final propId = reader.getUint16(offset, Endian.little);
        offset += 2;

        // BYTE token_match_type
        final typeId = reader.getUint8(offset);
        offset += 1;
        final type = T3GrammarMatchType.fromId(typeId);

        dynamic extra;
        switch (type) {
          case T3GrammarMatchType.prod:
            // UINT4 production object ID
            extra = reader.getUint32(offset, Endian.little);
            offset += 4;
            break;
          case T3GrammarMatchType.speech:
            // UINT2 vocabulary property
            extra = reader.getUint16(offset, Endian.little);
            offset += 2;
            break;
          case T3GrammarMatchType.nSpeech:
            // UINT2 count, then that many UINT2s
            final count = reader.getUint16(offset, Endian.little);
            offset += 2;
            final props = <int>[];
            for (var p = 0; p < count; p++) {
              props.add(reader.getUint16(offset, Endian.little));
              offset += 2;
            }
            extra = props;
            break;
          case T3GrammarMatchType.literal:
            // UINT2 byte-length prefix, then UTF8 bytes
            final len = reader.getUint16(offset, Endian.little);
            offset += 2;
            final bytes = data.sublist(offset, offset + len);
            extra = utf8.decode(bytes);
            offset += len;
            break;
          case T3GrammarMatchType.tokType:
            // UINT4 token enum ID
            extra = reader.getUint32(offset, Endian.little);
            offset += 4;
            break;
          case T3GrammarMatchType.star:
          case T3GrammarMatchType.undef:
            // No extra data
            break;
        }
        tokens.add(T3GrammarToken(propId: propId, matchType: type, extra: extra));
      }

      prod.addAlt(T3GrammarAlt(score: score, badness: badness, processorObjId: procId, tokens: tokens));
    }

    return prod;
  }

  @override
  Uint8List save() {
    final builder = BytesBuilder();
    final scratch = ByteData(4);

    // UINT2 alt_count
    scratch.setUint16(0, alternatives.length, Endian.little);
    builder.add(scratch.buffer.asUint8List(0, 2));

    for (final alt in alternatives) {
      // INT2 score
      scratch.setInt16(0, alt.score, Endian.little);
      builder.add(scratch.buffer.asUint8List(0, 2));
      // INT2 badness
      scratch.setInt16(0, alt.badness, Endian.little);
      builder.add(scratch.buffer.asUint8List(0, 2));
      // UINT4 processor_object_id
      scratch.setUint32(0, alt.processorObjId, Endian.little);
      builder.add(scratch.buffer.asUint8List());
      // UINT2 token_count
      scratch.setUint16(0, alt.tokens.length, Endian.little);
      builder.add(scratch.buffer.asUint8List(0, 2));

      for (final tok in alt.tokens) {
        // UINT2 property_association
        scratch.setUint16(0, tok.propId, Endian.little);
        builder.add(scratch.buffer.asUint8List(0, 2));
        // BYTE token_match_type
        builder.addByte(tok.matchType.id);

        switch (tok.matchType) {
          case T3GrammarMatchType.prod:
            scratch.setUint32(0, tok.extra as int, Endian.little);
            builder.add(scratch.buffer.asUint8List());
            break;
          case T3GrammarMatchType.speech:
            scratch.setUint16(0, tok.extra as int, Endian.little);
            builder.add(scratch.buffer.asUint8List(0, 2));
            break;
          case T3GrammarMatchType.nSpeech:
            final list = tok.extra as List<int>;
            scratch.setUint16(0, list.length, Endian.little);
            builder.add(scratch.buffer.asUint8List(0, 2));
            for (final p in list) {
              scratch.setUint16(0, p, Endian.little);
              builder.add(scratch.buffer.asUint8List(0, 2));
            }
            break;
          case T3GrammarMatchType.literal:
            final strBytes = utf8.encode(tok.extra as String);
            scratch.setUint16(0, strBytes.length, Endian.little);
            builder.add(scratch.buffer.asUint8List(0, 2));
            builder.add(strBytes);
            break;
          case T3GrammarMatchType.tokType:
            scratch.setUint32(0, tok.extra as int, Endian.little);
            builder.add(scratch.buffer.asUint8List());
            break;
          default:
            break;
        }
      }
    }

    return builder.toBytes();
  }

  @override
  T3Value? getProperty(int propId) {
    // Intrinsic support not fully implemented, returning null usually works for basics
    return null;
  }

  @override
  void setProperty(int propId, T3Value value, {T3UndoManager? undoManager}) {
    throw UnsupportedError('GrammarProduction objects are immutable (via setProperty). Use intrinsic methods.');
  }

  @override
  Map<String, dynamic> get debugInfo => {'objectId': objectId, 'metaclass': metaclass, 'altCount': alternatives.length};
}
