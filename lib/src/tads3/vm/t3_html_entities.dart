/// TADS3 HTML Entity Conversion
///
/// This file contains mappings for HTML entities used in TADS3 output.
/// Based on the reference interpreter's mkchrtab.cpp entity table.

/// Converts TADS3 HTML entities to Unicode characters.
///
/// TADS3 uses HTML-style entities like `&rarr;` or `&#8594;` in text output.
/// This function converts them to their Unicode character equivalents.
String convertHtmlEntities(String text) {
  if (!text.contains('&')) return text;

  final result = StringBuffer();
  var i = 0;

  while (i < text.length) {
    if (text[i] == '&') {
      // Find the end of the entity
      final end = text.indexOf(';', i);
      if (end == -1) {
        // No closing semicolon, just add the character
        result.write(text[i]);
        i++;
        continue;
      }

      final entity = text.substring(i + 1, end);

      if (entity.startsWith('#')) {
        // Numeric entity: &#123; or &#x1F;
        int? codePoint;
        if (entity.startsWith('#x') || entity.startsWith('#X')) {
          // Hexadecimal
          codePoint = int.tryParse(entity.substring(2), radix: 16);
        } else {
          // Decimal
          codePoint = int.tryParse(entity.substring(1));
        }

        if (codePoint != null && codePoint > 0) {
          result.writeCharCode(codePoint);
        } else {
          // Invalid numeric entity, keep as-is
          result.write('&$entity;');
        }
      } else {
        // Named entity
        final codePoint = _htmlEntities[entity];
        if (codePoint != null) {
          result.writeCharCode(codePoint);
        } else {
          // Unknown entity, keep as-is
          result.write('&$entity;');
        }
      }
      i = end + 1;
    } else {
      result.write(text[i]);
      i++;
    }
  }

  return result.toString();
}

