import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/features/settings/application/settings_controller.dart';

import '../../helpers/memory_repositories.dart';

void main() {
  test(
    'saves settings and restores them in a new provider container',
    () async {
      final repository = MemorySettingsRepository();
      final firstContainer = ProviderContainer(
        overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
      );
      final firstController = firstContainer.read(appSettingsProvider.notifier);
      await firstController.initialized;

      firstController.setDefaultDownloadDirectory(r'D:\MediaFlowDownloads');
      firstController.setDownloadNotificationsEnabled(false);
      firstController.setAutoCleanupFailedFiles(false);
      firstController.setDarkModeEnabled(true);
      firstController.setRestoreTasksOnStartup(false);
      await firstController.flush();
      firstContainer.dispose();

      final secondContainer = ProviderContainer(
        overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(secondContainer.dispose);
      final secondController = secondContainer.read(
        appSettingsProvider.notifier,
      );
      await secondController.initialized;
      final restored = secondContainer.read(appSettingsProvider);

      expect(restored.defaultDownloadDirectory, r'D:\MediaFlowDownloads');
      expect(restored.downloadNotificationsEnabled, isFalse);
      expect(restored.autoCleanupFailedFiles, isFalse);
      expect(restored.darkModeEnabled, isTrue);
      expect(restored.restoreTasksOnStartup, isFalse);
      expect(repository.saveCount, greaterThan(0));
    },
  );
}
