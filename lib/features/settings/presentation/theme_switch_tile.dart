import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_providers.dart';

class ThemeSwitchTile extends ConsumerWidget {
  const ThemeSwitchTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final scheme = Theme.of(context).colorScheme;
    final platformDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final isDark =
        mode == ThemeMode.dark || (mode == ThemeMode.system && platformDark);
    final accent = scheme.primary;

    return ListTile(
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
          color: accent,
          size: 22,
        ),
      ),
      title: const Text(
        'Koyu tema',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15.5,
        ),
      ),
      subtitle: Text(
        isDark ? 'Açık' : 'Kapalı',
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 12.5,
        ),
      ),
      trailing: Switch.adaptive(
        value: isDark,
        onChanged: (v) =>
            ref.read(themeModeProvider.notifier).toggleDark(v),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      onTap: () => ref
          .read(themeModeProvider.notifier)
          .toggleDark(!isDark),
    );
  }
}
