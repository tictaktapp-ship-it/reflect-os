import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/features/chat/providers/chat_providers.dart';
import 'package:reflect_os/features/team/data/models/workspace_membership.dart';

Future<void> showOnlineMembersSheet(
  BuildContext context, {
  required String workspaceId,
  required List<WorkspaceMembership> members,
  required WidgetRef ref,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _OnlineMembersSheet(
      workspaceId: workspaceId,
      members: members,
      ref: ref,
    ),
  );
}

class _OnlineMembersSheet extends StatelessWidget {
  const _OnlineMembersSheet({
    required this.workspaceId,
    required this.members,
    required this.ref,
  });

  final String workspaceId;
  final List<WorkspaceMembership> members;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final onlineIds = ref.watch(chatOnlinePresenceProvider(workspaceId));
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.people_outline, size: 20),
                  const SizedBox(width: 8),
                  Text('Team Members',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: members.length,
                itemBuilder: (context, i) {
                  final member = members[i];
                  final isOnline = onlineIds.contains(member.userId);
                  final name = member.displayName ?? 'Unknown';
                  final initials = _initials(name);
                  return ListTile(
                    leading: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.accentPrimary,
                          backgroundImage: member.avatarUrl != null
                              ? NetworkImage(member.avatarUrl!)
                              : null,
                          child: member.avatarUrl == null
                              ? Text(initials,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600))
                              : null,
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: isOnline
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFF9CA3AF),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: theme.scaffoldBackgroundColor,
                                  width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    title: Text(name,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      isOnline ? 'Online' : 'Offline',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isOnline
                            ? const Color(0xFF22C55E)
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'[\s@]+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
