import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/routing/routes.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/core/providers/theme_provider.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/features/auth/providers/auth_action_provider.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Profile ───────────────────────────────────────────────
          const _ProfileCard(),

          // ── Account ───────────────────────────────────────────────
          _SectionCard(
            children: [
              _SettingsRow(
                label: 'Account',
                value: email,
              ),
            ],
          ),

          // ── Workspace ─────────────────────────────────────────────
          const _WorkspaceSwitcherSection(),

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

          // ── Personalisation ───────────────────────────────────────
          _SectionCard(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.people_outline),
                title: const Text('Demographic Packs'),
                subtitle: const Text('Tailor decisions to your audience'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.packs),
              ),
            ],
          ),

          // ── Data & Privacy ───────────────────────────────────────
          _SectionCard(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Data & Privacy'),
                subtitle: const Text('GDPR requests, data export, delete account'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.settingsDataPrivacy),
              ),
            ],
          ),

          // ── Privacy & Security ─────────────────────────────────────
          _EncryptionSection(ref: ref),

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

          // ── Portfolio ─────────────────────────────────────────
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

    await ref.read(profileRepositoryProvider).updateDisplayName(userId, result);
    ref.invalidate(profileProvider);
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

// ── Workspace Switcher ────────────────────────────────────────────────────────

class _WorkspaceSwitcherSection extends ConsumerWidget {
  const _WorkspaceSwitcherSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceName = ref.watch(workspaceNameProvider).valueOrNull;
    if (workspaceName == null) return const SizedBox.shrink();

    return _SectionCard(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.business_outlined),
          title: const Text('Workspace'),
          subtitle: Text(workspaceName),
          trailing: const Icon(Icons.unfold_more),
          onTap: () => _showSheet(context, ref),
        ),
      ],
    );
  }

  void _showSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        final workspaces = ref.read(userWorkspacesProvider).valueOrNull ?? [];
        final currentId = ref.read(currentWorkspaceProvider).valueOrNull;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  'Switch Workspace',
                  style: Theme.of(sheetCtx).textTheme.titleMedium,
                ),
              ),
              ...workspaces.map(
                (w) => ListTile(
                  leading: const Icon(Icons.business_outlined),
                  title: Text(w.name),
                  subtitle: Text(w.role == 'owner' ? 'Owner' : 'Member'),
                  trailing: w.id == currentId
                      ? const Icon(Icons.check, color: AppColors.accentPrimary)
                      : null,
                  onTap: () {
                    ref.read(selectedWorkspaceIdProvider.notifier).state = w.id;
                    Navigator.of(sheetCtx).pop();
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
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
      ],
    );
  }
}
