import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/features/settings/application/settings_controller.dart';
import 'package:mediaflow/features/settings/domain/app_settings.dart';
import 'package:mediaflow/features/settings/domain/settings_repository.dart';

import '../../helpers/memory_repositories.dart';

void main() {
  test(
    'late settings restore does not write into a disposed provider',
    () async {
      final load = Completer<AppSettings>();
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(
            _DeferredSettingsRepository(load.future),
          ),
        ],
      );
      final controller = container.read(appSettingsProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      container.dispose();
      load.complete(const AppSettings());
      await controller.initialized;
    },
  );

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

final class _DeferredSettingsRepository implements SettingsRepository {
  const _DeferredSettingsRepository(this._load);

  final Future<AppSettings> _load;

  @override
  Future<AppSettings> load() => _load;

  @override
  Future<void> save(AppSettings settings) async {}
}
