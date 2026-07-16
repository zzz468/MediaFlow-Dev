import 'package:flutter_riverpod/flutter_riverpod.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

enum AppEnvironment { development, production }

class AppConfig {
  const AppConfig({
    required this.appName,
    required this.version,
    required this.buildNumber,
    required this.repositoryUrl,
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
      version: String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0'),
      buildNumber: String.fromEnvironment('APP_BUILD', defaultValue: '1'),
      repositoryUrl: String.fromEnvironment(
        'REPOSITORY_URL',
        defaultValue: 'https://github.com/zzz468/MediaFlow-Dev',
      ),
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
  final String version;
  final String buildNumber;
  final String repositoryUrl;
  final AppEnvironment environment;
  final bool enableVerboseLogging;

  bool get isProduction => environment == AppEnvironment.production;
  String get displayVersion => '$version+$buildNumber';
}
