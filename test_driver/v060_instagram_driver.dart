import 'package:integration_test/integration_test_driver.dart';

// Connect only to an already installed/running APK. The caller supplies the
// VM Service URL through flutter drive --use-existing-app; no install route.
Future<void> main() => integrationDriver(timeout: const Duration(minutes: 10));
