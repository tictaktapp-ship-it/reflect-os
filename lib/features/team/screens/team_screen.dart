import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:reflect_os/widgets/app_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/core/utils/csv_downloader.dart';
import 'package:reflect_os/features/team/data/models/workspace_membership.dart';
import 'package:reflect_os/features/team/providers/team_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:reflect_os/widgets/dialog_shell.dart';
import 'package:reflect_os/core/theme/app_radius.dart';

class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key});

  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> {
  RealtimeChannel? _realtimeChannel;

  // ── CSV helpers ─────────────────────────────────────────────────────────────

  static String _csvField(String? value) {
    if (value == null || value.isEmpty) return '';
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static String _isoDate(DateTime dt) =>
      dt.toLocal().toIso8601String().split('T').first;

  static String _toCsv(List<WorkspaceMembership> members) {
    final buf = StringBuffer();
    buf.writeln('Name,Email,Role,Joined Date');
    for (final m in members) {
      final name = (m.displayName != null && m.displayName!.isNotEmpty)
          ? m.displayName!
          : (m.userId.length >= 8 ? m.userId.substring(0, 8) : m.userId);
      buf.writeln([
        _csvField(name),
        '',
        _csvField(m.role),
        _csvField(_isoDate(m.createdAt)),
      ].join(','));
    }
    return buf.toString();
  }

  static void _downloadCsv(
      BuildContext context, List<WorkspaceMembership> members) {
    final csv = _toCsv(members);
    final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode(csv)];
    downloadCsv(bytes, 'team_${DateTime.now().millisecondsSinceEpoch}.csv');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported ${members.length} members')),
    );
  }

  @override
  void initState() {
    super.initState();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeRealtime() {
    _realtimeChannel = supabase
        .channel('workspace_memberships_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'workspace_memberships',
          callback: (_) {
            if (mounted) ref.invalidate(teamMembersProvider);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'workspace_memberships',
          callback: (payload) {
            if (mounted) ref.invalidate(teamMembersProvider);
          },
        )
        .subscribe();
  }

  void _showInviteDialog(BuildContext context) {
    final emailController = TextEditingController();
    String selectedRole = 'Editor';
    bool isBusy = false;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return DialogShell(
            title: 'Invite Team Member',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    hintText: 'name@example.com',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'Editor', child: Text('Editor')),
                    DropdownMenuItem(value: 'Viewer', child: Text('Viewer')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedRole = v);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF19CBD6),
                ),
                onPressed: isBusy
                    ? null
                    : () async {
                        final email = emailController.text.trim();
                        if (email.isEmpty) return;
                        setDialogState(() => isBusy = true);
                        try {
                          final workspaceId = ref
                              .read(currentWorkspaceProvider)
                              .valueOrNull;
                          if (workspaceId == null) {
                            throw Exception('No workspace selected');
                          }
                          await ref
                              .read(teamRepositoryProvider)
                              .inviteMember(
                                workspaceId: workspaceId,
                                email: email,
                                role: selectedRole,
                              );
                          if (ctx.mounted) {
                            Navigator.of(dialogCtx).pop();
                            ref.invalidate(teamMembersProvider);
                            ref.invalidate(pendingInvitesProvider);
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            Navigator.of(dialogCtx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to invite: $e')),
                            );
                          }
                        }
                      },
                child: const Text('Invite'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showMemberSheet(
    BuildContext context,
    WorkspaceMembership member,
    bool isCurrentUser,
    bool canEdit,
  ) {
    String selectedRole = member.role;
    final nameToShow = (member.displayName != null &&
            member.displayName!.isNotEmpty)
        ? member.displayName!
        : (member.userId.length >= 8
            ? member.userId.substring(0, 8)
            : member.userId);
    final joined =
        DateFormat('d MMM yyyy').format(member.createdAt.toLocal());

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return DialogShell(
            title: 'Team Member',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: member.avatarUrl != null
                          ? NetworkImage(member.avatarUrl!)
                          : null,
                      backgroundColor: AppColors.accentPrimary,
                      child: member.avatarUrl == null
                          ? Text(
                              nameToShow[0].toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                nameToShow,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              if (isCurrentUser) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentPrimary
                                        .withValues(alpha: 0.15),
                                    borderRadius: AppRadius.smBR,
                                  ),
                                  child: Text(
                                    'you',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: AppColors.accentPrimary,
                                        ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            'Joined $joined',
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
                  ],
                ),
                const SizedBox(height: 20),
                if (canEdit) ...[
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: const [
                      DropdownMenuItem(value: 'Owner', child: Text('Owner')),
                      DropdownMenuItem(
                          value: 'Editor', child: Text('Editor')),
                      DropdownMenuItem(
                          value: 'Viewer', child: Text('Viewer')),
                    ],
                    onChanged: (v) {
                      if (v != null) setSheetState(() => selectedRole = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.destructive,
                      side: BorderSide(color: AppColors.destructive),
                    ),
                    onPressed: () async {
                      Navigator.of(sheetCtx).pop();
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (_) => DialogShell(
                          title: 'Remove Member',
                          child: Text(
                              'Remove $nameToShow from this workspace?'),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                  foregroundColor: AppColors.destructive),
                              onPressed: () =>
                                  Navigator.of(context).pop(true),
                              child: const Text('Remove'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;
                      try {
                        await ref
                            .read(teamRepositoryProvider)
                            .removeMember(member.id);
                        ref.invalidate(teamMembersProvider);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Failed to remove: $e')),
                          );
                        }
                      }
                    },
                    child: const Text('Remove from workspace'),
                  ),
                ],
              ],
            ),
            actions: canEdit ? [
              TextButton(
                onPressed: () => Navigator.of(sheetCtx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: selectedRole == member.role
                    ? null
                    : () async {
                        try {
                          await ref
                              .read(teamRepositoryProvider)
                              .updateMemberRole(
                                  member.id, selectedRole);
                          if (ctx.mounted) {
                            Navigator.of(sheetCtx).pop();
                            ref.invalidate(teamMembersProvider);
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content:
                                      Text('Failed to update role: $e')),
                            );
                          }
                        }
                      },
                child: const Text('Save changes'),
              ),
            ] : null,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(teamMembersProvider);
    final invitesAsync = ref.watch(pendingInvitesProvider);
    final currentUserId = supabase.auth.currentUser?.id;
    final members = membersAsync.valueOrNull ?? [];

    final currentUserMembership = members
        .where((m) => m.userId == currentUserId)
        .firstOrNull;
    final isOwner = currentUserMembership?.role.toLowerCase() == 'owner';

    return Scaffold(
      appBar: AppHeader(
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export CSV',
            onPressed: members.isEmpty
                ? null
                : () => _downloadCsv(context, members),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showInviteDialog(context),
        backgroundColor: const Color(0xFF19CBD6),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.person_add_outlined, size: 20),
        label: const Text(
          'Invite Member',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'DMSans',
            letterSpacing: 0.3,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'View and manage the members of this workspace and their access levels.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
          ),
          Expanded(
            child: membersAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Failed to load team: $error',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (items) {
                final pendingInvites =
                    invitesAsync.valueOrNull ?? [];

                return ListView(
                  padding:
                      const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: [
                    if (items.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No team members found.'),
                        ),
                      )
                    else
                      ...items.map((m) {
                        final isCurrent = m.userId == currentUserId;
                        final canEdit =
                            isOwner && !isCurrent && m.role.toLowerCase() != 'owner';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _MemberTile(
                            member: m,
                            isCurrentUser: isCurrent,
                            onTap: canEdit || isCurrent
                                ? () => _showMemberSheet(
                                    context, m, isCurrent, canEdit)
                                : null,
                          ),
                        );
                      }),

                    // Pending invites section
                    if (pendingInvites.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ExpansionTile(
                        tilePadding: const EdgeInsets.only(left: 4, right: 8),
                        title: Text(
                          'PENDING INVITES (${pendingInvites.length})',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                              ),
                        ),
                        initiallyExpanded: true,
                        children: pendingInvites
                            .map((invite) => _InviteTile(
                                  invite: invite,
                                  onRevoke: () async {
                                    try {
                                      await ref
                                          .read(teamRepositoryProvider)
                                          .revokeInvite(
                                              invite['id'] as String);
                                      ref.invalidate(
                                          pendingInvitesProvider);
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                          content: Text(
                                              'Failed to revoke: $e'),
                                        ));
                                      }
                                    }
                                  },
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.isCurrentUser,
    required this.onTap,
  });

  final WorkspaceMembership member;
  final bool isCurrentUser;
  final VoidCallback? onTap;

  static Color _roleColor(String role) => switch (role.toLowerCase()) {
        'owner' => AppColors.accentPrimary,
        'editor' => AppColors.warning,
        _ => AppColors.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColor(member.role);
    final nameToShow =
        (member.displayName != null && member.displayName!.isNotEmpty)
            ? member.displayName!
            : (member.userId.length >= 8
                ? member.userId.substring(0, 8)
                : member.userId);
    final joined =
        DateFormat('d MMM yyyy').format(member.createdAt.toLocal());

    return Card(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: member.avatarUrl != null
                    ? NetworkImage(member.avatarUrl!)
                    : null,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                child: member.avatarUrl == null
                    ? Icon(
                        Icons.person,
                        size: 18,
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nameToShow,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Joined $joined',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.15),
                  borderRadius: AppRadius.mdBR,
                ),
                child: Text(
                  isCurrentUser ? '${member.role} (you)' : member.role,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: roleColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteTile extends StatelessWidget {
  const _InviteTile({required this.invite, required this.onRevoke});

  final Map<String, dynamic> invite;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final email = invite['email'] as String? ?? '';
    final role = invite['role'] as String? ?? '';
    final expiresAt = invite['expires_at'] != null
        ? DateTime.tryParse(invite['expires_at'] as String)
        : null;
    final expiryStr = expiresAt != null
        ? DateFormat('d MMM yyyy').format(expiresAt.toLocal())
        : '—';

    return ListTile(
      leading: const Icon(Icons.mail_outline, size: 20),
      title: Text(email, style: Theme.of(context).textTheme.bodyMedium),
      subtitle: Text('$role · Expires $expiryStr',
          style: Theme.of(context).textTheme.bodySmall),
      trailing: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.destructive,
        ),
        onPressed: onRevoke,
        child: const Text('Revoke'),
      ),
    );
  }
}
