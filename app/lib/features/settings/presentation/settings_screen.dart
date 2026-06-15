import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/providers.dart';
import '../../notifications/data/notification_service.dart';
import '../data/settings_service.dart';

const _githubUrl = 'https://github.com/rkapdi/politiFace';
const _licenseUrl =
    'https://github.com/rkapdi/politiFace/blob/main/LICENSE';
const _privacyUrl = 'https://rkapdi.github.io/politiFace/privacy-policy/';

/// Runtime app version string, read once at first access. Format: "1.1.0 (2)".
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService(ref.watch(databaseProvider));
});

final remindersEnabledProvider = FutureProvider<bool>((ref) async {
  final settings = ref.watch(settingsServiceProvider);
  final stored = await settings.remindersEnabled();
  if (!stored) return false;
  // Toggle says on, but the user may have revoked notifications in iOS
  // Settings → Notifications since. Sync the truth so the UI never lies.
  final authorized = await NotificationService.instance.isAuthorized();
  if (!authorized) {
    await settings.setRemindersEnabled(false);
    await NotificationService.instance.cancel();
    return false;
  }
  return true;
});

final analyticsEnabledProvider = FutureProvider<bool>((ref) async {
  return ref.watch(settingsServiceProvider).analyticsEnabled();
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reminders = ref.watch(remindersEnabledProvider).valueOrNull ?? false;
    final analytics = ref.watch(analyticsEnabledProvider).valueOrNull ?? false;
    final settings = ref.read(settingsServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          tooltip: 'Back to home',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: ListView(
        children: [
          _SectionHeader(text: 'Appearance', theme: theme),
          _ThemeModePicker(
            value: ref.watch(themeModeProvider),
            onChanged: (m) =>
                ref.read(themeModeProvider.notifier).set(m),
          ),
          const Divider(height: 32),
          _SectionHeader(text: 'Notifications', theme: theme),
          SwitchListTile(
            title: const Text('Daily review reminder'),
            subtitle: const Text(
                "We'll nudge you at 7 PM so your streak doesn't break."),
            value: reminders,
            onChanged: (v) async {
              if (v) {
                final granted =
                    await NotificationService.instance.requestPermission();
                if (!granted) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        'Permission denied. Enable in iOS Settings → Notifications.'),
                    duration: Duration(seconds: 3),
                  ));
                  return;
                }
                await NotificationService.instance.scheduleDailyReminder();
              } else {
                await NotificationService.instance.cancel();
              }
              await settings.setRemindersEnabled(v);
              ref.invalidate(remindersEnabledProvider);
            },
          ),
          const Divider(height: 32),
          _SectionHeader(text: 'Privacy', theme: theme),
          SwitchListTile(
            title: const Text('Anonymous usage analytics'),
            subtitle: const Text(
                'Help us improve. No political preferences are ever tracked.'),
            value: analytics,
            onChanged: (v) async {
              await settings.setAnalyticsEnabled(v);
              ref.invalidate(analyticsEnabledProvider);
            },
          ),
          ListTile(
            title: const Text('Privacy policy'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _open(_privacyUrl),
          ),
          const Divider(height: 32),
          _SectionHeader(text: 'About', theme: theme),
          ListTile(
            title: const Text('Version'),
            trailing: Text(
              ref.watch(appVersionProvider).valueOrNull ?? '…',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          ListTile(
            title: const Text('Source code on GitHub'),
            subtitle: const Text('Open source under MIT'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _open(_githubUrl),
          ),
          ListTile(
            title: const Text('License'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _open(_licenseUrl),
          ),
          const Divider(height: 32),
          _SectionHeader(text: 'Danger zone', theme: theme),
          ListTile(
            leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            title: Text(
              'Reset progress',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            subtitle: const Text(
                'Wipes streak, XP, reviews, and onboarding. Content stays.'),
            onTap: () => _confirmReset(context, ref),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset all progress?'),
        content: const Text(
            'This clears your streak, XP, every review, and onboarding state. '
            "You'll see onboarding again on the next launch."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    HapticFeedback.heavyImpact();
    await ref.read(settingsServiceProvider).resetProgress();
    ref.invalidate(profileProvider);
    ref.invalidate(dailyChallengeTodayProvider);
    ref.invalidate(remindersEnabledProvider);
    ref.invalidate(analyticsEnabledProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Progress wiped. Restart the app to re-seed.'),
      duration: Duration(seconds: 3),
    ));
    context.go('/');
  }
}

class _ThemeModePicker extends StatelessWidget {
  const _ThemeModePicker({required this.value, required this.onChanged});
  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  static const _options = [
    (ThemeMode.system, 'System', Icons.brightness_auto_outlined),
    (ThemeMode.light, 'Light', Icons.light_mode_outlined),
    (ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final opt in _options) ...[
            Expanded(
              child: _ThemeOptionTile(
                selected: value == opt.$1,
                label: opt.$2,
                icon: opt.$3,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(opt.$1);
                },
                theme: theme,
              ),
            ),
            if (opt.$1 != _options.last.$1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
    required this.theme,
  });
  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final accent = theme.colorScheme.primary;
    return Material(
      color: selected
          ? accent.withOpacity(0.12)
          : theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? accent : theme.colorScheme.outlineVariant,
              width: selected ? 2 : 1.2,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? accent : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 6),
              Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: selected ? accent : theme.colorScheme.onSurface,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text, required this.theme});
  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 1.0,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
