import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';

class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(
                            Icons.play_circle_fill_rounded,
                            size: 48,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          config.appName,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text('版本 ${config.displayVersion}'),
                        const SizedBox(height: 14),
                        const Text(
                          '免费、开源、跨平台的本地媒体链接处理工具。'
                          '解析、下载记录、设置和日志均保存在本地。',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '项目地址',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: SelectableText(config.repositoryUrl),
                            ),
                            IconButton(
                              tooltip: '复制项目地址',
                              onPressed: () => _copyRepositoryUrl(
                                context,
                                config.repositoryUrl,
                              ),
                              icon: const Icon(Icons.copy_rounded),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '开源协议',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'MediaFlow 使用 Apache License 2.0 发布。你可以在遵守协议、'
                          '保留版权和许可声明的前提下使用、修改和分发本项目。',
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '本软件不提供任何平台内容授权。用户应遵守媒体平台条款、'
                          '版权规则和所在地法律。',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('零成本原则'),
                        SizedBox(height: 10),
                        Text('• 不依赖自建服务器或付费云服务'),
                        Text('• 不使用商业媒体解析 API'),
                        Text('• 优先使用公开信息和本地离线处理'),
                        Text('• 用户数据和日志仅保存在本机'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _copyRepositoryUrl(BuildContext context, String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('项目地址已复制。')));
  }
}
