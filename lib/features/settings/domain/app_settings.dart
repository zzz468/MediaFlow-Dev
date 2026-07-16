class AppSettings {
  const AppSettings({
    this.defaultDownloadDirectory,
    this.downloadNotificationsEnabled = true,
    this.autoCleanupFailedFiles = true,
    this.darkModeEnabled = false,
    this.restoreTasksOnStartup = true,
  });

  final String? defaultDownloadDirectory;
  final bool downloadNotificationsEnabled;
  final bool autoCleanupFailedFiles;
  final bool darkModeEnabled;
  final bool restoreTasksOnStartup;

  AppSettings copyWith({
    Object? defaultDownloadDirectory = _unset,
    bool? downloadNotificationsEnabled,
    bool? autoCleanupFailedFiles,
    bool? darkModeEnabled,
    bool? restoreTasksOnStartup,
  }) {
    return AppSettings(
      defaultDownloadDirectory: identical(defaultDownloadDirectory, _unset)
          ? this.defaultDownloadDirectory
          : defaultDownloadDirectory as String?,
      downloadNotificationsEnabled:
          downloadNotificationsEnabled ?? this.downloadNotificationsEnabled,
      autoCleanupFailedFiles:
          autoCleanupFailedFiles ?? this.autoCleanupFailedFiles,
      darkModeEnabled: darkModeEnabled ?? this.darkModeEnabled,
      restoreTasksOnStartup:
          restoreTasksOnStartup ?? this.restoreTasksOnStartup,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'defaultDownloadDirectory': defaultDownloadDirectory,
      'downloadNotificationsEnabled': downloadNotificationsEnabled,
      'autoCleanupFailedFiles': autoCleanupFailedFiles,
      'darkModeEnabled': darkModeEnabled,
      'restoreTasksOnStartup': restoreTasksOnStartup,
    };
  }

  factory AppSettings.fromJson(Map<String, Object?> json) {
    return AppSettings(
      defaultDownloadDirectory: json['defaultDownloadDirectory'] as String?,
      downloadNotificationsEnabled:
          json['downloadNotificationsEnabled'] as bool? ?? true,
      autoCleanupFailedFiles: json['autoCleanupFailedFiles'] as bool? ?? true,
      darkModeEnabled: json['darkModeEnabled'] as bool? ?? false,
      restoreTasksOnStartup: json['restoreTasksOnStartup'] as bool? ?? true,
    );
  }

  static const _unset = Object();
}
