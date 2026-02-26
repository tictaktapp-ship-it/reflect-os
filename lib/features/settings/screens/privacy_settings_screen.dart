import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState
    extends ConsumerState<PrivacySettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _workspaceId;

  // Defaults — used when no row exists yet.
  bool _pushEnabled = true;
  bool _emailEnabled = true;
  bool _weeklyDigestEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
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
                    Card(
                      color: AppColors.backgroundSurface,
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
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(),
                      ),
                  ],
                ),
    );
  }
}
