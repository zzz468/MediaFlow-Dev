import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'local_log_store.dart';

enum LogCategory { parser, downloader, network, error }

abstract final class AppLogger {
  static bool _configured = false;
  static LocalLogStore _localStore = LocalLogStore.instance;
  static final Map<LogCategory, Logger> _loggers = <LogCategory, Logger>{
    for (final category in LogCategory.values)
      category: Logger('MediaFlow.${category.name}'),
  };

  static void configure({LocalLogStore? localStore}) {
    if (_configured) {
      return;
    }

    _configured = true;
    _localStore = localStore ?? LocalLogStore.instance;
    Logger.root.level = kDebugMode ? Level.ALL : Level.INFO;
    Logger.root.onRecord.listen((record) {
      final category = _categoryFor(record.loggerName);
      unawaited(_localStore.write(category.name, record));
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

  static void info(String message, {required LogCategory category}) {
    _logger(category).info(message);
  }

  static void warning(
    String message, {
    LogCategory category = LogCategory.error,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _logger(category).warning(message, error, stackTrace);
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    _logger(LogCategory.error).severe(message, error, stackTrace);
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
    _logger(LogCategory.downloader).severe(message, error, stackTrace);
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
    _logger(LogCategory.error).severe(message, error, stackTrace);
  }

  static Logger _logger(LogCategory category) => _loggers[category]!;

  static LogCategory _categoryFor(String loggerName) {
    for (final category in LogCategory.values) {
      if (loggerName.endsWith('.${category.name}')) {
        return category;
      }
    }
    return LogCategory.error;
  }
}
