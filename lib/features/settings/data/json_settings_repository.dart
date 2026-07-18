import 'dart:convert';
import 'dart:io';

import '../../../core/logging/app_logger.dart';
import '../../../core/storage/app_data_directory.dart';
import '../domain/app_settings.dart';
import '../domain/settings_repository.dart';

class JsonSettingsRepository implements SettingsRepository {
  factory JsonSettingsRepository({
    AppDataDirectoryResolver directoryResolver = resolveAppDataDirectory,
  }) {
    return JsonSettingsRepository._(directoryResolver);
  }

  JsonSettingsRepository._(this._directoryResolver);

  final AppDataDirectoryResolver _directoryResolver;

  @override
  Future<AppSettings> load() async {
    try {
      final file = await _settingsFile();
      if (!await file.exists()) {
        return const AppSettings();
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        return const AppSettings();
      }
      return AppSettings.fromJson(Map<String, Object?>.from(decoded));
    } catch (error, stackTrace) {
      AppLogger.fileError(
        'Failed to load application settings.',
        error: error,
        stackTrace: stackTrace,
      );
      return const AppSettings();
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    final file = await _settingsFile();
    final temporaryFile = File('${file.path}.tmp');
    await temporaryFile.writeAsString(
      jsonEncode(settings.toJson()),
      flush: true,
    );
    if (await file.exists()) {
      await file.delete();
    }
    await temporaryFile.rename(file.path);
  }

  Future<File> _settingsFile() async {
    final directory = await _directoryResolver();
    await directory.create(recursive: true);
    return File('${directory.path}${Platform.pathSeparator}settings.json');
  }
}
