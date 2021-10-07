import 'dart:io';

import 'package:logging/logging.dart';
export 'package:logging/logging.dart';

/// Mixin class for adding logging functionality to other classes.
abstract class Loggable {
  Logger _logger = Logger("Loggable");

  /// Sets the logger and name for this [Loggable] mixin instance.
  set logName(String name) => _logger = Logger(name);

  /// Gets the log for output.
  ///
  /// ### Usage:
  ///
  /// ```
  /// log.warning("The app did something concerning...");
  /// ```
  Logger get log => _logger;
}

/// Helper function which initializes the [Logger] to listen for log
/// events and print them if they meet [level] or higher (more severe).
///
/// This function should be called only once.
///
/// ### Usage:
///
/// ```
/// initializeLogger(Level.INFO);
/// log.fine("this message won't print");
/// log.warning("this message will print");
/// ```
void initializeLogger(Level level) {
  if (_loggerInitialized) {
    Logger("initializeLogger()").warning(
        "Attempted to initialize the logger after it was already initialized.");
    return;
  }

  logLevel = level;

  Logger.root.onRecord.listen((LogRecord rec) {
    stdout.writeln('(${rec.time}:)[${rec.loggerName}]${rec.level.name}: ${rec.message}');
  });

  _loggerInitialized = true;
}

/// Sets the [Logger] logging [Level].
set logLevel(Level newLevel) => Logger.root.level = newLevel;

/// Gets the current [Logger] [Level].
Level get logLevel => Logger.root.level;

bool _loggerInitialized = false;
