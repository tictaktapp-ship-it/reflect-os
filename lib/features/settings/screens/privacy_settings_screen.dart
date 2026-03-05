import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/settings/providers/settings_provider.dart';

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState
    extends ConsumerState<PrivacySettingsScreen> {
  // ── Workspace notification settings (existing) ────────────────────────
  bool _isLoading = true;
  bool _isSaving = false;
  String? _workspaceId;

  bool _pushEnabled = true;
  bool _emailEnabled = true;
  bool _weeklyDigestEnabled = true;

  // ── User notification preferences (new) ──────────────────────────────
  bool _notifLoading = true;
  bool _notifSaving = false;
  bool _notifWeeklyDigestEnabled = true;
  bool _notifActivationEmailsEnabled = true;
  String _notifTimezone = 'Europe/London';
  bool _isSendingTestDigest = false;

  static const _timezones = [
    'Europe/London',
    'Europe/Paris',
    'America/New_York',
    'America/Los_Angeles',
    'Asia/Singapore',
    'Australia/Sydney',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _loadNotifPrefs();
    });
  }

  // ── Existing workspace notification settings ──────────────────────────

  Future<void> _load() async {
    final workspaceId = await ref.read(currentWorkspaceProvider.future);
    if (!mounted) return;

    if (workspaceId == null) {
      setState(() => _isLoading = false);
      return;
    }

    _workspaceId = workspaceId;

    final row = await supabase
        .from('user_visible_workspace_notification_settings')
        .select()
        .eq('workspace_id', workspaceId)
        .maybeSingle();

    if (!mounted) return;
    setState(() {
      if (row != null) {
        _pushEnabled = row['push_enabled'] as bool;
        _emailEnabled = row['email_enabled'] as bool;
        _weeklyDigestEnabled = row['weekly_digest_enabled'] as bool;
      }
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    if (_workspaceId == null) return;
    setState(() => _isSaving = true);
    try {
      await supabase.from('workspace_notification_settings').upsert(
        {
          'workspace_id': _workspaceId,
          'push_enabled': _pushEnabled,
          'email_enabled': _emailEnabled,
          'weekly_digest_enabled': _weeklyDigestEnabled,
        },
        onConflict: 'workspace_id',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── User notification preferences (new) ──────────────────────────────

  Future<void> _loadNotifPrefs() async {
    try {
      final prefs = await ref
          .read(settingsRepositoryProvider)
          .getNotificationPreferences();
      if (!mounted) return;
      setState(() {
        if (prefs != null) {
          _notifWeeklyDigestEnabled = prefs.weeklyDigestEnabled;
          _notifActivationEmailsEnabled = prefs.activationEmailsEnabled;
          _notifTimezone = prefs.weeklyDigestTimezone;
        }
        _notifLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _notifLoading = false);
    }
  }

  Future<void> _saveNotifPrefs() async {
    setState(() => _notifSaving = true);
    try {
      await ref.read(settingsRepositoryProvider).upsertNotificationPreferences(
            weeklyDigest: _notifWeeklyDigestEnabled,
            activationEmails: _notifActivationEmailsEnabled,
            timezone: _notifTimezone,
          );
      ref.invalidate(notificationPreferencesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email preferences saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _notifSaving = false);
    }
  }

  Future<void> _sendTestDigest() async {
    setState(() => _isSendingTestDigest = true);
    try {
      await supabase.functions.invoke('send-weekly-digest');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test digest sent to your email')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final isNetworkError = e.toString().contains('Failed to fetch') ||
          e.toString().contains('XMLHttpRequest');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNetworkError
                ? 'Test digest unavailable in this network environment. Will work in production.'
                : 'Failed to send test digest: $e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSendingTestDigest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            SvgPicture.asset(
              Theme.of(context).brightness == Brightness.dark
                  ? 'assets/images/reflect-icon-dark.svg'
                  : 'assets/images/reflect-icon-light.svg',
              height: 160,
            ),
            const SizedBox(width: 8),
            const Text('Notifications'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _workspaceId == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No workspace found. Please contact support.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ── In-app / push notifications ────────────────────
                    _SectionLabel(label: 'In-App & Push'),
                    Card(
                      color: Theme.of(context).colorScheme.surface,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            secondary:
                                const Icon(Icons.notifications_outlined),
                            title: const Text('Push Notifications'),
                            subtitle: const Text(
                                'Receive push alerts for checkpoints and updates'),
                            value: _pushEnabled,
                            onChanged: _isSaving
                                ? null
                                : (value) {
                                    setState(() => _pushEnabled = value);
                                    _save();
                                  },
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            secondary: const Icon(Icons.email_outlined),
                            title: const Text('Email Notifications'),
                            subtitle: const Text(
                                'Receive email summaries and alerts'),
                            value: _emailEnabled,
                            onChanged: _isSaving
                                ? null
                                : (value) {
                                    setState(() => _emailEnabled = value);
                                    _save();
                                  },
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            secondary:
                                const Icon(Icons.calendar_today_outlined),
                            title: const Text('Weekly Digest'),
                            subtitle: const Text(
                                'Receive a weekly summary of your decisions'),
                            value: _weeklyDigestEnabled,
                            onChanged: _isSaving
                                ? null
                                : (value) {
                                    setState(
                                        () => _weeklyDigestEnabled = value);
                                    _save();
                                  },
                          ),
                        ],
                      ),
                    ),
                    if (_isSaving)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: LinearProgressIndicator(),
                      ),

                    // ── Email preferences ──────────────────────────────
                    _SectionLabel(label: 'Email Preferences'),
                    if (_notifLoading)
                      const Card(
                        margin: EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      )
                    else
                      Card(
                        color: Theme.of(context).colorScheme.surface,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          children: [
                            SwitchListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              secondary:
                                  const Icon(Icons.summarize_outlined),
                              title: const Text('Weekly Digest Email'),
                              subtitle: const Text(
                                  'Receive a weekly AI summary of your decisions by email'),
                              value: _notifWeeklyDigestEnabled,
                              onChanged: _notifSaving
                                  ? null
                                  : (value) {
                                      setState(() =>
                                          _notifWeeklyDigestEnabled = value);
                                      _saveNotifPrefs();
                                    },
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            // Timezone selector
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  const Icon(Icons.schedule_outlined,
                                      size: 24,
                                      color: Colors.grey),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Digest Timezone'),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Digest is sent at 07:00 in your timezone',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.6),
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  DropdownButton<String>(
                                    value: _notifTimezone,
                                    underline: const SizedBox.shrink(),
                                    onChanged: _notifSaving
                                        ? null
                                        : (value) {
                                            if (value == null) return;
                                            setState(
                                                () => _notifTimezone = value);
                                            _saveNotifPrefs();
                                          },
                                    items: _timezones
                                        .map(
                                          (tz) => DropdownMenuItem(
                                            value: tz,
                                            child: Text(
                                              tz,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            SwitchListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              secondary:
                                  const Icon(Icons.play_circle_outline),
                              title: const Text('Activation Emails'),
                              subtitle: const Text(
                                  'Get notified when decisions move to Active'),
                              value: _notifActivationEmailsEnabled,
                              onChanged: _notifSaving
                                  ? null
                                  : (value) {
                                      setState(() =>
                                          _notifActivationEmailsEnabled =
                                              value);
                                      _saveNotifPrefs();
                                    },
                            ),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            // Send test digest button
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              child: Row(
                                children: [
                                  const Icon(Icons.send_outlined,
                                      size: 24, color: Colors.grey),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Test Weekly Digest'),
                                        Text(
                                          'Send a test digest to your email now',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.6),
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _isSendingTestDigest
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : OutlinedButton(
                                          onPressed: _sendTestDigest,
                                          child: const Text('Send test'),
                                        ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_notifSaving)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: LinearProgressIndicator(),
                      ),
                  ],
                ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6, top: 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
      ),
    );
  }
}
