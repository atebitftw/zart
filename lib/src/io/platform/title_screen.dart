import 'dart:math';
import 'package:zart/src/io/render/render_cell.dart';
import 'package:zart/src/io/render/screen_frame.dart';

/// RGB color constants for the title screen.
abstract final class _TitleColors {
  static const int black = 0x000000;
  static const int cyan = 0x00CCCC;
  static const int magenta = 0xCC00CC;
  static const int white = 0xFFFFFF;
  static const int yellow = 0xCCCC00;
  static const int green = 0x00CC00;
  static const int grey = 0x808080;
  static const int darkGrey = 0x444444;
}

/// Configuration for the animated prompt display.
class AnimatedPromptConfig {
  /// Typing speed in milliseconds per character.
  final int typingSpeedMs;

  /// Delay between prompts in milliseconds.
  final int delayBetweenPromptsMs;

  /// Color for the typed command text.
  final int promptColor;

  /// Color for the blinking caret.
  final int cursorColor;

  /// Color for the ">" prompt symbol.
  final int caretColor;

  /// Constructor.
  const AnimatedPromptConfig({
    this.typingSpeedMs = 80,
    this.delayBetweenPromptsMs = 1500,
    this.promptColor = _TitleColors.white,
    this.cursorColor = _TitleColors.grey,
    this.caretColor = _TitleColors.yellow,
  });
}

/// Title screen renderer for Zart.
///
/// Creates a [ScreenFrame] that can be rendered through the normal
/// platform provider rendering pipeline.
class ZartTitleScreen {
  /// Large ASCII art "ZART" logo
  static const List<String> _logo = [
    r' ███████╗ █████╗ ██████╗ ████████╗',
    r' ╚══███╔╝██╔══██╗██╔══██╗╚══██╔══╝',
    r'   ███╔╝ ███████║██████╔╝   ██║   ',
    r'  ███╔╝  ██╔══██║██╔══██╗   ██║   ',
    r' ███████╗██║  ██║██║  ██║   ██║   ',
    r' ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ',
  ];

  /// Frame content width (inside the border, not including border chars)
  static const int _innerWidth = 56;

  /// Default commands to display if no file is provided
  static const List<String> _defaultCommands = [
    'go north',
    'go south',
    'go east',
    'go west',
    'inventory',
    'look',
    'look at the sky',
    'look under the rug',
    'look in the chest',
    'examine the lamp',
    'open the mailbox',
    'read the leaflet',
    'take the sword',
    'kill the troll with the sword',
    'xyzzy',
    'plugh',
    'use the key',
    'open the door',
    'close the door',
    'eat the apple',
    'drink the potion',
    'unlock the door',
    'light the lamp',
    'turn on the lantern',
    'diagnose',
    'wait',
    'again',
    'save',
    'restore',
    'restart',
    'verbose',
    'score',
    'version',
    'take all',
    'get all',
    'drop gold',
    'hide',
    'take the towel',
    'put the towel over my head',
    'wear the cloak',
    'remove the armor',
    'eat the lunch',
    'hint',
    'help',
    'lie down in the mud',
    'open the mailbox',
    'push the button',
    'pull the lever',
    'climb the rope',
    'talk to the elf',
    'ask the wizard about the potion',
    'tell the troll about the treasure',
    'enter cave',
    'leave house',
    'sleep',
    'wake up',
    'tie the rope',
    'take the analgesic',
    'cast frotz on self',
    'ford, what about my house',
    'press the green button',
    'pet the dog',
    'order a sandwich',
    'drink a beer',
  ];

