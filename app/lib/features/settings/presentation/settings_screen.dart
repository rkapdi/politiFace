import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:workmanager/workmanager.dart';

import '../../../app/providers.dart';
import '../../../core/audio/sound_service.dart';
import '../../../core/sync/supabase_config.dart';
import '../../notifications/data/chapter_ready_service.dart';
import '../../notifications/data/notification_service.dart';
import '../../notifications/data/washington_watch_service.dart';
import '../data/settings_service.dart';
import 'account_section.dart';

const _permissionDeniedCopy =
    'Permission denied. Enable in iOS Settings → Notifications.';

const _githubUrl = 'https://github.com/rkapdi/politiFace';
const _licenseUrl = 'https://github.com/rkapdi/politiFace/blob/main/LICENSE';
const _privacyUrl = 'https://rkapdi.github.io/politiFace/privacy-policy/';

/// Runtime app version string, read once at first access. Format: "1.1.0 (2)".
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

final settingsServiceProvider = Provider<SettingsService>(
  (ref) => SettingsService(ref.watch(databaseProvider)),
);

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

final crashReportsEnabledProvider = FutureProvider<bool>(
  (ref) async => ref.watch(settingsServiceProvider).crashReportsEnabled(),
);

final chapterNotifEnabledProvider = FutureProvider<bool>((ref) async {
  final settings = ref.watch(settingsServiceProvider);
  final stored = await settings.chapterNotifEnabled();
  if (!stored) return false;
  final authorized = await NotificationService.instance.isAuthorized();
  if (!authorized) {
    await settings.setChapterNotifEnabled(false);
    await NotificationService.instance.cancelId(chapterReadyNotificationId);
    return false;
  }
  return true;
});

final washingtonNotifEnabledProvider = FutureProvider<bool>((ref) async {
  final settings = ref.watch(settingsServiceProvider);
  final stored = await settings.washingtonNotifEnabled();
  if (!stored) return false;
  final authorized = await NotificationService.instance.isAuthorized();
  if (!authorized) {
    await settings.setWashingtonNotifEnabled(false);
    await Workmanager().cancelByUniqueName(washingtonRefreshTaskId);
    return false;
  }
  return true;
});

final washLawsEnabledProvider = FutureProvider<bool>(
  (ref) => ref.watch(settingsServiceProvider).washLawsEnabled(),
);

final washBillsEnabledProvider = FutureProvider<bool>(
  (ref) => ref.watch(settingsServiceProvider).washBillsEnabled(),
);

