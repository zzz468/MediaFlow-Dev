import 'package:go_router/go_router.dart';

import '../../features/history/presentation/download_history_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../shell/app_shell.dart';

abstract final class AppRoutes {
  static const home = '/home';
  static const history = '/history';
  static const settings = '/settings';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(currentPath: state.uri.path, child: child),
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const HomePage(),
        ),
        GoRoute(
          path: AppRoutes.history,
          builder: (context, state) => const DownloadHistoryPage(),
        ),
        GoRoute(
          path: AppRoutes.settings,
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    ),
  ],
);
