import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import '../features/processing/application/user_processing_providers.dart';
import '../features/processing/application/processing_providers.dart';

class MediaFlowApp extends ConsumerStatefulWidget {
  const MediaFlowApp({super.key});
  @override
  ConsumerState<MediaFlowApp> createState() => _MediaFlowAppState();
}

class _MediaFlowAppState extends ConsumerState<MediaFlowApp> {
  late final AppLifecycleListener lifecycle;
  Future<void>? closing;
  @override
  void initState() {
    super.initState();
    lifecycle = AppLifecycleListener(
      onExitRequested: () async {
        await closeProcessing();
        return AppExitResponse.exit;
      },
      onDetach: () => unawaited(closeProcessing()),
    );
  }

  Future<void> closeProcessing() => closing ??= () async {
    final controller = ref.read(userProcessingProvider.notifier).controller;
    final manager = ref.read(processingOperationManagerProvider);
    await controller.dispose();
    await manager.dispose();
  }();
  @override
  void dispose() {
    lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'MediaFlow',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
