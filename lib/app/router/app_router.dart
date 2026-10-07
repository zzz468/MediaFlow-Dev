import 'package:go_router/go_router.dart';

import '../../features/about/presentation/about_page.dart';
import '../../features/history/presentation/download_history_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../shell/app_shell.dart';
import '../../features/processing/presentation/media_tools_page.dart';

abstract final class AppRoutes {
  static const home = '/home';
  static const history = '/history';
  static const settings = '/settings';
  static const about = '/about';
  static const processing = '/processing';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(currentPath: state.uri.path, child: child),
      routes: [
        GoRoute(
          path: AppRoutes.processing,
          builder: (context, state) => const MediaToolsPage(),
        ),
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
        GoRoute(
          path: AppRoutes.about,
          builder: (context, state) => const AboutPage(),
        ),
      ],
    ),
  ],
);
