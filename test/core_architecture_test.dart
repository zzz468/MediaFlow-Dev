import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/core/config/app_config.dart';
import 'package:mediaflow/core/models/download_task.dart';

void main() {
  test('app config exposes the selected environment', () {
    const config = AppConfig(
      appName: 'MediaFlow Test',
      environment: AppEnvironment.production,
      enableVerboseLogging: true,
    );

    expect(config.isProduction, isTrue);
    expect(config.enableVerboseLogging, isTrue);
  });

  test('download task keeps immutable fields when updated', () {
    final createdAt = DateTime.utc(2026, 7, 16);
    final task = DownloadTask(
      id: 'task-1',
      mediaId: 'media-1',
      createdAt: createdAt,
    );

    final updated = task.copyWith(
      status: DownloadTaskStatus.downloading,
      progress: 0.5,
    );

    expect(updated.id, 'task-1');
    expect(updated.createdAt, createdAt);
    expect(updated.status, DownloadTaskStatus.downloading);
    expect(updated.progress, 0.5);
  });
}