  /// Show the title screen with animated command prompts.
  ///
  /// [commands] - List of commands to randomly type out.
  /// [config] - Configuration for typing animation.
  /// [renderCallback] is called with each frame to render.
  /// [asyncKeyWait] - Result of provider.setupAsyncKeyWait() for non-blocking key detection.
  static Future<void> show({
    required int width,
    required int height,
    required void Function(ScreenFrame frame) renderCallback,
    required ({
      Future<void> onKeyPressed,
      bool Function() wasPressed,
      void Function() cleanup,
    })
    asyncKeyWait,
    List<String>? commands,
    AnimatedPromptConfig config = const AnimatedPromptConfig(),
  }) async {
    final commandList = commands ?? _defaultCommands;
    final random = Random();
    var currentCommand = '';
    var charIndex = 0;
    var showCaret = true;
    var isTyping = true;
    var delayCounter = 0;

    // Pick a random command
    String pickRandomCommand() {
      return commandList[random.nextInt(commandList.length)];
    }

    currentCommand = pickRandomCommand();

    try {
      // Animation loop - check wasPressed() each iteration
      while (!asyncKeyWait.wasPressed()) {
        // Build frame with current animation state
        final frame = _buildFrame(
          width,
          height,
          promptText: currentCommand.substring(0, charIndex),
          showCaret: showCaret,
          config: config,
        );
        renderCallback(frame);

        // Small delay for animation timing
        await Future.delayed(Duration(milliseconds: config.typingSpeedMs));

        // Check if key was pressed
        if (asyncKeyWait.wasPressed()) break;

        // Toggle caret visibility for blinking effect
        showCaret = !showCaret;

        if (isTyping) {
          // Type next character
          if (charIndex < currentCommand.length) {
            charIndex++;
          } else {
            // Done typing, start delay
            isTyping = false;
            delayCounter = 0;
          }
        } else {
          // Waiting between prompts
          delayCounter += config.typingSpeedMs;

          if (delayCounter >= config.delayBetweenPromptsMs) {
            // Pick new command and reset
            currentCommand = pickRandomCommand();
            charIndex = 0;
            isTyping = true;
          }
        }
      }
    } finally {
      // Cleanup the async key wait
      asyncKeyWait.cleanup();
    }
  }

