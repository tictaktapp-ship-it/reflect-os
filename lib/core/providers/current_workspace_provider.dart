import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/providers/auth_state_provider.dart';
import 'package:reflect_os/features/workspace/providers/workspace_providers.dart';

/// Provides the current user's active workspace_id.
/// Derives from [selectedWorkspaceIdProvider] (explicit user choice) falling
/// back to the first entry in [userWorkspacesProvider] (personal workspace).
/// Kept as `FutureProvider<String?>` for backward compat with existing callers.
final currentWorkspaceProvider = FutureProvider<String?>((ref) async {
  final authStatus = ref.watch(authStateProvider);
  if (authStatus.valueOrNull is! AuthAuthenticated) return null;

  final selectedId = ref.watch(selectedWorkspaceIdProvider);
  if (selectedId != null) return selectedId;

  final workspaces = await ref.watch(userWorkspacesProvider.future);
  return workspaces.isNotEmpty ? workspaces.first.id : null;
});

/// Provides the display name of the current workspace.
/// Falls back to 'My Workspace' if the workspace cannot be found.
final workspaceNameProvider = FutureProvider<String?>((ref) async {
  final workspaceId = await ref.watch(currentWorkspaceProvider.future);
  if (workspaceId == null) return null;

  final workspaces = await ref.watch(userWorkspacesProvider.future);
  try {
    return workspaces.firstWhere((w) => w.id == workspaceId).name;
  } catch (_) {
    return 'My Workspace';
  }
});