/// Mapping of HTML entity names to Unicode code points.
/// Based on TADS3 reference interpreter (mkchrtab.cpp).
const Map<String, int> _htmlEntities = {
  // Standard HTML entities
  'nbsp': 160,
  'iexcl': 161,
  'cent': 162,
  'pound': 163,
  'curren': 164,
  'yen': 165,
  'brvbar': 166,
  'sect': 167,
  'uml': 168,
  'copy': 169,
  'ordf': 170,
  'laquo': 171,
  'not': 172,
  'shy': 173,
  'reg': 174,
  'macr': 175,
  'deg': 176,
  'plusmn': 177,
  'sup2': 178,
  'sup3': 179,
  'acute': 180,
  'micro': 181,
  'para': 182,
  'middot': 183,
  'cedil': 184,
  'sup1': 185,
  'ordm': 186,
  'raquo': 187,
  'frac14': 188,
  'frac12': 189,
  'frac34': 190,
  'iquest': 191,
  'times': 215,
  'divide': 247,

  // Latin uppercase
  'AElig': 198,
  'Aacute': 193,
  'Acirc': 194,
  'Agrave': 192,
  'Aring': 197,
  'Atilde': 195,
  'Auml': 196,
  'Ccedil': 199,
  'ETH': 208,
  'Eacute': 201,
  'Ecirc': 202,
  'Egrave': 200,
  'Euml': 203,
  'Iacute': 205,
  'Icirc': 206,
  'Igrave': 204,
  'Iuml': 207,
  'Ntilde': 209,
  'Oacute': 211,
  'Ocirc': 212,
  'Ograve': 210,
  'Oslash': 216,
  'Otilde': 213,
  'Ouml': 214,
  'THORN': 222,
  'Uacute': 218,
  'Ucirc': 219,
  'Ugrave': 217,
  'Uuml': 220,
  'Yacute': 221,

  // Latin lowercase
  'aacute': 225,
  'acirc': 226,
  'aelig': 230,
  'agrave': 224,
  'aring': 229,
  'atilde': 227,
  'auml': 228,
  'ccedil': 231,
  'eacute': 233,
  'ecirc': 234,
  'egrave': 232,
  'eth': 240,
  'euml': 235,
  'iacute': 237,
  'icirc': 238,
  'igrave': 236,
  'iuml': 239,
  'ntilde': 241,
  'oacute': 243,
  'ocirc': 244,
  'ograve': 242,
  'oslash': 248,
  'otilde': 245,
  'ouml': 246,
  'szlig': 223,
  'thorn': 254,
  'uacute': 250,
  'ucirc': 251,
  'ugrave': 249,
  'uuml': 252,
  'yacute': 253,
  'yuml': 255,

  // TADS extensions for smart quotes/dashes
  'lsq': 8216, // Left single quote '
  'rsq': 8217, // Right single quote '
  'ldq': 8220, // Left double quote "
  'rdq': 8221, // Right double quote "
  'endash': 8211, // En dash –
  'emdash': 8212, // Em dash —
  'trade': 8482, // Trademark ™
  // HTML 4.0 punctuation
  'ndash': 8211,
  'mdash': 8212,
  'lsquo': 8216,
  'rsquo': 8217,
  'ldquo': 8220,
  'rdquo': 8221,
  'sbquo': 8218,
  'bdquo': 8222,
  'lsaquo': 8249,
  'rsaquo': 8250,
  'dagger': 8224,
  'Dagger': 8225,
  'OElig': 338,
  'oelig': 339,
  'permil': 8240,
  'Yuml': 376,
  'scaron': 353,
  'Scaron': 352,
  'circ': 710,
  'tilde': 732,

  // Greek uppercase
  'Alpha': 913,
  'Beta': 914,
  'Gamma': 915,
  'Delta': 916,
  'Epsilon': 917,
  'Zeta': 918,
  'Eta': 919,
  'Theta': 920,
  'Iota': 921,
  'Kappa': 922,
  'Lambda': 923,
  'Mu': 924,
  'Nu': 925,
  'Xi': 926,
  'Omicron': 927,
  'Pi': 928,
  'Rho': 929,
  'Sigma': 931,
  'Tau': 932,
  'Upsilon': 933,
  'Phi': 934,
  'Chi': 935,
  'Psi': 936,
  'Omega': 937,

  // Greek lowercase
  'alpha': 945,
  'beta': 946,
  'gamma': 947,
  'delta': 948,
  'epsilon': 949,
  'zeta': 950,
  'eta': 951,
  'theta': 952,
  'iota': 953,
  'kappa': 954,
  'lambda': 955,
  'mu': 956,
  'nu': 957,
  'xi': 958,
  'omicron': 959,
  'pi': 960,
  'rho': 961,
  'sigmaf': 962,
  'sigma': 963,
  'tau': 964,
  'upsilon': 965,
  'phi': 966,
  'chi': 967,
  'psi': 968,
  'omega': 969,
  'thetasym': 977,
  'upsih': 978,
  'piv': 982,

  // Punctuation
  'bull': 8226, // Bullet •
  'hellip': 8230, // Horizontal ellipsis …
  'prime': 8242,
  'Prime': 8243,
  'oline': 8254,
  'frasl': 8260,

  // Letter-like symbols
  'weierp': 8472,
  'image': 8465,
  'real': 8476,
  'alefsym': 8501,

  // Arrows
  'larr': 8592, // Left arrow ←
  'uarr': 8593, // Up arrow ↑
  'rarr': 8594, // Right arrow →
  'darr': 8595, // Down arrow ↓
  'harr': 8596, // Left-right arrow ↔
  'crarr': 8629, // Carriage return arrow ↵
  'lArr': 8656, // Double left arrow ⇐
  'uArr': 8657, // Double up arrow ⇑
  'rArr': 8658, // Double right arrow ⇒
  'dArr': 8659, // Double down arrow ⇓
  'hArr': 8660, // Double left-right arrow ⇔
  // Mathematical operators
  'forall': 8704,
  'part': 8706,
  'exist': 8707,
  'empty': 8709,
  'nabla': 8711,
  'isin': 8712,
  'notin': 8713,
  'ni': 8715,
  'prod': 8719,
  'sum': 8721,
  'minus': 8722,
  'lowast': 8727,
  'radic': 8730,
  'prop': 8733,
  'infin': 8734,
  'ang': 8736,
  'and': 8743,
  'or': 8744,
  'cap': 8745,
  'cup': 8746,
  'int': 8747,
  'there4': 8756,
  'sim': 8764,
  'cong': 8773,
  'asymp': 8776,
  'ne': 8800,
  'equiv': 8801,
  'le': 8804,
  'ge': 8805,
  'sub': 8834,
  'sup': 8835,
  'nsub': 8836,
  'sube': 8838,
  'supe': 8839,
  'oplus': 8853,
  'otimes': 8855,
  'perp': 8869,
  'sdot': 8901,
  'lceil': 8968,
  'rceil': 8969,
  'lfloor': 8970,
  'rfloor': 8971,
  'lang': 9001,
  'rang': 9002,

  // Geometric shapes
  'loz': 9674,

  // Card suits
  'spades': 9824,
  'clubs': 9827,
  'hearts': 9829,
  'diams': 9830,

  // Other
  'fnof': 402,

  // Standard entities
  'amp': 38,
  'lt': 60,
  'gt': 62,
  'quot': 34,
  'apos': 39,
};
