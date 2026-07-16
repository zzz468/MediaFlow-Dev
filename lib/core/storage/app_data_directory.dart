import 'dart:io';

import 'package:path_provider/path_provider.dart';

typedef AppDataDirectoryResolver = Future<Directory> Function();

Future<Directory> resolveAppDataDirectory() async {
  final supportDirectory = await getApplicationSupportDirectory();
  final directory = Directory(
    '${supportDirectory.path}${Platform.pathSeparator}MediaFlow',
  );
  await directory.create(recursive: true);
  return directory;
}
