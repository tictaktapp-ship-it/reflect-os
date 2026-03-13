import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/features/team/data/models/workspace_membership.dart';
import 'package:reflect_os/features/team/data/team_repository.dart';

final teamRepositoryProvider = Provider<TeamRepository>(
  (ref) => const TeamRepository(),
);

final teamMembersProvider =
    FutureProvider<List<WorkspaceMembership>>((ref) async {
  final workspaceId = await ref.watch(currentWorkspaceProvider.future);
  if (workspaceId == null) return [];
  return ref
      .read(teamRepositoryProvider)
      .getWorkspaceMemberships(workspaceId);
});

final pendingInvitesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final workspaceId = await ref.watch(currentWorkspaceProvider.future);
  if (workspaceId == null) return [];
  return ref.read(teamRepositoryProvider).getPendingInvites(workspaceId);
});
