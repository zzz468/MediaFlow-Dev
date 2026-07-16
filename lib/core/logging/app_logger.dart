import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

abstract final class AppLogger {
  static bool _configured = false;
  static final Logger _logger = Logger('MediaFlow');

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
    });
  }

  static void info(String message) {
    _logger.info(message);
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.severe(message, error, stackTrace);
  }
}