final washEosEnabledProvider = FutureProvider<bool>(
  (ref) => ref.watch(settingsServiceProvider).washEosEnabled(),
);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reminders = ref.watch(remindersEnabledProvider).valueOrNull ?? false;
    final crashReports =
        ref.watch(crashReportsEnabledProvider).valueOrNull ?? false;
    final chapterReady =
        ref.watch(chapterNotifEnabledProvider).valueOrNull ?? false;
    final washingtonOn =
        ref.watch(washingtonNotifEnabledProvider).valueOrNull ?? false;
    final washLaws = ref.watch(washLawsEnabledProvider).valueOrNull ?? false;
    final washBills = ref.watch(washBillsEnabledProvider).valueOrNull ?? false;
    final washEos = ref.watch(washEosEnabledProvider).valueOrNull ?? false;
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
          if (SupabaseConfig.isConfigured) ...[
            _SectionHeader(text: 'Account', theme: theme),
            const AccountSection(),
            const Divider(height: 32),
          ],
          _SectionHeader(text: 'Appearance', theme: theme),
          _ThemeModePicker(
            value: ref.watch(themeModeProvider),
            onChanged: (m) => ref.read(themeModeProvider.notifier).set(m),
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.style_outlined),
            title: const Text('Decks'),
            subtitle: const Text('Choose what shows up in your daily practice'),
            onTap: () => context.push('/decks'),
          ),
          const Divider(height: 32),
          _SectionHeader(text: 'Sound', theme: theme),
          SwitchListTile(
            title: const Text('Sound effects'),
            subtitle: const Text(
              'Soft feedback sounds during rounds and practice. '
              'They follow your ringer switch.',
            ),
            value: ref.watch(soundEnabledProvider),
            onChanged: (v) async {
              await ref.read(soundEnabledProvider.notifier).set(v);
              // Toggle-ON preview: gesture-synchronous and self-describing.
              if (v) ref.read(soundServiceProvider).play(SoundEffect.correct);
            },
          ),
          const Divider(height: 32),
          _SectionHeader(text: 'Notifications', theme: theme),
          SwitchListTile(
            title: const Text('Daily review reminder'),
            subtitle: const Text(
              "We'll nudge you at 7 PM so your streak doesn't break.",
            ),
            value: reminders,
            onChanged: (v) async {
              if (v) {
                final granted =
                    await NotificationService.instance.requestPermission();
                if (!granted) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(_permissionDeniedCopy),
                      duration: Duration(seconds: 3),
                    ),
                  );
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
          SwitchListTile(
            title: const Text('New chapter ready'),
            subtitle: const Text(
              'A morning heads-up when the next chapter unlocks.',
            ),
            value: chapterReady,
            onChanged: (v) async {
              if (v) {
                final granted =
                    await NotificationService.instance.requestPermission();
                if (!granted) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(_permissionDeniedCopy),
                      duration: Duration(seconds: 3),
                    ),
                  );
                  return;
                }
              } else {
                await NotificationService.instance
                    .cancelId(chapterReadyNotificationId);
              }
              await settings.setChapterNotifEnabled(v);
              ref.invalidate(chapterNotifEnabledProvider);
            },
          ),
          SwitchListTile(
            title: const Text('What Washington did'),
            subtitle: const Text(
              'When a law passes, a bill moves, or an executive order lands.',
            ),
            value: washingtonOn,
            onChanged: (v) async {
              if (v) {
                final granted =
                    await NotificationService.instance.requestPermission();
                if (!granted) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(_permissionDeniedCopy),
                      duration: Duration(seconds: 3),
                    ),
                  );
                  return;
                }
                await Workmanager().registerPeriodicTask(
                  washingtonRefreshTaskId,
                  washingtonRefreshTaskId,
                  initialDelay: const Duration(minutes: 15),
                );
              } else {
                await Workmanager().cancelByUniqueName(washingtonRefreshTaskId);
              }
              await settings.setWashingtonNotifEnabled(v);
              ref.invalidate(washingtonNotifEnabledProvider);
            },
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('New laws'),
                  value: washLaws,
                  onChanged: washingtonOn
                      ? (v) async {
                          await settings.setWashLawsEnabled(v);
                          ref.invalidate(washLawsEnabledProvider);
                        }
                      : null,
                ),
                SwitchListTile(
                  title: const Text('Bills advancing'),
                  value: washBills,
                  onChanged: washingtonOn
                      ? (v) async {
                          await settings.setWashBillsEnabled(v);
                          ref.invalidate(washBillsEnabledProvider);
                        }
                      : null,
                ),
                SwitchListTile(
                  title: const Text('Executive orders'),
                  value: washEos,
                  onChanged: washingtonOn
                      ? (v) async {
                          await settings.setWashEosEnabled(v);
                          ref.invalidate(washEosEnabledProvider);
                        }
                      : null,
                ),
              ],
            ),
          ),
          const Divider(height: 32),
          _SectionHeader(text: 'Privacy', theme: theme),
          SwitchListTile(
            title: const Text('Crash reports'),
            subtitle: const Text(
                'Anonymous crash reports help us fix bugs; they never '
                'include what you review or who you are. Turn off any time; '
                'takes effect on next launch.'),
            value: crashReports,
            onChanged: (v) async {
              await settings.setCrashReportsEnabled(v);
              ref.invalidate(crashReportsEnabledProvider);
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
              'Wipes streak, XP, reviews, and onboarding. Content stays.',
            ),
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
            'This clears your streak, XP, every review, and onboarding state, '
            'and reverts sound, theme, and reminder settings to their '
            "defaults. You'll see onboarding again on the next launch."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    HapticFeedback.heavyImpact();
    await ref.read(settingsServiceProvider).resetProgress();
    // Reset also wipes every notification flag, so cancel what's actually
    // scheduled too, otherwise a stale alarm keeps firing with the toggle
    // (now defaulted back to on) out of sync with reality.
    await NotificationService.instance.cancel();
    await NotificationService.instance.cancelId(chapterReadyNotificationId);
    await Workmanager().cancelByUniqueName(washingtonRefreshTaskId);
    ref.invalidate(profileProvider);
    ref.invalidate(remindersEnabledProvider);
    ref.invalidate(crashReportsEnabledProvider);
    ref.invalidate(chapterNotifEnabledProvider);
    ref.invalidate(washingtonNotifEnabledProvider);
    ref.invalidate(washLawsEnabledProvider);
    ref.invalidate(washBillsEnabledProvider);
    ref.invalidate(washEosEnabledProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Progress wiped. Restart the app to re-seed.'),
        duration: Duration(seconds: 3),
      ),
    );
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          text.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}
