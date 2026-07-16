import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/theme_controller.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(themeModeProvider) == ThemeMode.dark;

    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Configure the MediaFlow workspace.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 32),
        Card(
          child: SwitchListTile(
            value: isDarkMode,
            onChanged: (enabled) {
              ref.read(themeModeProvider.notifier).setDarkMode(enabled);
            },
            title: const Text('Dark mode'),
            subtitle: const Text('Use a dark color theme for the app.'),
            secondary: const Icon(Icons.dark_mode_outlined),
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
                const _AboutRow(label: 'Version', value: '0.1.0'),
                const _AboutRow(label: 'Status', value: 'Stage 2 foundation'),
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
