import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/routing/routes.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/core/providers/theme_provider.dart';
import 'package:reflect_os/features/auth/providers/auth_action_provider.dart';
import 'package:reflect_os/features/settings/providers/vertical_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = supabase.auth.currentUser?.email ?? '—';
    final isSigningOut = ref.watch(authActionProvider).isLoading;
    final themeMode = ref.watch(themeModeProvider);
    final verticalAsync = ref.watch(currentVerticalProvider);
    final isInvesting =
        verticalAsync.valueOrNull?.verticalName == 'investing';

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Account ───────────────────────────────────────────────
          _SectionCard(
            children: [
              _SettingsRow(
                label: 'Account',
                value: email,
              ),
            ],
          ),

          // ── Notifications ─────────────────────────────────────────
          _SectionCard(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('Notifications'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.settingsPrivacy),
              ),
            ],
          ),

          // ── Appearance ────────────────────────────────────────────
          _SectionCard(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.brightness_6_outlined),
                title: const Text('Appearance'),
                subtitle: Text(
                  themeMode == ThemeMode.light ? 'Light' : 'Dark',
                ),
                trailing: Switch(
                  value: themeMode == ThemeMode.light,
                  onChanged: (_) =>
                      ref.read(themeModeProvider.notifier).toggle(),
                ),
              ),
            ],
          ),

          // ── Billing ───────────────────────────────────────────────
          _SectionCard(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.credit_card_outlined),
                title: const Text('Billing'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.settingsBilling),
              ),
            ],
          ),

          // ── Audit Log ─────────────────────────────────────────────
          _SectionCard(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history_outlined),
                title: const Text('Audit Log'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.settingsAuditLog),
              ),
            ],
          ),

          // ── Templates ─────────────────────────────────────────────
          _SectionCard(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.article_outlined),
                title: const Text('Templates'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.settingsTemplates),
              ),
            ],
          ),

          // ── Import ────────────────────────────────────────────────
          _SectionCard(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.upload_file_outlined),
                title: const Text('Bulk Import'),
                subtitle: const Text('Import decisions from a CSV file'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.import),
              ),
            ],
          ),

          // ── Calendar ──────────────────────────────────────────────
          _SectionCard(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Calendar'),
                subtitle: const Text('Connect Google Calendar or Outlook'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.settingsCalendar),
              ),
            ],
          ),

          // ── Workspace Vertical ────────────────────────────────────
          _SectionCard(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.tune_outlined),
                title: const Text('Workspace Vertical'),
                subtitle: const Text(
                    'Customise tags, categories, and checkpoints'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.settingsVertical),
              ),
            ],
          ),

          // ── Workspace Branding ────────────────────────────────────
          _SectionCard(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Workspace Branding'),
                subtitle: const Text('Logo, colours, and company details'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.settingsBranding),
              ),
            ],
          ),

          // ── Portfolio (investing vertical only) ───────────────
          if (isInvesting)
            _SectionCard(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.business_outlined),
                  title: const Text('Portfolio'),
                  subtitle: const Text('Manage investment assets'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.investmentAssets),
                ),
              ],
            ),

          // ── Sign out ──────────────────────────────────────────────
          _SectionCard(
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.destructive,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSigningOut
                      ? null
                      : () => ref
                          .read(authActionProvider.notifier)
                          .signOut(),
                  child: isSigningOut
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Sign Out'),
                ),
              ),
            ],
          ),

          // ── App version ───────────────────────────────────────────
          _SectionCard(
            children: [
              _SettingsRow(
                label: 'Version',
                value: '1.0.0',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
