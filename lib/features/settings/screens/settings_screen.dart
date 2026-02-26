import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/routing/routes.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/core/providers/theme_provider.dart';
import 'package:reflect_os/features/auth/providers/auth_action_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = supabase.auth.currentUser?.email ?? '—';
    final isSigningOut = ref.watch(authActionProvider).isLoading;
    final themeMode = ref.watch(themeModeProvider);

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

          // ── Sign out ──────────────────────────────────────────────
          _SectionCard(
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.destructive,
                    foregroundColor: AppColors.textPrimary,
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
      color: AppColors.backgroundSurface,
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
                color: AppColors.textSecondary,
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
