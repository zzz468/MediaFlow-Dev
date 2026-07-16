import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/downloader/application/download_notice_controller.dart';
import '../router/app_router.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.currentPath, required this.child, super.key});

  final String currentPath;
  final Widget child;

  static const _destinations = <_AppDestination>[
    _AppDestination('首页', AppRoutes.home, Icons.home_outlined, Icons.home),
    _AppDestination(
      '下载',
      AppRoutes.history,
      Icons.download_outlined,
      Icons.download,
    ),
    _AppDestination(
      '设置',
      AppRoutes.settings,
      Icons.settings_outlined,
      Icons.settings,
    ),
    _AppDestination(
      '关于',
      AppRoutes.about,
      Icons.info_outline_rounded,
      Icons.info_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<DownloadCompletionNotice?>(downloadCompletionNoticeProvider, (
      previous,
      next,
    ) {
      if (next == null) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('“${next.title}”下载完成。')));
      ref.read(downloadCompletionNoticeProvider.notifier).clear();
    });

    final selectedIndex = _selectedIndex;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Scaffold(
            body: SafeArea(child: child),
            bottomNavigationBar: NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => _navigate(context, index),
              destinations: _destinations
                  .map(
                    (destination) => NavigationDestination(
                      icon: Icon(destination.icon),
                      selectedIcon: Icon(destination.selectedIcon),
                      label: destination.label,
                    ),
                  )
                  .toList(),
            ),
          );
        }

        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  labelType: NavigationRailLabelType.all,
                  leading: const Padding(
                    padding: EdgeInsets.only(top: 20, bottom: 24),
                    child: _BrandMark(),
                  ),
                  onDestinationSelected: (index) => _navigate(context, index),
                  destinations: _destinations
                      .map(
                        (destination) => NavigationRailDestination(
                          icon: Icon(destination.icon),
                          selectedIcon: Icon(destination.selectedIcon),
                          label: Text(destination.label),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: child),
              ],
            ),
          ),
        );
      },
    );
  }

  int get _selectedIndex {
    final index = _destinations.indexWhere(
      (destination) => destination.path == currentPath,
    );
    return index == -1 ? 0 : index;
  }

  void _navigate(BuildContext context, int index) {
    context.go(_destinations[index].path);
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        Icons.play_arrow_rounded,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
  }
}

class _AppDestination {
  const _AppDestination(this.label, this.path, this.icon, this.selectedIcon);

  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;
}
