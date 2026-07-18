import 'package:mediaflow/features/downloader/domain/download_task.dart';
import 'package:mediaflow/features/downloader/domain/download_task_repository.dart';
import 'package:mediaflow/features/settings/domain/app_settings.dart';
import 'package:mediaflow/features/settings/domain/settings_repository.dart';

class MemoryDownloadTaskRepository implements DownloadTaskRepository {
  MemoryDownloadTaskRepository([List<DownloadTask> initialTasks = const []])
    : tasks = List<DownloadTask>.from(initialTasks);

  List<DownloadTask> tasks;
  int saveCount = 0;

  @override
  Future<List<DownloadTask>> load() async => List<DownloadTask>.from(tasks);

  @override
  Future<void> save(List<DownloadTask> value) async {
    saveCount += 1;
    tasks = List<DownloadTask>.from(value);
  }
}

class MemorySettingsRepository implements SettingsRepository {
  MemorySettingsRepository([this.settings = const AppSettings()]);

  AppSettings settings;
  int saveCount = 0;

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> save(AppSettings value) async {
    saveCount += 1;
    settings = value;
  }
}
