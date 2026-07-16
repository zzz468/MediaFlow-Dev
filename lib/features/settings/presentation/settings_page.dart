import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/theme_controller.dart';
import '../../../core/cache/local_cache_service.dart';
import '../../../core/config/app_config.dart';
import '../application/settings_controller.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late Future<int> _cacheSizeFuture;
  bool _isClearingCache = false;

  @override
  void initState() {
    super.initState();
    _cacheSizeFuture = ref.read(localCacheServiceProvider).calculateSize();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final isDarkMode = ref.watch(themeModeProvider) == ThemeMode.dark;
    final appConfig = ref.watch(appConfigProvider);
    final isAndroid = Platform.isAndroid;

    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('设置', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  '所有设置和日志仅保存在本机。',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 28),
                _SectionCard(
                  title: '外观与启动',
                  children: [
                    SwitchListTile(
                      value: isDarkMode,
                      onChanged: (enabled) {
                        ref
                            .read(themeModeProvider.notifier)
                            .setDarkMode(enabled);
                      },
                      title: const Text('深色模式'),
                      subtitle: const Text('使用深色 Material 3 主题。'),
                      secondary: const Icon(Icons.dark_mode_outlined),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      value: settings.restoreTasksOnStartup,
                      onChanged: ref
                          .read(appSettingsProvider.notifier)
                          .setRestoreTasksOnStartup,
                      title: const Text('启动时恢复任务状态'),
                      subtitle: const Text('恢复未完成任务的路径、进度和暂停状态。'),
                      secondary: const Icon(Icons.restore_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: '下载',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: const Text('恢复默认目录'),
                      subtitle: Text(
                        isAndroid
                            ? '手机 Download/MediaFlow（公共目录）'
                            : settings.defaultDownloadDirectory ??
                                  '系统默认 MediaFlow 下载目录',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: isAndroid
                          ? const Icon(Icons.folder_shared_outlined)
                          : Wrap(
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
                                    settings.defaultDownloadDirectory,
                                  ),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                              ],
                            ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      value: settings.downloadNotificationsEnabled,
                      onChanged: ref
                          .read(appSettingsProvider.notifier)
                          .setDownloadNotificationsEnabled,
                      title: const Text('下载完成提示'),
                      subtitle: const Text('任务完成时在应用内显示本地提示。'),
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
                const SizedBox(height: 16),
                _SectionCard(
                  title: '本地数据',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.storage_outlined),
                      title: const Text('清理本地缓存'),
                      subtitle: FutureBuilder<int>(
                        future: _cacheSizeFuture,
                        builder: (context, snapshot) {
                          final size = snapshot.data;
                          return Text(
                            size == null
                                ? '正在计算日志和临时文件大小…'
                                : '${_formatBytes(size)} · 不会删除下载记录或媒体文件',
                          );
                        },
                      ),
                      trailing: FilledButton.tonalIcon(
                        onPressed: _isClearingCache ? null : _clearCache,
                        icon: _isClearingCache
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.delete_sweep_outlined),
                        label: const Text('清理'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: '软件信息',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.info_outline_rounded),
                      title: const Text('关于 MediaFlow'),
                      subtitle: Text(
                        '版本 ${appConfig.displayVersion} · Apache-2.0',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.go(AppRoutes.about),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _editDownloadDirectory(String? currentValue) async {
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
    if (selectedPath == null || !mounted) {
      return;
    }
    ref
        .read(appSettingsProvider.notifier)
        .setDefaultDownloadDirectory(selectedPath);
  }

  Future<void> _clearCache() async {
    setState(() => _isClearingCache = true);
    try {
      final clearedBytes = await ref.read(localCacheServiceProvider).clear();
      if (!mounted) {
        return;
      }
      setState(() {
        _cacheSizeFuture = ref.read(localCacheServiceProvider).calculateSize();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已清理 ${_formatBytes(clearedBytes)} 本地缓存。')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('缓存清理失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _isClearingCache = false);
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          ...children,
        ],
      ),
    );
  }
}
