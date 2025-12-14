import 'dart:convert';
import 'dart:io';

import 'package:zart/src/logging.dart';

/// Manages persistent configuration for Zart, including key bindings.
class ConfigurationManager {
  static const String _configFileName = 'zart.config';

  Map<String, String> _bindings = {};

  /// Current key bindings (Key -> Command).
  /// Key format: 'ctrl+a', 'ctrl+b', etc.
  Map<String, String> get bindings => Map.unmodifiable(_bindings);

  int _textColor = 1; // Default

  /// Current text color (1-15).
  int get textColor => _textColor;

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
