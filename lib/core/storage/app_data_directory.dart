import 'dart:io';

import 'package:path_provider/path_provider.dart';

typedef AppDataDirectoryResolver = Future<Directory> Function();

Future<Directory> resolveAppDataDirectory() async {
  // Explicit Windows acceptance builds isolate all settings/history/logs.
  // Normal builds and mobile platforms retain their existing storage path.
  const acceptanceRoot = String.fromEnvironment(
    'MEDIAFLOW_ACCEPTANCE_DATA_ROOT',
  );
  if (Platform.isWindows && acceptanceRoot.isNotEmpty) {
    final directory = Directory(acceptanceRoot);
    if (!directory.isAbsolute) {
      throw ArgumentError('Acceptance data root must be absolute.');
    }
    await directory.create(recursive: true);
    return directory;
  }
  final supportDirectory = await getApplicationSupportDirectory();
  final directory = Directory(
    '${supportDirectory.path}${Platform.pathSeparator}MediaFlow',
  );
  await directory.create(recursive: true);
  return directory;
}
