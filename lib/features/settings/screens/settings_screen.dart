import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:reflect_os/core/constants/legal_versions.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/providers/auth_state_provider.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/core/providers/package_info_provider.dart';
import 'package:reflect_os/core/providers/theme_provider.dart';
import 'package:reflect_os/core/routing/routes.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/core/widgets/workspace_switcher_chip.dart';
import 'package:reflect_os/features/auth/providers/auth_action_provider.dart';
import 'package:reflect_os/features/legal/providers/legal_consent_provider.dart';
import 'package:reflect_os/features/legal/screens/legal_acceptance_screen.dart';
import 'package:reflect_os/features/legal/screens/legal_document_viewer_screen.dart';
import 'package:reflect_os/features/settings/providers/profile_provider.dart';
import 'package:reflect_os/features/settings/widgets/encryption_mode_tile.dart';
import 'package:reflect_os/features/workspace/data/models/workspace_model.dart';
import 'package:reflect_os/features/workspace/providers/workspace_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = supabase.auth.currentUser?.email ?? '—';
    final isSigningOut = ref.watch(authActionProvider).isLoading;
    final themeMode = ref.watch(themeModeProvider);
    final currentWorkspaceName = ref.watch(workspaceNameProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── GROUP 1 — My Account ──────────────────────────────────
          _SettingsGroup(
            title: 'My Account',
            initiallyExpanded: true,
            children: [
              const _ProfileCard(),
              _SectionCard(
                children: [
                  _SettingsRow(label: 'Account', value: email),
                ],
              ),
            ],
          ),

          // ── GROUP 2 — Workspace ───────────────────────────────────
          _SettingsGroup(
            title: 'Workspace',
            subtitle: currentWorkspaceName,
            children: [
              const _WorkspaceContextBanner(),
              const _WorkspaceManagementSection(),
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
                  const Divider(height: 1, indent: 40, endIndent: 0),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.palette_outlined),
                    title: const Text('Workspace Branding'),
                    subtitle:
                        const Text('Logo, colours, and company details'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(Routes.settingsBranding),
                  ),
                  const Divider(height: 1, indent: 40, endIndent: 0),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.people_outline),
                    title: const Text('Demographic Packs'),
                    subtitle:
                        const Text('Tailor decisions to your audience'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(Routes.packs),
                  ),
                  const Divider(height: 1, indent: 40, endIndent: 0),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.article_outlined),
                    title: const Text('Templates'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(Routes.settingsTemplates),
                  ),
                  const Divider(height: 1, indent: 40, endIndent: 0),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.upload_file_outlined),
                    title: const Text('Bulk Import'),
                    subtitle:
                        const Text('Import decisions from a CSV file'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(Routes.import),
                  ),
                  const Divider(height: 1, indent: 40, endIndent: 0),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('Calendar'),
                    subtitle: const Text(
                        'Connect Google Calendar or Outlook'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(Routes.settingsCalendar),
                  ),
                ],
              ),
            ],
          ),

          // ── GROUP 3 — Preferences ─────────────────────────────────
          _SettingsGroup(
            title: 'Preferences',
            children: [
              _SectionCard(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.notifications_outlined),
                    title: const Text('Notifications'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(Routes.settingsPrivacy),
                  ),
                  const Divider(height: 1, indent: 40, endIndent: 0),
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
              _EncryptionSection(ref: ref),
            ],
          ),

          // ── GROUP 4 — Data & Admin ────────────────────────────────
          _SettingsGroup(
            title: 'Data & Admin',
            children: [
              _SectionCard(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.credit_card_outlined),
                    title: const Text('Billing'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(Routes.settingsBilling),
                  ),
                  const Divider(height: 1, indent: 40, endIndent: 0),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history_outlined),
                    title: const Text('Audit Log'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(Routes.settingsAuditLog),
                  ),
                  const Divider(height: 1, indent: 40, endIndent: 0),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Data & Privacy'),
                    subtitle: const Text(
                        'GDPR requests, data export, delete account'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        context.push(Routes.settingsDataPrivacy),
                  ),
                  const Divider(height: 1, indent: 40, endIndent: 0),
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
            ],
          ),

          // ── GROUP 5 — Legal & Privacy ─────────────────────────────
          const _LegalPrivacySection(),

          // ── GROUP 6 — About & Feedback ───────────────────────────
          _SettingsGroup(
            title: 'About & Feedback',
            children: [
              _SectionCard(
                children: [
                  // Sub-section 1 — About
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.info_outline),
                    title: const Text('About Reflect OS'),
                    onTap: () => _showAboutSheet(context),
                  ),
                  const Divider(height: 1, indent: 40, endIndent: 0),
                  // Sub-section 2 — Feedback & Contact
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.rate_review_outlined),
                    title: const Text('Send feedback'),
                    subtitle: const Text('Tell us what you think'),
                    onTap: () => _launchUrl(
                        'mailto:contact@reflect-os.com?subject=Feedback'),
                  ),
                  const Divider(height: 1, indent: 40, endIndent: 0),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.lightbulb_outline),
                    title: const Text('Request a feature'),
                    subtitle: const Text('Suggest something new'),
                    onTap: () => _launchUrl(
                        'mailto:contact@reflect-os.com?subject=Feature%20Request'),
                  ),
                  const Divider(height: 1, indent: 40, endIndent: 0),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.mail_outline),
                    title: const Text('Contact us'),
                    subtitle: const Text('contact@reflect-os.com'),
                    onTap: () =>
                        _launchUrl('mailto:contact@reflect-os.com'),
                  ),
                  const Divider(height: 1, indent: 40, endIndent: 0),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.language),
                    title: const Text('Website'),
                    subtitle: const Text('reflect-os.com'),
                    onTap: () => _launchUrl('https://reflect-os.com'),
                  ),
                ],
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
                value: ref.watch(packageInfoProvider).maybeWhen(
                      data: (info) =>
                          '${info.version} (build ${info.buildNumber})',
                      orElse: () => '—',
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── About & Feedback helpers ──────────────────────────────────────────────────

Future<void> _launchUrl(String url) async {
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

void _showAboutSheet(BuildContext context) {
  Widget bullet(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 5),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.accentPrimary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      );

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => SingleChildScrollView(
        controller: scrollCtrl,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App name + tagline
            Text(
              'Reflect OS',
              style: Theme.of(ctx).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Reflect OS is an intelligent decision-logging and reflection '
              'platform for individuals and high-stakes teams. It captures '
              'consequential decisions at the moment they are made, then '
              'brings users back at scheduled checkpoints to record what '
              'actually happened. Over time, those entries become a '
              'structured, searchable decision history that Reflect OS '
              'analyses to surface patterns, calibration signals, and '
              'evidence-based coaching insights. The result is fewer repeat '
              'mistakes, stronger judgment under pressure, and a compounding '
              '"decision intelligence" asset that gets more valuable with '
              'every decision logged.',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),

            // What it does
            Text(
              'What it does',
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Reflect OS helps you log, track, and review your decisions with '
              'structured templates, stakeholder collaboration, outcome scoring, '
              'and a built-in toolkit of decision-making frameworks. Every '
              'decision you make becomes a learning asset.',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),

            // Key features
            Text(
              'Key features',
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            bullet('Decision logging with structured templates'),
            bullet('Stakeholder management and approvals'),
            bullet('Outcome tracking and quality scoring'),
            bullet(
                'Decision toolkit with frameworks (RACI, pre-mortem, SWOT and more)'),
            bullet('Weekly decision digest and coaching tools'),
            bullet('Workspace management for teams'),
            const SizedBox(height: 16),

            // Compliance & standards
            Text(
              'Compliance & standards',
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Reflect OS is designed with privacy and compliance in mind:',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            bullet(
                'Designed for GDPR compliance — full data export and account deletion available in-app'),
            bullet(
                'All data encrypted at rest and in transit (via Supabase/TLS)'),
            bullet('Row-level security enforced on all user data'),
            bullet('Soft deletion with 30-day recovery window'),
            bullet('No advertising, no third-party data selling'),
            bullet('Hosted in the EU (Supabase eu-west-1)'),
            const SizedBox(height: 24),

            // Close button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Settings Group (collapsible) ──────────────────────────────────────────────

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.title,
    required this.children,
    this.initiallyExpanded = false,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      key: PageStorageKey(title),
      title: subtitle != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            )
          : Text(title, style: theme.textTheme.titleSmall),
      initiallyExpanded: initiallyExpanded,
      tilePadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      childrenPadding: EdgeInsets.zero,
      shape: const Border(),
      collapsedShape: const Border(),
      children: children,
    );
  }
}

