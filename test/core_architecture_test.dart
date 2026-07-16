import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/core/config/app_config.dart';

void main() {
  test('app config exposes the selected environment', () {
    const config = AppConfig(
      appName: 'MediaFlow Test',
      version: '0.1.0-beta',
      buildNumber: '1',
      repositoryUrl: 'https://example.test/mediaflow',
      environment: AppEnvironment.production,
      enableVerboseLogging: true,
    );

    expect(config.isProduction, isTrue);
    expect(config.enableVerboseLogging, isTrue);
  });
}
