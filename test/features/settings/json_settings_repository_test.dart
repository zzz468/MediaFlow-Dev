import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/features/settings/data/json_settings_repository.dart';
import 'package:mediaflow/features/settings/domain/app_settings.dart';

void main() {
  test('persists and restores application settings as JSON', () async {
    final directory = await Directory.systemTemp.createTemp(
      'mediaflow-settings-',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final repository = JsonSettingsRepository(
      directoryResolver: () async => directory,
    );
    const settings = AppSettings(
      defaultDownloadDirectory: r'D:\MediaFlowDownloads',
      downloadNotificationsEnabled: false,
      autoCleanupFailedFiles: false,
      darkModeEnabled: true,
    );

    await repository.save(settings);
    final restored = await repository.load();

    expect(
      restored.defaultDownloadDirectory,
      settings.defaultDownloadDirectory,
    );
    expect(restored.downloadNotificationsEnabled, isFalse);
    expect(restored.autoCleanupFailedFiles, isFalse);
    expect(restored.darkModeEnabled, isTrue);
  });
}
