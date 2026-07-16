import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/application/settings_controller.dart';

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final darkModeEnabled = ref.watch(
      appSettingsProvider.select((settings) => settings.darkModeEnabled),
    );
    return darkModeEnabled ? ThemeMode.dark : ThemeMode.light;
  }

  void setDarkMode(bool enabled) {
    ref.read(appSettingsProvider.notifier).setDarkModeEnabled(enabled);
  }
}
