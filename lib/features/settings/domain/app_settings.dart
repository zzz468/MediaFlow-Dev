class AppSettings {
  const AppSettings({
    this.defaultDownloadDirectory,
    this.downloadNotificationsEnabled = true,
    this.autoCleanupFailedFiles = true,
    this.darkModeEnabled = false,
  });

  final String? defaultDownloadDirectory;
  final bool downloadNotificationsEnabled;
  final bool autoCleanupFailedFiles;
  final bool darkModeEnabled;

  AppSettings copyWith({
    Object? defaultDownloadDirectory = _unset,
    bool? downloadNotificationsEnabled,
    bool? autoCleanupFailedFiles,
    bool? darkModeEnabled,
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
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'defaultDownloadDirectory': defaultDownloadDirectory,
      'downloadNotificationsEnabled': downloadNotificationsEnabled,
      'autoCleanupFailedFiles': autoCleanupFailedFiles,
      'darkModeEnabled': darkModeEnabled,
    };
  }

  factory AppSettings.fromJson(Map<String, Object?> json) {
    return AppSettings(
      defaultDownloadDirectory: json['defaultDownloadDirectory'] as String?,
      downloadNotificationsEnabled:
          json['downloadNotificationsEnabled'] as bool? ?? true,
      autoCleanupFailedFiles: json['autoCleanupFailedFiles'] as bool? ?? true,
      darkModeEnabled: json['darkModeEnabled'] as bool? ?? false,
    );
  }

  static const _unset = Object();
}
