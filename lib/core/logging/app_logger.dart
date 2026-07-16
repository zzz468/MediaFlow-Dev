import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

enum LogCategory { application, parser, download, network, fileSystem }

abstract final class AppLogger {
  static bool _configured = false;
  static final Map<LogCategory, Logger> _loggers = <LogCategory, Logger>{
    for (final category in LogCategory.values)
      category: Logger('MediaFlow.${category.name}'),
  };

  static void configure() {
    if (_configured) {
      return;
    }

    _configured = true;
    Logger.root.level = kDebugMode ? Level.ALL : Level.INFO;
    Logger.root.onRecord.listen((record) {
      debugPrint(
        '[${record.level.name}] ${record.time.toIso8601String()} '
        '${record.loggerName}: ${record.message}',
      );
      if (record.error != null) {
        debugPrint('Error: ${record.error}');
      }
      if (record.stackTrace != null) {
        debugPrintStack(stackTrace: record.stackTrace);
      }
    });
  }

  static void info(
    String message, {
    LogCategory category = LogCategory.application,
  }) {
    _logger(category).info(message);
  }

  static void warning(
    String message, {
    LogCategory category = LogCategory.application,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _logger(category).warning(message, error, stackTrace);
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    _logger(LogCategory.application).severe(message, error, stackTrace);
  }

  static void parserError(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    _logger(LogCategory.parser).severe(message, error, stackTrace);
  }

  static void downloadError(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    _logger(LogCategory.download).severe(message, error, stackTrace);
  }

  static void networkError(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    _logger(LogCategory.network).severe(message, error, stackTrace);
  }

  static void fileError(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    _logger(LogCategory.fileSystem).severe(message, error, stackTrace);
  }

  static Logger _logger(LogCategory category) => _loggers[category]!;
}
