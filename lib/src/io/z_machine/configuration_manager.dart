import 'dart:convert';
import 'dart:io';

import 'package:zart/src/logging.dart';

/// The global configuration manager for Zart.
final ConfigurationManager configManager = ConfigurationManager();

/// Manages persistent configuration for Zart, including key bindings.
class ConfigurationManager {
  static const String _configFileName = 'zart.config';

  Map<String, String> _bindings = {};

  /// Current key bindings (Key -> Command).
  /// Key format: 'ctrl+a', 'ctrl+b', etc.
  Map<String, String> get bindings => Map.unmodifiable(_bindings);

  int _textColor = 1; // Default
  int _zartBarForeground = 9; // Default White
  int _zartBarBackground = 10; // Default Grey
  bool _zartBarVisible = true; // Default True

  /// Current text color (1-15).
  int get textColor => _textColor;

  /// Zart Bar Foreground Color (1-15).
  int get zartBarForeground => _zartBarForeground;
  set zartBarForeground(int value) {
    _zartBarForeground = value;
    save();
  }

  /// Zart Bar Background Color (1-15).
  int get zartBarBackground => _zartBarBackground;
  set zartBarBackground(int value) {
    _zartBarBackground = value;
    save();
  }

  /// Zart Bar Visibility.
  bool get zartBarVisible => _zartBarVisible;

  /// Sets Zart Bar Visibility and saves.
  set zartBarVisible(bool visible) {
    _zartBarVisible = visible;
    save();
  }

  /// Set the text color (1-15).
  set textColor(int value) {
    _textColor = value;
    save();
  }

  /// Load configuration from disk.
  void load() {
    final f = File(_configFileName);
    if (!f.existsSync()) {
      log.info('No configuration file found. Using defaults.');
      return;
    }

    try {
      final jsonString = f.readAsStringSync();
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);

      if (jsonMap.containsKey('bindings')) {
        final bindingsMap = jsonMap['bindings'] as Map<String, dynamic>;
        _bindings = bindingsMap.map((k, v) => MapEntry(k, v.toString()));
      }

      if (jsonMap.containsKey('text_color')) {
        _textColor = jsonMap['text_color'] as int;
      }

      if (jsonMap.containsKey('zart_bar_foreground')) {
        _zartBarForeground = jsonMap['zart_bar_foreground'] as int;
      }

      if (jsonMap.containsKey('zart_bar_background')) {
        _zartBarBackground = jsonMap['zart_bar_background'] as int;
      }

      if (jsonMap.containsKey('zart_bar_visible')) {
        _zartBarVisible = jsonMap['zart_bar_visible'] as bool;
      }

      log.info('Configuration loaded.');
    } catch (e) {
      log.warning('Failed to load configuration: $e');
    }
  }

  /// Save configuration to disk.
  void save() {
    final Map<String, dynamic> jsonMap = {
      'bindings': _bindings,
      'text_color': _textColor,
      'zart_bar_foreground': _zartBarForeground,
      'zart_bar_background': _zartBarBackground,
      'zart_bar_visible': _zartBarVisible,
    };

    try {
      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonMap);
      File(_configFileName).writeAsStringSync(jsonString);
      log.info('Configuration saved.');
    } catch (e) {
      log.severe('Failed to save configuration: $e');
    }
  }

  /// Get the command bound to a specific key combination.
  String? getBinding(String key) {
    return _bindings[key.toLowerCase()];
  }

  /// Set a binding. passing null or empty command removes the binding.
  void setBinding(String key, String? command) {
    final k = key.toLowerCase();
    if (command == null || command.isEmpty) {
      _bindings.remove(k);
    } else {
      _bindings[k] = command;
    }
    save();
  }
}