// ── Profile Card ──────────────────────────────────────────────────────────────

class _ProfileCard extends ConsumerStatefulWidget {
  const _ProfileCard();

  @override
  ConsumerState<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends ConsumerState<_ProfileCard> {
  bool _uploading = false;

  Future<void> _pickAndUploadAvatar() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final repo = ref.read(profileRepositoryProvider);
      final url = await repo.uploadAvatar(userId, file);
      await repo.updateAvatarUrl(userId, url);
      ref.invalidate(profileProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload avatar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _editDisplayName(String current) async {
    final controller = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Display name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Enter your name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty || !mounted) return;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await ref
          .read(profileRepositoryProvider)
          .updateDisplayName(userId, result);
      ref.invalidate(profileProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save display name: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final email = supabase.auth.currentUser?.email ?? '—';

    return _SectionCard(
      children: [
        profileAsync.when(
          loading: () => const SizedBox(
            height: 56,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => _ProfileRow(
            email: email,
            displayName: null,
            avatarUrl: null,
            uploading: false,
            onTapAvatar: _pickAndUploadAvatar,
            onEditName: _editDisplayName,
          ),
          data: (profile) => _ProfileRow(
            email: email,
            displayName: profile?.displayName,
            avatarUrl: profile?.avatarUrl,
            uploading: _uploading,
            onTapAvatar: _pickAndUploadAvatar,
            onEditName: _editDisplayName,
          ),
        ),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.email,
    required this.displayName,
    required this.avatarUrl,
    required this.uploading,
    required this.onTapAvatar,
    required this.onEditName,
  });

  final String email;
  final String? displayName;
  final String? avatarUrl;
  final bool uploading;
  final VoidCallback onTapAvatar;
  final void Function(String) onEditName;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(displayName ?? email);
    return Row(
      children: [
        GestureDetector(
          onTap: uploading ? null : onTapAvatar,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.accentPrimary,
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                  child: avatarUrl == null
                      ? Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
                if (uploading)
                  const Positioned.fill(
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.black45,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.accentPrimary,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      displayName ?? email,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    onPressed: () => onEditName(displayName ?? ''),
                    tooltip: 'Edit name',
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              Text(
                email,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'[\s@]+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

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
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
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

// ── Workspace Context Banner ──────────────────────────────────────────────────

class _WorkspaceContextBanner extends ConsumerWidget {
  const _WorkspaceContextBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentWorkspaceName = ref.watch(workspaceNameProvider).valueOrNull;
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.business,
                color: theme.colorScheme.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configuring workspace',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    currentWorkspaceName ?? 'Loading...',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => showWorkspaceSwitcherSheet(context, ref),
              child: Text(
                'Switch',
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Workspace Management ──────────────────────────────────────────────────────

class _WorkspaceManagementSection extends StatelessWidget {
  const _WorkspaceManagementSection();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.manage_accounts_outlined),
          title: const Text('Manage workspaces'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(Routes.settingsWorkspaces),
        ),
        const Divider(height: 1, indent: 40, endIndent: 0),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.auto_fix_high),
          title: const Text('Set up workspace'),
          subtitle: const Text('Configure verticals, templates and branding'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(Routes.workspaceWizard),
        ),
      ],
    );
  }
}

// ── Legal & Privacy section ───────────────────────────────────────────────────

class _LegalPrivacySection extends ConsumerWidget {
  const _LegalPrivacySection();

  static final _dateFmt = DateFormat('d MMM yyyy');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authStatus = ref.watch(authStateProvider).valueOrNull;
    final userId = authStatus is AuthAuthenticated
        ? authStatus.session.user.id
        : null;

    final consentAsync =
        userId != null ? ref.watch(latestConsentProvider(userId)) : null;
    final consent = consentAsync?.valueOrNull;

    final acceptedStr = consent != null
        ? _dateFmt.format(consent.acceptedAt.toLocal())
        : '—';

    void pushViewer(String title, String asset) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LegalDocumentViewerScreen(
            title: title,
            assetPath: asset,
          ),
        ),
      );
    }

    void showCookieSheet() {
      bool current = consent?.cookieConsent ?? false;
      showModalBottomSheet<void>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSheet) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cookie Preferences',
                      style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Functional cookies help remember your theme preference and '
                    'selected workspace. They are never used for advertising.',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: Theme.of(ctx)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Functional cookies'),
                    subtitle: const Text('Theme and workspace memory'),
                    value: current,
                    onChanged: (v) => setSheet(() => current = v),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return _SettingsGroup(
      title: 'Legal & Privacy',
      children: [
        _SectionCard(
          children: [
            // Terms & Conditions
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.gavel_outlined),
              title: const Text('Terms & Conditions'),
              subtitle: Text(
                  'Version ${LegalVersions.tcVersion} · Accepted $acceptedStr'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => pushViewer(
                'Terms & Conditions',
                'assets/legal/terms_and_conditions.txt',
              ),
            ),
            const Divider(height: 1, indent: 40, endIndent: 0),

            // Privacy Policy
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.policy_outlined),
              title: const Text('Privacy Policy'),
              subtitle: Text(
                  'Version ${LegalVersions.privacyVersion} · Accepted $acceptedStr'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => pushViewer(
                'Privacy Policy',
                'assets/legal/privacy_policy.txt',
              ),
            ),

            // Cookie Preferences — web only
            if (kIsWeb) ...[
              const Divider(height: 1, indent: 40, endIndent: 0),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cookie_outlined),
                title: const Text('Cookie Preferences'),
                subtitle: Text(consent?.cookieConsent == true
                    ? 'Functional cookies enabled'
                    : 'Functional cookies disabled'),
                trailing: const Icon(Icons.chevron_right),
                onTap: showCookieSheet,
              ),
            ],

            const Divider(height: 1, indent: 40, endIndent: 0),

            // Consent Receipt
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Consent Receipt'),
              subtitle: Text(
                consent != null
                    ? '${consent.platform ?? 'unknown'} · $acceptedStr'
                    : 'No consent record found',
              ),
              trailing: const Icon(Icons.info_outline),
            ),

            const Divider(height: 1, indent: 40, endIndent: 0),

            // Re-accept
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.refresh_outlined),
              title: const Text('Review & Re-accept Agreements'),
              subtitle: const Text('A new consent record will be created'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const LegalAcceptanceScreen(allowBack: true),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Encryption section ────────────────────────────────────────────────────────

/// Renders the Privacy & Security card containing the [EncryptionModeTile].
/// Resolves the current workspace id and owner status from Riverpod providers.
class _EncryptionSection extends StatelessWidget {
  const _EncryptionSection({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final workspaceId =
        ref.watch(currentWorkspaceProvider).valueOrNull;
    if (workspaceId == null) return const SizedBox.shrink();

    final workspaces =
        ref.watch(userWorkspacesProvider).valueOrNull ?? const <WorkspaceModel>[];
    WorkspaceModel? match;
    for (final w in workspaces) {
      if (w.id == workspaceId) {
        match = w;
        break;
      }
    }
    final isOwner = match?.role == 'owner';

    return _SectionCard(
      children: [
        EncryptionModeTile(
          workspaceId: workspaceId,
          isOwner: isOwner,
        ),
        const Divider(height: 1, indent: 40, endIndent: 0),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.verified_user_outlined),
          title: const Text('Verify encryption'),
          subtitle: const Text('Check that your data is actually encrypted'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(Routes.encryptionStatus),
        ),
      ],
    );
  }
}
