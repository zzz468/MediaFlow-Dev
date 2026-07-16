import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_logger.dart';
import '../data/json_settings_repository.dart';
import '../domain/app_settings.dart';
import '../domain/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => JsonSettingsRepository(),
);

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );

class AppSettingsController extends Notifier<AppSettings> {
  late SettingsRepository _repository;
  final Completer<void> _initialized = Completer<void>();
  Future<void> _pendingSave = Future<void>.value();
  bool _hasLocalChanges = false;

  Future<void> get initialized => _initialized.future;

  @override
  AppSettings build() {
    _repository = ref.read(settingsRepositoryProvider);
    scheduleMicrotask(_restore);
    return const AppSettings();
  }

  void setDefaultDownloadDirectory(String? value) {
    final normalized = value?.trim();
    _update(
      state.copyWith(
        defaultDownloadDirectory: normalized == null || normalized.isEmpty
            ? null
            : normalized,
      ),
    );
  }

  void setDownloadNotificationsEnabled(bool enabled) {
    _update(state.copyWith(downloadNotificationsEnabled: enabled));
  }

  void setAutoCleanupFailedFiles(bool enabled) {
    _update(state.copyWith(autoCleanupFailedFiles: enabled));
  }

  void setDarkModeEnabled(bool enabled) {
    _update(state.copyWith(darkModeEnabled: enabled));
  }

  void setRestoreTasksOnStartup(bool enabled) {
    _update(state.copyWith(restoreTasksOnStartup: enabled));
  }

  Future<void> flush() => _pendingSave;

  Future<void> _restore() async {
    final restored = await _repository.load();
    if (!_hasLocalChanges) {
      state = restored;
    }
    if (!_initialized.isCompleted) {
      _initialized.complete();
    }
  }

  void _update(AppSettings settings) {
    _hasLocalChanges = true;
    state = settings;
    _pendingSave = _pendingSave
        .then((_) => _repository.save(settings))
        .catchError((Object error, StackTrace stackTrace) {
          AppLogger.fileError(
            'Failed to save application settings.',
            error: error,
            stackTrace: stackTrace,
          );
        });
  }
}
