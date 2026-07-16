import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/logging/app_logger.dart';
import '../mediaflow_app.dart';

void bootstrap() {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.configure();

  FlutterError.onError = (details) {
    AppLogger.error(
      'A Flutter framework error occurred.',
      error: details.exception,
      stackTrace: details.stack,
    );
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    AppLogger.error(
      'An uncaught platform error occurred.',
      error: UnexpectedAppException(error),
      stackTrace: stackTrace,
    );
    return true;
  };

  runApp(const ProviderScope(child: MediaFlowApp()));
}
