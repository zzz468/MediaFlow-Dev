import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/theme_controller.dart';
import '../../../core/config/app_config.dart';
import '../application/settings_controller.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final isDarkMode = ref.watch(themeModeProvider) == ThemeMode.dark;
    final appConfig = ref.watch(appConfigProvider);

    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text('配置下载行为、存储位置和应用外观。', style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 32),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                value: isDarkMode,
                onChanged: (enabled) {
                  ref.read(themeModeProvider.notifier).setDarkMode(enabled);
                },
                title: const Text('深色模式'),
                subtitle: const Text('使用深色 Material 3 主题。'),
                secondary: const Icon(Icons.dark_mode_outlined),
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: settings.downloadNotificationsEnabled,
                onChanged: ref
                    .read(appSettingsProvider.notifier)
                    .setDownloadNotificationsEnabled,
                title: const Text('下载完成通知'),
                subtitle: const Text('下载完成后记录通知事件，为系统通知接入预留。'),
                secondary: const Icon(Icons.notifications_outlined),
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: settings.autoCleanupFailedFiles,
                onChanged: ref
                    .read(appSettingsProvider.notifier)
                    .setAutoCleanupFailedFiles,
                title: const Text('自动清理失败文件'),
                subtitle: const Text('下载失败时删除未完成的 .part 文件。'),
                secondary: const Icon(Icons.cleaning_services_outlined),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('默认下载目录'),
            subtitle: Text(
              settings.defaultDownloadDirectory ?? '系统默认 MediaFlow 下载目录',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Wrap(
              spacing: 4,
              children: [
                if (settings.defaultDownloadDirectory != null)
                  IconButton(
                    tooltip: '恢复默认目录',
                    onPressed: () {
                      ref
                          .read(appSettingsProvider.notifier)
                          .setDefaultDownloadDirectory(null);
                    },
                    icon: const Icon(Icons.restart_alt_rounded),
                  ),
                IconButton(
                  tooltip: '修改目录',
                  onPressed: () => _editDownloadDirectory(
                    context,
                    ref,
                    settings.defaultDownloadDirectory,
                  ),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About MediaFlow',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _AboutRow(label: 'Version', value: appConfig.displayVersion),
                const _AboutRow(label: 'Status', value: 'Stage 4.1'),
                const _AboutRow(
                  label: 'Platforms',
                  value: 'Windows · Android · iOS',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _editDownloadDirectory(
    BuildContext context,
    WidgetRef ref,
    String? currentValue,
  ) async {
    final controller = TextEditingController(text: currentValue ?? '');
    final selectedPath = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('设置默认下载目录'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '目录路径',
              hintText: r'D:\MediaFlowDownloads',
              helperText: '目录不存在时会在首次下载时自动创建。',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (selectedPath == null) {
      return;
    }
    ref
        .read(appSettingsProvider.notifier)
        .setDefaultDownloadDirectory(selectedPath);
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 88, child: Text(label)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