  /// Build a [ScreenFrame] for the title screen.
  ///
  /// [promptText] - Current text being typed in the prompt area.
  /// [showCaret] - Whether to show the blinking caret.
  /// [config] - Animation configuration.
  static ScreenFrame _buildFrame(
    int width,
    int height, {
    String promptText = '',
    bool showCaret = true,
    AnimatedPromptConfig config = const AnimatedPromptConfig(),
  }) {
    final cells = List.generate(
      height,
      (_) => List.generate(
        width,
        (_) => RenderCell(' ', bgColor: _TitleColors.black),
      ),
    );

    var row = 1;

    // Frame total width = 2 (borders) + innerWidth
    final frameWidth = _innerWidth + 2;
    final leftOffset = (width - frameWidth) ~/ 2;
    if (leftOffset < 0) {
      return ScreenFrame(cells: cells, width: width, height: height);
    }

    void writeCell(
      int r,
      int c,
      String char, {
      int? fg,
      int? bg,
      bool bold = false,
    }) {
      if (r >= 0 && r < height && c >= 0 && c < width) {
        cells[r][c] = RenderCell(
          char,
          fgColor: fg ?? _TitleColors.cyan,
          bgColor: bg ?? _TitleColors.black,
          bold: bold,
        );
      }
    }

    void writeString(
      int r,
      int startCol,
      String text, {
      int? fg,
      int? bg,
      bool bold = false,
    }) {
      for (var i = 0; i < text.length; i++) {
        writeCell(r, startCol + i, text[i], fg: fg, bg: bg, bold: bold);
      }
    }

    void writeHorizontalBorder(String left, String middle, String right) {
      writeCell(row, leftOffset, left, fg: _TitleColors.cyan);
      for (var i = 0; i < _innerWidth; i++) {
        writeCell(row, leftOffset + 1 + i, middle, fg: _TitleColors.cyan);
      }
      writeCell(
        row,
        leftOffset + 1 + _innerWidth,
        right,
        fg: _TitleColors.cyan,
      );
      row++;
    }

    void writeFrameLine(String content, {int? fg, bool bold = false}) {
      writeCell(row, leftOffset, '║', fg: _TitleColors.cyan);
      for (var i = 0; i < _innerWidth; i++) {
        if (i < content.length) {
          writeCell(row, leftOffset + 1 + i, content[i], fg: fg, bold: bold);
        } else {
          writeCell(row, leftOffset + 1 + i, ' ');
        }
      }
      writeCell(row, leftOffset + 1 + _innerWidth, '║', fg: _TitleColors.cyan);
      row++;
    }

    void writeEmptyLine() {
      writeFrameLine(' ' * _innerWidth);
    }

    void writeDivider() {
      writeCell(row, leftOffset, '║', fg: _TitleColors.cyan);
      for (var i = 0; i < _innerWidth; i++) {
        writeCell(row, leftOffset + 1 + i, '─', fg: _TitleColors.cyan);
      }
      writeCell(row, leftOffset + 1 + _innerWidth, '║', fg: _TitleColors.cyan);
      row++;
    }

    void writeCentered(String text, {int? fg, bool bold = false}) {
      final padding = (_innerWidth - text.length) ~/ 2;
      final leftPad = ' ' * (padding > 0 ? padding : 0);
      final content = leftPad + text;
      writeFrameLine(content, fg: fg, bold: bold);
    }

    void writeAnimatedPrompt(
      String text,
      bool caret,
      AnimatedPromptConfig cfg,
    ) {
      writeCell(row, leftOffset, '║', fg: _TitleColors.cyan);
      // Prompt symbol "> "
      writeCell(row, leftOffset + 2, '>', fg: cfg.caretColor, bold: true);
      writeCell(row, leftOffset + 3, ' ');
      // Command text
      for (var i = 0; i < text.length && i < _innerWidth - 4; i++) {
        writeCell(row, leftOffset + 4 + i, text[i], fg: cfg.promptColor);
      }
      // Caret
      final caretPos = leftOffset + 4 + text.length;
      if (caret && caretPos < leftOffset + 1 + _innerWidth) {
        writeCell(row, caretPos, '|', fg: cfg.cursorColor);
      }
      // Fill rest with spaces
      for (var i = 4 + text.length + (caret ? 1 : 0); i < _innerWidth; i++) {
        writeCell(row, leftOffset + 1 + i, ' ');
      }
      writeCell(row, leftOffset + 1 + _innerWidth, '║', fg: _TitleColors.cyan);
      row++;
    }

    // Top border
    writeHorizontalBorder('╔', '═', '╗');
    writeEmptyLine();

    // Logo with color gradient - solid blocks are colorful, shadow chars are darkGrey
    final logoColors = [
      _TitleColors.cyan,
      _TitleColors.green,
      _TitleColors.yellow,
      _TitleColors.magenta,
      _TitleColors.white,
      _TitleColors.grey,
    ];

    // Shadow characters (box-drawing) for 3D effect
    const shadowChars = {'╔', '╗', '╚', '╝', '║', '═'};

    for (var i = 0; i < _logo.length; i++) {
      final logoText = _logo[i];
      final logoPadding = (_innerWidth - logoText.length) ~/ 2;

      // Write left border
      writeCell(row, leftOffset, '║', fg: _TitleColors.cyan);

      // Write each character with appropriate color
      for (var j = 0; j < _innerWidth; j++) {
        final charIndex = j - logoPadding;
        if (charIndex >= 0 && charIndex < logoText.length) {
          final char = logoText[charIndex];
          // Shadow chars get darkGrey, solid blocks get colorful
          final color = shadowChars.contains(char)
              ? _TitleColors.darkGrey
              : logoColors[i];
          writeCell(
            row,
            leftOffset + 1 + j,
            char,
            fg: color,
            bold: !shadowChars.contains(char),
          );
        } else {
          writeCell(row, leftOffset + 1 + j, ' ');
        }
      }

      // Write right border
      writeCell(row, leftOffset + 1 + _innerWidth, '║', fg: _TitleColors.cyan);
      row++;
    }

    writeEmptyLine();
    writeDivider();
    writeEmptyLine();

    // Subtitle
    writeCentered('Interactive Fiction Library', fg: _TitleColors.white);
    writeEmptyLine();

    // Version
    writeCentered('Version 2.0', fg: _TitleColors.yellow);
    writeEmptyLine();

    // URL
    writeCentered('https://pub.dev/packages/zart', fg: _TitleColors.green);
    writeEmptyLine();

    // License
    writeCentered('MIT License', fg: _TitleColors.darkGrey);
    writeEmptyLine();
    writeDivider();
    writeEmptyLine();

    // Animated prompt display
    writeAnimatedPrompt(promptText, showCaret, config);

    writeEmptyLine();

    // Bottom border
    writeHorizontalBorder('╚', '═', '╝');
    row++;

    // Prompt (outside the frame, centered on screen)
    final pressKeyText = '[ Press Any Key To Start Game ]';
    final pressKeyStart = (width - pressKeyText.length) ~/ 2;
    writeString(row, pressKeyStart, pressKeyText, fg: _TitleColors.grey);

    return ScreenFrame(
      cells: cells,
      width: width,
      height: height,
      cursorVisible: false,
      hideStatusBar: true,
    );
  }
}
