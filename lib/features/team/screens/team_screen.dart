import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/core/utils/csv_downloader.dart';
import 'package:reflect_os/core/widgets/workspace_switcher_chip.dart';
import 'package:reflect_os/features/team/data/models/workspace_membership.dart';
import 'package:reflect_os/features/team/providers/team_provider.dart';

class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  // ── CSV helpers ────────────────────────────────────────────────────────────

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
        '', // Email not available in current model
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
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(teamMembersProvider);
    final currentUserId = supabase.auth.currentUser?.id;
    final members = membersAsync.valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const WorkspaceSwitcherChip(),
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
              loading: () => const Center(child: CircularProgressIndicator()),
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
                if (items.isEmpty) {
                  return const Center(child: Text('No team members found.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, index) => _MemberTile(
                    member: items[index],
                    isCurrentUser: items[index].userId == currentUserId,
                  ),
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
  const _MemberTile({required this.member, required this.isCurrentUser});

  final WorkspaceMembership member;
  final bool isCurrentUser;

  static Color _roleColor(String role) => switch (role.toLowerCase()) {
        'owner' => AppColors.accentPrimary,
        'editor' => AppColors.warning,
        _ => AppColors.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColor(member.role);
    final nameToShow = (member.displayName != null &&
            member.displayName!.isNotEmpty)
        ? member.displayName!
        : (member.userId.length >= 8
            ? member.userId.substring(0, 8)
            : member.userId);
    final joined = DateFormat('d MMM yyyy').format(member.createdAt.toLocal());

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar or fallback icon
            CircleAvatar(
              radius: 18,
              backgroundImage: member.avatarUrl != null
                  ? NetworkImage(member.avatarUrl!)
                  : null,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
              child: member.avatarUrl == null
                  ? Icon(
                      Icons.person,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isCurrentUser ? '${member.role} (you)' : member.role,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: roleColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
