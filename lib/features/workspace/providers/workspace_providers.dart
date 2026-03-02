import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/providers/auth_state_provider.dart';
import 'package:reflect_os/features/workspace/data/models/workspace_model.dart';
import 'package:reflect_os/features/workspace/data/repositories/workspace_repository.dart';

final workspaceRepositoryProvider = Provider<WorkspaceRepository>((ref) {
  return const WorkspaceRepository();
});

/// All workspaces visible to the current user.
/// Returns an empty list when unauthenticated.
final userWorkspacesProvider = FutureProvider<List<WorkspaceModel>>((ref) async {
  final authStatus = ref.watch(authStateProvider);
  if (authStatus.valueOrNull is! AuthAuthenticated) return [];
  return ref.read(workspaceRepositoryProvider).getUserWorkspaces();
});

/// Explicit workspace selection by the user.
/// When null the app defaults to the first workspace in [userWorkspacesProvider].
final selectedWorkspaceIdProvider = StateProvider<String?>((ref) => null);
