import 'package:flutter_riverpod/flutter_riverpod.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

enum AppEnvironment { development, production }

class AppConfig {
  const AppConfig({
    required this.appName,
    required this.environment,
    required this.enableVerboseLogging,
  });

  factory AppConfig.fromEnvironment() {
    const environmentName = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    );

    return const AppConfig(
      appName: String.fromEnvironment('APP_NAME', defaultValue: 'MediaFlow'),
      environment: environmentName == 'production'
          ? AppEnvironment.production
          : AppEnvironment.development,
      enableVerboseLogging: bool.fromEnvironment(
        'VERBOSE_LOGGING',
        defaultValue: false,
      ),
    );
  }

  final String appName;
  final AppEnvironment environment;
  final bool enableVerboseLogging;

  bool get isProduction => environment == AppEnvironment.production;
}
