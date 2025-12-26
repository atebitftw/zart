/// Glk style constants.
///
/// Glk Spec: "There are currently eleven styles defined."
/// These are used to indicate the semantic meaning of text, not appearance.
/// The presentation layer maps these to actual formatting.
class GlkStyle {
  /// Normal or body text.
  static const int normal = 0;

  /// Text which is emphasized (italic).
  static const int emphasized = 1;

  /// Text which has a particular arrangement of characters (monospace).
  static const int preformatted = 2;

  /// Text which introduces a large section (bold, larger).
  static const int header = 3;

  /// Text which introduces a smaller section.
  static const int subheader = 4;

  /// Text which warns of a dangerous condition (bold, red).
  static const int alert = 5;

  /// Text which notifies of an interesting condition (italic).
  static const int note = 6;

  /// Text which forms a quotation or long excerpt.
  static const int blockQuote = 7;

  /// Text which the player has entered (bold).
  static const int input = 8;

  /// User-defined styles.
  static const int user1 = 9;
  static const int user2 = 10;

  /// Total number of styles.
  static const int count = 11;

  /// Style names for debugging.
  static const List<String> names = [
    'Normal',
    'Emphasized',
    'Preformatted',
    'Header',
    'Subheader',
    'Alert',
    'Note',
    'BlockQuote',
    'Input',
    'User1',
    'User2',
  ];
}

/// Glk style hint selectors.
class GlkStyleHint {
  /// Indentation of the first line of a paragraph.
  static const int indentation = 0;

  /// Indentation of subsequent lines of a paragraph.
  static const int paraIndentation = 1;

  /// Text justification (0=Left, 1=LeftRight, 2=Centered, 3=Right).
  static const int justification = 2;

  /// Font size.
  static const int size = 3;

  /// Font weight (1=Bold, 0=Normal, -1=Light).
  static const int weight = 4;

  /// Font style (1=Italic, 0=Normal).
  static const int oblique = 5;

  /// Font pitch (1=Proportional, 0=Fixed).
  static const int proportional = 6;

  /// Foreground color (0x00RRGGBB).
  static const int textColor = 7;

  /// Background color (0x00RRGGBB).
  static const int backColor = 8;

  /// Reverse color (1=Reverse, 0=Normal).
  static const int reverseColor = 9;
}
